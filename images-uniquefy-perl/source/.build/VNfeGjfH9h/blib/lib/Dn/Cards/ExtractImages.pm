package Dn::Cards::ExtractImages;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(croak);
use Cwd qw(abs_path);
use Dn::Cards::ExtractImages::RegionBounds;
use English qw(-no_match_vars);
use Function::Parameters;
use Image::Magick;
use List::MoreUtils qw(uniq);
use MooX::HandlesVia;
use Readonly;
use Term::ProgressBar::Simple;
use Types::Standard;
use YAML::Tiny;

with qw(
    Dn::Role::HasImage
    Dn::Role::HasNumber
    Dn::Role::HasPath
);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                           }}}1

# debug
use Data::Dumper::Simple;

# attributes

# coords_file                                                          {{{1
has 'coords_file' => (
    is      => 'rw',
    isa     => Types::Standard::Str,
    default => 'coords.yaml',
    doc     => 'Coordinates file path',
);

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

# _bounds                                                              {{{1
has '_bounds_list' => (
    is  => 'lazy',
    isa => Types::Standard::ArrayRef [
        Types::Standard::InstanceOf ['Dn::Cards::ExtractImages::RegionBounds']
    ],
    handles_via => 'Array',
    handles     => { _bounds => 'elements' },
    doc         => 'Card image bounds',
);

method _build__bounds_list () {

    # read coordinate data
    my $file = $self->coords_file;
    my $yaml = YAML::Tiny->read($file)
        or croak "Unable to read file '$file'";
    my @image_pairs = @{ $yaml->[0] };

    # load geometry object list
    my @bounds_set;
    for my $pair (@image_pairs) {
        my $bounds = Dn::Cards::ExtractImages::RegionBounds->new(
            top_left_coords     => [ @{ $pair->{'top_left'} } ],
            bottom_right_coords => [ @{ $pair->{'bottom_right'} } ],
        );
        push @bounds_set, $bounds;
    }
    return [@bounds_set];
}    #                                                                 }}}1

# methods

# write_coords_file_template()                                         {{{1
#
# does:   write template coordinates file to location set by
#         attribute 'coords_file'
# params: nil
# prints: error messages on failure
# return: boolean, indicating success of write operation
# note:   will not overwrite existing file
method write_coords_file_template () {

    my $filename = $self->coords_file;

    # don't overwrite existing file
    if ( -e $filename ) {
        warn "'$filename' already exists\n";
        return;
    }

    # example coordinates
    my $data = [
        { top_left => [ 100, 100 ], bottom_right => [ 300, 300 ], },
        { top_left => [ 350, 100 ], bottom_right => [ 550, 300 ], },
    ];

    # user help
    # - will be ignored when file is imported because only the first
    #   "document", i.e., array element, is analysed by this script
    my $help = [
        {   help => [
                q{Above are example coordinates for two card images.},
                q{For each image specify the x and y coordinates of the},
                q{top-left (->tl<-) and bottom-right (->br<-) pixels.},
                q{},
                q{Pixels are numbered (positively) from the top-left},
                q{corner of the image. For example, the coordinates of},
                q{the top-left pixel are (1, 1) and the pixel with the},
                q{greatest x and y values is in the bottom-right corner},
                q{of the image.},
                q{},
                q{Provided you preserve the structure of this file this},
                q{help text will be ignored by dn-cards-images-extract.},
                q{This text can also be removed.}
            ],
        },
    ];

    # write template file
    my $yaml = YAML::Tiny->new( $data, $help )
        or croak 'Unable to instantiate YAML::Tiny object';
    $yaml->write($filename) or croak "Unable to write file '$filename'";

    return $TRUE;
}

# extract_images()                                                     {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
method extract_images () {

    # check args
    # - template writing takes precedence
    if ( $self->template ) {
        $self->_write_template;
        return;
    }
    if ( not $self->_checks_ok ) { return; }

    # cycle through image files
    my @files    = $self->_files;
    my $count    = scalar @files;
    my $progress = 0;
    if ( $count == 1 ) { say "Processing image file '$files[0]'"; }
    else {
        say "\nProcessing $count image files:";
        $progress = Term::ProgressBar::Simple->new($count);
    }
    for my $file (@files) {
        $self->_extract_card_images($file);
        $progress++;
    }
    undef $progress;    # ensure final messages displayed
    say 'Processing complete';

    return $TRUE;
}

