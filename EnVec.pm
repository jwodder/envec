use constant {
 COLOR_WHITE => 1,
 COLOR_BLUE  => 2,
 COLOR_BLACK => 4,
 COLOR_RED   => 8,
 COLOR_GREEN => 16
};

sub colorStr2Bits($) {
 my $str = shift;
 my $mask = 0;
 $mask |= COLOR_WHITE if $str =~ y/W//;
 $mask |= COLOR_BLUE  if $str =~ y/U//;
 $mask |= COLOR_BLACK if $str =~ y/B//;
 $mask |= COLOR_RED   if $str =~ y/R//;
 $mask |= COLOR_GREEN if $str =~ y/G//;
 return $mask;
}
