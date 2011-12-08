package EnVec::Get;
use warnings;
use strict;
use Carp;
use HTTP::Status qw< is_success status_message >;
use LWP::Simple 'getstore';

use Exporter 'import';

our @EXPORT_OK = qw< getURL textSpoilerURL getTextSpoiler checklistURL
 getChecklist stdSpoilerURL getStdSpoiler detailsURL getDetails >;

our %EXPORT_TAGS = (
 all  => \@EXPORT_OK,
 urls => [ qw< textSpoilerURL checklistURL stdSpoilerURL detailsURL > ],
 get  => [ qw< getURL getTextSpoiler getChecklist getStdSpoiler getDetails >]
);

sub getURL($$) {
 my($url, $file) = @_;
 my $res = getstore($url, $file);
 #my $res = mirror($url, $file);
 carp "Error fetching URL [$url]: ", status_message($res) if !is_success $res;
 return is_success $res;
}

sub textSpoilerURL($) { "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=spoiler&method=text&set=[%22$_[0]%22]&special=true" }

sub getTextSpoiler($$) {
 my($set, $file) = @_;
 getURL textSpoilerURL($set), $file;
}

sub checklistURL($) { "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&set=[%22$_[0]%22]&special=true" }

sub getChecklist($$) {
 my($set, $file) = @_;
 getURL checklistURL($set), $file;
}

sub stdSpoilerURL($) { "http://gatherer.wizards.com/Pages/Search/Default.aspx?output=standard&set=[%22$_[0]%22]&special=true" }

sub getStdSpoiler($$) {
 my($set, $file) = @_;
 getURL stdSpoilerURL($set), $file;
}

sub detailsURL($;$) {
 my($id, $part) = @_;
 $part = defined $part ? "&part=$part" : '';
 return "http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=$id$part";
}

sub getDetails($$;$) {
 my($id, $file, $part) = @_;
 getURL detailsURL($id, $part), $file;
}
