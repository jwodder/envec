#!/usr/bin/perl -w
use strict;
use Encode;
use Getopt::Std;
use EnVec ('loadSets', 'parseJSON', 'cmpSets');

sub chrlength($);
sub stats($);
sub maxField($@);
sub psify($);
sub showCards(@);

my %rarities = ('Mythic Rare' => 'Mythic',
 map { $_ => $_ } qw< Common Uncommon Rare Land Special Promo >);

my %opts;
getopts('Pd:', \%opts) || exit 2;
my $prelude = $opts{P} && join('', <DATA>);
my $dir = $opts{d} || 'lists';
-d $dir or mkdir $dir or die "$0: $dir/: $!";

my %sets = ();
loadSets;
$/ = undef;
for my $card (@{parseJSON <>}) {
 my $stats = stats($card->part1);
 $stats->{part2} = stats($card->part2) if $card->isMultipart;
 for (@{$card->printings}) {
  die 'Unknown rarity "', $_->rarity, '" for ', $card->name, ' in ', $_->set
   if !exists $rarities{$_->rarity};
  push @{$sets{$_->set}}, [ $_->effectiveNum, $rarities{$_->rarity}, $stats ];
 }
}

for my $set (sort cmpSets keys %sets) {
 (my $file = $set) =~ tr/ "'/_/d;
 $file = "$dir/$file." . ($opts{P} ? 'ps' : 'txt');
 open my $out, '>', $file or die "$0: $file: $!";
 select $out;
 my @cards = map {
  $_->[0] .= '.' if $_->[0];
  $_->[2]{part2} ? ($_, [ '//', '', $_->[2]{part2} ]) : ($_);
 } sort { $a->[0] <=> $b->[0] || $a->[2]{name} cmp $b->[2]{name} }
  @{$sets{$set}};
 my $nameLen = maxField('nameLen', @cards);
 my $typeLen = maxField('typeLen', @cards);
 my $costLen = maxField('costLen', @cards);
 my $extraLen = maxField('extraLen', @cards);
 if ($opts{P}) {
  print $prelude, <<EOT
/typeStart $nameLen 2 add em mul def
/extraStart typeStart $typeLen add 2 add em mul def
/costStart extraStart $extraLen add 2 add em mul def
/rareStart costStart $costLen add 2 add em mul def
EOT
 } else { print "$set\n" }
 if ($set eq 'Planechase' || $set eq 'Archenemy') {
  my(@special, @normal);
  for (@cards) {
   if ($_->[4] =~ /^(Plane|(Ongoing )?Scheme)\b/) { push @special, $_ }
   else { push @normal, $_ }
  }
  showCards @special;
  print($opts{P} ? "linefeed nameStart y moveto (---) show\n" : "---\n");
  showCards @normal;
 } else { showCards @cards }
 print "showpage\n" if $opts{P};
 close $out;
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
  name     => $name,
  nameLen  => chrlength $name,
  type     => $type,
  typeLen  => chrlength $type,
  cost     => $cost,
  costLen  => $costLen,
  extra    => $extra,
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
 $str =~ s/à/) show (a) (\\301) accent (/g;
 $str =~ s/á/) show (a) (\\302) accent (/g;
 $str =~ s/é/) show (e) (\\302) accent (/g;
 $str =~ s/í/) show (\\365) (\\302) accent (/g;
 $str =~ s/ú/) show (u) (\\302) accent (/g;
 $str =~ s/â/) show (a) (\\303) accent (/g;
 $str =~ s/û/) show (u) (\\303) accent (/g;
 $str =~ s/ö/) show (o) (\\310) accent (/g;
 return "($str) show\n";
}

sub showCards(@) {
 if ($opts{P}) {
  for my $card (@_) {
   print "\n", "linefeed\n";
   print '(' . $card->[0] . ") showNum\n" if $card->[0];
   print 'nameStart y moveto ', psify($card->[2]{name});
   print 'typeStart y moveto ', psify($card->[2]{type});
   print 'extraStart y moveto ', psify($card->[2]{extra}) if $card->[2]{extra};
   print 'costStart y moveto ';
   print($2 ? "$2\n" : $3 ? "$3$4\n" : psify($1 || $5))
    while $card->[2]{cost} =~ /\G(?:\{(\d+)\}|\{(\D)\}|\{(.)\/(.)\}|([^{}]+))/g;
   print $card->[1], "\n" if $card->[1];
  }
 } else {
  printf "%4s %-*s  %-*s  %-*s  %-*s  %s\n", $_->[0], $nameLen, $_->[2]{name},
   $typeLen, $_->[2]{type}, $extraLen, $_->[2]{extra}, $costLen, $_->[2]{cost},
   $_->[1] for @_
 }
}

