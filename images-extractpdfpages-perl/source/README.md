# NAME

Dn::Images::ExtractPdfPages - extract pdf pages as images

# SYNOPSIS

    use Dn::Images::ExtractPdfPages;
    ...

# DESCRIPTION

Takes a set of pdf files and extracts each page as a png image file. All output
files are created in the current directory, overwriting any files of the same
name.

The created image files have the same base name as their parent pdf files, with
an added page number. The page numbers are left-zero-padded so as to have a
uniform width, enabling correct sorting order. For example, the 13-page pdf
file `my-stuff.pdf` will give rise to 13 image files, including
`my-stuff_03.png` and `my-stuff_12.png`.

Since multiple input filepaths can have the same file name, and all output file
names are derived from the parent pdf file name, and all output files are
written to the current directory, and existing output files are silently
overwritten, having multiple input filepaths with identical file names is
problematic. For that reason, the `extract_images` method will abort if it
detects multiple input filepaths with identical file names.

## script

The command line utility `dn-images-extract-pdf-pages` is provided with this module. See the script's man page for further information.

# ATTRIBUTES

## density

Image resolution in dots per inch (dpi). This is an ImageMagick attribute.

Further details are available from [online
documentation](http://www.imagemagick.org/script/command-line-options.php#density).
On debian systems the libimage-magick-perl package provides [similar
information](file:///usr/share/doc/libimage-magick-perl/html/www/command-line-options.html#density).

Integer. Optional. Default: 300.

## quality

Image compression level. This is an ImageMagick attribute. Values range from 1
(lowest image quality and highest compression) to 100 (best quality but least
effective compression).

Further details are available from [online
documentation](http://www.imagemagick.org/script/command-line-options.php#quality).
On debian systems the libimage-magick-perl package provides [similar
information](file:///usr/share/doc/libimage-magick-perl/html/www/command-line-options.html#quality).

Integer. Optional. Default: 100.

## pdf\_files

PDF files to extract page images from.

Array reference. Optional. Default: empty array.

# METHODS

## add\_pdf\_files(@filepaths)

Add to the list of pdf files to extract images from. The module will allow the
same file to be added multiple times.

### Parameters

- @filepaths

    Paths of pdf files to process. List of filepaths. Required.

### Prints

Nil.

### Returns

Nil.

## extract\_pdf\_pages()

Generates a png image file in the current directory for each page in each input
filepath. The created image files have the same base name as their parent pdf
files, with an added page number. The page numbers are left-zero-padded so as
to have a uniform width, enabling correct sorting order. For example, the
13-page pdf file `my-stuff.pdf` will give rise to 13 image files, including
`my-stuff_03.png` and `my-stuff_12.png`.

### Params

Nil.

### Prints

User feedback and error messages.

### Returns

Scalar boolean indicating success or failure.

# CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

# DEPENDENCIES

## Perl modules

autodie, Carp, Dn::Role::HasImage, Dn::Role::HasNumber, Dn::Role::HasPath,
English, Function::Parameters, Moo, MooX::HandlesVia, namespace::clean,
PDF::API2, Readonly, strictures, Term::ProgressBar::Simple, Try::Tiny,
Types::Path::Tiny, Types::Standard, version.

## INCOMPATIBILITIES

Modules this one cannot be used with, and why.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
