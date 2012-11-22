package CCF::S3Storage::Dummy;

use strict;
use warnings;

use Carp;
use JSON;
use File::Path;
use DateTime;

use AnyEvent;

use CCF::Base64Like;

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;

	$arg{root} ||= $ENV{CCF_S3_DUMMY_ROOT};
	$arg{root} =~ s#/$##;

	croak "ROOT folder is not properly set" if ! length $arg{root};
	File::Path::make_path($arg{root}) if ! -d $arg{root};
	File::Path::make_path("$arg{root}/compile") if ! -d "$arg{root}/compile";
	File::Path::make_path("$arg{root}/request") if ! -d "$arg{root}/request";

	return bless {
		_BUCKETNAME => $arg{bucket},
		_ROOT => $arg{root},
	}, $class;
}

sub __update_json
{
	my ($old, $update) = @_;
	foreach my $key (keys %$update) {
		if(defined $update->{$key}) {
			$old->{$key} = $update->{$key};
		} else {
			delete $old->{$key};
		}
	}
}

sub _path
{
	my ($self, $frag) = @_;
	return $self->{_ROOT}.'/'.$frag;
}

sub _update_status_async
{
	my $cv = AE::cv;
	my ($self, $key, $new) = @_;
	my $path = $self->_path($key);
	my $obj;
	if(-f $path) {
		local $/;
		open my $fh, '<', $path;
		my $json = <$fh>;
		close $fh;
		$obj = decode_json($json);
	} else {
		$obj = {};
	}
	__update_json($obj, $new);
	open my $fh, '>', $path;
	print $fh encode_json($obj);
	close $fh;
	$cv->send;
	return $cv;
}

sub _get_status_async
{
	my $cv = AE::cv;
	my ($self, $key) = @_;
	my $path = $self->_path($key);
	if(-f $path) {
		local $/;
		open my $fh, '<', $path;
		my $json = <$fh>;
		close $fh;
		$cv->send(decode_json($json));
	} else {
		$cv->send;
	}
	return $cv;
}

sub update_compile_status_async
{
	my ($self, $id, $new) = @_;
	my $key = "compile/${id}.json";
	return $self->_update_status_async($key, $new);
}

sub get_compile_status_async
{
	my ($self, $id, $new) = @_;
	my $key = "compile/${id}.json";
	return $self->_get_status_async($key);
}

sub update_request_status_async
{
	my ($self, $id, $new) = @_;
	my $key = "request/${id}.json";
	return $self->_update_status_async($key, $new);
}

sub get_request_status_async
{
	my ($self, $id, $new) = @_;
	my $key = "request/${id}.json";
	return $self->_get_status_async($key);
}

sub get_requests_async
{
	my $cv = AE::cv;
	my ($self, $from, $number) = @_;
	my $result = [];
	my $start = $from <= $number ? 0 : $from - $number;
	foreach my $idx ($start..$from) {
		my $id = CCF::Base64Like::encode($idx);
		my $key = "request/${id}.json";
		my $file = $self->_path($key);
		unshift @$result, $id if -f $file;
	}
	$cv->send($result);
	return $cv;
}

1;
__END__

=head1 NAME

CCF::S3Storage::Dummy - Mock of S3 Storage handler for CCF

=head1 SYNOPSIS

  # is retrieved from environment variable $ENV{CCF_S3_DUMMY_ROOT}
  my $storage = CCF::S3Stroage::Dummy->new(
      bucket => 'bucketname',
  );

  # Update compile status
  $storage->update_compile_status_async($id, { status => 4 })->cb(sub {});

  # Get compile status
  $storage->get_compile_status_async($id)->cb(sub {
      my $status = shift->recv;
  });

