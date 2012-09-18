#!/usr/bin/perl

use strict;
use warnings;

use Test::Simple tests => 29;

use CCF::Base64Like;

# error condition

my $res = eval { CCF::Base64Like::encode(-1) };
ok(!defined($res));
ok($@ =~/^Can not accept negative value/);

ok(CCF::Base64Like::encode(0) eq 'A');
ok(CCF::Base64Like::encode(25) eq 'Z');
ok(CCF::Base64Like::encode(26) eq 'a');
ok(CCF::Base64Like::encode(51) eq 'z');
ok(CCF::Base64Like::encode(52) eq '0');
ok(CCF::Base64Like::encode(61) eq '9');
ok(CCF::Base64Like::encode(62) eq '-');
ok(CCF::Base64Like::encode(63) eq '_');
ok(CCF::Base64Like::encode(64) eq 'BA');
ok(CCF::Base64Like::encode(4095) eq '__');
ok(CCF::Base64Like::encode(4096) eq 'BAA');
ok(CCF::Base64Like::encode(4097) eq 'BAB');

ok(CCF::Base64Like::decode('') == 0);
ok(CCF::Base64Like::decode('A') == 0);
ok(CCF::Base64Like::decode('Z') == 25);
ok(CCF::Base64Like::decode('a') == 26);
ok(CCF::Base64Like::decode('z') == 51);
ok(CCF::Base64Like::decode('0') == 52);
ok(CCF::Base64Like::decode('9') == 61);
ok(CCF::Base64Like::decode('-') == 62);
ok(CCF::Base64Like::decode('_') == 63);
ok(CCF::Base64Like::decode('BA') == 64);
ok(CCF::Base64Like::decode('__') == 4095);
ok(CCF::Base64Like::decode('BAA') == 4096);
ok(CCF::Base64Like::decode('BAB') == 4097);

ok(CCF::Base64Like::decode(CCF::Base64Like::encode(123456789)) == 123456789);
ok(CCF::Base64Like::encode(CCF::Base64Like::decode('DCBA')) eq 'DCBA');
