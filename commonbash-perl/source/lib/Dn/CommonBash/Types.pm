package Dn::CommonBash::Types;

use 5.014_002;    #                                                    {{{1
use strict;
use warnings;
use version; our $VERSION = qv('0.1');    #                            }}}1

use Type::Utils qw(declare as where message);
use Type::Library -base, -declare => qw(Boolean Char OptionType ParamType);
use Types::Standard qw(Str);

# Boolean                                                              {{{1
declare 'Boolean',
    as Str,
    where {
        my $value = lc $_;
        my %is_valid_boolean
            = map { ( $_ => 1 ) } qw/yes true on 1 no false off 0/;
        return $is_valid_boolean{$value};
    },
    message {qq[Invalid Boolean value '$_']};

# Char                                                                 {{{1
declare 'Char',
    as Str,
    where { /^[[:alpha:]]/xsm },
    message {qq[Not a single alpabetic character ('$_')]};

# OptionType                                                           {{{1
declare 'OptionType',
    as Str,
    where {
        my $value = lc;
        my %is_valid_types
            = map { ( $_ => 1 ) }
            qw/string integer number boolean path date time none/;
        return $is_valid_types{$value};
    },
    message {qq[Invalid option type '$_']};

# ParamType                                                            {{{1
declare 'ParamType',
    as Str,
    where {
        my $value = lc;
        my %is_valid_types
            = map { ( $_ => 1 ) }
            qw/string integer number boolean path date time/;
        return $is_valid_types{$value};
    },
    message {qq[Invalid parameter type '$_']};    #                    }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf-8

=head1 NAME

Dn::CommonBash::Types - data constraints for package CommonBash

=head1 SYNOPSIS

    package Foo;
    use Dn::CommonBash::Types qw(Char);

    has 'attribute',
        isa => Dn::CommonBash::Types,    # must NOT quote, i.e., 'Types::Dn::File'
        is  => 'rw';

=head1 DESCRIPTION

A library of custom type constraints. In the following explanations of each type the error message may include the variable '$_', which represents the value provided to the attribute.

=over

=item I<Dn::CommonBash::Types::Boolean>

A boolean value. Must be one of: 'yes', 'true', 'on', 1, 'no', 'false' or 'off'.

Error message: "Invalid Boolean value '$_'".

=item I<Dn::CommonBash::Types::Char>

A single alphabetic character.

Error messages: "Not a single alpabetic character ('$_')".

=item I<Dn::CommonBash::Types::OptionType>

Option type. Must be one of: 'boolean', 'date', 'integer', 'none', 'number', 'path', 'string' or 'time'.

Error message: "Invalid option type '$_'".

=item I<Dn::CommonBash::Types::ParamType>

Parameter type. Must be one of: 'boolean', 'date', 'integer', 'number', 'path', 'string' or 'time'.

Error message: "Invalid parameter type '$_'".

=back

=head1 DEPENDENCES

=over

=item Type::Library

=item Type::Utils

=item Types::Standard

=back

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
