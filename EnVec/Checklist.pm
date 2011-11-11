package EnVec::Checklist;
use warnings;
use strict;
use XML::DOM::Lite 'Parser';
use EnVec::Util;

use Exporter 'import';
our @EXPORT_OK = ('loadChecklist');
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

sub loadChecklist($) {
 my $file = shift;
 my $doc = Parser->new->parseFile($file);
 ### TODO: Handle parse errors somehow!
 my @cards = ();
 for my $table (@{$doc->getElementsByTagName('table')}) {
  my $tblClass = $table->getAttribute('class');
  next unless defined $tblClass && $tblClass eq 'checklist';
  for my $tr (@{$table->getElementsByTagName('tr')}) {
   my $trClass = $tr->getAttribute('class');
   next unless defined $trClass && $trClass eq 'cardItem';
   my %item = ();
   for my $td (@{$tr->getElementsByTagName('td')}) {
    my $key = $td->getAttribute('class');
    my $value = textContent $td;
    $item{$key} = $value;
    if ($key eq 'name') {
     my $url = $td->getElementsByTagName('a')->[0]->getAttribute('href');
     $item{multiverseid} = $1 if defined $url && $url =~ /\bmultiverseid=(\d+)/;
    }
   }
   push @cards, \%item;
  }
  last;
 }
 return @cards;
}
