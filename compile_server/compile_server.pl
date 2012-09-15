#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket; # tcp_server
use AnyEvent::Util; # run_cmd

use English;
use YAML;
use File::Temp;

BEGIN {
	if($^O eq 'cygwin') {
		use Encode;
		use Win32::Codepage::Simple qw(get_codepage);
	}
}

use constant {
	REQUESTED => 1,
	COMPILING => 2,
	RUNNING => 3,
	FINISHED => 4,
};

# TODO: clear command
# TODO: FINISHED reaper
# TODO: Optional log
# TODO: Using sandbox

my $conf = YAML::LoadFile('config.yaml');

sub is_cygwin2native
{
	my ($type) = @_;
	return exists $conf->{$OSNAME}{$type}{cygwin2native} && $conf->{$OSNAME}{$type}{cygwin2native} eq 'true';
}

sub setenv
{
	my ($type) = @_;

	return sub {
		foreach my $hash (@{$conf->{$OSNAME}{$type}{env}}) {
			foreach my $name (keys %$hash) {
				my $t = $hash->{$name};
				$t =~ s/%([^%]*)%/exists($ENV{$1}) ? $ENV{$1} : ''/eg;
				if($name eq 'PATH') {
# NOTE: I can not understand but the following line causes out of memory error on my environment.
#					$t = join ':', map { Cygwin::win_to_posix_path($_, 'true') } split /;/, $t;
					$t = join ':', map { $_ = `cygpath -u '$_'`; s/\s*$//; $_ } split /;/, $t;
#					$t .= ':' . $ENV{PATH};
				}
				$ENV{$name} = $t;
			}
		}
	};
}

sub make_arg
{
	my ($type, $mode, $input, $output, $capture) = @_;
	my @arg;
	if(is_cygwin2native($type)) {
		$input = Cygwin::posix_to_win_path($input);
		$output = Cygwin::posix_to_win_path($output);
		(@arg) = (on_prepare => setenv($type)) if exists($conf->{$OSNAME}{$type}{env});
	}

# TODO: error check
#	return map { $_ eq '$input' ? $input : $_ eq '$output' ?  $output : $_ } @{$conf->{$OSNAME}{$type}{$mode}};
	my @res = map { my $t = $_; $t =~ s/\$input/$input/; $t =~ s/\$output/$output/; $t; } @{$conf->{$OSNAME}{$type}{$mode}}; 
	print join(' ', @res), "\n";
	return ([@res], '<', '/dev/null', '>', $capture, '2>', $capture, @arg);
}

sub dec
{
	my ($type, $str) = @_;
	return $str unless is_cygwin2native($type);
	return Encode::decode('CP'.get_codepage(), $str);
}

my %status;
my $id = 0;

sub invoke
{
	my ($handle, $json) = @_;

	my $curid = $id++;

	$status{$curid}{status} = REQUESTED;
	$handle->push_write(json => { id => $curid });
# TODO: Other sanity check
	if(!exists $json->{type} || !exists $conf->{$OSNAME}{$json->{type}}) {
		$status{$curid}{status} = FINISHED;
		$status{$curid}{compile} = 'CCF: Unknown compiler type.';
		return;
	}

	my $fh = File::Temp->new(UNLINK=>0,SUFFIX=>'.cpp');
	print $fh $json->{source};
	close $fh;
	my $source = $fh->filename;
	my $fho = File::Temp->new(UNLINK=>0,SUFFIX=>($json->{execute} eq 'true' ? '.exe' : '.o'));
	close $fho;
	my $out = $fho->filename;

	$status{$curid}{status} = COMPILING;
	if($json->{execute} eq 'true') {
		run_cmd(make_arg($json->{type}, 'link', $source, $out, \$status{$curid}{compile}))->cb(sub {
			$status{$curid}{compile} = dec($json->{type}, $status{$curid}{compile});
print "---compile begin---\n";
print $status{$curid}{compile};
print "---compile  end ---\n";
			$status{$curid}{status} = RUNNING;
			chmod 0711, $out if is_cygwin2native($json->{type});
			run_cmd([$out], '<', '/dev/null', '>', \$status{$curid}{execute}, '2>', \$status{$curid}{execute})->cb(sub{
print "---execute begin---\n";
print $status{$curid}{execute};
print "---execute  end ---\n";
				unlink $out;
				unlink $source;
				$status{$curid}{status} = FINISHED;
			});
		});
	} else {
		my $env = setenv($json->{type});
		run_cmd(make_arg($json->{type}, 'compile', $source, $out, \$status{$curid}{compile}))->cb(sub {
			$status{$curid}{compile} = dec($json->{type}, $status{$curid}{compile});
print "---compile begin---\n";
print $status{$curid}{compile};
print "---compile  end ---\n";
			unlink $out;
			unlink $source;
			$status{$curid}{status} = FINISHED;
		});
	}
}

sub status
{
	my ($handle, $json) = @_;

# TODO: check unknown ID
	$handle->push_write(json => { id => $json->{id}, status => $status{$json->{id}}{status} });
}

sub result
{
	my ($handle, $json) = @_;

	if(exists $status{$json->{id}}{execute}) {
		$handle->push_write(json => { id => $json->{id}, execute => $status{$json->{id}}{execute}, compile => $status{$json->{id}}{compile} });
	} else {
		$handle->push_write(json => { id => $json->{id}, compile => $status{$json->{id}}{compile} });
	}
}

sub list
{
	my ($handle, $json) = @_;

	$handle->push_write(json => { map { $_ => $conf->{$OSNAME}{$_}{name} } grep { $_ ne 'GLOBAL' } keys %{$conf->{$OSNAME}} });
}

my %handler = (
	invoke => \&invoke,
	status => \&status,
	result => \&result,
	list => \&list,
);

tcp_server '127.0.0.1', 8888, sub {
	my ($fh, $host, $port) = @_;

	print "connect\n";

	my $handle; $handle = AnyEvent::Handle->new(
		fh => $fh,
		on_eof => sub { $handle->destroy; },
		on_error => sub { $handle->destroy; },
	);
	my @handler; @handler = (json => sub {
		print "handler\n";
		my ($handle, $json) = @_;
		if(exists $json->{command} && exists $handler{$json->{command}}) {
			$handler{$json->{command}}->($handle, $json);
		} else {
			my $command = '';
			$command = $json->{command} if exists $json->{command};
			$command = "Unknown command `$command'";
			warn $command;
			$handle->push_write(json => { error => $command });
		}
		$handle->push_read(@handler);
	});
	$handle->push_read(@handler);
};

AnyEvent->condvar->recv;
