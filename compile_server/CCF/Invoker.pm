package CCF::Invoker;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Util;
use Data::Monad::CondVar;

use English;
use Encode;
use File::Temp;

use ObjectFile::Tiny;

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

# Search configuration value from specific configuration and GLOBAL configuration.
sub _config
{
	my $self = shift;
	return $self->{_config} if @_ == 0;

	my ($type, $key) = @_;
	return $self->_config->{$type}{$key} if exists $self->_config->{$type} && exists $self->_config->{$type}{$key};
	return $self->_config->{GLOBAL}{$key} if exists $self->_config->{GLOBAL} && exists $self->_config->{GLOBAL}{$key};
	return undef;
}

# Check verbose flag
sub _verbose
{
	my ($self) = @_;
	return exists $self->{_verbose} && $self->{_verbose};
}

# Check debug flag
sub _debug
{
	my ($self) = @_;
	return exists $self->{_debug} && $self->{_debug};
}

# Check cygwin2native configuration flag
sub _is_cygwin2native
{
	my ($self, $type) = @_;
	return exists $self->_config->{$type}{cygwin2native} && $self->_config->{$type}{cygwin2native} eq 'true';
}

# Setup general environment variables and call chain if necessary.
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

# Check sandbox configuration flag
sub _is_sandbox
{
	my ($self, $type) = @_;
	my $res = $self->_config($type, 'sandbox');
	return defined $res && ($res eq 'win' || $res eq 'linux');
}

# Setup sandbox environment variables and call chain if necessary.
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

# Make arguments for run_cmd
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
		push @res, $self->_config($type, 'sandbox-path') if $self->_is_sandbox($type);
		push @res, map {
			my $t = $_;
			$t =~ s/\$output/$output/;
# For link in sandbox, sandbox-prearg is prepended and sandbox-arg is appended to input
			$t =~ s/\$input/$input/ && $mode eq 'link' && $self->_is_sandbox($type) ?
			(@{$self->_config($type, 'sandbox-prearg') || []}, $t, @{$self->_config($type, 'sandbox-arg') || []}) : $t;
		} @{$self->_config->{$type}{$mode}};
	}
# in/out setup in run_cmd arguments
	if($self->_is_sandbox($type)) {
		if($self->_config($type, 'sandbox') eq 'win') {
			push @arg, '<', '/dev/null';
			$$capture = __mktemp('.txt');
			$on_prepare = $self->_sandbox_env($type, $mode, $on_prepare, $$capture);
		} else {
			push @arg, '<', '/dev/null', '>', $capture, '2>', $capture;
			$on_prepare = $self->_sandbox_env($type, $mode, $on_prepare);
		}
	} else {
		push @arg, '<', '/dev/null', '>', $capture, '2>', $capture;
	}
# set on_prepare if any
	push @arg, (on_prepare => $on_prepare) if defined $on_prepare;

	$self->_verbose and print STDERR join(' ', @res), "\n";
	return ([@res], @arg);
}

# If necessary, a result is get from a file
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

# Decode character encoding
sub _dec
{
	my ($self, $type, $str) = @_;
	return Encode::decode_utf8($str) unless $self->_is_cygwin2native($type);
	return Encode::decode('CP'.get_codepage(), $str);
}

# Make temporary file without auto deletion
sub __mktemp
{
	my ($suffix, $content) = @_;
	my $fh = File::Temp->new(UNLINK=>0,SUFFIX=>$suffix);
	print $fh $content if defined $content;
	close $fh;
	return $fh->filename;
}

sub __append_result
{
	my ($result, $key, $msg) = @_;
	return unless defined $msg;
	$result->{$key} = '' if ! exists $result->{$key};
	$result->{$key} .= $msg;
}

# External I/F for compilation
sub compile
{
	my ($self, $type, $source, $not_unlink) = @_;
	my ($result, $tresult) = {};

	my $input = __mktemp('.cpp', $source);
	my $obj   = __mktemp(($self->_is_cygwin2native($type) || $OSNAME eq 'MSWin32') ? '.obj' : '.o');

	return run_cmd($self->_make_arg($type, 'compile', $input, $obj, \$tresult))->map(sub {
		my $rc = shift;
		$tresult = $self->_recover_result($type, $tresult);
		$result->{output} = $self->_dec($type, $tresult);
		if($rc) {
			__append_result($result, 'error', sprintf("CCF: compilation failed by status: 0x%04X\n", $rc));
		}
		unlink $obj unless defined $not_unlink;
		unlink $input;
		return ($rc, $result, $obj);
	});
}

