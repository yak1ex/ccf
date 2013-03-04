#!/usr/bin/env plackup

use strict;
use warnings;

use Plack::Builder;
use Plack::App::File;

use Data::Section qw(-setup);

my $app = sub {
	return [503, ['Content-Type' => 'text/html'], [${__PACKAGE__->section_data('template')}]];
};

builder {
	mount '/ccf.cgi' => $app;
	mount '/ccf.html' => $app;
	mount '/result' => $app;
	mount '/results' => $app;
	mount '/' => Plack::App::File->new(root => './static');
};
__DATA__
__[template]__
<!DOCTYPE html>
 <html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link href="/ccf.css" rel="stylesheet" type="text/css">
<link rel="shortcut icon" href="/favicon.ico" type="image/vnd.microsoft.icon" />
<link rel="icon" href="/favicon.ico" type="image/vnd.microsoft.icon" />
<title>C++ Compiler Farm</title>
</head>
<body>
<div id="header">
<img src="/ccf.png" alt="C++ Compiler Farm" title="C++ Compiler Farm" />
<p id="owner-notice">ownered by <a href="http://twitter.com/yak_ex">@yak_ex</a></p>
<p id="menu">
<img src="/home.png" alt="Home" title="Home" />
<img src="/recent.png" alt="Recent" title="Recent" />
<a href="/FAQ.html"><img src="/FAQ.png" alt="FAQ" title="FAQ" /></a>
</p>
</div>
<p style="font-size: 20px; font-weight: bold">C++ Compiler Farm is now maintained. Please try again later...</p>
</body>
</html>
__END__

=head1 NAME

ccf.psgi - .psgi configuration for C++ Compiler Farm in maintenance mode

=head1 SYNOPSIS

  plackup ./maintain.psgi

=head1 DESCRIPTION

maintain.psgi is a .psgi configuration for C++ Compiler Farm in maintenance mode.
Static files are served as they are. PSGI appliation is fallback-ed to a static HTML.

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
