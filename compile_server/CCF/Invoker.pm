package CCF::Invoker;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Util;

use English;
use Encode;
use File::Temp;

BEGIN {
	if($^O eq 'cygwin') {
		require Win32::Codepage::Simple;
		Win32::Codepage::Simple->import(qw(get_codepage));
	}
}

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;
	return bless {
		_config => $arg{config},
		(exists $arg{verbose} ? (_verbose => $arg{verbose}) : ()),
		(exists $arg{debug} ? (_debug => $arg{debug}) : ()),
	}, $class;
}

sub _config
{
	my $self = shift;
	return $self->{_config} if @_ == 0;

	my ($type, $key) = @_;
	return $self->_config->{$type}{$key} if exists $self->_config->{$type} && exists $self->_config->{$type}{$key};
	return $self->_config->{GLOBAL}{$key} if exists $self->_config->{GLOBAL} && exists $self->_config->{GLOBAL}{$key};
	return undef;
}

sub _verbose
{
	my ($self) = @_;
	return exists $self->{_verbose} && $self->{_verbose};
}

sub _debug
{
	my ($self) = @_;
	return exists $self->{_debug} && $self->{_debug};
}

sub _is_cygwin2native
{
	my ($self, $type) = @_;
	return exists $self->_config->{$type}{cygwin2native} && $self->_config->{$type}{cygwin2native} eq 'true';
}

