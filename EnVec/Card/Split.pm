package EnVec::Card::Split;
use Carp;

use Class::Struct
 format => '$',  # "split", "flip", or "double-faced"
 part1 => 'EnVec::Card',
 part2 => 'EnVec::Card',
 ids => '%',
 rarities => '%';

our @ISA = ('EnVec::Card');

my $sep = ' // ';

for my $field (qw< name cost pow tough text loyalty handMod lifeMod color type
 >) {
 eval <<EOT;
sub $field {
 my \$self = shift;
 croak "Card fields of Card::Split objects cannot be modified" if \@_;
 my \$left = \$self->part1->$field;
 my \$right = \$self->part2->$field;
 return undef if !defined \$left && !defined $right;
 \$left = '' if !defined \$left;
 \$right = '' if !defined \$right;
 return \$left . \$sep . \$right;
}
EOT
}

for my $field (qw< supertypes types subtypes >) {
eval <<EOT;
sub $field {
 my \$self = shift;
 croak "Card fields of Card::Split objects cannot be modified" if \@_;
 return [ \@{\$self->part1->$field}, \@{\$self->part2->$field} ];
}
EOT
}

sub toJSON {
 my $self = shift;
 my $str = " {\n  \"format\": " . jsonify($self->format) . ",\n  \"part1\": ";
 (my $sub = $self->part1->toJSON) =~ s/^/ /gm;
 $str .= $sub . ",\n  \"part2\": ";
 ($sub = $self->part2->toJSON) =~ s/^/ /gm;
 $str .= $sub . ",\n";
 $str .= "  \"ids\": " . jsonify($self->ids) . ",\n";
 $str .= "  \"rarities\": " . jsonify($self->rarities) . "\n }";
 return $str;
}

sub mergeWith { ... }

our $tagwidth = $EnVec::Card::tagwidth;

sub showField {
 my($self, $field, $width) = @_;
 $width = ($width || 80) - $tagwidth - 1;
 return sprintf "%-${tagwidth}s %s\n", 'Format:', $self->format
  if $field eq 'format';
 my $subwidth = int(($width - length($sep)) / 2) + $tagwidth + 1;
 my $left = $self->part1->showField($field, $subwidth);
 my $right = $self->part2->showField($field, $subwidth);
 return '' if $left eq '' && $right eq '';
 my @leftLines = map { sprintf "%-${subwidth}s", $_ } split /\n/, $left;
 my @rightLines = map { substr $tagwidth+1, $_ } split /\n/, $right;
 if (@leftLines < @rightLines) {
  #push @leftLines, (' ' x $subwidth) x (@rightLines - @leftLines)
  push @leftLines, (sprintf "%-${subwidth}s", '') x (@rightLines - @leftLines)
 } else { push @rightLines, '' x (@leftLines - @rightLines) }
 return join '', map { $leftLines[$_] . $sep . $rightLines[$_] . "\n" }
  0..$#leftLines;
}

sub isSplit { 1 }

1;
