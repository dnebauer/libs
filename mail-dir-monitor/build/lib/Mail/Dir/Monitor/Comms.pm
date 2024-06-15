package Mail::Dir::Monitor::Comms;

# use modules    # {{{1
use Moo::Role;
use strictures 2;
use 5.006;
use 5.036_001;
use version; our $VERSION = qv('0.1');
use namespace::clean;
use Carp qw(confess);
use Const::Fast;
use Email::Sender::Simple;
use Email::Simple;
use English;
use File::Which;
use IPC::Run;
use Logger::Syslog;
use Sys::Hostname::Long;

const my $FALSE   => 0;
const my $HOST    => Sys::Hostname::Long::hostname_long();
const my $SPACE   => q{ };
const my $TIMEOUT => 10;
const my $TRUE    => 1;
const my $WARN    => 'warn';

# do not line- or block-buffer, but flush after every write to
# output channel, pipe or socket (see 'perldoc perlvar')
local $OUTPUT_AUTOFLUSH = $TRUE;    # }}}1

# methods (public)

# write_log($message[, $type])    {{{1
#
# does:   write message to system logs
# params: $message - message content [required]
#         $type    - message type ['info'|'warn'] [required]
# prints: nil
# return: nil
# note:   not all message types appear in all system logs -- on debian,
#         for example, /var/log/messages records only notice and warning
#         log messages while /var/log/syslog records all log messages
sub write_log ($self, $message, $type)
{    ## no critic (RequireInterpolationOfMetachars)

  $type =~ s/(.*)/\L$1/gxsm;    # lowercase

  ## no critic (ProhibitDuplicateLiteral)
  if    ($type eq 'info') { Logger::Syslog::notice($message) }
  elsif ($type eq 'warn') { Logger::Syslog::warning($message) }
  else                    { confess "Invalid type '$type'" }
  ## use critic

  return;
}

# mail_user($user, $title, $message)    {{{1
#
# does:   mail user a message
# params: $user    - name of user to notify
#         $title   - notification title [required]
#         $message - notification content [required]
# prints: nil
# return: nil
sub mail_user ($self, $user, $title, $message)
{    ## no critic (RequireInterpolationOfMetachars)

  # check for mail utility
  return if not File::Which::which('mail');

  # assemble email
  my $email = Email::Simple->create(
    header => [
      To      => "${user}\@${HOST}",
      From    => "root\@${HOST}",
      Subject => $title,
    ],
    body => $message,
  );

  # send email
  # - appears to be no way to detect send failure for local mail
  Email::Sender::Simple->send($email);

  return;
}

# write_user($user, $title, $message)    {{{1
#
# does:   write user a message
# params: $user    - name of user to notify [required]
#         $title   - notification title [required]
#         $message - notification content [required]
# prints: title and message in target user's terminal
# return: nil
sub write_user ($self, $user, $title, $message)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)

  # check for write utility
  return if not File::Which::which('write');

  # user has to be active, i.e., logged in
  return if not $self->_active_user($user);

  # send message
  my $in  = "$title\n$message";
  my @cmd = ('write', $user);     ## no critic (ProhibitDuplicateLiteral)
  my ($timeout, $out, $err) = (IPC::Run::timeout($TIMEOUT));
  if (not IPC::Run::run([@cmd], \$in, \$out, \$err, $timeout)) {
    my $msg = sprintf q{Could not run '%s': %s}, join($SPACE, @cmd),
        "$OS_ERROR";
    $self->write_log($msg, $WARN);
    return;
  }

  if ($err) { $self->write_log(qq{Error running 'write': $err}, $WARN); }

  return;
}    # }}}1

# methods (private)

# _active_user($user)   {{{1
#
# does:   determine whether user is active, i.e., logged in
# params: $user - user login name
# prints: nil
# return: bool - whether user logged in
sub _active_user ($self, $user)
{    ## no critic (RequireInterpolationOfMetachars)
  my @matches = grep {/\A$user\Z/xsm} $self->_active_users;
  return @matches ? $TRUE : $FALSE;
}

# _active_users()   {{{1
#
# does:   gets list of active users with 'who' command
# params: nil
# prints: nil
# return: list of users currently logged in
sub _active_users ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # run 'who' and capture output
  my @cmd = ('who');
  my ($timeout, $in, $out, $err) = (IPC::Run::timeout($TIMEOUT));
  if (not IPC::Run::run([@cmd], \$in, \$out, \$err, $timeout)) {
    my $msg = sprintf
        q{Could not run '%s': %s},    ## no critic (ProhibitDuplicateLiteral)
        join($SPACE, @cmd), "$OS_ERROR";
    $self->write_log($msg, $WARN);
    return $FALSE;
  }
  if ($err) { $self->write_log(qq{Error running 'who': $err}, $WARN); }

  # extract users from output
  my @lines = split /\n/xsm, $out;
  my %users;

  foreach my $line (@lines) {
    my ($username) = split $SPACE, $line;
    $users{$username}++;
  }

  my @sorted_users = sort keys %users;
  return @sorted_users;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Mail::Dir::Monitor::Comms - helper role providing methods

=head1 VERSION

This documentation is for Mail::Dir::Monitor::Comms version 0.4.

=head1 SYNOPSIS

    with (Mail::Dir::Monitor::Comms);

    $self->write_log("Directory has been deleted! ($dir)", $WARN);

=head1 DESCRIPTION

This is a helper module for L<Mail::Dir::Module> and
L<Mail::Dir::Monitor::Dir>. It provides methods used by both modules.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration files

None.

=head2 Environment variables

None.

=head1 SUBROUTINES/METHODS

=head2 write_log($message[, $type])

=head3 Purpose

Write a message to system logs.

Not all message types appear in all system logs. On debian systems, for
example, F</var/log/messages> records only notice and warning log messages
while F</var/log/syslog> records all log messages.

=head3 Parameters

=over

=item $message

Message content. Scalar string. Required.

=item $type

Message type. Scalar string. Valid values: 'info', 'warn'. Required.

=back

=head3 Prints

Nothing.

=head3 Returns

Void.

=head2 mail_user($user, $title, $message)

=head3 Purpose

Mail a user a message.

=head3 Parameters

=over

=item $user

User name of user to notify. Scalar string. Required.

=item $title

Notification title. Scalar string. Required.

=item $message

Notification content. Scalar string. Required.

=back

=head3 Prints

Nothing.

=head3 Returns

Void.

=head2 write_user($user, $title, $message)

=head3 Purpose

Write user a message.

=head3 Parameters

=over

=item $user

User name of user to notify. Scalar string. Required.

=item $title

Notification title. Scalar string. Required.

=item $message

Notification content. Scalar string. Required.

=back

=head3 Prints

Title and message in target user's terminal.

=head3 Returns

Void.

=head1 DIAGNOSTICS

=head2 Messages written to terminal

=head3 Invalid type 'TYPE'

Attempt to write a log message of a type other then 'info' or 'warn'. Fatal.

=head2 Message written to log

=head3 Could not run 'CMD': ERROR

An attempt to run a system command resulted in a system error. Warning.

=head3 Error running 'who': ERROR

=head3 Error running 'write': ERROR

A system error occurred when attempting to run one of these commands. Warning.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Email::Sender::Simple, Email::Simple, English, File::Which,
IPC::Run, Logger::Syslog, Moo::Role, namespace::clean, strictures,
Sys::Hostname::Long, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
