#!/usr/bin/perl
#
#   check.pl: Check the maximum valid ID
#
#   Written by Yak! <yak_ex@mx.scn.tv>
#
#   Distributed under the terms of Boost Software License, Version 1.0, August 17th, 2003
#   See http://www.boost.org/LICENSE_1_0.txt
#
#   $Id$
#

use lib qw(../lib);
use strict;
use warnings;

use Getopt::Std;
use Pod::Usage;

use YAML::Any;
use List::Util qw(max);

use CCF::Storage;

my %opts;
getopts('hd:b:m:', \%opts);
pod2usage(-verbosity => 2) if exists $opts{h};
my $dir = $opts{d} || '../web_frontend';

my $maxid = $opts{m} // YAML::Any::LoadFile($dir.'/id2.yaml')->{request} - 1;
my $bucket = $opts{b} // YAML::Any::LoadFile($dir.'/config.yaml')->{bucket};

my $storage = CCF::Storage->new(bucket => $bucket);

my ($maxreq, $maxcomp);

while(1) {
	my $dat = $storage->get_requests_async($maxid, 5)->recv;
	if(@$dat) {
		$maxreq = max map { $_->[0] } @$dat;
		$maxcomp = max map { values %{$_->[2]{keys}} } @$dat;
		last;
	} else {
		$maxid -= 5;
	}
}

print <<EOF;
maxreq: $maxreq
maxcomp: $maxcomp
EOF

__END__

=head1 NAME

migrate.pl - Migrate S3 schema to separate error messages

=head1 SYNOPSIS

  # ../web_frontend is assumed without argument
  perl migrate.pl

  # explict folder specification
  perl migrate.pl -d ../web_frontend

=head1 DESCRIPTION

Migrate S3 schema from plain text to hash with keys of output and error.

=cut
