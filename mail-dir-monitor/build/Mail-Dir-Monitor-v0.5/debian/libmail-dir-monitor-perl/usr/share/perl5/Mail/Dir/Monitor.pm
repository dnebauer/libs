package Mail::Dir::Monitor;

# use modules    # {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(confess);
use Config::Any;
use Const::Fast;
use Cwd;
use English;
use File::ConfigDir;
use File::Spec;
use File::Util;
use IO::File;
use Mail::Dir::Monitor::Dir;
use MooX::HandlesVia;
use MooX::Options;
use POSIX qw(:signal_h);
use Perl6::Slurp;
use Types::Standard;
use User::pwent qw();    # prevent core overrides as per manpage

with qw(Mail::Dir::Monitor::Comms);

const my @ARGS        => @ARGV;
const my $DEFAULT_UID => 1_000;
const my $FALSE       => 0;
const my $INFO        => 'info';
const my $SCRIPT => (-l __FILE__)
    ? Cwd::abs_path(readlink __FILE__)
    : Cwd::abs_path(__FILE__);
const my $TRUE => 1;
const my $WARN => 'warn';

# do not line- or block-buffer, but flush after every write to
# output channel, pipe or socket (see 'perldoc perlvar')
local $OUTPUT_AUTOFLUSH = $TRUE;    # }}}1

# options

# conf_dir (-c)    {{{1
option 'conf_dir' => (
  is    => 'ro',
  short => 'c',
  doc   => 'Print the configuration directory and exit',
);

# delay    (-d)    {{{1
option 'delay' => (
  is      => 'ro',
  short   => 'd',
  format  => 'i',
  default => 300,
  doc     => 'Delay (secs) between checks (default: 300 [5 mins])',
);    # }}}1

# attributes

# _min_uid    {{{1
has '_min_uid' => (
  is      => 'ro',
  isa     => Types::Standard::Int,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;

    # default to 1,000 if no login definitions file
    my $default = $DEFAULT_UID;
    my $file    = '/etc/login.defs';
    my $fh      = IO::File->new($file, 'r') or return $default;

    # set to value in login definitions file, if defined
    my @content = Perl6::Slurp::slurp $fh, { chomp => $TRUE };
    $fh->close;
    my $min_uid = $default;
    for my $line (@content) {
      if ($line =~ /\AUID_MIN/xsm) {
        ($min_uid = $line) =~ s/UID_MIN.*[\s+|=](\d+).*/$1/xsm;
      }
    }

    return $min_uid;
  },
  doc => 'Minimum UID for users',
);

# _restart    {{{1
has '_restart' => (
  is       => 'rw',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Flag for hangup interrupt (SIGHUP)',
);

# _terminate    {{{1
has '_terminate' => (
  is       => 'rw',
  isa      => Types::Standard::Bool,
  required => $FALSE,
  default  => $FALSE,
  doc      => 'Flag for terminate interrupt (SIGTERM)',
);

# _valid_user    {{{1
has '_user_list' => (
  is      => 'ro',
  isa     => Types::Standard::ArrayRef [Types::Standard::Str],
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my @users;
    my $min_uid = $self->_min_uid;
    while (defined(my $user = User::pwent::getpwent)) {
      if ($user->uid >= $min_uid) {
        push @users, $user->name;
      }
    }
    my @sort_users = sort @users;
    return [@sort_users];
  },
  handles_via => 'Array',
  handles     => { _has_user => 'first', },
  doc         => 'Array of users',
);

sub _valid_user ($self, $user)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitDuplicateLiteral)
  return $self->_has_user(sub {/\A$user\Z/xsm});
}

# _add_dir, _has_dirs, _dirs    {{{1
has '_dirs_list' => (
  is  => 'rw',
  isa => Types::Standard::ArrayRef [
    Types::Standard::InstanceOf ['Mail::Dir::Monitor::Dir'],
  ],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _dirs     => 'elements',
    _add_dir  => 'push',
    _has_dirs => 'count',
  },
  doc => 'Array of mail queue directories',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # if requested, show config directory and exit
  if ($self->conf_dir) {
    printf "%s\n", $self->_conf_dir;
    return;
  }

  # discover mail queue directories, and return if none
  return if not $self->_discover_dirs;

  # continual loop checking mail queue directories
  $self->_main_loop;

  return;
}

# _conf_dir()    {{{1
#
# does:   determine configuration directory
#
# params: nil
# prints: nil
# return: string, configuration directory path
sub _conf_dir ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $sys_cfg_dir = (File::ConfigDir::system_cfg_dir())[0];
  return File::Spec->catdir($sys_cfg_dir, 'mail-dir-monitor.d');
}

