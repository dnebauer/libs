package Mail::Dir::Monitor::Dir;

# use modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean;
use Const::Fast;
use Cwd;
use English;
use File::Util;
use MooX::HandlesVia;
use Types::Path::Tiny;
use Types::Standard;

with qw(Mail::Dir::Monitor::Comms);

const my $TRUE  => 1;
const my $FALSE => 0;
const my $INFO  => 'info';
const my $WARN  => 'warn';

# do not line- or block-buffer, but flush after every write to
# output channel, pipe or socket (see 'perldoc perlvar')
local $OUTPUT_AUTOFLUSH = $TRUE;    # }}}1

# attributes (public, required)

# dirpath    {{{1
has 'dirpath' => (
  is       => 'ro',
  isa      => Types::Path::Tiny::AbsPath,
  coerce   => Types::Path::Tiny::AbsPath->coercion,
  required => $TRUE,
  doc      => 'Directory path',
);

# name    {{{1
has 'name' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Human-readable label for directory',
);

# user    {{{1
has 'user' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Name of user that own mail queue',
);    # }}}1

# attributes (public, optional)

# mail    {{{1
has 'mail' => (
  is       => 'ro',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Whether to report blocked mail by user email',
);

# mask    {{{1
has 'mask' => (
  is       => 'ro',
  isa      => Types::Standard::RegexpRef,
  required => $FALSE,
  default  => sub {qr/\A.*\Z/xsm},
  doc      => 'Regexp for files to match; leave empty if matching all',
);

# write    {{{1
has 'write' => (
  is       => 'ro',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Whether to report blocked mail by user message',
);

# attributes (private)

# _exists    {{{1
has '_exists' => (
  is      => 'rw',
  isa     => Types::Standard::Bool,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    return -d $self->dirpath;
  },
  doc => 'Whether directory exists',
);

# [_add|_has|_clear]_curr_files    {{{1
has '_curr_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Types::Path::Tiny::File'],
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _curr_files       => 'elements',
    _add_curr_files   => 'push',
    _has_curr_files   => 'count',
    _clear_curr_files => 'clear',
  },
  doc => 'Files found on current check',
);

# [_add|_has|_clear]_prev_files, has_prev_file(name)    {{{1
has '_prev_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf [
      'Types::Path::Tiny::File',    ## no critic (ProhibitDuplicateLiteral)
    ],
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _add_prev_files   => 'push',
    _has_prev_file    => 'first',
    _has_prev_files   => 'count',
    _clear_prev_files => 'clear',    ## no critic (ProhibitDuplicateLiteral)
  },
  doc => 'Files found on previous check',
);                                   # }}}1

# methods

# check()    {{{1
#
# does:   compare current directory contents with previous contents
# params: nil
# prints: log message and notification if previous file still present
# return: n/a, dies on failure
sub check ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # skip if directory no longer exists
  return if not $self->_dir_ok;

  # get current files
  $self->_reread_dir();

  # look for stuck files, and report if any found
  my @stuck = $self->_stuck_files;
  if (@stuck) { $self->_report_stuck([@stuck]); }

  return;
}

# _dir_files()    {{{1
#
# does:   gets list of matching files in mail directory
#
# params: nil
# prints: nil
# return: list of file names
sub _dir_files ($self) {    ## no critic (RequireInterpolationOfMetachars)

  my $dirpath = $self->dirpath;
  my $options = {
    files_match => $self->mask,
    files_only  => $TRUE,
    recurse     => $FALSE,
  };

  return File::Util->new()->list_dir($dirpath => $options);
}

# _dir_ok()    {{{1
#
# does:   check directory still exists, and notify user if
#         directory status changes
#
# params: nil
# prints: nil
# return: boolean, whether dir exists
sub _dir_ok ($self) {    ## no critic (RequireInterpolationOfMetachars)

  my $dir     = $self->dirpath;
  my $existed = $self->_exists;
  my $exists  = -d $dir;

  # notify if status has changed
  if ($existed and (not $exists)) {
    $self->write_log("Directory has been deleted! ($dir)", $WARN);
  }
  if ((not $existed) and $exists) {
    $self->write_log("Directory has been recreated! ($dir)", $INFO);
  }

  $self->_exists($exists);    # update to current status

  return $exists;
}

# _report_stuck($files)    {{{1
#
# does:   find files in both current and previous file lists
# params: $files - arrayref of files 'stuck' in mail queue directory
# prints: send message to system log and desktop notification
# return: n/a
sub _report_stuck ($self, $files_ref)
{    ## no critic (RequireInterpolationOfMetachars)

  my ($name, $dir, $user) = ($self->name, $self->dirpath, $self->user);
  my $title = 'Blocked mail queue directory';

  # log message
  my @files    = @{$files_ref};
  my $count    = @files;
  my $msg_base = sprintf "$name ($dir) has %d stuck %s: ", $count,
      ($count == 1) ? 'file' : 'files';
  my $msg = "$title: $msg_base";
  $msg .= join q{, }, @files;
  $self->write_log($msg, $WARN);

  # notify user by mail and, if logged in, direct message
  $msg = join "\n", $msg_base, map {" - $_"} @files;
  if ($self->mail)  { $self->mail_user($user, $title, $msg); }
  if ($self->write) { $self->write_user($user, $title, $msg); }

  return;
}

