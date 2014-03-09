package Checker;

sub new
{
	return bless {
		_MIN => 0,
		_MAX => 0,
		_CUR => 0,
	}, __PACKAGE__;
}

sub inc
{
	my $self = shift;
	++$self->{_CUR};
	$self->{_MAX} = $self->{_CUR} if $self->{_MAX} < $self->{_CUR};
}

sub dec
{
	my $self = shift;
	--$self->{_CUR};
	$self->{_MIN} = $self->{_CUR} if $self->{_MIN} > $self->{_CUR};
}

sub min
{
	return $_[0]->{_MIN};
}

sub max
{
	return $_[0]->{_MAX};
}

package main;

use Test::More tests => 12;
use Test::Exception;
use AnyEvent;
use Data::Monad::CondVar;

BEGIN {
	use_ok('CCF::Queue');
}

{
	my $q = CCF::Queue->new(5);
	throws_ok { $q->enque(sub {}) } qr/a queued task does not return AnyEvent::CondVar/, 'invalid arg1';
	throws_ok { $q->enque(sub { 1 }) } qr/a queued task does not return AnyEvent::CondVar/, 'invalid arg2';
	throws_ok { $q->enque(sub { $q }) } qr/a queued task does not return AnyEvent::CondVar/, 'invalid arg3';
}

sub process
{
	my ($len, $task) = @_;
	my $q = CCF::Queue->new($len);
	my $cv = AE::cv;
	my $ck = Checker->new;
	$cv->begin(sub { $cv->send });
	foreach (1..$task) {
		$cv->begin;
		$q->enque(sub {
			cv_unit()->map(sub {
				$ck->inc;
			})->sleep(rand(3))->map(sub {
				$ck->dec;
				$cv->end;
			})
		});
	}
	$cv->end;
	$cv->recv;
	is($ck->max, ($len < $task ? $len : $task), "max - len: $len task: $task");
	is($ck->min, 0, "min - len: $len task: $task");
}

process(1, 5);
process(3, 10);
process(5, 10);
process(5, 3);