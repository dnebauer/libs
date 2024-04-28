package Dn::InteractiveIO;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.2');
use namespace::clean;

use Carp qw(croak);
use Const::Fast;
use IO::Interactive;
use IO::Prompter;
use Term::ReadKey;

const my $TRUE  => 1;
const my $FALSE => 0;

# }}}1

# methods

# print($msg)    {{{1
#
# does:   display ('print') message to stdout if connected to terminal
# params: $msg - message [scalar string, optional]
# prints: message to stdout
# return: n/a, dies on failure
sub print ($self, $msg)
{    ## no critic (RequireInterpolationOfMetachars ProhibitBuiltinHomonyms)
  return if not $msg;
  print {IO::Interactive::interactive} $msg or croak;
  return;
}

# say($msg)    {{{1
#
# does:   display ('say') message to stdout if connected to terminal
# params: $msg - message [scalar string, optional]
# prints: message to stdout
# return: n/a, dies on failure
sub say ($self, $msg)
{ ## no critic (RequireInterpolationOfMetachars ProhibitBuiltinHomonyms ProhibitDuplicateLiteral)
  return if not $msg;
  say {IO::Interactive::interactive} $msg or croak;
  return;
}

# warn($msg)    {{{1
#
# does:   display ('say') message to stderr if connected to terminal
# params: $msg - message [scalar string, optional]
# prints: message to stderr
# return: n/a, dies on failure
sub warn ($self, $msg)
{ ## no critic (RequireInterpolationOfMetachars ProhibitBuiltinHomonyms ProhibitDuplicateLiteral)
  return if not $msg;
  say { IO::Interactive::interactive(*STDERR) } $msg or croak;
  return;
}

# die($msg)    {{{1
#
# does:   display ('say') message to stderr if connected to terminal
#         and exit with failure exit status
# params: $msg - message [scalar string, optional]
# prints: message to stderr
# return: n/a, dies on exit
sub die ($self, $msg)
{ ## no critic (RequireInterpolationOfMetachars ProhibitBuiltinHomonyms ProhibitDuplicateLiteral)
  if ($msg) { $self->warn($msg); }
  exit 1;
}

# interactive()    {{{1
#
# does:   determine whether connected to terminal, i.e., is interactive
# params: nil
# prints: error message on failure
# return: boolean
sub interactive ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return IO::Interactive::is_interactive;
}

# confirm($question, $default)    {{{1
#
# does:   user answers a yes-or-no question if connected to terminal
# params: $question - question to answer
#                     [scalar string, optional, default='Proceed?']
#         $default  - return value if non-interactive
#                     [scalar boolean, optional, default=true]
# prints: question and answer if interactive
# return: boolean
sub confirm ($self, $question = 'Proceed?', $default = $TRUE)
{    ## no critic (RequireInterpolationOfMetachars)
  my $result = $default;
  if (IO::Interactive::is_interactive) {
    my @opts = ('-yesno', '-single', '-echo' => 'Yes/No');
    $result = IO::Prompter::prompt($question, @opts);
  }

  return $result;
}

# input($prompt, $default)    {{{1
#
# does:   user enter a value if connected to terminal
# params: $prompt  - user prompt
#                    [scalar string, optional, default='Enter value:']
#         $default - return value if non-interactive
#                    [scalar boolean, optional, default=true]
# prints: prompt and input if interactive
# return: scalar boolean
# note:   empty input is allowed
sub input ($self, $prompt = 'Enter value:', $default = $TRUE)
{    ## no critic (RequireInterpolationOfMetachars)
  my $input = $default;
  if (IO::Interactive::is_interactive) {

    # prompt() returns Contextual::Return object
    # force scalar context with '.=' concatenation
    my $value = scalar IO::Prompter::prompt($prompt);
    $input = $value;
  }

  return $input;
}

# input_required($prompt, $default)    {{{1
#
# does:   user enter a value if connected to terminal
#         input is required
# params: $prompt  - user prompt
#                    [scalar string, optional, default='Enter value:']
#         $default - return value if non-interactive
#                    [scalar boolean, optional, default=true]
# prints: prompt and input if interactive
# return: scalar boolean
# note:   empty input is not accepted
sub input_required ($self, $prompt = 'Enter value:', $default = $TRUE)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)
  my $input = $default;
  if (IO::Interactive::is_interactive) {
    while ($TRUE) {

      # prompt() returns Contextual::Return object
      # force scalar context with '.=' concatenation
      $input = q{};
      $input .= IO::Prompter::prompt($prompt);
      last if $input;
      $self->warn('Input is required - try again');
    }
  }

  return $input;
}    # }}}1

