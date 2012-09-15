#!/usr/bin/env plackup

use Plack::Builder;
use Plack::App::WrapCGI;
use Plack::App::File;
use CCF;

builder {
# Because recursive AnyEvent is prohibited, execute option is required
	mount '/ccf.cgi' => CCF->new;
	mount '/' => Plack::App::File->new(root => './static');
};
