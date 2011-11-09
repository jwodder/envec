package EnVec::Get;
use warnings;
use strict;
use HTTP::Status 'is_success';
use LWP::Simple 'getstore';

use Exporter 'import';
our @EXPORT_OK = qw< getTextSpoiler getChecklist getStdSpoiler getURL >;
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

sub getURL($$) {
 my($url, $file) = @_;
 my $res = getstore($url, $file);
 #my $res = mirror($url, $file);
#if (!is_success $res) {
# print STDERR "Could not fetch set \"$set\": ", status_message($res), "\n";
#}
 return is_success $res;
}

sub getTextSpoiler($$) {
 my($set, $file) = @_;
 getURL "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=spoiler&method=text&set=[%22$set%22]&special=true", $file;
}

sub getChecklist($$) {
 my($set, $file) = @_;
 getURL "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&set=[%22$set%22]&special=true", $file;
}

sub getStdSpoiler($$) {
 my($set, $file) = @_;
 getURL "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=standard&set=[%22$set%22]&special=true", $file;
}
