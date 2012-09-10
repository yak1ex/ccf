#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket; # tcp_server
use AnyEvent::Util; # run_cmd

use YAML;
use File::Temp;

# TODO: compiler configuration
# TODO: output capture
# TODO: command/response implementation (compile/status/result)

my $conf = YAML::LoadFile('config.yaml');

sub make_cl
{
	my ($type, $mode, $input, $output) = @_;

# TODO: error check
	return map { $_ eq '$input' ? $input : $_ eq '$output' ?  $output : $_ } @{$conf->{$type}{$mode}};
}

tcp_server '127.0.0.1', 8888, sub {
	my ($fh, $host, $port) = @_;

	print "connect\n";

	my $handle; $handle = AnyEvent::Handle->new(
		fh => $fh,
		on_eof => sub { $handle->destroy; },
		on_error => sub { $handle->destroy; },
	);
	my @handler; @handler = (json => sub {
		print "handler\n";
		my ($handle, $json) = @_;

		my $fh = File::Temp->new(UNLINK=>0,SUFFIX=>'.cpp');
		print $fh $json->{source};
		close $fh;
		my $source = $fh->filename;
		my $fho = File::Temp->new(UNLINK=>0,SUFFIX=>($json->{execute} eq 'true' ? '.exe' : '.o'));
		close $fho;
		my $out = $fho->filename;

		if($json->{execute} eq 'true') {
			run_cmd([make_cl($json->{type}, 'link', $source, $out)])->cb(sub {
				run_cmd([$out])->cb(sub{
					unlink $out;
					unlink $source;
				});
			});
		} else {
			run_cmd([make_cl($json->{type}, 'compile', $source, $out)])->cb(sub {
				unlink $out;
				unlink $source;
			});
		}

		$handle->push_read(@handler);
	});
	$handle->push_read(@handler);
};

AnyEvent->condvar->recv;
