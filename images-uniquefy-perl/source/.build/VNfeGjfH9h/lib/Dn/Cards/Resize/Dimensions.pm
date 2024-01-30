package Dn::Cards::Resize::Dimensions;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;
use English qw(-no_match_vars);
use Types::Standard;    #                                              }}}1

# debug
use Data::Dumper::Simple;

# attributes

# width                                                                {{{1
has 'width' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Width of resized image (in pixels)',
);

# height                                                                {{{1
has 'height' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Height of resized image (in pixels)',
);

# bleed_horizontal                                                     {{{1
has 'bleed_horizontal' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Size of left and right bleed borders (in pixels)',
);

# bleed_vertical                                                       {{{1
has 'bleed_vertical' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Size of top and bottom bleed borders (in pixels)',
);    #                                                                }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Cards::Resize::Dimensions - store image dimensions

=head1 SYNOPSIS

    use Dn::Cards::Resize::Dimensions;
    ...

=head1 DESCRIPTION

This module is designed for use by Dn::Cards::Resize. It stores image size and
the widh of bleed borders.

=head1 ATTRIBUTES

=head2 width

Image width. Optional. Default: 0.

=head2 height

Image height. Optional. Default: 0.

=head2 bleed_horizontal

Size of bleed border for left and right sides of images. Optional.  Default: 0.

=head2 bleed_vertical

Size of bleed border for top and bottom sides of images. Optional.  Default: 0.

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
