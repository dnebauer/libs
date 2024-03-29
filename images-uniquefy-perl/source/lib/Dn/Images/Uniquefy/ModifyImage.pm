package Dn::Images::Uniquefy::ModifyImage;

use Moo;    # {{{1
use strictures 2;
use 5.006;
use 5.036_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;

use autodie qw(open close);
use Carp    qw(confess);
use Const::Fast;
use English qw(-no_match_vars);
use MooX::HandlesVia;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE                => 1;
const my $FALSE               => 0;
const my $HEIGHT              => 'height';
const my $IMAGE_NOT_CREATED   => 'Image is not created';
const my $LAZY                => 'lazy';
const my $MAX_RGB             => 255;
const my $NEG_SIX             => -6;
const my $POS_SIX             => 6;
const my $RGB_COMPONENT_MAX   => 127;
const my $RGB_COMPONENT_INDEX => 'rgb_component_index';
const my $RGB_COMPONENT_VALUE => 'rgb_component_value';
const my $WIDTH               => 'width';                  # }}}1

# attributes

# filepath {{{1
has 'filepath' => (
  is      => 'rw',
  isa     => Types::Standard::Str,
  default => q{},
  doc     => 'Input image file path',
);

# width {{{1
has $WIDTH => (
  is      => 'ro',
  isa     => Types::Standard::Int,
  lazy    => $TRUE,
  default => sub {
    my $self = $_[0];
    if (not $self->_image) {
      confess $IMAGE_NOT_CREATED;
    }
    return $self->_image->get($WIDTH);
  },
  doc => 'Image width',
);

# height {{{1
has $HEIGHT => (
  is      => 'ro',
  isa     => Types::Standard::Int,
  lazy    => $TRUE,
  default => sub {
    my $self = $_[0];
    if (not $self->_image) {
      confess $IMAGE_NOT_CREATED;
    }
    return $self->_image->Get($HEIGHT);
  },
  doc => 'Image height',
);

# _[set|get]_pixel_properties, _has_pixel_property {{{1
# - properties: x, y, rgb_component_value, rgb_component_index
has '_pixel_coords_hash' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Int],
  lazy        => $TRUE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _set_pixel_properties => 'set',
    _get_pixel_properties => 'get',
    _has_pixel_property   => 'exists',
  },
  doc => 'Properties of pixel undergoing modification',
);

# _image {{{1
has '_image' => (
  is      => 'ro',
  isa     => Types::Standard::InstanceOf ['Image::Magick'],
  lazy    => $LAZY,
  default => sub {
    my $self = $_[0];
    if (not $self->filepath) {
      confess 'No image filepath provided';
    }
    return $self->image_create($self->filepath);
  },
  doc => 'ImageMagick object',
);

# methods

# modify_pixel() {{{1
#
# does:   modify pixel rgb component
# params: nil
# prints: feedback if fails
# return: n/a, dies on failure
sub modify_pixel ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # increment RGB value
  my $rgb_value = $self->_pixel_rgb_component_value
      + $self->_pixel_rgb_component_increment;

  # check whether new value is invalid
  # - since high initial values decrement and low initial
  #   values increment, in practice values outside 1-255
  #   should never occur
  if (($rgb_value <= 0) or ($rgb_value > $MAX_RGB)) {
    confess "Invalid RGB value '$rgb_value'";
  }

  # update independent rgb value tracking
  $self->_pixel_rgb_component_value($rgb_value);

  # update image object
  my $image = $self->_image;
  my @color = $self->image_pixel_color($image, $self->pixel_coords);
  my $index = $self->pixel_rgb_component_index;
  $color[$index] = $rgb_value;
  $self->image_pixel_color($image, $self->pixel_coords, @color);

  return;
}