sub _prepare_env
{
	my ($self, $type, $prev) = @_;

	return sub {
		foreach my $hash (@{$self->_config->{$type}{env}}) {
			foreach my $name (keys %$hash) {
				my $t = $hash->{$name};
				$t =~ s/%([^%]*)%/exists($ENV{$1}) ? $ENV{$1} : ''/eg;
				if($name eq 'PATH') {
# NOTE: I can not understand but the following line causes out of memory error on my environment.
#					$t = join ':', map { Cygwin::win_to_posix_path($_, 'true') } split /;/, $t;
					$t = join ':', map { $_ = `cygpath -u '$_'`; s/\s*$//; $_ } split /;/, $t;
#					$t .= ':' . $ENV{PATH};
				}
				$self->_debug and print "envset: $name => $t\n";
				$ENV{$name} = $t;
			}
		}
		$prev->() if defined $prev;
	};
}

sub _is_sandbox
{
	my ($self, $type) = @_;
	my $res = $self->_config($type, 'sandbox');
	return defined $res && ($res eq 'win' || $res eq 'linux');
}

sub _sandbox_env
{
	my ($self, $type, $mode, $prev, $output) = @_;

	return sub {
		if(defined $output) {
			my $input = Cygwin::posix_to_win_path('/dev/null');
			$output = Cygwin::posix_to_win_path($output);

			$ENV{SANDBOX_IN} = $input;
			$ENV{SANDBOX_OUT} = $output;
		}
		$ENV{SANDBOX_MEMLIMIT} = $self->_config($type, "memlimit-$mode") // 0;
		$ENV{SANDBOX_CPULIMIT} = $self->_config($type, "cpulimit-$mode") // 0;
		$ENV{SANDBOX_RTLIMIT}  = $self->_config($type, "rtlimit-$mode")  // 0;

		if($self->_debug) {
			print "envset: $_ => $ENV{$_}\n" for(grep { exists $ENV{$_} } qw(SANDBOX_IN SANDBOX_OUT SANDBOX_CPULIMIT SANDBOX_MEMLIMIT SANDBOX_RTLIMIT));
		}

		$prev->() if defined $prev;
	};
}

# TODO: Refactor
sub _make_arg
{
	my ($self, $type, $mode, $input, $output, $capture) = @_;
	my (@arg, $on_prepare);

# TODO: error check
	my @res;
	if($mode eq 'execute') {
		@res = ($input);
	} else {
		if($self->_is_cygwin2native($type)) {
			$input = Cygwin::posix_to_win_path($input);
			$output = Cygwin::posix_to_win_path($output);
			$on_prepare = $self->_prepare_env($type, $on_prepare) if exists($self->_config->{$type}{env});
		}
		@res = map {
			my $t = $_;
			$t =~ s/\$output/$output/;
			$t =~ s/\$input/$input/ && $mode eq 'link' && $self->_is_sandbox($type) && defined $self->_config($type, 'sandbox-prearg') ?
			(@{$self->_config($type, 'sandbox-prearg')}, $t) : $t;
		} @{$self->_config->{$type}{$mode}};
	}
	if($mode eq 'link' && $self->_is_sandbox($type) && defined $self->_config($type, 'sandbox-arg')) {
		push @res, @{$self->_config($type, 'sandbox-arg')};
	}
# in/out setup in run_cmd arguments
	if($self->_is_sandbox($type) && $self->_config($type, 'sandbox') eq 'win') {
		push @arg, '<', '/dev/null';
	} else {
		push @arg, '<', '/dev/null', '>', $capture, '2>', $capture;
	}
	if($self->_is_sandbox($type)) {
# in/out setup in sandbox environment variables
		if($self->_config($type, 'sandbox') eq 'win') {
			$$capture = __mktemp('.txt');
			$on_prepare = $self->_sandbox_env($type, $mode, $on_prepare, $$capture);
		} else {
			$on_prepare = $self->_sandbox_env($type, $mode, $on_prepare);
		}
		unshift @res, $self->_config($type, 'sandbox-path') if $mode ne 'execute';
	}
# set on_prepare if any
	push @arg, (on_prepare => $on_prepare) if defined $on_prepare;

	$self->_verbose and print STDERR join(' ', @res), "\n";
	return ([@res], @arg);
}

sub _recover_result
{
	my ($self, $type, $capture) = @_;
	if($self->_is_sandbox($type) && $self->_config($type, 'sandbox') eq 'win') {
		my $result;
		local $/;
		open my $fh, '<', $capture;
		$result = <$fh>;
		close $fh;
		unlink $capture;
		return $result;
	} else {
		return $capture;
	}
}

sub _dec
{
	my ($self, $type, $str) = @_;
	return Encode::decode_utf8($str) unless $self->_is_cygwin2native($type);
	return Encode::decode('CP'.get_codepage(), $str);
}

sub __mktemp
{
	my ($suffix, $content) = @_;
	my $fh = File::Temp->new(UNLINK=>0,SUFFIX=>$suffix);
	print $fh $content if defined $content;
	close $fh;
	return $fh->filename;
}

sub compile
{
	my ($self, $type, $source, $callback, $not_unlink) = @_;
	my $result;

	my $input = __mktemp('.cpp', $source);
	my $obj   = __mktemp(($self->_is_cygwin2native($type) || $OSNAME eq 'MSWin32') ? '.obj' : '.o');

	run_cmd($self->_make_arg($type, 'compile', $input, $obj, \$result))->cb(sub {
		my $rc = shift->recv;
		$result = $self->_recover_result($type, $result);
		$result = $self->_dec($type, $result);
		if($rc) {
			$result .= sprintf "CCF: compilation failed by status: 0x%04X\n", $rc;
		}
		unlink $obj unless defined $not_unlink;
		unlink $input;
		$callback->($rc, $result, $obj);
	});
}

sub _obj_adjust
{
	my ($self, $type, $obj, $callback) = @_;

	if($self->_is_sandbox($type)) {
		my $obj2 = __mktemp(($self->_is_cygwin2native($type) || $OSNAME eq 'MSWin32') ? '.obj' : '.o');
		my $result;
		run_cmd(['objcopy', '--redefine-sym', ($self->_config($type, 'sandbox') eq 'win' ? '_main=_main_' : 'main=main_'), $obj, $obj2], '<', '/dev/null', '>', \$result, '2>', \$result)->cb(sub {
			my $rc = shift->recv;
			if($rc) {
				$result .= $self->_dec($type, $result);
			} else {
				$result = '';
			}
			unlink $obj;
			$callback->($rc, $result, $obj2);
		});
	} else {
		$callback->(0, '', $obj);
	}
}

sub link
{
	my ($self, $type, $source, $callback) = @_;

	$self->compile($type, $source, sub {
		my ($rc, $result, $obj) = @_;
		if($rc) {
			unlink $obj;
			$callback->($rc, $result);
			return;
		}
		$self->_obj_adjust($type, $obj, sub {
			my ($rc, $result2, $obj) = @_;
			$result .= $self->_dec($type, $result2);
			if($rc) {
				unlink $obj;
				$result .= sprintf "CCF: Adjujstment of obj prior to link failed by status: 0x%04X\n", $rc;
				$callback->($rc, $result);
				return;
			}
			my $result3;
			my $out = __mktemp('.exe');
			run_cmd($self->_make_arg($type, 'link', $obj, $out, \$result3))->cb(sub {
				my $rc = shift->recv;
				$result3 = $self->_recover_result($type, $result3);
				$result .= $self->_dec($type, $result3);
				if($rc) {
					unlink $obj;
					$result .= sprintf "CCF: link failed by status: 0x%04X\n", $rc;
					$callback->($rc, $result);
					return;
				}
				unlink $obj;
				chmod 0711, $out if $self->_is_cygwin2native($type);
				$callback->($rc, $result, $out);
			});
		});
	}, 1);
}

sub execute
{
	my ($self, $type, $out, $callback) = @_;
	my $result;

	run_cmd($self->_make_arg($type, 'execute', $out, undef, \$result))->cb(sub {
		my $rc = shift->recv;
		$result = $self->_recover_result($type, $result);
		if($rc) {
			$result .= sprintf "CCF: execution failed by status: 0x%04X\n", $rc;
		}
		unlink $out;
		$callback->($rc, $result);
	});
}

1;
__END__
=head1 NAME

CCF::Invoker - Compiler invocation handler for C++ Compiler Farm

=head1 SYNOPSIS

  use CCF::Invoke;
  my $invoker = CCF::Invoke->new(config => $conf);

=head1 DESCRIPTION

CCF::Invoker is a helper module for compiler invocation in C++ Compiler Farm.

=head1 CONFIGURATION

=over 4

=item config => I<hashref>

  {
    GLOBAL => {
      sandbox: I<sandbox-type>
      memlimit-compile: I<integer>
      memlimit-execute: I<integer>
      cpulimit-compile: I<integer>
      cpulimit-execute: I<integer>
      rtlimit-compile:  I<integer>
      rtlimit-execute:  I<integer>
      sandbox-path: I<string>
      sandbox-args: I<string>
    },
    <compilerkey> => {
      name => I<name>
      cygwin2native => I<bool>
      env => [
        { I<name> => I<value>,
          I<name> => I<value> },
        { I<name> => I<value>,
          I<name> => I<value> },
      ],
      compile => [I<args>...],
      link => [I<args>...],
    }
  }

=back

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
