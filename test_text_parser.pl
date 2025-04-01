#!/bin/env perl
#

use lib '/proj/ads/soft/adsperl/lib/perl5';

use strict;
use warnings;
use Test::More qw(no_plan);

BEGIN { 
    use_ok('ADS::Abstracts::Index');
    use_ok('ADS::Abstracts::Utils');
};

my $usage = "Usage: $0 [OPTIONS] [install]
Options are:
  -d, --debug    print lots of debugging info
  -n, --dry-run  setup files for test but don't run the test itself
  -l, --loop     keep feeding the same data to the parser after the basic
                 tests are completed (useful to find memory leaks)
If 'install' is given as the last argument, the version of cleanup
in cgi-bin/install is used
";

my $dryrun = 0;
my $debug = 0;
my $loop = 0;

while (@ARGV and $ARGV[0] =~ /^-/) {
    my $s = shift(@ARGV);
    if ($s eq '-n' or $s eq '--dry-run') {
	$dryrun++;
    } elsif ($s eq '-d' or $s eq '--debug') {
	$debug++;
    } elsif ($s eq '-l' or $s eq '--loop') {
	$loop++;
    } elsif ($s eq '-h' or $s eq '--help') {
	die $usage;
    } else {
	die "$0: unknown option \"$s\"\n", $usage;
    }
}

my $install = (@ARGV and $ARGV[0] eq 'install') ? shift(@ARGV) : '';

my $thisdir = $0; $thisdir =~ s:/[^/]+$::;
my $test_dir = './test_text_parser';
my $test_input = $test_dir . '/text.input';
my $test_output = $test_dir . '/text.output';
unlink($test_output) if (-f $test_output);

my $class = 'ADS::Abstracts::Index::Tokenizer::Text';
my %f = ("/proj/ads/www/cgi/bin/$install/$ENV{HOSTTYPE}/maint/cleanup" => "text_parser.$ENV{HOSTTYPE}",
	 '/proj/ads/abstracts/config/text_ast.kill'        => 'text.kill',
	 '/proj/ads/abstracts/config/text_ast.kill_sens'   => 'text.kill_sens',
	 '/proj/ads/abstracts/links/unicode.ent'     => 'unicode.ent',
	 '/proj/ads/abstracts/config/text.trans'      => 'text.trans');
foreach (keys %f) {
    system("cp -p $_ $test_dir/$f{$_}");
    system("chmod a+w $test_dir/$f{$_} 2>/dev/null");
}

ok(-f $test_input, "found input file $test_input");
my $t = $class->new(field      => 'text',
		    configdir  => $test_dir,
		    file       => $test_output,
		    pipe       => "$thisdir/text_parser $test_dir $test_output",
		    splitwords => \&ADS::Abstracts::Utils::SplitText,
		    debug      => $debug,
		    quiet      => 0,
		    debug_pipe => $debug);
ok($t, 'created new text parser object');

open(my $ifh, $test_input) or die "cannot open input file $test_input: $!";
my $n = 1;
my @strings;
while (<$ifh>) {
    chop;
    my @string = $t->tokenize($_);
    warn "tokenized string is:\n", @string, "\n" if ($debug);
    $t->write($n++,@string);
    push(@strings,@string) if ($loop);
}

$t->closefh;
undef($ifh);

ok(-f $test_output, "found output file $test_output");
open($ifh,$test_output) or 
    die "cannot open input file $test_output: $!";

if ($dryrun) {
    while (<$ifh>) {    
	print $_;
    }
    exit(0);
}

ok(-f "$test_output.should", "found reference file $test_output.should");
open(my $sfh,"$test_output.should") or 
    die "cannot open input file $test_output.should: $!";

$n = 1;
while (1) {
    $_ = <$ifh>; my @is = defined($_) ? split : ();
    $_ = <$sfh>; my @should = defined($_) ? split : ();
    last unless (@is or @should);
    chop;
    is_deeply(\@is,\@should, $_);
}
undef($ifh);
undef($sfh);

# now feed some junk to the parser to see if it dies
$t = $class->new(field      => 'text',
		 configdir  => $test_dir,
		 file       => '/dev/null',
		 pipe       => "$thisdir/text_parser $test_dir /dev/null",
		 splitwords => \&ADS::Abstracts::Utils::SplitText,
		 debug      => $debug,
		 quiet      => 0,
		 debug_pipe => $debug);
$n = 1;
ok(-f "$test_input.junk", "found input file $test_input.junk");
open($ifh,"$test_input.junk") or
    die "cannot open input file $test_input.junk: $!";
while (<$ifh>) {
    chop;
    ok($t->write($n,$t->tokenize($_)), "junk test no. ". $n);
		$n++;
}

exit(0) unless ($loop);

warn "Now looping on input forver (hit CTRL-C to stop)\n";
ok($t, 'created new text parser object');
$n = 1;
while (1) {
    $t->write($n++,@strings);
    ok($n++, "loop test $n") if (0 == ($n % 100));
}
