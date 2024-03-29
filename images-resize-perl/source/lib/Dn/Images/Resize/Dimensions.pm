package Dn::Images::Resize::Dimensions;

use Moo;                # {{{1
use strictures 2;
use 5.006;
use 5.036_001;
use version; our $VERSION = qv('0.3');
use namespace::clean;
use English qw(-no_match_vars);
use Types::Standard;    # }}}1

# attributes

# width {{{1
has 'width' => (
  is      => 'rw',
  isa     => Types::Standard::Int,
  default => 0,
  doc     => 'Width of resized image (in pixels)',
);

# height {{{1
has 'height' => (
  is      => 'rw',
  isa     => Types::Standard::Int,
  default => 0,
  doc     => 'Height of resized image (in pixels)',
);

# border_horizontal {{{1
has 'border_horizontal' => (
  is      => 'rw',
  isa     => Types::Standard::Int,
  default => 0,
  doc     => 'Size of left and right borders (in pixels)',
);

# border_vertical {{{1
has 'border_vertical' => (
  is      => 'rw',
  isa     => Types::Standard::Int,
  default => 0,
  doc     => 'Size of top and bottom borders (in pixels)',
);    # }}}1

1;

# POD {{{1

## no critic (RequirePodSections)

__END__

=encoding utf8

=head1 NAME

Dn::Images::Resize::Dimensions - store image dimensions

=head1 SYNOPSIS

    use Dn::Images::Resize::Dimensions;
    ...

=head1 DESCRIPTION

This module is designed for use by Dn::Images::Resize. It stores image size and
the width of image borders.

=head1 ATTRIBUTES

=head2 width

Image width. Optional. Default: 0.

=head2 height

Image height. Optional. Default: 0.

=head2 border_horizontal

Size of border for left and right sides of images. Optional.  Default: 0.

=head2 border_vertical

Size of border for top and bottom sides of images. Optional.  Default: 0.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

English, Moo, namespace::clean, strictures, Types::Standard, version.

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