# _discover_dirs()    {{{1
#
# does:   discover mail queue directories that have been configured
#
# params: nil
# prints: nil
# return: boolean, whether any directories recovered
sub _discover_dirs ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # locate config dir ('/etc/mail-dir-monitor.d')
  my $config_dir = $self->_conf_dir;
  $self->write_log("Configuration directory is: $config_dir", $INFO);
  if (not -d $config_dir) {
    $self->write_log('Cannot locate configuration directory', $WARN);
    return $FALSE;
  }

  # get list of config files
  my $opts;
  $opts = {
    files_only      => $TRUE,
    onfail          => $WARN,
    flatten_to_hash => $TRUE,
  };
  my @conf_files = File::Util->new()->list_dir($config_dir => $opts);
  if (not @conf_files) {
    $self->write_log('No files in configuration directory', $INFO);
    return $FALSE;
  }
  my @conf_fps = map { File::Spec->catfile($config_dir, $_) } @conf_files;

  # read config files
  $opts = { files => [@conf_fps], use_ext => $FALSE };
  my $cfg = Config::Any->load_files($opts);

  # extract mail directories to monitor
  for my $file_item (@{$cfg}) {
    my ($file, $file_confs) = %{$file_item};
    my ($dir, $name, $user, $msg);
    my ($mask) = (qr/\A.*\Z/xsm);
    my ($mail, $write) = ($FALSE, $FALSE);
    for my $key (keys %{$file_confs}) {
      ## no critic (ProhibitDuplicateLiteral, ProhibitCascadingIfElse)
      if    ($key eq 'dir')   { $dir   = $file_confs->{'dir'}; }
      elsif ($key eq 'name')  { $name  = $file_confs->{'name'}; }
      elsif ($key eq 'mail')  { $mail  = $file_confs->{'mail'}; }
      elsif ($key eq 'user')  { $user  = $file_confs->{'user'}; }
      elsif ($key eq 'write') { $write = $file_confs->{'write'}; }
      elsif ($key eq 'mask') {
        my $mask_str = $file_confs->{'mask'};
        $mask = qr/$mask_str/xsm;
      }
      else {
        $msg = "Ignoring key '$key' in config file $file";
        $self->write_log($msg, $INFO);
      }
      ## use critic
    }

    # abort processing of this file if invalid user
    if ($user and not $self->_valid_user($user)) {
      $msg = "Ignoring config file $file: invalid user '$user'";
      $self->write_log($msg, $WARN);
      next;    # abort this loop
    }

    # add directory if all required values provided
    if ($name and $dir and $user) {

      # add directory
      $self->_add_dir(
        Mail::Dir::Monitor::Dir->new(
          dirpath => $dir,
          mail    => $mail,
          mask    => $mask,
          name    => $name,
          user    => $user,
          write   => $write,
        ),
      );

      # log this addition
      $msg = "Config directory $name, owned by $user, is $dir";
      $self->write_log($msg, $INFO);
      $msg = "Will monitor files matching regexp '$mask'";
      $self->write_log($msg, $INFO);
    }
    else {
      $msg = "No mail queue directory defined in $file";
      $self->write_log($msg, $WARN);
    }
  }

  # warning message if no mail queue directories discovered
  if (not $self->_has_dirs) {
    my $msg = 'No mail queue directories discovered, exiting';
    $self->write_log($msg, $WARN);
  }

  # return bool indicating whether any queue dirs discovered
  return $self->_has_dirs;
}

# _main_loop()    {{{1
#
# does:   main loop checking queue directories periodically
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _main_loop ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # set restart and exit handlers
  local $SIG{'HUP'}  = sub { $self->_restart($TRUE) };
  local $SIG{'TERM'} = sub { $self->_terminate($TRUE) };

  # check mail queue directories until SIGTERM or SIGHUP
  my ($loop, $delay) = (0, $self->delay);
  while ($TRUE) {

    # exit if requested with SIGTERM
    if ($self->_terminate) {
      $self->write_log('Received terminate signal, closing...', $INFO);
      last;
    }

    # restart if requested with SIGHUP
    # - use method from Perl Cookbook (edn 2, s 17.18)
    if ($self->_restart) {
      $self->write_log('Received hangup signal, restarting...', $INFO);
      for my $type (qw(ALRM CHLD HUP INT PIPE TERM)) {
        local $SIG{$type} = sub { };
      }
      POSIX::sigprocmask(POSIX::SIG_BLOCK, POSIX::SigSet->new,
        POSIX::SigSet->new);
      exec $SCRIPT, @ARGS or confess "Could not restart: $OS_ERROR";
    }

    $loop++;

    if ($loop > $delay) {
      for my $dir ($self->_dirs) { $dir->check; }
      $loop = 0;
    }
    sleep 1;
  }
  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

Mail::Dir::Monitor - daemon to monitor mail queue directories

=head1 VERSION

This documentation applies to Mail::Dir::Monitor version 0.5.

=head1 SYNOPSIS

    my $monitor = Mail::Dir::Monitor->new;
    $monitor->run;

=head1 DESCRIPTION

Users whose email client handles all aspects of email management from checking
for, downloading, reading, composing and sending email messages do not need
this daemon. They should stop reading now and move on.

