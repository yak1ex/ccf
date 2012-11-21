package CCF;

use strict;
use warnings;
use feature 'switch';

use parent qw(Plack::Component);
use CGI::PSGI;
use Plack::Util;

use AnyEvent;
use AnyEvent::Handle;

use JSON;
use Encode qw(decode);

use CCF::Dispatcher;
use CCF::Base64Like;
use CCF::IDCounter;
use CCF::S3Storage;
use CCF::S3Storage::Dummy;

# TODO: Error check

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;

	my $id = 0;
	tie $id, 'CCF::IDCounter', file => 'id.yaml', key => 'compile';
	my $rid = 0;
# TODO: share idcounter file between different keys
	tie $rid, 'CCF::IDCounter', file => 'id2.yaml', key => 'request';

	return bless {
		_DISPATCHER => CCF::Dispatcher->new(backend => $arg{backend}),
		_STORAGE => exists $ENV{CCF_S3_DUMMY_ROOT} ?
			CCF::S3Storage::Dummy->new(bucket => $arg{bucket}) :
			CCF::S3Storage->new(bucket => $arg{bucket}),
		_ID => \$id,
		_RID => \$rid,
	}, $class;
}

sub dispatcher
{
	my ($self) = @_;
	return $self->{_DISPATCHER};
}

sub storage
{
	my ($self) = @_;
	return $self->{_STORAGE};
}

sub id
{
	my ($self) = @_;
	return $self->{_ID};
}

sub req_id
{
	my ($self) = @_;
	return $self->{_RID};
}

sub _show
{
	my ($self, $obj, $responders) = @_;

	my $id = $obj->{id};
	$self->storage->get_compile_status_async($id)->cb(sub {
		my $obj = shift->recv;
		my $html;
		my $status = $obj->{status};
		given($status) {
			when (1)     { $responders->{html}('<html><body>Invoked.</body></html>'); }
			when (2)     { $responders->{html}('<html><body>Compiling.</body></html>'); }
			when ([3,4]) {
# TODO: HTML escape
# TODO: Apply CSS
				if($status == 3 || ! exists $obj->{execute}) {
					my $compile = $obj->{compile};
					$compile = '&nbsp;' if $compile eq '';
					$responders->{html}(<<EOF);
<html><body><p>Compiled.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre></body></html>
EOF
				} else {
					my $compile = $obj->{compile};
					$compile = '&nbsp;' if $compile eq '';
					my $execute = $obj->{execute};
					$execute = '&nbsp;' if $execute eq '';
					$responders->{html}(<<EOF);
<html><body><p>Executed.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre><p>execution result:</p><pre style="background:#fff;">$execute</pre></body></html>
EOF
				}
			}
		}
	});
}

sub _status
{
	my ($self, $obj, $responders) = @_;

	my $id = $obj->{id};
	$self->storage->get_compile_status_async($id)->cb(sub {
		my $obj = shift->recv;
		$responders->{json}($obj);
	});
}

sub _list
{
	my ($self, $obj, $responders) = @_;
	$responders->{json}($self->dispatcher->list);
}

sub _invoke
{
	my ($self, $obj, $responders) = @_;

	my $cv = AE::cv;
	my $result = {};
	my $req_id = CCF::Base64Like::encode(${$self->req_id}++);

	$cv->begin(sub {
		$self->storage->update_request_status_async($req_id, {
			execute => $obj->{execute},
			source => $obj->{source},
			keys => $result,
		});
		$responders->{json}($result);
	});
	foreach my $key (@{$obj->{type}}) {
		$cv->begin;
		my $handle = $self->dispatcher->handle($key);
		my $id = CCF::Base64Like::encode(${$self->id}++);
		$handle->push_write(storable => {
			%$obj,
			type => $key,
			id => $id,
		});
		$handle->push_read(storable => sub {
			my ($handle, $obj) = @_;
			$result->{$key} = $obj->{id};
			$cv->end;
		});
	}
	$cv->end;
}

# TODO: Apply CSS
# TODO: Adjust IFRAME size and layout
# TODO: Show link in client side
sub _results
{
	my ($self, $obj, $responders) = @_;

	my $req_id = $obj->{id};
	$self->storage->get_request_status_async($req_id)->cb(sub {
		my $req = shift->recv;
		my $source = Plack::Util::encode_html($req->{source});
# TODO: HTML escape
		my $res = <<EOF;
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link href="ccf.css" rel="stylesheet" type="text/css">
<link rel="shortcut icon" href="favicon.ico" type="image/vnd.microsoft.icon" />
<link rel="icon" href="favicon.ico" type="image/vnd.microsoft.icon" />
<title>C++ Compiler Farm - Results for Request: $req_id</title>
</head>
<body>
<div id="header">
<img src="ccf.png" alt="C++ Compiler Farm" title="C++ Compiler Farm" />
<p id="owner-notice">ownered by <a href="http://twitter.com/yak_ex">\@yak_ex</a></p>
<p id="menu"><a href="ccf.html"><img src="home.png" alt="Home" title="Home" /></a><a href="FAQ.html"><img src="FAQ.png" alt="FAQ" title="FAQ" /></a></p>
</div>
<h1>Results for Request: $req_id</h1>
<h2>Source</h2>
<pre id="result-source" class="result-box">$source</pre>
<h2>Results</h2>
EOF
		foreach my $key (sort keys %{$req->{keys}}) {
			$res .= <<EOF;
<h3>$key</h3>
<iframe src="ccf.cgi?command=show&id=$req->{keys}{$key}"></iframe>
EOF
		}
		$res .= <<EOF;
</body>
</html>
EOF
		$responders->{html}($res);

	});
}

my %dispatch = (
	invoke => \&_invoke,
	list => \&_list,
	show => \&_show,
	status => \&_status,
	results => \&_results,
);

my %multikey = ( type => 1 );

sub call
{
	my ($self, $env) = @_;

	return sub {
		my $responder = shift;

		my $q = CGI::PSGI->new($env);
		my $responders = {
			html => sub {
				my $str = shift;
				$responder->([$q->psgi_header(-type => 'text/html', -charset => 'utf-8'), [ Encode::encode_utf8($str) ] ]);
			},
			json => sub {
				my $obj = shift;
				$responder->([$q->psgi_header(-type => 'application/json', -charset => 'utf-8'), [Encode::encode_utf8(encode_json($obj))] ]);
			}
		};

		my (%obj) = map { my (@t) = $q->param($_); $_, exists $multikey{$_} ? [ @t ] : $t[0] } $q->param;

		if(exists $dispatch{$obj{command}}) {
			$dispatch{$obj{command}}->($self, \%obj, $responders);
		} else {
			warn "Unknown command: $obj{command}";
		}
	};
}

1;
__END__

=head1 NAME

CCF - PSGI application module for C++ Compiler Farm

=head1 SYNOPSIS

  use Plack::Builder;
  use CCF;

  builder {
    mount '/ccf.cgi' => CCF->new(backend => [['127.0.0.1', 8888]]):
  };

=head1 DESCRIPTION

CCF is a PSGI application module for C++ Compiler Farm.

=head1 CONFIGURATION

=over 4

=item backend => I<array-ref-of-array-ref>

Specify array reference of pairs of host and port.

=back


=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