# pixel_rgb_component_index([$index]) {{{1
#
# does:   setter and getter for index of pixel rgb component to modify
# params: $index - index of rgb component
#                  int, 0-2, optional: present if setter, absent if getter]
# prints: nil
# return: integer if getter
#         nil if setter
sub pixel_rgb_component_index ($self, $index = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # take care because $index legitimately can be 0

  if (defined $index) {    # setter

    # can only be 0, 1 or 2
    my @match = grep { $index =~ /\A$_\z/xsm } qw(0 1 2);
    confess if not @match;
    $self->_set_pixel_properties(rgb_component_index => $index);
    return $TRUE;
  }
  else {                   # getter

    # check that index has been set
    confess 'RGB component index not set'
        if not $self->_has_pixel_property($RGB_COMPONENT_INDEX);

    # return index
    return $self->_get_pixel_properties($RGB_COMPONENT_INDEX);
  }
}

# pixel_coords([$x], [$y]) {{{1
#
# does:   setter and getter for x and y pixel coords
# params: $x - x-coordinate
#              [int, optional: present if setter, absent if getter]
#         $y - y-coordinate
#              [int, optional: present if setter, absent if getter]
# prints: nil
# return: list of integers ($x, $y) if getter
#         nil if setter
sub pixel_coords ($self, @coords)
{    ## no critic (RequireInterpolationOfMetachars)

  if (@coords) {    # setter

    # need two coords
    my $count = @coords;
    if ($count != 2) {
      confess "Need 2 arguments (got $count)";
    }

    # need integer coords
    for my $coord (@coords) {
      if (not $self->int_pos_valid($coord)) {
        confess "Non-integer coordinate '$coord'";
      }
    }

    # set coords
    my ($x, $y) = @coords;
    $self->_set_pixel_properties(x => $x, y => $y);
    return $TRUE;
  }
  else {    # getter

    # check that coords have been set
    if (not $self->has_pixel_coords) {
      confess 'Pixel coordinates not set';
    }

    # return coords
    my @pixel_coords = $self->_get_pixel_properties(qw(x y));
    return @pixel_coords;
  }
}

# write_file($filepath) {{{1
#
# does:   write image to file
# params: $filepath - path of file to write
# prints: feedback if fails
# return: n/a, dies on failure
sub write_file ($self, $filepath)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $filepath) {
    confess 'No filepath provided';
  }
  $self->image_write($self->_image, $filepath);
  return;
}

# has_pixel_coords() {{{1
#
# does:   Determine whether both x and y pixel coordinates have been set
# params: nil
# prints: nil
# return: scalar boolean
sub has_pixel_coords ($self) {  ## no critic (RequireInterpolationOfMetachars)
  return (  $self->_has_pixel_property(q{x})
        and $self->_has_pixel_property(q{y}));
}

# _pixel_rgb_component_value([$value]) {{{1
#
# does:   setter and getter for value of pixel rgb component to modify
# params: $value - value of rgb component
#                  int, 0-255, optional: present if setter, absent if getter]
# prints: nil
# return: integer if getter
#         nil if setter
# note:   question - why track the value of the pixel rgb component being
#                    modified when it is always available from the image
#                    object/file undergoing modification?
#         answer   - track this independently of the image file itself because
#                    the value written to the image file is not always the same
#                    as the value in the Image::Magick object
#                  - more plainly, it is possible to create an Image::Magick
#                    object, read from the image file, alter a given pixel's
#                    color component value in the object, rewrite the image
#                    file, then reread the image file only to discover the same
#                    pixel's color component value has its original value
#                  - the main cause seems to be one of "granularity" -- if the
#                    color component value in the derived Image::Magick object
#                    is not changed by a sufficiently large amount, the change
#                    does not "take" when rewriting the file
#                  - this "granularity" does not appear to be consistent; an
#                    increment that successfully modifies a pixel's color
#                    component value in one file will not do so in another
#                  - so, this attribute will be the primary record of the color
#                    component value; if one increment does not result in a
#                    change to the value in the file, repeated modifications
#                    eventually will
sub _pixel_rgb_component_value ($self, $value = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # take care because $value legitimately can be 0

  if (defined $value) {    # setter

    # can only be 0-255
    if (not $self->int_pos_valid($value)) {
      confess "Value '$value' is not a positive integer";
    }
    if ($value > $MAX_RGB) {
      confess "Value '$value' not in range 0-255";
    }

    # set value
    $self->_set_pixel_properties(rgb_component_value => $value);

    return $TRUE;
  }
  else {    # getter

    # return value if set; if not ...
    if ($self->_has_pixel_property($RGB_COMPONENT_VALUE)) {
      return $self->_get_pixel_properties($RGB_COMPONENT_VALUE);
    }
    else {    # ... initialise value and return it

      # need pixel x and y coordinates
      if (not $self->has_pixel_coords) {
        confess 'Pixel coordinates not available';
      }

      # get rgb component of pixel
      my $image  = $self->_image;
      my @coords = $self->pixel_coords;
      my @color  = $self->image_pixel_color($image, @coords);
      my $index  = $self->pixel_rgb_component_index;

      # initialise
      $self->_set_pixel_properties(rgb_component_value => $color[$index]);

      # return value
      return $color[$index];
    }

  }
}

