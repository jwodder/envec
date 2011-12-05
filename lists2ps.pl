#!/usr/bin/perl -w
use strict;

-d 'lists' or mkdir 'lists' or die "$0: lists/: $!";
my $out;
while (<>) {
 chomp;
 next if /^\s*$/ || /^\s*#/;
 if (/^(\S.*):$/) {
  my $set = $1;
  if (defined $out) {print $out "showpage\n"; close $out; undef $out; }
  (my $file = $set) =~ tr/ "'/_/d;
  open $out, '>', "lists/$file.ps" or die "$0: lists/$file.ps: $!";
  print $out <<EOT;
%!PS-Adobe-3.0
/fontsize 8 def
/lineheight fontsize 1.5 mul def
/Monaco findfont fontsize scalefont setfont
/pageNo 0 def
/buf 3 string def

/linefeed {
 y 72 lineheight add le {showpage startPage} if
 /y y lineheight sub def
 66 y moveto
} def

/startPage {
 /pageNo pageNo 1 add def
 66 725 moveto ($set) show
 /pns pageNo buf cvs def
 546 725 pns stringwidth pop sub moveto
 pns show
 66 722.5 moveto 480 0 rlineto stroke
 /y 722 def
} def

/em (m) stringwidth pop neg def
/bs { show em 0 rmoveto } def
startPage
linefeed
EOT
 } else {
  s/([(\\)])/\\$1/g;
  s/’/'/g;
  s/Æ/\\341/g;
  s/à/a) bs (\\301/g;
  s/á/a) bs (\\302/g;
  s/é/e) bs (\\302/g;
  s/í/\\365) bs (\\302/g;
  s/ú/u) bs (\\302/g;
  s/â/a) bs (\\303/g;
  s/û/u) bs (\\303/g;
  s/ö/o) bs (\\310/g;
  print $out "($_) show linefeed\n";
 }
}
if (defined $out) {print $out "showpage\n"; close $out; undef $out; }
