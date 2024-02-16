package Dn::Images::ExtractRegions::RegionCoords;

use Moo;    # {{{1
use strictures 2;
use 5.006;
use 5.036_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;

use Const::Fast;
use English qw(-no_match_vars);
use MooX::HandlesVia;
use Types::Standard;

const my $TRUE        => 1;
const my $FALSE       => 0;
const my $OP_CLEAR    => 'clear';
const my $OP_ELEMENTS => 'elements';
const my $OP_PUSH     => 'push';
const my $TRAIT_ARRAY => 'Array';      # }}}1

# attributes

# top_left_coords, [add|clear]_top_left, top_left, {{{1
has 'top_left_coords' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Int],
  default     => sub { [] },
  handles_via => $TRAIT_ARRAY,
  handles     => {
    top_left       => $OP_ELEMENTS,
    add_top_left   => $OP_PUSH,
    clear_top_left => $OP_CLEAR,
  },
  documentation => 'X and Y coordinates of top-left pixel',
);

# bottom_right_coords, [add|clear]_bottom_right, bottom_right {{{1
has 'bottom_right_coords' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Int],
  default     => sub { [] },
  handles_via => $TRAIT_ARRAY,
  handles     => {
    bottom_right       => $OP_ELEMENTS,
    add_bottom_right   => $OP_PUSH,
    clear_bottom_right => $OP_CLEAR,
  },
  documentation => 'X and Y coordinates of bottom right pixel',
);    # }}}1

1;

# POD {{{1

## no critic (RequirePodSections)

__END__

=encoding utf8

=head1 NAME

Dn::Images::ExtractRegions::RegionCoords - store coordinates of rectangular regions

=head1 SYNOPSIS

    use Dn::Images::ExtractRegions::RegionCoords;
    ...

=head1 DESCRIPTION

Stores coordinates information delineating rectangular regions of images. For
each region the x and y coordinates of the top-left and bottom-right pixels of
the region are recorded.

This module was written to be used by the
Dn::Images::ExtractRegions::RegionCoords module.

=head1 ATTRIBUTES

=head2 top_left_coords

X and y coordinates of the top-left pixel in the rectangular region. Array
reference containing integers. Optional. Default: [].

=head2 bottom_right_coords

X and y coordinates of the bottom-right pixel in the rectangular region. Array reference containing integers. Optional. Default: [].

=head1 METHODS

=head2 add_top_left(@coords)

Add coordinates for top-left pixel of rectangular region of image.

=head3 Params

=over

=item @coords

X and y coordinates. List of integers. Required.

=back

=head3 Prints

Nil.

=head3 Returns

N/A.

=head2 top_left()

Get coordinates for top-left pixel of rectangular region of image.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

List of integers.

=head2 clear_top_left()

Clear existing coordinates for the top-left pixel.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

N/A.

=head2 add_bottom_right(@coords)

Add coordinates for bottom-right pixel of rectangular region of image. List of
integers. Required.

=head3 Params

=over

=item @coords

X and y coordinates. List of integers. Required.

=back

=head3 Prints

Nil.

=head3 Returns

N/A.

=head2 bottom_right()

Get coordinates for bottom-right pixel of rectangular region of image.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

List of integers.

=head2 clear_bottom_right()

Clear existing coordinates for the bottom-right pixel.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

N/A.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, English, Moo, MooX::HandlesVia, namespace::clean, strictures,
Types::Standard, version.

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
