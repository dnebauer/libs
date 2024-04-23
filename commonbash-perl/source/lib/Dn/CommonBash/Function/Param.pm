package Dn::CommonBash::Function::Param;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('5.30');

use Test::NeedsDisplay;    # must be first listed
use Const::Fast;
use Dn::CommonBash::Types;
use English;
use MooX::HandlesVia;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE                      => 1;
const my $FALSE                     => 0;
const my $CLOSE_BRACKET_COMMA_SPACE => q{], };
const my $COMMA_SPACE               => q{, };
const my $SINGLE_QUOTE              => q{'};
const my $SINGLE_QUOTE_COMMA_SPACE  => q{', };    # }}}1

# attributes

# name    {{{1
has 'name' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => 'Parameter name',
);

# purpose    {{{1
has 'purpose' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => q{Description of parameter's purpose},
);

# required    {{{1
has 'required' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::Boolean,
  documentation => 'Whether parameter is required or optional (bool)',
);

# multipart    {{{1
has 'multipart' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::Boolean,
  documentation => 'Whether parameter can occur multiple times (bool)',
);

# type    {{{1
has 'type' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::ParamType,
  documentation => 'Types of value that parameter can hold',

  # must be one of: 'string', 'integer', 'boolean',
  # 'filepath', 'date' or 'time'
);

# values, add_value, _values_list    {{{1
has '_values_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    values      => 'elements',
    add_value   => 'push',
    _has_values => 'count',
  },
  documentation => 'Allowable values parameter can be set to',
);

# default    {{{1
has 'default' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => 'Default value',
);

# notes, add_note, _notes_list    {{{1
has '_notes_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    notes      => 'elements',
    add_note   => 'push',
    _has_notes => 'count',
  },
  documentation => 'Miscellaneous notes',
);    # }}}1

# methods

# display_param_screen($order)    {{{1
#
# does:   provide formatted version of parameter for screen display
# params: $order - parameter number [integer, required]
# prints: nil
# return: list of display lines
# note:   output is a list of strings -- one string per screen line
# note:   output strings are prepared by Role::Utils::Dn->vim_printify and
#         need to be printed to screen using Role::Utils::Dn->vim_list_print
# note:   designed to be called by Role::Utils::Dn->display_function_screen
# note:   format:
#           PARAM 1: foo [required, multipart]
#               Use: To splinge the bar
#              Note: Use only in case of emergency
#              Note: See doctor if symptoms persist
#              Type: String
#            Values: 'race', 'the', 'night'
#           Default: 'race'
sub display_param_screen ($self, $order)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not($order and $order =~ /^[1-9]\d*\z/xsm)) { return (); }
  my @param;
  my @errors;

  # number
  my $line = 'PARAM ' . $order . ': ';

  # name
  $line .= $self->name;

  # required: is integer so unquoted
  $line .= ' [';
  my $is_required;
  if ($self->required) {
    $is_required = $self->value_boolise($self->required);
    $line .= ($is_required)
        ? 'required'    ## no critic (ProhibitDuplicateLiteral)
        : 'optional';
  }
  else {                # no 'required' attribute
    push @errors, q{  Error: No 'required' attribute};
  }

  # multipart: is integer so unquoted
  if ($self->multipart) {
    my $is_multipart = $self->value_boolise($self->multipart);
    $line .= ($is_multipart) ? ', multipart' : q{};
  }
  else {                # no 'multipart' attribute
    push @errors, q{  Error: No 'multipart' attribute};
  }
  $line .= ']';

  # have now completed first line
  push @param, $line;
  foreach my $error (@errors) {
    push @param, $self->vim_printify('error', $error);
  }

  # purpose
  if ($self->purpose) {
    push @param, '    Use: ' . $self->purpose;
  }
  else {    # no 'purpose' attribute
    push @param, $self->vim_printify(
      'error',    ## no critic (ProhibitDuplicateLiteral)
      q{  Error: No 'purpose' attribute},
    );
  }

  # notes
  if ($self->_has_notes) {
    foreach my $note ($self->notes) {
      push @param, '   Note: ' . $note;
    }
  }

  # type
  if ($self->type) {
    push @param, '   Type: ' . $self->type;
  }
  else {    # no 'type' attribute
    push @param, $self->vim_printify(
      'error',    ## no critic (ProhibitDuplicateLiteral)
      q{  Error: No 'type' attribute},
    );
  }

  # values
  if ($self->_has_values) {
    my @quoted_values =
        map { $SINGLE_QUOTE . $_ . $SINGLE_QUOTE } $self->values;
    my $values = ' Values: ';
    $values .= join $COMMA_SPACE, @quoted_values;
    push @param, $values;
  }

  # default
  if ($self->default) {
    push @param, q{Default: '} . $self->default . $SINGLE_QUOTE;

    # detect logical inconsistency of parameter with default value
    # that is nonetheless required
    if ($is_required) {
      @errors = (
        'Warning: Possible misconfiguration: Has',
        '         default value but also is required',
      );
      foreach my $error (@errors) {
        push @param, $self->vim_printify('warn', $error);
      }
    }
  }

  # return parameter details
  return @param;
}

