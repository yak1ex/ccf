package CCF::Base64Like;

use strict;
use warnings;

require Exporter;

our (@EXPORT_OK) = qw(encode decode);

my (@conv) = split //, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
my (%rconv) = map { $conv[$_], $_ } 0..$#conv;

use Carp;

sub encode
{
	my ($arg) = shift;
	my $result;
	croak 'Can not accept negative value' if($arg < 0);
	return 'A' if $arg == 0;
	while($arg > 0) {
		$result .= @conv[$arg % 64];
		$arg = int($arg / 64);
	}
	return scalar reverse $result;
}

sub decode
{
	my ($arg) = shift;
	my $result = 0;
	foreach my $c (split //, $arg) {
		$result = $result * 64 + $rconv{$c};
	}
	return $result;
}

1;
__END__

=head1 NAME

CCF::Base64Like - string-number conversion like base64url scheme

=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
