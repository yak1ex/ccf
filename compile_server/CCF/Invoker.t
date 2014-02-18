use Test::More;
use CCF::Invoker;

use YAML;
use AnyEvent;
use Sys::Hostname;

my $confname = 'config.yaml';
my $conf = YAML::LoadFile($confname);
my $confkey = hostname() =~ /^ip-|^AMAZON/ ? $^O eq 'cygwin' ? 'cygwin' : 'linux' : 'cygwin-test';
$conf = $conf->{$confkey};
my $invoker = CCF::Invoker->new(config => $conf);

my $noerror = sub { diag($_[0]->{error}) if exists $_[0]->{error}; return ! exists $_[0]->{error} };

my @basic = (
	['compile', qr/ /x, 'int main(void) { return 0; }}', [undef, qr/CCF: compilation failed by status:/]],
	['compile', qr/ /x, 'int main(void) { return 0; }', [undef, $noerror]],
	['execute', qr/ /x, 'int main(void) { return 0; }', [undef, $noerror, '', $noerror]],
	['execute', qr/ /x, 'int main(void) { return 1; }', [undef, $noerror, '', qr/CCF: exit with non-zero status: 0x0100/]],
);

my %case = (
	cygwin => [
#		@basic,
# #pragma data_seg
		['execute', qr/ /x, <<'EOF', [undef, qr/CCF: Found prohibited section\(s\):/, '', qr/CCF: exit with non-zero status:/]],
extern "C" int system(const char *command);
int func() { system("echo hoge"); return 0; }
 #pragma data_seg(".CRT$XIB")
static int(*startup[])(void) = { func };
#pragma data_seg()
int main(void) { return 0; }
EOF
# #pragma init_seg
		['execute', qr/ /x, <<'EOF', [qr/warning C4073: initializers put in library initialization area/, qr/CCF: Found prohibited section\(s\):/, '', qr/CCF: exit with non-zero status:/]],
extern "C" int system(const char *command);
#pragma init_seg(lib)
struct S { S() { system("echo hoge"); } } s;
int main(void) { return 0; }
EOF
# #pragma comment(linker, "/entry:hoge")
		['execute', qr/ /x, <<'EOF', [undef, qr/CCF: Found prohibited linker directive\(s\):/, '', qr/CCF: exit with non-zero status:/]],
#pragma comment(linker, "/entry:hoge")
int main(void) { return 0; }
EOF
# static initialization
		['execute', qr/ /x, 'extern "C" int system(const char *command); struct s { s() { system("echo hoge"); } } s; int main(void) { return 0; }',
			[undef, $noerror, '', $noerror]],
# permitted static initialization
		['execute', qr/ /x, 'extern "C" int puts(const char *s); struct s { s() { puts("hoge"); } } s; int main(void) { return 0; }',
			[undef, $noerror, qr/hoge/, $noerror]],
	],
	linux => [
#		@basic,
# __attribute__((constructor(0)))
		['execute', 'clang30', 'extern "C" int system(const char *command); void func() __attribute__((constructor(0))); void func() { system("echo hoge"); } int main(void) { return 0; }',
			['', $noerror, qr/CCF: Disallowed system call #174 rt_sigaction/, qr/CCF: exit with non-zero status:/]],
		['execute', qr/^clang3[1-4]$/, 'extern "C" int system(const char *command); void func() __attribute__((constructor(0))); void func() { system("echo hoge"); } int main(void) { return 0; }',
			['', qr/CCF: Found prohibited section\(s\):/, '', qr/CCF: exit with non-zero status:/]],
		['execute', qr/^gcc\d+$/, 'extern "C" int system(const char *command); void func() __attribute__((constructor(0))); void func() { system("echo hoge"); } int main(void) { return 0; }',
			[qr/warning: constructor priorities from 0 to 100 are reserved for the implementation/, qr/CCF: Found prohibited section\(s\):/, '', qr/CCF: exit with non-zero status:/]],
# __attribute__((constructor))
		['execute', qr/[34]\d$/x, 'extern "C" int system(const char *command); void func() __attribute__((constructor)); void func() { system("echo hoge"); } int main(void) { return 0; }',
			['', $noerror, qr/CCF: Disallowed system call #174 rt_sigaction/, qr/CCF: exit with non-zero status:/]],
# __attribute__((section (".preinit_array")))
		['execute', qr/[34]\d$/x, 'extern "C" int system(const char *command); void func() { system("echo hoge"); } __attribute__((section (".preinit_array")))  void(*t[1])(void) = { func };  int main(void) { return 0; }',
			['', qr/CCF: Found prohibited section\(s\): \.preinit_array/, '', qr/CCF: exit with non-zero status:/]],
# __attribute__((section (".init_array")))
		['execute', qr/[34]\d$/x, 'extern "C" int system(const char *command); void func() { system("echo hoge"); } __attribute__((section (".init_array")))  void(*t[1])(void) = { func };  int main(void) { return 0; }',
			['', $noerror, qr/CCF: Disallowed system call #174 rt_sigaction/, qr/CCF: exit with non-zero status:/]],
# __attribute__((section (".init")))
		['execute', qr/[34]\d$/x, 'extern "C" int system(const char *command); void func() __attribute__((section (".init"))); void func() { system("echo hoge"); } int main(void) { return 0; }',
			['', qr/CCF: Found prohibited section\(s\): \.init/, '', qr/CCF: exit with non-zero status:/]],
# static initialization
		['execute', qr/[34]\d$/x, 'extern "C" int system(const char *command); struct s { s() { system("echo hoge"); } } s; int main(void) { return 0; }',
			['', $noerror, qr/CCF: Disallowed system call #174 rt_sigaction/, qr/CCF: exit with non-zero status:/]],
# permitted static initialization
		['execute', qr/[34]\d$/x, 'extern "C" int puts(const char *s); struct s { s() { puts("hoge"); } } s; int main(void) { return 0; }',
			['', $noerror, qr/hoge/, $noerror]],
	],
	'cygwin-test' => [
		@basic,
	],
);

sub test
{
	my ($result, $ckey, $spec, $idx, $idx2) = @_;
	my $action = $spec->[3][$idx2];
	return unless defined $action;
	my $type = $idx2 >= 2 ? 'execute' : 'compile/link';
	my $key = $idx2 % 2 ? 'error' : 'output';
	my $name = "IDX: $idx IDX2: $idx2 COMPILER: $ckey for $key in $type";
	if(my $ref = ref $action) {
		if($ref eq 'CODE') {
			ok($action->($result), $name);
		} elsif($ref eq 'Regexp') {
			like($result->{$key}, $action, $name);
		}
	} else {
		is($result->{$key}, $action, $name);
	}
}

while(my ($idx, $spec) = each @{$case{$confkey}}) {
	my $re = ref $spec->[1] eq 'Regexp' ? $spec->[1] : qr/^\Q$spec->[1]\E$/;
	my @key = grep { $_ ne 'GLOBAL' && $_ =~ $re } keys %$conf;
	foreach my $key (@key) {
		my $cv = AE::cv;
		if($spec->[0] eq 'compile') {
			$invoker->compile($key, $spec->[2], sub {
				my ($rc, $result) = @_;
				test($result, $key, $spec, $idx, 0);
				test($result, $key, $spec, $idx, 1);
				$cv->send;
			});
		} else { # 'execute'
			$invoker->link($key, $spec->[2], sub {
				my ($rc, $result, $out) = @_;
				test($result, $key, $spec, $idx, 0);
				test($result, $key, $spec, $idx, 1);
				$invoker->execute($key, $out, sub{
					my ($rc, $result) = @_;
					test($result, $key, $spec, $idx, 2);
					test($result, $key, $spec, $idx, 3);
					unlink $out;
					$cv->send;
				});
			});
		}
		$cv->recv;
	}
}

# TODO: plan tests
done_testing;
