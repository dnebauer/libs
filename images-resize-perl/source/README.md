# NAME

Dn::Images::Resize - resize images, optionally adding borders

# SYNOPSIS

    use Dn::Images::Resize;
    ...

# DESCRIPTION

This module resizes image files, optionally adding borders, and saves them to
the current directory, overwriting any existing files with the same name.

Width and height, and additional side and top/bottom borders, can be
specified explicitly using the appropriate module attributes.

## Resizing and aspect ratio

By default each image is resized to the maximum possible height and width to
fit into the resized dimensions, while preserving the aspect ratio. If the
initial image has a markedly different aspect ratio to the resized dimensions,
the resizing process can result in significant additional space on the sides or
top/bottom of the resulting images. This new space is filled with the specified
fill color (`fill_color` attribute).

If aspect ratio is not preserved (by setting the `preserve_aspect_ratio`
attribute to false) the image is resized to fit the specified dimensions. That
is, the images are stretched vertically and horizontally to fit the new
dimensions. If the initial image has a markedly different aspect ratio to the
resized dimensions, the resizing process can result in significant distortion
of the image.

## Border

Once the image is resized borders can be added to the sides and top/bottom of
the image. These may be bleed borders added so that printing extends to the
edge of cut pages. Borders are added by setting the `border_horizontal` and
`border_vertical` to non-zero (positive) values. The border color is set using
the `fill_color` attribute; the default is to make them transparent.

## Scripts

Two command line utilities are provided with this module: `dn-images-resize` and `dn-images-printerstudio-resize`. See the
following section for more details on Printer's Studio support. See the script
man pages for more information on their use.

## Printer's Studio support

The script `dn-images-printerstudio-resize` provided with this module
provides support for converting images into suitable dimensions for use as
Printer's Studio game cards. See the script's man page for further information.

## Overwriting files

The original files are overwritten by the transformed images so it advisable to
save copies of them before running this script.

## Duplicate file names

The input files are specified by file paths which can involve multiple
directory paths. It is possible, therefor, that input image files in different
directories could have the same file name.

All output image files, by contrast, are written to the current working
directory. Output image file names are are the same as their input ("parent")
image files, ignoring the input images' directories. Since there can be
duplicate input image file names in a set of input images, there can be
duplicate output image file names in the corresponding set of output image
files. For that reason, the `resize_images` method will abort if it detects
multiple input filepaths with identical file names.

# ATTRIBUTES

## width

Image width of resized image. Required. No default value.

## height

Image height of resized image. Required. No default value.

## preserve\_aspect\_ratio

Whether to preserve aspect ratio when resizing. Optional. Default: true.

## fill\_color

Color used for additional space added to the image when resizing (when aspect
ratio is preserved). This color is also used for borders. Optional. Default:
'none' (transparent).

Available color schemes and colors are described in the [ImageMagick color
page](https://people.debian.org/~naoliv/misc/imagemagick/link/www/color.html).
On debian systems the libimage-magick-perl package provides a similar page at
`/usr/share/doc/libimage-magick-perl/html/www/color.html`.

Note that setting fill color will have no effect on the final image if aspect
ratio is ignored (because the image is stretched to cover the entirety of the
resized dimensions) and borders are set to zero width.

## border\_horizontal

Size in pixels of border for left and right sides of images. Optional.
Default: 0.

Note that if `border_horizontal` remains set to zero no border will be added
to the left and right sides of resized images.

## border\_vertical

Size in pixels of border for top and bottom sides of images. Optional.
Default: 0.

Note that if `border_vertical` remains set to zero no border will be added to
the top and bottom sides of resized images.

## image\_files

Images to be resized. Specifying files other than image files will result in
the Image::Magick module dying when it attempts to load the image, which also
causes this module to die.

# METHODS

## add\_image\_files(@filepaths)

Specify additional image files to be resized.

### Parameters

- $param

    Paths of additional image files to be resized. Duplicate filepaths will be
    ignored. Scalar string. Required.

### Prints

Nil.

### Returns

Nil.

## resize\_images()

Resize specified images and, optionally, add borders to them. Resized image
files are written to the current working directory.

# CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

# DEPENDENCIES

## Perl modules

autodie, Carp, Cwd, Dn::Images::Resize::Dimensions, Dn::Role::HasImage,
Dn::Role::HasPath, English, Function::Parameters, Moo, MooX::HandlesVia,
namespace::clean, Readonly, strictures, Term::ProgressBar::Simple,
Types::Standard, version.

## INCOMPATIBILITIES

There are no known incompatibilities with other modules.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
