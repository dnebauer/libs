package Dn::Common::Types;

use 5.014_002;
use strict;
use warnings;
use version; our $VERSION = qv('0.1');

use Type::Library -base, -declare => qw(NotifySysType);
use Type::Utils qw(declare as where message);
use Types::Standard qw(Str);

declare 'NotifySysType', as Str, where {
    my $val = $_;
    my %is_valid_type = map { ( $_ => 1 ) } qw/info question warn error/;
    return ( $val and $is_valid_type{$val} );
}, message {qq[notify_sys type '$_' is invalid]};

1;

__END__

=encoding utf-8

=head1 NAME

Dn::Common::Types - library of custom type constraints for Dn::Common

=head1 SYNOPSIS

    package Foo;
    use Dn::Common::Types qw(NotifySysType);

    has 'type',
        is  => 'rw';
        isa => Dn::Common::Types::NotifySysType,    # must NOT quote

=head1 DESCRIPTION

Dn::Common::Types is a library of custom type constraints. In the following explanations of each type the error message may include the variable '$_', which represents the value provided to the attribute.

=over

=item I<Dn::Common::Types::NotifySysType>

Valid C<notify_sys> type. Must be one of: 'info', 'question', 'warn' or 'error'.

Error message: "notify_sys type '$_' is invalid".

=back

=head1 DEPENDENCES

=head2 Perl modules

Type::Library, Type::Utils, Types::Standard.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

