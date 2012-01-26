package EnVec::Card::Content;
use warnings;
use strict;
use EnVec::Colors;
use EnVec::Util;

use Class::Struct name       => '$',
		  cost       => '$',
		  supertypes => '@',
		  types      => '@',
		  subtypes   => '@',
		  text       => '$',
		  pow        => '$',
		  tough      => '$',
		  loyalty    => '$',
		  hand       => '$',
		  life       => '$',
		  indicator  => '$';  # /^W?U?B?R?G?$/

my @scalars = qw< name cost text pow tough loyalty hand life indicator >;
my @lists = qw< supertypes types subtypes >;

sub toJSON {
 my $self = shift;
 return "{\n" . join(",\n", map {
   my $val = $self->$_();
   defined $val && $val ne '' && !(ref $val eq 'ARRAY' && !@$val)
    ? "    \"$_\": @{[jsonify($val)]}" : ();
  } @scalars, @lists) . "\n   }";
}

sub toXML {
 my $self = shift;
 my $str = "  <content>\n   <name>" . txt2xml($self->name) . "</name>\n";
 $str .= "   <cost>" . sym2xml($self->cost) . "</cost>\n"
  if defined $self->cost;
 $str .= "   <supertype>" . txt2xml($_) . "</supertype>\n"
  for @{$self->supertypes};
 $str .= "   <type>" . txt2xml($_) . "</type>\n" for @{$self->types};
 $str .= "   <subtype>" . txt2xml($_) . "</subtype>\n" for @{$self->subtypes};
 $str .= "   <text>" . sym2xml($_) . "</text>\n"
  for split /\n/, $self->text || '';
 for (qw< pow tough loyalty hand life indicator >) {
  $str .= "   <$_>" . txt2xml($self->$_()) . "</$_>\n" if defined $self->$_()
 }
 $str .= "  </content>\n";
 return $str;
}

sub color {
 my $self = shift;
 return '' if $self->name eq 'Ghostfire';  # special case
 # Since Innistrad, cards that formerly said "[This card] is [color]" now have
 # color indicators instead, so there's no need to check for such strings.
 return colors2colors(($self->cost || '') . ($self->indicator || ''));
}

sub colorID {
 my $self = shift;
 my $colors = colors2bits($self->cost) | colors2bits($self->indicator);
 my $text = $self->text || '';
 # Since Innistrad, cards that formerly said "[This card] is [color]" now have
 # color indicators instead, so there's no need to check for such strings.
 $colors |= COLOR_WHITE if $text =~ m:\{(./)?W(/.)?\}:;
 $colors |= COLOR_BLUE  if $text =~ m:\{(./)?U(/.)?\}:;
 $colors |= COLOR_BLACK if $text =~ m:\{(./)?B(/.)?\}:;
 $colors |= COLOR_RED   if $text =~ m:\{(./)?R(/.)?\}:;
 $colors |= COLOR_GREEN if $text =~ m:\{(./)?G(/.)?\}:;
 ### Reminder text has to be ignored somehow.
 ### Do basic land types contribute to color identity?
 return bits2colors $colors;
}

sub cmc {
 my $self = shift;
 return 0 if !$self->cost;
 my $cmc = 0;
 for (split /(?=\{)/, $self->cost) {
  if (/(\d+)/) { $cmc += $1 }
  elsif (y/WUBRGSwubrgs//) { $cmc++ }  # This weeds out {X}, {Y}, etc.
 }
 return $cmc;
}

sub type {
 my $self = shift;
 return join ' ', @{$self->supertypes}, @{$self->types},
  @{$self->subtypes} ? ('--', @{$self->subtypes}) : ();
}

sub isSupertype {
 my($self, $type) = @_;
 for (@{$self->supertypes}) { return 1 if $_ eq $type }
 return '';
}

sub isType {
 my($self, $type) = @_;
 for (@{$self->types}) { return 1 if $_ eq $type }
 return '';
}

sub isSubtype {
 my($self, $type) = @_;
 for (@{$self->subtypes}) { return 1 if $_ eq $type }
 return '';
}

sub hasType {
 my($self, $type) = @_;
 $self->isType($type) || $self->isSubtype($type) || $self->isSupertype($type);
}

sub isNontraditional {
 my $self = shift;
 $self->isType('Vanguard') || $self->isType('Plane') || $self->isType('Scheme');
}

sub PT {
 my $self = shift;
 return defined $self->pow ? $self->pow . '/' . $self->tough : undef;
}

sub HandLife {
 my $self = shift;
 return defined $self->hand ? $self->hand . '/' . $self->life : undef;
}

sub copy {
 my $self = shift;
 # It isn't clear whether Storable::dclone can handle blessed objects, so...
 my %fields = map { $_ => $self->$_() } @scalars;
 $fields{$_} = [ @{$self->$_()} ] for @lists;
 new EnVec::Card::Content %fields;
}

sub equals {
 my($self, $other) = @_;
 return '' if ref $self ne ref $other;
 for my $f (@scalars) {
  my $left = $self->$f();
  my $right = $other->$f();
  next if !defined $left && !defined $right;
  return '' if !defined $left || !defined $right;
  return '' if $left ne $right;
 }
 for my $f (@lists) {
  my @left = @{$self->$f()};
  my @right = @{$other->$f()};
  return '' if @left != @right;
  for my $i (0..$#left) { return '' if $left[$i] ne $right[$i] }
 }
 return 1;
}

1;
