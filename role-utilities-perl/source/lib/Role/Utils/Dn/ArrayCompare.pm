package Role::Utils::Dn::ArrayCompare;

# modules/constants    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use version; our $VERSION = qv('0.8');
use namespace::clean;

use Array::Diff;
use Const::Fast;
use English;
use MooX::HandlesVia;
use MooX::Options (
  authors      => 'David Nebauer <david at nebauer dot org>',
  description  => 'Compare two arrays',
  protect_argv => 0,
);
use Types::Standard;

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# attributes

# array1    {{{1
has 'array1' => (
  is          => 'ro',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  required    => $TRUE,
  handles_via => 'Array',
  handles     => { _array1_elements => 'elements' },
  doc         => 'Left-hand "old" array',
);

# array2    {{{1
has 'array2' => (
  is          => 'ro',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  required    => $TRUE,
  handles_via => 'Array',
  handles     => { _array2_elements => 'elements' },
  doc         => 'Right-hand "new" array',
);

# _diff    {{{1
has '_diff' => (
  is  => 'lazy',
  isa => Types::Standard::InstanceOf ['Array::Diff'],
  doc => 'Instance of Array::Diff holding both arrays',
);

sub _build__diff($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $diff = Array::Diff->diff([ sort $self->_array1_elements ],
    [ sort $self->_array2_elements ]);
  return $diff;
}

# elements_added   {{{1
has 'elements_added' => (
  is  => 'lazy',
  isa => Types::Standard::Bool,
  doc => 'Whether elements were added to array',
);

sub _build_elements_added($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $added_count = scalar $self->added_elements;
  return ($added_count > 0) ? $TRUE : $FALSE;
}

# added_elements    {{{1
has '_added_elements_array' => (
  is          => 'lazy',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  handles     => { added_elements => 'elements' },
  doc         => 'Elements added to array',
);

sub _build__added_elements_array($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $added = $self->_diff->added;
  return $added;
}

# elements_removed   {{{1
has 'elements_removed' => (
  is  => 'lazy',
  isa => Types::Standard::Bool,
  doc => 'Whether elements were removed from array',
);

sub _build_elements_removed($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $removed_count = scalar $self->removed_elements;
  return ($removed_count > 0) ? $TRUE : $FALSE;
}

# removed_elements    {{{1
has '_removed_elements_array' => (
  is          => 'lazy',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  handles     => { removed_elements => 'elements' },
  doc         => 'Elements removed from array',
);

sub _build__removed_elements_array($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $removed = $self->_diff->deleted;
  return $removed;
}

# changed   {{{1
has 'changed' => (
  is  => 'lazy',
  isa => Types::Standard::Bool,
  doc => 'Whether array was changed',
);

sub _build_changed($self) {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $changed = $self->elements_added or $self->elements_removed;
  return $changed;
}                              # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Role::Utils::Dn::ArrayCompare - returned by Role::Utils::Dn->compare_arrays()

=head1 SYNOPSIS

    with qw(Role::Utils::Dn);

    my $result = $self->compare_arrays($array_1, $array_2);
    if ( $result->changed ) {
        ...
    }

=head1 VERSION

This documentation refers to Role::Utils::Dn::ArrayCompare version 0.8.

=head1 DESCRIPTION

Captures the result of comparing two arrays with the C<Role::Utils::Dn> method
C<compare_arrays>.

=head1 SUBROUTINES/METHODS

None.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 elements_added

Whether elements were added to array1 to produce array2. Scalar boolean.

=head3 added_elements

Elements added to array1 to produce array2. List.

=head3 elements_removed

Whether elements were removed from array1 to produce array2. Scalar boolean.

=head3 removed_elements

Elements removed from array1 to produce array2. List.

=head3 changed

Whether array1 was changed to produce array2. Scalar boolean.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

This module emits no custom warning or error messages.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None reported.

=head1 DEPENDENCIES

=head2 Perl modules

Array::Diff, Const::Fast, English, Moo, MooX::HandlesVia, MooX::Options,
namespace::clean, strictures, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

L<David Nebauer|mailto:davidnebauer@hotkey.net.au>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2026 L<David Nebauer|mailto:davidnebauer@hotkey.net.au>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# }}}1

# vim:fdm=marker
