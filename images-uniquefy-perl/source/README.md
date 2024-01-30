# NAME

Dn::Images::Uniquefy - tweak image files to ensure each is unique

# SYNOPSIS

    use Dn::Images::Uniquefy;
    ...

# DESCRIPTION

Process a set of image files and ensures they are unique. The original files
are overwritten so it advisable to save copies of them before running this
script.

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
files. For that reason, the `uniquefy_images` method will abort if it detects
multiple input filepaths with identical file names.

## Script

The command line utility `dn-images-uniquefy` is included with this module.
See the script's man page for further information.

# ATTRIBUTES

## image\_files

Paths of image files to process. Array reference of strings. Optional.
Default: empty array.

# METHODS

## add\_image\_files(@filepaths)

Additional files to be processed.

### Params

- @filepaths

    Paths of additional files to be processed. Duplicate file paths are ignored.
    List of string paths. Required.

### Prints

Nil.

### Returns

Nil.

## uniquefy\_images()

Tweak files to ensure they are not identical but still appear identical to the
human eye. Tweaked files are written to the current directory.

### Params

Nil.

### Prints

User feedback and error messages.

### Returns

Boolean scalar indicating success. Note that method dies on serious failures.

# CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

# DEPENDENCIES

## Perl modules

autodie, Carp, Dn::Images::Uniquefy::ModifyImage,
Dn::Images::Uniquefy::PixelsProcessed, Dn::Role::HasImage, Dn::Role::HasPath,
English, experimental, Function::Parameters, Moo, MooX::HandlesVia,
namespace::clean, Readonly, strictures, Term::ProgressBar::Simple,
Types::Path::Tiny, Types::Standard, version.

## INCOMPATIBILITIES

There are no known incompatibilities with other modules.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
