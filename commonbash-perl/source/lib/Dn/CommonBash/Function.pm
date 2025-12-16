package Dn::CommonBash::Function;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('5.40');

use Test::NeedsDisplay;    # needs to be the first listed module
use Carp qw(confess);
use Const::Fast;
use Dn::CommonBash::Function::Option;
use Dn::CommonBash::Function::Param;
use English;
use MooX::HandlesVia;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE            => 1;
const my $FALSE           => 0;
const my $COMMA           => q{,};
const my $LUA_TABLE_CLOSE => q[}];
const my $LUA_TABLE_OPEN  => q[{ ];
const my $SPACE           => q{ };
const my $STR_ERROR       => q{error};    # }}}1

# attributes

# purpose    {{{1
has 'purpose' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => q{Description of functions's purpose},
);

# prints    {{{1
has 'prints' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => q{Desription of functions's printed output},
);

# returns    {{{1
has 'returns' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => q{Description of functions's return value},
);

# _notes, add_note    {{{1
has '_notes_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _notes     => 'elements',
    add_note   => 'push',
    _has_notes => 'count',
  },
  documentation => q{Miscellaneous notes},
);

# _usages, add_usage    {{{1
has '_usage_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _usages     => 'elements',
    add_usage   => 'push',
    _has_usages => 'count',
  },
  documentation => q{Example code demonstrating use},
);

# option($flag), _options_list, add_option    {{{1
has '_options_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Dn::CommonBash::Function::Option'],
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _options        => 'elements',    # () -> @opt_refs
    add_option      => 'push',        # ($opt_ref)
    _has_options    => 'count',       # () -> bool
    _filter_options => 'grep',
  },
  documentation => 'Options',
);

sub option ($self, $flag) {
  if (not $flag) { return; }    ## no critic (EmptyReturn)
  my @matches     = $self->_filter_options(sub { $_->flag eq $flag });
  my $match_count = @matches;
  if ($match_count == 1) {
    return $matches[0];
  }
  else {
    return;    ## no critic (EmptyReturn)
  }
}

# param($name), _params, add_param    {{{1
has '_param_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Dn::CommonBash::Function::Param'],
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _params        => 'elements',
    add_param      => 'push',
    _has_params    => 'count',
    _filter_params => 'grep',
  },
  documentation => 'Parameters',
);

sub param ($self, $name) {
  if (not $name) { return; }    ## no critic (EmptyReturn)
  my @matches     = $self->_filter_params(sub { $_->name eq $name });
  my $match_count = @matches;
  if ($match_count == 1) {
    return $matches[0];
  }
  else {
    return;    ## no critic (EmptyReturn)
  }
}    # }}}1

# methods

# display_function_screen($name)    {{{1
#
# does:   provide formatted version of function for screen display
# params: $name = function name [required]
# prints: nil
# return: list of display lines
# note:   output is a list of strings -- one string per screen line
# note:   output strings are prepared by Role::Utils::Dn->vim_printify
#         and need to be printed to screen using Role::Utils::Dn->vim_list_print
# note:   the function object does not contain its own name -- that is
#         captured by the hash key pointing to the function object -- it
#         must be passed as an argument
# note:   format:
#           Function: <function>
#           <purpose>
#           [Prints: <prints>]
#           [Return: <return>]
#           [<note1>]
#           [<note2>]
#           [<usage1>]
#           [<usage2>]
#           [...]
#           << options >>
#           << params >>
sub display_function_screen ($self, $name) {
  my @fn;

  # name
  push @fn, $self->vim_printify('title', '*** Function = ' . $name . ' ***');

  # purpose
  if ($self->purpose) {
    push @fn, '    Use: ' . $self->purpose;
  }
  else {    # no 'purpose' attribute
    push @fn,
        $self->vim_printify($STR_ERROR, q{  Error: No 'purpose' attribute});
  }

  # prints
  if ($self->prints) {
    push @fn, ' Prints: ' . $self->prints;
  }
  else {    # no 'prints' attribute
    push @fn,
        $self->vim_printify($STR_ERROR, q{  Error: No 'prints' attribute},);
  }

  # returns
  if ($self->returns) {
    push @fn, 'Returns: ' . $self->returns;
  }
  else {    # no 'returns' attribute
    push @fn, $self->vim_printify('warn', q{  Error: No 'returns' attribute});
  }

  # notes
  if ($self->_has_notes) {
    foreach my $note ($self->_notes) {
      push @fn, '   Note: ' . $note;
    }
  }

  # usage
  if ($self->_has_usages) {
    my $prefix = '  Usage: ';
    my $header = $TRUE;
    foreach my $usage ($self->_usages) {
      push @fn, $prefix . $self->string_tabify($usage);
      if ($header) {
        $prefix = q{         };
        $header = $FALSE;
      }
    }
  }

  # options
  if ($self->_has_options) {
    foreach my $option ($self->_options) {
      push @fn, $SPACE;
      push @fn, $option->display_option_screen;
    }
  }

  # parameters
  my $order = 1;
  if ($self->_has_params) {
    foreach my $param ($self->_params) {
      push @fn, $SPACE;
      push @fn, $param->display_param_screen($order++);
    }
  }

  return @fn;
}

