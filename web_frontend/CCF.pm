package CCF;

use strict;
use warnings;
use feature 'switch';

use parent qw(Plack::Component);
use CGI::PSGI;

use AnyEvent;
use AnyEvent::Handle;

use JSON;
use Encode qw(decode);

# TODO: Error check

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;
	return bless {
		_backend => $arg{backend}
	}, $class;
}

sub _host
{
	my ($self, $idx) = @_;
	$idx //= 0;
	return $self->{_backend}[$idx][0];
}

sub _port
{
	my ($self, $idx) = @_;
	$idx //= 0;
	return $self->{_backend}[$idx][1];
}

sub _num_backends
{
	my ($self) = @_;
	return scalar @{$self->{_backend}};
}

sub call
{
	my ($self, $env) = @_;

	return sub {
		my $responder_orig = shift;

		my $q = CGI::PSGI->new($env);

		my $responder = sub {
			my $str = shift;
			$responder_orig->([$q->psgi_header(-type => 'text/html', -charset => 'utf-8'), [ Encode::encode_utf8($str) ] ]);
		};

		my $command = $q->param('command');

		my $handle; $handle = AnyEvent::Handle->new(
			connect => [$self->_host, $self->_port],
			on_error => sub { undef $handle },
		);

		if($command eq 'show') {
			my $id = $q->param('id');
			$handle->push_write(json => { command => 'status', id => $id });
			$handle->push_read(json => sub {
				my ($handle, $json) = @_;
				my $html;
				my $status = $json->{status};
				given($status) {
					when (1)     { $responder->('<html><body>Invoked.</body></html>'); }
					when (2)     { $responder->('<html><body>Compiling.</body></html>'); }
					when ([3,4]) {
						$handle->push_write(json => { command => 'result', id => $id });
						$handle->push_read(json => sub {
							my ($handle, $json) = @_;
# TODO: HTML escape
# TODO: Apply CSS
							if($status == 3 || ! exists $json->{execute}) {
								my $compile = $json->{compile};
								$compile = '&nbsp;' if $compile eq '';
								$responder->(<<EOF);
<html><body><p>Compiled.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre></body></html>
EOF
							} else {
								my $compile = $json->{compile};
								$compile = '&nbsp;' if $compile eq '';
								my $execute = $json->{execute};
								$execute = '&nbsp;' if $execute eq '';
								$responder->(<<EOF);
<html><body><p>Executed.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre><p>execution result:</p><pre style="background:#fff;">$execute</pre></body></html>
EOF
							}
						});
					}
				}
			});
		} else {
			my (@names) = $q->param;
			$handle->push_write(json => { map { $_, $q->param($_) } @names });
			$handle->push_read(json => sub {
				my ($handle_, $json) = @_;
				$responder_orig->([$q->psgi_header(-type => 'application/json', -charset => 'utf-8'), [Encode::encode_utf8(encode_json($json))] ]);
			});
		}
	};
}

1;