# _checks_ok()                                                         {{{1
#
# does:   do pre-operation checks
# params: nil
# prints: feedback
# return: n/a, dies on failure
method _checks_ok () {

    # need at least one file specified                                 {{{2
    my @files = $self->_files;
    my $count = scalar @files;
    if ( not $count ) {
        warn "No files specified\n";
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
    my %dupes = %{ $self->file_name_duplicates(@fps) };
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

    # coordinate file must be valid                                    {{{2
    my $coords_file = $self->coords_file;
    if ( not $coords_file ) {
        warn "Coordinate file not specified\n";
        return;
    }
    if ( not $self->file_readable($coords_file) ) {
        warn q{Cannot read coordinate file '} . $coords_file . "'\n";
        return;
    }

    # must have coordinates                                            {{{2
    my @bounds_set = $self->_bounds;
    if ( not @bounds_set ) {
        warn 'No coordinates provided by '
            . "coordinates file '$coords_file'\n";
        return;
    }

    # ensure all files can be opened as images                         {{{2
    if ( not $self->image_files_valid(@files) ) { return; }

    return $TRUE;
}

# _extract_card_images($fp)                                            {{{1
#
# does:   extract card images from pdf page image
# params: $fp - path to pdf page image file
# prints: feedback if fails
# return: n/a, dies on failure
method _extract_card_images ($fp) {
    croak 'No filepath provided' if not $fp;
    croak 'Invalid image file' if not $self->file_readable($fp);

    my ( $base, $suffix ) = $self->file_name_parts($fp);

    # cycle through coordinates
    my @bounds_set   = $self->_bounds;
    my $bounds_count = scalar @bounds_set;
    my $count_width  = $self->int_pad_width($bounds_count) + 1;
    my $loop         = 1;
    for my $bounds (@bounds_set) {
        my $image = $self->image_create($fp);

        # crop image to card boundary
        my @args = ( $bounds->top_left, $bounds->bottom_right );
        $self->image_crop( $image, @args );

        # write cropped card image
        my $mask = $base . '_%0' . $count_width . 'd' . $suffix;
        my $output = sprintf "$mask", $loop;
        $self->image_write( $image, $output );

        undef $image;    # avoid memory cache overflow
        $loop++;
    }

    return;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1
__END__

=encoding utf8

=head1 NAME

Dn::Cards::ExtractImages - what I do

=head1 SYNOPSIS

    use Dn::Cards::ExtractImages;
    ...

=head1 DESCRIPTION

This module extracts rectangular regions from specified image files. It assumes
the rectangular region sides are truly vertical and horizontal. It also assumes
the regions occur in the same locations on each of the specified image files,
i.e., the top-left and bottom-right pixels of the regions have the same (x, y)
coordinates in each image.

Note: game cards are commonly available in digital form from BoardGameGeek and
other sites in multipage pdf files where the pdf pages each contain multiple
card images in the same locations, e.g., a 3-by-3 arrangement. If pdf pages are
extracted as individual image files, this script can process them to extract
the individual card images.

=head2 Region coordinates

The locations of the rectangular regions on the images are provided in a
coordinates file. This file is in yaml format. For each rectangular region the
x and y coordinates of its top-left and bottom-right pixel are provided. Note
that the coordinates origin point is at the top-left corner of the image, and x
and y coordinates number positively right and down from there, respectively.
The top-left pixel is (0, 0) and the bottom-right pixel has the largest x and y
coordinates.

Here is an example coordinates file:

 ---
 -
   top_left:
     - 975
     - 1262
   bottom_right:
     - 1723
     - 2314
 -
   top_left:
     - 1786
     - 1262
   bottom_right:
     - 2534
     - 2314
 -
   top_left:
     - 2598
     - 1262
   bottom_right:
     - 3346
     - 2314

C<top_left> and C<bottom_right> are the top-left and bottom-right pixel,
respectively, of each rectangular region. For each pixel the x and y
coordinates are listed, with the x coordinate followed by the y coordinate.

=head2 Output files

Output files are named like F<BASE_XX.SUFFIX> where 'BASE' and 'SUFFIX' are the
base name and suffix of the parent image file, and 'XX' is the individual
number of the extracted image. The output files are numbered from 1 in the
order in which they are specified in the coordinate file. The numbers are
left-padded with zeroes to ensure correct alphabetical sorting. The number of
padded zeroes depends on the total number of output files. For example, if
there are eight output files the third output file is numbered '3', but if
there are 18 output files the third output file is numbered '03', and so on.

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
files. For that reason, the C<extract_images> method will abort if it detects
multiple input filepaths with identical file names.

=head1 ATTRIBUTES

=head2 coords_file

Path to coordinates file. Used when writing or reading the coordinates file.
Scalar string. Optional. Default: 'coords.yaml'.

=head2 image_files

Image files to process. Array reference containing strings. Required. No
default value.

=head1 METHODS

=head2 add_image_files(@filepaths)

Add image files to be processed.

=head3 Params

=over

=item @filepaths

Paths to image files to be processed. List of strings. Required.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar boolean indicating success or failure of operation.

=head2 write_coords_file_template()

Write a template coordinates file. The filepath used is that set in the
C<coords_file> attribute. Note that if the output filepath already exists the
method will exit I<without> overwriting it. Duplicate filepaths are ignored.

=head3 Params

=over

=item @filepaths

Additional image files to be processed.

=back

=head3 Prints

Nil.

=head3 Returns

N.A.

=head2 extract_images()

From each image extract the rectangular regions specified in the coordinates
file and write them to image files in the current directory.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Cwd, Dn::Cards::ExtractImages::RegionBounds, Dn::Role, English,
Function::Parameters, Image::Magick, List::MoreUtils, Moo, MooX::HandlesVia,
namespace::clean, Readonly, strictures, Term::ProgressBar::Simple,
Types::Standard, YAML::Tiny, version.

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
