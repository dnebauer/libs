package Dn::Common;

use 5.014_002;    # {{{1
use Moo;
use strictures 2;
use version; our $VERSION = qv('1.1.3');

use namespace::clean;
use Carp qw(cluck confess croak);
use Data::Dumper::Simple;
use Dn::Common::Types qw(NotifySysType);
use English qw(-no_match_vars);
use Env qw(CLUI_DIR DESKTOP_SESSION DIR HOME PAGER PWD);
use Function::Parameters qw(:lax);
use MooX::HandlesVia;
use Readonly;
use Type::Utils qw(declare);   # as|where|message apparently already declared!
use Types::Path::Tiny;
use Types::Standard;

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;

# DEPENDENCIES

use Config::Simple;
use Curses;
use Cwd qw(abs_path getcwd);
use Data::Structure::Util qw(unbless);
use Data::Validate::URI;
use Date::Simple;
use DateTime;
use DateTime::Format::Mail;
use DateTime::TimeZone;
use Desktop::Detect qw(detect_desktop);
use Dn::Common::CommandResult;
use Dn::Common::TermSize;
use Email::Valid;
use File::Basename;
use File::chdir;    # $CWD and @CWD
use File::Copy;
use File::Copy::Recursive qw(rcopy);
use File::Find::Rule;
use File::MimeInfo;
use File::Path qw(remove_tree);
use File::Spec;
use File::Temp qw(tempdir);
use File::Util;
use File::Which;
use HTML::Entities;
use IO::Pager;
use IPC::Cmd qw(run);
use IPC::Open3;
use IPC::Run;
use List::MoreUtils qw(any first_result first_value);
use Logger::Syslog;
use Net::DBus;
use Net::Ping::External qw(ping);
use Proc::ProcessTable;
use Scalar::Util qw(blessed reftype);
use Storable qw(dclone retrieve store);
use Term::ANSIColor;
use Term::Clui;
$CLUI_DIR = 'OFF';    # do not remember responses
use Term::ReadKey;
use Text::Pluralize;
use Text::Wrap;
use Time::HiRes qw(usleep);
use Time::Simple;
use UI::Dialog;

use experimental 'switch';    # }}}1

# Attributes

# notify_sys_icon_path    {{{1
has 'notify_sys_icon_path' => (
    is            => 'rw',
    isa           => Types::Path::Tiny::AbsFile,
    coerce        => $TRUE,
    lazy          => $TRUE,
    reader        => '_notify_sys_icon_path',
    required      => $FALSE,
    documentation => q{Default icon for method 'notify_sys'},
);

method _notify_sys_icon () {
    if ( $self->_notify_sys_icon_path ) {
        return $self->_notify_sys_icon_path->realpath()->canonpath();
    }
    return;
}

# notify_sys_title    {{{1
has 'notify_sys_title' => (
    is            => 'rw',
    isa           => Types::Standard::Str,
    lazy          => $TRUE,
    reader        => '_notify_sys_title',
    required      => $FALSE,
    documentation => q{Default title for method 'notify_sys'},
);

# notify_sys_type    {{{1
has 'notify_sys_type' => (
    is            => 'rw',
    isa           => Dn::Common::Types::NotifySysType,
    lazy          => $TRUE,
    reader        => '_notify_sys_type',
    required      => $FALSE,
    documentation => q{Default type for method 'notify_sys'},
);

# run_command_fatal    {{{1
has 'run_command_fatal' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    lazy          => $TRUE,
    reader        => '_run_command_fatal',
    required      => $FALSE,
    documentation => q{Default fatal setting for method 'run_command'},
);

# run_command_silent    {{{1
has 'run_command_silent' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    lazy          => $TRUE,
    reader        => '_run_command_silent',
    required      => $FALSE,
    documentation => q{Default silent setting for method 'run_command'},
);

# _adb    {{{1
has '_adb' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    lazy          => $TRUE,
    builder       => '_build_adb',
    documentation => q{An adb executable (either 'adb' or 'fb-adb')},
);

method _build_adb () {
    foreach my $adb (qw(fb-adb adb)) {
        if ( $self->executable_path($adb) ) {
            return $adb;
        }
    }
    warn "Cannot find 'fb-adb' or 'adb'\n";
    return q{};
}

# _android_device()    {{{1
has '_android_device_id' => (
    is            => 'rw',
    isa           => Types::Standard::Str,
    default       => q{},
    documentation => q{Internal device id (use '_android_device()' instead)},
);

# use this method instead of directly using attribute '_android_device_id'
# - returns android device id or dies
method _android_device () {

    # use existing android device id if still available
    my $device = $self->_android_device_id;
    if ( $device and $self->_android_device_available($device) ) {
        return $device;
    }

    # otherwise try to select a new device
    $device = $self->android_device_reset();
    if ($device) {
        $self->_android_device_id($device);
        return $device;
    }
    else {
        die "No android device set\n";
    }
}

# _configuration_files    {{{1
has '_configuration_files' => (
    is  => 'rw',
    isa => Types::Standard::ArrayRef [
        Types::Standard::InstanceOf ['Config::Simple']
    ],
    lazy        => $TRUE,
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        _config_files           => 'elements',
        _add_config_file        => 'push',       # ($obj) -> void
        _processed_config_files => 'count',      # () -> $boolean
    },
    documentation => q{Details from configuration files},
);

# _desktop    {{{1
has '_desktop' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    lazy          => $TRUE,
    builder       => '_build_desktop',
    documentation => 'The running desktop',
);

method _build_desktop () {
    my $desktop = Desktop::Detect->detect_desktop()->{desktop};

    # kde
    # - version 4: returns 'kde-plasma'
    if ( $desktop eq 'kde-plasma' ) { return 'kde'; }

    # - version 5: returns nothing, so directly inspect $DESKTOP_SESSION
    if ( $DESKTOP_SESSION eq 'plasma' ) { return 'kde'; }

    # gnome
    my %gnome_desktop
        = map { ( $_ => $TRUE ) } qw(gnome gnome-classic gnome-fallback);
    if ( $gnome_desktop{$desktop} ) { return $desktop; }

    # other
    return $desktop;
}

# _icon_error_path    {{{1
has '_icon_error_path' => (
    is            => 'rw',
    isa           => Types::Path::Tiny::AbsFile,
    coerce        => $TRUE,
    lazy          => $TRUE,
    builder       => '_build_icon_error_path',
    documentation => q{Error icon file path},
);

method _build_icon_error_path () {
    return $self->_get_icon('error.xpm');
}

method _icon_error () {
    if ( $self->_icon_error_path ) {
        return $self->_icon_error_path->realpath()->canonpath();
    }
    return;
}

# _icon_info_path    {{{1
has '_icon_info_path' => (
    is            => 'rw',
    isa           => Types::Path::Tiny::AbsFile,
    coerce        => $TRUE,
    lazy          => $TRUE,
    builder       => '_build_icon_info_path',
    documentation => q{Information icon file path},
);

method _build_icon_info_path () {
    return $self->_get_icon('info.xpm');
}

method _icon_info () {
    if ( $self->_icon_info_path ) {
        return $self->_icon_info_path->realpath()->canonpath();
    }
    return;
}

# _icon_question_path    {{{1
has '_icon_question_path' => (
    is            => 'rw',
    isa           => Types::Path::Tiny::AbsFile,
    coerce        => $TRUE,
    lazy          => $TRUE,
    builder       => '_build_icon_question_path',
    documentation => q{Question icon file path},
);

method _build_icon_question_path () {
    return $self->_get_icon('question.xpm');
}

method _icon_question () {
    if ( $self->_icon_question_path ) {
        return $self->_icon_question_path->realpath()->canonpath();
    }
    return;
}

# _icon_warn_path    {{{1
has '_icon_warn_path' => (
    is            => 'rw',
    isa           => Types::Path::Tiny::AbsFile,
    coerce        => $TRUE,
    lazy          => $TRUE,
    builder       => '_build_icon_warn_path',
    documentation => q{Warning icon file path},
);

method _build_icon_warn_path () {
    return $self->_get_icon('warn.xpm');
}

method _icon_warn () {
    if ( $self->_icon_warn_path ) {
        return $self->_icon_warn_path->realpath()->canonpath();
    }
    return;
}

# _kde_screensaver    {{{1
has '_kde_screensaver' => (
    is            => 'rw',
    isa           => Types::Standard::InstanceOf ['Net::DBus::RemoteObject'],
    lazy          => $TRUE,
    builder       => '_build_kde_screensaver',
    documentation => q{KDE screensaver object},

    # use lazy+builder because if use default sub then other modules
    # that use this one can fail their build with this error:
    #     perl Build test --verbose
    #     t/basic.t ...............
    #     # No DISPLAY. Looking for xvfb-run...
    #     # Restarting with xvfb-run...
    #     Xlib:  extension "RANDR" missing on display ":99".
    #     org.freedesktop.DBus.Error.ServiceUnknown: The name \
    #         org.freedesktop.ScreenSaver was not provided by \
    #         any .service files
    #     Compilation failed in require at t/basic.t line 3.
    #     ...
);

method _build_kde_screensaver () {
    return Net::DBus->session->get_service('org.freedesktop.ScreenSaver')
        ->get_object('/org/freedesktop/ScreenSaver');
}

# _processes    {{{1
has '_processes' => (
    is          => 'rw',
    isa         => Types::Standard::HashRef [Types::Standard::Str],
    lazy        => $TRUE,
    default     => sub { {} },
    handles_via => 'Hash',
    handles     => {
        _add_process         => 'set',       # ($pid, $cmd)->void
        _command             => 'get',       # ($pid)->$cmd
        _clear_processes     => 'clear',     # ()->void
        _pids                => 'keys',      # ()->@pids
        _commands            => 'values',    # ()->@commands
        _processes_pair_list => 'kv',        # ()->([$pid,$cmd],...)
        _has_processes       => 'count',     # ()->$boolean
    },
    documentation => q{Running processes},
);

# _screensaver_can_attempt_suspend    {{{1
has '_screensaver_can_attempt_suspend' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    lazy          => $TRUE,
    builder       => '_build_screensaver_can_attempt_suspend',
    documentation => q{Whether to attempt to suspend screensaver},
);

method _build_screensaver_can_attempt_suspend () {

    # can if xscreensaver or kde screensaver
    my $type = $self->_screensaver_type;
    my %can_suspend = map { ( $_ => $TRUE ) } qw(x kde);
    return $can_suspend{$type};
}

# _screensaver_cookie    {{{1
has '_screensaver_cookie' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    lazy          => $TRUE,
    documentation => q{Cookie used to track some suspend requests},
);

# _screensaver_suspended    {{{1
has '_screensaver_suspended' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    default       => $FALSE,
    documentation => q{Flags whether screensaver is currently suspended},
);

# _screensaver_type    {{{1
has '_screensaver_type' => (
    is            => 'rw',
    isa           => Types::Standard::Str,
    lazy          => $TRUE,
    builder       => '_build_screensaver_type',
    documentation => q{ScreenSaver type, i.e., 'x', 'kde'},
);

method _build_screensaver_type () {

    # x: xscreensaver
    my $xscreensaver
        = qr/^(xscreensaver|\/usr\/bin\/xscreensaver(\s-nosplash)?)\z/xsm;
    if ( $self->process_running($xscreensaver) ) { return q{x}; }

    # kde: kde screensaver
    if ( $self->_desktop eq 'kde' ) { return 'kde'; }

    return q{};
}

# _script    {{{1
has '_script' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    lazy          => $TRUE,
    default       => sub { File::Util->new()->strip_path($PROGRAM_NAME); },
    documentation => q{Basename of calling script},
);

# _urls    {{{1
has '_urls' => (
    is            => 'rw',
    isa           => Types::Standard::ArrayRef [Types::Standard::Str],
    lazy          => $TRUE,
    builder       => '_build_urls',
    handles_via   => 'Array',
    handles       => { _ping_urls => 'elements', },
    documentation => q{URLs to ping},
);

method _build_urls () {
    return [ 'www.debian.org', 'www.uq.edu.au' ];
}    # }}}1

# Methods

# Style notes    {{{1

=begin comment

STYLE NOTES

eval

- [http://www.perlmonks.org/?node_id=736082]
-
- use form:
-
-     if ( !eval { CODE_BLOCK; 1 } ) {
-         # handle error
-     }
-     # handle success
-
- where code block can be a variable assignment

=end comment

=cut

# }}}1

# abort(@messages, [$prepend])    {{{1
#
# does:   abort script with error message
# params: @messages - message lines [required]
#         $prepend  - whether to prepend script name to message lines
#                     [named parameter, boolean, optional, default=false]
# prints: messages
# return: nil
# usage:  $cp->abort('Did not work', $filepath);
#         $cp->abort('Did not work', $filepath, prepend => $TRUE);
# note:   respects newline if enclosed in double quotes
method abort (@messages) {

    # check args
    if ( not @messages ) {
        cluck 'No message provided';
        return;
    }

    # display messages
    $self->notify(@messages);

    # set prefix
    my ( $prepend, @messages )
        = $self->extract_key_value( 'prepend', @messages );
    my $prefix = ($prepend) ? $self->_script . ': ' : q{};

    # abort
    die "${prefix}Aborting\n";
}

# android_copy_file($source, $target, $android)    {{{1
#
# does:   copy file to or from android device
# params: $source  - source file [required]
#         $target  - target file or directory [required]
#         $android - which path is on android device
#                    [required, must be 'source' or 'target']
# prints: nil, except error messages
# return: n/a (die if serious error)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
# note:   tries using 'fb-adb' then 'adb', and dies if both unavailable
method android_copy_file ($source, $target, $android) {

    # check args
    if ( not $source )  { confess 'No source provided'; }
    if ( not $target )  { confess 'No target provided'; }
    if ( not $android ) { confess 'No android indicator provided'; }
    my %valid_android = map { ( $_ => $TRUE ) } qw(source target);
    if ( not $valid_android{$android} ) {
        confess "Invalid android indicator '$android'";
    }

    # set variables
    my $adb = $self->_adb;
    if ( not $adb ) { confess 'Could not find adb on this system'; }
    my $device = $self->_android_device;
    my $operation = ( $android eq 'source' ) ? 'pull' : 'push';

    # copy files
    my $cmd = [ $adb, '-s', $device, $operation, $source, $target ];
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) {
        my $error = $result->error;
        my @msg = ( "File copy failed\n", "System reported: $error\n" );
        confess @msg;
    }
    return;
}

# android_devices()    {{{1
#
# does:   gets all attached android devices
# params: nil
# prints: nil
# return: list of devices
# note:   tries using 'fb-adb' then 'adb', and returns
#         failure code if both unavailable
method android_devices () {

    my $adb = $self->_adb;    # android debug bridge
    if ( not $adb ) {
        warn "Unable to search for android devices\n";
        return;
    }

    # get and parse android devices report
    # - ignore failed command and parse output anyway
    my $cmd = [ $adb, 'devices' ];
    my $result = $self->capture_command_output($cmd);
    my @devices;
    my $device_count              = 0;
    my $inaccessible_device_count = 0;
    for my $line ( $result->stdout ) {
        my @elements = split /\s+/xsm, $line;
        if ( scalar @elements == 2 ) {
            my $device = $elements[0];
            my $type   = $elements[1];
            if ( $type eq 'device' ) {
                $device_count++;

                # if a device is plugged into a hub charging port
                # the device string is represented by '??????????'
                # which results in problems when it is used in
                # regular expressions
                if   ( $device =~ /^\?+\z/xsm ) { $inaccessible_device_count++; }
                else                            { push @devices, $device; }
            }
        }
    }
    if ( $inaccessible_device_count > 0 ) {
        if ( $inaccessible_device_count == $device_count ) {
            my $arg = 'The attached (device was|devices were) not properly '
                . 'registered and (is|are) inaccessible';
            my $msg = $self->pluralise( $arg, $device_count );
            warn "$msg\n";
        }
        else {    # some devices accessible and some inaccessible
            my $arg
                = '(An|Some) attached (device was|devices were) not properly '
                . 'registered and (is|are) inaccessible';
            my $msg = $self->pluralise( $arg, $device_count );
            warn "$msg\n";
        }
    }
    return @devices;
}

# android_device_reset()    {{{1
# does:   sets android device for android operations
# params: nil
# prints: feedback and error messages
# return: device id, undef if fails
# alert:  this function is called automatically whenever a method is
#         called that requires an android device, and one has not already
#         been selected;
#         that selected device is used for subsequent methods that require
#         an android device, unless it becomes unavailable;
#         if that device becomes unavailable, the next time a method
#         is called that requires an android device, this method is called
#         again to select a new device;
#         for those reasons this method should rarely need to be called
#         directly
method android_device_reset () {
    my @devices      = $self->android_devices();
    my $device_count = scalar @devices;
    for ($device_count) {

        # no android devices detected
        if ( $_ == 0 ) {
            warn "No android device detected\n";
            return;
        }

        # if single android device, select it automatically
        if ( $_ == 1 ) {
            return $devices[0];
        }

        # if multiple android devices, select one
        if ( $_ > 1 ) {
            return $self->input_choose( 'Select android device: ', @devices );
        }
    }
}

# android_file_list($dir)    {{{1
#
# does:   get list of files in android directory
# params: $dir - directory to analyse [required]
# prints: nil, except for error messages
# return: list of file names
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
method android_file_list ($dir) {
    if ( not $dir ) { $dir = q{}; }
    my $type = 'file';
    return $self->_android_file_or_subdir_list( $dir, $type );
}

# android_mkdir($dir)    {{{1
#
# does:   ensure subdirectory exists on android device
# params: $dir - directory to create [required]
# prints: nil, except error messages
# return: n/a, dies on failure
# note:   no error if directory already exists (mkdir -p)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
# note:   tries using 'fb-adb' then 'adb', and dies if both unavailable
method android_mkdir ($dir) {

    # check arg
    if ( not $dir ) { confess 'No directory provided'; }

    # set variables
    my $adb = $self->_adb;
    if ( not $adb ) { confess 'Could not find adb on this system'; }
    my $device = $self->_android_device();

    # make directory
    my $cmd = [ $adb, '-s', $device, 'shell', 'mkdir', '-p', $dir ];
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) {
        my @msg   = ("Fatal error creating directory '$dir'\n");
        my $error = $result->error;
        if ($error) { push @msg, "System reported: $error\n"; }
        confess @msg;
    }
    return;
}

# android_subdir_list($dir)    {{{1
#
# does:   get list of subdirectories in android directory
# params: $dir - directory to analyse [required]
# prints: nil
# return: list of subdirectory names
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
method android_subdir_list ($dir) {
    if ( not $dir ) { $dir = q{}; }
    my $type = 'subdir';
    return $self->_android_file_or_subdir_list( $dir, $type );
}

# autoconf_version()    {{{1
#
# does:   gets autoconf version
# params: nil
# prints: nil, except error on failure
# return: scalar version number, die on failure
method autoconf_version () {
    my $cmd = [ 'autoconf', '--version', ];
    my $cmd_str = join q{ }, @{$cmd};
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) { confess "Command '$cmd_str' failed"; }
    my $version_line = ( $result->stdout )[0];
    my @version_line_elements = split /\s+/xsm, $version_line;
    foreach my $element (@version_line_elements) {
        if ( $element =~ /^ \d+ [ [.]\d+ ]?/xsm ) {
            return $element;
        }
    }
    confess "Did not find version number in '$version_line'";
}

# backup_file($file)    {{{1
#
# does:   backs up file by renaming it to a unique file name
# params: $file - file to back up [required]
# prints: nil (error message if fails)
# return: nil (die if fails)
# detail: simply adds integer to file basename to get unique file name
# uses:   File::Copy (move), File::Basename (fileparse)
method backup_file ($file) {

    # determine backup file name
    my ( $base, $suffix )
        = ( File::Basename::fileparse( $file, qr/[.][^.]*\z/xsm ) )[ 0, 2 ];
    my $count  = 1;
    my $backup = $base . q{_} . $count++ . $suffix;
    while ( -e $backup ) {
        $backup = $base . q{_} . $count++ . $suffix;
    }

    # do backup
    File::Copy::move( $file, $backup )
        or confess "Error: unable to backup $base to $backup";

    # notify user
    say "Existing file '$file' renamed to '$backup'";
}

# boolise($value)    {{{1
#
# does:   convert value to boolean
# detail: convert 'yes', 'true' and 'on' to 1
#         convert 'no, 'false, and 'off' to 0
#         other values returned unchanged
# params: $value - value to analyse [required]
# prints: nil
# return: boolean
method boolise ($value) {
    if ( not defined $value ) { return; }    # handle special case
    for ($value) {
        if ( $_ =~ /^yes$|^true$|^on$/ixsm)  { return 1; }  # true -> 1
        if ( $_ =~ /^no$|^false$|^off$/ixsm) { return 0; }  # false -> 0
        return $value;
    }
}

