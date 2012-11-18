package CCF::Dispatcher;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;

use Carp;

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;
	$self = bless {
		_backend => $arg{backend},
		_type => {},
	}, $class;
	my $cv = AE::cv;
	$cv->begin(sub {
		for(my $idx = 0; $idx < @{$self->{_list}}; ++$idx) {
			my $entry = $self->{_list}[$idx];
			foreach my $key (keys %{$entry}) {
				if(exists $self->{_type}{$key}) {
					carp 'Name mismatch with the same key' if $self->{_type}{$key}[0] ne $entry->{$key};
					push @{$self->{_type}{$key}[1]}, $idx;
				} else {
					$self->{_type}{$key}[0] = $entry->{$key};
					$self->{_type}{$key}[1] = [ $idx ];
				}
			}
		}
		delete $self->{_list};
	});
	foreach my $idx (0..$#{$arg{backend}}) {
		$cv->begin();
		my $handle = $self->_handle($idx);
		$handle->push_write(storable => { command => 'list' });
		$handle->push_read(storable => sub { 
			my ($handle_, $obj) = @_;
			$self->{_list}[$idx] = $obj;
			$cv->end;
		});
	}
	$cv->end;
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
		connect => [$self->_host($idx), $self->_port($idx)],
		on_error => sub { undef $handle },
	);
	return $handle;
}

sub _idx
{
	my ($self, $type) = @_;
	return $self->{_type}{$type}[1][0]; # TODO: Currently, always return the first entry.
}

sub handle
{
	my ($self, $key) = @_;
	my $idx = $self->_idx($key);
	return $self->_handle($idx);
}

sub list
{
	my ($self) = @_;
	my $obj = {};
	foreach my $key (keys %{$self->{_type}}) {
		$obj->{$key} = $self->{_type}{$key}[0];
	}
	return $obj;
}

1;
__END__

=head1 NAME

CCF::Dispatcher - C++ Compiler Farm backend dispatcher module

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
