# NAME

Dn::Images::ExtractRegions - extract rectangular regions as images

# SYNOPSIS

    use Dn::Images::ExtractRegions;
    ...

# DESCRIPTION

This module extracts rectangular regions from specified image files. It assumes
the rectangular region sides are truly vertical and horizontal. It also assumes
the regions occur in the same locations on each of the specified image files,
i.e., the top-left and bottom-right pixels of the regions have the same (x, y)
coordinates in each image.

## Region coordinates

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

`top_left` and `bottom_right` are the top-left and bottom-right pixel,
respectively, of each rectangular region. For each pixel the x and y
coordinates are listed, with the x coordinate followed by the y coordinate.

## Output files

Output files are named like `BASE_XX.SUFFIX` where 'BASE' and 'SUFFIX' are the
base name and suffix of the parent image file, and 'XX' is the individual
number of the extracted image. The output files are numbered from 1 in the
order in which they are specified in the coordinate file. The numbers are
left-padded with zeroes to ensure correct alphabetical sorting. The number of
padded zeroes depends on the total number of output files. For example, if
there are eight output files the third output file is numbered '3', but if
there are 18 output files the third output file is numbered '03', and so on.

## Overwriting files

Output files are written to the current directory. Existing files of the same
name are silently overwritten.

## Duplicate file names

The input files are specified by file paths which can involve multiple
directory paths. It is possible, therefor, that input image files in different
directories could have the same file name.

All output image files, by contrast, are written to the current working
directory. Output image file names are derived from the names of their input
("parent") image files, ignoring the input images' directories. Since there can
be duplicate input image file names in a set of input images, there can be
duplicate output image file names in the corresponding set of output image
files. For that reason, the `extract_images` method will abort if it detects
multiple input filepaths with identical file names.

head2 Aids

The command line utility `dn-images-extract-regions` is provided with this
module. See the script's man page for further information.

A LibreOffice/OpenOffice spreadsheet called `coords-nine-regions.ods`
is distributed with this module. On debian systems it is usually installed at
`/usr/share/libdn-images-extractregions-perl/`. The spreadsheet is
meant to help with images having nine rectangular regions in a 3x3 layout.
Users enter necessary x and y coordinates and press a button to write a <`coords.yaml` file in the current directory. The spreadsheet assumes the
rectangular regions are exactly the same in size and are aligned in a perfect
grid.

# ATTRIBUTES

## coords\_file

Path to coordinates file. Used when writing or reading the coordinates file.
Scalar string. Optional. Default: 'coords.yaml'.

## image\_files

Image files to process. Array reference containing strings. Required. No
default value.

# METHODS

## add\_image\_files(@filepaths)

Add image files to be processed.

### Params

- @filepaths

    Paths to image files to be processed. List of strings. Required.

### Prints

Error messages.

### Returns

Scalar boolean indicating success or failure of operation.

## write\_coords\_file\_template()

Write a template coordinates file. The filepath used is that set in the
`coords_file` attribute. Note that if the output filepath already exists the
method will exit _without_ overwriting it. Duplicate filepaths are ignored.

### Params

- @filepaths

    Additional image files to be processed.

### Prints

Nil.

### Returns

Nil.

## extract\_images()

From each image extract the rectangular regions specified in the coordinates
file and write them to image files in the current directory.

# CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

# DEPENDENCIES

## Perl modules

autodie,Carp, Const::Fast, Dn::Images::ExtractRegions::RegionCoords, English,
Moo, MooX::HandlesVia, namespace::clean, Role::Utils::Dn, strictures,
Term::ProgressBar::Simple, Types::Path::Tiny, Types::Standard, version,
YAML::Tiny.

## INCOMPATIBILITIES

There are no known incompatibilities with other modules.

# BUGS AND LIMITATIONS

When processing large pdf files it is possible to exceed the cache resources
available to the underlying ImageMagick application, resulting in a fatal
error. See ["Exhausting cache resources during image
processing" in Role::Utils::Dn](https://metacpan.org/pod/Role%3A%3AUtils%3A%3ADn#Exhausting-cache-resources-during-image-processing) for further details.

Please report any bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