# browse($title, $text)    {{{1
#
# does:   displays a large volume of text in default editor
# params: $title - title applied to editor temporary file
# prints: nil
# return: nil
method browse ($title, $text) {
    return if not $title;
    return if not $text;
    my $text
        = qq{\n}
        . $title
        . qq{\n\n}
        . qq{[This text should be displaying in your default editor.\n}
        . qq{If no default editor is specified, vi(m) is used.\n}
        . q{To exit this screen, exit the editor as you normally would}
        . q{ - 'ZQ' for vi(m).]}
        . qq{\n\n}
        . $text;
    Term::Clui::edit( $title, $text );
}

# capture_command_output($cmd)    {{{1
#
# does:   run system command and capture output
# params: $cmd - command to run
#                [string or array reference, required]
# return: Dn::Common::CommandResult object
# uses:   Dn::Common::CommandResult, IPC::Cmd
method capture_command_output ($cmd) {

    # process arg
    if ( not( defined $cmd ) ) { confess 'No command provided'; }
    my $arg_type = ref $cmd;
    if ( $arg_type eq 'ARRAY' ) {
        my @cmd_args = @{$cmd};
        if ( not @cmd_args ) { confess 'No command arguments provided'; }
    }
    elsif ( $arg_type ne q{} ) {       # if not array ref must be string
        confess 'Command is not a string or array reference';
    }

    # run command
    my ( $succeed, $err, $full_ref, $stdout_ref, $stderr_ref )
        = IPC::Cmd::run( command => $cmd );

    # process output
    # - err: has trailing newline
    if ( defined $err ) {
        chomp $err;
    }
    else {
        $err = q{};    # prevent undef which fails type constraint
    }

    # - full, stdout and stderr: appears that for at least some commands
    #   all output lines are put into a single string, separated with
    #   embedded newlines, which is then put into a single element list
    #   which is made into an array reference; these are unpacked below
    my @full;
    foreach my $chunk ( @{$full_ref} ) {
        chomp $chunk;
        my @lines = split /\n/xsm, $chunk;
        push @full, @lines;
    }
    my @stdout;
    foreach my $chunk ( @{$stdout_ref} ) {
        chomp $chunk;
        my @lines = split /\n/xsm, $chunk;
        push @stdout, @lines;
    }
    my @stderr;
    foreach my $chunk ( @{$stderr_ref} ) {
        chomp $chunk;
        my @lines = split /\n/xsm, $chunk;
        push @stderr, @lines;
    }

    # return results as an object
    return Dn::Common::CommandResult->new(
        success      => $succeed,
        error        => $err,
        full_output  => [@full],
        standard_out => [@stdout],
        standard_err => [@stderr],
    );
}

# centre_text($text, $width)    {{{1
#
# does:   centre text within specified width by inserting leading spaces
# params: $text  - text to centre [optional, default=empty string]
#         $width - line width [optional, default=terminal width]
# prints: nil, except error messages
# return: scalar string
method centre_text ($text, $width) {

    # check args
    if ( not $text ) { return q{}; }
    my $length = length $text;
    if ( $length == 0 ) { return q{}; }
    my $term_width = eval { $self->term_size->width };
    if ( $term_width and not $width ) {
        $width = $term_width;        # try to use term width if no width
    }
    if ( not $self->valid_positive_integer($width) ) {
        warn "Width '$width' is not a positive integer\n";
        return $text;
    }
    if ( not $width )        { return $text; }
    if ( $length >= $width ) { return $text; }

    # calculate left padding
    my $excess = $width - $length;
    if ( $excess <= 1 ) { return $text; }
    my $left_pad_size = int( $excess / 2 );
    my $left_pad      = q{ } x $left_pad_size;

    # return result
    my $padded_text = $left_pad . $text;
    return $padded_text;
}

# changelog_from_git($dir)    {{{1
#
# does:   get ChangLog content from git repository
# params: $dir = root file of repository [required]
#                must contain a '.git' directory
# prints: nil, feedback on failure
# return: list, empty on failure
method changelog_from_git ($dir) {

    # check directory
    if ( not $dir ) { return; }
    my $repo_root = $self->true_path($dir);
    if ( not -d $repo_root ) { cluck "Invalid directory '$dir'"; }
    my $git_dir = $repo_root . '/.git';
    if ( not -d $git_dir ) { cluck "'$dir' is not a git repo root"; }

    # operate from repo root dir
    local $File::chdir::CWD = $File::chdir::CWD;
    $File::chdir::CWD = $repo_root;

    # obtain git log output
    my $cmd = [ 'git', 'log', '--date-order', '--date=short' ];
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) {
        cluck "Unable to get git log in '$dir'";
        return;
    }

    # process output log entries
    my ( @log, @entry );
    my $indent = q{ } x 4;
    my ( $author, $email, $date );
    foreach my $line ( $result->stdout ) {
        next if $line =~ /^commit /xsm;
        next if $line =~ /^\s*$/xsm;
        my ( $key, @values ) = split /\s+/xsm, $line;
        my $value = join q{ }, @values;
        for ($key) {
            if ( $_ eq 'Author:' ) {  # start of entry
                                      # flush previous entry, if any
                if (@entry) {
                    push @log, "$date  $author <$email>";
                    push @log, q{};
                    foreach my $line (@entry) {
                        push @log, $indent . q{* } . $line;
                    }
                    push @log, q{};
                    @entry = ();
                }

                # process current line
                elsif ( $value =~ /^([^<]+)\s+<([^>]+)>\s*$/xsm ) {
                    $author = $1;
                    $email  = $2;
                }
                else {
                    confess "Bad match on line '$line'";
                }
            }
            elsif ( $_ eq 'Date:' ) {
                $date = $value;
            }
            else {    # entry detail
                push @entry, $value;
            }
        }
    }

    # flush final entry
    if (@entry) {
        push @log, "$date  $author <$email>";
        push @log, q{};
        foreach my $line (@entry) {
            push @log, $indent . q{* } . $line;
        }
        push @log, q{};
    }

    # return log
    return @log;
}

# clear_screen()    {{{1
#
# does:   clear the terminal screen
# params: nil
# prints: nil
# return: nil
method clear_screen () {
    my $clear = 'clear';
    if ( $self->executable_path($clear) ) {
        system 'clear';
    }
    else {
        cluck "System command '$clear' is not available";
    }
}

# config_param($param)    {{{1
#
# does:   get parameter value
# params: $param - configuration parameter name
# prints: nil
# return: list of parameter value(s)
# uses:   Config::Simple
method config_param ($param) {

    # set and check variables
    if ( not $param ) {
        return;
    }
    my @values;

    # read config files if not already done
    if ( not $self->_processed_config_files ) {
        $self->_process_config_files;
    }

    # cycle through config files looking for matches
    # - later matches override earlier matches
    # - force list context initially
    for my $config_file ( $self->_config_files ) {
        if ( $config_file->param($param) ) {
            @values = $config_file->param($param);
        }
    }

    # return value depends on calling context
    return @values;
}

# cwd()    {{{1
#
# does:   get current directory
# params: nil
# prints: nil
# return: scalar
#  uses:  Cwd
method cwd () {
    return Cwd::getcwd();
}

# date_email ([$date], [$time], [$offset])    {{{1
#
# does:   produce a date formatted according to RFC 2822
#         (Internet Message Format)
# params: $date   - iso-format date
#                   [named parameter, optional, default=today]
#         $time   - 24 hour time [named parameter, optional, default=now]
#                   leading hour zero, and seconds, are optional
#         $offset - timezone offset, e.g., +0930
#                   [named parameter, optional, default=local timezone offset]
# prints: message if fatal error
# return: scalar string (undef if error)
# note:   example output: 'Mon, 16 Jul 1979 16:45:20 +1000'
method date_email (:$date, :$time, :$offset) {

    # date
    if ($date) {
        if ( not $self->valid_date($date) ) {
            cluck "Invalid date '$date'\n";
            return;
        }
    }
    else {
        $date = $self->today();
    }

    # time
    if ($time) {
        if ( not $self->valid_24h_time($time) ) {
            cluck "Invalid time '$time'\n";
            return;
        }
    }
    else {
        $time = $self->now();
    }

    # timezone
    my $timezone;
    if ($offset) {
        $timezone = $self->timezone_from_offset($offset);
        if ( not $timezone ) { return; }    # error shown by previous line
    }
    else {
        $timezone = $self->local_timezone();
    }

    # get rfc 2822 string
    my $ds = Date::Simple->new($date);
    if ( not $ds ) { confess 'Unable to create Date::Simple object'; }
    my $ts = Time::Simple->new($time);
    if ( not $ts ) { confess 'Unable to create Time::Simple object'; }
    my $dt = DateTime->new(
        year      => $ds->year,
        month     => $ds->month,
        day       => $ds->day,
        hour      => $ts->hour,
        minute    => $ts->minute,
        second    => $ts->second,
        time_zone => $timezone,
    );
    if ( not $dt ) { confess 'Unable to create DateTime object'; }
    my $email_date = DateTime::Format::Mail->format_datetime($dt);
    if ( not $email_date ) { confess 'Unable to generate RFC2822 date'; }
    return $email_date;
}

# day_of_week([$date])    {{{1
#
# does:   day of week the supplied date falls on
# params: $date - date in ISO format [optional, default=today]
# prints: nil
# return: scalar day
# uses:   Date::Simple
method day_of_week ($date) {
    if ( not $date ) { $date = $self->today(); }
    return if not $self->valid_date($date);
    my %day_numbers = (
        '0' => 'Sunday',
        '1' => 'Monday',
        '2' => 'Tuesday',
        '3' => 'Wednesday',
        '4' => 'Thursday',
        '5' => 'Friday',
        '6' => 'Saturday',
    );
    my $d          = Date::Simple->new($date);
    my $day_number = $d->day_of_week();
    my $day        = $day_numbers{$day_number};
    if ( not $day ) { return; }
    return $day;
}

# debhelper_compat()    {{{1
#
# does:   get current debian compatibility level
#         - actually gets major version of debian package 'debhelper'
# params: nil
# prints: nil
# return: scalar string - version (undef if problem encountered)
method debhelper_compat () {

    # get full version
    my $version_full = $self->debian_package_version('debhelper');
    return if not $version_full;

    # get semantic version
    # - meaning only '[E:]X' and not, for example, '[E:]X.Y.Z')
    my $match_full_version = qr{
        \A       # anchor to start of string
        (\d+:)?  # epoch (optional)
        [\d\.]+  # version: A.B.C...
        \Z       # anchor to start of string
    }xsm;
    my $match_major_version = qr{
        \A                # anchor to start of string
        (                 # start capture
          (?:\d+:)?       # epoch (optional)
          \d+             # major version number
        )                 # end capture (don't care about string end)
    }xsm;
    my $major_version;
    if ( $version_full =~ $match_full_version ) {
        $version_full =~ $match_major_version;
        $major_version = $1;
    }
    return if not $major_version;

    return $major_version;

}

