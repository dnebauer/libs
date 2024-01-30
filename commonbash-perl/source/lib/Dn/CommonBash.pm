package Dn::CommonBash;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.014_002;
use namespace::clean;
use version; our $VERSION = qv('0.1');
use Test::NeedsDisplay;

use autodie qw(open close);
use Carp qw(confess);
use Dn::CommonBash::Function;
use English qw(-no_match_vars);
use Function::Parameters;
use MooX::HandlesVia;
use Readonly;
use Types::Standard qw(HashRef InstanceOf);
use Cwd qw(abs_path);
use Dn::Common;
use Dn::CommonBash::Function;
use List::MoreUtils qw(any);
use experimental 'switch';

my $cp = Dn::Common->new();
Readonly my $TRUE          => 1;
Readonly my $FALSE         => 0;
Readonly my $_vim_variable => q{dnLibCommonBash};    #                 }}}1

# Attributes

# _function_data                                                       {{{1
has '_function_data' => (
    is      => 'rw',
    isa     => Types::Standard::HashRef[Types::Standard::InstanceOf['Dn::CommonBash::Function']],
    default => sub { {} },
    handles_via  => 'Hash',
    handles => {
        _set_functions   => 'set',         # ($k, $v, $k, ...)
        _function        => 'get',         # ($funcname) -> $funcref
        _has_function    => 'get',         # ($funcname) -> $funcref
        _has_functions   => 'count',       # () -> bool
        _function_names  => 'keys',        # () -> @funcnames
        _function_count  => 'count',       # () -> $count
        _get_functions   => 'elements',    # () -> ($k, $v, $k, ...)
        _clear_functions => 'clear',       # ()
    },
    documentation => 'Function (objects)',
);    #                                                                }}}1

# Methods

# _handle_pkglib_dir($filepath, [$master])                             {{{1
#
# does:   modify filepath if it contains autotools variables @pkglib_dir@ or
#         @pkglibexec_dir@
# params: $filepath - library file path [required]
#         $master   - root file of libdncommon-bash [filepath]
#                     [required if function data not loaded]
# prints: nil
# return: scalar string filepath
# detail: a library filepath is determined to be from an unbuilt autotools
#         library file if it contains the variable placeholders
#         '@pkglib_dir@' or '@pkglibexec_dir@' -- if it does the filepath is
#         processed specially: the placeholder is replaced by the path from the
#         library master file and the extension '.in' is added
method _handle_pkglib_dir ($filepath, $master) {
    if ( $filepath =~ /\@pkglib_dir\@/xsm ) {
        my $master_path = $cp->get_path($master);
        $filepath =~ s/\@pkglib_dir\@/$master_path/xsm;
        $filepath .= q{.in};
    }
    elsif ( $filepath =~ /\@pkglibexec_dir\@/xsm ) {
        my $master_path = $cp->get_path($master);
        $filepath =~ s/\@pkglibexec_dir\@/$master_path/xsm;
        $filepath .= q{.in};
    }
    return $filepath;
}

# _library_files($master)                                              {{{1
#
# does:   get list of files in libdncommon-bash
# params: $master - root file in libdncommon-bash [filepath, required]
# prints: nil (except error feedback)
# return: list
# note:   takes (deletes) files one at a time from @found_files, add
#         to master list, then parse file for more sourced files
#         (assumes format like: 'source /path/to/libfile  # comment');
#         if sourced files found, add to @found_files to process in turn
method _library_files ($master) {
    if ( not $master ) { confess q{No master library file provided}; }
    if ( not -r $master ) {
        confess qq[Invalid master library file '$master' provided];
    }
    my @found_files = $master;
    my @libfiles;

    while (@found_files) {

        # delete file to be processed from front of @found_files array
        my $libfile = shift @found_files;
        if (@libfiles) {          # any fails if @libfiles empty
            if ( not( List::MoreUtils::any {/^$libfile\z/xsm} @libfiles ) ) {
                push @libfiles, $libfile;
            }
        }
        else {
            push @libfiles, $libfile;
        }
        open my $fh, '<', $libfile;
        my @lines = <$fh>;
        close $fh;
        foreach my $line (@lines) {
            chomp $line;

            # look for sourced files
            my $filename = $line =~ s/^\s*[.]\s+(\S+).*$/$1/rxsm;
            if ( $filename ne $line ) {

                # add newly discovered filename to end of @found_files array
                $filename = $self->_handle_pkglib_dir( $filename, $master );
                push @found_files, $filename;
            }
        }
    }
    my $msg = q{Found } . scalar @libfiles . q{ library files};
    say $msg;
    return @libfiles;
}

