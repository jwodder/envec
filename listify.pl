#!/usr/bin/perl -w
use strict;
use Encode;
use Getopt::Std;
use EnVec ('loadSets', 'loadJSON', 'allSets');

sub chrlength($);
sub stats($);
sub maxField($@);
sub psify($);
sub texify($);
sub showCards(@);

my($nameLen, $typeLen, $costLen, $extraLen);

my %rarities = ('Mythic Rare' => 'Mythic',
 map { $_ => $_ } qw< Common Uncommon Rare Land Special Promo >);

my %opts;
getopts('LPd:o:', \%opts) || exit 2;
print STDERR "$0: You may specify -L or -P, but not both\n" and exit 2
 if $opts{L} && $opts{P};
print STDERR "$0: Single-file output is not implemented for LaTeX/PostScript\n"
 and exit 2 if $opts{o} && ($opts{L} || $opts{P});
my $dir = $opts{d} || 'lists';
$opts{o} or -d $dir or mkdir $dir or die "$0: $dir/: $!";

my $prelude = $opts{L} ? <<'EOT' : $opts{P} ? join('', <DATA>) : '';
\documentclass{article}
\usepackage[top=1in,bottom=1in,left=1in,right=1in]{geometry}
\usepackage{graphicx}
\newcommand{\img}[1]{\includegraphics[height=2ex]{../../rules/img/#1}}
\usepackage{longtable}
\begin{document}
EOT

loadSets;
my %sets = ();
for my $card (@{loadJSON shift}) {
 my $stats = stats($card->part1);
 $stats->{part2} = stats($card->part2) if $card->isMultipart;
 for (@{$card->printings}) {
  ###(my $rarity = $_->rarity) =~ s/ \([CUR]\d+\)$//;
  my $rarity = $_->rarity;
  die "Unknown rarity \"$rarity\" for ", $card->name, ' in ', $_->set
   if !exists $rarities{$rarity};
  push @{$sets{$_->set}}, [ $_->effectiveNum, $rarities{$rarity}, $stats ];
 }
}

my $out;
open $out, '>', $opts{o} or die "$0: $opts{o}: $!" if $opts{o};
for my $set (grep { exists $sets{$_} } allSets) {
 if (!$opts{o}) {
  (my $file = $set) =~ tr/ "'/_/d;
  $file = "$dir/$file." . ($opts{L} ? 'tex' : $opts{P} ? 'ps' : 'txt');
  open $out, '>', $file or die "$0: $file: $!";
 }
 select $out;
 my @cards = map {
  $_->[0] .= '.' if $_->[0];
  $_->[2]{part2} ? ($_, [ '//', '', $_->[2]{part2} ]) : ($_);
 } sort { ($a->[0] || 0) <=> ($b->[0] || 0) || $a->[2]{name} cmp $b->[2]{name} }
  @{$sets{$set}};
 $nameLen = maxField('nameLen', @cards);
 $typeLen = maxField('typeLen', @cards);
 $costLen = maxField('costLen', @cards);
 $extraLen = maxField('extraLen', @cards);
 if ($opts{L}) {
  print $prelude, <<EOT
\\section*{$set}
\\begin{longtable}[c]{rl|l|l|l|l}
No. & Name & Type & & Cost & \\\\ \\hline \\endhead
EOT
 } elsif ($opts{P}) {
  print $prelude, <<EOT
/setname ($set) def
/typeStart nameStart $nameLen 2 add em mul add def
/extraStart typeStart $typeLen 2 add em mul add def
/costStart extraStart $extraLen 2 add em mul add def
/rareStart costStart $costLen 2 add em mul add def
startPage
EOT
 } else { print "$set\n" }
 if ($set =~ /^Planechase( 2012 Edition)?$/ || $set eq 'Archenemy') {
  my(@special, @normal);
  for (@cards) {
   if ($_->[2]{type} =~ /^(Plane|Phenomenon|(Ongoing )?Scheme)\b/) {
    push @special, $_
   } else { push @normal, $_ }
  }
  showCards @special;
  print($opts{L} ? "\\hline\n"
	: $opts{P} ? "linefeed nameStart y moveto (---) show\n"
	: "---\n");
  showCards @normal;
 } else { showCards @cards }
 if ($opts{L}) { print "\\end{longtable}\n\\end{document}\n" }
 elsif ($opts{P}) { print "showpage\n" }
 elsif ($opts{o}) { print "\n" }
 close $out if !$opts{o};
}

sub chrlength($) {
 my $str = shift;
 # SDF's version of Encode.pm has some sort of bug that causes &decode_utf8 to
 # overwrite its first argument with (I assume) the argument's trailing
 # unconvertible characters, even when FB_CROAK is supplied.  Even more
 # infuriating, passing the return value of &shift directly to &decode_utf8
 # doesn't protect the argument to &chrlength.
 return length(decode_utf8($str, Encode::FB_CROAK));
 ### Would changing decode_utf8(...) to decode('utf8', ...) solve the problem?
}

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
  $max = $_->[2]{$field} if $_->[2]{$field} > $max;
  $max = $_->[2]{part2}{$field}
   if $_->[2]{part2} && $_->[2]{part2}{$field} > $max;
 }
 return $max;
}

