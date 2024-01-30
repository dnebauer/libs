package Dn::Cards::Resize;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(croak);
use Cwd;
use Dn::Cards::Resize::Dimensions;
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use Scalar::Util qw(blessed);
use Readonly;
use Term::ProgressBar::Simple;
use Types::Standard;

with qw(
    Dn::Role::HasImage
    Dn::Role::HasPath
);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                           }}}1

# debug
use Data::Dumper::Simple;

# attributes

# card_type                                                            {{{1
has 'type' => (
    is      => 'rw',
    isa     => Types::Standard::Str,
    default => q{},
    doc     => q{Card type ('bridge', 'european', 'euromini', }
        . q{'large', 'mini', 'poker', 'square', 'tarot')},
);

# preserve_aspect_ratio                                    {{{1
has 'preserve_aspect_ratio' => (
    is      => 'rw',
    isa     => Types::Standard::Bool,
    default => $TRUE,
    doc     => 'Whether to preserve aspect ratioi (default: true)',
);

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
);

# bleed_color                                                          {{{1
has 'bleed_color' => (
    is      => 'rw',
    isa     => Types::Standard::Str,
    default => 'none',
    doc     => "Color of bleed border (default: 'none' = transparent)",
);

# image_files, add_image_files, _files                                 {{{1
has 'image_files' => (
    is          => 'rw',
    isa         => Types::Standard::ArrayRef [Types::Standard::Str],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        add_image_files => 'push',
        _files          => 'elements',
    },
    doc => 'Image files',
);

# _dimensions                                                          {{{1
has '_dimensions' => (
    is  => 'lazy',
    isa => Types::Standard::InstanceOf ['Dn::Cards::Resize::Dimensions'],
    doc => 'Final dimensions of image',
);

method _build__dimensions () {
    my $dimensions;
    my $card_type = $self->card_type;
    if ($card_type) {          # use card dimensions

        # can't also specify custom width and height
        if ( $self->width or $self->height ) {
            croak "Can't specify both card type and custom dimensions";
        }

        # use card dimensions
        $dimensions = $self->_card($card_type);
    }
    else {                     # use specified custom values

        # width and height are required
        my $width  = $self->width;
        my $height = $self->height;
        if ( not( $width and $height ) ) {
            croak 'Must specify image dimensions or card type';
        }

        # bleed dimensions are optional
        my $bleed_horizontal = $self->bleed_horizontal;
        my $bleed_vertical   = $self->bleed_vertical;

        $dimensions = Dn::Cards::Resize::Dimensions->new(
            width            => $width,
            height           => $height,
            bleed_horizontal => $bleed_horizontal,
            bleed_vertical   => $bleed_vertical,
        );
    }

    return $dimensions;
}

# _orig_dir                                                            {{{1
has '_orig_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => 'Directory in which script is run',
);

method _build__orig_dir () {
    return Cwd::getcwd();
}

# _temp_dir                                                            {{{1
has '_temp_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => 'Temporary working directory',
);

method _build__temp_dir () {
    return $self->dir_temp();
}

# _card, _valid_card                                                   {{{1
has '_card_dimensions' => (
    is  => 'lazy',
    isa => Types::Standard::HashRef [
        Types::Standard::InstanceOf ['Dn::Cards::Resize::Dimensions']
    ],
    handles_via => 'Hash',
    handles     => {
        _card       => 'get',
        _valid_card => 'exists',
    },
    doc => 'Card dimensions',
);