# debian_install_deb($deb)    {{{1
#
# does:   installs debian package from a deb file
# params: $deb - deb package file [required]
# prints: question and feedback
# return: boolean
method debian_install_deb ($deb) {

    # test filepath
    if ( not $deb ) {
        cluck 'No debian package filepath provided';
        return;
    }
    if ( not -r $deb ) {
        cluck "Invalid filepath '$deb' provided";
        return;
    }
    if ( not $self->is_deb($deb) ) {
        cluck "File '$deb' is not a valid debian package file";
        return;
    }

    # set variables
    my $installer = 'dpkg';
    if ( not $self->executable_path($installer) ) {
        confess "Invalid installer '$installer'";
    }
    my $params  = '--install';
    my $success = $FALSE;
    my $cmd;

    # play nice with other calling apps
    my $silent = $self->_run_command_silent;
    my $fatal  = $self->_run_command_fatal;
    $self->run_command_silent($FALSE);
    $self->run_command_fatal($FALSE);

    # try installing as if root
    $cmd = [ $installer, $params, $deb ];
    if ( $self->run_command($cmd) ) {
        $success = $TRUE;
        say 'Package installed successfully';
    }
    else {
        warn "Looks like you are not root/superuser\n";
    }

    # try installing with sudo
    if ( not $success ) {
        $cmd = [ 'sudo', $installer, $params, $deb ];
        if ( $self->run_command($cmd) ) {
            $success = $TRUE;
            say 'Package installed successfully';
        }
        else {
            warn "Okay, you do not have root privileges for '$installer'\n";
        }
    }

    # lastly, try su
    # - could not pass command as arrayref
    #   . if every part is made array element then operation fails with:
    #       /bin/su: unrecognized option '--install'
    #   . if pass entire command spanning double quotes (including double
    #     quotes) as a single array element, then entire command appears
    #     to be passed to bash as a single unit, and after providing
    #     password the operation fails with:
    #       bash: dpkg --install ../build/FILE.deb: No such file or directory
    if ( not $success ) {
        $cmd
            = [   'su -c' . q{ } . q{"}
                . $installer . q{ }
                . $params . q{ }
                . $deb
                . q{"} ];
        say 'The root password is needed';
        if ( $self->run_command($cmd) ) {
            $success = $TRUE;
            say 'Package installed successfully';
        }
        else {
            warn "That's it, I give up installing this package\n";
        }
    }

    # finished trying to install
    if ( defined $silent ) { $self->run_command_silent($silent); }
    if ( defined $fatal )  { $self->run_command_fatal($fatal); }
    return $success;
}

# debian_package_version($pkg)    {{{1
#
# does:   get version of debian package
# params: $pkg - name of debian package
# prints: nil
# return: scalar string - version (undef on failure)
method debian_package_version ($pkg) {

    # check arg
    return if not $pkg;

    # get output of 'dpkg -s debian-policy'
    my $cmd     = [ 'dpkg', '-s', $pkg ];
    my $cmd_str = join q{ }, @{$cmd};
    my $result  = $self->capture_command_output($cmd);
    return if not $result->success;

    # get version line from status output
    my $version_line
        = List::MoreUtils::first_value {/\AVersion: /xsm} $result->stdout;
    return if not $version_line;

    # get full version number
    my $version = ( split /\s+/xsm, $version_line )[1];
    return if not $version;

    return $version;

}

# debian_standards_version()    {{{1
#
# does:   get current version of debian standards
#         - actually gets semantic version of debian package 'debian-policy'
#         - if problem encountered returns safe version ('3.9.2')
# params: nil
# prints: nil
# return: scalar string - version
method debian_standards_version () {

    my $default = '3.9.2';

    # get full version
    my $version_full = $self->debian_package_version('debian-policy');
    return $default if not $version_full;

    # get semantic version
    # - meaning only '[E:]X.Y.Z' and not, for example, '[E:]X.Y.Z.A')
    my $match_full_version = qr{
        \A       # anchor to start of string
        (\d+:)?  # epoch (optional)
        [\d\.]+  # version: A.B.C...
        \Z       # anchor to start of string
    }xsm;
    my $match_semantic_version = qr{
        \A                # anchor to start of string
        (                 # start capture
          (?:\d+:)?       # epoch (optional)
          \d+             # major version number
          (?:\.\d+){0,2}  # up to two further version levels
        )                 # end capture (don't care about string end)
    }xsm;
    my $version;
    if ( $version_full =~ $match_full_version ) {
        $version_full =~ $match_semantic_version;
        $version = $1;
    }
    return $default if not $version;

    return $version;

}

# debless($object)    {{{1
#
# does:   get underlying data structure of object/blessed reference
# params: $object - blessed reference to extract data from [required]
# prints: nil
# return: hash reference
# uses:   Data::Structure::Util, Scalar::Util, Storable
method debless ($object) {

    # check argument
    if ( not $object ) { confess 'No object provided'; }
    my $class = Scalar::Util::blessed($object);
    if ( not( defined $class ) ) { confess 'Not a blessed object'; }
    my $ref_type = Scalar::Util::reftype($object);
    if ( $ref_type ne 'HASH' ) { confess 'Not a blessed hash'; }

    # get underlying data structure
    my $clone = Storable::dclone($object);
    my $data  = Data::Structure::Util::unbless($clone);

    return $data;

}

# deentitise($string)    {{{1
#
# does:   convert HTML entities to reserved characters
# params: $string - string to analyse [required]
# prints: nil
# return: scalar string
# # uses: HTML::Entities
method deentitise ($string = q//) {
    return HTML::Entities::decode_entities($string);
}

# denumber_list(@list)    {{{1
#
# does:   remove number prefixes added by method 'number_list'
# params: @items - list to modify [required]
# prints: nil
# return: list
# note:   map operation extracted to method as per Perl Best Practice
method denumber_list (@items) {
    map { $self->_remove_numeric_prefix($_) } @items;
}

method _remove_numeric_prefix ($item) {
    $item =~ s/^\s*\d+[.]\s+//xsm;
    $item;
}

# dir_add_dir($dir, @subdirs)    {{{1
#
# does:   add subdirectories to directory path
# params: $dir     - directory path to add to [required]
#                    need not exist
#         @subdirs - subdirectories to add [required]
# prints: nil
# return: scalar directory path
method dir_add_dir ($dir, @subdirs) {
    if ( not $dir ) { confess 'No directory provided'; }
    if ( not @subdirs ) {
        cluck 'No subdirectory names provided';
        return $dir;
    }
    my @path = $self->path_split($dir);
    foreach my $subdir (@subdirs) {
        push @path, $subdir;
    }
    return $self->join_dir( [@path] );
}

# dir_add_file($dir, $file)    {{{1
#
# does:   add file name to directory path
# params: $dir    - directory path to add to [required]
#                   need not exist
#         $subdir - file name to add [required]
# prints: nil
# return: scalar file path
method dir_add_file ($dir, $file) {
    my @path = $self->path_split($dir);
    push @path, $file;
    return $self->join_dir( [@path] );
}

# dirs_list($directory)    {{{1
#
# does:   list subdirectories in directory
# params: $directory - directory path [optional, default=cwd]
# prints: nil
# return: list, die if operation fails
method dirs_list ($dir) {
    if ( not $dir ) { $dir = $self->cwd(); }
    $dir = $self->true_path($dir);
    if ( not -d $dir ) { confess "Invalid directory '$dir'"; }
    my $f = File::Util->new();

    # method 'list_dir' fails if directory has no subdirs, so cannot test
    # for failure of method - assume "failure" == no subdirs in directory
    my @dirs;
    @dirs = $f->list_dir( $dir, { dirs_only => $TRUE } );
    if (@dirs) {
        @dirs = grep { !/^[.]{1,2}$/xsm } @dirs;    # exclude '.' and '..'
    }
    return @dirs;
}

# display($string, [$error], [$indent], [$hang])    {{{1
#
# does:   displays screen text with word wrapping
# params: $string - text to display [required]
#         $error  - print to stderr
#                   [named parameter, optional, default=false]
# prints: text for display to stdout or stderr
# return: nil
# usage:  $cp->display($long_string);
#         $cp->display( $long_string, error => $TRUE )
# uses:   Text::Wrap
method display ($string, :$error = $FALSE) {
    my $msg = Text::Wrap::wrap( q{}, q{}, $string );
    chomp $msg;
    if ($error) {
        say $msg;
    }
    else {
        warn "$msg\n";
    }
}

# do_copy($src, $dest)    {{{1
#
# does:   copy source file or directory to target file or directory
# params: $src  - source file or directory [required]
#                 must exist
#         $dest - destination file or directory [required]
#                 need not exist
# prints: nil, except for error message
# return: boolean success of copy
#         die if missing argument
# uses:   File::Copy::Recursive
# note:   can copy file to file or directory
#         can copy directory to directory
#         can not copy directory to existing file
# note:   F::C::R function rmove tries very hard to perform copy,
#         creating target directories where necessary
method do_copy ($src, $dest) {

    # check args - missing argument is fatal
    if ( not $src )  { confess 'No source provided'; }
    if ( not $dest ) { confess 'No destination provided'; }

    # convert to true path
    my $source      = $self->true_path($src);
    my $destination = $self->true_path($dest);

    # check args - source must exist
    if ( not -e $source ) {
        cluck "Source '$src' does not exist";
        return;
    }

    # check args - cannot copy directory onto file
    if ( -d $source and -e $destination ) {
        cluck "Cannot copy directory '$src' onto file '$dest'";
        return;
    }

    # perform copy
    return File::Copy::Recursive::rcopy( $source, $destination );
}

# do_rmdir($dir)    {{{1
#
# does:   remove directory recursively (like 'rm -fr')
# params: $dir - directory to remove [required]
# prints: nil
# return: boolean
# uses:   File::Path
method do_rmdir ($dir) {
    if ( not $dir )    { confess 'No directory provided'; }
    if ( not -d $dir ) { confess "Directory '$dir' is invalid"; }
    return File::Path::remove_tree($dir);
}

# do_wrap($string, [$width],[$indent], [$hang], [$break])    {{{1
#
# does:   displays screen text with word wrapping
# params:    {{{2
#         $strings - text to wrap, string or array reference
#                    [required]
#         %options - options hash [optional]:
#             $width  - width at which to wrap [default=terminal width]
#                       note: cannot be wider than terminal width
#             $indent - size of indent [default=0]
#             $hang   - size of indent of second and subsequent lines
#                       [default=$indent]
#             $break  - characters on which to break
#                       note: cannot include escapes (such as '\s')
#                       [array reference, default=(' ')]    }}}2
# prints: nil
# return: list of strings (no terminal slashes)
# usage:  my @output = $cp->do_wrap($long_string, indent => 2, hang => 4);
#         my @output = $cp->do_wrap([@many_strings]);
# notes:    {{{2
# note:   continuation lines have a prepended continuation character;
#         alternatives include:
#         U+2938 (⤸),
#         U+21A9 (↩),
#         U+21B2 (↲),
#         U+21B5 (↵),
#         U+21D9 (⇙),
#         U+2926 (⤦),
#         U+2936 (⤶),
#         U+23CE (⏎),
#         U+2B0B (⬋),
#         U+2B03 (⬃)
# note:   a line consisting solely of break characters (such as a
#         line of dashes, where dashes are defined as a break
#         character) will simply disappear during processing --
#         this is due to an idiosyncrasy of the Text::Wrap class
# note:   often used with method 'pager' to format screen display    }}}2
# uses:   Text::Wrap
method do_wrap ($strings, %options) {

    # handle args
    # - $strings    {{{2
    if ( not $strings ) { confess 'No strings provided'; }
    my $strings_ref = ref $strings;
    my @input;
    for ($strings_ref) {
        if ( $_ eq 'ARRAY' ) { @input = @{$strings}; }
        elsif ( $_ eq q{} ) { push @input, $strings; }
        else {
            my $err = 'Input is not a string or array reference: '
                . Dumper($strings);
            confess $err;
        }
    }

    # - $width    {{{2
    my $width;
    if ( $options{'width'} ) {
        if (    $self->valid_positive_integer( $options{'width'} )
            and $options{'width'} > 0 )
        {
            $width = $options{'width'};
        }
        else {
            my $err
                = q{Invalid option 'width': } . Dumper( $options{'width'} );
            confess $err;
        }
    }
    my $terminal_width = $self->term_size->width - 1;
    if ( ( not $width ) or ( $width > $terminal_width ) ) {
        $width = $terminal_width;
    }
    local $Text::Wrap::columns = $Text::Wrap::columns;
    $Text::Wrap::columns = $width;

    # - $indent    {{{2
    my $indent = q{};
    if ( $options{'indent'} ) {
        if (    $self->valid_positive_integer( $options{'indent'} )
            and $options{'indent'} > 0
            and ( ( $options{'indent'} + 10 ) < $width ) )
        {
            $indent = q{ } x $options{'indent'};
        }
        else {
            my $err
                = q{Invalid option 'indent': } . Dumper( $options{'indent'} );
            confess $err;
        }
    }

    # - $hang    {{{2
    my $hang = $indent;
    if ( $options{'hang'} ) {
        if ( $self->valid_positive_integer( $options{'hang'} )
            and ( ( $options{'hang'} + 10 ) < $width ) )
        {
            $hang = q{ } x $options{'hang'};
        }
        else {
            my $err = q{Invalid option 'hang': } . Dumper( $options{'hang'} );
            confess $err;
        }
    }

    # - $break    {{{2
    my $break_chars = [q{ }];
    if ( defined $options{'break'} ) {
        my $break_ref = ref $options{'break'};
        if ( $break_ref eq 'ARRAY' ) {
            $break_chars = $options{'break'};
        }
        else {
            my $err
                = q{Invalid option 'break': } . Dumper( $options{'break'} );
            confess $err;
        }
    }

    # some break tokens can't be doubled, or it screws up the output
    # - also, ensure tokens are single characters
    my ( @doubled_chars, @ignoring );
    my @do_not_double = (q{ });
    foreach my $char ( @{$break_chars} ) {
        if ( length $char > 1 ) {
            push @ignoring, $char;
            next;
        }

        # do not use 'x' switch as searching includes spaces
        ## no critic (RequireExtendedFormatting)
        if ( not List::MoreUtils::any {/^$char\z/sm} @do_not_double ) {
            push @doubled_chars, $char;
        }
        ## use critic
    }
    if (@ignoring) {
        foreach my $item (@ignoring) { $item = "'$item'"; }
        my $chars = join q{, }, @ignoring;
        warn "Break on single characters only -- ignoring: $chars\n";
    }

    # double break characters in case one is eaten by Text::Wrap
    foreach my $char (@doubled_chars) {
        foreach my $line (@input) {
            $line =~ s/$char/$char$char/xsmg;
        }
    }

    # assemble $break regex and set $Text::Wrap::break
    my $pattern = q{};
    if ( @{$break_chars} ) { $pattern .= ( join q{}, @{$break_chars} ); }
    if ($pattern) { $pattern = "[$pattern]"; }
    my $break = qr/$pattern/xsm;
    local $Text::Wrap::break = $Text::Wrap::break;
    $Text::Wrap::break = $break;    # }}}2

    # wrap message
    local $Text::Wrap::huge = $Text::Wrap::huge;
    $Text::Wrap::huge = 'wrap';
    my @output;
    foreach my $line (@input) {
        my $wrapped = Text::Wrap::wrap( $indent, $hang, $line );
        my @wrapped_lines = split /\n/xsm, $wrapped;
        if ( scalar @wrapped_lines > 1 ) {    # add continuation character
            my $first_line = shift @wrapped_lines;
            foreach my $line (@wrapped_lines) { $line .= q{↩}; }    # U+21A9
            unshift @wrapped_lines, $first_line;
        }
        push @output, @wrapped_lines;
    }
    chomp @output;

    # reverse doubling of break tokens
    foreach my $char (@doubled_chars) {
        foreach my $line (@output) {
            $line =~ s/$char$char/$char/xsmg;
        }
    }

    return @output;
}

# echo_e($string)    {{{1
#
# does:   use shell command 'echo -e'
# params: $text - text to print [required]
# prints: string with shell escape sequences escaped
# return: nil
method echo_e ($text) {
    if ( not $text ) {
        confess q{No text provided};
    }
    my @cmd = ( q{echo}, q{-e}, $text );
    system @cmd;
}

# echo_en($string)    {{{1
#
# does:   use shell command 'echo -en'
# params: $text - text to print [required]
# prints: string with shell escape sequences escaped
#         and no trailing newline
# return: nil
method echo_en ($text) {
    if ( not $text ) {
        confess q{No text provided};
    }
    my @cmd = ( q{echo}, q{-en}, $text );
    system @cmd;
}

# ensure_no_trailing_slash($dir)    {{{1
#
# does:   removes trailing slash from directory path
# params: $dir - directory path to analyse [required]
# prints: nil
# return: scalar string - altered dirpath
method ensure_no_trailing_slash ($dir) {
    if ( not $dir ) { return; }
    while ( $dir =~ m{/$}xsm ) {
        chop $dir;
    }
    return $dir;
}

# ensure_trailing_slash($dir)    {{{1
#
# does:   ensures directory has trailing slash
# params: $dir - directory path to analyse [required]
# prints: nil
# return: scalar string - altered dirpath
method ensure_trailing_slash ($dir) {
    if ( not $dir ) { return; }
    while ( $dir =~ m{/$}xsm ) {
        chop $dir;
    }
    $dir .= q{/};
    return $dir;
}

# entitise($string)    {{{1
#
# does:   convert reserved characters to HTML entities
# params: $string - string to analyse [required]
# prints: nil
# return: scalar string
# # uses: HTML::Entities
method entitise ($string = q//) {
    return HTML::Entities::encode_entities($string);
}

# executable_path($exe)    {{{1
#
# does:   find path to executable
# params: $exe - short name of executable [requiered]
# prints: nil
# return: scalar filepath
#         scalar boolean (undef if not found)
# uses:   File::Which
method executable_path ($exe) {
    if ( not $exe ) { confess 'No executable name provided'; }
    scalar File::Which::which($exe);
}

# extract_key_value($key, @items)    {{{1
#
# does:   extract key value from list
#         assumes key and value are pair of elements in list
#         also returns list with key and value removed
# params: $key   - key, first element in key-value pair
#         @items - items to analyse
# prints: nil
# return: list ($key_value, @amended_list)
# usage:  my ($value, @list) = $cp->($key, @list);
method extract_key_value ($key, @items) {
    my ( @remainder, $value, $next_is_value );
    for my $item (@items) {
        if ( lc $item eq lc $key ) {      # key value next
            $next_is_value = $TRUE;
        }
        elsif ($next_is_value) {          # this is prepend value
            $value         = $item;
            $next_is_value = $FALSE;
        }
        else {                            # a message item
            push @remainder, $item;
        }
    }
    return ( $value, @remainder );
}

# file_used_by($file)    {{{1
#
# does:   get processes using file
# params: $file - file/filepath, relative or absolute [required]
# prints: nil, except errors
# return: list of pids
method file_used_by ($file) {

    # check arg
    if ( not $file )    { confess 'No file provided'; }
    if ( not -e $file ) { confess "Cannot find file '$file'"; }

    # check for fuser
    my $fuser = 'fuser';
    if ( not $self->executable_path($fuser) ) {
        confess "$fuser not available";
    }

    # okay, let's investigate who is locking
    my $cmd = [ $fuser, $file ];
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) {
        foreach my $line ( $result->full ) {
            warn "$line\n";
        }
        my $cmd_string = join q{ }, @{$cmd};
        confess "Command '$cmd' failed unexpectedly";
    }
    my $output = join q{ }, $result->stdout;
    $output = $self->trim($output);
    my @pids = split /\s+/xsm, $output;

    # return results
    return @pids;
}

# files_list([$dir_path])    {{{1
#
# does:   list files in directory
# params: $directory - directory path [optional, default=cwd]
# prints: nil
# return: list, die if operation fails
method files_list ($dir) {
    if ( not $dir ) { $dir = $self->cwd(); }
    $dir = $self->true_path($dir);
    if ( not -d $dir ) { confess "Invalid directory '$dir'"; }
    my $f = File::Util->new();

    # method 'list_dir' fails if directory has no files, so cannot test
    # for failure of method - assume "failure" == no files in directory
    my @files;
    @files = $f->list_dir( $dir, { files_only => $TRUE } );
    return @files;
}

# find_files_in_dir($dir, $pattern)    {{{1
#
# does:   finds file in directory matching pattern
# params: $dir     - directory to search
#         $pattern - file name pattern to match
#                    (glob or regular expression)
# prints: nil
# return: list of absolute file paths
# note:   does not recurse into subdirectories
# uses:   Cwd, File::Find::Rule
method find_files_in_dir ( $dir, $pattern ) {
    if ( not $pattern ) {
        cluck 'No file pattern provided';
        return;
    }
    if ( not $dir ) {
        cluck 'No directory provided';
        return;
    }
    my $dir_path = Cwd::abs_path($dir);
    return File::Find::Rule->file->maxdepth(1)->name($pattern)->in($dir_path);
}

# future_date($date)    {{{1
#
# does:   determine whether supplied date occurs in the future,
#         i.e, today or after today
# params: $date - date to compare, must be ISO format [required]
# prints: nil (error if invalid date)
# return: boolean (dies if invalid date)
method future_date ($date) {

    # check date
    if ( not $self->valid_date($date) ) {
        confess "Invalid date '$date'";
    }

    # get dates
    my $iso_date = Date::Simple->new($date);
    my $today    = Date::Simple->new();

    # evaluate date sequence
    return ( $iso_date >= $today );
}

# get_filename($filepath)    {{{1
#
# does:   get filename from filepath
# params: $filepath - file path [required]
# prints: nil
# return: scalar filename
# uses:   File::Basename
# note:   returns last element in path, which may be dir in dirpath
method get_filename ($filepath) {
    if ( not $filepath ) { confess 'No file path provided'; }
    return File::Basename::fileparse($filepath);
}

# get_last_subdir($dirpath)    {{{1
#
# does:   get last subdirectory from directory path
# params: $dirpath - directory path [required]
# prints: nil
# return: scalar path
# uses:   File::Spec
method get_last_subdir ($dirpath) {
    if ( not $dirpath ) { confess 'No directory path provided'; }
    my @path = File::Spec->splitdir($dirpath);
    my $last_dir;
    while ( not $last_dir ) {       # final element empty if trailing slash
        $last_dir = pop @path;
    }
    if ( not $last_dir ) {
        if (@path) {
            my $residual = $self->join_dir( [@path] );
            my @err = (
                qq{Unable to resolve last directory:\n},
                qq{  Received path '$dirpath' and wound up with an empty\n},
                qq{  last directory and residual path '$residual'\n},
            );
            confess @err;
        }
        else {    # no path and no last_dir -- assume root
            return q{/};
        }
    }
    return $last_dir;
}

# get_path($filepath)    {{{1
#
# does:   get path from filepath
# params: $filepath - file path [required]
# prints: nil
# return: scalar path
# uses:   File::Util
method get_path ($filepath) {
    if ( not $filepath ) { confess 'No file path provided'; }
    my $path = File::Util->new()->return_path($filepath);
    if ( $path eq $filepath ) {
        $path = q{};
    }
    return $path;
}

# input_ask($prompt, [$default],[$prepend])    {{{1
#
# does:   get input from user
# params: $prompt  - user prompt [required]
#         $default - default input [optional, default=q{}]
#         $prepend - whether to prepend scrip name to prompt
#                    [named parameter, options, default=false]
# prints: user interaction
# return: user input (scalar)
# note:   intended for entering short values
#         -- once the line wraps the user cannot move to previous line
#         use method 'input_large' for long input
# uses:   Term::Clui
method input_ask ($prompt, $default, @options) {

    # process args
    if ( not $prompt ) { return; }
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) { $prompt = $self->_script . ': ' . $prompt; }

    # get user input
    return Term::Clui::ask( $prompt, $default );
}

# input_choose($prompt, @options, [$prepend])    {{{1
#
# does:   user selects option from a menu
# params: $prompt  - menu prompt [required]
#         @options - menu options [required]
#         $prepend - flag to prepend script name to prompt
#                    [named parameter, boolean, optional, default=false]
# prints: menu and user interaction
# usage:  my $value = undef;
#         my @options = ( 'Pick me', 'No, me!' );
#          while ($TRUE) {
#              @picks = $self->input_choose(
#                  "Select value:", @options, $prepend => 1
#              );
#              last if @picks;
#              say "Invalid choice. Sorry, please try again.";
#          }
# return: return value depends on the calling context:
#         - scalar: returns scalar (undef if choice cancelled)
#         - list:   returns list (empty list if choice cancelled)
# uses:   Term::Clui
method input_choose ($prompt, @options) {

    # process args
    if ( not @options ) { return; }
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) { $prompt = $self->_script . ': ' . $prompt; }

    # get user selection
    return Term::Clui::choose( $prompt, @options );
}

# input_confirm($question, [$prepend])    {{{1
#
# does:   user answers y/n to a question
# params: $question - question to be answered with yes or no
#                     [required, can be multi-line (use "\n")]
#         $prepend  - whether to prepend scrip name to question
#                     [named parameter, options, default=false]
# prints: user interaction
#         after user answers, all but first line of question
#           is removed from the screen
#         answer also remains on screen
# return: scalar boolean
# usage:  my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
#         if ( input_confirm($prompt) ) {
#             # do stuff
#         }
# uses:   Term::Clui
method input_confirm ($question, @options) {

    # set variables
    if ( not $question ) { return; }
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) { $question = $self->_script . ': ' . $question; }

    # get user response
    return Term::Clui::confirm($question);
}

# input_large($prompt, [$default],[$prepend])    {{{1
#
# does:   get input from user
# params: $prompt  - user prompt [required]
#         $default - default input [optional, default=q{}]
#         $prepend - whether to prepend scrip name to prompt
#                    [named parameter, options, default=false]
# prints: user interaction
# return: user input (list, split on newlines)
# note:   intended for entering lathe, multi-line values
#         for short values, where prompt and response will easily fit
#           on one line, use method'input_ask'
# uses:   Term::Clui
method input_large ($prompt, $default, @options) {

    # set variables
    if ( not $prompt ) { return; }
    ( my $prepend, @options )
        = $self->extract_key_value( 'prepend', @options );
    if ($prepend) { $prompt = $self->_script . ': ' . $prompt; }
    my $rule = q{-} x 60;
    my $content
        = "[Everything to first horizontal rule will be deleted]\n"
        . $prompt . "\n"
        . $rule . "\n"
        . $default;

    # get user input
    # - put into list splitting on newline
    my @data = split /\n/xsm, Term::Clui::edit( $prompt, $content );

    # get index of horizontal rule
    # - first line if no horizontal rule
    my ( $index, $rule_index ) = ( 1, 0 );
    foreach my $line (@data) {
        chomp $line;
        if ( $line =~ /^-+$/xsm ) {
            $rule_index = $index;
        }
        $index++;
    }

    # return user input lines following horizontal rule
    if (@data) {
        return join "\n", @data[ $rule_index .. $#data ];
    }
    else {
        return;
    }
}

# internet_connection([$verbose])    {{{1
#
# does:   determine whether an internet connection can be found
# params: $verbose - whether to provide feedback [optional, default=false]
# prints: feedback if requested
# return: boolean
# uses:   Net::Ping::External
method internet_connection ($verbose = $FALSE) {
    my $connected;
    my @urls         = $self->_ping_urls;
    my $max_attempts = scalar @urls;
    my $timeout      = 1;                        # seconds
    if ($verbose) {
        say "Checking internet connection (maximum $max_attempts attempts):";
    }
    while ( my ( $index, $url ) = each @urls ) {
        my $attempt_number = $index + 1;
        if ($verbose) { print "  Attempt $attempt_number... "; }
        if (Net::Ping::External::ping(
                hostname => $url,
                timeout  => $timeout,            # appears to be ignored
            )
            )
        {
            $connected = $TRUE;
            if ($verbose) { say 'OK'; }
            last;
        }
        else {
            if ($verbose) { say 'Failed'; }
        }
    }
    if ($connected) {
        if ($verbose) { say 'Internet connection detected'; }
        return $TRUE;
    }
    else {
        if ($verbose) { say 'No internet connection detected'; }
        return;
    }
}

# is_android_directory($path)    {{{1
#
# does:   determine whether path is an android directory
# params: $path - path to check [required]
# prints: nil, except error messages
# return: boolean (dies if no path provided)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
method is_android_directory ($path) {
    if ( not $path ) { $path = q{}; }
    my $type = 'dir';
    return $self->_is_android_file_or_dir( $path, $type );
}

# is_android_file($path)    {{{1
#
# does:   determine whether path is an android file
# params: $path - path to check [required]
# prints: nil, except error messages
# return: boolean (dies if no path provided)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
method is_android_file ($path) {
    if ( not $path ) { $path = q{}; }
    my $type = 'file';
    return $self->_is_android_file_or_dir( $path, $type );
}

# is_boolean($value)    {{{1
#
# does:   determine whether supplied value is boolean
# detail: checks whether value is one of: 'yes', 'true', 'on', 1,
#         'no, 'false, 'off' or 0
# params: $value - value to be analysed [required]
# prints: nil
# return: boolean (undefined if no value provided)
method is_boolean ($value) {
    if ( not defined $value ) { return; }
    $value = $self->boolise($value);
    return $value =~ /(^1$|^0$)/xsm;
}

# is_deb($filepath)    {{{1
#
# does:   determine whether file is a debian package file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_deb ($filepath) {
    if ( not $filepath ) {
        cluck 'No filepath provided';
        return;
    }
    if ( not -r $filepath ) {
        cluck "Invalid filepath '$filepath'";
        return;
    }
    my @mimetypes
        = ( 'application/x-deb', 'application/vnd.debian.binary-package', );
    foreach my $mimetype (@mimetypes) {
        if ( $self->_is_mimetype( $filepath, $mimetype ) ) {
            return $TRUE;
        }
    }
    return;
}

# is_mp3($filepath)    {{{1
#
# does:   determine whether file is an mp3 file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_mp3 ($filepath) {
    if ( not $filepath ) {
        cluck 'No filepath provided';
        return;
    }
    if ( not -r $filepath ) {
        cluck "Invalid filepath '$filepath'";
        return;
    }
    return $self->_is_mimetype( $filepath, 'audio/mpeg' );
}

# is_mp4($filepath)    {{{1
#
# does:   determine whether file is an mp3 file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_mp4 ($filepath) {
    if ( not $filepath ) {
        cluck 'No filepath provided';
        return;
    }
    if ( not -r $filepath ) {
        cluck "Invalid filepath '$filepath'";
        return;
    }
    return $self->_is_mimetype( $filepath, 'video/mp4' );
}

