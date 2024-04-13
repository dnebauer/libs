package Role::Utils::Dn::CommandResult;

use Moo;
use strictures 2;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;

use Const::Fast;
use MooX::HandlesVia;
use Types::Standard;

const my $TRUE     => 1;
const my $ARRAY    => 'Array';
const my $ELEMENTS => 'elements';
const my $COUNT    => 'count';

has 'success' => (
  is            => 'ro',
  isa           => Types::Standard::Bool,
  required      => $TRUE,
  documentation => 'Whether command succeeded',
);

has 'error' => (
  is            => 'ro',
  isa           => Types::Standard::Str,
  required      => $TRUE,
  documentation => 'Error message if command failed',
);

has 'full_output' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { full => $ELEMENTS, has_full => $COUNT, },
  documentation => 'Full output (stdout and stderr)',
);

has 'standard_out' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { stdout => $ELEMENTS, has_stdout => $COUNT, },
  documentation => 'Standard output',
);

has 'standard_err' => (
  is            => 'ro',
  isa           => Types::Standard::ArrayRef [Types::Standard::Str],
  required      => $TRUE,
  handles_via   => $ARRAY,
  handles       => { stderr => $ELEMENTS, has_stderr => $COUNT, },
  documentation => 'Standard error',
);

1;

## no critic (RequirePodSections)

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

=head1 DESCRIPTION

Captures results of running a command with the C<Role::Utils::Dn> method
C<shell_command>.

=head1 METHODS

=head2 success

Whether command succeeded. Scalar boolean.

=head2 error

Error message. Scalar string. (Undef if command succeeded.)

=head2 full

Full output, includes standard output and standard error. List of strings with
no trailing newlines.

=head2 has_full

Whether there is any output. Scalar boolean (actually the number of output
lines).

=head2 stdout

Output sent to standard out. List of strings with no trailing newlines.

=head2 has_stdout

Whether there was output to standard out. Scalar boolean (actually the number
of lines).

=head2 stderr

Standard error. List of strings with no trailing newlines.

=head2 has_stderr

Whether there was output to standard error. Scalar boolean (actually the number
of lines).

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, Moo, MooX::HandlesVia, namespace::clean, strictures,
Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2021 David Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
