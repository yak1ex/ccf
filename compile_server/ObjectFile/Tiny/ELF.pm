package ObjectFile::Tiny::ELF;

use strict;
use warnings;

use ObjectFile::Tiny::ReadBin qw(read1 read2 read4 read8);
use Carp;

sub check
{
	my ($class, $file) = @_;
	open my $fh, '<:raw', $file;
	my $magic;
	read($fh, $magic, 16);
	my $magic2 = read4($fh);
	close $fh;
	return $magic =~ /^\x7FELF\x01\x01/ && $magic2 == 0x00030001;
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

	my $magic;
	read($fh, $magic, 16);
	croak "$self->{_FILE} is not LE32 ELF" unless $magic =~ /^\x7FELF\x01\x01/;
	$magic = read4($fh);
	croak "$self->{_FILE} is not x86 ELF object" unless $magic == 0x00030001;
	seek $fh, 4+4+4, 1; # skip version, entry, offset to program header
	my $tosec = read4($fh);
	seek $fh, 4+2+2+2, 1; # skip flags, ehsize, phentsize, phnum
	my $sizesec = read2($fh);
	my $numsec = read2($fh);
	my $idxstr = read2($fh);
	seek $fh, $tosec, 0;

	my @section;
	foreach (1..$numsec) {
		my $name = read4($fh);
		read4($fh); # type
		read4($fh); # flags
		read4($fh); # addr
		my $toraw = read4($fh);
		my $szraw = read4($fh);
		push @section, [$name, $szraw, $toraw];
		seek $fh, 4+4+4+4, 1;
	}
	my $tostring = $section[$idxstr]->[2];

	foreach my $section (@section) {
		seek $fh, $tostring + $section->[0], 0;
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
