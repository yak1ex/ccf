package CCF::Dispatcher;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

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

sub handle
{
	my ($self, $obj) = @_;
	my $handle; $handle = AnyEvent::Handle->new(
		connect => [$self->_host, $self->_port],
		on_error => sub { undef $handle },
	);
	return $handle;
}

1;
