package Dn::Images::Resize;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(confess);
use Cwd;
use Dn::Images::Resize::Dimensions;
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use Readonly;
use Term::ProgressBar::Simple;
use Types::Standard;

with qw(Role::Utils::Dn);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                           }}}1

# attributes

# width                                                                {{{1
has 'width' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => q[Width of resized image (in pixels)],
);

# height                                                                {{{1
has 'height' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => q[ Height of resized image (in pixels) ],
);

# preserve_aspect_ratio                                    {{{1
has 'preserve_aspect_ratio' => (
    is      => 'rw',
    isa     => Types::Standard::Bool,
    default => $TRUE,
    doc     => q[ Whether to preserve aspect ratio (default: true) ],
);

# fill_color                                                           {{{1
has 'fill_color' => (
    is      => 'rw',
    isa     => Types::Standard::Str,
    default => 'none',
    doc     => q[ Fill color (default: 'none' = transparent) ],
);

# border_horizontal                                                    {{{1
has 'border_horizontal' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => q[ Size of left and right borders (in pixels) ],
);

# border_vertical                                                      {{{1
has 'border_vertical' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => q[ Size of top and bottom borders (in pixels) ],
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
    doc => q[ Image filepaths ],
);

# _dimensions                                                          {{{1
has '_dimensions' => (
    is  => 'lazy',
    isa => Types::Standard::InstanceOf ['Dn::Images::Resize::Dimensions'],
    doc => q[ Final dimensions of image ],
);

method _build__dimensions () {

    return Dn::Images::Resize::Dimensions->new(
        width             => $self->width,
        height            => $self->height,
        border_horizontal => $self->border_horizontal,
        border_vertical   => $self->border_vertical,
    );
}

# _orig_dir                                                            {{{1
has '_orig_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => q[ Directory in which script is run ],
);

method _build__orig_dir () {
    return Cwd::getcwd();
}

# _temp_dir                                                            {{{1
has '_temp_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => q[ Temporary working directory ],
);

method _build__temp_dir () {
    return $self->dir_temp();
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

    my $dimensions = $self->_dimensions;

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

        # resize image and add borders
        $self->image_resize( $image, $dimensions->width, $dimensions->height,
            $self->fill_color, preserve => $self->preserve_aspect_ratio, );
        $self->image_add_border(
            $image,
            $dimensions->border_horizontal,
            $dimensions->border_vertical,
            $self->fill_color,
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

        while ( my ( $name, $paths ) = each %dupes ) {
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

    # require dimensions and/or borders                                {{{2
    if (    ( not( $self->width and $self->height ) )
        and ( not( $self->border_horizontal and $self->border_vertical ) ) )
    {
        warn "No dimensions or borders provided\n";
        warn "No resizing will be performed\n";
        return;
    }    #                                                             }}}2

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
    confess 'No filepath provided' if not $orig_fp;
    confess 'No image provided'    if not $image;
    confess 'Not an image object'  if not $self->image_object($image);

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

Dn::Images::Resize - resize images, optionally adding borders

=head1 SYNOPSIS

    use Dn::Images::Resize;
    ...

=head1 DESCRIPTION

This module resizes image files and/or adds borders, and saves them to the
current directory, overwriting any existing files with the same name.

Width and height, and additional side and top/bottom borders, can be specified
explicitly using the appropriate module attributes.

=head2 Resizing and aspect ratio

If height and width are provided the default behaviour is to resize each image
to the maximum possible height and width that fits into the resized dimensions,
while preserving the aspect ratio. If the initial image has a markedly
different aspect ratio to the resized dimensions, the resizing process can
result in significant additional space on the sides or top/bottom of the
resulting images. This new space is filled with the specified fill color
(C<fill_color> attribute).

If aspect ratio is not preserved (by setting the C<preserve_aspect_ratio>
attribute to false) the image is resized to fit the specified dimensions. That
is, the images are stretched vertically and horizontally to fit the new
dimensions. If the initial image has a markedly different aspect ratio to the
resized dimensions, the resizing process can result in significant distortion
of the image.

=head2 Border

Once the image is resized borders can be added to the sides and top/bottom of
the image. These may be bleed borders added so that printing extends to the
edge of cut pages. Borders are added by setting the C<border_horizontal> and
C<border_vertical> to non-zero (positive) values. The border color is set using
the C<fill_color> attribute; the default is to make them transparent.

=head2 Scripts

Two command line utilities are provided with this module: S<<
C<dn-images-resize> >> and S<< C<dn-images-printerstudio-resize> >>. See the
following section for more details on Printer's Studio support. See the script
man pages for more information on their use.

=head2 Printer's Studio support

The script S<< C<dn-images-printerstudio-resize> >> provided with this module
provides support for converting images into suitable dimensions for use as
Printer's Studio game cards. See the script's man page for further information.

=head2 Overwriting files

All transformed images are written to the current directory. If this is where
the original files were located they are silently overwritten, so it is
advisable to save copies of them before running this script. Any previously
written output files in this directory are also silently overwritten.

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

=head2 width

Image width of resized image. Required. No default value.

=head2 height

Image height of resized image. Required. No default value.

=head2 preserve_aspect_ratio

Whether to preserve aspect ratio when resizing. Optional. Default: true.

=head2 fill_color

Color used for additional space added to the image when resizing (when aspect
ratio is preserved). This color is also used for borders. Optional. Default:
'none' (transparent).

Available color schemes and colors are described in the L<ImageMagick color
page|https://people.debian.org/~naoliv/misc/imagemagick/link/www/color.html>.
On debian systems the libimage-magick-perl package provides a similar page at
F</usr/share/doc/libimage-magick-perl/html/www/color.html>.

Note that setting fill color will have no effect on the final image if aspect
ratio is ignored (because the image is stretched to cover the entirety of the
resized dimensions) and borders are set to zero width.

=head2 border_horizontal

Size in pixels of border for left and right sides of images. Optional.
Default: 0.

Note that if C<border_horizontal> remains set to zero no border will be added
to the left and right sides of resized images.

=head2 border_vertical

Size in pixels of border for top and bottom sides of images. Optional.
Default: 0.

Note that if C<border_vertical> remains set to zero no border will be added to
the top and bottom sides of resized images.

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

Resize specified images and, optionally, add borders to them. Resized image
files are written to the current working directory.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Cwd, Dn::Images::Resize::Dimensions, Role::Utils::Dn, English,
Function::Parameters, Moo, MooX::HandlesVia, namespace::clean, Readonly,
strictures, Term::ProgressBar::Simple, Types::Standard, version.

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