sub psify($) {
 ### Rewrite this to use the "ISOLatin1Encoding" encoding vector in PostScript.
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
 $str =~ s/--/\\320/g;
 return "($str) show\n";
}

sub texify($) {
 my $str = shift;
 $str =~ s/([{&}])/\\$1/g;
 $str =~ s/(^|(?<=\s))"/``/g;
 $str =~ s/(^|(?<=\s))'/``/g;
 $str =~ s/"/''/g;
 $str =~ s/’/'/g;
 $str =~ s/Æ/\\AE{}/g;
 $str =~ s/à/\\`a/g;
 $str =~ s/á/\\'a/g;
 $str =~ s/é/\\'e/g;
 $str =~ s/í/\\'{\\i}/g;
 $str =~ s/ú/\\'u/g;
 $str =~ s/â/\\^a/g;
 $str =~ s/û/\\^u/g;
 $str =~ s/ö/\\"o/g;
 $str =~ s/--/---/g;
 return $str;
}

sub showCards(@) {
 if ($opts{L}) {
  for my $card (@_) {
   print $card->[0] if $card->[0];
   print ' & ', texify($card->[2]{name}), ' & ', texify($card->[2]{type});
   print ' & ';
   print texify($card->[2]{extra}) if $card->[2]{extra};
   print ' & ';
   print defined($5) ? texify($5)
    : '\img{' . ($2 ? $2 : $3 ? "$3$4" : $1) . '.pdf}'
    while $card->[2]{cost} =~ /\G(?:\{(\d+)\}|\{(\D)\}|\{(.)\/(.)\}|([^{}]+))/g;
   print ' & ', substr($card->[1], 0, 1), "\\\\\n";
  }
 } elsif ($opts{P}) {
  for my $card (@_) {
   print "\n", "linefeed\n";
   print '(', $card->[0], ") showNum\n" if $card->[0];
   print 'nameStart y moveto ', psify($card->[2]{name});
   print 'typeStart y moveto ', psify($card->[2]{type});
   print 'extraStart y moveto ', psify($card->[2]{extra}) if $card->[2]{extra};
   print 'costStart y moveto ';
   print($2 ? "$2\n" : $3 ? "$3$4\n" : psify(defined($1) ? $1 : $5))
    while $card->[2]{cost} =~ /\G(?:\{(\d+)\}|\{(\D)\}|\{(.)\/(.)\}|([^{}]+))/g;
   print $card->[1], "\n";
  }
 } else {
  printf "%4s %s  %s  %-*s  %-*s  %s\n",
   $_->[0] || '',
   $_->[2]{name} . ' ' x ($nameLen - $_->[2]{nameLen}),
   $_->[2]{type} . ' ' x ($typeLen - $_->[2]{typeLen}),
   $extraLen, $_->[2]{extra},
   $costLen, $_->[2]{cost},
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

/accent {
 exch dup show
 gsave
 stringwidth pop
 1 index stringwidth pop
 add -2 div 0 moveto
 show
 grestore
} def

/linefeed {
 y 72 lineheight add le { showpage startPage } if
 /y y lineheight sub def
} def

/startPage {
 /pageNo pageNo 1 add def
 66 725 moveto setname show
 /pns pageNo buf cvs def
 546 pns stringwidth pop sub 725 moveto
 pns show
 66 722.5 moveto 480 0 rlineto stroke
 /y 722 def
} def

/nameStart 72 def
/showNum { dup stringwidth pop nameStart exch sub 3 sub y moveto show } def

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
