package Dn::Cards::UniquefyImages;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(croak);
use Dn::Cards::UniquefyImages::Image;
use Dn::Cards::UniquefyImages::PixelsProcessed;
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use Readonly;
use Types::Standard;
use experimental 'switch';

with qw(
    Dn::Role::HasImage
    Dn::Role::HasPath
);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                           }}}1

# debug
use Data::Dumper::Simple;

# attributes

# image_files, add_image_files, _files                                 {{{1
has 'image_files' => (
    is          => 'rw',
    isa         => Types::Standard::ArrayRef [Types::Standard::Str],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        add_image_files => 'push',
        _files          => 'elements'
    },
    doc => 'Image files',
);

# _orig_dir                                                            {{{1
has '_orig_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => 'Directory in which script is run',
);

method _build__orig_dir () {
    return $self->dir_current;
}

# _temp_dir                                                            {{{1
has '_temp_dir' => (
    is  => 'lazy',
    isa => Types::Standard::Str,
    doc => 'Temporary working directory',
);

method _build__temp_dir () {
    return $self->dir_temp;
}

# _add_processed_file, _processed_files                                {{{1
has '_processed_files_list' => (
    is          => 'rw',
    isa         => Types::Standard::ArrayRef [Types::Standard::Str],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        _add_processed_file => 'push',
        _processed_files    => 'elements',
    },
    doc => 'Processed files',
);

# _max_x                                                               {{{1
has '_max_x' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Maximum image height',
);

# _max_y                                                               {{{1
has '_max_y' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 0,
    doc     => 'Image width',
);

# _pixels_processed                                                    {{{1
has '_pixels_processed' => (
    is  => 'lazy',
    isa => Types::Standard::InstanceOf [
        'Dn::Cards::UniquefyImages::PixelsProcessed'],
    doc => 'Pixels that have been processed (altered)',
);

method _build__pixels_processed () {
    return Dn::Cards::UniquefyImages::PixelsProcessed->new;
}

# _rgb_component_index                                                 {{{1
has '_rgb_component_index' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => '0',
    doc     => 'RGB color component (0 = red, 1 = green, 2 = blue)',
);    #                                                                }}}1

# methods

# uniquefy_images()                                                    {{{1
#
# does:   tweak files to ensure they are unique
# params: nil
# prints: user feedback and error messages
# return: boolean scalar indicating success
#         note that method dies on serious failures
method uniquefy_images () {

    # validate image files and set maximum height and width
    if ( not $self->_preprocess_files ) { return; }

    # create unique image files in temporary directory
    my @files = $self->_files;
    my $count = scalar @files;
    my $progress;
    say "\nUniquefying $count image files:";
    $progress = Term::ProgressBar::Simple->new($count);
    for my $file (@files) {

        # modify (if necessary) till image file is unique
        my $image = $self->_new_image($file);
        $image->write_image( $self->_temp_fp($file) );
        while ( not $self->_is_unique($file) ) {
            if ( not $image->pixel_x ) { $self->_set_next_pixel($image); }
            $image->modify_pixel;
            $image->write_file( $self->_temp_fp($file) );
        }

        # if here then successfully "uniquefied" file
        $self->_add_processed_file($file);
        undef $image;    # avoid memory cache overflow

        $progress++;
    }

    undef $progress;     # ensure final messages displayed

    # copy temporary files over original files
    say 'Overwriting with unique files';
    $self->dir_copy( $self->_temp_dir, $self->_orig_dir );

    say 'Processing complete';

    return $TRUE;
}

