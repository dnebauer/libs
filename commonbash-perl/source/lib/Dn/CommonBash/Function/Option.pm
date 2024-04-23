package Dn::CommonBash::Function::Option;

# modules    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use namespace::clean;
use version; our $VERSION = qv('5.30');

use Test::NeedsDisplay;    # must be first listed module
use Const::Fast;
use Dn::CommonBash::Types;
use English;
use MooX::HandlesVia;
use Types::Standard;

with qw(Role::Utils::Dn);

const my $TRUE             => 1;
const my $FALSE            => 0;
const my $APOS_COMMA_SPACE => q{', };
const my $COMMA_SPACE      => q{, };
const my $SINGLE_QUOTE     => q{'};     # }}}1

# attributes

# flag    {{{1
has 'flag' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::Char,
  documentation => 'Option flag',
);

# purpose    {{{1
has 'purpose' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => q{Description of option's purpose},
);

# required    {{{1
has 'required' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::Boolean,
  documentation => 'Whether option is required or optional',
);

# multiple    {{{1
has 'multiple' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::Boolean,
  documentation => 'Whether option can occur multiple times or not',
);

# type    {{{1
has 'type' => (
  is            => 'rw',
  isa           => Dn::CommonBash::Types::OptionType,
  documentation => 'Type of values that option can hold',
);

# values, add_value, _values_list    {{{1
has '_values_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    values      => 'elements',
    add_value   => 'push',
    _has_values => 'count',
  },
  documentation => 'Allowable values this option can be set to',

  # has no meaning if 'type' is set to 'none'
);

# default    {{{1
has 'default' => (
  is            => 'rw',
  isa           => Types::Standard::Str,
  documentation => 'Default value for this option',

  # has no meaning if 'type' is set to 'none'
);

# notes, add_note, _notes_list    {{{1
has '_notes_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  handles_via => 'Array',
  default     => sub { [] },
  handles     => {
    notes      => 'elements',
    add_note   => 'push',
    _has_notes => 'count',
  },
  documentation => 'Miscellaneous notes',
);    # }}}1

# methods

