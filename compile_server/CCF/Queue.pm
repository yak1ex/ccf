package CCF::Queue;

use AnyEvent;
use Carp;

sub new
{
	my ($self, $limit) = @_;
	my $class = ref $self || $self;
	return bless {
		_QUEUE => [],
		_LIMIT => $limit,
		_AVAIL => $limit,
	}, $class;
}

# precondition: $self->{_AVAIL} MUST be positive
sub _enter
{
	my ($self, $task) = @_;
	--$self->{_AVAIL};
	my $ret = $task->[0]->();
	if(eval { $ret->isa('AnyEvent::CondVar') }) {
		$ret->cb(sub {
			$task->[1]->send(shift->recv);
			$self->_leave();
		});
	} else {
		croak "a queued task does not return AnyEvent::CondVar";
	}
}

sub _leave
{
	my ($self) = @_;
	++$self->{_AVAIL};
	if(@{$self->{_QUEUE}}) {
		my $task = shift @{$self->{_QUEUE}};
		# NOTE: $self->{_AVAIL} should be positive
		$self->_enter($task);
	}
}

sub enqueue
{
	my ($self, $coderef) = @_;
	my $cv = AE::cv;
	if($self->{_AVAIL} > 0) {
		$self->_enter([$coderef, $cv]);
	} else {
		push @{$self->{_QUEUE}}, [$coderef, $cv];
	}
	return $cv;
}

1;
