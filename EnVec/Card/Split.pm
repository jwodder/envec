package EnVec::Card::Split;

our @ISA = ('EnVec::Card');

use Class::Struct
 left => 'EnVec::Card',
 right => 'EnVec::Card',
 ids => '%',
 rarities => '%';

for my $field (qw< name cost pow tough text loyalty handMod lifeMod color >) {
 our &$field = sub {
  my $self = shift;
  if (@_) { ### carp ### }
  my $left = $self->left->$field();
  $left = '' if !defined $left;
  my $right = $self->right->$field();
  $right = '' if !defined $right;
  return "$left // $right";
 };
}
