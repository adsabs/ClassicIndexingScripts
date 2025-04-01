#!/usr/bin/perl
#
# $Id$ 
#
# Normalizes author names given in stdin as *.words files:
#     docid<tab>auth1<tab>auth2<tab>...
#
#
# Example usage: 
#    to create a list of bibcode-authors in a database:
#       gunzip -c author.words.gz | ./norm_authors.pl > norm_author.words
#
# $Log$
#

use strict;
use integer;

my $script = $0;
$script =~ s:^.*/::;

while (<>) {
    chop;
    my ($id,@rest) = split(/\t/);
    print join("\t", $id, map { normalize_author($_) } @rest), "\n";
}

sub normalize_author {
    my $a = lc(shift);

    # should check for Jr. Sr. etc...
    $a =~ s/,\s(\w).*$/, $1/g;
    $a =~ s/\b(.)/\u$1/g;

    return $a;
}
