package ObjectFile::Tiny::COFF;

use strict;
use warnings;

use ObjectFile::Tiny::ReadBin qw(read1 read2 read4 read8);
use Carp;

sub check
{
	my ($class, $file) = @_;
	open my $fh, '<:raw', $file;
	my $magic = read2($fh);
	close $fh;
	return $magic == 0x14c;
}

sub new
{
	my $self = shift;
	my $class = ref $self || $self;
	my $file = shift;
	$self = bless {
		_FILE => $file
	}, $class;
	$self->_load_section_info();
	return $self;
}

sub _load_section_info
{
	my ($self) = @_;
	open my $fh, '<:raw', $self->{_FILE};

	my $magic = read2($fh);
	croak "$self->{_FILE} is not x86 COFF" unless $magic == 0x14c;
	my $numsec = read2($fh);
	read4($fh); # skip timestamp
	my $tosymbol = read4($fh);
	my $numsymbol = read4($fh);
	my $tostring = $tosymbol + 18 * $numsymbol;
	my $sizeopt = read2($fh);
	read2($fh); # skip characteristics
	seek $fh, $sizeopt, 1;

	my @section;
	foreach (1..$numsec) {
		my $name;
		read($fh, $name, 8);
		$name = unpack('Z8', $name);
		read4($fh); # Virtual Size
		read4($fh); # Virtual Address
		my $szraw = read4($fh);
		my $toraw = read4($fh);
		push @section, [$name, $szraw, $toraw];
		seek $fh, 4+4+2+2+4, 1;
	}

	foreach my $section (@section) {
		next unless $section->[0] =~ m@^/(\d+)@; #/
		seek $fh, $tostring + $1, 0;
		my $name = '';
		my $str;
		while(1) {
			read($fh, $str, 1);
			last if $str eq "\0";
			$name .= $str;
		}
		$section->[0] = $name;
	}

	close $fh;

	$self->{_SECTIONS} = \@section;
}

sub exists_section
{
	my ($self, $re) = @_;
	$re = qr/^\Q$re\E$/ unless ref($re) eq 'Regexp';
	return grep { $_ =~ $re } map { $_->[0] } @{$self->{_SECTIONS}};
}

sub section_names
{
	my ($self) = @_;
	return map { $_->[0] } @{$self->{_SECTIONS}};
}

sub _get_idx
{
	my ($self, $name) = @_;
	my @t = grep { $self->{_SECTIONS}[$_][0] eq $name } 0..$#{$self->{_SECTIONS}};
	return $t[0] if @t;
	return;
}

sub section_contents
{
	my ($self, $name) = @_;
	my $idx = $self->_get_idx($name);
	croak "Section: $name not found" unless defined $idx;
	my $spec = $self->{_SECTIONS}[$idx];
	my $contents;
	open my $fh, '<:raw', $self->{_FILE};
	seek $fh, $spec->[2], 0;
	read $fh, $contents, $spec->[1];
	close $fh;
	return $contents;
}

1;