# _load_from_library($master)                                          {{{1
#
# does:   load function data from library
# params: $master - root file in libdncommon-bash (filepath, required]
# prints: feedback
# return: nil
method _load_from_library ($master) {
    if ( not $master ) { confess q{Library master file not set}; }
    my %fns;
    my @lines;
    my @libfiles = $self->_library_files($master);
    if ( not @libfiles ) { confess q{No library files discovered}; }

    # read in content of all library files
    for my $libfile (@libfiles) {
        open my $fh, '<', $libfile;
        push @lines, <$fh>;
        close $fh;
    }

    # process library content
    for my $line (@lines) {
        chomp $line;

        # next line fails mysteriously if flags 'xsm' used
        # as per 'Perl Best Practice'
        next if $line !~ /^# fn_tag/;    # not a function definition line
        my @elements = split /\s+/xsm, $line;    # get elements of line
        my $fn = $elements[2];
        if ( not $fns{$fn} ) {                   # ensure function defined
            $fns{$fn} = Dn::CommonBash::Function->new();
        }
        my $func        = $fns{$fn};
        my $key_element = $elements[3];
        for ($key_element) {

            # option attribute definition line
            when (/^option\z/xsm) {
                my $flag = $elements[4];
                my $attr = $elements[5];
                my $val  = join q{ }, @elements[ 6 .. $#elements ];
                if ( not $func->option($flag) ) {
                    $func->add_option(
                        Dn::CommonBash::Function->new()->new_option($flag) );
                }
                my $option = $func->option($flag);
                for ($attr) {
                    when (/^purpose\z/xsmi)  { $option->purpose($val); }
                    when (/^required\z/xsmi) { $option->required($val); }
                    when (/^multiple\z/xsmi) { $option->multiple($val); }
                    when (/^type\z/xsmi)     { $option->type($val); }
                    when (/^value\z/xsmi)    { $option->add_value($val); }
                    when (/^default\z/xsmi)  { $option->default($val); }
                    when (/^note\z/xsmi)     { $option->add_note($val); }
                }
            }

            # param attribute definition line
            when (/^param\z/xsm) {
                my $name = $elements[4];
                my $attr = $elements[5];
                my $val  = join q{ }, @elements[ 6 .. $#elements ];
                if ( not $func->param($name) ) {
                    $func->add_param(
                        Dn::CommonBash::Function->new()->new_param($name) );
                }
                my $param = $func->param($name);
                for ($attr) {
                    when (/^purpose\z/xsmi)   { $param->purpose($val); }
                    when (/^required\z/xsmi)  { $param->required($val); }
                    when (/^multipart\z/xsmi) { $param->multipart($val); }
                    when (/^type\z/xsmi)      { $param->type($val); }
                    when (/^value\z/xsmi)     { $param->add_value($val); }
                    when (/^default\z/xsmi)   { $param->default($val); }
                    when (/^note\z/xsmi)      { $param->add_note($val); }
                }
            }

            # function attribute definition line
            default {
                my $attr = $elements[3];
                my $val = join q{ }, @elements[ 4 .. $#elements ];
                for ($attr) {
                    when (/^purpose\z/xsmi) { $func->purpose($val); }
                    when (/^prints\z/xsmi)  { $func->prints($val); }
                    when (/^returns\z/xsmi) { $func->returns($val); }
                    when (/^note\z/xsmi)    { $func->add_note($val); }
                    when (/^usage\z/xsmi)   { $func->add_usage($val); }
                }
            }
        }
    }

    # load function data
    $self->_clear_functions;
    $self->_set_functions(%fns);
}

# _load_from_store($store)                                             {{{1
#
# does:   load function data from persistent data store
# params: $store - storage filepath [required]
# prints: feedback
# return: nil
# note:   data store is assumed to have been created
#         with the 'write_store' method
method _load_from_store ($store) {

    # check storage file
    if ( not $store ) { confess q{No storage filepath provided}; }
    if ( not -r $store ) {
        confess qq[Invalid storage filepath '$store' provided];
    }

    # retrieve function data and load it
    my $funcs_ref = $cp->retrieve_store($store);
    my %functions = %{$funcs_ref};
    $self->_clear_functions;
    $self->_set_functions(%functions);

    # provide feedback
    my $msg = q{Retrieved data on } . $self->_function_count . q{ functions};
    say $msg;
}

# display_function_details($name, [$store])                            {{{1
#
# does:   display information about the named function
#         formatted for console display
# params: $name  - name of function to display [required]
#         $store - function data store [filepath, optional]
#                  required if functions have not been loaded
# prints: nil
# return: list of display lines
method display_function_details ($name, $store) {

    # must have function name
    if ( not $name ) {
        confess q{No name provided};
    }

    # ensure function data is loaded
    if ( not $self->_has_functions ) {
        if ( not( $self->_load_from_store($store) ) ) {
            confess qq{Unable to load from store '$store'};
        }
    }

    # must have details on that function
    if ( not( $self->_has_function($name) ) ) {
        confess qq{Cannot find details of function '$name'};
    }

    # display details
    if ( my $function = $self->_function($name) ) {
        if ( my @display = $function->display_function_screen($name) ) {
            return @display;
        }
        else {
            confess qq{Unable to get display details for function '$name'};
        }
    }
    else {
        confess qq{Unable to retrieve details for function '$name'};
    }
}

# select_function($filter, [$store])                                   {{{1
#
# does:   choose a function
# params: $filter - part of function name [required]
#         $store  - function data store [filepath, optional]
#                   required if functions have not been loaded
# prints: nil
# return: scalar string
method select_function ($filter, $store) {
    if ( not $self->_has_functions ) {
        $self->_load_from_store($store);
    }
    my @funcs = $self->_function_names();

    # first try for exact match (assume returns either 1 or 0)
    my @exact_match;
    if ($filter) {
        @exact_match = grep {/^$filter\z/xsmi} @funcs;
    }
    if ( scalar @exact_match == 1 ) {
        return $exact_match[0];
    }

    # if no exact match, look for partial matches
    if ($filter) {
        @funcs = grep {/$filter/xsmi} @funcs;
    }

    for ( scalar @funcs ) {
        when ( $_ == 0 ) {
            say q{No matching function found};
            return;
        }
        when ( $_ == 1 ) {
            say q{Only one matching function found};
            return "@funcs";
        }
        default {    # > 1
            return $cp->input_choose( q{Select function:}, @funcs );
        }
    }
}

# write_dictionary($dict, [$master])                                   {{{1
#
# does:   write sorted list of function names to dictionary file
# params: $dict - dictionary filepath [required]
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: nil
# return: nil
method write_dictionary ($dict, $master) {

    # need output filename and data to write to it
    if ( not $dict ) {
        confess q{No dictionary filepath provided};
    }
    if ( not $self->_has_functions ) {
        if ( not( $self->_load_from_library($master) ) ) {
            confess qq{Unable to extract function data from '$master'};
        }
    }

    # ensure dictionary path exists
    my $dict_dir = $cp->get_path($dict);
    if ($dict_dir) {
        if ( not( $cp->make_dir($dict_dir) ) ) {
            confess qq{Unable to make directory '$dict_dir'};
        }
    }

    # write dictionary file
    open my $fh, '>', $dict;
    my @function_names = sort $self->_function_names;
    foreach my $function_name (@function_names) {
        print {$fh} "$function_name\n" or confess qq{Couldn't write '$dict'};
    }
    close $fh;

    # provide feedback
    say q{wrote }
        . $self->_function_count
        . q{ function names to dictionary file};
    return;
}

# write_loader($loader, [$master])                                     {{{1
#
# does:   generate vim loader file
# params: $loader - loader filepath [required]
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: nil
# return: nil
# note:   designed to be called by Dn::CommonBash::Function->write_loader
method write_loader ($loader, $master) {

    # need output filename and data to write to it
    if ( not $loader ) {
        confess q{No loader filepath provided};
    }
    if ( not $self->_has_functions ) {
        if ( not( $self->_load_from_library($master) ) ) {
            confess qq{Unable to extract function data from '$master'};
        }
    }

    # ensure loader path exists
    my $loader_dir = $cp->get_path($loader);
    if ($loader_dir) {
        if ( not( $cp->make_dir($loader_dir) ) ) {
            confess qq{Unable to make directory '$loader_dir'};
        }
    }

    # generate output
    my @data;
    push @data, q{" Vim loader file};
    push @data, q{ };
    push @data, q{" Loads function data from libdncommon-bash};
    push @data, q{" into an associative array.};
    push @data, q{};
    push @data,
          q{" [Generated by }
        . $cp->scriptname() . q{ on }
        . $cp->today() . q{]};
    push @data, q{};
    push @data, q{" -------------------------------------------};
    push @data, q{};
    push @data, q[let ] . $_vim_variable . q[ = {}];
    push @data, q{};

    # main output here
    foreach my $func_name ( $self->_function_names ) {
        my $function = $self->_function($func_name);
        push @data,
              q{let }
            . $_vim_variable . q{['}
            . $func_name
            . q{'] = }
            . $function->write_function_loader();
    }

    # write output
    open my $fh, '>', $loader;
    foreach my $line (@data) {
        print {$fh} qq{$line\n}
            or confess qq{Unable to write file '$loader'};
    }
    close $fh;

    # provide feedback
    my $msg
        = q{wrote data on }
        . $self->_function_count()
        . q{ functions to loader file};
    say $msg;
}

# write_store($store, [$master])                                       {{{1
#
# does:   generate persistent data store
# params: $store  - storage file path [required]
#                   will create path if does not exist
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: feedback
# return: nil
method write_store ($store, $master) {
        # need output filename and data to write to it
    if ( not $store ) {
        confess q{No data store filepath provided};
    }
    if ( not $self->_has_functions ) {
        if ( not( $self->_load_from_library($master) ) ) {
            confess qq{Unable to extract function data from '$master'};
        }
    }

    # get functions to store
    my $functions = { $self->_get_functions };

    # ensure storage path exists
    my $storage_dir = $cp->get_path($store);
    if ($storage_dir) {
        if ( not( $cp->make_dir($storage_dir) ) ) {
            confess qq{Unable to make directory '$storage_dir'};
        }
    }

    # save functions to store
    $cp->save_store( $functions, $store );

    # provide feedback
    my $msg
        = q{wrote data on }
        . $self->_function_count()
        . q{ functions to storage file};
    say $msg;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=encoding utf-8

=head1 NAME

Dn::CommonBash - helper module for libdncommon-bash

=head1 SYNOPSIS

  use Dn::CommonBash;

=head1 DESCRIPTION

This module is a helper to the library of shell functions called
libdncommon-bash. The submodules and associated methods assist in building and
using libdncommon-bash.

Uses submodule:

=over

=item Dn::CommonBash::Function

Encapsulates a shell function provided by libdncommon-bash.

=back

=head1 SUBROUTINES/METHODS

=head2 display_function_details($name, [$store])

=head3 Purpose

Display information about the named function. Output is formatted for screen
(console) display.

=head3 Parameters

=over

=item $name

Name of function to display.

=item $store

Location of function data store. This store is written by
S<Dn::CommonBash-E<gt>write_store>.

Required if function data has not yet been loaded from the data store. If
function data has been loaded this parameter is optional, and ignored if
present.

=back

=head3 Prints

Nil.

=head3 Returns

List of display lines.

=head2 select_function($filter, [$store])

=head3 Purpose

Choose a function that matches filter.

Note that an exact match with a function name takes precedence over partial
matches with other function names. For example, given the following functions:

=over 4

=over

=item Do_Thing

=item Do_Thing_Cleverly

=item Do_Thing_Quickly

=back

=back

the command C<$cp-E<gt>select_function('Do_Thing')> will immediately display
details for function 'Do_Thing'. The command
C<$cp-E<gt>select_function('Do_Thing_')> (note trailing underscore) will
display a list of 'Do_Thing_Cleverly' and 'Do_Thing_Quickly' for the user to
select from.

=head3 Parameters

=over

=item $filter

Function name, or part thereof, to filter function names.

Required.

=item $store

Location of function data store. This store is written by
S<Dn::CommonBash-E<gt>write_store>.

Required if function data has not yet been loaded from the data store. If
function data has been loaded this parameter is optional, and ignored if
present.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 write_dictionary($dict, [$master])

=head3 Purpose

Writes sorted list of function names to dictionary file.

=head3 Parameters

=over

=item $dict

Dictionary filepath.

Required.

=item master

Location of root file in the dncommon-bash library.

Required if function data has not previously been extracted from dncommon-bash.
If function data has been loaded this parameter is not required, and if present
is ignored.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 write_loader($loader)

=head3 Purpose

Generate vim loader file. Designed to be called by
S<Dn::CommonBash::Function-E<gt>write_loader>.

=head3 Parameters

=over

=item $loader

Loader filepath.

Required.

=item master

Location of root file in the dncommon-bash library.

Required if function data has not previously been extracted from dncommon-bash.
If function data has been loaded this parameter is not required, and if present
is ignored.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 write_store($store)

=head3 Purpose

Generate persistent data store.

=head3 Parameters

=over

=item $store

Storage file path.

Required.

=item master

Location of root file in the dncommon-bash library.

Required if function data has not previously been extracted from dncommon-bash.
If function data has been loaded this parameter is not required, and if present
is ignored.

=back

=head3 Prints

Feedback.

=head3 Returns

Nil.

=head1 DEPENDENCIES

=over

=item autodie

=item Carp

=item Cwd

=item Dn::Common

=item Dn::CommonBash::Function

=item English

=item experimental

=item Function::Parameters

=item List::MoreUtils

=item Moo

=item MooX::HandlesVia

=item namespace::clean

=item Readonly

=item strictures

=item Test::NeedsDisplay

=item Types::Standard

=item version

=back

=head1 BUGS AND LIMITATIONS

Please report all bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
