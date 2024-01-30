package Dn::Images::Uniquefy::PixelsProcessed;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use Carp qw(confess);
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use Readonly;
use Types::Standard;

with qw(Role::Utils::Dn);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                        }}}1

# attributes

# clear_x_coords, _set_x_coord, _x_coord, _x_coord_exists              {{{1
has '_pixels_list' => (
    is          => 'rw',
    isa         => Types::Standard::HashRef [Types::Standard::ArrayRef],
    lazy        => $TRUE,
    default     => sub { {} },
    handles_via => 'Hash',
    handles     => {
        _set_x_coord    => 'set',
        _x_coord        => 'get',
        _x_coord_exists => 'exists',
        clear_x_coords  => 'clear',
    },
    doc => 'X and y coordinates of processed pixels',
);    #                                                                }}}1

# methods

# mark_pixel_as_processed($x, $y)                                      {{{1
#
# does:   flag pixel as processed
# params: x - pixel's x-coord [int, required]
#         y - pixel's y-coord [int, required]
# prints: error message on failure
# return: n/a, die on failure
method mark_pixel_as_processed ($x, $y) {

    # check args
    # - note that zero is a valid coordinate value, hence 'defined'
    confess 'No y coordinate provided'      if not defined $y;
    confess 'No x coordinate provided'      if not defined $x;
    confess "Non-integer y coordinate '$y'" if not $self->int_pos_valid($y);
    confess "Non-integer x coordinate '$x'" if not $self->int_pos_valid($x);

    if ( $self->_x_coord_exists($x) ) {    # add y coord if necessary

        # get y-coords for this x-coord
        my @y_coords = @{ $self->_x_coord($x) };

        # see whether this y-coord is already included
        my @match = grep { $_ == $y } @y_coords;

        # if not, add to this x-coord
        if ( not @match ) {
            push @y_coords, $y;
            $self->_set_x_coord( $x => [@y_coords] );
        }
    }
    else {    # add both x and y coords
        $self->_set_x_coord( $x => [$y] );
    }
}

# pixel_is_processed($x, $y)                                           {{{1
#
# does:   determine whether pixel has been processed
# params: x - pixel's x-coord [int, required]
#         y - pixel's y-coord [int, required]
# prints: error message on failure
# return: boolean, dies on failure
method pixel_is_processed ($x, $y) {

    # check args
    # - note that zero is a valid coordinate value, hence 'defined'
    confess 'No y coordinate provided'      if not defined $y;
    confess 'No x coordinate provided'      if not defined $x;
    confess "Non-integer y coordinate '$y'" if not $self->int_pos_valid($y);
    confess "Non-integer x coordinate '$x'" if not $self->int_pos_valid($x);

    if ( not $self->_x_coord_exists($x) ) { return; }

    # get y-coords for this x-coord
    my @y_coords = @{ $self->_x_coord($x) };

    # see whether this y-coord is already included
    my @matches = grep { $_ == $y } @y_coords;

    return scalar @matches;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Images::Uniquefy::PixelsProcessed - track processed pixels

=head1 SYNOPSIS

    use Dn::Images::Uniquefy::PixelsProcessed;
    ...

=head1 DESCRIPTION

Keeps a record of processed pixels by storing their x and y coordinates. Newly
processed pixels are added using the C<mark_pixel_as_processed> method. It is
possible to check whether a pixel has been processed with the
C<pixel_is_processed> method.

This module is designed to be used by the C<Dn::Images::Uniquefy> module.

=head1 ATTRIBUTES

No attributes are provided.

=head1 METHODS

=head2 clear_x_coords()

Clear all processed pixels.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 mark_pixel_as_processed($x, $y)

Flag pixel as processed.

=head3 Params

=over

=item $x

X coordinate of processed pixel. Integer. Required.

=item $y

Y coordinate of processed pixel. Integer. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Nil. Dies on failure.

=head2 pixel_is_processed($x, $y)

Determine whether pixel has been processed.

=head3 Params

=over

=item $x

X-coordinate of pixel to query. Integer. Required.

=item $y

Y-coordinate of pixel to query. Integer. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Scalar boolean. Dies on failure.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

Role::Utils::Dn, English, Function::Parameters, Moo, MooX::HandlesVia,
namespace::clean, Readonly, strictures, Types::Standard, version.

=head2 INCOMPATIBILITIES

There are no known incompatibilities with other modules.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim:fdm=marker
