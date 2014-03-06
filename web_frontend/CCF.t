package Mock::CompileServer;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

sub invoke
{
	my ($handle, $obj) = @_;
	$handle->push_write(storable => { id => $obj->{id} });
}

sub status
{
	my ($handle, $obj) = @_;
	$handle->push_write(storable => { id => $obj->{id}, status => 4 });
}

sub result
{
	my ($handle, $obj) = @_;
	$handle->push_write(storable => { id => $obj->{id}, execute => { output => 'execution reuslt' }, compile => { output => 'compilation result' }});
}

sub list
{
	my ($handle, $obj) = @_;
	$handle->push_write(storable => { mock => [ 'mock', 1, 0 ] });
}

my %handler = (
	invoke => \&invoke,
	status => \&status,
	result => \&result,
	list => \&list,
);

sub new
{
	my ($self, $port) = @_;
	my $class = ref $self || $self;
	$self = {};
	$self->{_GUARD} = tcp_server undef, $port, sub {
		my ($fh, $host, $port) = @_;

		my $handle; $handle = AnyEvent::Handle->new(
			fh => $fh,
			on_eof => sub { print "EOF\n"; $handle->destroy; },
			on_error => sub { print "ERROR\n"; $handle->destroy; },
		);
		my @handler; @handler = (storable => sub {
			my ($handle, $obj) = @_;
			if(exists $obj->{command} && exists $handler{$obj->{command}}) {
				print STDERR "handler called by command `$obj->{command}'.\n";
				$handler{$obj->{command}}->($handle, $obj);
			} else {
				my $command = '';
				$command = $obj->{command} if exists $obj->{command};
				$command = "Unknown command `$command'";
				warn $command;
				$handle->push_write(storable => { error => $command });
			}
			$handle->push_read(@handler);
		});
		$handle->push_read(@handler);
	};
	return bless $self, $class;
}

########################################################################

package main;

use lib qw(../lib);

use Test::More tests => 11;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use File::Temp;
use CCF;

my $dir = File::Temp->newdir;
$ENV{CCF_STORAGE_DUMMY_ROOT} = $dir->dirname;
my $mock = Mock::CompileServer->new(8888);
{open my $fh, '>', $dir->dirname . "/id.yaml"; close $fh;}
{open my $fh, '>', $dir->dirname . "/id2.yaml"; close $fh;}
my $app = CCF->new(bucket => 'cpp-compiler-farm-test', backend => [['127.0.0.1', 8888]], dir => $dir->dirname);
my $test = Plack::Test->create(builder {
	mount '/ccf.cgi' => $app;
	mount '/result' => $app;
	mount '/results' => $app;
});

########################################################################

my $res = $test->request(GET '/ccf.cgi');
is($res->code, 400, 'no argument - status code: bad request');

$res = $test->request(GET '/ccf.cgi?command=invalid');
is($res->code, 400, 'invalid command - status code: bad request');

########################################################################
# show

$res = $test->request(GET '/ccf.cgi?command=show');
is($res->code, 400, 'show w/o id - status code: bad request');

# All ids are considered as invalid
$res = $test->request(GET '/ccf.cgi?command=show&id=1000');
is($res->code, 400, 'show with inavlid id - status code: bad request');

########################################################################
# status

$res = $test->request(GET '/ccf.cgi?command=status');
is($res->code, 400, 'status w/o id - status code: bad request');

# All ids are considered as invalid
$res = $test->request(GET '/ccf.cgi?command=status&id=1000');
is($res->code, 400, 'status with inavlid id - status code: bad request');

########################################################################
# invoke

$res = $test->request(GET '/ccf.cgi?command=invoke');
is($res->code, 400, 'invoke w/o type and source - status code: bad request');

$res = $test->request(GET '/ccf.cgi?command=invoke&type=mock');
is($res->code, 400, 'invoke w/o source - status code: bad request');

$res = $test->request(GET '/ccf.cgi?command=invoke&source=mock');
is($res->code, 400, 'invoke w/o type - status code: bad request');

# CCF.pm expects storage update
#$res = $test->request(GET '/ccf.cgi?command=invoke&type=mock&source=mock');
#is($res->code, 200, 'invoke - status code: ok');

########################################################################
# result

$res = $test->request(GET '/ccf.cgi?command=result');
is($res->code, 400, 'result w/o id - status code: bad request');

# All ids are considered as invalid
$res = $test->request(GET '/ccf.cgi?command=result&id=1000');
is($res->code, 400, 'result with inavlid id - status code: bad request');