# is_perl($filepath)    {{{1
#
# does:   determine whether file is a perl file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
method is_perl ($filepath) {
    if ( not $filepath ) {
        cluck 'No filepath provided';
        return;
    }
    if ( not -r $filepath ) {
        cluck "Invalid filepath '$filepath'";
        return;
    }

    # check for mimetype match
    if ( $self->_is_mimetype( $filepath, 'application/x-perl' ) ) {
        return $TRUE;
    }

    # mimetype detection can fail if filename has no extension
    # look for shebang and see if it is a perl interpreter
    my $fh;
    if ( not( open $fh, '<', $filepath ) ) {
        confess "Unable to open file '$filepath' for reading";
    }
    my @lines = <$fh>;
    if ( not( close $fh ) ) {
        confess "Unable to close file '$filepath'";
    }
    chomp @lines;
    foreach my $line (@lines) {
        if ( $line =~ /^ \s* [#] [!] (\S+) /xsm ) {
            my $interpreter = $1;
            my $executable  = $self->get_filename($interpreter);
            return $TRUE if $executable eq 'perl';
            last;
        }
    }
    return;
}

# join_dir($dir)    {{{1
#
# does:   concatenates list of directories in path to string path
# params: $dir - directory parts (arrayref) [required]
# prints: nil
# return: scalar string path
#         die on error
# uses: File::Spec
method join_dir ($dir) {
    if ( ref $dir ne 'ARRAY' ) {
        confess "Directory parameter is not an arrayref: $dir";
    }
    my @dir_parts = @{$dir};
    if ( not @dir_parts ) { return; }
    return File::Spec->catdir(@dir_parts);
}

# kde_desktop()    {{{1
#
# does:   determine whether running KDE
# params: nil
# prints: nil
# return: scalar boolean
# uses:   Desktop::Detect
method kde_desktop () {

    # try Desktop::Detect module (currently does not work on kde5)
    my $desktop = Desktop::Detect->detect_desktop()->{desktop};
    if ( $desktop eq 'kde-plasma' ) { return $TRUE; }

    # directly inspect $DESKTOP_SESSION (for kde5)
    if ( $DESKTOP_SESSION eq 'plasma' ) { return $TRUE; }

    # if those tests failed, then presumably not kde
    return;
}

# konsolekalendar_date_format($date)    {{{1
#
# does:   get date formatted as konsolekalendar does in its output
#         example date value is 'Tues, 15 Apr 2008'
#         corresponding strftime format string is '%a, %e %b %Y'
# params: $date - ISO formatted date [optional, default=today]
# prints: nil
# return: scalar date string
method konsolekalendar_date_format ($date) {

    # get date
    if ( not $date ) { $date = $self->today(); }
    if ( not $self->valid_date($date) ) { return; }

    # reformat
    my $format = '%a, %e %b %Y';
    my $d      = Date::Simple->new($date)->format($format);
    $d =~ s/  / /gsm;                        # dates 1-9 have leading space
    return $d;
}

# kill_process($pid)    {{{1
#
# does:   kill process
# params: $pid - process id [required]
# prints: nil, except if fails
# return: list ($success, $err)
method kill_process ($pid) {

    # check arg
    if ( not $pid ) { confess 'No pid provided'; }
    if ( not $self->pid_running($pid) ) {
        cluck "PID $pid is not running";
        return ( $FALSE, "PID $pid was not running" );
    }

    # attempt to kill process
    my @signals = qw(TERM INT HUP KILL);    # 15, 2, 1, 9
    foreach my $signal (@signals) {
        kill $signal, $pid;
        last if not $self->pid_running($pid);
        Time::HiRes::usleep(250);
    }

    # report success
    if ( $self->pid_running($pid) ) {
        return ( $FALSE, "Unable to kill process $pid" );
    }
    else {
        return ($TRUE);
    }
}

# listify(@items)    {{{1
#
# does:   tries to convert scalar, array and hash references to scalars
# params: @items - items to convert to lists [required]
# prints: warnings for other reference types
# return: list
method listify (@items) {
    my ( @scalars, $scalar, @array, %hash );
    for my $item (@items) {
        my $ref = ref $item;
        if ($ref) {
            for ($ref) {
                if (/SCALAR/xsm) {
                    $scalar = ${$item};
                    push @scalars, $self->listify($scalar);
                }
                elsif (/ARRAY/xsm) {
                    @array = @{$item};
                    foreach my $element (@array) {
                        push @scalars, $self->listify($element);
                    }
                }
                elsif (/HASH/xsm) {
                    %hash = %{$item};
                    foreach my $key ( keys %hash ) {
                        push @scalars, $self->listify($key);
                        push @scalars, $self->listify( $hash{$key} );
                    }
                }
                else {
                    cluck "Cannot listify a '$ref'";
                    say 'Item dump:';
                    say q{-} x 30;
                    cluck Dumper($item);
                    say q{-} x 30;
                }
            }
        }
        else {
            push @scalars, $item;
        }
    }
    if ( not @scalars ) { return; }
    return @scalars;
}

# local_timezone()    {{{1
#
# does:   get local timezone
# params: nil
# prints: nil
# return: scalar string
method local_timezone () {
    return DateTime::TimeZone->new( name => 'local' )->name();
}

# logger($message, [$type])    {{{1
#
# does:   write message to system logs
# params: $message - message content [required]
#         $type    - message type ['debug'|'notice'|'warning'|'error']
#                   [optional, default='notice']
# prints: nil
# return: nil
# note:   not all message types appear in all system logs -- on debian,
#         for example, /var/log/messages records only notice and warning
#         log messages while /var/log/syslog records all log messages
# uses:   Logger::Syslog
method logger ($message, $type = 'notice') {

    # set and check variables
    return if not $message;
    $type =~ s/(.*)/\L$1/gxsm;               # lowercase
    my %valid_type = map {$_ => $TRUE } qw(debug notice warning error);
    if (not(exists $valid_type{$type})) { confess "Invalid type '$type'";}

    # log message
    my $dispatch = {
      debug => \&Logger::Syslog::debug,
      notice => \&Logger::Syslog::notice,
      warning => \&Logger::Syslog::warning,
      error => \&Logger::Syslog::error,
    };
    $dispatch->{$type}->($message);
    #for ($type) {
    #    if    ($_ =~ /^debug$/xsm)   { Logger::Syslog::debug($message) }
    #    elsif ($_ =~ /^notice$/xsm)  { Logger::Syslog::notice($message) }
    #    elsif ($_ =~ /^warning$/xsm) { Logger::Syslog::warning($message) }
    #    elsif ($_ =~ /^error$/xsm)   { Logger::Syslog::error($message) }
    #    else                         { confess "Invalid type '$type'" }
    #}

    return;
}

# make_dir($dir_path)    {{{1
#
# does:   make directory recursively
# params: $dir_path - directory path [required]
# prints: nil
# return: boolean (whether created)
# note:   if directory already exists does nothing but return true
# uses:   File::Util
method make_dir ($dir_path) {
    if ( not $dir_path ) { confess 'No directory path provided'; }
    File::Util->new()->make_dir( $dir_path, { if_not_exists => $TRUE } )
        or confess "Unable to create '$dir_path'";
}

# moox_option_bool_is_true($value)    {{{1
#
# does:   determine whether boolean MooX::Option option value is true
# params: $value - value of option [required]
# prints: nil, except error
# return: boolean, dies on failure
# note:   when true value is '1'
#         when false value is '[]', which evaluates as true
method moox_option_bool_is_true ($value) {
    if ( not( defined $value ) ) { confess 'No option value provided'; }
    for ( ref $value ) {
        if ( $_ eq q{} )     { return $value; }       # scalar
        elsif ( $_ eq 'ARRAY' ) { return @{$value}; }    # array ref
        else { confess "Value is a $_ reference"; }  # neither
    }
}

# msg_box([$msg], [$title])    {{{1
#
# does:   display message in gui dialog
# params: $msg   - message [optional, default='Press OK button to proceed']
#         $title - dialog title [optional, default=scriptname]
# prints: nil
# return: nil
# uses:   UI::Dialog
method msg_box ($msg, $title) {
    if ( not $title ) { $title = $self->scriptname(); }
    if ( not $msg )   { $msg   = 'Press OK button to proceed'; }
    my @widget_preference = $self->_ui_dialog_widget_preference();
    my $ui = UI::Dialog->new( order => [@widget_preference] );
    return $ui->msgbox( title => $title, text => $msg );
}

# notify(@messages, [$prepend])    {{{1
#
# does:   display console message
# params: @messages - message lines [required]
#         $prepend  - whether to prepend script name to message lines
#                     named parameter, boolean, optional, default=false
# prints: messages
# return: nil
# usage:  $cp->notify('File path is:', $filepath);
#         $cp->notify('File path is:', $filepath, prepend => $TRUE);
# note:   respects newline if enclosed in double quotes
method notify (@messages) {

    # set prepend flag and display messages
    my ( $prepend, @messages )
        = $self->extract_key_value( 'prepend', @messages );

    # set prefix
    my $prefix = ($prepend) ? $self->_script . ': ' : q{};

    # display messages
    for my $message (@messages) {
        say "$prefix$message";
    }
}

# notify_sys($msg, [$title], [$type], [$icon], [$time])    {{{1
#
# does:   display message to user in system notification area
# params: $msg   - message content [required]
#         $title - message title
#                  [named parameter, optional, falls back to attribute
#                   'notify_sys_title' then falls back to calling script name]
#         $type  - 'info'|'question'|'warn'|'error'
#                  [named parameter, optional, falls back to attribute
#                   'notify_sys_type' then falls back to 'info']
#         $icon  - message icon filepath
#                  [named parameter, optional, falls back to attribute
#                   'notify_sys_icon_path', otherwise no default]
#         $time  - message display time (msec)
#                  [named parameter, optional, default=10,000]
# return: boolean, whether able to display notification
# usage:  $cp->notify_sys('Operation successful!', title => 'Outcome');
# alert:  do not call this method from a spawned child process --
#         the 'show()' call in the last line of this method causes
#         the child process to hang without any feedback to user
# note:   not guaranteed to respect newlines
# uses:   Net::DBus
method notify_sys ($msg, :$title, :$type, :$icon, :$time) {

    # parameters
    # - msg
    if ( not $msg ) { return; }

    # - title
    if ( not $title ) {
        if ( $self->_notify_sys_title ) {
            $title = $self->_notify_sys_title;
        }
        else {
            $title = $self->_script;
        }
    }

    # - type
    my %is_valid_type = map { ( $_ => 1 ) } qw/info question warn error/;
    if ( not( $type and $is_valid_type{$type} ) ) {
        if ( $self->_notify_sys_type ) {
            $type = $self->_notify_sys_type;
        }
        else {
            $type = 'info';
        }
    }

    # - icon
    if ( not( $icon and -e $icon ) ) {
        if ( $self->_notify_sys_icon ) {
            $icon = $self->_notify_sys_icon;
        }
        else {
            $icon = $type eq "info"     ? $self->_icon_info
                  : $type eq "question" ? $self->_icon_question
                  : $type eq "warn"     ? $self->_icon_warn
                  : $type eq "error"    ? $self->_icon_error
                  :                       undef;
            if (not defined($icon)) { confess "Invalid type '$type'"; }
        }
    }

    # - time
    if ( not( $time and $time =~ /^[1-9]\d+\z/xsm ) ) {
        $time = 10_000;
    }

    # display notification popup
    my $bus = Net::DBus->session;
    my $svc = $bus->get_service('org.freedesktop.Notifications');
    my $obj = $svc->get_object('/org/freedesktop/Notifications');
    $obj->Notify( $self->_script, 0, $icon, $title, $msg, [], {}, $time );
    return;
}

# now()    {{{1
#
# does:   provide current time ('HH::MM::SS')
# params: nil
# prints: nil
# return: scalar string
method now () {
    return Time::Simple->new()->format;
}

# number_list(@items)    {{{1
#
# does:   prefix each list item with element index (base = 1)
#         prefix is left padded so each is the same length
# params: @items - list to be modified [required]
# prints: nil
# return: list
# note:   map operation extracted to method as per Perl Best Practice
method number_list (@items) {
    if ( not @items ) { return; }
    my $prefix_length = length scalar @items;
    my $index         = 1;
    my @numbered_list
        = map { $self->_add_numeric_prefix( $_, $prefix_length ) } @items;
    return @numbered_list;
}

method _add_numeric_prefix ($item, $prefix_length) {
    state $index = 1;
    my $index_width   = length $index;
    my $padding_width = $prefix_length - $index_width;
    my $padding       = q{ } x $padding_width;
    my $prefix        = "$padding$index. ";
    $index++;
    $item = "$prefix$item";
    return $item;
}

# offset_date($offset)    {{{1
#
# does:   get a date offset from today
# params: $offset - offset in days [required]
#                   can be positive or negative
# prints: nil
# return: ISO-formatted date (die if fails)
# uses:   Date::Simple
method offset_date ($offset) {
    if ( not( $offset and $self->valid_integer($offset) ) ) { return; }
    my $date = Date::Simple->today() + $offset;
    return $date->format('%Y-%m-%d');
}

# pager($lines)    {{{1
#
# does:   display list of lines in terminal using pager
# params: $lines  - array reference [required]
#         $prefer - preferred pager, used if it is found on the system
#                   [optional, no default]
# prints: paged lines
# return: n/a, die on failure
# note:   pager used depends on IO::Pager algorithm
# note:   does not matter whether lines have terminal newlines or not
# note:   often used with method 'do_wrap' to format screen display
# uses:   IO::Pager
method pager ($lines, $prefer) {

    # check args
    if ( not $lines ) { confess 'No lines provided'; }
    my $ref_type = ref $lines;
    if ( $ref_type ne 'ARRAY' ) { confess 'Not an array reference'; }
    my $default_pager;
    if ( $prefer and $self->executable_path($prefer) and $prefer ne $PAGER ) {
        $default_pager = $PAGER;
        $PAGER         = $prefer;
    }

    # display lines
    my @output = @{$lines};
    chomp @output;
    my $pager = IO::Pager->new();
    foreach my $line (@output) {
        $pager->print("$line\n");
    }

    # restore default pager
    if ($default_pager) { $PAGER = $default_pager; }
}

# parent_dir($dir)    {{{1
#
# does:   return parent directory
# params: $dir - directory path to analyse [required]
# prints: nil
# return: scalar (absolute directory path)
# note:   converts to, and returns, absolute path
method parent_dir ($dir) {
    if ( not $dir ) { confess 'No path provided'; }
    my @dir_path = $self->path_split( $self->true_path($dir) );
    pop @dir_path;         # remove current dir to get parent
    return $self->join_dir( [@dir_path] );
}

# path_split($path)    {{{1
#
# does:   split directory or file path into component elements
# params: $path - directory or file path to split [required]
#                 need not exist
# prints: nil
# return: list
# uses:   File::Spec
method path_split ($path) {

    # check arg
    if ( not $path ) { confess 'No path provided'; }

    # get path parts
    my ( $volume, $dir, $file ) = File::Spec->splitpath(shift);
    my @path;

    # process volume
    if ($volume) { push @path, $volume; }

    # process directory
    # - last directory item can be empty
    if ($dir) { push @path, File::Spec->splitdir($dir); }
    my $final = pop @path;    # keep last item if not empty
    if ($final) { push @path, $final; }

    # process file
    if ($file) { push @path, $file; }

    # return result
    return @path;
}

# pid_command($pid)    {{{1
#
# does:   get command for given process id
# params: $pid - process id [required]
# prints: nil, except error messages
# return: scalar string (process command)
method pid_command ($pid) {
    if ( not $pid ) { confess 'No pid providede'; }
    if ( not $self->pid_running($pid) ) {
        warn "PID $pid is not running\n";
        return;
    }
    return $self->_command($pid);
}

# pid_running($pid)    {{{1
#
# does:   determines whether process id is running
#         reloads processes each time method is called
# params: $pid - pid to look for [required]
# prints: nil
# return: boolean scalar
method pid_running ($pid) {
    if ( not $pid ) { return; }
    $self->_reload_processes;
    my @pids = $self->_pids();
    return scalar grep {/^$pid$/xsm} @pids;    # force scalar context
}

# pluralise($string, $numeric)    {{{1
#
# does:   adjust string based on provided numerical value
# params: $string - string to adjust [required]
#         $number - integer value [required]
# prints: nil
# return: scalar string
# note:   passes values straight through to Text::Pluralizer::pluralize
# uses:   Text::Pluralizer
method pluralise ($string, $number) {

    # check args
    if ( not( defined $string ) ) { confess 'No string provided'; }
    if ( not $string )            { return q{}; }
    if ( not $number )            { confess "No number provided"; }
    if ( not $self->valid_positive_integer($number) ) {
        confess "Number '$number' is not an integer";
    }

    # use Text::Pluralize
    return Text::Pluralize::pluralize( $string, $number );
}

# process_children($pid)    {{{1
#
# does:   gets child processes of a specified pid
# params: $pid - pid to analyse [required]
# prints: nil, except errors
# return: list of pids
method process_children ($pid) {

    # check arg
    if ( not $pid ) { confess 'No pid provided'; }
    if ( not $self->pid_running($pid) ) {
        confess "PID '$pid' is not running";
    }

    # get child processes
    my $t = Proc::ProcessTable->new();
    return map { $_->pid() } grep { $_->ppid() == $pid } @{ $t->table() };
}

# process_ids($cmd_re, [$silent])    {{{1
#
# does:   get process ids for command
# params: $cmd_re - regular expression to match against ps output [required]
#         $silent - whether to suppress warnings about no/multiple matches
#                   [named parameter, optional, default=false]
# prints: warning (if not suppressed)
# return: list of scalar integers
method process_ids ($cmd_re, :$silent = $FALSE) {

    # set and check variables
    if ( not $cmd_re ) { return; }
    $self->_reload_processes;
    my @pids = $self->_pids;

    # search process commands for matches
    my @matching_pids;
    foreach my $pid (@pids) {
        my $cmd = $self->_command($pid);
        if ( $cmd =~ $cmd_re ) {
            push @matching_pids, $pid;
        }
    }

    # provide warning if triggered and feedback requested
    if ( not $silent ) {
        my $match_count = scalar @matching_pids;
        if ( $match_count == 0 ) {
            warn "No matches for process command '$cmd_re'\n";
        }
        if ( $match_count > 1 ) {
            my $msg = "Multiple ($match_count) matches for "
                . "process command '$cmd_re'\n";
            cluck $msg;
        }
    }

    # return matches
    return @matching_pids;
}

# process_parent($pid)    {{{1
#
# does:   gets parent process of a specified pid
# params: $pid - pid to analyse [required]
# prints: nil, except errors
# return: scalar int (pid)
method process_parent ($pid) {

    # check arg
    if ( not $pid ) { confess 'No pid provided'; }
    if ( not $self->pid_running($pid) ) {
        confess "PID '$pid' is not running";
    }

    # get parent process
    my $t = Proc::ProcessTable->new();
    my @parents
        = map { $_->ppid() } grep { $_->pid() == $pid } @{ $t->table() };
    my $parent_count = scalar @parents;
    if ( $parent_count == 0 ) { confess 'No parent PIDs found'; }
    if ( $parent_count > 1 )  { confess 'Multiple parent PIDs found'; }
    return $parents[0];
}

# process_running($regex)    {{{1
#
# does:   determine whether process is running
# params: $regex       - regular expression to match against ps output
#                        [required]
# prints: nil
# return: boolean
method process_running ($regex) {

    # set and check variables
    if ( not $regex ) { return; }
    $self->_reload_processes;
    my @cmds = $self->_commands;

    # search process commands for matches
    return scalar grep {/$regex/xsm} @cmds;
}

# prompt([message])    {{{1
#
# does:   display message and prompt user to press any key
# params: message - prompt message [optional]
#                   [default='Press any key to continue...']
# prints: prompt message
# return: nil
method prompt ($message) {
    if ( not $message ) { $message = 'Press any key to continue... '; }
    print $message;
    Term::ReadKey::ReadMode('raw');
    while ($TRUE) {
        my $key = Term::ReadKey::ReadKey(0);
        last if defined $key;
    }
    Term::ReadKey::ReadMode('restore');
    print "\n";
}

# push_arrayref($arrayref, @items)    {{{1
#
# does:   add items to arrayref
# params: $arrayref - array reference to add to [required]
#         @items    - items to add [required]
# prints: nil, except error messages
# return: array reference (dies on failure)
method push_arrayref ($arrayref, @items) {

    # check args
    if ( not @items )    { confess 'No items provided'; }
    if ( not $arrayref ) { confess 'No array reference provided'; }
    my $ref_type = ref $arrayref;
    if ( $ref_type ne 'ARRAY' ) { confess 'Not an array reference'; }

    # add items
    my @list = @{$arrayref};
    push @list, @items;
    return [@list];
}

# restore_screensaver([$title])    {{{1
#
# does:   restores suspended screensaver
# params: $title - title of message box [optional, default=scriptname]
# prints: nil (feedback via popup notification)
# return: boolean
# uses:   Net::DBus::RemoteObject
#         DBus service org.freedesktop.ScreenSaver
method restore_screensaver ($title) {
    if ( not $title ) { $title = $self->_script; }
    my $type = $self->_screensaver_type;

    # handle based on screensaver type
    for ($type) {
        if (/^kde\z/xsm) { return $self->_restore_kde_screensaver($title); }
        elsif (/^x\z/xsm)   { return $self->_restore_xscreensaver(); }
        else {
            my $msg = 'Unable to manipulate ';
            if ($type) { $msg .= "'$type'"; }
            else       { $msg = 'Cannot detect any screensaver'; }
            $self->notify_sys( $msg, title => $title, type => 'error' );
        }
    }
    return;
}

# retrieve_store($file)    {{{1
#
# does:   retrieves function data from storage file
# params: $file - file in which data is stored [required]
# prints: nil (except feedback from Storage module)
# return: boolean
# uses:   Storable
# usage:  my $storage_file = '/path/to/filename';
#         my $ref = $self->retrieve_store($storage_file);
#         my %data = %{$ref};
method retrieve_store ($file) {
    if ( not -r $file ) { confess "Cannot read file '$file'"; }
    return Storable::retrieve $file;
}

# run_command($cmd, [$silent], [$fatal])    {{{1
#
# does:   run system command
# params: $cmd    - command to run
#                   [array reference, required]
#         $silent - suppress output
#                   if false displays command, shell feedback and,
#                   if command failed, a failure message
#                   [named parameter, boolean, optional,
#                    default to attribute 'run_command_silent' if defined,
#                    otherwise to false]
#         $fatal  - whether to die on failed command
#                   [named parameter, boolean, optional,
#                    default to attribute 'run_command_fatal' if defined,
#                    otherwise to false]
# prints: display all shell feedback
# return: scalar context: boolean
#         list context: boolean, error message
# note:   command feedback, if provided, is displayed after command
#         execution completes -- for a long-running command this can
#         result in an apparently unresponsive terminal
# uses:   Curses, IPC::Cmd
method run_command ($cmd, :$silent, :$fatal) {

    # process arguments
    # - $cmd
    if ( not( defined $cmd ) ) { confess 'No command provided'; }
    my $arg_type = ref $cmd;
    if ( $arg_type ne 'ARRAY' ) {
        confess 'Command is not array reference';
    }
    my @cmd_args = @{$cmd};
    if ( not @cmd_args ) { confess 'No command arguments provided'; }

    # - silent/verbose
    if ( not( defined $silent ) ) {
        if ( defined $self->_run_command_silent ) {
            $silent = $self->_run_command_silent;
        }
    }
    my $verbose = not $silent;

    # - fatal
    if ( not( defined $fatal ) ) {
        if ( defined $self->_run_command_fatal ) {
            $fatal = $self->_run_command_fatal;
        }
    }

    # build dividers
    my ( $div_top, $div_bottom );
    if ( not $silent ) {
        my ( $height, $width );
        my $mwh = Curses->new();
        $mwh->getmaxyx( $height, $width );    # terminal dimensions
        endwin();
        if ( $width > 61 ) { $width = 60; }
        else               { $width--; }
        $div_top    = q{-} x $width;
        $div_bottom = q{=} x $width;
    }

    # provide initial feedback
    my $cmd_string;
    if ( not $silent ) {
        say q{ };
        $cmd_string = join q{ }, @cmd_args;
        say "Running '$cmd_string':";
        say $div_top;
    }

    # run command
    my ( $succeed, $err, $full, $stdout, $stderr )
        = IPC::Cmd::run( command => $cmd, verbose => $verbose );

    # provide final feedback
    if ($verbose) {

        # errors supposedly displayed during execution,
        # but show again to be sure
        if ($err) { warn "$err\n"; }
        say $div_bottom;
        if ( not $succeed ) { say "Command failed\n"; }
    }

    if ( $fatal and not $succeed ) {
        if ( not $err ) { warn "No error message available\n"; }
        my $msg = 'Stopping execution due to error';
        if   ($verbose) { die "$msg\n"; }    # errors already displayed
        else            { confess $msg; }    # break silence now
    }

    # return
    return (wantarray) ? ( $succeed, $err ) : $succeed;
}

# save_store($ref, $file)    {{{1
#
# does:   store data structure in file
# params: $ref  - reference to data structure to be stored
#         $file - file path in which to store data
# prints: nil (except feedback from Storable module)
# return: boolean
# uses:   Storage
# usage:  my $storage_dir = '/path/to/filename';
#         $self->save_store( \%data, $storage_file );
method save_store ($ref, $file) {
    if ( not $ref ) { return; }

    # path must exist
    my $path = $self->get_path($file);
    if ( $path && !-d $path ) {
        confess "Invalid path in '$file'";
    }

    # will overwrite, but warn user
    if ( -e $file ) {
        cluck "Overwriting '$file'";
    }

    # save data
    return Storable::store $ref, $file;
}

# scriptname    {{{1
#
# does:   gets name of executing script
# params: nil
# prints: nil
# return: scalar file name
method scriptname () {
    return $self->_script;
}

# sequential_24h_times($time1, $time2)    {{{1
#
# does:   determine whether supplied times are in chronological
#         sequential, i.e., second time occurs after first time
#         assume both times are from the same day
# params: $time1 - first time to compare, 24 hour time [required]
#         $time2 - second time to compare, 24 hour time [required]
# prints: nil (error if invalid time)
# return: boolean (dies if invalid time)
method sequential_24h_times ($time1, $time2) {

    # check times
    if ( not $self->valid_24h_time($time1) ) {
        confess "Invalid time '$time1'";
    }
    if ( not $self->valid_24h_time($time2) ) {
        confess "Invalid time '$time2'";
    }

    # compare
    my $t1 = Time::Simple->new($time1);
    my $t2 = Time::Simple->new($time2);
    return ( $t2 > $t1 );
}

# sequential_dates($date1, $date2)    {{{1
#
# does:   determine whether supplied dates are in chronological sequence
# params: $date1 - first date, ISO-formatted [required]
#         $date1 - second date, ISO-formatted [required]
# prints: nil (error if invalid dates)
# return: boolean (die on failure)
method sequential_dates ($date1, $date2) {

    # check dates
    if ( not $date1 ) { confess 'Missing date'; }
    if ( not $date2 ) { confess 'Missing date'; }
    if ( not $self->valid_date($date1) ) {
        confess "Invalid date '$date1'";
    }
    if ( not $self->valid_date($date2) ) {
        confess "Invalid date '$date2'";
    }

    # compare dates
    my $d1 = Date::Simple->new($date1);
    my $d2 = Date::Simple->new($date2);
    return ( $d2 > $d1 );
}

# shared_module_file_milla($dist, $file)    {{{1
#
# does:   gets filepath of file in 'share' directory
#         of milla project
# params: $file - file name [required]
# prints: nil
# return: scalar file path (undef if not found)
#         (so also functions as boolean)
method shared_module_file_milla ($dist, $file) {
    if ( not $file ) { confess 'No file provided'; }
    if ( not $dist ) { confess 'No dist provided'; }
    my $branch = "auto/share/dist/$dist/$file";
    my $fp;
    for my $root (@INC) {
        if ( -e "$root/$branch" ) {
            $fp = "$root/$branch";
            last;
        }
    }
    return $fp;
}

# shell_underline($string)    {{{1
#
# does:   underline string
# params: $string - string to underline
# prints: nil
# return: string with enclosing shell commands
method shell_underline ($string) {
    if ( not $string )         { return; }
    if ( length $string == 0 ) { return $string; }
    my $underline_on  = q{\033[4m};
    my $underline_off = q{\033[24m};
    return $underline_on . $string . $underline_off;
}

# shorten($string, [$limit], [$cont])    {{{1
#
# does:   truncate text if too long
# params: $string - string to shorten [required]
#         $length - length at which to truncate, must be > 10
#                   [optional, default=72]
#         $cont   - continuation sequence at end of truncated string
#                   must be no longer than three characters
#                   [optional, default='...']
# prints: nil
# return: scalar string
method shorten ($string, $limit, $cont) {

    # variables
    my $default_limit = 72;
    my $default_cont  = '...';

    # - cont
    if ( not $cont ) {
        $cont = $default_cont;
    }
    if ( length $cont > 3 ) {
        cluck "Continuation sequence '$cont' too long; using default '$cont'";
        $cont = $default_cont;
    }

    # - limit
    if ( not $limit ) {
        $limit = $default_limit;
    }
    if ( not $self->valid_positive_integer($limit) ) {
        cluck "Non-integer '$limit'; using default '$default_limit'";
        $limit = $default_limit;
    }
    if ( $limit <= 10 ) {
        cluck "Limit '$limit' too short; using default '$default_limit'";
        $limit = $default_limit;
    }
    $limit = $limit - length $cont;

    # - string
    if ( not $string ) {
        confess q{No parameter 'string' provided at};
    }

    # truncate if necessary
    if ( length($string) > $limit ) {
        $string = substr( $string, 0, $limit - 1 ) . $cont;
    }

    return $string;
}

# suspend_screensaver([$title], [$msg])    {{{1
#
# does:   suspends kde screensaver if present
# params: $title - title of message box [optional, default=scriptname]
#         $msg   - message explaining suspend request
#                 [optional, default='request from $PID']
#                 example: 'running smplayer'
# prints: nil (feedback via popup notification)
# return: boolean
method suspend_screensaver ($title, $msg) {
    if ( not $title ) { $title = $self->_script; }
    if ( not $msg )   { $msg   = "request from $PID"; }

    # handle based on screensaver type
    my $type = $self->_screensaver_type;
    for ($type) {
        if ($_ =~ /^kde\z/xsm) {
            return $self->_suspend_kde_screensaver( $title, $msg );
        }
        elsif ($_ =~ /^x\z/xsm) {
            return $self->_suspend_xscreensaver( $title, $msg );
        }
        else {    # presume no screensaver, so exit with success
            my $msg = 'Unable to manipulate ';
            if ($type) { $msg .= "'$type'"; }
            else       { $msg = 'No screensaver detected'; }
            $self->notify_sys( $msg, title => $title );
            return $TRUE;
        }
    }
    return;
}

# tabify($string, [$tab_size])    {{{1
#
# does:   covert tab markers ('\t') to spaces
# params: $string   - string to convert [required]
#         $tab_size - size of tab in characters [optional, default=4]
# prints: nil
# return: scalar string
method tabify ($string = q//, $tab_size = 4) {

    # set tab
    if ( $tab_size !~ /^[1-9]\d*\z/xsm ) { $tab_size = 4; }
    my $tab = q{ } x $tab_size;

    # convert tabs
    $string =~ s/\\t/$tab/gxsm;
    return $string;
}

# temp_dir()    {{{1
#
# does:   create temporary directory
# params: nil
# prints: nil
# return: scalar directory path
# uses:   File::Temp
method temp_dir () {
    return File::Temp::tempdir( CLEANUP => $TRUE );
}

# term_size()    {{{1
#
# does:   get terminal size
# params: nil
# prints: nil
# return: Dn::Common::TermSize instance
# usage:  my $height = $cp->term_size->height;
#         my $width = $cp->term_size->width;
# usage:  my $ts = $cp->term_size;
#         my ( $height, $width ) = ( $ts->height, $ts->width );
# uses:   Curses
method term_size () {
    return Dn::Common::TermSize->new();
}

# timezone_from_offset($offset)    {{{1
#
# does:   determine timezone for offset
# params: $offset - timezone offset to check [required]
# prints: nil
# return: scalar string
method timezone_from_offset ($offset) {
    if ( not $offset ) { confess 'No offset provided'; }

    # get timezones for all offsets
    my @countries = DateTime::TimeZone->countries();
    my %timezone;
    foreach my $country (@countries) {
        my @names = DateTime::TimeZone->names_in_country($country);
        foreach my $name (@names) {
            my $dt = DateTime->now( time_zone => $name, );
            my $offset_seconds = $dt->offset();
            my $offset
                = DateTime::TimeZone->offset_as_string($offset_seconds);
            push @{ $timezone{$offset} }, $name;
        }
    }

    # find timezones for given offset
    if ( not $timezone{$offset} ) {
        cluck "No timezones for offset '$offset'\n";
        return;
    }
    my @timezones = sort @{ $timezone{$offset} };

    # prefer Australian timezone
    my $oz_timezone
        = List::MoreUtils::first_result { $_ if /Australia/sm } @timezones;
    if ($oz_timezone) {
        return $oz_timezone;
    }
    else {
        return $timezones[0];
    }
}

# today()    {{{1
#
# does:   get today as an ISO-formatted date
# params: nil
# prints: nil
# return: ISO-formatted date
# uses:   Date::Simple
method today () {
    return Date::Simple->today()->format('%Y-%m-%d');
}

# tools_available(@tools)    {{{1
#
# does:   check that required executables are available on system
# params: @tools - required executables [optional]
# prints: message to stderr if any tools not available
# return: scalar boolean
# usage:  if ( not $cp->tools_available( 'tar', 'gzip' ) ) { return; }
# note:   error message looks like:
#             Required executable is not available: not-here
#             Required executables are not available: not-here, me-either
method tools_available (@tools) {
    if ( not @tools ) { return; }
    my @missing = grep { not $self->executable_path($_) } @tools;
    if (@missing) {
        my $missing_tools = join q{, }, @missing;
        my $err
            = $self->pluralise(
            'Required (executable is|executables are) not available: ',
            scalar @missing )
            . $missing_tools . "\n";
        $self->display( $err, error => $TRUE );
        return;
    }
    else {
        return $TRUE;
    }
}

# trim($string)    {{{1
#
# does:   remove leading and trailing whitespace
# params: $string - string to be converted [required]
# prints: nil
# return: scalar string
method trim ($string = q//) {
    $string =~ s/^\s+//xsm;
    $string =~ s/\s+\z//xsm;
    return $string;
}

# true_path($filepath)    {{{1
#
# does:   convert relative filepath to absolute
# params: $filepath - filepath to convert [required]
# prints: nil
# return: scalar
# uses:   Cwd
# detail: if an absolute filepath is provided it is returned unchanged
# detail: Symlinks will be followed and converted to their true filepaths
# alert:  directory path does not exist
#           if the directory part of the filepath does not exist the
#           entire filepath is returned unchanged; this is a compromise --
#           there may be times when you want to normalise a non-existent
#           path, i.e, to collapse '../' parent directories; abs_path will
#           silently return an empty result if an invalid directory is
#           included in the path; since safety should always take priority,
#           the method will return the supplied filepath unchanged if the
#           directory part does not exist
# alert:  double quote variable parameter
#           if passing a variable to this function it should be double
#           quoted; if not, passing a value like './' results in an error
#           as the value is somehow reduced to an empty value
method true_path ($filepath) {
    if ( not $filepath ) { return; }

    # invalid directory path causes abs_path to fail, so return unchanged
    my $path = $self->get_path($filepath);
    if ( $path and not -d $path ) { return $filepath; }

    # do conversion
    return abs_path($filepath);
}

# valid_24h_time($time)    {{{1
#
# does:   determine whether supplied time is valid 24 hour time
# params: $time - time to evaluate, 'HH:MM' or 'HHMM' format [required]
#                 leading zero can be dropped
# prints: nil
# return: boolean
method valid_24h_time ($time) {
    if ( not $time ) { return; }

    # deal with case of 4-digit time, e.g., '0520'
    if ( $time =~ /^ ( \d{2} ) ( \d{2} ) \z/xsm ) { $time = "$1:$2"; }

    # evaluate time value
    my $value = eval { Time::Simple->new($time); 1 };
    return $value;
}

# valid_date($date)    {{{1
#
# does:   determine whether date is valid and in ISO format
# params: $date - candidate date [required]
# prints: nil
# return: boolean
method valid_date ($date) {
    if ( not $date ) { return; }
    return Date::Simple->new($date);
}

# valid_email($email)    {{{1
#
# does:   determine whether an email address is valid
# params: $email - address to check [required]
# prints: nil
# return: boolean
method valid_email ($email) {
    if ( not $email ) { return; }
    return Email::Valid->address($email);
}

# valid_integer($value)    {{{1
#
# does:   determine whether a valid integer (can be negative)
# params: $value - value to test [required]
# prints: nil
# return: boolean
method valid_integer ($value) {
    if ( not defined $value ) { return; }
    for ($value) {
        if ($_ =~ /^[+-]?0\z/xsm)        { return $TRUE; }    # zero
        elsif ($_ =~ /^[+-]?[1-9]\d*\z/xsm) { return $TRUE; }    # other int
        else                      { return; }
    }
}

# valid_positive_integer($value)    {{{1
#
# does:   determine whether a valid positive integer (zero or above)
# params: $value - value to test [required]
# prints: nil
# return: boolean
method valid_positive_integer ($value) {
    if ( not defined $value ) { return; }
    for ($value) {
        if ($_ =~ /^[+]?0$/xsm)         { return $TRUE; }    # zero
        elsif ($_ =~ /^[+]?[1-9]\d*\z/xsm) { return $TRUE; }    # above zero
        else                     { return; }
    }
}

# valid_timezone_offset($offset)    {{{1
#
# does:   determine whether a timezone offset is valid
# params: $offset - timezone offset to check
# prints: nil
# return: boolean
method valid_timezone_offset ($offset) {
    if ( not $offset ) { confess 'No offset provided'; }
    my @countries = DateTime::TimeZone->countries();
    my %is_valid_offset;
    foreach my $country (@countries) {
        my @names = DateTime::TimeZone->names_in_country($country);
        foreach my $name (@names) {
            my $dt = DateTime->new( year => 1999, time_zone => $name, );
            my $offset_seconds = $dt->offset();
            my $offset
                = DateTime::TimeZone->offset_as_string($offset_seconds);
            $is_valid_offset{$offset} = $TRUE;
        }
    }
    return $is_valid_offset{$offset};
}

# valid_web_url($url)    {{{1
#
# does:   determine whether a web address is valid
# params: $url - url to check [required]
# prints: nil
# return: boolean
method valid_web_url ($url) {
    if ( not $url ) { return; }
    my $validator = Data::Validate::URI->new();
    return $validator->is_web_uri($url);
}

# vim_list_print(@messages)    {{{1
#
# does:   prints a list of strings to the terminal screen using
#         vim's default colour scheme
# detail: see method 'vim_print' for details of the colour schemes
#         each message can be printed in a different style
#         - element strings need to be prepared using 'vim_printify'
# params: @messages - messages to display [required]
#                     can contain escaped double quotes.
# prints: messages in requested styles
# return: nil
method vim_list_print (@messages) {
    my @messages = $self->listify(@messages);
    my ( $index, $flag );
    foreach my $message (@messages) {
        for ($message) {
            ## no critic (ProhibitCascadingIfElse)
            if    ($_ =~ /^::title::/ixsm)  { $index = 9;  $flag = 't' }
            elsif ($_ =~ /^::error::/ixsm)  { $index = 9;  $flag = 'e' }
            elsif ($_ =~ /^::warn::/ixsm)   { $index = 8;  $flag = 'w' }
            elsif ($_ =~ /^::prompt::/ixsm) { $index = 10; $flag = 'p' }
            else                            { $index = 0;  $flag = 'n' }
            ## use critic
        }
        $message = substr $message, $index;
        $self->vim_print( $flag, $message );
    }
}

# vim_print($type, @messages)    {{{1
#
# does:   print text to terminal screen using vim's default colour scheme
# params: $type     - type ['title'|'error'|'warning'|'prompt'|'normal']
#                     case-insensitive, can supply partial value
#                     [required]
#         @messages - content to print [required, multi-part]
#                     can contain escaped double quotes
# prints: messages
# return: nil
# detail: five styles have been implemented:
#                  Vim
#                  Highlight
#         Style    Group       Foreground    Background
#         -------  ----------  ------------  ----------
#         title    Title       bold magenta  normal
#         error    ErrorMsg    bold white    red
#         warning  WarningMsg  red           normal
#         prompt   MoreMsg     bold green    normal
#         normal   Normal      normal        normal
# usage:  $cp->vim_print( 't', "This is a title" );
# note:   will gracefully handle arrays and array references in message list
# uses:   Term::ANSIColor
method vim_print ($type, @messages) {

    # variables
    # - messages
    @messages = $self->listify(@messages);

    # - type
    if ( not $type ) { $type = 'normal'; }

    # - attributes (to pass to function 'colored')
    my $attributes = $type eq 't' ? [ 'bold', 'magenta' ]
                   : $type eq 'p' ? [ 'bold', 'bright_green' ]
                   : $type eq 'w' ? ['bright_red']
                   : $type eq 'e' ? [ 'bold', 'white', 'on_red' ]
                   :                ['reset']
                   ;

    # print messages
    for my $message (@messages) {
        say Term::ANSIColor::colored( $attributes, $message );
    }
}

# vim_printify($type, $message)    {{{1
#
# does:   modifies a single string to be passed to 'vim_list_print'
# params: $type    - as per method 'vim_print' [required]
#         $message - content to be modified [required]
#                    can contain escaped double quotes
# prints: nil
# return: modified string
# usage:  @output = $cp->vim_printify( 't', 'My Title' );
# detail: the string is given a prefix that signals to 'vim_list_print'
#         what format to use (prefix is stripped before printing)
method vim_printify ($type, $message) {

    # variables
    # - message
    if ( not $message ) { return q{}; }

    # - type
    if ( not $type ) { $type = 'normal'; }

    # - token to prepend to message
    #my $token;
    #for ($type) {
    #    if ($_ =~ /^t/ixsm) { $token = '::title::' }
    #    elsif ($_ =~ /^p/ixsm) { $token = '::prompt::' }
    #    elsif ($_ =~ /^w/ixsm) { $token = '::warn::' }
    #    elsif ($_ =~ /^e/ixsm) { $token = '::error::' }
    #    else         { $token = q{} }
    #}
    my $token = $type =~ /^t/ixsm ? '::title::'
              : $type =~ /^p/ixsm ? '::prompt::'
              : $type =~ /^w/ixsm ? '::warn::'
              : $type =~ /^e/ixsm ? '::error::'
              :                     q{}
              ;

    # return altered string
    return "$token$message";
}

# write_file($file, $content, [$silent], [$fatal], [$no_newline])    {{{1
#
# does:   write file
# params: $file       - filepath to create [required]
#         $content    - content to write, scalar or arrayref [required]
#         $silent     - whether to suppress feedback
#                       [named parameter, optional, default=false]
#         $fatal      - whether to die on write failure
#                       [named parameter, optional, default=false]
#         $no_newline - whether to not add a terminal newline where missing
#                       [named parameter, optional, default=false]
# prints: feedback:
#         if succeeded - "Wrote file '$file'"
#         if failed - "Unable to write '$file'"
# return: boolean success
# note:   if $fatal is true and write operation fails, an error message
#         is provided on dying event if $silent is true
method write_file ($file, $content, :$silent, :$fatal, :$no_newline) {

    # check args
    if ( not $file )    { confess 'No file path provided'; }
    if ( not $content ) { confess 'No file content provided'; }

    # prepare content
    my @filling = $self->listify($content);
    if ( not @filling ) { confess 'No file content provided'; }
    chomp @filling;
    if ( not $no_newline ) {
        foreach my $line (@filling) { $line .= "\n"; }
    }

    # remove existing file
    if ( -e $file ) {
        if ( not( unlink $file ) ) {    # sets $ERRNO on failure
            my @err = (
                "Unable to delete existing file '$file'\n",
                "Error: $ERRNO\n",
            );
            if ($fatal)        { confess @err; }
            if ( not $silent ) { cluck @err; }
            return;
        }
    }

    # write file
    my $fh;
    if ( not( open $fh, '>', $file ) ) { ## no critic (RequireBriefOpen)
        my $err = "Unable to create '$file'";
        if ($fatal)        { confess $err; }
        if ( not $silent ) { cluck $err; }
        return;
    }
    my $retval = $TRUE;    # to ensure we try to close file
    if ( not( print {$fh} @filling ) ) {
        my $err = "Unable to write to '$file'";
        if ($fatal)        { confess $err; }
        if ( not $silent ) { cluck $err; }
        $retval = $FALSE;
    }
    if ( not( close $fh ) ) {
        my $err = "Unable to close '$file'";
        if ($fatal)        { confess $err; }
        if ( not $silent ) { cluck $err; }
        $retval = $FALSE;
    }

    # final check that a file was created
    if ( not -e $file ) {
        my $err = "Unable to create '$file'";
        if ($fatal)        { confess $err; }
        if ( not $silent ) { cluck $err; }
        $retval = $FALSE;
    }

    # provide feedback if successful
    if ( $retval and not $silent ) { say "Created file '$file'"; }

    return $retval;
}

# yesno($question, [$title])    {{{1
#
# does:   ask yes/no question in gui dialog
# params: $question - question [required]
#         $title    - dialog title [optional, default=scriptname]
# prints: nil
# return: boolean
# note:   aborting dialog with Esc returns false
# uses:   UI::Dialog
method yesno ($question, $title) {
    if ( not $title ) { $title = $self->scriptname(); }
    if ( not $question ) { confess 'No question provided'; }
    my @widget_preference = $self->_ui_dialog_widget_preference();
    my $ui = UI::Dialog->new( order => [@widget_preference] );
    return $ui->yesno( title => $title, text => $question );
}

# _android_device_available($device)    {{{1
#
# does:   determine whether an android device is available
# params: $device - android device [required]
# prints: nil, except error messages
# return: scalar boolean, dies on failure
method _android_device_available ($device) {
    if ( not $device ) { confess 'No device provided'; }
    my @devices = $self->android_devices();
    if ( not @devices ) { return; }
    return List::MoreUtils::any {/^$device\z/xsm} @devices;
}

# _android_file_or_subdir_list($dir, $type)    {{{1
#
# does:   engine for getting a list of files or subdirectories
#         in an android directory
# params: $dir    - directory containing files or subdirectories [required]
#         $type   - whether obtaining files or subdirectories
#                   [required, must be 'file' or 'subdir']
# prints: nil, except error messages
# return: list of scalar (dies if no path provided)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
# note:   tries using 'fb-adb' then 'adb', and dies if both unavailable
method _android_file_or_subdir_list ($dir, $type) {

    # check args
    if ( not $dir )  { confess 'No directory provided'; }
    if ( not $type ) { confess 'No type provided'; }
    my %valid_type = map { ( $_ => $TRUE ) } qw(file subdir);
    if ( not $valid_type{$type} ) { confess "Invalid type '$type'"; }
    my $device = $self->_android_device();

    # select android debug bridge
    my $adb = $self->_adb;
    if ( not $adb ) { confess 'Could not find adb on this system'; }

    # confirm directory exists
    if ( not $self->is_android_directory($dir) ) {
        confess "Invalid android directory '$dir'\n";
    }

    # obtain directory listing
    my $cmd = [ $adb, '-s', $device, 'shell', 'ls', '-aF', $dir ];
    my $result = $self->capture_command_output($cmd);
    if ( not $result->success ) {
        my $error = $result->error;
        my @msg   = (
            "Unable to obtain listing from directory '$dir'\n",
            "System reported error: $error\n",
        );
        confess @msg;
    }
    my @stdout = $result->stdout;

    # get matching files or directories
    # - files in output have '- ' prepended
    # - subdirectories in output have 'd ' prepended
    my $match;
    for ($type) {
        if ($_ =~ /^file\z/xsm)   { $match = qr/^ -\s ( [\s\S]+ ) $/xsm; }
        elsif ($_ =~ /^subdir\z/xsm) { $match = qr/^ d\s ( [\s\S]+ ) $/xsm; }
    }
    my @items;
    foreach my $line (@stdout) {
        if ( $line =~ $match ) {
            push @items, $1;
        }
    }

    return @items;
}

# _file_mime_type($filepath)    {{{1
#
# does:   determine mime type of file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
# uses:   File::MimeInfo
# note:   this method previously used File::Type::mime_type but that
#         module incorrectly identifies some mp3 files as
#         'application/octet-stream'
# note:   alternatives include File::MMagic and File::MMagic:Magic
method _file_mime_type ($filepath) {
    if ( not $filepath )    { confess 'No filepath provided'; }
    if ( not -r $filepath ) { confess "Invalid filepath '$filepath'"; }
    return File::MimeInfo->new()->mimetype($filepath);
}

# _get_icon($icon)    {{{1
#
# does:   gets filepath of icon included in module package
# params: $icon - file name of icon [required]
# prints: nil
# return: icon url using file:// protocol
method _get_icon ($icon) {
    my $fp = $self->shared_module_file_milla( 'Dn-Common', $icon );
    cluck "Unable to locate 'Dn-Common/$icon'" if not $fp;
    return $fp;
}

# _is_android_file_or_dir($path, $type)    {{{1
#
# does:   engine for detecting whether a path
#         is an android file or directory
# params: $path   - path to check [required]
#         $type   - whether file or directory
#                   [required, must be 'file' or 'dir']
# prints: nil, except error messages
# return: boolean (dies if no path provided)
# note:   see notes to method 'android_device_reset' regarding
#         selection of android device
# note:   tries using 'fb-adb' then 'adb', and dies if both unavailable
method _is_android_file_or_dir ($path, $type) {

    # check args
    if ( not $path ) { confess 'No path provided'; }
    if ( not $type ) { confess 'No type provided'; }
    my %valid_type = map { ( $_ => $TRUE ) } qw(file dir);
    if ( not $valid_type{$type} ) { confess "Invalid type '$type'"; }
    my $device = $self->_android_device();

    # select android debug bridge
    my $adb = $self->_adb;
    if ( not $adb ) { confess 'Could not find adb on this system'; }

    # test path
    my $flag = ( $type eq 'file' ) ? '-f' : '-d';
    my $cmd = [ $adb, '-s', $device, 'shell', 'test', $flag, $path ];
    my $result = $self->capture_command_output($cmd);
    return $result->success;
}

# _is_mimetype($filepath, $mimetype)    {{{1
#
# does:   determine whether file is a specified mimetype
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
#         $mimetype - mime type to test for [required]
# prints: nil
# return: scalar boolean
# uses:   File::MimeInfo
method _is_mimetype ($filepath, $mimetype) {
    if ( not $mimetype ) { confess 'No mimetype provided'; }
    my $filetype = $self->_file_mime_type($filepath);
    if ( not $filetype ) { return; }
    return $filetype =~ m{^$mimetype\z}xsm;
}

# _load_processes()    {{{1
#
# does:   load '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
method _load_processes () {
    $self->_clear_processes;
    foreach my $process ( @{ Proc::ProcessTable->new()->table() } ) {
        $self->_add_process( $process->pid, $process->cmndline );
    }
}

# _process_config_files()    {{{1
#
# does:   find all configuration files for calling script
#         loads attribute '_configuration_files'
# params: nil
# prints: nil
# return: nil
method _process_config_files () {
    my $root = File::Util->new()->strip_path($PROGRAM_NAME);

    # set directory and filename possibilities to try
    my ( @dirs, @files );
    push @dirs,  $PWD;                # ./     == bash $( pwd )
    push @dirs,  '/usr/local/etc';    # /usr/local/etc/
    push @dirs,  '/etc';              # /etc/
    push @dirs,  "/etc/$root";        # /etc/FOO/
    push @dirs,  $HOME;               # ~/     == bash $HOME
    push @files, "${root}config";     # FOOconfig
    push @files, "${root}conf";       # FOOconf
    push @files, "${root}.config";    # FOO.config
    push @files, "${root}.conf";      # FOO.conf
    push @files, "${root}rc";         # FOOrc
    push @files, ".${root}rc";        # .FOOrc

    # look for existing combinations and capture those config files
    for my $dir (@dirs) {
        for my $file (@files) {
            my $cf = sprintf '%s/%s', $dir, $file;
            if ( -r "$cf" ) {
                $self->_add_config_file( Config::Simple->new($cf) );
            }
        }
    }
}

# _reload_processes()    {{{1
#
# does:   reload '_processes' attribute with pid=>command pairs
# params: nil
# prints: nil
# return: nil
method _reload_processes () {
    $self->_load_processes;
}

# _restore_kde_screensaver([$title])    {{{1
#
# does:   restores suspended KDE screensaver
# params: $title - title of message box [optional, default=scriptname]
# prints: nil (feedback via popup notification)
# return: boolean
# uses:   Net::DBus::RemoteObject
#         DBus service org.freedesktop.ScreenSaver
method _restore_kde_screensaver ($title) {
    my $cookie;

    # sanity checks
    my $err;
    if ( $self->_screensaver_cookie ) {
        $cookie = $self->_screensaver_cookie;
    }
    else {                                 # must first be suspended
        $err = 'Screensaver has not been suspended by this process';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->_screensaver_can_attempt_suspend ) {
        $err = 'Cannot suspend screensaver';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # restore kde screensaver
    if ( !eval { $self->_kde_screensaver->UnInhibit($cookie); 1 } ) {   # fail
        $err = 'Unable to restore kde screensaver programmatically';
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = "Error: $EVAL_ERROR";
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = 'It should restore automatically as this script exits';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    else {    # succeeded
        $self->notify_sys( 'Restored kde screensaver', title => $title );
        $self->_screensaver_cookie();
        $self->_screensaver_suspended($FALSE);    # no longer suspended
        return $TRUE;
    }
}

# _restore_xscreensaver([$title])    {{{1
#
# does:   restores suspended xscreensaver
# params: $title - title of message box [optional, default=scriptname]
# prints: nil (feedback via popup notification)
# return: boolean
method _restore_xscreensaver ($title) {

    # first check that screensaver is suspended
    if ( not $self->_screensaver_suspended ) {
        $self->notify_sys(
            'Screensaver is not currently suspended',
            title => $title,
            type  => 'error',
        );
        return;
    }

    # simply restart xscreensaver
    my $cmd = 'xscreensaver &';

    # detect and handle failure
    my $err = 'Unable to restore xscreensaver';
    if ( !eval { system $cmd; 1 } ) {
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->process_running(qr/^xscreensaver\z/xsm) ) {
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # succeeded
    $self->_screensaver_suspended($FALSE);    # no longer suspended
    return $TRUE;
}

# _suspend_kde_screensaver([$title], [$msg])    {{{1
#
# does:   suspends kde screensaver if present
# params: $title - title of message box [optional, default=scriptname]
#         $msg   - message explaining suspend request [required]
# prints: nil (feedback via popup notification)
# return: boolean
# uses:   Net::DBus::RemoteObject
#         DBus service org.freedesktop.ScreenSaver
method _suspend_kde_screensaver ($title, $msg) {
    if ( not $title ) { confess 'No title provided'; }
    if ( not $msg )   { confess 'No message provided'; }
    my $cookie;

    # sanity checks
    my $err;
    if ( $self->_screensaver_cookie ) {

        # do not repeat request
        $err
            = 'This process has already requested KDE screensaver suspension';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->_screensaver_can_attempt_suspend ) {
        $err = 'Am not able to suspend KDE screensaver';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # suspend screensaver
    if ( !eval { $cookie = $self->_kde_screensaver->Inhibit( $PID, $msg ); 1 }
        )
    {
        $err = 'Failed to suspend KDE screensaver';    # failed
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = "Error: $EVAL_ERROR";
        $self->notify_sys( $err, type => 'error', title => $title );
        $self->_screensaver_can_attempt_suspend($FALSE);
        return;
    }
    else {                                             # succeeded
        $self->notify_sys( 'Suspended KDE screensaver', title => $title );
        $self->_screensaver_suspended($TRUE);
        $self->_screensaver_cookie($cookie);
        return $TRUE;
    }
}

# _suspend_xscreensaver([$title], [$msg])    {{{1
#
# does:   suspends xscreensaver if present
# params: $title - title of message box [required]
#         $msg   - message explaining suspend request [required]
# prints: nil (feedback via popup notification)
# return: boolean
method _suspend_xscreensaver ($title, $msg) {
    if ( not $title ) { confess 'No title provided'; }
    if ( not $msg )   { confess 'No message provided'; }

    # sanity checks
    my $err;
    if ( $self->_screensaver_suspended ) {    # do not repeat request
        $err = 'This process has already requested xscreensaver suspension';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }
    if ( not $self->_screensaver_can_attempt_suspend ) {
        $err = 'Am not able to suspend xscreensaver';
        $self->notify_sys( $err, type => 'error', title => $title );
        return;
    }

    # suspend screensaver
    my @cmd = qw(xscreensaver-command -exit);
    if ( !eval { system @cmd; 1 } ) {
        $err = 'Failed to suspend xscreensaver';    # failed
        $self->notify_sys( $err, type => 'error', title => $title );
        $err = "Error: $EVAL_ERROR";
        $self->notify_sys( $err, type => 'error', title => $title );
        $self->_screensaver_can_attempt_suspend($FALSE);
        return;
    }
    else {                                          # succeeded
        $self->notify_sys( 'Suspended xscreensaver', title => $title );
        $self->_screensaver_suspended($TRUE);
        return $TRUE;
    }
}

# _ui_dialog_widget_preference()    {{{1
#
# does:   provide widget preferences for UI::Dialog
# params: nil
# prints: nil
# return: list
# uses:   File::Which
method _ui_dialog_widget_preference () {
    my @widgets = qw(kdialog zenity gdialog cdialog whiptail ascii);
    return grep { File::Which::which $_ } @widgets;
}    # }}}1

1;

# _POD: Method header format    {{{1
# --------------------------
#
# In the pod documentation below each method description begins with the
# method signature in a second level header.
#
# A typical header looks like:
#
#     =head2 method($arg1, $arg2)
#
# For methods with no arguments this would normally result in a header like:
#
#     =head2 method()
#
# Some display engines, however, format headers differently if they include
# empty parentheses, i.e., in a different colour.
#
# To ensure consistent display of method headers, therefore, headers for
# methods without arguments have a single space inserted between parentheses,
# like:
#
#     =head2 method( )
#
# This ensures all method headers are displayed in the same format.    }}}1

# POD    {{{1

__END__

=encoding utf-8

=head1 NAME

Dn::Common - common methods for use by perl scripts

=head1 SYNOPSIS

    use Dn::Common;

=head1 DESCRIPTION

Provides methods used by Perl scripts. Can be used to create a standalone
object providing these methods; or as base class for derived module or class.

=head1 SUBROUTINES/METHODS

=head2 abort(@messages, [$prepend])

=head3 Purpose

Display console message and abort script execution.

=head3 Parameters

=over

=item @messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

=item $prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

=back

=head3 Prints

Messages followed by abort message.

=head3 Returns

Nil.

=head3 Usage

    $cp->abort('We failed');
    $cp->abort('We failed', prepend => $TRUE);

=head2 android_copy_file($source, $target, $android)

=head3 Purpose

Copy file to or from android device.

=head3 Parameters

=over

=item $source

Source file path.

Required.

=item $target

Target file or directory.

Required.

=item $android

Which path is on android device. Must be 'source' or 'target'.

Required.

=back

=head3 Prints

Nil, except error message.

=head3 Returns

N/A, die if serious error.

=head3 Notes

See method L</"android_device_reset"> regarding selection of android device for
this method.

Method tries using C<fb-adb> then C<adb> and dies if both unavailable.

=head2 android_devices( )

=head3 Purpose

Get attached android devices.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

List of attached devices. (Empty list if none.)

=head3 Note

Tries to use C<fb-adb> then C<adb>. If neither is detected prints an error
message and returns empty list (or undef if called in scalar context).

=head2 android_device_reset( )

=head3 Purpose

Reset android device for android operations.

=head3 Parameters

Nil.

=head3 Prints

User feedback if no android devices available, or user has to select between
multiple devices.

=head3 Returns

Scalar string (device id), or undef if no device is set.
Boolean scalar.

=head3 Warning

This method is called automatically whenever a method is called that requires
an android device and one has not already been selected. If only one android
device is available, it is selected automatically. If multiple android devices
are available, the user is prompted to select one. If no android device is
available, the method dies.

A selected device is used for subsequent methods that require an android
device, provided the device is still available. If the previously selected
android device has become unavailable, when the next method is called that
requires an android device, a new device is selected as before.

For these reasons, this method should rarely need to be called directly.

=head2 android_file_list($dir)

=head3 Purpose

Get list of files in an android directory.

=head3 Parameters

=over

=item $dir

Android directory to obtains contents of.

Required.

=back

=head3 Prints

Nil, except for error messages.

=head3 Returns

List of file names.

=head3 Note

See method L</"android_device_reset"> regarding selection of android device for
this method.

=head2 android_mkdir($dir)

=head3 Purpose

Ensure subdirectory exists on android device.

=head3 Parameters

=over

=item $dir

Directory to create.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

N/A, dies on failure.

=head3 Notes

No error if directory already exists, e.g., C<mkdir -p>.

See method L</"android_device_reset"> regarding selection of android device for
this method.

Method tries using C<fb-adb> then C<adb> and dies if both unavailable.

=head2 android_subdir_list($dir)

=head3 Purpose

Get list of subdirectories in an android directory.

=head3 Parameters

=over

=item $dir

Android directory to obtains contents of.

Required.

=back

=head3 Prints

Nil, except for error messages.

=head3 Returns

List of subdirectory names.

=head3 Note

See method L</"android_device_reset"> regarding selection of android device for
this method.

=head2 autoconf_version( )

=head3 Purpose

Gets autoconf version. Can be used as value for the autoconf macro 'AC_PREREQ'.

=head3 Parameters

Nil.

=head3 Prints

Nil on successful execution.

Error message on failure.

=head3 Returns

Scalar string. Dies on failure.

=head2 backup_file($file)

=head3 Purpose

Backs up file by renaming it to a unique file name. Will simply add integer to
file basename.

=head3 Parameters

=over

=item $file

File to back up.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar filename.

=head2 boolise($value)

=head3 Purpose

Convert value to boolean.

Specifically, converts 'yes', 'true' and 'on' to 1, and convert 'no, 'false,
and 'off' to 0. Other values are returned unchanged.

=head3 Parameters

=over

=item $value

Value to analyse.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 browse($title, $text)

=head3 Purpose

Displays large volume of text in default editor and then returns viewer to
original screen.

=head3 Parameters

=over

=item $title

Title is prepended to displayed text (along with some usage instructions) and
is used in creating the temporary file displayed in the editor.

Required.

=item $text

Text to display.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Nil.

=head2 capture_command_output($cmd)

=head3 Purpose

Run system command and capture output.

=head3 Parameters

=over

=item $cmd

Command to run. Array reference.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Dn::Common::CommandResult object.

=head3 Note

The returned object can provide stdout output, stderr output and full output
(stdout and stderr combined as initially output). In each case, the output is
provided as a list, with each list element being a line of original output.

=head2 centre_text([$text], [$width])

=head3 Purpose

Centre text within specified width by inserting leading spaces.

=head3 Parameters

=over

=item $text

Text to centre.

Optional. Default: empty string.

=item $width

Width of line within which to centre text.

Optional. Default: terminal width.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Scalar string.

=head3 Usage

    my $string = 'Centre me';
    my $centred = $cp->centre_text( $string, 20 );
    # $centred = '     Centre me'

=head2 changelog_from_git($dir)

=head3 Purpose

Get ChangLog content from git repository.

=head3 Parameters

=over

=item $dir

Root file of repository. Must contain C<.git> subdirectory.

Required.

=back

=head3 Prints

Nil, except feedback on failure.

=head3 Returns

List of scalar strings.

=head2 clear_screen( )

=head3 Purpose

Clear the terminal screen.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Nil.

=head3 Usage

    $cp->clear_screen;

=head2 config_param($parameter)

=head3 Configuration file syntax

This method can handle configuration files with the following formats:

=over

=item simple

    key1  value1
    key2  value2

=item http-like

    key1: value1
    key2: value2

=item ini file

    [block1]
    key1=value1
    key2=value2

    [block2]
    key3 = value3
    key4 = value4

Note in this case the block headings are optional.

=back

Warning: Mixing formats in the same file will cause a fatal error.

The key is provided as the argument to method, e.g.:
    $parameter1 = $cp->config_param('key1');

If the ini file format is used with block headings, the block heading must be
included using dot syntax, e.g.:
    $parameter1 = $cp->config_param('block1.key1');

=head3 Configuration file locations and names

This method looks in these directories for configuration files in this order:
    ./               # i.e., bash $( pwd )
    /usr/local/etc
    /etc
    /etc/FOO         # where FOO is the calling script
    ~/               # i.e., bash $HOME

Each directory is searched for these file names in this order:
    FOOconfig     # where FOO is the calling script
    FOOconf
    FOO.config
    FOO.conf
    FOOrc
    .FOOrc

=head3 Multiple values

A key can have multiple values separated by commas:

    key1  value1, value2, "value 3"

or

    key1: value1, value2

or

    key1=value1, value2

This is different to multiple B<lines> in the configuration files defining the
same key. In that case, the last such line overwrites all earlier ones.

=head3 Return value

As it is possible to retrieve multiple values for a single key, this method
returns a list of parameter values. If the result is obtained in scalar context
it gives the number of values - this can be used to confirm a single parameter
result where only one is expected.

=head2 cwd( )

=head3 Purpose

Provides current directory.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string

=head2 date_email ([$date], [$time], [$offset])

=head3 Purpose

Produce a date formatted according to RFC 2822 (Internet Message Format). An
example such date is S<'Mon, 16 Jul 1979 16:45:20 +1000'>.

=head3 Parameters

=over

=item $date

ISO-formatted date.

Named parameter. Optional. Default: today.

=item $time

A time in 24-hour format: S<'HH:MM[:SS]'>. Note that the following are not
required: leading zero for hour, and seconds.

Named parameter. Optional. Default: now.

=item $offset

Timezone offset. Example: '+0930'.

Named parameter. Optional. Default: local timezone offset.

=back

=head3 Prints

Nil routinely. Error message if fatal error encountered.

=head3 Returns

Scalar string, undef if method fails.

=head2 day_of_week([$date])

=head3 Purpose

Get the day of week that the supplied date falls on.

=head3 Parameters

=over

=item $date

Date to analyse. Must be in ISO format.

Optional. Default: today.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar day name.

=head2 debhelper_compat( )

=head3 Purpose

Get current debian compatibility level. The way it does this is to get the
major version of the 'debhelper' debian package.

Note that method returns only an integer value. See 'Usage' below for an
example of how it might be used in constructing a debian package F<control>
file.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar integer.

Undef if problem encountered.

=head3 Usage

    my $compat = $cp->debhelper_compat;
    push @control, (
        q[Build-Depends: ],
        qq[ debhelper-compat (= $compat),],
        q [autotools-dev],
    )

See L<debhelper/"COMPATIBILITY LEVELS"> for further usage details.

=head2 debian_install_deb($deb)

=head3 Purpose

Install debian package from a deb file.

First tries to install using C<dpkg> as if the user were root. If that fails,
tries to install using C<sudo dpkg>. If that fails, finally tries to install
using C<su -c dpkg>, which requires entry of the superuser (root) password.

=head3 Parameters

=over

=item $deb

Debian package file.

Required.

=back

=head3 Prints

Feedback.

=head3 Returns

Scalar boolean.

=head2 debian_package_version($pkg)

=head3 Purpose

Get the version of an installed debian package.

=head3 Parameters

=over

=item $pkg

Name of debian package.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string (version string).

Undef on failure.

=head2 debian_standards_version( )

=head3 Purpose

Get current version of debian standards. The way it does this is to get the
semantic version of the 'debian-policy' debian package.

Returns a safe version string ('3.9.2') if any problem is encountered.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string (version string).

=head2 debless($object)

=head3 Purpose

Get underlying data structure of object/blessed reference. Will only work on an
object containing an underlying data structure that is a hash.

=head3 Parameters

=over

=item $object

Blessed reference to obtain underlying data structure of. Underlying data
structure must be a hash.

Required.

=back

=head3 Prints

Nil, except error message if method fails.

=head3 Returns

Hash. Dies if method fails.

=head2 deentitise($string)

=head3 Purpose

Perform standard conversions of HTML entities to reserved characters.

=head3 Parameters

=over

=item $string

String to analyse.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 denumber_list(@list)

=head3 Purpose

Remove number prefixes added by method 'number_list'.

=head3 Parameters

=over

=item @items

List to modify.

Required.

=back

=head3 Prints

Nil.

=head3 Return

List.

=head2 dir_add_dir($dir, @subdirs)

=head3 Purpose

Add subdirectory to directory path.

=head3 Parameters

=over

=item $dir

Directory path to add to. The directory need not exist.

Required.

=item @subdirs

Subdirectories to add to path.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar directory path.

=head2 dir_add_file($dir, $file)

=head3 Purpose

Add file name to directory path.

=head3 Parameters

=over

=item $dir

Directory path to add to. The directory need not exist.

Required.

=item $file

File name to add to path.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar file path.

=head2 dirs_list([$directory])

=head3 Purpose

List subdirectories in directory. Uses current directory if no directory is
supplied.

=head3 Parameters

=over

=item $directory

Directory from which to obtain file list.

Optional. Default: current directory.

=back

=head3 Prints

Nil (error message if dies).

=head3 Returns

List (dies if operation fails).

=head2 display($string, [$error])

=head3 Purpose

Displays text on screen with word wrapping.

=head3 Parameters

=over

=item $string

Test for display.

Required.

=item $error

Print text to stderr rather than stdout. Boolean.

Optional. Default: false.

=back

=head3 Print

Text for screen display.

=head3 Return

Nil.

=head3 Usage

    $cp->display($long_string);

=head2 do_copy($src, $dest)

=head3 Purpose

Copy source file or directory to target file or directory.

=head3 Parameters

=over

=item $src

Source file or directory. Must exist.

Required.

=item $dest

Destination file or directory. Need not exist.

Required.

=back

=head3 Prints

Nil on successful operation.

Error message on failure.

=head3 Returns

Boolean success of copy operation.

Dies if missing argument.

=head3 Notes

Can copy file to file or directory, and directory to directory, but I<not>
directory to file.

Uses the File::Copy::Recursive::rcopy function which tries very hard to
complete the copy operation, including creating missing subdirectories in the
target path.

=head2 do_rmdir($dir)

=head3 Purpose

Removes directory recursively (like 'rm -fr').

=head3 Parameters

=over

=item $dir

Root of directory tree to remove.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 do_wrap($strings, [%options])

=head3 Purpose

Wrap strings at terminal (or provided) width. Continuation lines have a
prepended continuation character (U+21A9, leftwards arrow with hook).

This method is often used with method 'pager' to format screen display.

=head3 Parameters

=over

=item $strings

Text to wrap. Single string or reference to array of strings.

Required.

=item %options

Options hash. Optional.

Hash members:

=over

=item $width

Width at which to wrap.

Optional. Default: terminal width.

Note: Cannot be wider than terminal width. If it is, this width is silently
discarded and the terminal width used instead.

=item $indent

Size of indent. Can be indent of first line only (if $hang is also provided) or
of all lines (if $hang is not provided). Indent is spaces.

Optional. Default: 0.

=item $hang

Size of indent of second and subsequent lines. If not provided, $indent is used
for all lines.

Optional. Default: $indent.

=item $break

Characters on which to break. Cannot includes escapes (such as '\s'). Array
reference.

Optional. Default: [' '].

=back

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

List of scalar strings (no terminal newlines).

=head3 Usage

    my @output = $cp->do_wrap($long_string, indent => 2, hang => 4);
    my @output = $cp->do_wrap([@many_strings]);

=head2 echo_e($string)

=head3 Purpose

Use shell command 'echo -e' to display text in console. Escape sequences are
escaped.

=head3 Parameters

=over

=item $text

Text to display. Scalar string.

Required.

=back

=head3 Prints

Text with shell escape sequences escaped.

=head3 Returns

Nil.

=head2 echo_en($string)

=head3 Purpose

Use shell command 'echo -en' to display text in console. Escape sequences are
escaped. No newline is appended.

=head3 Parameters

=over

=item $text

Text to display. Scalar string.

Required.

=back

=head3 Prints

Text with shell escape sequences escaped and no trailing newline.

=head3 Returns

Nil.

=head2 ensure_no_trailing_slash($dir)

=head3 Purpose

Remove trailing slash ('/'), if present, from directory path.

=head3 Parameters

=over

=item $dir

Directory path to analyse.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string (directory path).

Undef if no directory path provided.

=head2 ensure_trailing_slash($dir)

=head3 Purpose

Ensure directory has a trailing slash ('/').

=head3 Parameters

=over

=item $dir

Directory path to analyse.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string (directory path).

Undef if no directory path provided.

=head2 entitise($string)

=head3 Purpose

Perform standard conversions of reserved characters to HTML entities.

=head3 Parameters

=over

=item $string

String to analyse.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 executable_path($exe)

=head3 Purpose

Get path of executable.

=head3 Parameters

=over

=item $exe

Short name of executable.

Required.

=back

=head3 Prints

Nil.

=head3 Return

Scalar filepath: absolute path to executable if executable exists.

Scalar boolean: returns undef If executable does not exist.

=head2 extract_key_value($key, @items)

=head3 Purpose

Provided with a list that contains a key-value pair as a sequential pair of
elements, return the value and the list-minus-key-and-value.

=head3 Parameters

=over

=item $key

Key of the key-value pair.

Required.

=item @items

The items containing key and value.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

List with first element being the target value (undef if not found) and
subsequent elements being the original list minus key and value.

=head3 Usage

    my ($value, @list) = $cp->($key, @list);

=head2 file_used_by($file)

=head3 Purpose

Get ids of processes using a specified file.

=head3 Parameters

=over

=item $file

File or filepath. Can be relative or absolute.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

List of pids.

=head3 Note

Uses shell utility C<fuser>.

=head2 files_list([$directory])

=head3 Purpose

List files in directory. Uses current directory if no directory is supplied.

=head3 Parameters

=over

=item $directory

Directory path.

Optional. Default: current directory.

=back

=head3 Prints

Nil.

=head3 Returns

List. Dies if operation fails.

=head2 find_files_in_dir($dir, $pattern)

=head3 Purpose

Finds file in directory matching a given pattern. Note that only the nominated
directory is searched -- the search does not recurse into subdirectories.

=head3 Parameters

=over

=item $dir

Directory to search.

Required.

=item $pattern

File name pattern to match. It can be a glob or a regular expression.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

List of absolute file paths.

=head2 future_date($date)

=head3 Purpose

Determine whether supplied date occurs in the future, i.e, today or after
today.

=head3 Parameters

=over

=item $date

Date to compare. Must be ISO format.

Required.

=back

=head3 Prints

Nil. (Error if invalid date.)

=head3 Return

Boolean. (Dies if invalid date.)

=head2 get_filename($filepath)

=head3 Purpose

Get filename from filepath.

=head3 Parameters

=over

=item $filepath

Filepath to analyse. Assumed to have a filename as the last element in the
path.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string (filename).

=head3 Note

This method simply returns the last element in the path. If it is a directory
path, and there is no trailing directory separator, the final subdirectory in
the path is returned. It is potentially possible to check the path at runtime
to determine whether it is a directory path or file path. The disadvantage of
doing so is that the method would then not be able to handle I<virtual>
filepaths.

=head2 get_last_directory($dirpath)

=head3 Purpose

Get last directory from a directory path.

=head3 Parameters

=over

=item $dirpath

Directory path to analyse.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Scalar path (dies on failure).

=head2 get_path($filepath)

=head3 Purpose

Get path from filepath.

=head3 Parameters

=over

=item $filepath

File path.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar path.

=head2 input_ask($prompt, [$default], [$prepend])

=head3 Purpose

Obtain input from user.

This method is intended for entering short values. Once the entered text wraps
to a new line the user cannot move the cursor back to the previous line.

Use method 'input_large' if the value is likely to be longer than a single
line.

=head3 Parameters

=over

=item $prompt

User prompt. If user uses 'prepend' option (see below) the script name is
prepended to the prompt.

=item $default

Default input.

Optional. Default: none.

=item $prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

=back

=head3 Prints

User interaction.

=head3 Returns

User's input (scalar).

=head3 Usage

    my $value;
    my $default = 'default';
    while (1) {
        $value = $self->input_ask( "Enter value:", $default );
        last if $value;
    }

=head2 input_choose($prompt, @options, [$prepend])

=head3 Purpose

User selects option from a menu.

=head3 Parameters

=over

=item $prompt

Menu prompt.

Required.

=item @options

Menu options.

Required.

=item $prepend

Flag indicating whether to prepend script name to prompt.

Named parameter. Scalar boolean.

Optional. Default: false.

=back

=head3 Prints

Menu and user interaction.

=head3 Returns

Return value depends on the calling context:

=over

=item scalar

Returns scalar (undef if choice cancelled).

=item list

Returns list (empty list if choice cancelled).

=back

=head3 Usage

    my $value = undef;
    my @options = ( 'Pick me', 'No, me!' );
    while ($TRUE) {
        $value = $self->input_choose( "Select value:", @options );
        last if $value;
        say "Invalid choice. Sorry, please try again.";
    }

=head2 input_confirm($question, [$prepend])

=head3 Purpose

User answers y/n to a question.

=head3 Parameters

=over

=item $question

Question to elicit user response. If user uses 'prepend' option (see below) the
script name is prepended to it.

Can be multi-line, i.e., enclose in double quotes and include '\n' newlines.
After the user answers, all but first line of question is removed from the
screen. For that reason, it is good style to make the first line of the
question a short summary, and subsequent lines can give additional detail.

Required.

=item $prepend

Whether to prepend the script name to the question.

Boolean.

Optional. Default: false.

=back

=head3 Prints

User interaction.

=head3 Return

Scalar boolean.

=head3 Usage

    my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
    if ( input_confirm($prompt) ) {
        # do stuff
    }

=head2 input_large($prompt, [$default], [$prepend])

=head3 Purpose

Obtain input from user.

This method is intended for entry of data likely to be longer than a single
line. Use method 'input_ask' if entering a simple (short) value. An editor is
used to enter the data. The default editor is used. If no default editor is
set, vi(m) is used.

When the editor opens it displays some boilerplate, the prompt, a horizontal
rule (a line of dashes), and the default value if provided. When the editor is
closed all lines up to and including the first horizontal rule are deleted. The
user can get the same effect by deleting in the editor all lines up to and
including the first horizontal rule.

Use method 'input_ask' if the prompt and input will fit on a single line.

=head3 Parameters

=over

=item $prompt

User prompt. If user uses 'prepend' option (see below) the script name is
prepended to the prompt.

=item $default

Default input.

Optional. Default: none.

=item $prepend

Whether to prepend the script name to the prompt.

Named parameter. Boolean.

Optional. Default: false.

=back

=head3 Prints

User interaction.

=head3 Returns

User's input as list, split on newlines in user input.

=head3 Usage

Here is a case where input is required:

    my @input;
    my $default = 'default';
    my $prompt = 'Enter input:';
    while (1) {
        @input = $self->input_large( $prompt, $default );
        last if @input;
        $prompt = "Input is required\nEnter input:";
    }

=head2 internet_connection([$verbose])

=head3 Purpose

Checks to see whether an internet connection can be found.

=head3 Parameters

=over

=item $verbose

Whether to provide user feedback during connection attempts.

Optional. Default: false.

=back

=head3 Prints

Feedback if requested, otherwise nil.

=head3 Returns

Boolean.

=head2 is_android_directory($path)

=head3 Purpose

Determine whether path is an android directory.

=head3 Parameters

=over

=item $path

Path to check.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Boolean (dies if no path provided).

=head3 Note

See method L</"android_device_reset"> regarding selection of android device for
this method.

=head2 is_android_file($path)

=head3 Purpose

Determine whether path is an android file.

=head3 Parameters

=over

=item $path

Path to check.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Boolean (dies if no path provided).

=head3 Note

See method L</"android_device_reset"> regarding selection of android device for
this method.

=head2 is_boolean($value)

=head3 Purpose

Determine whether supplied value is boolean.

Specifically, checks whether value is one of: 'yes', 'true', 'on', 1, 'no,
'false, 'off' or 0.

=head3 Parameters

=over

=item $value

Value to be analysed.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean. (Undefined if no value provided.)

=head2 is_deb($filepath)

=head3 Purpose

Determine whether file is a debian package file.

=head3 Parameters

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 is_mp3($filepath)

=head3 Purpose

Determine whether file is an mp3 file.

=head3 Parameters

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 is_mp4($filepath)

=head3 Purpose

Determine whether file is an mp4 file.

=head3 Parameters

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 is_perl($filepath)

=head3 Purpose

Determine whether file is a perl file.

=head3 Parameters

=over

=item $filepath

File to analyse.

Required. Method dies if $filepath is not provided or is invalid.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 join_dir($dir)

=head3 Purpose

Concatenate list of directories in path to string path.

=head3 Parameters

=over

=item $dir

Directory parts. Array reference.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string directory path. (Dies on error.

=head2 kde_desktop( )

=head3 Purpose

Determine whether the KDE desktop is running.

=head3 Parameters

Nil

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 konsolekalendar_date_format([$date])

=head3 Purpose

Get date formatted in same manner as konsolekalendar does in its output. An
example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format
string is '%a, %e %b %Y'.

=head3 Parameters

=over

=item $date

Date to convert. Must be in ISO format.

Optional, Default: today.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar date string.

=head2 kill_process($pid)

=head3 Purpose

Kill a specified process.

=head3 Parameters

=over

=item $pid

Id of process to kill.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

List ($success, $error_message).

=head2 listify(@items)

=head3 Purpose

Tries to convert scalar, array and hash references in list to sequences of
simple scalars. For other reference types a warning is issued.

=head3 Parameters

=over

=item @items

Items to convert to simple list.

=back

=head3 Prints

Warning messages for references other than scalar, array and hash.

=head3 Returns

Simple list.

=head2 local_timezone( )

=head3 Purpose

Get local timezone.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 logger($message, [$type])

=head3 Purpose

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. Not all
message types appear in all system logs. On Debian, for example,
/var/log/messages records only notice and warning log messages while
/var/log/syslog records all log messages.

Method dies if invalid message type is provided.

=head3 Parameters

=over

=item $message

Message content.

Required.

=item $type

Type of log message. Must be one of 'debug', 'notice', 'warning' and 'error'.

Method dies if invalid message type is provided.

Optional. Default: 'notice'.

=back

=head3 Prints

Nil.

=head3 Returns

Nil. Note method dies if invalid message type is provided.

=head3 Usage

    $cp->logger('Widget started');
    $cp->logger( 'Widget died unexpectedly!', 'error' );

=head2 make_dir($dir_path)

=head3 Purpose

Make directory recursively.

=head3 Parameters

=over

=item $dir_path

Directory path to create.

Required.

=back

=head3 Prints

Nil.

=head3 Return

Scalar boolean. If directory already exists returns true.

=head2 moox_option_bool_is_true($value)

=head3 Purpose

Determine whether a boolean MooX::Option is true.

A simple truth check on such a value does not work because MooX::Option's false
value, an empty array reference, evaluates in perl as true.

=head3 Parameters

=over

=item $value

Option value.

Required.

=back

=head3 Prints

Nil, except error message on failure.

=head3 Returns

N/A, dies on failure.

=head2 msg_box([$msg], [$title])

=head3 Purpose

Display message in gui message box.

=head3 Parameters

=over

=item $msg

Message to display.

Optional. Default: 'Press OK button to proceed'.

=item $title

Title of message box.

Optional. Default: name of calling script.

=back

=head3 Prints

Nil.

=head3 Returns

N/A.

=head2 notify(@messages, [$prepend])

=head3 Purpose

Display console message.

=head3 Parameters

=over

=item @messages

Message lines. Respects newlines if enclosed in double quotes.

Required.

=item $prepend

Whether to prepend each message line with name of calling script.

Named parameter. Boolean.

Optional. Default: false.

=back

=head3 Prints

Messages.

=head3 Returns

Nil.

=head3 Usage

    $cp->notify('File path is:', $filepath);
    $cp->notify('File path is:', $filepath, prepend => $TRUE);

=head2 notify_sys_type($type)

=head2 notify_sys_title($title)

=head2 notify_sys_icon_path($icon)

=head3 Purpose

Set default values for C<notify_sys> method parameters C<type>, C<title> and
C<icon>, respectively. Applies to subsequent calls to C<notify_sys>. Overridden
by parameters supplied in subsequent C<notify_sys> method calls.

=head2 notify_sys($message, [$title], [$type], [$icon], [$time])

=head3 Purpose

Display message to user in system notification area

=head3 Parameters

=over

=item $message

Message content.

Note there is no guarantee that newlines in message content will be respected.

Required.

=item $title

Message title.

Named parameter. Optional. Defaults to attribute C<notify_sys_title> if
available, otherwise to name of calling script.

=item $type

Type of message. Must be one of 'info', 'question', 'warn' and 'error'.

Named parameter. Optional. Defaults to attribute C<notify_sys_type> if
available, otherwise to 'info'.

=item $icon

Message box icon filepath.

Named parameter. Optional. Defaults to attribute C<notify_sys_icon_path> if
available, otherwise to a default icon provided for each message type.

=item $time

Message display time (msec).

Named parameter. Optional. Default: 10,000.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean: whether able to display notification.

=head3 Usage

    $cp->notify_sys('Operation successful!', title => 'Outcome')

=head3 Caution

Do not call this method from a spawned child process -- the 'show()' call in
the last line of this method causes the child process to hang without any
feedback to user.

=head2 now( )

=head3 Purpose

Provide current time in format 'HH::MM::SS'.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 number_list(@items)

=head3 Purpose

Prefix each list item with element index. The index base is 1.

The prefix is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

=head3 Parameters

=over

=item @items

List to be modified.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

List.

=head2 offset_date($offset)

=head3 Purpose

Get a date offset from today. The offset can be positive or negative.

=head3 Parameters

=over

=item $offset

Offset in days. Can be positive or negative.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

ISO-formatted date.

=head2 pager($lines, [$prefer])

=head3 Purpose

Display list of lines in terminal using pager. Unless a preferred pager is
provided the pager used is determined by C<IO::Pager>.

It does not matter whether or not the lines have terminal newlines or not.

This method is often used with method 'do_wrap' to format screen display.

=head3 Parameters

=over

=item $lines

Content to display. Array reference.

Required.

=item $prefer

Preferred pager. It is used if available.

Optional. No default, i.e., normally follows L<IO::Pager|IO::Pager> algorithm.

=back

=head3 Prints

Provided content, each line begins on a new line and is intelligently wrapped.

The content is paged. See L<IO::Pager|IO::Pager> for details on the algorithm
used to determine the pager used.

=head3 Return

N/A.

=head2 parent_dir($dir)

=head3 Purpose

Get parent directory of a directory path.

Whether the provided directory path is absolute or relative, the returned
parent directory path is absolute.

=head3 Parameters

=over

=item $dir

Directory path to analyse. May be relative or absolute.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar (absolute directory path).

=head2 path_split($path)

=head3 Purpose

Split directory or file path into component parts.

=head3 Parameters

=over

=item $path

Directory or file path to split. Need not exist.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

List.

=head2 pid_command($pid)

=head3 Purpose

Get command for a specified process id.

=head3 Parameters

=over

=item $pid

Process id for which to obtain command.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Scalar string (process command).

=head2 pid_running($pid)

=head3 Purpose

Determines whether process id is running.

Note that the process table is reloaded each time this method is called, so it
can be called repeatedly in dynamic situations where processes are starting and
stopping.

=head3 Parameters

=over

=item $pid

Process ID to search for.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 pluralise($string, $number)

=head3 Purpose

Adjust string based on provided numerical value. Note that this method is a
simple wrapper of L<Text::Pluralize::pluralize|Text::Pluralise/pluralize>.

=head3 Parameters

=over

=item $string

String to adjust based on the numeric value provided.

Required.

=item $number

Numeric value used in adjusting the string provided. Must be a positive integer
(including zero).

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 process_children($pid)

=head3 Purpose

Get child processes of a specified pid.

=head3 Parameters

=over

=item $pid

PID to analyse.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

List of pids.

=head2 process_ids($cmd_re, [$silent])

=head3 Purpose

Get pids for process command.

=head3 Parameters

=over

=item $cmd_re

Value to match against process commands in ps output. Regular expression.

Required.

=item $silent

Whether to suppress warnings. Note: by default warnings are issued if there is
no match or there are multiple matches found.

Named parameter. Optional. Default: false.

=back

=head3 Prints

Warning messages if other than a single matching pid found.

=head3 Returns

List of scalar integers (pids).

=head2 process_parent($pid)

=head3 Purpose

Get parent process of a specified pid.

=head3 Parameters

=over

=item $pid

PID to analyse.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Scalar integer (PID).

=head2 process_running($regex)

=head3 Purpose

Determines whether process is running. Matches on process command.

Note that the process table is reloaded each time this method is called, so it
can be called repeatedly in dynamic situations where processes are starting and
stopping.

=head3 Parameters

=over

=item $regex

Regular expression to match to command in C<ps aux> output.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 prompt([message])

=head3 Purpose

Display message and prompt user to press any key.

=head3 Parameters

=over

=item Message

Message to display.

Optional. Default: 'Press any key to continue...'.

=back

=head3 Prints

Message.

=head3 Returns

Nil.

=head2 push_arrayref($arrayref, @items)

=head3 Purpose

Add items to array reference.

=head3 Parameters

=over

=item $arrayref

Array reference to add to.

Required.

=item @items

Items to add to array reference.

Required.

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

Array reference. (Method dies on failure.)

=head2 restore_screensaver([$title])

=head3 Purpose

Restore suspended screensaver. Currently handles xscreensaver and kde
screensaver.

As a result of the method used to suspend the kde screensaver, it can only be
restored by the same process that suspended it (see method
'suspend_screensaver'), or when that process exits.

=head3 Parameters

=over

=item $title

Message box title. Note that feedback is given in a popup notification (see
method C<notify_sys>).

Optional. Default: name of calling script.

=back

=head3 Prints

User feedback indicating success or failure.

=head3 Returns

Boolean. Whether able to successfully suspend the screensaver.

Note that if none of the supported screensavers is detected, the return value
is true, i.e., it is presumed there is no screensaver.

=head2 retrieve_store($file)

=head3 Purpose

Retrieves function data from storage file.

=head3 Parameters

=over

=item $file

File in which data is stored.

Required.

=back

=head3 Prints

Nil (except feedback from Storage module).

=head3 Returns

Reference to stored data structure.

=head3 Usage

    my $storage_file = '/path/to/filename';
    my $ref = $self->retrieve_store($storage_file);
    my %data = %{$ref};

=head2 run_command_silent($silent)

=head2 run_command_fatal($fatal)

=head3 Purpose

Set default values for C<run_command> method parameters C<silent> and C<fatal>,
respectively. Applies to subsequent calls to C<run_command>. Overridden by
parameters supplied in subsequent C<run_command> method calls.

=head2 run_command($cmd, [$silent], [$fatal])

=head3 Purpose

Run a system command.

The default behaviour is to display the command, shell feedback between
horizontal dividers and, if the command failed, an error message.

Note that shell feedback is displayed only after command execution completes --
for a long-running command this can result in an apparently unresponsive
terminal.

=head3 Parameters

=over

=item $cmd

Command to run. Array reference.

Required.

=item $silent

Suppress output of command feedback. If the command fails and 'fatal' is
enabled, a traceback is displayed. Boolean.

Named parameter. Optional. Defaults to attribute C<run_command_silent> if
defined, otherwise to false.

=item $fatal

Whether to halt script execution if the command fails. Boolean.

Named parameter. Optional. Defaults to attribute C<run_command_fatal> if
defined, otherwise to false.

=back

=head3 Prints

Command to be executed, shell output and, if the command failed, an error
message. This output can be suppressed by 'silent'. Note that even if 'silent'
is selected, if the command fails while 'fatal' is set, an error traceback is
displayed.

=head3 Returns

In scalar context: boolean.

In list context: boolean, error message.

=head2 save_store($ref, $file)

=head3 Purpose

Store data structure in file.

=head3 Parameters

=over

=item $ref

Reference to data structure (usually hash or array) to be stored.

=item $file

File path in which to store data.

=back

=head3 Prints

Nil (except feedback from Storable module).

=head3 Returns

Boolean.

=head3 Usage

    my $storage_dir = '/path/to/filename';
    $self->save_store( \%data, $storage_file );

=head2 scriptname( )

=head3 Purpose

Get name of executing script.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 sequential_24h_times($time1, $time2)

=head3 Purpose

Determine whether supplied times are in chronological sequence, i.e., second
time occurs after first time. Assume both times are from the same day.

=head3 Parameters

=over

=item $time1

First time to compare. 24 hour time format.

Required.

=item $time2

Second time to compare. 24 hour time format.

Required.

=back

=head3 Prints

Nil. (Error if invalid time.)

=head3 Returns

Boolean (Dies if invalid time.)

=head2 sequential_dates($date1, $date2)

=head3 Purpose

Determine whether supplied dates are in chronological sequence.

Both dates must be in ISO format or method will return failure. It is
recommended that date formats be checked before calling this method.

=head3 Parameters

=over

=item $date1

First date. ISO format.

Required.

=item $date2

Second date. ISO format.

Required.

=back

=head3 Prints

Nil. Error message if dates not in ISO-format.

=head3 Returns

Boolean.

=head2 shared_module_file_milla($dist, $file)

=head3 Purpose

Obtains the path to a file in a module's shared directory. Assumes the module
was built using dist-milla and the target file was in the build tree's 'share'
directory.

Converts the filepath to a url using the file:// protocol. For example,
F</path/to/file> converts to F<file:///path/to/file>.

=head3 Parameters

=over

=item $dist

Module name. Uses "dash" format. For example, module My::Module would be
C<My-Module>.

Required.

=item $file

Name of file to search for.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar. (If not found returns undef, so can also function as scalar boolean.)

=head2 shell_underline($string)

=head3 Purpose

Underline string using shell escapes.

=head3 Parameters

=over

=item $string

String to underline. Scalar string.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string: string with enclosing shell commands.

=head2 shorten($string, [$limit], [$cont])

=head3 Purpose

Truncate text with ellipsis if too long.

=head3 Parameters

=over

=item $string

String to shorten.

Required.

=item $length

Length at which to truncate. Must be integer > 10.

Optional. Default: 72.

=item $cont

Continuation sequence placed at end of truncated string to indicate shortening.
Cannot be longer than three characters.

Optional. Default: '...'.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 suspend_screensaver([$title], [$msg])

=head3 Purpose

Suspend screensaver. Currently handles xscreensaver and kde screensaver.

As a result of the method used to suspend and restore the kde screensaver, it
can only be restored by the same process that suspended it (see method
'restore_screensaver'), or when that process exits.

=head3 Parameters

=over

=item $title

Message box title. Note that feedback is given in a popup notification (see
method C<notify_sys>).

Optional. Default: name of calling script.

=item $msg

Message explaining suspend request. It is passed to the screensaver object and
is not seen by the user.

Named parameter.

Optional. Default: 'request from $PID'.

=back

=head3 Prints

User feedback indicating success or failure.

=head3 Returns

Boolean. Whether able to successfully suspend the screensaver.

=head3 Usage

    $cp->suspend_screensaver('Playing movie');
    $cp->suspend_screensaver(
        'Playing movie', msg => 'requested by my-movie-player'
    );

=head2 tabify($string, [$tab_size])

=head3 Purpose

Covert tab markers ('\t') in string to spaces. Default tab size is four spaces.

=head3 Parameters

=over

=item $string

String in which to convert tabs.

Required.

=item $tab_size

Number of spaces in each tab. Integer.

Optional. Default: 4.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 temp_dir( )

=head3 Purpose

Create a temporary directory.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar directory path.

=head2 term_size( )

=head3 Purpose

Get dimensions of current terminal.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

A Dn::Common::TermSize object.

=head3 Usage

    my $height = $cp->term_size->height;
    my $width = $cp->term_size->width;

    my $ts = $cp->term_size;
    my ( $height, $width ) = ( $ts->height, $ts->width );

=head2 timezone_from_offset($offset)

=head3 Purpose

Determine timezone for offset. In most cases an offset matches multiple
timezones. The first matching Australian timezone is selected if one is
present, otherwise the first matching timezone is selected.

=head3 Parameters

=over

=item $offset

Timezone offset to check. Example: '+0930'.

Required.

=back

=head3 Prints

Error message if no offset provided or no matching timezone found.

=head3 Returns

Scalar string (timezone), undef if no match found.

=head2 today( )

=head3 Purpose

Get today as an ISO-formatted date.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

ISO-formatted date.

=head2 tools_available(@tools)

=head3 Purpose

Check that required executables are available on system.

=head3 Parameters

=over

=item @tools

Required executables. List.

Optional.

=back

=head3 Prints

Message to stderr if any tools not available, otherwise nil.

=head3 Returns

Scalar boolean.

=head3 Usage

    if ( not $cp->tools_available( 'tar', 'gzip' ) ) { return; }

=head3 Note

The error message looks like:

    Required executable is not available: not-here

or

    Required executables are not available: not-here, me-either

=head2 trim($string)

=head3 Purpose

Remove leading and trailing whitespace.

=head3 Parameters

=over

=item $string

String to be converted.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 true_path($filepath)

=head3 Purpose

Converts relative to absolute filepaths. Any filepath can be provided to this
method -- if an absolute filepath is provided it is returned unchanged.
Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is
returned unchanged. This is a compromise. There may be times when you want to
normalise a non-existent path, i.e, to collapse '../' parent directories. The
'abs_path' function can handle a filepath with a nonexistent file.
Unfortunately, however, it will silently return an empty result if an invalid
directory is included in the path. Since safety should always take priority,
the method will return the supplied filepath unchanged if the directory part
does not exist.

WARNING: If passing a variable to this function it should be double quoted. If
not, passing a value like './' results in an error as the value is somehow
reduced to an empty value.

=head3 Parameters

=over

=item $filepath

Path to analyse. If a variable should be double quoted (see above).

Required.

=back

=head3 Prints

Nil

=head3 Returns

Scalar filepath.

=head2 valid_24h_time($time)

=head3 Purpose

Determine whether supplied time is valid.

=head3 Parameters

=over

=item $time

Time to evaluate. Must be in 'HH:MM' format (leading zero can be dropped) or
'HHMM' format (cannot drop leading zero).

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 valid_date($date)

=head3 Purpose

Determine whether date is valid and in ISO format.

=head3 Parameters

=over

=item $date

Candidate date.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 valid_email($email)

=head3 Purpose

Determine validity of an email address.

=head3 Parameters

=over

=item $email

Email address to validate.

Required.

=back

=head3 Prints

Nil.

=head3 Return

Scalar boolean.

=head2 valid_integer($value)

=head3 Purpose

Determine whether supplied value is a valid integer.

=head3 Parameters

=over

=item $value

Value to test.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 valid_positive_integer($value)

=head3 Purpose

Determine whether supplied value is a valid positive integer (zero or above).

=head3 Parameters

=over

=item $value

Value to test.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean.

=head2 valid_timezone_offset($offset)

=head3 Purpose

Determine whether a timezone offset is valid.

=head3 Parameters

=over

=item $offset

Timezone offset to analyse. Example: '+0930'.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 valid_web_url($url)

=head3 Purpose

Determine validity of a web url.

=head3 Parameters

=over

=item $url

Web address to validate.

Required.

=back

=head3 Prints

Nil.

=head3 Return

Scalar boolean.

=head2 vim_list_print(@messages)

=head3 Purpose

Prints a list of strings to the terminal screen using vim's default colour
scheme.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

Supplied strings can contain escaped double quotes.

=head3 Parameters

=over

=item @messages

Each element of the list can be printed in a different style. Element strings
need to be prepared using the 'vim_printify' method. See the 'vim_printify'
method for an example.

Required.

=back

=head3 Prints

Messages in requested styles.

=head3 Returns

Nil.

=head2 vim_print($type, @messages)

=head3 Purpose

Print text to terminal screen using vim's default colour scheme.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

=head3 Parameters

=over

=item $type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'.
Case-insensitive. Can supply a partial value, down to and including just the
first letter.

Required.

=item @messages

Content to display.

Supplied strings can contain escaped double quotes.

Required.

=back

=head3 Prints

Messages in the requested colour scheme.

=head3 Returns

Nil.

=head3 Usage

    $cp->vim_print( 't', 'This is a title' );

=head2 vim_printify($type, $message)

=head3 Purpose

Modifies a single string to be included in a List to be passed to the
'vim_list_print' method. The string is given a prefix that signals to
'vim_list_print' what format to use. The prefix is stripped before the string
is printed.

Five styles have been implemented:

             Vim
             Highlight
    Style    Group       Foreground    Background
    -------  ----------  ------------  ----------
    title    Title       bold magenta  normal
    error    ErrorMsg    bold white    red
    warning  WarningMsg  red           normal
    prompt   MoreMsg     bold green    normal
    normal   Normal      normal        normal

=head3 Parameters

=over

=item $type

Type of text. Determines colour scheme.

Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'.
Case-insensitive. Can supply a partial value, down to and including just the
first letter.

Required.

=item $message

Content to modify.

Supplied string can contain escaped double quotes.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Modified string.

=head3 Usage

    $cp->vim_printify( 't', 'This is a title' );

=head2 write_file($file, $content, [$silent], [$fatal], [$no_newline])

=head3 Purpose

Write provided content to a file.

=head3 Parameters

=over

=item $file

Path of file to create.

Required.

=item $content

Content to write to file. Scalar or array reference.

Required.

=item $silent

Whether to suppress feedback.

Named parameter. Optional. Default: false.

=item $fatal

Whether to die on write failure.

Named parameter. Optional. Default: false.

=item $no_newline

Whether to not add a terminal newline where missing.

Named parameter. Optional. Default: false.

=back

=head3 Prints

Feedback:

=over

=over

=item if write operation is successful

    "Wrote file '$file'"

=item if write operation fails

    "Unable to write '$file'"

=back

=back

=head3 Returns

Boolean success.

=head3 Note

If $fatal is set to true and the write operation fails, an error message is
provided regardless of the value of $silent.

=head2 yesno($question, [$title])

=head3 Purpose

Ask yes/no question in gui dialog.

Note that aborting the dialog (by pressing Escape) has the same effect as
selecting 'No' -- returning false.

=head3 Parameters

=over

=item $question

Question to be answered. Is displayed unaltered, i.e., include terminal
question mark.

Required.

=item $title

Dialog title.

Optional. Default: script name.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Config::Simple, Curses, Cwd, Data::Dumper::Simple, Data::Structure::Util,
Data::Validate::URI, Date::Simple, DateTime, DateTime::Format::Mail,
DateTime::TimeZone, Desktop::Detect, Dn::Common::CommandResult,
Dn::Common::TermSize, Dn::Common::Types, Email::Valid, English, Env,
experimental, File::Basename, File::chdir, File::Copy, File::Copy::Recursive,
File::Find::Rule, File::MimeInfo, File::Path, File::Spec, File::Temp,
File::Util, File::Which, Function::Parameters, HTML::Entities, IO::Pager,
IPC::Cmd, IPC::Open3, IPC::Run, List::MoreUtils, Logger::Syslog,
namespace::clean, Moo, MooX::HandlesVia, Net::DBus, Net::Ping::External,
Proc::ProcessTable, Readonly, Scalar::Util, Storable, strictures,
Term::ANSIColor, Term::Clui, Term::ReadKey, Test::NeedsDisplay,
Text::Pluralize, Text::Wrap, Time::HiRes, Time::Simple, Type::Utils,
Types::Path::Tiny, Types::Standard, UI::Dialog, version.

=head2 Utilities

adb | fb-adb, autoconf, echo, fuser, su, sudo.

=head2 Debian packaging

Two of the modules that Dn::Common depends on are not available from the
standard debian repository: F<Text::Pluralize> and F<Time::Simple>. Debian
packages for these modules, F<libtext-pluralize-perl> and
F<libtime-simple-perl> respectively, are available from the same provider of
the debian package for this module, F<libdn-common-perl>.

=head1 BUGS AND LIMITATIONS

Report to module author.

=head1 AUTHOR

David Nebauer E<lt>david@nebauer.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>david@nebauer.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim:fdm=marker