# _preprocess_files()                                                  {{{1
#
# does:   check file validity and set max height and width
# params: nil
# prints: error message on failure
# return: n/a, exit on failure
method _preprocess_files () {
    my @files = $self->_files;

    # need at least two files                                          {{{2
    my $count = scalar @files;
    if ( not $count ) {
        warn "No image files specified\n";
        return $FALSE;
    }
    if ( $count == 1 ) {
        warn "Only one image file specified\n";
        return $FALSE;
    }

    # must all be valid image files                                    {{{2
    # - method croaks if image file invalid
    if ( not $self->image_files_valid(@files) ) {
        warn "Invalid image file(s) detected\n";
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

    # get maximum image dimensions                                     {{{2
    my ( $width, $height ) = $self->image_max_dimensions(@files);
    $self->_max_x = $width;
    $self->_max_y = $height;    #                                      }}}2

    return $TRUE;
}

# _new_image($file)                                                    {{{1
#
# does:   create new image object
#
# params: $file - path of image file
# prints: error message on failure
# return: Dn::Cards::UniquefyImages::Image object
method _new_image ($file) {
    return Dn::Cards::UniquefyImages::Image->new( filepath => $file );
}

# _temp_fp($filepath)                                                  {{{1
#
# does:   get path of file in temporary directory
#
# params: $filepath - (relative) path of original image file
# prints: error message if invalid inputs
# return: filepath [Str], exits on failure
method _temp_fp ($filepath) {
    croak 'No filepath provided' if not $filepath;
    my $name = $self->file_name($filepath);
    return $self->file_cat_dir( $name, $self->_temp_dir );
}

# _is_unique($file)                                                    {{{1
#
# does:   test whether image file is unique, i.e., not
#         identical to any previously processed image file
# params: nil
# prints: error message if invalid inputs
# return: bool, exits on failure
method _is_unique ($file) {

    croak 'No filepath provided' if not $file;
    my $fp = $self->_temp_fp($file);

    # get previously processed images
    my @processed_files = $self->_processed_files;

    # special case: first file to be processed
    if ( not @processed_files ) { return $TRUE; }

    # compare this image file with previously written image files
    # - if identical to any, return false
    for my $processed_file (@processed_files) {
        my $processed_fp = $self->_temp_fp($processed_file);
        return $FALSE if $self->file_identical( $fp, $processed_fp );
    }

    # if here then no files matched as identical,
    # and the file is therefore unique
    return $TRUE;
}

# _set_next_pixel($image)                                              {{{1
#
# does:   set image with details of next pixel to modify
#
# params: nil
# prints: error message if invalid inputs
# return: n/a, exits on failure
method _set_next_pixel ($image) {

    # check arg
    croak 'No image provided' if not $image;
    if ( not $image ) { croak 'No image provided'; }
    my $object_type = Scalar::Util::blessed $image;
    if ( $object_type ne 'Dn::Cards::UniquefyImages::Image' ) {
        croak "Invalid object type '$object_type' provided";
    }

    # get max x- and y-coords
    my ( $max_x, $max_y ) = ( $self->_max_x, $self->_max_y );
    if ( $image->height lt $max_y ) { $max_y = $image->height - 1; }
    if ( $image->width lt $max_x )  { $max_x = $image->width - 1; }

    # now find next available pixel
    my ( $x, $y ) = ( $max_x, $max_y );
    while ( $self->_pixels_processed->pixel_is_processed( $x, $y ) ) {
        if ( $x == 1 ) {
            if ( $y == 1 ) {    # (1, 1)
                my $component = $self->_rgb_component_index;
                croak 'Exhausted RGB components' if $component == 2;
                $self->_rgb_component_index(++$component);
                ( $x, $y ) = ( $max_x, $max_y );
                $self->_pixels_processed->clear_x_coords;
            }
            else { --$y; }      # (1, >1)
        }
        else {
            if ( $y == 1 ) { --$x; $y = $max_y; }    # (>1, 1)
            else           { --$y; }                 # (>1, >1)
        }
    }

    # set pixel details
    $self->_pixels_processed->mark_pixel_as_processed( $x, $y );
    $image->pixel_coords( $x, $y );
    $image->pixel_rgb_component_index( $self->_rgb_component_index );

    return;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Cards::UniquefyImages - tweak image files to ensure each is unique

=head1 SYNOPSIS

    use Dn::Cards::UniquefyImages;
    ...

=head1 DESCRIPTION

Process a set of image files and ensures they are unique. The original files
are overwritten so it advisable to save copies of them before running this
script.

=head2 Overwriting files

Output files are written to the current directory. Existing files of the same
name are silently overwritten.

=head2 Duplicate file names

The input files are specified by file paths which can involve multiple
directory paths. It is possible, therefor, that input image files in different
directories could have the same file name.

All output image files, by contrast, are written to the current working
directory. Output image file names are derived from the names of their input
("parent") image files, ignoring the input images' directories. Since there can
be duplicate input image file names in a set of input images, there can be
duplicate output image file names in the corresponding set of output image
files. For that reason, the C<uniquefy_images> method will abort if it detects
multiple input filepaths with identical file names.

=head1 ATTRIBUTES

=head2 image_files

Paths of image files to process. Array reference of strings. Optional.
Default: empty array.

=head1 METHODS

=head2 add_image_files(@filepaths)

Additional files to be processed.

=head3 Params

=over

=item @filepaths

Paths of additional files to be processed. Duplicate file paths are ignored.
List of string paths. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 uniquefy_images()

Tweak files to ensure they are not identical but still appear identical to the
human eye. Tweaked files are written to the current directory.

=head3 Params

Nil.

=head3 Prints

User feedback and error messages.

=head3 Returns

Boolean scalar indicating success. Note that method dies on serious failures.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Dn::Cards::UniquefyImages::Image,
Dn::Cards::UniquefyImages::PixelsProcessed, Dn::Role, English, experimental,
Function::Parameters, Moo, MooX::HandlesVia, namespace::clean, Readonly,
strictures, Types::Standard, version.

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
