package CCF::Dispatcher;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Carp;

use CCF::Base64Like;

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

sub _handle
{
	my ($self, $idx) = @_;
	my $handle; $handle = AnyEvent::Handle->new(
		connect => [$self->_host, $self->_port],
		on_error => sub { undef $handle },
	);
	return $handle;
}

sub handle_and_pre_adjust_id
{
	my ($self, $obj) = @_;
	if(exists $obj->{id}) {
		my $idx = CCF::Base64Like::decode(substr($obj->{id}, 0, 1));
		$obj->{id} = CCF::Base64Like::decode(substr($obj->{id}, 1));
		return ($self->_handle($idx), $idx);
	} else {
		# Currently, list does not include type.
		if(! exists $obj->{command} || $obj->{command} ne 'list') {
			croak('id or type must exist') if ! exists $obj->{type};
		}
		return ($self->_handle(0), 0); # TODO: Currently, always return the first entry.
	}
}

sub post_adjust_id
{
	my ($self, $obj, $idx) = @_;
	if(exists $obj->{id}) {
		$obj->{id} = CCF::Base64Like::encode($idx) . CCF::Base64Like::encode($obj->{id});
	}
}

1;