1;

# POD    {{{1
__END__

=head1 NAME

Dn::InteractiveIO - interactive methods

=head1 VERSION

This documentation applies to module Dn::InteractiveIO version 0.3.

=head1 SYNOPSIS

    use Dn::InteractiveIO;
    my $io = Dn::InteractiveIO->new;

    # echo to stdout like 'print' and 'say' commands
    $io->print("This is sent to stdout\n");
    $io->say('This is also sent to stdout');

    # echo to stderr like 'say'
    $io->warn('This is sent to stderr');

    # can test whether connected to terminal
    if ( $io->interactive ) { $self->do_something_in_terminal; }

    # can get user to answer yes/no question
    if ( $io->confirm('Question?') ) { $self->do_stuff; }

    # ask user for input, and can prohibit empty input
    my $value = $io->input;   # empty input allowed
    my $required_value = $io->input_required;    # not allowed

    # echo message to stderr like 'say' then exit with error status
    $io->die('Also stderr, then dies');

=head1 DESCRIPTION

Displays interactive output, i.e., displays only when connected to a terminal.

=head1 SUBROUTINES/METHODS

=head2 print($msg)

Sends message to stdout using C<print> command if connected to a terminal,
i.e., environment is interactive.

=head3 Parameters

=over

=item $msg

Message to display. Scalar string. Optional.

=back

=head2 say($msg)

Sends message to stdout using C<say> command if connected to a terminal,
i.e., environment is interactive.

=head3 Parameters

=over

=item $msg

Message to display. Scalar string. Optional.

=back

=head2 warn($msg)

Sends message to stderr using C<say> command if connected to a terminal,
i.e., environment is interactive.

=head3 Parameters

=over

=item $msg

Message to display. Scalar string. Optional.

=back

=head2 die($msg)

Sends message to stderr using C<say> command if connected to a terminal,
i.e., environment is interactive. Then exits script with error code (1).

=head3 Parameters

=over

=item $msg

Message to display. Scalar string. Optional.

=back

=head2 interactive()

Determine whether interactive, i.e., connected to terminal.

=head3 Parameters

Nil.

=head3 Returns

Boolean.

=head2 confirm($question, $default)

User answers question in affirmative or negative.

=head3 Parameters

=over

=item $question

Question to display. Requires question mark. Scalar string. Optional.
Default: 'Proceed?'

=item $default

Value to return if not connected to terminal, i.e., not interactive.
Scalar boolean. Optional. Default: true.

=back

=head3 Returns

Boolean.

=head2 input($prompt, $default)

User enters a value. An empty string, where the user simply presses the
Enter key, is allowed.

=head3 Parameters

=over

=item $prompt

User prompt. Does not add colon automatically. Scalar string. Optional.
Default: 'Enter value:'

=item $default

Value to return if not connected to terminal, i.e., not interactive.
Scalar string. Optional. Default: undef.

=back

=head3 Returns

Scalar string.

=head2 input_required($prompt, $default)

User enters a value. Note that empty input, where the user simply presses the
Enter key, is not allowed. If the user enter an empty string an error message
occurs and the user is presented again with the input prompt.

=head3 Parameters

=over

=item $prompt

User prompt. Does not add colon automatically. Scalar string. Optional.
Default: 'Enter value:'

=item $default

Value to return if not connected to terminal, i.e., not interactive.
Scalar string. Optional. Default: undef.

=back

=head3 Returns

Scalar string. Note that an empty string is not permitted.

=head1 DIAGNOSTICS

=head2 Input is required - try again

This warning is emitted if the user fails to enter input when input is
required.

=head1 CONFIGURATION AND ENVIRONMENT

This module has no configuration files or environmental variables.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, IO::Interactive, IO::Prompter, Moo, namespace::clean, strictures,
Term::ReadKey, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim:fdm=marker
