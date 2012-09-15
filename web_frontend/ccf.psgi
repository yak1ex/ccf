#!/usr/bin/env plackup
use Plack::Builder;
use Plack::App::WrapCGI;
use Plack::App::File;

builder {
# Because recursive AnyEvent is prohibited, execute option is required
	mount '/ccf.cgi' => Plack::App::WrapCGI->new(script => "./ccf.cgi", execute => 1);
	mount '/' => Plack::App::File->new(root => './static');
};