# new_option($flag)    {{{1
#
# does:   create new Dn::CommonBash::Function::Option object
# params: $flag - option flag [required]
# prints: nil
# return: Dn::CommonBash::Function::Option object
sub new_option ($self, $flag) {
  if (not $flag) { confess q{No option flag provided}; }
  return Dn::CommonBash::Function::Option->new(flag => $flag);
}

# new_param($flag)    {{{1
#
# does:   create new Dn::CommonBash::Function::Param object
# params: $name - param name [required]
# prints: nil
# return: Dn::CommonBash::Function::Param object
sub new_param ($self, $name) {
  if (not $name) { confess q{No parameter name provided}; }
  return Dn::CommonBash::Function::Param->new(name => $name);
}

# write_nvim_function_loader()    {{{1
#
# does:   generate rhs of lua assignment statement for function loader
# params: name - name of function [string, required]
# prints: nil
# return: scalar string
sub write_nvim_function_loader ($self, $name) {
  my $fn = $LUA_TABLE_OPEN;

  $fn .= qq(["name"] = "$name", );

  # purpose
  if ($self->purpose) {
    my $purpose_value = $self->string_entitise($self->purpose);
    $fn .= qq(["purpose"] = "$purpose_value", );
  }

  # prints
  if ($self->prints) {
    my $prints_value = $self->string_entitise($self->prints);
    $fn .= qq(["prints"] = "$prints_value", );
  }

  # returns
  if ($self->returns) {
    my $returns_value = $self->string_entitise($self->returns);
    $fn .= qq(["returns"] = "$returns_value", );
  }

  # notes
  if ($self->_has_notes) {
    $fn .= qq(["notes"] = $LUA_TABLE_OPEN );
    foreach my $note ($self->_notes) {
      my $note_value = $self->string_entitise($note);
      $fn .= qq("$note_value", );
    }
    $fn .= $LUA_TABLE_CLOSE . $COMMA . $SPACE;
  }

  # usage
  if ($self->_has_usages) {
    $fn .= qq(["usage"] = $LUA_TABLE_OPEN );
    foreach my $usage ($self->_usages) {
      my $usage_value = $self->string_entitise($usage);
      $fn .= qq("$usage_value", );
    }
    $fn .= $LUA_TABLE_CLOSE . $COMMA . $SPACE;
  }

  # options
  if ($self->_has_options) {
    $fn .= qq(["options"] = $LUA_TABLE_OPEN );
    foreach my $option ($self->_options) {
      my $option_value = $option->write_nvim_option_loader();
      $fn .= qq($option_value, );
    }
    $fn .= $LUA_TABLE_CLOSE . $COMMA . $SPACE;
  }

  # parameters
  if ($self->_has_params) {
    $fn .= qq(["params"] = $LUA_TABLE_OPEN );
    foreach my $param ($self->_params) {
      my $param_value = $param->write_nvim_param_loader();
      $fn .= qq($param_value, );
    }
    $fn .= $LUA_TABLE_CLOSE . $COMMA . $SPACE;
  }
  $fn .= $LUA_TABLE_CLOSE;
  return $fn;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Dn::CommonBash::Function - a bash function

=head1 VERSION

This documentation is for Dn::CommonBash::Function version 5.40.

=head1 SYNOPSIS

  use Dn::CommonBash::Function;

=head1 DESCRIPTION

Dn::CommonBash::Function encapsulates a bash function.

=head1 SUBROUTINES/METHODS

=head2 add_note($note)

=head3 Purpose

Add parameter note.

=head3 Parameters

=over

=item $note

Note to add. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of notes in parameter.

=head2 add_usage($usage)

=head3 Purpose

Add parameter usage line.

=head3 Parameters

=over

=item $usage

Usage line to add. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of usage lines in parameter.

=head2 add_option($option)

=head3 Purpose

Add function option.

=head3 Paramaters

=over

=item $option

A Dn::CommonBash::Function::Option object.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of options in function.

=head2 add_param($param)

=head3 Purpose

Add function parameter.

=head3 Paramaters

=over

=item $param

A Dn::CommonBash::Function::Param object.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of parameters in function.

=head2 display_function_screen($name)

=head3 Purpose

Provide formatted version of function for screen display.
Output is a list of strings -- one string per screen line.
Output strings are prepared by the C<vim_printify> method of
L<Role::Utils::Dn> and need to be printed to screen using the
C<vim_list_print> method of L<Role::Utils::Dn>.

Because the function object does not contain its own name --
that is captured by the hash key pointing to the function object --
it must be passed as an argument.

Format:

	Function: <function>
	<purpose>
	[Prints: <prints>]
	[Return: <return>]
	[<note1>]
	[<note2>]
	[<usage1>]
	[<usage2>]
	[...]
	<< options >>
	<< params >>

=head3 Parameters

=over

=item $name

Function name.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

List of display lines.

=head2 new_option($flag)

=head3 Purpose

Create new Dn::CommonBash::Function::Option object.

=head3 Parameters

=over

=item $flag

Option flag.

Required. Single character.

=back

=head3 Prints

Nil (error message if fails).

=head3 Returns

Dn::CommonBash::Function::Option object.

=head2 new_param($name)

=head3 Purpose

Create new Dn::CommonBash::Function::Param object.

=head3 Parameters

=over

=item $name

Parameter name.

Required.

=back

=head3 Prints

Nil (error message if fails).

=head3 Returns

Dn::CommonBash::Function::Param object.

=head2 option($flag)

=head3 Purpose

Get existing option.

=head3 Parameters

=over

=item $flag

Flag of option to retrieve.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Option object (Dn::CommonBash::Function::Option).

=head2 param($name)

=head3 Purpose

Get existing parameter.

=head3 Parameters

=over

=item $name

Name of parameter to retrieve.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Parameter object (Dn::CommonBash::Function::Param).

=head2 prints([$prints])

=head3 Purpose

Get or set parameter 'prints' attribute.

=head3 Parameters

=over

=item $prints

Parameter 'prints' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 purpose([$purpose])

=head3 Purpose

Get or set parameter 'purpose' attribute.

=head3 Parameters

=over

=item $purpose

Parameter 'purpose' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 returns([$returns])

=head3 Purpose

Get or set parameter 'returns' attribute.

=head3 Parameters

=over

=item $returns

Parameter 'returns' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 write_nvim_function_loader()

=head3 Purpose

Generate right hand side of lua assignment statement for function loader.

=head3 Parameters

Nil.

=head3 Print

Nil.

=head3 Returns

Scalar string.

=head1 DIAGNOSTICS

=head2 No option flag provided
=head2 No parameter name provided

Occurs when the user fails to provide necessary input.

=head1 CONFIGURATION AND ENVIRONMENT

This module does not rely on any configuration setting
or environmental variables.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

There are no known bugs or limitations.

=head1 DEPENDENCIES

Carp, Const::Fast, Dn::CommonBash::Function::Options,
Dn::CommonBash::Function::Param, English, Moo, MooX::HandlesVia, MooX::Options,
namespace::clean, Role::Utils::Dn, strictures, Test::NeedsDisplay,
Types::Standard, version.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
