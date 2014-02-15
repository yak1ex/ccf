package CCF::Storage::S3;

use strict;
use warnings;

use Carp;
use JSON;

use AnyEvent;
use AnyEvent::Net::Amazon::S3;
use AnyEvent::Net::Amazon::S3::Client;

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;

	$arg{aws_access_key_id} ||= delete $ENV{AWS_ACCESS_KEY_ID};
	$arg{aws_secret_access_key} ||= delete $ENV{AWS_ACCESS_KEY_SECRET};

	croak "AWS key is not properly set"
		if ! length $arg{aws_access_key_id} || ! length $arg{aws_secret_access_key};

	my $s3 = AnyEvent::Net::Amazon::S3->new(
		aws_access_key_id => $arg{aws_access_key_id},
		aws_secret_access_key => $arg{aws_secret_access_key},
	);

	my $client = AnyEvent::Net::Amazon::S3::Client->new(
		s3 => $s3,
	);

	my $bucket = $client->bucket(name => $arg{bucket});

	return bless {
		_BUCKET => $bucket,
	}, $class;
}

sub _bucket
{
	my ($self) = @_;
	return $self->{_BUCKET};
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

sub _update_status_async
{
	my $cv = AE::cv;
	my ($self, $key, $new) = @_;
	my $obj = $self->_bucket->object(
		key => $key,
		acl_short => 'public-read',
		content_type => 'application/json',
	);
	$obj->exists_async->cb(sub {
		my $exists = shift->recv;
		if($exists) {
			$obj->get_async->cb(sub {
				my $value = shift->recv;
				my $json = decode_json($value);
				__update_json($json, $new);
				$obj->put_async(encode_json($json))->cb(sub {
					$cv->send;
				});
			});
		} else {
			$obj->put_async(encode_json({ map { defined $new->{$_} ? ($_, $new->{$_}) : () } keys %$new}))->cb(sub {
				$cv->send;
			});
		}
	});
	return $cv;
}

sub _get_status_async
{
	my $cv = AE::cv;
	my ($self, $key) = @_;
	my $obj = $self->_bucket->object(
		key => $key,
		acl_short => 'public-read',
		content_type => 'application/json',
	);

	$obj->exists_async->cb(sub {
		my $exists = shift->recv;
		if($exists) {
			$obj->get_async->cb(sub {
				$cv->send(decode_json(shift->recv));
			});
		} else {
			$cv->send;
		}
	});
	return $cv;
}

sub update_compile_status_async
{
	my ($self, $id, $new) = @_;
	my $key = sprintf('compile/%08d.json', $id);
	return $self->_update_status_async($key, $new);
}

sub get_compile_status_async
{
	my ($self, $id) = @_;
	my $key = sprintf('compile/%08d.json', $id);
	return $self->_get_status_async($key);
}

sub update_request_status_async
{
	my ($self, $id, $new) = @_;
	my $key = sprintf('request/%08d.json', $id);
	return $self->_update_status_async($key, $new);
}

sub get_request_status_async
{
	my ($self, $id) = @_;
	my $key = sprintf('request/%08d.json', $id);
	return $self->_get_status_async($key);
}

sub get_requests_async
{
	my $cv = AE::cv;
	my ($self, $from, $number) = @_;
	my $start = ($from + 1 >= $number) ? $from - $number + 1 : 0;
	my $data = $self->_bucket->list_async({
		prefix => 'request/',
		marker => ($start > 0 ? sprintf('request/%08d.json', $start - 1) :  undef),
		max_keys => $from < $number ? $from + 1 : $number,
	});
	$data->cb(sub {
		my $objs = shift->recv;
		my $result = [ reverse map { my ($key) = $_->key =~ m,request/(.*)\.json$,; [ 0+$key, $_->last_modified ]; } @$objs];
		$cv->begin(sub { $cv->send($result); });
		foreach my $idx (0..$#$result) {
			$cv->begin;
			$self->get_request_status_async($result->[$idx][0])->cb(sub {
				my $obj = shift->recv;
				push @{$result->[$idx]}, $obj;
				$cv->end;
			});
		}
		$cv->end;
		return 0;
	});
	return $cv;
}

sub update_compile_stat_async
{
	my ($self, $id, $new) = @_;
	my $key = sprintf('cstat/%08d.json', $id);
	return $self->_update_status_async($key, $new);
}

sub get_compile_stat_async
{
	my ($self, $id) = @_;
	my $key = sprintf('cstat/%08d.json', $id);
	return $self->_get_status_async($key);
}

sub get_compile_stats_async
{
	my $cv = AE::cv;
	my ($self) = @_;
	my $data = $self->_bucket->list_async({
		prefix => 'cstat/',
	});
	my $result = {};
	my $lcv = AE::cv;
	$lcv->begin(sub {
		$cv->send($result);
	});
	$data->cb(sub {
		my $objs = shift->recv;
		if(defined $objs) {
			$lcv->begin;
			foreach my $objs (@$objs) {
				$lcv->begin;
				$objs->get_async->cb(sub {
					my $obj = decode_json(shift->recv);
					my $key = $obj->{addr}.':'.$obj->{port};
					if(exists $result->{$key}) {
						++$result->{$key};
					} else {
						$result->{$key} = 1;
					}
					$lcv->end;
				});
			}
			$lcv->end;
			return 1;
		} else {
			$lcv->end;
			return 0;
		}
	});
	return $cv;
}

1;
__END__

=head1 NAME

CCF::Storage::S3 - S3 Storage handler for CCF

=head1 SYNOPSIS

  # AWS key is retrieved from environment variables
  my $storage = CCF::Stroage::S3->new(
      bucket => 'bucketname',
  );

  # Update compile status
  $storage->update_compile_status_async($id, { status => 4 })->cb(sub {});

  # Get compile status
  $storage->get_compile_status_async($id)->cb(sub {
      my $status = shift->recv;
  });

=head1 DESCRIPTION

=head1 OPTIONS

=head2 bucket

Specify S3 bucket name

=head2 aws_access_key_id

If not specified, C<$ENV{AWS_ACCESS_KEY_ID}> is used.

=head2 aws_secret_access_key

If not specified, C<$ENV{AWS_ACCESS_KEY_SECRET}> is used.

=head1 METHODS

=head2 C<update_compile_status_async($id, $hash_ref)>

$id is compilation ID and $hash_ref holds updating entries.
If KEY => undef is included, KEY will be deleted.
JSON-encoded string is stored into C<'compile/${id}.json'>.
Returns an AnyEvent condition variable.

=head2 C<get_compile_status_async($id)>

$id is compilation ID.
Returns an AnyEvent condition variable.
JSON-decoded object of C<'compile/${id}.json'> is sent via the condition variable.

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
