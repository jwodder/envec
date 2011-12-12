#!/usr/bin/perl -w
use strict;
use Encode;
use Getopt::Std;
use EnVec ('loadSets', 'parseJSON');

my %opts;
getopts('P', \%opts) || exit 2;

my %rarities = ('Mythic Rare' => 'Mythic',
 map { $_ => $_ } qw< Common Uncommon Rare Land Special Promo >);
if ($opts{P}) { $rarities{$_} = "($rarities{$_}) show" for keys %rarities }

my %sets = ();
loadSets;
$/ = undef;
for my $card (@{parseJSON <>}) {
 my $stats = stats($card->part1);
 $stats->{part2} = stats($card->part2) if $card->isMultipart;
 push @{$sets{$_->{set}}}, [
  $_->{number} || '',
  $rarities{$_->{rarity}} || die('Unknown rarity "', $_->{rarity}, '" for ',
				  $card->name, ' in ', $_->{set}),
  $stats
 ] for @{$card->printings};
}

for my $set (sort cmpSets keys %sets) {
 ### Start list
 my @cards = map {
   $_->[0] .= '.' if $_->[0];
   if ($_->[2]{part2}) { ($_, [ '//', '', $_->[2]{part2} ]) }
   else { ($_) }
  } sort { $a->[0] <=> $b->[0] || $a->[2]{name} cmp $b->[2]{name} }
   @{$sets{$set}};
 my $nameLen = maxField('nameLen', @cards);
 my $typeLen = maxField('typeLen', @cards);
 my $costLen = maxField('costLen', @cards);
 my $extraLen = maxField('extraLen', @cards);
 print <<EOT if $opts{P};
/typeStart $nameLen 2 add em mul def
/extraStart typeStart $typeLen add 2 add em mul def
/costStart extraStart $extraLen add 2 add em mul def
/rareStart costStart $costLen add 2 add em mul def
EOT
 if ($set eq 'Planechase' || $set eq 'Archenemy') {
  my(@special, @normal);
  for (@cards) {
   if ($_->[4] =~ /^(Plane|(Ongoing )?Scheme)\b/) { push @special, $_ }
   else { push @normal, $_ }
  }
  showCards @special;
  print($opts{P} ? "nameStart y moveto (---) show linefeed\n" : "---\n");
  showCards @normal;
 } else { showCards @cards }
 ### End list
 print "showpage\n" if $opts{P};
}

sub chrlength($) { length(decode_utf($_[0], Encode::FB_CROAK)) }

sub stats($) {
 my $card = shift;
 my $name = $card->name;
 my $type = $card->type;
 my $cost = $card->cost || '--';
 $cost .= ' [' . $card->indicator . ']' if $card->indicator;
 my $extra = $card->PT || $card->loyalty || $card->HandLife || '';
 my $costLen = length $cost;
 if ($opts{P}) {
  (my $cost2 = $cost) =~ s/\{[^\d{}]+\}/./g;
  $cost2 =~ s/\{(\d+)\}/$1/g;
  $costLen = length $cost2;
 }
 return {
  name => $name,
  nameLen => chrlength $name,
  type => $type,
  typeLen => chrlength $type,
  cost => $cost,
  costLen => $costLen,
  extra => $extra,
  extraLen => length $extra,
 };
}

sub maxField($@) {
 my $field = shift;
 my $max = 0;
 for (@_) {
  $max = $_->{$field} if $_->{$field} > $max;
  $max = $_->{part2}{$field} if $_->{part2} && $_->{part2}{$field} > $max;
 }
 return $max;
}

sub psify($) {
 my $str = shift;
 $str =~ s/([(\\)])/\\$1/g;
 $str =~ s/’/'/g;
 $str =~ s/Æ/\\341/g;
 $str =~ s/à/a) bs (\\301/g;
 $str =~ s/á/a) bs (\\302/g;
 $str =~ s/é/e) bs (\\302/g;
 $str =~ s/í/\\365) bs (\\302/g;
 $str =~ s/ú/u) bs (\\302/g;
 $str =~ s/â/a) bs (\\303/g;
 $str =~ s/û/u) bs (\\303/g;
 $str =~ s/ö/o) bs (\\310/g;
 return "($str) show\n";
}

sub showCards(@) {
 if ($opts{P}) {
  for my $card (@_) {
   print '(' . $card->[0] . ") showNum\n" if $card->[0];
   print 'nameStart y moveto ', psify($card->[2]{name});
   print 'typeStart y moveto ', psify($card->[2]{type});
   print 'extraStart y moveto ', psify($card->[2]{extra}) if $card->[2]{extra};
   print 'costStart y moveto ';
   print($2 ? "$2\n" : psify($1 || $3))
    while $card->[2]{cost} =~ /\G(\{(\d+)\}|\{([^\d{}]+)\}|([^{}]+))/g;
   print 'rareStart y moveto ', $card->[1], "\n" if $card->[1];
   print "linefeed\n\n";
  }
 } else {
  printf "%4s %-*s  %-*s  %-*s  %-*s  %s\n", $_->[0], $nameLen, $_->[2]{name},
   $typeLen, $_->[2]{type}, $extraLen, $_->[2]{extra}, $costLen, $_->[2]{cost},
   $_->[1] for @_
 }
}
