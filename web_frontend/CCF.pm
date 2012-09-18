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

use CCF::Dispatcher;

# TODO: Error check

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;
	return bless {
		_dispatcher => CCF::Dispatcher->new(backend => $arg{backend})
	}, $class;
}

sub dispatcher
{
	my ($self) = @_;
	return $self->{_dispatcher};
}

sub _show
{
	my ($self, $q, $responder, $handle) = @_;

	my $html_responder = sub {
		my $str = shift;
		$responder->([$q->psgi_header(-type => 'text/html', -charset => 'utf-8'), [ Encode::encode_utf8($str) ] ]);
	};

	my $id = $q->param('id');
	$handle->push_write(storable => { command => 'status', id => $id });
	$handle->push_read(storable => sub {
		my ($handle, $obj) = @_;
		my $html;
		my $status = $obj->{status};
		given($status) {
			when (1)     { $html_responder->('<html><body>Invoked.</body></html>'); }
			when (2)     { $html_responder->('<html><body>Compiling.</body></html>'); }
			when ([3,4]) {
				$handle->push_write(storable => { command => 'result', id => $id });
				$handle->push_read(storable => sub {
					my ($handle, $obj) = @_;
# TODO: HTML escape
# TODO: Apply CSS
					if($status == 3 || ! exists $obj->{execute}) {
						my $compile = $obj->{compile};
						$compile = '&nbsp;' if $compile eq '';
						$html_responder->(<<EOF);
<html><body><p>Compiled.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre></body></html>
EOF
					} else {
						my $compile = $obj->{compile};
						$compile = '&nbsp;' if $compile eq '';
						my $execute = $obj->{execute};
						$execute = '&nbsp;' if $execute eq '';
						$html_responder->(<<EOF);
<html><body><p>Executed.</p><p>compilation result:</p><pre style="background:#fff;">$compile</pre><p>execution result:</p><pre style="background:#fff;">$execute</pre></body></html>
EOF
					}
				});
			}
		}
	});
}

my %command = (show => \&_show);

sub call
{
	my ($self, $env) = @_;

	return sub {
		my $responder = shift;

		my $q = CGI::PSGI->new($env);

		my $command = $q->param('command');

		my $handle = $self->dispatcher->handle();

		if(exists $command{$command}) {
			$command{$command}->($self, $q, $responder, $handle);
		} else {
			my (@names) = $q->param;
			$handle->push_write(storable => { map { $_, $q->param($_) } @names });
			$handle->push_read(storable => sub {
				my ($handle_, $obj) = @_;
				$responder->([$q->psgi_header(-type => 'application/json', -charset => 'utf-8'), [Encode::encode_utf8(encode_json($obj))] ]);
			});
		}
	};
}

1;
