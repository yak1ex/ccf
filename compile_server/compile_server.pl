#!/usr/bin/perl

use FindBin;
use lib "${FindBin::Bin}/../lib";

use strict;
use warnings;

use AnyEvent;
use Data::Monad::CondVar;
use AnyEvent::Handle;
use AnyEvent::Socket; # tcp_server
use AnyEvent::Util; # run_cmd
use AnyEvent::Net::Amazon::S3::Client;

use English;
use YAML;
use Getopt::Std;
use Pod::Usage;
use Socket ();

use CCF::Invoker;
use CCF::Storage;

use constant {
	REQUESTED => 1,
	COMPILING => 2,
	RUNNING => 3,
	FINISHED => 4,
};

our ($VERSION) = '0.01';

#
# Init
#

my %opts;
$Getopt::Std::STANDARD_HELP_VERSION = 1;
getopts('hp:c:k:vd', \%opts);
pod2usage(-verbose => 1) if exists $opts{h};
my $confname = $opts{c} // 'config.yaml';
! -f $confname and pod2usage(-msg => "\n$0: ERROR: Configuration file `$confname' does not exist.\n", -exitval => 1, -verbose => 0);
my $conf = YAML::LoadFile($confname);
my $bucketname = $conf->{GLOBAL}{bucket};
my $confkey = $opts{k} // $OSNAME;
! exists $conf->{$confkey} and pod2usage(-msg => "\n$0: ERROR: Configuration key `$confkey' does not exist in configuration file.\n", -exitval => 1, -verbose => 0);
my $port = $opts{p} // 8888;
$conf = $conf->{$confkey};
my $invoker = CCF::Invoker->new(config => $conf, verbose => $opts{v}, debug => $opts{d});

my $storage = CCF::Storage->new(
	bucket => $bucketname,
	root => delete $ENV{CCF_STORAGE_DUMMY_ROOT},
	aws_access_key_id => delete $ENV{AWS_ACCESS_KEY_ID},
	aws_secret_access_key => delete $ENV{AWS_ACCESS_KEY_SECRET},
);

sub tracemsg
{
	my ($type, $result) = @_;
	my $output = $result->{output} || '';
	my $error = $result->{error} || '';
	return "---$type begin---\n$output$error---$type  end ---\n";
}

sub invoke
{
	my ($handle, $obj) = @_;

	my $curid = $obj->{id};

	my ($myport, $myaddr) = Socket::sockaddr_in(getsockname($handle->fh));
	$myaddr = format_address($myaddr);
	$storage->update_compile_stat_async($curid, {
		id => $curid,
		addr => $myaddr,
		port => $myport,
	});

	my $cv = $storage->update_compile_status_async($curid, {
		id => $curid,
		status => REQUESTED,
	});
	$handle->push_write(storable => { id => $curid });
# TODO: Other sanity check
	if(!exists $obj->{type} || !exists $conf->{$obj->{type}}) {
		$cv->flat_map(sub {
			$storage->update_compile_status_async($curid, {
				status => FINISHED,
				compile => { error => 'CCF: Unknown compiler type.' },
			})
		});
		return;
	}
	if(exists $obj->{source} && length $obj->{source} > 10 * 1024) {
		$cv->flat_map(sub {
			$storage->update_compile_status_async($curid, {
				status => FINISHED,
				compile => { error => 'CCF: Source size is over 10KiB.' },
			})
		});
		return;
	}

	$cv = $cv->flat_map(sub {
		$storage->update_compile_status_async($curid, {
			status => COMPILING
		})
	});
	if($obj->{execute} eq 'true') {
		$invoker->link($obj->{type}, $obj->{source})->cb(sub {
			my ($rc, $result, $out) = shift->recv;
			if(length $result->{output} > 10 * 1024) {
				$result->{output} = substr($result->{output}, 0, 10 * 1024)."...\n";
				$result->{error} = '' if ! exists $result->{error};
				$result->{error} .= 'CCF: Output size is over 10KiB.';
			}
			$opts{v} and print STDERR tracemsg('compile', $result);
			if($rc) {
				$cv->flat_map(sub {
					$storage->update_compile_status_async($curid, {
						status => FINISHED,
						compile => $result,
					})
				});
				return;
			} else {
				$cv = $cv->flat_map(sub {
					$storage->update_compile_status_async($curid, {
						status => RUNNING,
						compile => $result,
					})
				});
				$invoker->execute($obj->{type}, $out)->cb(sub{
					my ($rc, $result) = shift->recv;
					if(length $result->{output} > 10 * 1024) {
						$result->{output} = substr($result->{output}, 0, 10 * 1024)."...\n";
						$result->{error} = '' if ! exists $result->{error};
						$result->{error} .= 'CCF: Output size is over 10KiB.';
					}
					$opts{v} and print STDERR tracemsg('execute', $result);
					unlink $out;
					$cv->flat_map(sub {
						$storage->update_compile_status_async($curid, {
							status => FINISHED,
							execute => $result,
						});
					});
				});
			}
		});
	} else {
		$invoker->compile($obj->{type}, $obj->{source})->cb(sub {
			my ($rc, $result) = shift->recv;
			if(length $result->{output} > 10 * 1024) {
				$result->{output} = substr($result->{output}, 0, 10 * 1024)."...\n";
				$result->{error} = '' if ! exists $result->{error};
				$result->{error} .= 'CCF: Output size is over 10KiB.';
			}
			$opts{v} and print STDERR tracemsg('compile', $result);
			$cv->flat_map(sub {
				$storage->update_compile_status_async($curid, {
					status => FINISHED,
					compile => $result,
				});
			});
		});
	}
}

sub status
{
	my ($handle, $obj) = @_;

# TODO: check unknown ID
	$storage->get_compile_status_async($obj->{id})->cb(sub {
		my $status = shift->recv;
		$status = { status => 0 } if ! defined $status;
		$handle->push_write(storable => { id => $obj->{id}, status => $status->{status} });
	});
}

sub result
{
	my ($handle, $obj) = @_;

	$storage->get_compile_status_async($obj->{id})->cb(sub {
		my $status = shift->recv;
		if(exists $status->{execute}) {
			$handle->push_write(storable => { id => $obj->{id}, execute => $status->{execute}, compile => $status->{compile} });
		} else {
			$handle->push_write(storable => { id => $obj->{id}, compile => $status->{compile} });
		}
	});
}

sub list
{
	my ($handle, $obj) = @_;

	$handle->push_write(storable => { map { $_ => [ $conf->{$_}{name}, $conf->{$_}{'c++11'}, $conf->{$_}{'c++1y'} ] } grep { $_ ne 'GLOBAL' } keys %$conf });
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

	my ($myport, $myaddr) = Socket::sockaddr_in(getsockname($fh));
	$myaddr = format_address($myaddr);
#	$opts{v} and print STDERR "connect with ${myaddr}:${myport} from ${host}:${port}\n";

	my $handle; $handle = AnyEvent::Handle->new(
		fh => $fh,
		on_eof => sub { AE::log debug => 'on_eof called in compile_server'; $handle->destroy },
		on_error => sub { warn "on_error called by $_[2] in compile_server"; $handle->destroy; },
	);
	$handle->on_read(sub {
		my ($handle) = @_;
		$handle->push_read(storable => sub {
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
		});
	});
};

AnyEvent->condvar->recv;

__END__

=head1 NAME

compile_server.pl - Compile server for C++ Compiler Farm

=head1 SYNOPSIS

compile_server.pl [-h] [-p I<port>] [-c I<filename>] [-k I<key>] [-i] [-I I<number>] [-r I<interval>:I<count>] [-v] [-d]

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
