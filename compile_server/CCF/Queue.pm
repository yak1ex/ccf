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
	my ($self, $coderef) = @_;
	--$self->{_AVAIL};
	my $ret = $coderef->();
	if(eval { $ret->isa('AnyEvent::CondVar') }) {
		$ret->cb(sub {
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
		my $coderef = shift @{$self->{_QUEUE}};
		# NOTE: $self->{_AVAIL} should be positive
		$self->_enter($coderef);
	}
}

sub enque
{
	my ($self, $coderef) = @_;
	if($self->{_AVAIL} > 0) {
		$self->_enter($coderef);
	} else {
		push @{$self->{_QUEUE}}, $coderef;
	}
}

1;
