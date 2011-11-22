#!/usr/bin/perl -w
use strict;
use EnVec 'parseJSON';

$/ = undef;
print join("\t", map { defined $_ ? $_ : '' }
 fixFlip($_->name), $_->type, $_->cost, $_->indicator,
 $_->PT,
 $_->loyalty,
 defined $_->handMod && $_->handMod . '/' . $_->lifeMod
), "\n" for @{parseJSON <>};

sub fixFlip {my $str = shift; $str =~ s/^[^()]+\(([^()]+)\)$/$1/; return $str; }
