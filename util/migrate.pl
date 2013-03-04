#!/usr/bin/perl
#
#   migrate.pl: Migrate S3 schema to separate error messages
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

use CCF::S3Storage;
use CCF::S3Storage::Dummy;

my %opts;
getopts('hd:', \%opts);
pod2usage(-verbosity => 2) if exists $opts{h};
my $dir = $opts{d} || '../web_frontend';

my $conf = YAML::Any::LoadFile($dir.'/config.yaml');
my $maxid = YAML::Any::LoadFile($dir.'/id.yaml')->{compile} - 1;

my $storage = exists $ENV{CCF_S3_DUMMY_ROOT} ?
	CCF::S3Storage::Dummy->new(bucket => $conf->{bucket}) :
	CCF::S3Storage->new(bucket => $conf->{bucket});

print STDERR 'converting...';
foreach my $id (0..$maxid) {
	my $dat = $storage->get_compile_status_async($id)->recv;
	last if ref $dat->{compile}|| ref $dat->{execute};
	foreach my $key (qw(compile execute)) {
		if(exists $dat->{$key}) {
			my $error;
			$error .= $1 while $dat->{$key} =~ s/^(CCF:.*(?:\n|$))//m;
			$dat->{$key} = { output => $dat->{$key} };
			$dat->{$key}{error} = $error if defined $error;
		}
	}
	$storage->update_compile_status_async($id, $dat)->recv;
	print STDERR "$id,";
}
print STDERR "\n";

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
