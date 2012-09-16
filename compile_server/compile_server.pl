#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket; # tcp_server
use AnyEvent::Util; # run_cmd

use English;
use YAML;
use File::Temp;
use Getopt::Std;
use Pod::Usage;

BEGIN {
	if($^O eq 'cygwin') {
		use Encode;
		use Win32::Codepage::Simple qw(get_codepage);
	}
}

use constant {
	REQUESTED => 1,
	COMPILING => 2,
	RUNNING => 3,
	FINISHED => 4,
};

our ($VERSION) = '0.01';

# TODO: clear command
# TODO: FINISHED reaper
# TODO: Optional log
# TODO: Using sandbox

#
# Init
#

my %opts;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
getopts('hp:c:k:v', \%opts);
pod2usage(-verbose => 1) if exists $opts{h};
my $confname = $opts{c} // 'config.yaml';
! -f $confname and pod2usage(-msg => "\n$0: ERROR: Configuration file `$confname' does not exist.\n", -exitval => 1, -verbose => 0);
my $conf = YAML::LoadFile($confname);
my $confkey = $opts{k} // $OSNAME;
! exists $conf->{$confkey} and pod2usage(-msg => "\n$0: ERROR: Configuration key `$confkey' does not exist in configuration file.\n", -exitval => 1, -verbose => 0);
my $port = $opts{p} // 8888;

# TODO: Separate cygwin2native handling to module?

sub is_cygwin2native
{
	my ($type) = @_;
	return exists $conf->{$OSNAME}{$type}{cygwin2native} && $conf->{$OSNAME}{$type}{cygwin2native} eq 'true';
}

