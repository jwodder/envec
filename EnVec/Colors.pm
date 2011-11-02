package EnVec::Colors;
use Exporter 'import';
our @EXPORT = qw< COLOR_WHITE COLOR_BLUE COLOR_BLACK COLOR_RED COLOR_GREEN
 colors2bits bits2colors parseColors >;

use constant {
 COLOR_WHITE => 1,
 COLOR_BLUE  => 2,
 COLOR_BLACK => 4,
 COLOR_RED   => 8,
 COLOR_GREEN => 16
};

sub colors2bits($) {
 my $str = shift;
 my $mask = 0;
 $mask |= COLOR_WHITE if $str =~ y/W//;
 $mask |= COLOR_BLUE  if $str =~ y/U//;
 $mask |= COLOR_BLACK if $str =~ y/B//;
 $mask |= COLOR_RED   if $str =~ y/R//;
 $mask |= COLOR_GREEN if $str =~ y/G//;
 return $mask;
}

sub bits2colors($) {
 my $mask = shift;
 my $str = '';
 $str .= 'W' if $mask & COLOR_WHITE;
 $str .= 'U' if $mask & COLOR_BLUE;
 $str .= 'B' if $mask & COLOR_BLACK;
 $str .= 'R' if $mask & COLOR_RED;
 $str .= 'G' if $mask & COLOR_GREEN;
 return $str;
}

sub parseColors($) {
 my $text = shift;
 my $str = '';
 $str .= 'W' if $text =~ /\bWhite\b/i;
 $str .= 'U' if $text =~ /\bBlue\b/i;
 $str .= 'B' if $text =~ /\bBlack\b/i;
 $str .= 'R' if $text =~ /\bRed\b/i;
 $str .= 'G' if $text =~ /\bGreen\b/i;
 return $str;
}

1;
