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
	my ($self, $obj, $responders) = @_;

	my ($handle, $idx) = $self->dispatcher->handle_and_pre_adjust_id($obj);
	my $id = $obj->{id};
	$handle->push_write(storable => { command => 'status', id => $id });
	$handle->push_read(storable => sub {
		my ($handle, $obj) = @_;
		my $html;
		my $status = $obj->{status};
		given($status) {
			when (1)     { $responders->{html}('<html><body>Invoked.</body></html>'); }
			when (2)     { $responders->{html}('<html><body>Compiling.</body></html>'); }
			when ([3,4]) {
				$handle->push_write(storable => { command => 'result', id => $id });
				$handle->push_read(storable => sub {
					my ($handle, $obj) = @_;
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
				});
			}
		}
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

	$cv->begin(sub {
		$responders->{json}($result);
	});
	foreach my $key (@{$obj->{type}}) {
		$cv->begin;
		my ($handle, $idx) = $self->dispatcher->handle_and_idx($key);
		$handle->push_write(storable => {
			%$obj,
			type => $key,
		});
		$handle->push_read(storable => sub {
			my ($handle, $obj) = @_;
			$self->dispatcher->post_adjust_id($obj, $idx);
			$result->{$key} = $obj->{id};
			$cv->end;
		});
	}
	$cv->end;
}

my %dispatch = (
	invoke => \&_invoke,
	list => \&_list,
	show => \&_show,
);

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

		my (%obj) = map { my (@t) = $q->param($_); $_, @t == 1 ? $t[0] : [ @t ] } $q->param;

		if(exists $dispatch{$obj{command}}) {
			$dispatch{$obj{command}}->($self, \%obj, $responders);
		} else {
			my ($handle, $idx) = $self->dispatcher->handle_and_pre_adjust_id(\%obj);
			$handle->push_write(storable => \%obj);
			$handle->push_read(storable => sub {
				my ($handle_, $obj) = @_;
				$self->dispatcher->post_adjust_id($obj, $idx);
				$responders->{json}($obj);
			});
		}
	};
}

1;
