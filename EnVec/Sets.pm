package EnVec::Sets;
use warnings;
use strict;
use Carp;
use Exporter 'import';
our @EXPORT_OK = qw< loadedSets loadSets cmpSets setsToImport allSets >;
our %EXPORT_TAGS = (all => [ @EXPORT_OK ]);

our $setfile = 'data/sets.tsv';

my %sets = ();
my %shorts = ();
my @setList = ();
my $loaded = 0;
my $warned = 0;

sub loadedSets() { $loaded }

sub loadSets(;$) {
 my $sf = shift || $setfile;
 my $setdat;
 if ($sf eq '-') { $setdat = *STDIN }
 else { open $setdat, '<', $sf or croak "EnVec::Sets::loadSets: $sf: $!" }
 %sets = ();
 %shorts = ();
 @setList = ();
 while (<$setdat>) {
  chomp;
  next if /^\s*#/ || /^\s*$/;
  my($short1, $short2, $name, $date, $import) = split /\t+/;
  if (exists $sets{$name}) {
   carp "EnVec::Sets::loadSets: $sf: set \"$name\" appears more than once; second appearance discarded";
   next;
  }
  $date =~ tr/0-9//cd;
  $date = $name if $date eq '';
   # ^^ so that comparing two dateless sets will at least be deterministic
  $sets{$name} = {
   short1 => $short1,
   short2 => $short2,
   name => $name,
   date => $date,
   import => $import
  };
  push @setList, $name;
  if (exists $shorts{$short1}) {
   carp "EnVec::Sets::loadSets: $sf: abbreviation \"$short1\" used more than once; second appearance ignored";
  } else { $shorts{$short1} = $name }
 }
 $loaded = 1;
 close $setdat;
}

sub cmpSets($$) {
 my @s = @_;
 if ($loaded) { @s = map { defined $sets{$_}{date} ? $sets{$_}{date} : $_ } @s }
 elsif (!$warned) {
  carp "Warning: EnVec::Sets::loadSets not yet invoked";
  $warned = 1;
 }
 return $s[0] cmp $s[1] || $_[0] cmp $_[1];
}

sub setsToImport() {
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::Sets::loadSets not yet invoked";
  $warned = 1;
 }
 return grep { $sets{$_}{import} } @setList;
}

sub allSets() {
 if (!$loaded && !$warned) {
  carp "Warning: EnVec::Sets::loadSets not yet invoked";
  $warned = 1;
 }
 return @setList;
}
