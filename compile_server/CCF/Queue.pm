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

sub _call
{
	my ($self, $coderef) = @_;
	--$self->{_AVAIL};
	my $ret = $coderef->();
	if(eval { $ret->isa('AnyEvent::CondVar') }) {
		$ret->cb(sub {
			++$self->{_AVAIL};
			$self->_take();
		});
	} else {
		croak "a queued task does not return AnyEvent::CondVar";
	}
}

sub _take
{
	my ($self) = @_;
	if(@{$self->{_QUEUE}}) {
		my $coderef = shift @{$self->{_QUEUE}};
		$self->_call($coderef);
	}
}

sub enque
{
	my ($self, $coderef) = @_;
	if($self->{_AVAIL} > 0) {
		$self->_call($coderef);
	} else {
		push @{$self->{_QUEUE}}, $coderef;
	}
}

1;