__DATA__
%!PS-Adobe-3.0

%/fontsize 10 def
%/lineheight 12 def
%/Monaco findfont fontsize scalefont setfont

/fontsize 8 def
/lineheight 10 def
/Times-Roman findfont fontsize scalefont setfont

/em (M) stringwidth pop def

/circRad fontsize 0.4 mul def
/circWidth circRad 2.1 mul def  % width of a "cell" containing a circle

/pageNo 0 def
/buf 3 string def

/accent { exch dup show gsave stringwidth pop neg 0 rmoveto show grestore } def

/linefeed {
 y 72 lineheight add le { showpage startPage } if
 /y y lineheight sub def
} def

/startPage {
 /pageNo pageNo 1 add def
 66 725 moveto ($set) show
 /pns pageNo buf cvs def
 546 pns stringwidth pop sub 725 moveto
 pns show
 66 722.5 moveto 480 0 rlineto stroke
 /y 722 def
} def

/nameStart 72 def
/showNum { dup stringwidth pop nameStart exch sub y moveto show } def

/setcenter {
 currentpoint
 fontsize  2 div add /cy exch def
 circWidth 2 div add /cx exch def
} def

/disc {
 setcenter
 gsave
 setrgbcolor
 newpath cx cy circRad 0 360 arc fill
 grestore
 circWidth 0 rmoveto
} def

/W { 1 1 0.53 disc } def
/U { 0 0 1 disc } def
/B { 0 0 0 disc } def
/R { 1 0 0 disc } def
/G { 0 1 0 disc } def
/X { (X) show } def

/hybrid {
 gsave
 setcenter
 setrgbcolor newpath cx cy circRad 225 45 arc fill  % bottom half
 setrgbcolor newpath cx cy circRad 45 225 arc fill  % top half
 grestore
 circWidth 0 rmoveto
} def

/WU { 1 1 0.53  0 0 1  hybrid } def
/WB { 1 1 0.53  0 0 0  hybrid } def
/UB { 0 0 1     0 0 0  hybrid } def
/UR { 0 0 1     1 0 0  hybrid } def
/BR { 0 0 0     1 0 0  hybrid } def
/BG { 0 0 0     0 1 0  hybrid } def
/RG { 1 0 0     0 1 0  hybrid } def
/RW { 1 0 0     1 1 0.53 hybrid } def
/GW { 0 1 0     1 1 0.53 hybrid } def
/GU { 0 1 0     0 0 1  hybrid } def
/2W { 0.8 0.8 0.8  1 1 0.53  hybrid } def
/2U { 0.8 0.8 0.8  0 0 1     hybrid } def
/2B { 0.8 0.8 0.8  0 0 0     hybrid } def
/2R { 0.8 0.8 0.8  1 0 0     hybrid } def
/2G { 0.8 0.8 0.8  0 1 0     hybrid } def

/phi {
 gsave
 circWidth neg 0 rmoveto
 setcenter
 setrgbcolor
 newpath cx cy circRad 0 360 arc clip
 newpath
 currentlinewidth 2 div setlinewidth
 cx cy circRad 2 div 0 360 arc
 cx cy circRad add moveto
 0 circRad -2 mul rlineto
 stroke
 grestore
} def

/WP { W 0 0 0 phi } def
/UP { U 1 1 1 phi } def
/BP { B 1 1 1 phi } def
/RP { R 1 1 1 phi } def
/GP { G 0 0 0 phi } def

/Mythic   { rareStart y moveto (Mythic)   show } def
/Rare     { rareStart y moveto (Rare)     show } def
/Uncommon { rareStart y moveto (Uncommon) show } def
/Common   { rareStart y moveto (Common)   show } def
/Land     { rareStart y moveto (Land)     show } def
/Special  { rareStart y moveto (Special)  show } def
/Promo    { rareStart y moveto (Promo)    show } def

startPage
