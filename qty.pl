#!/usr/bin/perl -w
use strict;
use JSON::Syck;

$/ = undef;
my $json = <>;
my $data = JSON::Syck::Load($json);
print scalar @$data, "\n";