# _pixel_rgb_component_increment() {{{1
#
# does:   increment by which to modify pixel rgb component
# params: nil
# prints: nil
# return: scalar integer
sub _pixel_rgb_component_increment ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  return ($self->_pixel_rgb_component_value <= $RGB_COMPONENT_MAX)
      ? $POS_SIX
      : $NEG_SIX;
}    # }}}1

1;

# POD {{{1

## no critic (RequirePodSections)

__END__

=encoding utf8

=head1 NAME

Dn::Images::Uniquefy::ModifyImage - modify image pixels

=head1 SYNOPSIS

    use Dn::Images::Uniquefy::ModifyImage;
    ...

=head1 DESCRIPTION

This module is intended to be used by the Dn::Images::Uniquefy module, and
that is probably the module you should use.

This module assists in modifying pixel color. In particular, it modifies a
single color component (red, green or blue) of a specified pixel by a given
increment.

=head1 ATTRIBUTES

=head2 filepath

Path to input image file.

=head2 width

Image width in pixels. Read-only. Will cause module to die if image filepath
has not been set.

=head2 height

Image height in pixels. Read-only. Will cause module to die if image filepath
has not been set.

=head1 METHODS

=head2 modify_pixel()

Modify pixel color component. Requires that the following have been provided:
image file (C<filepath> attribute), pixel coordinates (C<pixel_coords> method)
and color component (C<pixel_rgb_component_index> method).

=head3 Params

Nil.

=head3 Prints

Error messages if the operation fails.

=head3 Returns

Nil. Image object is edited in place and method dies on failure.

=head2 pixel_rgb_component_index([$index])

Setter and getter for index of pixel rgb component to modify.

=head3 Params

=over

=item $index

Index of rgb color component to modify. Optional. If this parameter is supplied
it is set. Value is not provided when method is called as a getter. Must be an
integer in the range 0-2.

=back

=head3 Prints

Nil.

=head3 Returns

If called as setter: no meaningful value is returned.

If called as getter: scalar integer is returned.

=head2 pixel_coords([$x], [$y])

Setter and getter for x and y coordinates of pixel to be modified.

=head3 Params

=over

=item $x

X-coordinate of pixel to be modified. Optional. If value is provided it is set.
Value is not provided when method is called as a getter.

=item $y

Y-coordinate of pixel to be modified. Optional. If value is provided it is set.
Value is not provided when method is called as a getter.

=back

=head3 Prints

Nil.

=head3 Returns

If called as setter: no meaningful value is returned.

If called as getter: list of integers ($x, $y).

=head2 write_file($filepath)

Write image to file.

=head3 Params

=over

=item $filepath

Path of file to write.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Nil. Method dies on failure.

=head2 has_pixel_coords()

Determine whether both x and y pixel coordinates have been set.

=head3 Params

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Const::Fast, English, Moo, MooX::HandlesVia, namespace::clean,
Role::Utils::Dn, strictures, Types::Standard,  version.

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
