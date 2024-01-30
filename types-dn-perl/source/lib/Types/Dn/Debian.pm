package Types::Dn::Debian;

use 5.014_002;
use strict;
use warnings;
use version; our $VERSION = qv('0.1');

use Type::Library
    -base,
    -declare => qw(
    PackageCopyrightYear
    PackageControlDescription
    PackageVersion
);
use Type::Utils qw(declare as where message);
use Types::Standard qw(InstanceOf Int Str);

use Dpkg::Version;
# can remove following warning suppression once dpkg version >= 1.20
no if $Dpkg::Version::VERSION ge '1.02',
    warnings => qw(Dpkg::Version::semantic_change::overload::bool);

declare 'PackageCopyrightYear',
    as Int, where {
    my $year = $_;
    my $now  = (localtime)[5] + 1900;
    return ( $year >= 2000 and $year <= $now );
    }, where {
    return qq[Copyright year '$_' cannot be earlier than 2000] if $_ < 2000;
    return qq[Copyright year '$_' cannot be in the future];
    };

declare 'PackageControlDescription', as Str, where {
    my $str_len = length;
    return ( $str_len > 0 and $str_len <= 60 );
}, message {
    return q[Description cannot be empty] if length == 0;
    return qq[Description '$_' is too long (>60 characters)];
};

declare 'PackageVersion', as InstanceOf ['Dpkg::Version'],
    where { $_->is_valid() },
    message { q[Invalid package version '] . $_->as_string() . q['] };

1;

__END__

=encoding utf-8

=head1 NAME

Types::Dn - library of custom moo(se) types for Debian

=head1 SYNOPSIS

    package Foo;
    use Types::Dn qw(File);
    use Types::Dn::Debian qw(PackageControlDescription);

    has 'file',
        isa => Types::Dn::File,    # must NOT quote, i.e., 'Types::Dn::File'
        is  => 'rw';

=head1 DESCRIPTION

Types::Dn is a library of custom Moose types. In the following explanations of each type the error message may include the variable '$_', which represents the value provided to the attribute.

=over

=item I<Types::Dn::Debian::PackageCopyrightYear>

Year of copyright of package. Must be no earlier than 2000 and no later than the current year.

Error messages:

=over

=over

=item

If earlier than 2000: "Copyright year '$_' cannot be earlier than 2000"

=item

If later than current year: "Copyright year '$_' cannot be in the future".

=back

=back

Uses perl's inbuilt function C<localtime> to determine current year.

=item I<iTypes::Dn::Debian::PackageControlDescription>

A string used in debian package F<control> files in the C<Description> field. In essence, it is a string that cannot be longer than 60 characters.

Error messages:

=over

=over

=item

If description is empty: "Description cannot be empty"

=item

If description is longer than 60 characters: "Description '$_' is too long (>60 characters)".

=back

=back

Uses perl's inbuilt function C<length> to determine description length.

=item I<Types::Dn::Debian::PackageVersion>

Instance of C<Dpkg::Version> instantiated with a valid version number.

Error message: "Invalid package version 'VERSION'".

Uses C<Dpkg::Version-E<gt>is_valid()> to determine validity of package version, and C<Dpkg::Version-E<gt>as_string()> to report package version in the error message.

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

