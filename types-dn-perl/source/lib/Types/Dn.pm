package Types::Dn;

use 5.014_002;
use strict;
use warnings;
use version; our $VERSION = qv('0.1');

use Type::Library -base,
    -declare => qw(Directory EmailAddress File ISODate PID Time24H WebURL);

use Type::Utils qw(declare as where message);

use Types::Standard qw(Int Str);

use Cwd qw(abs_path);
use Data::Validate::URI;
use Date::Simple qw();
use List::MoreUtils qw(any);
use Proc::ProcessTable;
use Email::Valid;
use Time::Simple;

declare 'Directory', as Str,
    where { -d Cwd::abs_path($_) },
    message {qq[Invalid file '$_']};

declare 'EmailAddress', as Str,
    where { Email::Valid->address($_) },
    message {qq[Invalid email address '$_']};

declare 'File', as Str,
    where { -f Cwd::abs_path($_) },
    message {qq[Invalid file '$_']};

declare 'ISODate', as Str,
    where { return Date::Simple->new($_) },
    message {qq[Invalid ISO date '$_']};

declare 'PID', as Int, where {
    my $pid = $_;
    my $t   = Proc::ProcessTable->new();
    return List::MoreUtils::any { $_->pid == $pid } @{ $t->table() };
}, message {qq[Invalid PID '$_']};

declare 'Time24H', as Str, where {
    my $time = $_;
    if ( $time and $time =~ /^ ( \d{2} ) ( \d{2} ) \z/xsm ) {
        $time = "$1:$2";
    }
    return eval { Time::Simple->new($time); 1 };
}, message {qq[Invalid 24 hour time '$_']};

declare 'WebURL', as Str,
    where { Data::Validate::URI->new()->is_web_uri($_) },
    message {qq[Invalid web address '$_']};

1;

__END__

=encoding utf-8

=head1 NAME

Types::Dn - library of custom moo(se) types

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

=item I<Types::Dn::Debian::PackageControlDescription>

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

=item I<Types::Dn::Directory>

Valid path, either absolute or relative to the current working directory.

Error message: "Invalid directory '$_'".

Uses C<Cwd::abs_path> to obtain an absolute directory path, and perl's inbuilt C<-d> operator to determine whether it exists.

=item I<Types::Dn::EmailAddress>

An email address in valid format. Note that the email address does not have to exist -- no internet connection is required for this check.

Error message: "Invalid email address '$_'".

Uses C<Email::Valid-E<gt>address> to check email validity.

=item I<Types::Dn::File>

Requires the value to be a valid file path when expanded using C<Cwd::abs_path>. For that reason the value needs to needs to be either an existing absolute file path or an existing file path relative to the current directory.

Error message: "Invalid file '$_'".

Uses C<Cwd::abs_path> to obtain an absolute file path, and perl's inbuilt C<-f> operator to determine whether it exists.

=item I<Types::Dn::ISODate>

Valid ISO date.

Error message: "Invalid ISO date '$_'".

Uses C<Date::Simple>'s constructor to determine date validity -- the constructor returns a date object (a boolean true value) if the date is valid, and returns C<undef> (a boolean false value) if the date is invalid.

=item I<Types::Dn::PID>

Running process id.

Error message: "Invalid PID '$_'".

Uses C<Proc::ProcessTable> to get process information, and C<List::MoreUtils::any> to search list data.

=item I<Types::Dn::Time24H>

Valid 24 hour time. Can be formatted as 'HHMM' (cannot drop leading zero) or 'HH:MM' (can drop leading zero).

Error message: "Invalid 24 hour time '$_'".

Uses C<Time::Simple>'s constructor to determine date validity -- the constructor returns a time object (a boolean true value) if the time is valid, and returns C<undef> (a boolean false value) if the time is invalid.

=item I<Types::Dn::WebURL>

A web address in valid format. Note that the web address does not need to be reachable -- no internet connection is required for this check.

Error message: "Invalid web address '$_'".

Uses C<Data::Validate::URI-E<gt>>is_web_uri> to check address validity.

=back

=head1 DEPENDENCES

=over

=item Cwd

=item Data::Validate::URI

=item Dpkg::Version

=item Email::Valid

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

