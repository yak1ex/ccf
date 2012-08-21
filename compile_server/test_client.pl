#!/usr/bin/perl
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

my $cv = AnyEvent->condvar;

my $handle = AnyEvent::Handle->new(
	connect => ['127.0.0.1', 8888],
	on_drain => sub { $cv->send },
);

$handle->push_write(json => {type=>'gcc46-c++11',execute=>'true',source=><<'EOF'});
#include <iostream>

int main(void)
{
	std::cout << "Run" << std::endl;
	return 0;
}
EOF

$cv->recv;
