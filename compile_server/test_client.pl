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

$handle->push_write(json => {type=>'gcc45',execute=>'true',source=><<'EOF'});
#include <iostream>

int main(void)
{
	int n;
	std::cout << "Run: " << __GNUC__ << '.' << __GNUC_MINOR__ << '.' << __GNUC_PATCHLEVEL__ << std::endl;
#ifdef __GXX_EXPERIMENTAL_CXX0X__
	std::cout << "     with C++0X mode" << std::endl;
#endif
	return 0;
}
EOF

$cv->recv;
