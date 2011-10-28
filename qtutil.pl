sub simplify($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 $str =~ s/\s+/ /g;
 return $str;
}

sub trim($) {
 my $str = shift;
 $str =~ s/^\s+|\s+$//g;
 return $str;
}
