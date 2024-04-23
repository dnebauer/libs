package Dn::CommonBash;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('5.30');
use Test::NeedsDisplay;    # must be first listed module

use autodie qw(open close);
use Carp    qw(croak confess);
use Const::Fast;
use Cwd;
use Dn::CommonBash::Function;
use English;
use List::SomeUtils;
use MooX::HandlesVia;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE         => 1;
const my $FALSE        => 0;
const my $FOR_READING  => q{<};
const my $FOR_WRITING  => q{>};
const my $NUMBER_TWO   => 2;
const my $NUMBER_THREE => 3;
const my $NUMBER_FOUR  => 4;
const my $NUMBER_FIVE  => 5;
const my $NUMBER_SIX   => 6;
const my $SPACE        => q{ };
const my $VIM_VARIABLE => q{dnLibCommonBash};

# }}}1

# attributes

# _function_data    {{{1
has '_function_data' => (
  is  => 'rw',
  isa => Types::Standard::HashRef [
    Types::Standard::InstanceOf ['Dn::CommonBash::Function'],
  ],
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
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
);                                     # }}}1

# methods

# _handle_pkglib_dir($filepath, [$master])    {{{1
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
sub _handle_pkglib_dir ($self, $filepath, $master)
{    ## no critic (RequireInterpolationOfMetachars)
  if ($filepath =~ /\@pkglib_dir\@/xsm) {
    my $master_path = $self->dir_name($master);
    $filepath =~ s/\@pkglib_dir\@/$master_path/xsm;
    $filepath .= q{.in};
  }
  elsif ($filepath =~ /\@pkglibexec_dir\@/xsm) {
    my $master_path = $self->dir_name($master);
    $filepath =~ s/\@pkglibexec_dir\@/$master_path/xsm;
    $filepath .= q{.in};    ## no critic (ProhibitDuplicateLiteral)
  }
  return $filepath;
}

# _library_files($master)    {{{1
#
# does:   get list of files in libdncommon-bash
# params: $master - root file in libdncommon-bash [filepath, required]
# prints: nil (except error feedback)
# return: list
# note:   takes (deletes) files one at a time from @found_files, add
#         to master list, then parse file for more sourced files
#         (assumes format like: 'source /path/to/libfile  # comment');
#         if sourced files found, add to @found_files to process in turn
sub _library_files ($self, $master)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $master) { confess q{No master library file provided}; }
  if (not -r $master) {
    confess qq[Invalid master library file '$master' provided];
  }
  my @found_files = $master;
  my @libfiles;

  while (@found_files) {

    # delete file to be processed from front of @found_files array
    my $libfile = shift @found_files;
    if (@libfiles) {    # any fails if @libfiles empty
      if (not(List::SomeUtils::any {/^$libfile\z/xsm} @libfiles)) {
        push @libfiles, $libfile;
      }
    }
    else {
      push @libfiles, $libfile;
    }
    my $fh;
    open $fh, $FOR_READING, $libfile
        or croak "Unable to open $libfile for reading: $OS_ERROR";
    my @lines = <$fh>;
    close $fh;
    foreach my $line (@lines) {
      chomp $line;

      # look for sourced files
      my $filename = $line =~ s/^\s*[.]\s+(\S+).*$/$1/rxsm;
      if ($filename ne $line) {

        # add newly discovered filename to end of @found_files array
        $filename = $self->_handle_pkglib_dir($filename, $master);
        push @found_files, $filename;
      }
    }
  }
  my $msg = q{Found } . scalar @libfiles . q{ library files};
  say $msg or croak;
  return @libfiles;
}

