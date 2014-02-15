package CCF;

use strict;
use warnings;
use feature 'switch';

use parent qw(Plack::Component);
use Plack::Request;
use Plack::Util;

use AnyEvent;
use AnyEvent::Handle;

use JSON;
use Encode qw(decode);
use Text::Template;
use DateTime;
use Time::Duration;

use CCF::Dispatcher;
use CCF::IDCounter;
use CCF::Storage;

opendir DIR, 'tmpl';
my @tmpl = map { s/\.tmpl$//; uc($_) } grep { /\.tmpl$/ } readdir DIR;
my %tmpl = map { $_ => Text::Template->new(TYPE => 'FILE', SOURCE => 'tmpl/'.lc($_).'.tmpl') } @tmpl;

# TODO: Error check

sub new
{
	my ($self, %arg) = @_;
	my $class = ref($self) || $self;

	my $id = 0;
	tie $id, 'CCF::IDCounter', file => 'id.yaml', key => 'compile';
	my $rid = 0;
# TODO: share idcounter file between different keys
	tie $rid, 'CCF::IDCounter', file => 'id2.yaml', key => 'request';

	return bless {
		_DISPATCHER => CCF::Dispatcher->new(backend => $arg{backend}),
		_STORAGE => CCF::Storage->new(
			bucket => $arg{bucket},
			root => delete $ENV{CCF_STORAGE_DUMMY_ROOT},
			aws_access_key_id => delete $ENV{AWS_ACCESS_KEY_ID},
			aws_secret_access_key => delete $ENV{AWS_ACCESS_KEY_SECRET},
		),
		_ID => \$id,
		_RID => \$rid,
	}, $class;
}

sub dispatcher
{
	my ($self) = @_;
	return $self->{_DISPATCHER};
}

sub storage
{
	my ($self) = @_;
	return $self->{_STORAGE};
}

sub id
{
	my ($self) = @_;
	return $self->{_ID};
}

sub req_id
{
	my ($self) = @_;
	return $self->{_RID};
}

sub _show
{
	my ($self, $obj, $responders) = @_;

	my $id = $obj->{id};
	$self->storage->get_compile_status_async($id)->cb(sub {
		my $obj = shift->recv;
		my $html;
		my $status = $obj->{status};
		given($status) {
			when (1)     { $responders->{html}($tmpl{INVOKED}->fill_in(HASH => {})); }
			when (2)     { $responders->{html}($tmpl{COMPILING}->fill_in(HASH => {})); }
			when ([3,4]) {
# TODO: HTML escape
# TODO: Apply CSS
				if($status == 3 || ! exists $obj->{execute}) {
					my $compile = $obj->{compile};
					$compile = Plack::Util::encode_html($compile);
					$compile = '&nbsp;' if $compile eq '';
					$responders->{html}($tmpl{COMPILED}->fill_in(HASH => { compile => \$compile, execute => ($status == 3) }));
				} else {
					my $compile = $obj->{compile};
					$compile = Plack::Util::encode_html($compile);
					$compile = '&nbsp;' if $compile eq '';
					my $execute = $obj->{execute};
					$execute = Plack::Util::encode_html($execute);
					$execute = '&nbsp;' if $execute eq '';
					$responders->{html}($tmpl{EXECUTED}->fill_in(HASH => { compile => \$compile, execute => \$execute }));
				}
			}
		}
	});
}

sub _status
{
	my ($self, $obj, $responders) = @_;

	my $id = $obj->{id};
	$self->storage->get_compile_status_async($id)->cb(sub {
		my $obj = shift->recv;
		$responders->{json}($obj);
	});
}

sub _list
{
	my ($self, $obj, $responders) = @_;
	$responders->{json}($self->dispatcher->list);
}

sub _invoke
{
	my ($self, $obj, $responders) = @_;

	my $cv = AE::cv;
	my $req_id = ${$self->req_id}++;
	my $result = { keys => {}, id => $req_id };

	$cv->begin(sub {
		$self->storage->update_request_status_async($req_id, {
			execute => $obj->{execute},
			source => $obj->{source},
			title => $obj->{title},
			keys => $result->{keys},
		});
		$responders->{json}($result);
	});
	foreach my $key (@{$obj->{type}}) {
		$cv->begin;
		my $handle = $self->dispatcher->handle($key);
		my $id = ${$self->id}++;
		$handle->push_write(storable => {
			%$obj,
			type => $key,
			id => $id,
		});
		$handle->push_read(storable => sub {
			my ($handle, $obj) = @_;
			$result->{keys}{$key} = $obj->{id};
			$cv->end;
		});
	}
	$cv->end;
}

sub _result
{
	my ($self, $obj, $responders) = @_;

	my $req_id = $obj->{id};
	$self->storage->get_request_status_async($req_id)->cb(sub {
		my $req = shift->recv;
		my $source = Plack::Util::encode_html($req->{source});
		$responders->{html}($tmpl{RESULT}->fill_in(HASH => { id => \$req_id, 'keys' => $req->{keys}, source => \$source, title => \$req->{title} }));
	});
}

sub _rlist
{
	my ($self, $obj, $responders) = @_;
	$obj->{from} = ${$self->req_id} - 1 if ! defined $obj->{from} || $obj->{from} > ${$self->req_id} - 1;
	$obj->{number} ||= 20;
	$self->storage->get_requests_async($obj->{from}, $obj->{number})->cb(sub {
		my $keys = [ map { [$_->[0], Time::Duration::ago(DateTime->now->epoch - $_->[1]->epoch, 1), $_->[2] ] } @{shift->recv} ];
		$responders->{html}($tmpl{RLIST}->fill_in(HASH => { keys => \$keys, from => $obj->{from}, number => $obj->{number}, max_id => ${$self->req_id}-1 }));
	});
}

sub _cstats
{
	my ($self, $obj, $responders) = @_;
	$self->storage->get_compile_stats_async()->cb(sub {
		my $stats = shift->recv;
		$responders->{html}($tmpl{CSTATS}->fill_in(HASH => { stats => \$stats }));
	});
}

my %dispatch = (
	invoke => \&_invoke,
	list => \&_list,
	show => \&_show,
	status => \&_status,
	result => \&_result,
	rlist => \&_rlist,
	cstats => \&_cstats,
);

my %multikey = ( type => 1 );

sub call
{
	my ($self, $env) = @_;

	return sub {
		my $responder = shift;

		my $q = Plack::Request->new($env);
		my $responders = {
			html => sub {
				my $str = shift;
				$responder->($q->new_response(200, ['Content-Type' => 'text/html; charset=utf-8'], Encode::encode_utf8($str))->finalize);
			},
			json => sub {
				my $obj = shift;
				$responder->($q->new_response(200, ['Content-Type' => 'application/json; charset=utf-8'], Encode::encode_utf8(encode_json($obj)))->finalize);
			}
		};

		my (%obj) = map { my (@t) = $q->param($_); $_, exists $multikey{$_} ? [ @t ] : $t[0] } $q->param;
		if($q->script_name ne '/ccf.cgi') {
			if($q->script_name eq '/result') {
				if(length $q->path_info > 1) {
					my $req_id = $q->path_info;
					$req_id =~ s#^/##;
					$obj{command} = 'result';
					$obj{id} = $req_id;
				} else {
					$obj{command} = 'rlist';
				}
			} else { # '/results'
				$obj{command} = 'rlist';
				if(length $q->path_info > 1) {
					$q->path_info =~ m,^/(\d+)(?:/(\d+)?)?$,;
					$obj{from} = $1;
					$obj{number} = length($2) ? $2 : undef;
				}
			}
		}

		if(exists $dispatch{$obj{command}}) {
			$dispatch{$obj{command}}->($self, \%obj, $responders);
		} else {
			warn "Unknown command: $obj{command}";
		}
	};
}

1;
__END__

=head1 NAME

CCF - PSGI application module for C++ Compiler Farm

=head1 SYNOPSIS

  use Plack::Builder;
  use CCF;

  builder {
    mount '/ccf.cgi' => CCF->new(backend => [['127.0.0.1', 8888]]):
  };

=head1 DESCRIPTION

CCF is a PSGI application module for C++ Compiler Farm.

=head1 CONFIGURATION

=over 4

=item backend => I<array-ref-of-array-ref>

Specify array reference of pairs of host and port.

=back


=head1 AUTHOR

Yak! <yak_ex@mx.scn.tv>

=head1 LICENSE

Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

=cut
