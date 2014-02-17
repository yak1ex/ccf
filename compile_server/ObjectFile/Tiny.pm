package ObjectFile::Tiny;

use strict;
use warnings;

my @type;
BEGIN {
	@type = map { "ObjectFile::Tiny::$_" } qw(ELF COFF);
	eval "require $_" for @type;
}

sub new
{
	my $self = shift;
	my $file = shift;
	foreach my $type (@type) {
		return $type->new($file) if $type->check($file);
	}
	return;
}
