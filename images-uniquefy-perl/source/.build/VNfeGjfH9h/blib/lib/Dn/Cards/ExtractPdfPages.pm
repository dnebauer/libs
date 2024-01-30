package Dn::Cards::ExtractPdfPages;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(croak);
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use PDF::API2;
use Readonly;
use Try::Tiny;
use Types::Standard;
use experimental 'switch';

with qw(
    Dn::Role::HasImage
    Dn::Role::HasNumber
    Dn::Role::HasPath
);

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                           }}}1

# attributes

# density                                                              {{{1
has 'density' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 300,
    doc     => 'Image resolution (pixels per inch)',
);

# quality                                                              {{{1
has 'quality' => (
    is      => 'rw',
    isa     => Types::Standard::Int,
    default => 100,
    doc     => 'Compression level (1=highest to 100=least)',
);

# pdf_files, add_pdf_files, _files                                     {{{1
has 'pdf_files' => (
    is          => 'rw',
    isa         => Types::Standard::ArrayRef [Types::Standard::Str],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        add_pdf_files => 'push',
        _files        => 'elements',
    },
    doc => 'Image files',
);    #                                                                }}}1

# methods

# extract_pdf_pages()                                                  {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
method extract_pdf_pages () {

    # check files
    if ( not $self->_file_checks_ok ) { return; }

    # cycle through files
    my @files    = $self->_files;
    my $count    = scalar @files;
    my $progress = 0;
    if ( $count == 1 ) { say "Extracting page images from '$files[0]'"; }
    else {
        say "Extracting page images from $count pdf files:";
        $progress = Term::ProgressBar::Simple->new($count);
    }

    # process image and extract pages as images
    my $attributes = { density => $self->density, quality => $self->quality };
    for my $file (@files) {
        my $image = $self->image_create( $file, $attributes );
        my $output = $self->_output_filemask($file);
        $self->_extract_images( $image, $output );
        undef $image;    # avoid memory cache overflow

        $progress++;
    }

    undef $progress;     # ensure final messages displayed

    say 'Extraction complete';

    return $TRUE;
}

# _file_checks_ok()                                                    {{{1
#
# does:   check that files have been specified and that there will be
#         no output filename collisions
# params: nil
# prints: error message if check fails
# return: scalar boolean
method _file_checks_ok () {

    my @fps = $self->_files;

    # check that files have been specified
    if ( not @fps ) {
        warn "No valid files specified\n";
        return;
    }

    # check for output filename collisions
    # - input pdf files are specified by filepaths
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

    # test successful
    return $TRUE;
}

# _output_filemask($fp)                                                {{{1
#
# does:   derive output file name mask
#
# params: $fp - (relative) path of file
# prints: error message if invalid inputs
# return: file name mask [Str], exits on failure
method _output_filemask ($fp) {

    # check arg
    croak 'No filepath provided'   if not $fp;
    croak "Invalid filepath '$fp'" if not $self->file_readable($fp);

    # need basename
    my $base = $self->file_base($fp);

    # need maximum width of page numbers to enable left zero-padding
    # - e.g., 13 pages need 2 digits while 9 pages need 1 digit
    try {
        my $pdf   = PDF::API2->open($fp);
        my $pages = $pdf->pages;
        if ( not $pages ) { die; }
        my $pad_width = $self->int_pad_width($pages);
        return $base . '_%0' . $pad_width . 'd.png';
    }
    catch {
        croak "\nUnable to process '$fp' as a pdf file";
    }
}

# _extract_images($image, $output)                                     {{{1
#
# does:   extract page images from pdf image file
#
# params: $image - Image::Magick object of pdf file
# prints: error message if invalid inputs
# return: n/a, exits on failure
method _extract_images ($image, $output) {

    # check args
    croak 'No output filemask provided' if not $output;
    croak 'No image provided'           if not $image;
    croak 'Not an image object' if not $self->image_object($image);

    # write page images
    $self->image_write($output);

    return;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Cards::ExtractPdfPages - extract pdf pagesas images

=head1 SYNOPSIS

    use Dn::Cards::ExtractPdfPages;
    ...

=head1 DESCRIPTION

Takes a set of pdf files and extracts each page as a png image file. All output
files are created in the current directory, overwriting any files of the same
name.

The created image files have the same base name as their parent pdf files, with
an added page number. The page numbers are left-zero-padded so as to have a
uniform width, enabling correct sorting order. For example, the 13-page pdf
file F<my-stuff.pdf> will give rise to 13 image files, including
F<my-stuff_03.png> and F<my-stuff_12.png>.

Since multiple input filepaths can have the same file name, and all output file
names are derived from the parent pdf file name, and all output files are
written to the current directory, and existing output files are silently
overwritten, having multiple input filepaths with identical file names is
problematic. For that reason, the C<extract_images> method will abort if it
detects multiple input filepaths with identical file names.

=head1 ATTRIBUTES

=head2 density

Image resolution in dots per inch (dpi). This is an ImageMagick attribute.

Further details are available from L<online
documentation|http://www.imagemagick.org/script/command-line-options.php#density>.
On debian systems the libimage-magick-perl package provides L<similar
information|file:///usr/share/doc/libimage-magick-perl/html/www/command-line-options.html#density>.

Integer. Optional. Default: 300.

=head2 quality

Image compression level. This is an ImageMagick attribute. Values range from 1
(lowest image quality and highest compression) to 100 (best quality but least
effective compression).

Further details are available from L<online
documentation|http://www.imagemagick.org/script/command-line-options.php#quality>.
On debian systems the libimage-magick-perl package provides L<similar
information|file:///usr/share/doc/libimage-magick-perl/html/www/command-line-options.html#quality>.

Integer. Optional. Default: 100.

=head2 pdf_files

PDF files to extract page images from.

Array reference. Optional. Default: empty array.

=head1 METHODS

=head2 add_pdf_files(@filepaths)

Add to the list of pdf files to extract images from. The module will allow the
same file to be added multiple times.

=head3 Parameters

=over

=item $param

Parameter details. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 extract_pdf_pages()

Generates a png image file in the current directory for each page in each input
filepath. The created image files have the same base name as their parent pdf
files, with an added page number. The page numbers are left-zero-padded so as
to have a uniform width, enabling correct sorting order. For example, the
13-page pdf file F<my-stuff.pdf> will give rise to 13 image files, including
F<my-stuff_03.png> and F<my-stuff_12.png>.

=head3 Prints

User feedback and error messages.

=head3 Returns

Scalar boolean indicating success or failure.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Dn::Role, English, experimental, Function::Parameters, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, PDF::API2, Readonly,
strictures, Term::ProgressBar::Simple, Try::Tiny, Types::Standard, version.

=head2 INCOMPATIBILITIES

Modules this one cannot be used with, and why.

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
