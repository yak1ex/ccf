#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use CGI;
use JSON;

# TODO: Error check

my $q = CGI->new;

my $command = $q->param('command');

my $cv = AnyEvent->condvar;

my $handle; $handle = AnyEvent::Handle->new(
	connect => ['127.0.0.1', 8888],
	on_error => sub { undef $handle },
);

my (@names) = $q->param;
$handle->push_write(json => { map { $_, $q->param($_) } @names });
$handle->push_read(json => sub {
	my ($handle_, $json) = @_;
	print $q->header(-type => 'application/json', -charset => 'utf-8');
	print encode_json $json;
	$cv->send;
});

$cv->recv;