Some users, for inexplicable reasons, use different utilities to manage
different email tasks. For example, C<offlineimap> to download mail, C<notmuch>
to index, thread and search mail, C<mutt> (terminal) or C<astroid> (gui) to
read and compose mail, and C<msmtp> to send mail. In these configurations mail
for sending is often written to a directory where these messages are queued
before being sent. When the user's internet connection is interrupted these
messages cannot be sent and, depending on the configuration and fuctionality of
the email-related programs, such messages may become stranded and not sent even
when internet connectivity is restored. This daemon is designed to be useful in
this very specific situation.

This is meant to be run as a daemon to monitor mail queue directories for
"stuck" mail which remains unsent. If any files are found on two consecutive
scans, the details are written to the system log. The user who owns the mail
queue may optionally be notified by local user mail and by a message sent to
their active terminal with the C<write> utility. Whether these notifications
are sent depends on how the mail queue directories are configured (see
L</"CONFIGURATION AND ENVIRONMENT"> for further details). Log messages are also
written during startup when configuration files are read (also discussed in
L</"CONFIGURATION AND ENVIRONMENT">).

=head2 Logging

Module L<Logger::Syslog|Logger::Syslog> is used for logging. Note that not all
message levels appear in all system logs. On debian, for example, log file
F</var/log/messages> records only info and warning messages while
F</var/log/syslog> records messages of all levels.

This module generates only info and warning level messages.

=head2 Daemonising this module

While this module is intended to be run as a daemon, no daemonising scripts are
packaged with it. One set of such scripts, S<< F<mail-dir-launcher> >> and
S<< F<mail-dir-monitor> >>, are packaged together with the files needed to run
it as a systemd service. On debian system it may be packaged as
S<< F<mail-dir-monitor> >> and available from the same sources as this module.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

None.

=head2 Configuration

There is a system-wide configuration directory. Running this module with the
C<--conf_dir> option set to true will print the configuration directory path
for your system to the console. The directory path is most likely
F<SYSCONF_DIR/mail-dir-monitor.d> (F</etc/mail-dir-monitor.d> on debian
systems), but the definitive value is obtained by using the C<--conf_dir>
option. All files in the configuration directory are read at startup.

Each configuration file should use ini format and define a single mail queue
directory. It does so by defining three required values (C<dir>, C<name> and
C<user>) and three optional values (C<mail>, C<mask> and C<write>), explained
further below. For options requiring boolean values use 1 and 0 for true and
false, respectively; other values will cause the module to die on startup.

=over

=item dir

The path to the directory.

String. Required.

=item mail

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

=item mask

By default this module monitors all files in a mail queue directory. Sometimes,
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

=item name

A human readable name for the directory intended to be used in user feedback.
The name can consist of multiple words. It should fit naturally into the
following sentence instead of NAME: "The NAME has stuck email files."

String. Required.

=item user

User login name of the owner of the mail queue. This is used for sending direct
feedback via local mail and terminal messages, so if there is any confusion
over the ownership of a mail queue, choose the user to whom notifications
should be sent. This value is required even if both C<mail> and C<write> are to
be left disabled.

Boolean. Optional. Default: false.

=item write

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

=back

=head2 Environment

This module does not use environment variables.

=head1 OPTIONS

=over

=item conf_dir

Display path to configuration directory and exit.

Flag. Optional. Default: false.

=item delay

Delay in seconds between checking mail queue directories. Do not make this too
short or false errors may be generated by large emails which take a significant
amount of time to send.

Scalar integer. Optional. Default: 300 (5 minutes).

=back

=head1 SUBROUTINES/METHODS

=head2 run()

This is the only public method. It starts a daemon which periodically checks
mail directories for "stuck" email, as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Messages sent to terminal

=head3 Could not restart: ERROR

An attempt to restart the daemon by sending the SIGHUP signal failed.
The error reported by the operating system is displayed. Fatal error.

=head2 Messages sent to log

=head3 Cannot locate configuration directory

The configuration directory (F<SYSCONF_DIR>/mail-dir-monitor.d>) cannot be
found. Fatal error.

=head3 Ignoring config file FILE: invalid user 'USER'

The configured owner of the mail directory is not a valid user according to the
operating system.

=head3 Ignoring key 'KEY' in config file FILE

An invalid key was found in a configuration file. Warning.

=head3 No files in configuration directory

The configuration directory (F<SYSCONF_DIR>/mail-dir-monitor.d>) contains no
files. Fatal error.

=head3 No mail queue directories discovered, exiting

No mail queue directories were defined by processing all configuration files.
Fatal.

=head3 No mail queue directory defined in FILE

The configuration file did not provide all the values needed to define a mail
queue directory. Warning.

=head3 Received terminate signal, closing...

The daemon received a SIGTERM signal. Fatal.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Config::Any, Const::Fast, Cwd, English, File::ConfigDir, File::Spec,
File::Util, IO::File, Mail::Dir::Monitor::Dir, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, POSIX, Perl6::Slurp, strictures,
Types::Standard, User::pwent, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
