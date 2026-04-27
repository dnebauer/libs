package Role::Utils::Dn::CommandResult;

# modules/constants    {{{1
use Moo;
use strictures 2;
use 5.038_001;
use version; our $VERSION = qv('0.8');
use namespace::clean;

use Const::Fast;
use MooX::HandlesVia;
use Types::Standard;

const my $TRUE     => 1;
const my $ARRAY    => 'Array';
const my $ELEMENTS => 'elements';
const my $COUNT    => 'count';      # }}}1

# attributes

# success    {{{1
has 'success' => (
  is            => 'ro',
  isa           => Types::Standard::Bool,
  required      => $TRUE,
  documentation => 'Whether command succeeded',
);

# error    {{{1
has 'error' => (
  is            => 'ro',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  documentation => 'Error message if command failed',
);

# has_full, full    {{{1
has 'full_output' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { full => $ELEMENTS, has_full => $COUNT, },
  documentation => 'Full output (stdout and stderr)',
);

# has_stdout, stdout    {{{1
has 'standard_out' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { stdout => $ELEMENTS, has_stdout => $COUNT, },
  documentation => 'Standard output',
);

# has_stderr, stderr    {{{1
has 'standard_err' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { stderr => $ELEMENTS, has_stderr => $COUNT, },
  documentation => 'Standard error',
);    # }}}

1;

# POD    {{{1

__END__

=head1 NAME

Role::Utils::Dn::CommandResult - returned by Role::Utils::Dn->shell_command()

=head1 SYNOPSIS

    with qw(Role::Utils::Dn);

    my $cmd = [ ... ];
    my $result = $self->shell_command($cmd);
    if ( $result->success ) {
        ...
    }

=head1 VERSION

This documentation refers to Role::Utils::Dn::CommandResult version 0.8.

=head1 DESCRIPTION

Captures results of running a command with the C<Role::Utils::Dn> method
C<shell_command>.

=head1 SUBROUTINES/METHODS

None.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 success

Whether command succeeded. Scalar boolean.

=head3 error

Error message. Scalar string. (Undef if command succeeded.)

=head3 full

Full output, includes standard output and standard error. List of strings with
no trailing newlines.

=head3 has_full

Whether there is any output. Scalar boolean (actually the number of output
lines).

=head3 stdout

Output sent to standard out. List of strings with no trailing newlines.

=head3 has_stdout

Whether there was output to standard out. Scalar boolean (actually the number
of lines).

=head3 stderr

Standard error. List of strings with no trailing newlines.

=head3 has_stderr

Whether there was output to standard error. Scalar boolean (actually the number
of lines).

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 DIAGNOSTICS

This module emits no custom warning or error messages.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None reported.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, Moo, MooX::HandlesVia, namespace::clean, strictures,
Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

L<David Nebauer|mailto:davidnebauer@hotkey.net.au>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2021 L<David Nebauer|mailto:davidnebauer@hotkey.net.au>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# }}}1

# vim:fdm=marker
