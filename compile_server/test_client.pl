#!/usr/bin/perl
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Data::Dumper;

# TODO: command line option handling
# TODO: type should be extracted from configuration

my $cv = AnyEvent->condvar;

my $handle = AnyEvent::Handle->new(
	connect => ['127.0.0.1', 8888],
#	on_drain => sub { $cv->send },
);

$handle->push_write(json => {command=>'invoke',type=>'gcc45',execute=>'true',source=><<'EOF'});
#include <iostream>
#include <unistd.h>

int main(void)
{
	int n;
	sleep(5);
	std::cout << "Run: " << __GNUC__ << '.' << __GNUC_MINOR__ << '.' << __GNUC_PATCHLEVEL__ << std::endl;
#ifdef __GXX_EXPERIMENTAL_CXX0X__
	std::cout << "     with C++0X mode" << std::endl;
#endif
	return 0;
}
EOF
$handle->push_read(json => sub {
	my ($handle, $json) = @_;
	print "ID $json->{id}\n";
	$handle->push_write(json => {command=>'status',id=>$json->{id}});
	my @handler; @handler = (
		json => sub {
			my ($handle, $json) = @_;
			if($json->{status} == 4) {
				$handle->push_write(json => {command=>'result',id=>$json->{id}});
				$handle->push_read(json => sub {
					my ($handle, $json) = @_;
					print Data::Dumper->Dump([$json]);
					$cv->send;
				});
			} else {
				# TODO: async
				print "ID $json->{id} $json->{status}\n";
				sleep 1;
				$handle->push_write(json => {command=>'status',id=>$json->{id}});
				$handle->push_read(@handler);
			}
		}
	);
	$handle->push_read(@handler);
});

$cv->recv;
