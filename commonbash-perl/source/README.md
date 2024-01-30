# NAME

Dn::CommonBash - helper module for libdncommon-bash

# SYNOPSIS

    use Dn::CommonBash;

# DESCRIPTION

This module is a helper to the library of shell functions called libdncommon-bash. The submodules and associated methods assist in building and using libdncommon-bash.

Uses submodule:

- Dn::CommonBash::Function

    Encapsulates a shell function provided by libdncommon-bash.

# SUBROUTINES/METHODS

## display\_function\_details($name, \[$store\])

### Purpose

Display information about the named function. Output is formatted for screen (console) display.

### Parameters

- $name

    Name of function to display.

- $store

    Location of function data store. This store is written by Dn::CommonBash->write\_store.

    Required if function data has not yet been loaded from the data store. If function data has been loaded this parameter is optional, and ignored if present.

### Prints

Nil.

### Returns

List of display lines.

## select\_function($filter, \[$store\])

### Purpose

Choose a function that matches filter.

Note that an exact match with a function name takes precedence over partial matches with other function names. For example, given the following functions:

> - Do\_Thing
> - Do\_Thing\_Cleverly
> - Do\_Thing\_Quickly

the command `$cp->select_function('Do_Thing')` will immediately display details for function 'Do\_Thing'. The command `$cp->select_function('Do_Thing_')` (note trailing underscore) will display a list of 'Do\_Thing\_Cleverly' and 'Do\_Thing\_Quickly' for the user to select from.

### Parameters

- $filter

    Function name, or part thereof, to filter function names.

    Required.

- $store

    Location of function data store. This store is written by Dn::CommonBash->write\_store.

    Required if function data has not yet been loaded from the data store. If function data has been loaded this parameter is optional, and ignored if present.

### Prints

Nil.

### Returns

Scalar string.

## write\_dictionary($dict, \[$master\])

### Purpose

Writes sorted list of function names to dictionary file.

### Parameters

- $dict

    Dictionary filepath.

    Required.

- master

    Location of root file in the dncommon-bash library.

    Required if function data has not previously been extracted from dncommon-bash. If function data has been loaded this parameter is not required, and if present is ignored.

### Prints

Nil.

### Returns

Nil.

## write\_loader($loader)

### Purpose

Generate vim loader file. Designed to be called by Dn::CommonBash::Function->write\_loader.

### Parameters

- $loader

    Loader filepath.

    Required.

- master

    Location of root file in the dncommon-bash library.

    Required if function data has not previously been extracted from dncommon-bash. If function data has been loaded this parameter is not required, and if present is ignored.

### Prints

Nil.

### Returns

Nil.

## write\_store($store)

### Purpose

Generate persistent data store.

### Parameters

- $store

    Storage file path.

    Required.

- master

    Location of root file in the dncommon-bash library.

    Required if function data has not previously been extracted from dncommon-bash. If function data has been loaded this parameter is not required, and if present is ignored.

### Prints

Feedback.

### Returns

Nil.

# DEPENDENCIES

## Moose

## namespace::autoclean

## MooseX::MakeImmutable

## Moose::Util::TypeConstraints

## Function::Parameters

## Fatal

## English

## Carp

## Readonly

Use modern perl features.

## Test::NeedsDisplay

Required for build routines that lack a display.

## Cwd

Provides 'abs\_path' for determining absolute paths.

## List::MoreUtils

Provides 'any' for determining list membership.

## Dn::Common

Provides utility methods.

## Dn::CommonBash::Function

Provides specific support for building and using the dncommon-bash library.

# BUGS AND LIMITATIONS

Please report all bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer <davidnebauer@hotkey.net.au>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
