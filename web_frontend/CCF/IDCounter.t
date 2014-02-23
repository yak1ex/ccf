use Test::More tests => 22;
use CCF::IDCounter;
use File::Temp;

my @pid;
my $fh = File::Temp->new;
{
	foreach my $i (1..10) {
		my $counter = 0;
		tie $counter, 'CCF::IDCounter', file => $fh->filename, key => 'test';
		++$counter;
		is($counter, $i, "write/read $i")
	}
}
{
	my $counter = 0;
	tie $counter, 'CCF::IDCounter', file => $fh->filename, key => 'test';
	is($counter, 10, 're-read 10');
}
{
	foreach my $i (1..10) {
		my $counter = 0;
		tie $counter, 'CCF::IDCounter', file => $fh->filename, key => 'test';
		++$counter;
		is($counter, 10 + $i, "write/read ".(10 + $i));
	}
}
{
	my $counter = 0;
	tie $counter, 'CCF::IDCounter', file => $fh->filename, key => 'test';
	is($counter, 20, 're-read 20');
}