# _reread_dir()    {{{1
#
# does:   re-read directory contents
# params: nil
# prints: nil
# return: n/a, dies on failure
sub _reread_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # cycle (old) current list to previous list
  $self->_clear_prev_files;
  $self->_add_prev_files($self->_curr_files);
  $self->_clear_curr_files;

  # get current files
  $self->_add_curr_files($self->_dir_files);

  return;
}

# _stuck_files()    {{{1
#
# does:   find files in both current and previous file lists
# params: nil
# prints: nil, except error messages
# return: list of file names
sub _stuck_files ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # no need to compare if previously or currently empty
  return () if not $self->_has_prev_files;
  return () if not $self->_has_curr_files;

  # okay, now compare lists
  return grep {
    $self->_has_prev_file(sub {/\A$_\Z/xsm})
  } $self->_curr_files;
}                             # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Mail::Dir::Monitor::Dir - model a mail queue directory

=head1 VERSION

This documentation is for Mail::Dir::Monitor::Dir version 0.5.

=head1 SYNOPSIS

    has '_dirs_list' => (
      is  => 'rw',
      isa => Types::Standard::ArrayRef [
        Types::Standard::InstanceOf ['Mail::Dir::Monitor::Dir'],
      ],
      default     => sub { [] },
      handles_via => 'Array',
      handles     => { _dirs => 'elements' },
      doc         => 'Array of mail queue directories',
    );

    # ...

    while ($TRUE) {

      $loop++;

      if ($loop > $delay) {
        for my $dir ($self->_dirs) { $dir->check; }
        $loop = 0;
      }
      sleep 1;
    }

=head1 DESCRIPTION

A helper module for L<Mail::Dir::Monitor> that models a mail queue directory.
See L<Mail::Dir::Monitor/DESCRIPTION> for more details.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 dir

The path to the directory.

String. Required.

=head3 mail

Whether to notify user of blocked email messages by sending an email to their
local user account using the C<mail> utility that is standard on *nix systems.
Will have no effect if no C<mail> executable is available.

Note that most systems are not set up by default to notify a user when local
user mail is received -- local user mail is handled differently to email
received from an ISP. The only notification is that users receive a message in
their terminal the next time they log into it. Users who rely on a graphical
user interface and do not use terminals will never see any notifications
regarding local user mail.

Boolean. Optional. Default: false.

=head3 mask

By default this script monitors all files in a mail queue directory. Sometimes,
however, it may be preferable to monitor only a particular type of file. For
example, in mail configurations including msmtp each email sent can result in
two files being created in the mail queue directory: a F<.msmtp> file and a
F<.mail> file. Since notification messages include a list of "stuck" files, to
minimise message size it may be desirable to monitor only one of those two file
types.

This is done by specifying a regular expression that matches the file type to
be monitored. Only the expression itself need by specified. For example, to
specify F<.msmtp> files you may use the value "[.]msmtp\Z". This will be
converted internally into the regular expression

    qr/[.]msmtp\Z/xsm

String. Optional. Default: ".*".

=head3 name

A human readable name for the directory intended to be used in user feedback.
The name can consist of multiple words. It should fit naturally into the
following sentence instead of NAME: "The NAME has stuck email files."

String. Required.

=head3 user

User login name of the owner of the mail queue. This is used for sending direct
feedback via local mail and terminal messages, so if there is any confusion
over the ownership of a mail queue, choose the user to whom notifications
should be sent. This value is required even if both C<mail> and C<write> are to
be left disabled.

Boolean. Optional. Default: false.

=head3 write

Whether to notify user of blocked email messages by sending a message directly
to their terminal using the C<write> utility that is standard on *nix systems.
Will have no effect if no C<write> executable is available.

Individual users can configure their terminals to not receive C<write>
messages, though on most system the default for users is to allow display of
such messages. See the manpage for C<write> for more details.

There are a number of circumstances in which it may be inadvisable to utilise
this method of notification:

=over

=item *

Users who rely on a graphical user environment and do not use terminals.

=item *

Users who primarily use terminals for console editors, such as vim, as the
messages sent by write will disrupt the editor display.

=item *

Users who routinely use multiple terminals and/or terminal multiplexers, as the
message will be sent to only one terminal and that terminal may not be visible
to the user at the time the message is sent.

=back

Boolean. Optional. Default: false.

=head2 Configuration directory

None.

=head2 Environment variables

None.

=head1 SUBROUTINES/METHODS

=head2 check()

=head3 Purpose

Compare current directory contents with previous contents.

=head3 Parameters

None.

=head3 Prints

Log message and notification if previous file(s) still present.

=head3 Returns

Void. Dies on failure.

=head1 DIAGNOSTICS

These messages are written to the log.

=head2 Blocked mail queue directory: NAME (DIR) has NUM stuck files: file1, ...

Occurs if a mail queue directory contains the same file(s) in consecutive
content checks.

=head2 Directory has been deleted! (DIR)

Occurs if a mail queue directory is deleted between checks. Warning.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, Cwd, English, File::Util, Moo, MooX::HandlesVia, namespace::clean,
strictures, Types::Path::Tiny, Types::Standard, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
