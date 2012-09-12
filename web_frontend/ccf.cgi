#!/usr/bin/perl

use strict;
use warnings;
use feature 'switch';

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

if($command eq 'show') {
	my $id = $q->param('id');
	$handle->push_write(json => { command => 'status', id => $id });
	$handle->push_read(json => sub {
		my ($handle, $json) = @_;
		my $html;
		my $status = $json->{status};
		given($status) {
			when (1)     { $html = "<html><body>Invoked.</body></html>"; }
			when (2)     { $html = "<html><body>Compiling.</body></html>"; }
			when ([3,4]) {
				$handle->push_write(json => { command => 'result', id => $id });
				$handle->push_read(json => sub {
					my ($handle, $json) = @_;
					print $q->header(-type => 'text/html', -charset => 'utf-8');
# TODO: HTML escape
# TODO: Apply CSS
					if($status == 3 || ! exists $json->{execute}) {
						my $compile = $json->{compile};
						$compile = '&nbsp;' if $compile eq '';
						print <<EOF;
<html><body><p>Compiled.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre></body></html>
EOF
					} else {
						my $compile = $json->{compile};
						$compile = '&nbsp;' if $compile eq '';
						my $execute = $json->{execute};
						$execute = '&nbsp;' if $execute eq '';
						print <<EOF;
<html><body><p>Executed.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre><p>execution result:</p><pre style="background:#fff;">$execute</pre></body></html>
EOF
					}
					$cv->send;
				});
			}
		}
		if(defined $html) {
			print $q->header(-type => 'text/html', -charset => 'utf-8');
			print $html;
			$cv->send;
		}
	});
} else {
	my (@names) = $q->param;
	$handle->push_write(json => { map { $_, $q->param($_) } @names });
	$handle->push_read(json => sub {
		my ($handle_, $json) = @_;
		print $q->header(-type => 'application/json', -charset => 'utf-8');
		print encode_json $json;
		$cv->send;
	});
}

$cv->recv;
