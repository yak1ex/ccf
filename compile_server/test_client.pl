#!/usr/bin/perl
use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Getopt::Std;

# TODO: type should be checked with configuration

sub usage
{
	print "\n$_[0]\n" if defined $_[0];
	print <<EOF;

test_client.pl [option]

Test client for compile server

option:
	-h: Show this help
	-t <type>: Target type (required)
	-c: compile only
	-l: List types from configuration file
	-v: Verbose

EOF

	exit;
}

my %opts;
getopts('ht:clv', \%opts);

usage if exists $opts{h};
if(exists $opts{l}) {
	use English;
	use YAML;
	print "List all types in this environment:\n";
	my $conf = YAML::LoadFile('config.yaml');
	foreach my $key (sort keys %{$conf->{$OSNAME}}) {
		if($key ne 'GLOBAL') {
			print "\t$key\n";
		}
	}
	exit;
}
usage('-t option must be specified.') if ! exists $opts{t};

my $cv = AnyEvent->condvar;

my $handle = AnyEvent::Handle->new(
	connect => ['127.0.0.1', 8888],
#	on_drain => sub { $cv->send },
);

$handle->push_write(json => {command=>'invoke',type=>$opts{t},execute=>(exists $opts{c} ? 'false' : 'true'),source=><<'EOF'});
#include <iostream>

int main(void)
{
	int n;
#ifdef _MSC_VER
	std::cout << "Run: MSVC cl " << _MSC_VER << std::endl;
#else
#ifdef __clang__
	std::cout << "Run: Clang " << __clang_major__ << '.' << __clang_minor__ << '.' << __clang_patchlevel__ << " faked as GCC " << __GNUC__ << '.' << __GNUC_MINOR__ << '.' << __GNUC_PATCHLEVEL__ << std::endl;
#else
	std::cout << "Run: GCC " << __GNUC__ << '.' << __GNUC_MINOR__ << '.' << __GNUC_PATCHLEVEL__ << std::endl;
#endif
#ifdef __GXX_EXPERIMENTAL_CXX0X__
	std::cout << "     with C++0X mode" << std::endl;
#endif
#endif
	return 0;
}
EOF
my $is_compile_output = 0;
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
					print "---compile---\n$json->{compile}---compile---\n" if $is_compile_output == 0;
					print "---execute---\n$json->{execute}---execute---\n";
					$cv->send;
				});
			} elsif($json->{status} == 3 && $is_compile_output == 0) {
				$is_compile_output = 1;
				$handle->push_write(json => {command=>'result',id=>$json->{id}});
				$handle->push_read(json => sub {
					my ($handle, $json) = @_;
					print "---compile---\n$json->{compile}---compile---\n";
					$handle->push_write(json => {command=>'status',id=>$json->{id}});
					$handle->push_read(@handler);
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