sub setenv
{
	my ($type) = @_;

	return sub {
		foreach my $hash (@{$conf->{$OSNAME}{$type}{env}}) {
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

sub make_arg
{
	my ($type, $mode, $input, $output, $capture) = @_;
	my @arg;
	if(is_cygwin2native($type)) {
		$input = Cygwin::posix_to_win_path($input);
		$output = Cygwin::posix_to_win_path($output);
		(@arg) = (on_prepare => setenv($type)) if exists($conf->{$OSNAME}{$type}{env});
	}

# TODO: error check
#	return map { $_ eq '$input' ? $input : $_ eq '$output' ?  $output : $_ } @{$conf->{$OSNAME}{$type}{$mode}};
	my @res = map { my $t = $_; $t =~ s/\$input/$input/; $t =~ s/\$output/$output/; $t; } @{$conf->{$OSNAME}{$type}{$mode}}; 
	$opts{v} and print STDERR join(' ', @res), "\n";
	return ([@res], '<', '/dev/null', '>', $capture, '2>', $capture, @arg);
}

sub dec
{
	my ($type, $str) = @_;
	return Encode::decode_utf8($str) unless is_cygwin2native($type);
	return Encode::decode('CP'.get_codepage(), $str);
}

my %status;
my $id = 0;

sub invoke
{
	my ($handle, $obj) = @_;

	my $curid = $id++;

	$status{$curid}{status} = REQUESTED;
	$handle->push_write(storable => { id => $curid });
# TODO: Other sanity check
	if(!exists $obj->{type} || !exists $conf->{$OSNAME}{$obj->{type}}) {
		$status{$curid}{status} = FINISHED;
		$status{$curid}{compile} = 'CCF: Unknown compiler type.';
		return;
	}
	if(exists $obj->{source} && length $obj->{source} > 10 * 1024) {
		$status{$curid}{status} = FINISHED;
		$status{$curid}{compile} = 'CCF: Source size is over 10KiB.';
		return;
	}

	my $fh = File::Temp->new(UNLINK=>0,SUFFIX=>'.cpp');
	print $fh $obj->{source};
	close $fh;
	my $source = $fh->filename;
	my $fho = File::Temp->new(UNLINK=>0,SUFFIX=>($obj->{execute} eq 'true' ? '.exe' : '.o'));
	close $fho;
	my $out = $fho->filename;

	$status{$curid}{status} = COMPILING;
	if($obj->{execute} eq 'true') {
		run_cmd(make_arg($obj->{type}, 'link', $source, $out, \$status{$curid}{compile}))->cb(sub {
			my $rc = shift->recv;
			$status{$curid}{compile} = dec($obj->{type}, $status{$curid}{compile});
			if($rc) {
				$status{$curid}{compile} .= sprintf "CCF: compilation failed by status: 0x%04X\n", $rc;
			}
			$opts{v} and print STDERR "---compile begin---\n$status{$curid}{compile}---compile  end ---\n";
			if($rc) {
				$status{$curid}{status} = FINISHED;
			} else {
				$status{$curid}{status} = RUNNING;
				chmod 0711, $out if is_cygwin2native($obj->{type});
				run_cmd([$out], '<', '/dev/null', '>', \$status{$curid}{execute}, '2>', \$status{$curid}{execute})->cb(sub{
					my $rc = shift->recv;
					if($rc) {
						$status{$curid}{execute} .= sprintf "CCF: execution failed by status: 0x%04X\n", $rc;
					}
					$opts{v} and print STDERR "---execute begin---\n$status{$curid}{execute}---execute  end ---\n";
					unlink $out;
					unlink $source;
					$status{$curid}{status} = FINISHED;
				});
			}
		});
	} else {
		run_cmd(make_arg($obj->{type}, 'compile', $source, $out, \$status{$curid}{compile}))->cb(sub {
			my $rc = shift->recv;
			$status{$curid}{compile} = dec($obj->{type}, $status{$curid}{compile});
			if($rc) {
				$status{$curid}{compile} .= sprintf "CCF: compilation failed by status: 0x%04X\n", $rc;
			}
			$opts{v} and print STDERR "---compile begin---\n$status{$curid}{compile}---compile  end ---\n";
			unlink $out;
			unlink $source;
			$status{$curid}{status} = FINISHED;
		});
	}
}

sub status
{
	my ($handle, $obj) = @_;

# TODO: check unknown ID
	$handle->push_write(storable => { id => $obj->{id}, status => $status{$obj->{id}}{status} });
}

sub result
{
	my ($handle, $obj) = @_;

	if(exists $status{$obj->{id}}{execute}) {
		$handle->push_write(storable => { id => $obj->{id}, execute => $status{$obj->{id}}{execute}, compile => $status{$obj->{id}}{compile} });
	} else {
		$handle->push_write(storable => { id => $obj->{id}, compile => $status{$obj->{id}}{compile} });
	}
}

sub list
{
	my ($handle, $obj) = @_;

	$handle->push_write(storable => { map { $_ => $conf->{$OSNAME}{$_}{name} } grep { $_ ne 'GLOBAL' } keys %{$conf->{$OSNAME}} });
}

my %handler = (
	invoke => \&invoke,
	status => \&status,
	result => \&result,
	list => \&list,
);

$opts{v} and print STDERR "listening on port $port...\n";
tcp_server '127.0.0.1', $port, sub {
	my ($fh, $host, $port) = @_;

	$opts{v} and print STDERR "connect\n";

	my $handle; $handle = AnyEvent::Handle->new(
		fh => $fh,
		on_eof => sub { $handle->destroy; },
		on_error => sub { $handle->destroy; },
	);
	my @handler; @handler = (storable => sub {
		my ($handle, $obj) = @_;
		if(exists $obj->{command} && exists $handler{$obj->{command}}) {
			$opts{v} and print STDERR "handler called by command `$obj->{command}'.\n";
			$handler{$obj->{command}}->($handle, $obj);
		} else {
			my $command = '';
			$command = $obj->{command} if exists $obj->{command};
			$command = "Unknown command `$command'";
			warn $command;
			$handle->push_write(storable => { error => $command });
		}
		$handle->push_read(@handler);
	});
	$handle->push_read(@handler);
};

AnyEvent->condvar->recv;

__END__

=head1 NAME

compile_server.pl - Compile server for C++ Compiler Farm

=head1 SYNOPSIS

compile_server [-h] [-p I<port>] [-c I<filename>] [-k I<key>] [-v]

  # show help (this POD) and exit
  compile_server.pl -h
  
  # read configuration from config.yaml and $OSNAME is used for configuration key
  compile_server.pl
  
  # read configuration from conf.yaml and cygwin-test is used for configuration key
  compile_server.pl -c conf.yaml -k cygwin-test

  # listen on port 8880 with logging
  compile_server.pl -p 8880 -v

=head1 DESCRIPTION

compile_server.pl is a backend compile server for C++ Compiler Farm.
It accepts source code and return its compilation / execution results.

=head1 OPTIONS

=over 4

=item -h

Show this POD and exit

=item -p I<port>

Listen port. Defaults to 8888.

=item -c I<filename>

Configuration YAML file name. Defaults to config.yaml.

=item -k I<key>

Configuration key. The key must exist in the configuration file.
Defaults to $OSNAME.

=item -v

Enable verbose logging.

=back

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=cut
