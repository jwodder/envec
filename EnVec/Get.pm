package EnVec::Get;
use HTTP::Status 'is_success';
use LWP::Simple 'mirror';
use Exporter 'import';
our @EXPORT_OK = qw< getTextSpoiler >;

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
