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
	}, $class;
}

sub _config
{
	my ($self) = @_;
	return $self->{_config};
}

sub _verbose
{
	my ($self) = @_;
	return exists $self->{_verbose} && $self->{_verbose};
}

sub _is_cygwin2native
{
	my ($self, $type) = @_;
	return exists $self->_config->{$type}{cygwin2native} && $self->_config->{$type}{cygwin2native} eq 'true';
}

sub _prepare_env
{
	my ($self, $type) = @_;

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
				$ENV{$name} = $t;
			}
		}
	};
}

sub _make_arg
{
	my ($self, $type, $mode, $input, $output, $capture) = @_;
	my @arg;
	if($self->_is_cygwin2native($type)) {
		$input = Cygwin::posix_to_win_path($input);
		$output = Cygwin::posix_to_win_path($output);
		(@arg) = (on_prepare => $self->_prepare_env($type)) if exists($self->_config->{$type}{env});
	}

# TODO: error check
	my @res = map { my $t = $_; $t =~ s/\$input/$input/; $t =~ s/\$output/$output/; $t; } @{$self->_config->{$type}{$mode}}; 
	$self->_verbose and print STDERR join(' ', @res), "\n";
	return ([@res], '<', '/dev/null', '>', $capture, '2>', $capture, @arg);
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
		$result = $self->_dec($type, $result);
		if($rc) {
			$result .= sprintf "CCF: compilation failed by status: 0x%04X\n", $rc;
		}
		unlink $obj unless defined $not_unlink;
		unlink $input;
		$callback->($rc, $result, $obj);
	});
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
		my $result2;
		my $out = __mktemp('.exe');

		run_cmd($self->_make_arg($type, 'link', $obj, $out, \$result2))->cb(sub {
			my $rc = shift->recv;
			$result .= $self->_dec($type, $result2);
			if($rc) {
				$result .= sprintf "CCF: link failed by status: 0x%04X\n", $rc;
			}
			unlink $obj;
			chmod 0711, $out if $self->_is_cygwin2native($type);
			$callback->($rc, $result, $out);
		});
	}, 1);
}

sub execute
{
	my ($self, $type, $out, $callback) = @_;
	my $result;

	run_cmd([$out], '<', '/dev/null', '>', \$result, '2>', \$result)->cb(sub{
		my $rc = shift->recv;
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
      memlimit-compile: I<integer>
      memlimit-execute: I<integer>
      cpulimit-compile: I<integer>
      cpulimit-execute: I<integer>
      rtlimit-compile:  I<integer>
      rtlimit-execute:  I<integer>
      sandbox: I<sandbox-type>
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
