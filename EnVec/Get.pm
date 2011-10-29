package EnVec::Get;
use HTTP::Status qw< status_message is_success >;
use LWP::Simple 'mirror';

sub getTextSpoiler($$) {
 my($set, $file) = @_;
 my $url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=spoiler&method=text&set=[%22$set%22]&special=true";
 #my $res = getstore($url, $file);
 my $res = mirror($url, $file);
#if (!is_success $res) {
# print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
#}
 return is_success $res;
}