# display_option_screen()    {{{1
#
# does:   provide formatted version of option for screen display
# params: nil
# prints: nil
# return: list
# note:   output is a list of strings -- one string per screen line
# note:   output strings are prepared by Role::Utils::Dn->vim_printify
#         and need to be printed to screen by Role::Utils::Dn->vim_list_print
# note:   designed to be called by Dn::CommonBash->display_function_screen
# note:   example output:
#             OPTION: -v [optional, multiple]
#                Use: To display more information
#               Note: Using multiple times gives further information
# note:   example output:
#             OPTION: -x "<String>" [required]
#                Use: To splinge the bar
#               Note: Use only in case of emergency
#               Note: See doctor if symptoms persist
#             Values: 'race', 'the', 'night'
#            Default: 'race'
sub display_option_screen ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $line;      # each line of display
  my @option;    # display output
  my @errors;    # errors
                 # flag
  $line = ' OPTION: -' . $self->flag;

  # type
  if ($self->type && $self->type !~ /none/xsmi) {    # has value
    $line .= q{\<} . $self->type . q{>"};
  }
  else {                                             # has no value
    push @errors, q{  Error: No 'type' attribute};
  }

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

  # multiple: is integer so unquoted
  if ($self->multiple) {
    my $is_multiple = $self->value_boolise($self->multiple);
    $line .= ($is_multiple) ? ', multiple' : q{};
    $line .= ']';
  }
  else {                # no 'multiple' attribute
    push @errors, q{  Error: No 'multiple' attribute};
  }

  # have now completed first line
  push @option, $line;
  foreach my $error (@errors) {
    push @option, $self->vim_printify('error', $_);
  }

  # purpose
  if ($self->purpose) {
    push @option, '    Use: ' . $self->purpose;
  }
  else {    # no 'purpose' attribute
    push @option, $self->vim_printify(
      'error',    ## no critic (ProhibitDuplicateLiteral)
      q{  Error: No 'purpose' attribute},
    );
  }

  # notes
  if ($self->_has_notes) {
    foreach my $note ($self->notes) {
      push @option, '   Note: ' . $note;
    }
  }

  # values
  if ($self->_has_values) {
    my $vals = ' Values: ';
    my @quoted_values =
        map { $SINGLE_QUOTE . $_ . $SINGLE_QUOTE } $self->values;
    $vals .= join $COMMA_SPACE, @quoted_values;
    push @option, $vals;
  }

  # default
  if ($self->default) {
    push @option, q{Default: '} . $self->default . $SINGLE_QUOTE;

    # detect logical inconsistency of option with default value
    # that is nonetheless required
    if ($is_required) {
      @errors = (
        'Warning: Possible misconfiguration: Has',
        '         default value but also is required',
      );
      for my $error (@errors) {
        push @option, $self->vim_printify('warn', $error);
      }
    }
  }

  # return option details
  return @option;
}

# write_option_loader()    {{{1
#
# does:   generate portion of vim 'let' command for loader
# params: nil
# prints: nil
# return: scalar string
sub write_option_loader ($self)
{    ## no critic (RequireInterpolationOfMetachars)
  my $option = '{ ';

  # flag
  if ($self->flag) {
    $option
        .= q{'flag': '}
        . $self->string_entitise($self->flag())
        . $APOS_COMMA_SPACE;
  }

  # purpose
  if ($self->purpose) {
    $option
        .= q{'purpose': '}
        . $self->string_entitise($self->purpose())
        . $APOS_COMMA_SPACE;
  }

  # required: is integer so unquoted
  if ($self->required) {
    $option
        .= q{'required': }
        . $self->value_boolise($self->required)
        . $COMMA_SPACE;
  }

  # multiple: is integer so unquoted
  if ($self->multiple) {
    $option
        .= q{'multiple': }
        . $self->value_boolise($self->multiple)
        . $COMMA_SPACE;
  }

  # type
  if ($self->type) {
    $option
        .= q{'type': '}
        . $self->string_entitise($self->type())
        . $APOS_COMMA_SPACE;
  }

  # values
  if ($self->_has_values) {
    $option .= q{'values': [ };
    foreach my $value ($self->values) {
      $option
          .= $SINGLE_QUOTE
          . $self->string_entitise($value)
          . $APOS_COMMA_SPACE;
    }
    $option .= '], ';
  }

  # default
  if ($self->default) {
    $option
        .= q{'default': '}
        . $self->string_entitise($self->default)
        . $APOS_COMMA_SPACE;
  }

  # notes
  if ($self->_has_notes) {
    $option .= q{'notes': [ };
    foreach my $note ($self->notes) {
      $option
          .= $SINGLE_QUOTE
          . $self->string_entitise($note)
          . $APOS_COMMA_SPACE;
    }
    $option .= '], ';    ## no critic (ProhibitDuplicateLiteral)
  }
  $option .= '}';

  # return option loader
  return $option;
}    # }}}1

1;

# POD    {{{1

__END__

=encoding utf-8

=head1 NAME

Dn::CommonBash::Function::Option - dncommon-bash library function option

=head1 VERSION

This documentation is for Dn::CommonBash::Function::Option version 5.30.

=head1 SYNOPSIS

  use Dn::CommonBash::Function::Option;

=head1 DESCRIPTION

Dn::CommonBash::Function::Option encapsulates a function option.

=head1 SUBROUTINES/METHODS

=head2 add_note($note)

=head3 Purpose

Add option parameter.

=head3 Paramaters

=over

=item $note

Note to be added to option. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of notes in option.

=head2 add_value($value)

=head3 Purpose

Add option parameter.

=head3 Paramaters

=over

=item $value

Value to be added to option. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Integer. Number of values in option.

=head2 default([$default])

=head3 Purpose

Get or set option 'default' attribute.

=head3 Parameters

=over

=item $default

Option 'default' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 display_option_screen()

=head3 Purpose

Provide formatted version of option for screen display.
Output is a list of strings -- one string per screen line.
Output strings are prepared by the C<vim_printify> method from
L<Role::Utils::Dn> and need to be printed to screen using the
C<vim_list_print> method from L<Role::Utils::Dn>.

This method is designed to be called by the C<display_function_screen> method
from L<Dn::CommonBash::Function>.

Format:

	 OPTION: -v [optional, multiple]
	    Use: To display more information
	   Note: Using multiple times gives further information

	 OPTION: -x "<String>" [required]
	    Use: To splinge the bar
	   Note: Use only in case of emergency
	   Note: See doctor if symptoms persist
	 Values: 'race', 'the', 'night'
	Default: 'race'

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of output display lines.

=head2 flag([$flag])

=head3 Purpose

Get or set option 'flag' attribute.

=head3 Parameters

=over

=item $flag

Option 'flag' value. Scalar string.

Optional. If provided the attribute is set to this value.
If not provided the current attribute value is returned.

=back

=head3 Prints

Nil.

=head3 Returns

Nil if parameter provided.

Current attribute value if no parameter provided.

=head2 multiple([$multiple])

=head3 Purpose

Get or set option 'multiple' attribute.

=head3 Parameters

=over

=item $multiple

Option 'multiple' value. Boolean value ('yes', 'true', 1, 'no', 'false', or 0).

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

Gets option notes.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of option notes.

=head2 purpose([$purpose])

=head3 Purpose

Get or set option 'purpose' attribute.

=head3 Parameters

=over

=item $purpose

Option 'purpose' value. Scalar string.

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

Get or set option 'required' attribute.

=head3 Parameters

=over

=item $required

Option 'required' value. Boolean value ('yes', 'true', 1, 'no', 'false', or 0).

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

Get or set option 'type' attribute.

=head3 Parameters

=over

=item $purpose

Option 'type' value. Must be one of: 'string', 'integer', 'number',
'boolean', 'path', 'date', 'time', or 'none'.

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

Gets option values.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of option values.

=head2 write_option_loader()

=head3 Purpose

Generate portion of vim 'let' command for loader.

Designed to be called by the C<write_function_loader> from
L<Dn::CommonBash::Function>.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head1 DIAGNOSTICS

This module emits no custom error messages.

=head1 CONFIGURATION AND ENVIRONMENT

This module has no configuration options or files, and has no
environmental variables.

=head1 INCOMPATIBILITIES

There are no know incompatibilities.

=head1 BUGS AND LIMITATIONS

There are no known bugs or limitations.

=head1 DEPENDENCIES

Const::Fast, Dn::CommonBash::Types, English, Moo, MooX::HandlesVia,
Role::Utils::Dn, Test::NeedsDisplay, Types::Standard, namespace::clean,
strictures, version.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
