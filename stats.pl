#!/usr/bin/perl -w
use strict;
use EnVec qw< loadSets loadJSON >;

my $in;
if (@ARGV) { open $in, '<', $ARGV[0] or die "$0: $ARGV[0]: $!" }
else { $in = *STDIN }
loadSets;
my $cards = loadJSON $in;
print join("\t", map { defined $_ ? $_ : '' }
 fixFlip($_->name), $_->type, $_->cost, $_->indicator,
 $_->PT,
 $_->loyalty,
 defined $_->handMod && $_->handMod . '/' . $_->lifeMod
), "\n" for @$cards;

sub fixFlip {my $str = shift; $str =~ s/^[^()]+\(([^()]+)\)$/$1/; return $str; }