# write_param_loader()    {{{1
#
# does:   generate portion of vim 'let' command for loader
# params: nil
# prints: nil
# return: scalar string
# note:   designed to be called by Dn::CommonBash->write_function_loader
sub write_param_loader ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $param = '{ ';

  # name
  if ($self->name) {
    $param
        .= q{'name': '}
        . $self->string_entitise($self->name)
        . $SINGLE_QUOTE_COMMA_SPACE;
  }

  # purpose
  if ($self->purpose) {
    $param
        .= q{'purpose': '}
        . $self->string_entitise($self->purpose)
        . $SINGLE_QUOTE_COMMA_SPACE;
  }

  # required: is integer so unquoted
  if ($self->required) {
    $param
        .= q{'required': }
        . $self->value_boolise($self->required)
        . $COMMA_SPACE;
  }

  # multipart: is integer so unquoted
  if ($self->multipart) {
    $param
        .= q{'multipart': }
        . $self->value_boolise($self->multipart)
        . $COMMA_SPACE;
  }

  # type
  if ($self->type) {
    $param
        .= q{'type': '}
        . $self->string_entitise($self->type)
        . $SINGLE_QUOTE_COMMA_SPACE;
  }

  # values
  if ($self->_has_values) {
    $param .= q{'values': [ };
    foreach my $value ($self->values) {
      $param
          .= $SINGLE_QUOTE
          . $self->string_entitise($value)
          . $SINGLE_QUOTE_COMMA_SPACE;
    }
    $param .= $CLOSE_BRACKET_COMMA_SPACE;
  }

  # default
  if ($self->default) {
    $param
        .= q{'default': '}
        . $self->string_entitise($self->default)
        . $SINGLE_QUOTE_COMMA_SPACE;
  }

  # notes
  if ($self->_has_notes) {
    $param .= q{'notes': [ };
    foreach my $note ($self->notes) {
      $param
          .= $SINGLE_QUOTE
          . $self->string_entitise($note)
          . $SINGLE_QUOTE_COMMA_SPACE;
    }
    $param .= $CLOSE_BRACKET_COMMA_SPACE;
  }
  $param .= '}';

  # return param loader
  return $param;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Dn::CommonBash::Function::Param - dncommon-bash library function parameter

=head1 VERSION

This documentation refers to Dn::CommonBash::Function::Param version 5.30.

=head1 SYNOPSIS

  use Dn::CommonBash::Function::Param;

=head1 DESCRIPTION

Dn::CommonBash::Function::Param encapsulates a function parameter.

=head1 SUBROUTINES/METHODS

=head2 add_note($note)

=head3 Purpose

Add to parameter attribute.

=head3 Paramaters

=over

=item $note

Note to be added to parameter. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of notes in parameter.

=head2 add_value($value)

=head3 Purpose

Add to parameter attribute.

=head3 Paramaters

=over

=item $value

Value to be added to parameter. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of values in parameter.

=head2 default([$default])

=head3 Purpose

Get or set parameter 'default' attribute.

=head3 Parameters

=over

=item $default

Parameter 'default' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 display_param_screen()

=head3 Purpose

Provide formatted version of parameter for screen display.
Output is a list of strings -- one string per screen line.
Output strings are prepared by the C<vim-printify> method from
L<Role::Utils::Dn> and need to be printed to screen using the
C<vim_list_print> method from L<Role::Utils::Dn>.

This method is designed to be called by the C<display_function_screen> method
from L<Dn::CommonBash>.

Format:

	PARAM 1: foo [required, multipart]
	    Use: To splinge the bar
	   Note: Use only in case of emergency
	   Note: See doctor if symptoms persist
	   Type: String
	 Values: 'race', 'the', 'night'
	Default: 'race'

=head3 Parameters

=over 4

=over

=item $order

Number of parameter. Scalar integer.

Required.

=back

=back

=head3 Prints

Nil.

=head3 Returns

List of display lines.

=head2 multipart([$multipart])

=head3 Purpose

Get or set parameter 'multipart' attribute.

=head3 Parameters

=over

=item $multipart

Parameter 'multipart' value.
Boolean value ('yes', 'true', 1, 'no', 'false', or 0).

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 name([$name])

=head3 Purpose

Get or set parameter 'name' attribute.

=head3 Parameters

=over

=item $name

Parameter 'name' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 notes()

=head3 Purpose

Gets parameter notes.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of parameter notes.

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

=head2 required([$required])

=head3 Purpose

Get or set parameter 'required' attribute.

=head3 Parameters

=over

=item $required

Parameter 'required' value.
Boolean value ('yes', 'true', 1, 'no', 'false', or 0).

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 type([$type])

=head3 Purpose

Get or set parameter 'type' attribute.

=head3 Parameters

=over

=item $type

Parameter 'type' value. Must be one of: 'string', 'integer', 'number',
'boolean', 'path', 'date', or 'time'.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 values()

=head3 Purpose

Gets parameter values.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of parameter values.

=head2 write_param_loader()

=head3 Purpose

Generate portion of vim 'let' command for loader. Designed to be called by the
C<write_function_loader> method of L<Dn::CommonBash>.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head1 DIAGNOSTICS

This module does not emit any custom errors.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration options for this module.

=head1 INCOMPATIBILITIES

There are no known incomptibilities.

=head1 BUGS AND LIMITATIONS

There are no known bugs.

=head1 DEPENDENCIES

Const::Fast, English, Moo, MooX::HandlesVia, namespace::clean, Role::Utils::Dn,
strictures, Test::NeedsDisplay, Types::Standard, version.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
