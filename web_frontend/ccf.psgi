#!/usr/bin/env plackup

use lib qw(../lib);

use Plack::Builder;
use Plack::App::File;
use CCF;

use YAML;

my $conf = YAML::LoadFile('config.yaml');
my $app = CCF->new(bucket => $conf->{bucket}, backend => $conf->{backend})->to_app;

builder {
	mount '/ccf.cgi' => $app;
	mount '/result' => $app;
	mount '/results' => $app;
	mount '/' => Plack::App::File->new(root => './static')->to_app;
};
__END__

=head1 NAME

ccf.psgi - .psgi configuration for C++ Compiler Farm

=head1 SYNOPSIS

  plackup ./ccf.psgi

=head1 DESCRIPTION

ccf.psgi is a .psgi configuration for C++ Compiler Farm.
Configutaion is read from F<config.yaml>.

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
