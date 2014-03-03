package CCF::IDCounter;

use strict;
use warnings;

use parent qw(Tie::Scalar);

use YAML;
use Fcntl qw(:flock SEEK_SET);

sub TIESCALAR
{
	my ($class, %arg) = @_;
	my $obj;
	if(exists $arg{file} && -f $arg{file}) {
		if(open my $fh, '<', $arg{file}) {
			flock($fh, LOCK_SH);
			local $/;
			$obj = YAML::Load(<$fh>);
			flock($fh, LOCK_UN);
			close $fh;
		} else {
			warn "Open failed: $!";
			$obj = {};
		}
	} else {
		$obj = {};
	}
	return bless {
		_file => $arg{file},
		_key => $arg{key},
		_obj => $obj,
	}, $class;
}

sub FETCH
{
	my ($self) = @_;
	$self->{_obj}{$self->{_key}} = 0 if(! exists $self->{_obj}{$self->{_key}});
	return $self->{_obj}{$self->{_key}};
}

sub STORE
{
	my ($self, $value) = @_;
	$self->{_obj}{$self->{_key}} = $value;
	open my $fh, '+<', $self->{_file} or warn "Open failed: $!" and return;
	flock($fh, LOCK_EX);
	truncate($fh, 0);
	seek($fh, 0, 0);
	print $fh YAML::Dump($self->{_obj});
	flock($fh, LOCK_UN);
	close $fh;
}
1;
__END__

=head1 NAME

CCF::IDCounter - Tied Persistent ID counter

=head1 SYNOPSIS

  my $counter;
  tie $counter, 'CCF::IDCounter', file => 'id.yaml', key => 'cygwin';

=head1 DESCRIPTION

CCF::IDCounter is persistent ID counter using tied scalar.
ID counter is associated with a key.
ID counter is load from YAML file when initialization. NOTE that loading occurs only at initialization time.
Each time ID counter is updated, it is stored to YAML file.

=head1 CONFIGURATION

=over 4

=item file => I<path>

YAML filename that ID values are stored.

=item key => I<key>

key in YAML file.

=back

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
