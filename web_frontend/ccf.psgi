#!/usr/bin/env plackup

use Plack::Builder;
use Plack::App::WrapCGI;
use Plack::App::File;
use CCF;

use YAML;

my $conf = YAML::LoadFile('config.yaml');

builder {
# Because recursive AnyEvent is prohibited, execute option is required
	mount '/ccf.cgi' => CCF->new(backend => $conf);
	mount '/' => Plack::App::File->new(root => './static');
};
__END__
=head1 NAME

ccf.psgi - .psgi configuration for C++ Compiler Farm

=head1 SYNOPSIS

  plackup ./ccf.psgi

=head1 DESCRIPTION

ccf.psgi is a .psgi configuration for C++ Compiler Farm.

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
