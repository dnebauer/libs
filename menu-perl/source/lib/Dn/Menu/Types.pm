package Dn::Menu::Types;

# modules    {{{1
use 5.006;
use 5.038_001;
use strict;
use warnings;
use version; our $VERSION = qv('0.3');    # }}}1

# declare types at compile time as per Type::Tiny::Manual::Libraries manpage
## no critic (ProhibitUnusedImport)
use Type::Library -base, -declare => qw(MenuType);
## use critic
use Types::Standard qw(Str);
use Type::Utils     qw(declare as where message);

# MenuType    {{{1
declare 'MenuType', as Str, where {
  my $value = lc;
  if (not $value) { return; }
  my %valid_type = map { ($_ => 1) } qw /hotkey term gui/;
  return $valid_type{$value};
}, message {qq[Invalid menu type '$_']};

1;

# POD    {{{1

__END__

=head1 NAME

Dn::Menu::Types - data constraints for package Dn::Menu

=head1 VERSION

This documentation applies to Dn::Menu::Types version 0.3.

=head1 SYNOPSIS

    package Foo;
    use Dn::Menu::Type qw(MenuType);

    has 'attribute',
        isa => Dn::Menu::Types::MenuType,    # must NOT quote
        is  => 'rw';

=head1 DESCRIPTION

A library of custom type constraints. In the following explanations of each
type the error message may include the variable '$_', which represents the
value provided to the attribute.

=over

=item I<Dn::Menu::Types::MenuType>

One of the menu types offered. Must be one of: 'hotkey', 'term' and 'gui'.

Error message: "Invalid menu type '$_'".

=back

=head1 SUBROUTINES/METHODS

Nil.

=head1 DIAGNOSTICS

This module emits no custom error or warning messages.

=head1 CONFIGURATION AND ENVIRONMENT

This module has no configuration options or environmental variables.

=head1 DEPENDENCIES

Type::Library, Type::Utils, Types::Standard.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
