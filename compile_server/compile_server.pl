#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket; # tcp_server
use AnyEvent::Util; # run_cmd

use English;
use YAML;
use Getopt::Std;
use Pod::Usage;

use CCF::IDCounter;
use CCF::Invoker;

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
getopts('hp:c:k:iI:vd', \%opts);
pod2usage(-verbose => 1) if exists $opts{h};
my $confname = $opts{c} // 'config.yaml';
! -f $confname and pod2usage(-msg => "\n$0: ERROR: Configuration file `$confname' does not exist.\n", -exitval => 1, -verbose => 0);
my $conf = YAML::LoadFile($confname);
my $confkey = $opts{k} // $OSNAME;
! exists $conf->{$confkey} and pod2usage(-msg => "\n$0: ERROR: Configuration key `$confkey' does not exist in configuration file.\n", -exitval => 1, -verbose => 0);
my $port = $opts{p} // 8888;
$conf = $conf->{$confkey};
my $invoker = CCF::Invoker->new(config => $conf, verbose => $opts{v}, debug => $opts{d});

my %status;
my $id = 0;
tie $id, 'CCF::IDCounter', file => 'id.yaml', key => $confkey if ! exists $opts{i};
$id = $opts{I} if exists $opts{I};

sub invoke
{
	my ($handle, $obj) = @_;

	my $curid = $id++;

	$status{$curid}{status} = REQUESTED;
	$handle->push_write(storable => { id => $curid });
# TODO: Other sanity check
	if(!exists $obj->{type} || !exists $conf->{$obj->{type}}) {
		$status{$curid}{status} = FINISHED;
		$status{$curid}{compile} = 'CCF: Unknown compiler type.';
		return;
	}
	if(exists $obj->{source} && length $obj->{source} > 10 * 1024) {
		$status{$curid}{status} = FINISHED;
		$status{$curid}{compile} = 'CCF: Source size is over 10KiB.';
		return;
	}

	$status{$curid}{status} = COMPILING;
	if($obj->{execute} eq 'true') {
		$invoker->link($obj->{type}, $obj->{source}, sub {
			my ($rc, $result, $out) = @_;
			$opts{v} and print STDERR "---compile begin---\n$result---compile  end ---\n";
			$status{$curid}{compile} = $result;
			if($rc) {
				$status{$curid}{status} = FINISHED;
			} else {
				$status{$curid}{status} = RUNNING;
				$invoker->execute($obj->{type}, $out, sub{
					my ($rc, $result) = @_;
					if(length $result > 10 * 1024) {
						$result = substr $result, 0, 10 * 1024;
						$result .= 'CCF: Output size is over 10KiB.';
					}
					$opts{v} and print STDERR "---execute begin---\n$result---execute  end ---\n";
					$status{$curid}{execute} = $result;
					unlink $out;
					$status{$curid}{status} = FINISHED;
				});
			}
		});
	} else {
		$invoker->compile($obj->{type}, $obj->{source}, sub {
			my ($rc, $result) = @_;
			$opts{v} and print STDERR "---compile begin---\n$result---compile  end ---\n";
			$status{$curid}{compile} = $result;
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

	$handle->push_write(storable => { map { $_ => $conf->{$_}{name} } grep { $_ ne 'GLOBAL' } keys %$conf });
}

my %handler = (
	invoke => \&invoke,
	status => \&status,
	result => \&result,
	list => \&list,
);

$opts{v} and print STDERR "listening on port $port...\n";
tcp_server undef, $port, sub {
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

compile_server.pl [-h] [-p I<port>] [-c I<filename>] [-k I<key>] [-i] [-I I<number>] [-v] [-d]

  # show help (this POD) and exit
  compile_server.pl -h
  
  # read configuration from config.yaml and $OSNAME is used for configuration key
  compile_server.pl
  
  # read configuration from conf.yaml and cygwin-test is used for configuration key
  compile_server.pl -c conf.yaml -k cygwin-test

  # don't use persistent ID management and set initial ID as 10
  compile_server.pl -i -I 10

  # listen on port 8880 with logging
  compile_server.pl -p 8880 -v -d

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

=item -i

Don't use persistent ID management.

=item -I I<number>

Set initial ID as the specified number. Defaults to the value read from persistent ID if -i is not specified. Otherwise, defaults to 0.

=item -v

Enable verbose logging.

=item -d

Enable debug logging.

=back

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
