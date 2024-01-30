package Dn::Common::CommandResult;

use Moo;
use strictures 2;
use 5.014_002;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use MooX::HandlesVia;
use Readonly;
use Types::Standard;

Readonly my $TRUE => 1;

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
    handles_via   => 'Array',
    handles       => { full => 'elements', has_full => 'count', },
    documentation => 'Full output (stdout and stderr)',
);

has 'standard_out' => (
    is            => 'ro',
    isa           => Types::Standard::ArrayRef [Types::Standard::Str],
    required      => $TRUE,
    handles_via   => 'Array',
    handles       => { stdout => 'elements', has_stdout => 'count', },
    documentation => 'Standard output',
);

has 'standard_err' => (
    is            => 'ro',
    isa           => Types::Standard::ArrayRef [Types::Standard::Str],
    required      => $TRUE,
    handles_via   => 'Array',
    handles       => { stderr => 'elements', has_stderr => 'count', },
    documentation => 'Standard error',
);

1;

__END__

=head1 NAME

Dn::Common::CommandResult - returned by Dn::Common->capture_command_output

=head1 SYNOPSIS

    use Dn::Common;
    use Dn::Common::CommandResult;

    my $cp = Dn::Common->new();
    my $cmd = [ ... ];
    my $result = $cp->capture_command_output($cmd);
    if ( $result->success ) {
        ...
    }

=head1 DESCRIPTION

Captures results of running a command with the C<Dn::Command> method C<capture_command_output>.

=head1 METHODS

=head2 success

Whether command succeeded. Scalar boolean.

=head2 error

Error message. Scalar string. (Undef if command succeeded.)

=head2 full

Full output, includes standard output and standard error. List of strings with no trailing newlines.

=head2 has_full

Whether there is any output. Scalar boolean (actually the number of output lines).

=head2 stdout

Output sent to standard out. List of strings with no trailing newlines.

=head2 has_stdout

Whether there was output to standard out. Scalar boolean (actually the number of lines).

=head2 stderr

Standard error. List of strings with no trailing newlines.

=head2 has_stderr

Whether there was output to standard error. Scalar boolean (actually the number of lines).

=head1 DEPENDENCIES

=head2 Perl modules

Moo, MooX::HandlesVia, namespace::clean, Readonly, strictures, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
