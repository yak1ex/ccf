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
	$self = bless {
		_backend => $arg{backend},
		_type => {}
	}, $class;
	AE::cv->begin(sub {
		for(my $idx = 0; $idx < @{$self->{_list}}; ++$idx) {
			my $entry = $self->{_list}[$idx];
			foreach my $key (keys %{$entry}) {
				if(exists $self->{_type}{$key}) {
					carp 'Name mismatch with the same key' if $self->{_type}{$key}[0] ne $entry->{$key};
					push @{$self->{_type}{$key}[1]}, $idx;
				} else {
					$self->{_type}{$key}[1] = [ $idx ];
				}
			}
		}
		delete $self->{_list};
	});
	foreach my $idx (0..$#{$arg{backend}}) {
		AE::cv->begin();
		my $handle = $self->_handle($idx);
		$handle->push_write(storable => { command => 'list' });
		$handle->push_read(storable => sub {
			my ($handle_, $obj) = @_;
			$self->{_list}[$idx] = $obj;
			AE::cv->end;
		});
	}
	AE::cv->end;
	return $self;
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
