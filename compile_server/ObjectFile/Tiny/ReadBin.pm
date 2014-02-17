package ObjectFile::Tiny::ReadBin;

use strict;
use warnings;

use Symbol 'qualify_to_ref';

use constant {
	LE => 0,
	BE => 1
};

require Exporter;
our @ISA = qw(Exporter);

# TODO: endian import directive
our @EXPORT_OK = qw(
	read1 read2 read4 read6 read8
	read1be read2be read4be read6be read8be
	read1le read2le read4le read6le read8le
	endian
);

our $endian = LE; # Default is little

BEGIN
{
	my (%suffix) = (
		1 => [1, 'C'],
		'2le' => [2, 'v'],
		'2be' => [2, 'n'],
		'4le' => [4, 'V'],
		'4be' => [4, 'N'],
	);

	for my $key (keys %suffix) {
		no strict 'refs';
		*{__PACKAGE__.'::read'.$key} = sub (*) {
			my $fh = qualify_to_ref(shift, caller);
			my $t;
			return unpack($suffix{$key}[1], $t) if read($fh, $t, $suffix{$key}[0]) == $suffix{$key}[0];
			return undef;
		};
		*{__PACKAGE__.'::write'.$key} = sub (*$) {
			my $fh = qualify_to_ref(shift, caller);
			print $fh pack($suffix{$key}[1], shift);
		};
	}
	for my $size (2,4,6,8) {
		no strict 'refs';
		*{__PACKAGE__.'::read'.$size} = sub (*) {
			return $endian == LE ? goto &{"read${size}le"} : goto &{"read${size}be"};
		};
		*{__PACKAGE__.'::write'.$size} = sub (*$) {
			return $endian == LE ? goto &{"write${size}le"} : goto &{"write${size}be"};
		};
	}
}

# TODO: use template

sub read6le(*)
{
	my $fh = qualify_to_ref(shift, caller);
	my ($t1, $t2);
	return undef if read($fh, $t1, 4) != 4;
	return undef if read($fh, $t2, 2) != 2;
	return (unpack('v', $t2) << 32) | unpack('V', $t1);
}

sub read6be(*)
{
	my $fh = qualify_to_ref(shift, caller);
	my ($t1, $t2);
	return undef if read($fh, $t1, 4) != 4;
	return undef if read($fh, $t2, 2) != 2;
	return (unpack('N', $t1) << 16) | unpack('n', $t2);
}

sub read8le(*)
{
	my $fh = qualify_to_ref(shift, caller);
	my ($t1, $t2);
	return undef if read($fh, $t1, 4) != 4;
	return undef if read($fh, $t2, 4) != 4;
	return (unpack('V', $t2) << 32) | unpack('V', $t1);
}

sub read8be(*)
{
	my $fh = qualify_to_ref(shift, caller);
	my ($t1, $t2);
	return undef if read($fh, $t1, 4) != 4;
	return undef if read($fh, $t2, 4) != 4;
	return (unpack('N', $t1) << 32) | unpack('N', $t2);
}

sub endian
{
	$endian = $_[0] if @_;
	return $endian;
}

1;
