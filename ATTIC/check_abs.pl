#!/usr/bin/perl
#
# Checks abstracts for weird stuff
#

use strict;
use warnings;
use ADS::Abstracts::IO;
use ADS::Abstracts::Entities;
my ($id,$absfile);

# catch these cases in text
my $latex_re = qr/[{}\$]/;
my $halpha_re = qr/\bH(:?alpha|beta|gamma)\b/i;
my $decoder = ADS::Abstracts::Entities::Resolver->new(WarnFunc => sub { print "$id\tENTITY\t", @_; });

# input is file containing IDs (accnos) and abstract files
while (<STDIN>) {
    chop;
    ($id,$absfile) = split;    
    my $field = ReadAbs($absfile);
    my @fields = keys %$field;
    my ($f,@matches);
    foreach $f (qw(XTL ABS AFF)) {
	next unless (defined($field->{$f}));
	print $id, "\tLATEX\t", join("\t",@matches), "\n"
	    if (@matches = ($field->{$f} =~ /(\S*$latex_re\S*)/g));
	print $id, "\tHALPHA\t", join("\t",@matches), "\n"
	    if (@matches = ($field->{$f} =~ /(\S*$halpha_re\S*)/g));
    }
    foreach $f (@fields) {
	next unless (defined($field->{$f}));
	$decoder->decode($field->{$f});
    }
    
}