# Adjust symbol name in an object file to hook
sub _obj_adjust
{
	my ($self, $type, $obj) = @_;

	if($self->_is_sandbox($type)) {
		my $obj2 = __mktemp(($self->_is_cygwin2native($type) || $OSNAME eq 'MSWin32') ? '.obj' : '.o');
		my ($result, $tresult) = {};
		return run_cmd(['objcopy', '--redefine-sym', ($self->_config($type, 'sandbox') eq 'win' ? '_main=_main_' : 'main=main_'), $obj, $obj2], '<', '/dev/null', '>', \$tresult, '2>', \$tresult)->map(sub {
			my $rc = shift;
			if($rc) {
				__append_result($result, 'output', $self->_dec($type, $tresult));
			}
			unlink $obj;
			return ($rc, $result, $obj2);
		});
	} else {
		return cv_unit(0, {}, $obj);
	}
}

sub _check_obj
{
	my ($self, $type, $obj) = @_;
	if($self->_is_sandbox($type)) {
		my $o = ObjectFile::Tiny->new($obj);
		my $wd = $self->_config($type, 'sandbox-whitelist-directive');
		if(defined $wd) {
			my $contents = $o->section_contents('.drectve');
			$contents =~ s/^\s+//;
			$contents =~ s/"(\w+='[^'"]*')?(\s+\w+='[^'"]*')*"/_/g;
			my @t = grep { $_ !~ qr/$wd/ } split /\s+/, $contents;
			return 'Found prohibited linker directive(s): '.join(', ', @t) if @t;
		}
		my $bs = $self->_config($type, 'sandbox-blacklist-section');
		if(defined $bs) {
			my @t = $o->exists_section(qr/$bs/);
			return 'Found prohibited section(s): '.join(', ', @t) if @t;
		}
	}
	return;
}

# External I/F for link
sub link
{
	my ($self, $type, $source) = @_;

	$self->compile($type, $source, 1)->flat_map(sub {
		my ($rc, $result, $obj) = @_;
		if($rc) {
			unlink $obj;
			return cv_unit($rc, $result);
		}
		my $check = $self->_check_obj($type, $obj);
		if(defined $check) {
			unlink $obj;
			__append_result($result, 'error', 'CCF: '.$check);
			return cv_unit($rc, $result);
		}
		return $self->_obj_adjust($type, $obj)->flat_map(sub {
			my ($rc, $tresult, $obj) = @_;
			__append_result($result, 'output', $self->_dec($type, $tresult->{output}));
			if($rc) {
				unlink $obj;
				__append_result($result, 'error', sprintf("CCF: Adjujstment of obj prior to link failed by status: 0x%04X\n", $rc));
				return cv_unit($rc, $result);
			}
			undef $tresult;
			my $out = __mktemp('.exe');
			return run_cmd($self->_make_arg($type, 'link', $obj, $out, \$tresult))->map(sub {
				my $rc = shift;
				$tresult = $self->_recover_result($type, $tresult);
				__append_result($result, 'output', $self->_dec($type, $tresult));
				if($rc) {
					unlink $obj;
					__append_result($result, 'error', sprintf("CCF: link failed by status: 0x%04X\n", $rc));
					return ($rc, $result);
				}
				unlink $obj;
				chmod 0711, $out if $self->_is_cygwin2native($type);
				return ($rc, $result, $out);
			});
		});
	});
}

# External I/F for execution
sub execute
{
	my ($self, $type, $out) = @_;
	my ($result, $tresult) = {};

	return run_cmd($self->_make_arg($type, 'execute', $out, undef, \$tresult))->map(sub {
		my $rc = shift;
		$result->{output} = $self->_recover_result($type, $tresult);
		if($rc) {
			__append_error($result, sprintf("CCF: exit with non-zero status: 0x%04X\n", $rc));
		}
		unlink $out;
		return ($rc, $result);
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