# _load_from_library($master)    {{{1
#
# does:   load function data from library
# params: $master - root file in libdncommon-bash (filepath, required]
# prints: feedback
# return: nil
sub _load_from_library ($self, $master)
{ ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity ProhibitDuplicateLiteral)
  if (not $master) { confess q{Library master file not set}; }
  my %fns;
  my @lines;
  my @libfiles = $self->_library_files($master);
  if (not @libfiles) { confess q{No library files discovered}; }

  # read in content of all library files
  for my $libfile (@libfiles) {
    my $fh;
    open $fh, $FOR_READING, $libfile
        or croak "Unable to open $libfile for reading: $OS_ERROR";
    push @lines, <$fh>;
    close $fh;
  }

  # process library content
  const my $IDX_OPT_ATTR_FUNC   => $NUMBER_TWO;
  const my $IDX_OPT_ATTR_KEY    => $NUMBER_THREE;
  const my $IDX_OPT_ATTR_FLAG   => $NUMBER_FOUR;
  const my $IDX_OPT_ATTR_ATTR   => $NUMBER_FIVE;
  const my $IDX_OPT_ATTR_VAL    => $NUMBER_SIX;
  const my $IDX_PARAM_ATTR_NAME => $NUMBER_FOUR;
  const my $IDX_PARAM_ATTR_ATTR => $NUMBER_FIVE;
  const my $IDX_PARAM_ATTR_VAL  => $NUMBER_SIX;
  const my $IDX_FN_ATTR_ATTR    => $NUMBER_THREE;
  const my $IDX_FN_ATTR_VAL     => $NUMBER_FOUR;

  for my $line (@lines) {
    chomp $line;

    # next line fails mysteriously if flags 'xsm' used
    # as per 'Perl Best Practice'
    next if $line !~ /^# fn_tag/xsm;         # not a function definition line
    my @elements = split /\s+/xsm, $line;    # get elements of line
    my $fn       = $elements[$IDX_OPT_ATTR_FUNC];
    if (not $fns{$fn}) {                     # ensure function defined
      $fns{$fn} = Dn::CommonBash::Function->new();
    }
    my $func        = $fns{$fn};
    my $key_element = $elements[$IDX_OPT_ATTR_KEY];
    for ($key_element) {

      # option attribute definition line
      if (/^option\z/xsm) {
        my $flag = $elements[$IDX_OPT_ATTR_FLAG];
        my $attr = $elements[$IDX_OPT_ATTR_ATTR];
        my $val  = join $SPACE, @elements[ $IDX_OPT_ATTR_VAL .. $#elements ];
        if (not $func->option($flag)) {
          $func->add_option(
            Dn::CommonBash::Function->new()->new_option($flag));
        }
        my $option = $func->option($flag);
        for ($attr) {
          ## no critic (ProhibitCascadingIfElse)
          if    (/^purpose\z/xsmi)  { $option->purpose($val); }
          elsif (/^required\z/xsmi) { $option->required($val); }
          elsif (/^multiple\z/xsmi) { $option->multiple($val); }
          elsif (/^type\z/xsmi)     { $option->type($val); }
          elsif (/^value\z/xsmi)    { $option->add_value($val); }
          elsif (/^default\z/xsmi)  { $option->default($val); }
          elsif (/^note\z/xsmi)     { $option->add_note($val); }
          ## use critic
        }
      }

      # param attribute definition line
      elsif (/^param\z/xsm) {
        my $name = $elements[$IDX_PARAM_ATTR_NAME];
        my $attr = $elements[$IDX_PARAM_ATTR_ATTR];
        my $val = join $SPACE, @elements[ $IDX_PARAM_ATTR_VAL .. $#elements ];
        if (not $func->param($name)) {
          $func->add_param(Dn::CommonBash::Function->new()->new_param($name));
        }
        my $param = $func->param($name);
        for ($attr) {
          ## no critic (ProhibitCascadingIfElse)
          if    (/^purpose\z/xsmi)   { $param->purpose($val); }
          elsif (/^required\z/xsmi)  { $param->required($val); }
          elsif (/^multipart\z/xsmi) { $param->multipart($val); }
          elsif (/^type\z/xsmi)      { $param->type($val); }
          elsif (/^value\z/xsmi)     { $param->add_value($val); }
          elsif (/^default\z/xsmi)   { $param->default($val); }
          elsif (/^note\z/xsmi)      { $param->add_note($val); }
          ## use critic
        }
      }

      # function attribute definition line
      else {
        my $attr = $elements[$IDX_FN_ATTR_ATTR];
        my $val  = join $SPACE, @elements[ $IDX_FN_ATTR_VAL .. $#elements ];
        for ($attr) {
          ## no critic (ProhibitCascadingIfElse)
          if    (/^purpose\z/xsmi) { $func->purpose($val); }
          elsif (/^prints\z/xsmi)  { $func->prints($val); }
          elsif (/^returns\z/xsmi) { $func->returns($val); }
          elsif (/^note\z/xsmi)    { $func->add_note($val); }
          elsif (/^usage\z/xsmi)   { $func->add_usage($val); }
          ## use critic
        }
      }
    }
  }

  # load function data
  $self->_clear_functions;
  $self->_set_functions(%fns);

  return;
}

# _load_from_store($store)    {{{1
#
# does:   load function data from persistent data store
# params: $store - storage filepath [required]
# prints: feedback
# return: nil
# note:   data store is assumed to have been created
#         with the 'write_store' method
sub _load_from_store ($self, $store)
{    ## no critic (RequireInterpolationOfMetachars)

  # check storage file
  if (not $store) { confess q{No storage filepath provided}; }
  if (not -r $store) {
    confess qq[Invalid storage filepath '$store' provided];
  }

  # retrieve function data and load it
  my $funcs_ref = $self->data_retrieve($store);
  my %functions = %{$funcs_ref};
  $self->_clear_functions;
  $self->_set_functions(%functions);

  # provide feedback
  my $msg = q{Retrieved data on } . $self->_function_count . q{ functions};
  say $msg or croak;

  return;
}

# display_function_details($name, [$store])    {{{1
#
# does:   display information about the named function
#         formatted for console display
# params: $name  - name of function to display [required]
#         $store - function data store [filepath, optional]
#                  required if functions have not been loaded
# prints: nil
# return: list of display lines
sub display_function_details ($self, $name, $store)
{    ## no critic (RequireInterpolationOfMetachars)

  # must have function name
  if (not $name) {
    confess q{No name provided};
  }

  # ensure function data is loaded
  if (not $self->_has_functions) {
    if (not($self->_load_from_store($store))) {
      confess qq{Unable to load from store '$store'};
    }
  }

  # must have details on that function
  if (not($self->_has_function($name))) {
    confess qq{Cannot find details of function '$name'};
  }

  # display details
  if (my $function = $self->_function($name)) {
    if (my @display = $function->display_function_screen($name)) {
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

# select_function($filter, [$store])    {{{1
#
# does:   choose a function
# params: $filter - part of function name [required]
#         $store  - function data store [filepath, optional]
#                   required if functions have not been loaded
# prints: nil
# return: scalar string
sub select_function ($self, $filter, $store)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $self->_has_functions) {
    $self->_load_from_store($store);
  }
  my @funcs = $self->_function_names();

  # first try for exact match (assume returns either 1 or 0)
  my @exact_match;
  if ($filter) {
    @exact_match = grep {/^$filter\z/xsmi} @funcs;
  }
  if (scalar @exact_match == 1) {
    return $exact_match[0];
  }

  # if no exact match, look for partial matches
  if ($filter) {
    @funcs = grep {/$filter/xsmi} @funcs;
  }

  for (scalar @funcs) {
    if ($_ == 0) {
      say q{No matching function found} or croak;
      return q{};
    }
    elsif ($_ == 1) {
      say q{Only one matching function found} or croak;
      return "@funcs";
    }
    else {    # > 1
      return $self->interact_choose(q{Select function:}, @funcs);
    }
  }
  return q{};
}

# write_dictionary($dict, [$master])    {{{1
#
# does:   write sorted list of function names to dictionary file
# params: $dict - dictionary filepath [required]
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: nil
# return: nil
sub write_dictionary ($self, $dict, $master)
{    ## no critic (RequireInterpolationOfMetachars)

  # need output filename and data to write to it
  if (not $dict) {
    confess q{No dictionary filepath provided};
  }
  if (not $self->_has_functions) {
    if (not($self->_load_from_library($master))) {
      confess qq{Unable to extract function data from '$master'};
    }
  }

  # ensure dictionary path exists
  my $dict_dir = $self->dir_name($dict);
  if ($dict_dir) {
    if (not($self->dir_make($dict_dir))) {
      confess qq{Unable to make directory '$dict_dir'};
    }
  }

  # write dictionary file
  my @function_names = sort $self->_function_names;
  my $fh;
  open $fh, $FOR_WRITING, $dict
      or croak "Unable to open $dict for writing: $OS_ERROR";
  foreach my $function_name (@function_names) {
    print {$fh} "$function_name\n" or confess qq{Couldn't write '$dict'};
  }
  close $fh;

  # provide feedback
  say q{wrote }
      . $self->_function_count
      . q{ function names to dictionary file}
      or croak;
  return;
}

# write_loader($loader, [$master])    {{{1
#
# does:   generate vim loader file
# params: $loader - loader filepath [required]
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: nil
# return: nil
# note:   designed to be called by Dn::CommonBash::Function->write_loader
sub write_loader ($self, $loader, $master)
{    ## no critic (RequireInterpolationOfMetachars)

  # need output filename and data to write to it
  if (not $loader) {
    confess q{No loader filepath provided};
  }
  if (not $self->_has_functions) {
    if (not($self->_load_from_library($master))) {
      ## no critic (ProhibitDuplicateLiteral)
      confess qq{Unable to extract function data from '$master'};
      ## use critic
    }
  }

  # ensure loader path exists
  my $loader_dir = $self->dir_name($loader);
  if ($loader_dir) {
    if (not($self->dir_make($loader_dir))) {
      confess qq{Unable to make directory '$loader_dir'};
    }
  }

  # generate output
  my @data;
  push @data, q{" Vim loader file};
  push @data, $SPACE;
  push @data, q{" Loads function data from libdncommon-bash};
  push @data, q{" into an associative array.};
  push @data, q{};
  push @data,
        q{" [Generated by }
      . $self->script_name() . q{ on }
      . $self->date_current_iso() . q{]};
  push @data, q{};
  push @data, q{" -------------------------------------------};
  push @data, q{};
  push @data, q[let ] . $VIM_VARIABLE . q[ = {}];
  push @data, q{};

  # main output here
  foreach my $func_name ($self->_function_names) {
    my $function = $self->_function($func_name);
    push @data, q{let }    ## no critic (ProhibitDuplicateLiteral)
        . $VIM_VARIABLE . q{['}
        . $func_name
        . q{'] = }
        . $function->write_function_loader();
  }

  # write output
  my $fh;
  open $fh, $FOR_WRITING, $loader
      or croak "Unable to open $loader for writing: $OS_ERROR";
  foreach my $line (@data) {
    print {$fh} qq{$line\n}
        or confess qq{Unable to write file '$loader'};
  }
  close $fh;

  # provide feedback
  my $msg =
        q{wrote data on }
      . $self->_function_count()
      . q{ functions to loader file};
  say $msg or croak;

  return;
}

# write_store($store, [$master])    {{{1
#
# does:   generate persistent data store
# params: $store  - storage file path [required]
#                   will create path if does not exist
#         $master - filepath of root file of dncommon-bash library
#                   [required if function data not loaded]
# prints: feedback
# return: nil
sub write_store ($self, $store, $master)
{    ## no critic (RequireInterpolationOfMetachars)

  # need output filename and data to write to it
  if (not $store) {
    confess q{No data store filepath provided};
  }
  if (not $self->_has_functions) {
    if (not($self->_load_from_library($master))) {
      ## no critic (ProhibitDuplicateLiteral)
      confess qq{Unable to extract function data from '$master'};
      ## use critic
    }
  }

  # get functions to store
  my $functions = { $self->_get_functions };

  # ensure storage path exists
  my $storage_dir = $self->dir_name($store);
  if ($storage_dir) {
    if (not($self->dir_make($storage_dir))) {
      confess qq{Unable to make directory '$storage_dir'};
    }
  }

  # save functions to store
  $self->data_store($functions, $store);

  # provide feedback
  my $msg = q{wrote data on }    ## no critic (ProhibitDuplicateLiteral)
      . $self->_function_count() . q{ functions to storage file};
  say $msg or croak;

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Dn::CommonBash - helper module for libdncommon-bash

=head1 SYNOPSIS

  use Dn::CommonBash;

=head1 VERSION

This documentation is for Dn::CommonBash version 5.30.

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

=head1 DIAGNOSTICS

=head2 Unable to open FILE for reading: ERROR
=head2 Unable to open FILE for writing: ERROR

Occur when a system error prevents file reading or writing.

=head2 Invalid master library file 'FILE' provided
=head2 Library master file not set
=head2 No library files discovered
=head2 No master library file provided
=head2 Unable to load from store 'FILE'

Occurs when the master library file path is not provided or cannot be read.

=head2 Invalid storage filepath 'FILE' provided
=head2 No storage filepath provided
=head2 Unable to extract function data from 'FILE'

Occurs when the master library file path is not provided or cannot be read.

=head2 Cannot find details of function 'NAME'
=head2 No name provided
=head2 Unable to get display details for function 'NAME'
=head2 Unable to retrieve details for function 'NAME'

These errors occur when data on a specific function is unable to be retrieved
from the storage file.

=head2 Couldn't write 'FILE'
=head2 No dictionary filepath provided
=head2 Unable to make directory 'FILE'
=head2 Unable to open $dict for writing: ERROR"

These errors occur when the dictionary file is unable to be written.

=head2 No loader filepath provided
=head2 Unable to make directory 'FILE'
=head2 Unable to open $loader for writing: ERROR
=head2 Unable to write file 'FILE'

Errors that can occur when writing the vim loader file.

=head2 No data store filepath provided
=head2 Unable to make directory 'FILE'

These errors can occur when writing the data storage file.

=head1 CONFIGURATION AND ENVIRONMENT

This module has no configuration settings, nor does it rely on
environmental variables.

=head1 INCOMPATIBILITIES

There are no known incompatibiilties.

=head1 DEPENDENCIES

autodie, Carp, Const::Fast, Cwd, Dn::CommonBash::Function, English,
List::SomeUtils, Moo, MooX::HandlesVia, namespace::clean, Role::Utils::Dn,
strictures, Test::NeedsDisplay, Types::Standard, version.

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