method _build__card_dimensions () {

    # bridge                                                           {{{2
    my $bridge = Dn::Cards::Resize::Dimensions->new(
        width            => 1346,
        height           => 2100,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # european                                                         {{{2
    my $european = Dn::Cards::Resize::Dimensions->new(
        width            => 1488,
        height           => 2076,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # european mini                                                    {{{2
    my $euromini = Dn::Cards::Resize::Dimensions->new(
        width            => 1039,
        height           => 1581,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # large                                                            {{{2
    my $large = Dn::Cards::Resize::Dimensions->new(
        width            => 2102,
        height           => 3445,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # mini                                                             {{{2
    my $mini = Dn::Cards::Resize::Dimensions->new(
        width            => 1050,
        height           => 1498,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # poker                                                            {{{2
    my $poker = Dn::Cards::Resize::Dimensions->new(
        width            => 1500,
        height           => 2100,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # square                                                           {{{2
    my $square = Dn::Cards::Resize::Dimensions->new(
        width            => 1654,
        height           => 1654,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # tarot                                                            {{{2
    my $tarot = Dn::Cards::Resize::Dimensions->new(
        width            => 1654,
        height           => 2855,
        bleed_horizontal => 70,
        bleed_vertical   => 70,
    );

    # return types                                                     {{{2
    return {
        bridge   => $bridge,
        european => $european,
        euromini => $euromini,
        large    => $large,
        mini     => $mini,
        poker    => $poker,
        square   => $square,
        tarot    => $tarot,
    };    #                                                            }}}2

}    #                                                                 }}}1

# methods

# resize_images()                                                      {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
method resize_images () {

    # pre-flight check
    if ( not $self->_checks_ok ) { return; }

    # cycle through image files
    my @files    = $self->_files;
    my $count    = scalar @files;
    my $progress = 0;
    if ( $count == 1 ) { say "Resizing image file '$files[0]'"; }
    else {
        say "\nResizing $count image files:";
        $progress = Term::ProgressBar::Simple->new($count);
    }
    for my $file (@files) {

        my $image = $self->image_create($file);

        # resize image and add bleed borders
        my $dimensions = $self->_dimensions;
        $self->image_resize( $image, $dimensions->width, $dimensions->height,
            preserve => $self->preserve_aspect_ratio, );
        $self->image_add_border(
            $image,
            $dimensions->bleed_horizontal,
            $dimensions->bleed_vertical,
            $self->bleed_color
        );
        $self->_write_to_temp_dir( $image, $file );
        undef $image;    # avoid memory cache overflow

        $progress++;
    }

    undef $progress;     # ensure final messages displayed

    # copy temporary files over original files (dies on failure)
    say 'Overwriting with resized files';
    $self->dir_copy( $self->_temp_dir, $self->_orig_dir );

    say 'Processing complete';

    return $TRUE;
}

# _checks_ok()                                                         {{{1
#
# does:   check validity of files and requested operations
# params: nil
# prints: feedback
# return: n/a, dies on failure
method _checks_ok () {

    my @files = $self->_files;

    # card type must be valid                                          {{{2
    if ( $self->card_type and not $self->_valid_card( $self->card_type ) ) {
        warn q{Invalid card type '} . $self->card_type . "'\n";
        return;
    }

    # check for output filename collisions                             {{{2
    # - input image files are specified by filepaths
    # - output files are in current working directory and share the
    #   basename of the parent
    # - it is therefor possible that multiple input file paths could
    #   be from different directories but have the same filename
    # - this would result in output files from those input files
    #   having the same name
    my %dupes = %{ $self->file_name_duplicates(@files) };
    if ( scalar keys %dupes ) {
        warn "Multiple input file paths have the same file name.\n";
        warn "Input filepaths that have the same file name will\n";
        warn "generate output files with the same name.\n";
        warn "Since all output files are written to the current\n";
        warn "directory, and existing files are silently overwritten,\n";
        warn "this will result in some later output files overwriting\n";
        warn "earlier output files.\n";
        warn "Problem filename(s) are:\n";

        while ( ( $name, $paths ) = each %dupes ) {
            warn "- $name\n";
            for my $path ( @{$paths} ) { warn "  - $path\n"; }
        }
        warn "Aborting.\n";
        return;
    }

    # ensure all files can be opened as images                         {{{2
    if ( not $self->image_files_valid(@files) ) {
        warn "Invalid image file(s) specified\n";
        return;
    }

    # require either card type or dimensions                           {{{2
    if ( $self->card_type ) {    # can't have width and height as well
        if ( $self->width or $self->height ) {
            warn "Can't specify card type and image dimensions\n";
            return;
        }
    }
    else {                       # no card type so need both dimensions
        if ( not( $self->width and $self->height ) ) {
            warn "Need to specify image dimensions (or card type)\n";
            return;
        }
    }

    return $TRUE;
}

# _write_to_temp_dir($image, $orig_fp)                                 {{{1
#
# does:   write image to temporary directory
# params: $orig_fp - original path of image file
# prints: feedback if fails
# return: n/a, dies on failure
method _write_to_temp_dir ($image, $orig_fp) {

    # check args
    croak 'No filepath provided' if not $orig_fp;
    croak 'No image provided'    if not $image;
    croak 'Not an image object'  if not $self->image_object($image);

    # get target filepath
    my $temp_fp = $self->file_cat_dir( $orig_fp, $self->_temp_dir );

    # write image file to temporary directory
    $self->image_write( $image, $temp_fp );
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Cards::Resize - resize images, optionally adding bleed borders

=head1 SYNOPSIS

    use Dn::Cards::Resize;
    ...

=head1 DESCRIPTION

This module resizes image files and saves them to the current directory,
overwriting any existing files with the same name. A "bleed border" of any
color can be added to the image as well.

Width and height, and and additional side and top/bottom bleed borders, can be
specified explicitly using the appropriate module attributes. The module also
provides sensible default values for resizing images to suit Printer's Studio
game card types.

=head2 Resizing and aspect ratio

By default each image is resized to the maximum possible height and width to
fit onto the specified card type, while preserving the aspect ratio. If the
initial image has a markedly different aspect ratio to the resized dimensions,
the resizing process can result in significant blank space on the sides or
top/bottom of the resulting images.

If aspect ratio is not preserved (by setting the C<preserve_aspect_ratio>
attribute to false) the image is resized to fit the specified dimensions. That
is, the images are stretched vertically and horizontally to fit the new
dimensions. If the initial image has a markedly different aspect ratio to the
resized dimensions, the resizing process can result in significant distortion
of the image.

=head2 Bleed border

Once the image is resized bleed borders can be added to the sides and
top/bottom of the image. This is done by setting the C<bleed_horizontal> and
C<bleed_vertical> to non-zero (positive) values. The default is to make the
bleed borders transparent. The bleed borders can be changed to a particular
color by setting the C<bleed_color> attribute.

=head2 Printer's Studio support

As noted earlier, this module provides support for converting images into
suitable dimensions for use as Printer's Studio game cards. The following table
shows the physical dimensions of the available card types and the size in
pixels used by this module. It is assumed that for all images the vertical
resolution is the same as the horizontal resolution.

 Card type     | Option     Height   Width  Height  Width
               | value       (mm)     (mm)   (px)    (px)
 --------------|-----------------------------------------
 Bridge        | bridge       89      57     2100    1346
 European      | european     88      63     2076    1488
 European Mini | euromini     67      44     1581    1039
 Large         | large       146      89     3445    2102
 Mini          | mini         63.5    44.45  1498    1050
 Poker         | poker        89      63.5   2100    1500
 Square        | square       70      70     1652    1654
 Tarot         | tarot       121      70     2855    1654

A bleed border of 70 pixels is added to each side of the resized images.

=head2 Overwriting files

The original files are overwritten by the transformed images so it advisable to
save copies of them before running this script.

=head2 Duplicate file names

The input files are specified by file paths which can involve multiple
directory paths. It is possible, therefor, that input image files in different
directories could have the same file name.

All output image files, by contrast, are written to the current working
directory. Output image file names are are the same as their input ("parent")
image files, ignoring the input images' directories. Since there can be
duplicate input image file names in a set of input images, there can be
duplicate output image file names in the corresponding set of output image
files. For that reason, the C<resize_images> method will abort if it detects
multiple input filepaths with identical file names.

=head1 ATTRIBUTES

=head2 card_type

Used when resizing images for use as Printer's Studio game cards. The available
card types are: 'bridge', 'european', 'euromini' (European Mini), 'large',
'mini', 'poker', 'square' and 'tarot'. See the L<Printer's Studio Custom Game
Cards page|http://www.printerstudio.com/unique-ideas/blank-playing-cards.html>
for details. Optional. No default value.

=head2 preserve_aspect_ratio

Whether to preserve aspect ratio when resizing. Optional. Default: true.

=head2 width

Image width of resized image. Required unless using C<card_type> attribute. No
default value.

=head2 height

Image height of resized image. Required unless using C<card_type> attribute. No
default value.

=head2 bleed_horizontal

Size in pixels of bleed border for left and right sides of images. Optional.
Default: 0.

Note that if C<bleed_horizontal> remains set to zero no bleed border will be
added to the left and right sides of resized images.

=head2 bleed_vertical

Size in pixels of bleed border for top and bottom sides of images. Optional.
Default: 0.

Note that if C<bleed_vertical> remains set to zero no bleed border will be
added to the top and bottom sides of resized images.

=head2 bleed_color

Color of the bleed borders. Optional. Default: 'none' (transparent).

Available color schemes and colors are described in the L<ImageMagick color
page|https://people.debian.org/~naoliv/misc/imagemagick/link/www/color.html>.
On debian systems the libimage-magick-perl package provides a similar page at
F</usr/share/doc/libimage-magick-perl/html/www/color.html>.

Note that setting bleed color without setting a non-zero bleed border size
(using the C<bleed_horizontal> and C<bleed_vertical> attributes) will have no
effect.

=head2 image_files

Images to be resized. Specifying files other than image files will result in
the Image::Magick module dying when it attempts to load the image, which also
causes this module to die.

=head1 METHODS

=head2 add_image_files(@filepaths)

Specify additional image files to be resized.

=head3 Parameters

=over

=item $param

Paths of additional image files to be resized. Duplicate filepaths will be
ignored. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 resize_images()

Resize specified images and, optionally, add bleed borders to them. Resized
image files are written to the current working directory.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Cwd, Dn::Cards::Resize::Dimensions, Dn::Role, English,
Function::Parameters, Moo, MooX::HandlesVia, namespace::clean, Readonly,
Scalar::Util, strictures, Term::ProgressBar::Simple, Types::Standard, version.

=head2 INCOMPATIBILITIES

There are no known incompatibilities with other modules.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
