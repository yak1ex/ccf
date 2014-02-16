package CCF::Storage;

use strict;
use warnings;

use CCF::Storage::Dummy;
use CCF::Storage::S3;

sub new
{
	my $self = shift;
	my $class = 'CCF::Storage::S3';

	if(exists $ENV{CCF_STORAGE_DUMMY_ROOT}) {
		$class = 'CCF::Storage::Dummy';
		push @_, root => delete $ENV{CCF_STORAGE_DUMMY_ROOT};
	} else {
		my %arg = @_;
		$class = 'CCF::Storage::Dummy' if exists $arg{root} && defined $arg{root};
	}

	return $class->new(@_);
}

1;
__END__

=head1 NAME

CCF::Storage - Storage handler for CCF

=head1 SYNOPSIS

  # AWS key is retrieved from environment variables
  my $storage = CCF::Stroage->new(
      bucket => 'bucketname',
  );

  # Update compile status
  $storage->update_compile_status_async($id, { status => 4 })->cb(sub {});

  # Get compile status
  $storage->get_compile_status_async($id)->cb(sub {
      my $status = shift->recv;
  });

=head1 DESCRIPTION

If environment variable C<CCF_STORAGE_DUMMY_ROOT> is defined or root is specified by options, CCF::Storage::Dummy is used.
Otherwise, CCF::Storage::S3 is used.
Note that C<CCF_STORAGE_DUMMY_ROOT> will be deleted after the object creation if root is not specified and the environment variable C<CCF_STORAGE_DUMMY_ROOT> is defined.

=head1 OPTIONS

All options are passed through to an actual handler.

=head1 METHODS

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
