package Role::Utils::Dn;

use Moo::Role;    # {{{1
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean;

use autodie qw(open close);
use Carp    qw(carp confess croak);
use Const::Fast;
use Clipboard;
use Curses;
use Data::Dumper::Simple;
use Date::Simple qw(today);
use DateTime;
use DateTime::Format::Mail;
use DateTime::TimeZone;
use English qw(-no_match_vars);
use Env     qw($PAGER);
use Feature::Compat::Try;
use File::Basename;
use File::Compare;
use File::Copy::Recursive;
use File::MimeInfo;
use File::Path;
use File::Spec;
use File::Temp;
use File::Util;
use File::Which;
use HTML::Entities;
use Image::Magick;
use IO::Interactive;
use IO::Pager;
use IPC::Cmd;
use IPC::Run;    # required by IPC::Cmd
use List::SomeUtils;
use List::Util qw(reduce);
use Net::Ping::External;
use Path::Tiny;
use POSIX ();    # for WIFEXITED, WEXITSTATUS, WIFSIGNALED, WTERMSIG
use Role::Utils::Dn::CommandResult;
use Scalar::Util;
use Symbol;
use Term::ANSIColor;
use Term::Clui;
use Term::ProgressBar::Simple;
use Text::Pluralize;
use Text::Wrap;
use Time::Simple;
use experimental qw(switch);

const my $TRUE                   => 1;
const my $FALSE                  => 0;
const my $CLASS_REGEXP           => 'Regexp';
const my $DOT                    => q{.};
const my $DOUBLE_QUOTE           => q{"};
const my $EMPTY_STRING           => q{};
const my $FILE_COMPARE_ERROR     => -1;
const my $KEY_BACKGROUND         => 'background';
const my $KEY_BREAK              => 'break';
const my $KEY_FATAL              => $TRUE;
const my $KEY_CONT               => 'cont';
const my $KEY_FONT               => 'font';
const my $KEY_GEOMETRY           => 'geometry';
const my $KEY_GRAVITY            => 'gravity';
const my $KEY_HANG               => 'hang';
const my $KEY_HEIGHT             => 'height';
const my $KEY_INDENT             => 'indent';
const my $KEY_SILENT             => 'silent';
const my $KEY_TIMEOUT            => 0;
const my $KEY_WIDTH              => 'width';
const my $LIST_STAR              => '* ';
const my $MOD_PATH_TINY          => 'Path::Tiny';
const my $MSG_INSTALL_GOOD       => 'Package installed successfully';
const my $MSG_NO_COMMAND         => 'No command provided';
const my $MSG_NO_FILEPATH        => 'No filepath provided';
const my $MSG_NO_IMAGE           => 'No image provided';
const my $MSG_NO_SOURCE          => 'No source file provided';
const my $MSG_NO_TARGET          => 'No target provided';
const my $MSG_NO_TERM_OUTPUT     => 'Unable to output to terminal';
const my $MSG_NOT_ARRAYREF       => 'Not an array reference';
const my $MSG_NOT_IMG_OBJ        => 'Not an image object';
const my $MSG_SCALAR_NOT_HASHREF => 'Expected hash reference, got scalar';
const my $NEGATE      => -1;           ## no critic (ProhibitDuplicateLiteral)
const my $NEWLINE     => "\n";
const my $NUMBER_TEN  => 10;
const my $OPT_INSTALL => '--install';
const my $PARAM_COMMA_SPACE => q{, };
const my $PARAM_DPKG        => 'dpkg';
const my $PARAM_HEIGHT   => 'height';  ## no critic (ProhibitDuplicateLiteral)
const my $PARAM_WIDTH    => 'width';   ## no critic (ProhibitDuplicateLiteral)
const my $REF_TYPE_ARRAY => 'ARRAY';
const my $REF_TYPE_HASH  => 'HASH';
const my $RGB_ARG_COUNT  => 3;
const my $RGB_ARG_MAX    => 255;
const my $SPACE          => q{ };
const my $TAB_SIZE       => 4;
const my $VAL_CENTER     => 'Center';
const my $VAL_LEFT       => 'left';    # }}}1

# methods

# array_push($arrayref, @items)    {{{1
#
# does:   add items to an arrayref
# params: $arrayref - array reference to add to [required]
#         @items    - items to add [required]
# prints: nil, except error messages
# return: array reference (dies on failure)
sub array_push ($self, $arrayref, @items)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  if (not @items)    { confess 'No items provided'; }
  if (not $arrayref) { confess 'No array reference provided'; }
  my $ref_type = ref $arrayref;
  if ($ref_type ne $REF_TYPE_ARRAY) { confess $MSG_NOT_ARRAYREF ; }

  # add items
  my @list = @{$arrayref};
  push @list, @items;
  return [@list];
}

# autoconf_version()    {{{1
#
# does:   gets autoconf version
# params: nil
# prints: nil, except error on failure
# return: scalar version number, die on failure
sub autoconf_version ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my $cmd     = [ 'autoconf', '--version', ];
  my $cmd_str = join $SPACE, @{$cmd};
  my $result  = $self->shell_command($cmd);
  if (not $result->success) { confess "Command '$cmd_str' failed"; }
  my $version_line          = ($result->stdout)[0];
  my @version_line_elements = split /\s+/xsm, $version_line;
  foreach my $element (@version_line_elements) {
    if ($element =~ /^ \d+ [ [.]\d+ ]?/xsm) {
      return $element;
    }
  }
  confess "Did not find version number in '$version_line'";
}

# changelog_from_git($dir)    {{{1
#
# does:   get ChangeLog content from git repository
# params: $dir = root file of repository [required]
#                must contain a '.git' directory
# prints: nil, feedback on failure
# return: list, dies on failure
sub changelog_from_git ($self, $dir)
{    ## no critic (RequireInterpolationOfMetachars)

  # check directory
  if (not $dir) { return (); }
  my $repo_root = $self->path_true($dir);
  if (not -d $repo_root) { croak "Invalid directory '$dir'"; }
  my $git_dir = $repo_root . '/.git';
  if (not -d $git_dir) { croak "'$dir' is not a git repo root"; }

  # operate from repo root dir
  local $File::chdir::CWD = $File::chdir::CWD;
  $File::chdir::CWD = $repo_root;

  # obtain git log output
  my $cmd    = [ 'git', 'log', '--date-order', '--date=short' ];
  my $result = $self->shell_command($cmd);
  if (not $result->success) {
    croak "Unable to get git log in '$dir'";
  }

  # process output log entries
  my (@log, @entry);
  my $indent = $SPACE x $TAB_SIZE;
  my ($author, $email, $date);
  foreach my $line ($result->stdout) {
    next if $line =~ /^commit /xsm;
    next if $line =~ /^\s*$/xsm;
    my ($key, @values) = split /\s+/xsm, $line;
    my $value = join $SPACE, @values;
    for ($key) {
      if ($_ eq 'Author:') {    # start of entry
                                # flush previous entry, if any
        if (@entry) {
          push @log, "$date  $author <$email>";
          push @log, q{};
          foreach my $line (@entry) {
            push @log, $indent . $LIST_STAR . $line;
          }
          push @log, q{};
          @entry = ();
        }

        # process current line
        elsif ($value =~ /^([^<]+)\s+<([^>]+)>\s*$/xsm) {
          $author = $1;
          $email  = $2;
        }
        else {
          confess "Bad match on line '$line'";
        }
      }
      elsif ($_ eq 'Date:') {
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
      push @log, $indent . $LIST_STAR . $line;
    }
    push @log, q{};
  }

  # return log
  return @log;
}

# changelog_version_regex()    {{{1
#
# does:   provide regex for finding version in the
#         debianise/debian-files/changelog file
#
# params: nil
# prints: nil
# return: scalar regex
# note:   assumes first line of changelog file is well-formed, i.e., like:
#             dn-cronsudo (2.1-2) UNRELEASED; urgency=low
#         so the first pair of parentheses encloses pkg_version-deb_revision,
#         and has a final line like:
#             -- John Doe <john@doe.com>  Fri, 29 Oct 2021 17:22:13 +0930
# note:   returned regex includes five named captures from the most recent
#         changelog entry:
#                    <pkg> = package name
#                <version> = version
#                <release> = package release
#                <urgency> = package urgency
#             <maintainer> = maintainer name+email
# note:   access named capture like:
#             my $changelog_content = $changelog->slurp_utf8;
#             my $re = $self->changelog_version_regex;
#             if ( $changelog_content =~ $re ) {
#                 my $version = "$LAST_PAREN_MATCH{'version'}";
#                 # ...
#             }
sub changelog_version_regex ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # building blocks
  my $any = qr/.*?/xsm;

  # first capture: package name

  my $pkg = qr{
        (?<pkg>    # first capture is package name
        \A\S+      # package name
        )          # close capture
        \s+        # followed by space
    }xsm;

  # second capture: version+revision

  my $version = qr{
        [(]            # enclosed in parentheses
        (?<version>    # commence capture of version+revision
        [^)]+          # version+revision
        )              # close second capture
        [)]            # enclosed in parentheses
        \s+            # followed by space
    }xsm;

  # third capture: release

  my $release = qr{
        (?<release>    # commence capture of release
        [^;]+          # release
        )              # close third capture
        ;\s+           # followed by semicolon and space
    }xsm;

  # fourth capture: urgency

  my $urgency = qr{
        (?<urgency>    # commence capture of urgency
        .*?$           # remainder of line
        )              # close fourth capture
        $any           # followed by any content
    }xsm;

  # fifth capture: maintainer

  my $maint = qr{
        (?<maint>    # commence capture of maintainer
        ^[ ]+--\s+   # leading double hyphen
        [^\>]+>      # maintainer name and then <email_address>
        )            # close fifth capture
    }xsm;

  return qr{ $pkg $version $release $urgency $maint }xsm;
}

# configure_ac_version_regex()    {{{1
#
# does:   provide regex for finding version in the
#         tarball/autotools/configure.ac file
#
# params: nil
# prints: nil
# return: scalar regex
# note:   returned regex includes three named captures:
#                 <pre> = from beginning of file to version
#             <version> = version
#                <post> = from version to end of file
# note:   access named capture like:
#             my $configure_ac_content = $configure_ac->slurp_utf8;
#             my $re = $self->configure_ac_version_regex;
#             if ( $configure_ac_content =~ $re ) {
#                 my $version = "$LAST_PAREN_MATCH{'version'}";
#                 # ...
#             }
sub configure_ac_version_regex ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # building blocks
  my $any = qr/.*?/xsm;
  my $arg = qr{
        \[.*?\]    # argument, enclosed in square brackets
        $any  # interargument characters, may include newline
    }xsm;

  # in $any can't enclose '.' in a character class ('[.]')
  # because then it wouldn't match newlines
  # (see 'Metacharacters' section in 'perlre' manpage)
  # so need to disable related Perl::Critic warnings

  # first capture: all of file before version

  my $pre_version = qr{
        (?<pre>    # first capture is all of file before version
        \A$any     # capture from beginning of file
        AC_INIT    # version is an argument to the AC_INIT macro
        $any       # chars between macro name and opening '('
        [(]        # open arguments for AC_INIT macro
        $arg       # first AC_INIT argument: description
        \[         # opening brace of second argument
        )          # close first capture
    }xsm;

  # second capture: version

  my $version = qr{
        (?<version>    # second capture is version
        $any           # second AC_INIT argument: version
        )              # close second capture
    }xsm;

  # third capture: all of file after version

  my $post_version = qr{
        (?<post>     # third capture is all of file after version no.
        \]           # closing brace of second argument
        $any         # interargument chars, may include newline
        $arg         # third AC_INIT argument: maintainer email
        $arg         # fourth AC_INIT argument: distribution name
        [)]          # close AC_INIT macro
        $any\z       # include remainder of file
        )
    }xsm;

  return qr{ $pre_version $version $post_version }xsm;
}

# copy_to_clipboard($val)    {{{1
#
# does:   copy value to system clipboard
# params: $val - value to copy to system clipboard
# return: n/a, dies on error
# note:   non scalar values are converted to string by the Dumper
#         function from the Data::Dumper::Simple module
# note:   in X-Windows system (such as linux) the value is copied
#         to both the primary selection (paste with middle mouse button
#         of shift key + middle mouse button) and clipboard selection
#         (ctrl+v keys or shift+ctrl+v keys)
sub copy_to_clipboard ($self, $val)
{    ## no critic (RequireInterpolationOfMetachars)

  my $scalar = $self->stringify($val);

  # system-neutral assignation to clipboard    {{{2
  # - in X-Windows (e.g., linux) copies to primary selection,
  #   which pastes with middle mouse button
  if (!eval { Clipboard->copy($scalar); 1 }) {
    warn "Couldn't copy '$scalar' to clipboard: $EVAL_ERROR\n";
  }

  # linux systems assign to X-Windows clipboard selection    {{{2
  if (List::SomeUtils::any {/\A$OSNAME\z/xsm} qw(linux darwin)) {

    # stolen from https://www.av8n.com/security/Xclip.pm

    my @cmd  = qw(xclip -selection clipboard);
    my $pipe = Symbol::gensym;

    # open pipe to xclip
    # - no need for error message on failure as 'open' prints one
    if (!open $pipe, q{|-}, @cmd) { return; }

    # echo value to xclip via pipe
    print {$pipe} $scalar or confess "Couldn't write to pipe: $OS_ERROR";

    # close pipe
    if (!close $pipe) {

      # exit status of pipe close
      my $err = ${^CHILD_ERROR_NATIVE};

      # decode this exit status with POSIX module functions
      if (POSIX::WIFEXITED($err)) {
        carp 'cmd exited with status ', POSIX::WEXITSTATUS($err), $NEWLINE;
      }
      if (POSIX::WIFSIGNALED($err)) {
        carp 'cmd killed by signal ', POSIX::WTERMSIG($err), $NEWLINE;
      }
      carp ' +++ ', join($SPACE, @cmd), $NEWLINE;
    }
  }    # }}}2
  return;
}

# cwd()    {{{1
#
# does:   get current directory
# params: nil
# prints: nil
# return: scalar string
sub cwd ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return Path::Tiny::path($DOT)->realpath;
}

# data_retrieve($file)    {{{1
#
# does:   retrieves function data from storage file
# params: $file - file in which data is stored [required]
# prints: nil (except feedback from Storage module)
# return: as per Storable manpage:
#         • variable reference on success
#         • undef if an I/O system error occurs
#         • "other serious errors are propagated via 'die'"
# usage:  my $storage_file = '/path/to/filename';
#         my $ref = $self->data_retrieve($storage_file);
#         my %data = %{$ref};
sub data_retrieve ($self, $file)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not -r $file) { confess "Cannot read data file '$file'"; }
  return Storable::retrieve $file;
}

# data_store($data, $file)    {{{1
#
# does:   store data structure in file
# params: $data  - reference to data structure to be stored [ref, required]
#         $file - file path in which to store data [scalar. required]
# prints: nil (except feedback from Storable module)
# return: as per Storable manpage:
#         • boolean true on success
#         • undef for internal errors like I/O errors
#         • "serious errors are propagated as a 'die' exception"
# usage:  my $storage_dir = '/path/to/filename';
#         $self->data_store( \%data, $storage_file );
sub data_store ($self, $data, $file)
{    ## no critic (RequireInterpolationOfMetachars)

  # check params
  # - data must be a reference
  if (ref $data eq q{}) {
    confess 'Data structure is not a reference';
  }

  # - path must exist
  my $path = $self->dir_name($file);
  if ($path && !-d $path) {
    confess "Invalid data file path in '$file'";
  }

  # will overwrite, but warn user
  if (-e $file) {
    $self->interact_warn("Overwriting data file '$file' with new data");
  }

  # save data
  return Storable::store $data, $file;
}

# date_current_iso()    {{{1
#
# does:   get current date in ISO 8601 format (yyyy-mm-dd)
# params: nil
# prints: nil
# return: scalar string
# uses:   Date::Simple
sub date_current_iso ($self) {  ## no critic (RequireInterpolationOfMetachars)
  return Date::Simple->today()->format('%Y-%m-%d');
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
# return: scalar string, dies on failure
# note:   example output: 'Mon, 16 Jul 1979 16:45:20 +1000'
sub date_email ($self, $date = undef, $time = undef, $offset = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # date
  if ($date) {
    if (not $self->date_valid($date)) {
      croak "Invalid date '$date'";
    }
  }
  else {
    $date = $self->date_current_iso();
  }

  # time
  if ($time) {
    if (not $self->time_24h_valid($time)) {
      croak "Invalid time '$time'";
    }
  }
  else {
    $time = $self->time_now();
  }

  # timezone
  my $timezone;
  if ($offset) {
    $timezone = $self->time_zone_from_offset($offset);
    if (not $timezone) { croak; }    # error shown by previous line
  }
  else {
    $timezone = $self->time_zone_local();
  }

  # get rfc 2822 string
  my $ds = Date::Simple->new($date);
  if (not $ds) { confess 'Unable to create Date::Simple object'; }
  my $ts = Time::Simple->new($time);
  if (not $ts) { confess 'Unable to create Time::Simple object'; }
  my $dt = DateTime->new(
    year      => $ds->year,
    month     => $ds->month,
    day       => $ds->day,
    hour      => $ts->hour,
    minute    => $ts->minute,
    second    => $ts->second,
    time_zone => $timezone,
  );
  if (not $dt) { confess 'Unable to create DateTime object'; }
  my $email_date = DateTime::Format::Mail->format_datetime($dt);
  if (not $email_date) { confess 'Unable to generate RFC2822 date'; }
  return $email_date;
}

# date_valid($date)    {{{1
#
# does:   determine whether date is valid and in ISO format
# params: $date - candidate date [required]
# prints: nil
# return: boolean
sub date_valid ($self, $date) { ## no critic (RequireInterpolationOfMetachars)
  if (not $date) { return $FALSE; }
  return Date::Simple->new($date);
}

# debhelper_compat()    {{{1
#
# does:   get current debian compatibility level
#         - actually gets major version of debian package 'debhelper'
# params: nil
# prints: nil
# return: scalar string - version (undef if problem encountered)
sub debhelper_compat ($self) {  ## no critic (RequireInterpolationOfMetachars)

  # get full version
  # - called method dies on failure
  my $version_full = $self->debian_package_version('debhelper');

  # get semantic version
  # - meaning only '[E:]X' and not, for example, '[E:]X.Y.Z')
  my $match_full_version = qr{
            \A                  # anchor to start of string
            (\d+:)?             # epoch (optional)
            [\d\N{FULL STOP}]+  # version: A.B.C...
            \z                  # anchor to end of string
        }xsm;
  my $match_major_version = qr{
            \A                # anchor to start of string
            (                 # start capture
              (?:\d+:)?       # epoch (optional)
              \d+             # major version number
            )                 # end capture (don't care about string end)
        }xsm;
  my $major_version;
  if ($version_full =~ $match_full_version) {
    $version_full =~ $match_major_version;
    $major_version = $1;
  }
  if (not $major_version) {
    my $msg = 'Unable to extract debhelper major version number'
        . " from version: $version_full";
    confess $msg;
  }

  return $major_version;
}

# debian_install_deb($deb)    {{{1
#
# does:   installs debian package from a deb file
# params: $deb - deb package file [required]
# prints: question and feedback
# return: boolean
sub debian_install_deb ($self, $deb)
{    ## no critic (RequireFinalReturn RequireInterpolationOfMetachars)

  # test filepath
  if (not $deb) {
    warn "No debian package filepath provided\n";
    return;
  }
  if (not -r $deb) {
    warn "Invalid filepath: $deb\n";
    return;
  }
  if (not $self->file_is_deb($deb)) {
    warn "Invalid package file: $deb\n";
    return;
  }

  # requires 'dpkg'
  if (not $self->tools_available($PARAM_DPKG)) { return; }

  # try installing as if root
  my @cmd = ($PARAM_DPKG, $OPT_INSTALL, $deb);
  try {
    $self->run_command(undef, @cmd);
    say $MSG_INSTALL_GOOD or confess;
    return $TRUE;
  }
  catch ($err) {
    warn "Looks like you are not root/superuser\n";
  }

  # try installing with sudo
  @cmd = ('sudo', $PARAM_DPKG, $OPT_INSTALL, $deb,);
  try {
    $self->run_command(undef, @cmd);
    say $MSG_INSTALL_GOOD or confess;
    return $TRUE;
  }
  catch ($err) {
    warn "Okay, seems you do not have root privileges for 'dpkg'\n";
  }

  # lastly, try su
  # - if every part is made array element then operation fails with:
  #   /bin/su: unrecognized option '--install'
  # - if pass entire command spanning double quotes (including double
  #   quotes) as a single array element, then entire command appears
  #   to be passed to bash as a single unit, and after providing
  #   password the operation fails with:
  #     bash: dpkg --install ../build/FILE.deb: No such file or directory
  @cmd =
      (   'su -c'
        . $SPACE
        . $DOUBLE_QUOTE
        . $PARAM_DPKG
        . $SPACE
        . $OPT_INSTALL
        . $SPACE
        . $deb
        . $DOUBLE_QUOTE);
  say 'The root password is needed' or confess;
  try {
    $self->run_command(undef, @cmd);
    say $MSG_INSTALL_GOOD or confess;
    return $TRUE;
  }
  catch ($err) {
    warn "That's it, I give up installing this package\n";
  }

  return;
}

# debian_package_version($pkg)    {{{1
#
# does:   get version of debian package
# params: $pkg - name of debian package
# prints: nil
# return: scalar string - version
#         false = dpkg command failed
#         dies on failure to parse version string
sub debian_package_version ($self, $pkg)
{    ## no critic (RequireInterpolationOfMetachars)

  # check arg
  return $FALSE if not $pkg;

  # get output of 'dpkg -s PKG'
  my $cmd    = [ $PARAM_DPKG, '-s', $pkg ];
  my $result = $self->shell_command($cmd);
  return $FALSE if not $result->success;

  # get version line from status output
  my @out      = $result->stdout;
  my $ver_line = List::SomeUtils::first_value {/\AVersion: /xsm} @out;
  confess "Unable to extract version information for package $pkg"
      if not $ver_line;

  # get full version number
  my $version = (split /\s+/xsm, $ver_line)[1];
  confess "Unable to extract $pkg version from $ver_line"
      if not $version;

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
sub debian_standards_version ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # get full version
  # - called method returns undef on dpkg error, otherwise dies on failure
  my $version_full = $self->debian_package_version('debian-policy');
  confess "Unable to get 'debian-policy' status with dpkg\n"
      if not $version_full;

  # get semantic version
  # - meaning only '[E:]X.Y.Z' and not, for example, '[E:]X.Y.Z.A')
  my $match_full_version = qr{
        \A                  # anchor to start of string
        (\d+:)?             # epoch (optional)
        [\d\N{FULL STOP}]+  # version: A.B.C...
        \Z                  # anchor to start of string
    }xsm;
  my $match_semantic_version = qr{
        \A                           # anchor to start of string
        (                            # start capture
          (?:\d+:)?                  # epoch (optional)
          \d+                        # major version number
          (?:\N{FULL STOP}\d+){0,2}  # up to two further version levels
        )                            # end capture (ignore string end)
    }xsm;
  my $version;
  if ($version_full =~ $match_full_version) {
    $version_full =~ $match_semantic_version;
    $version = $1;
  }
  confess "Unable to extract 3-part version from '$version_full'"
      if not $version;

  return $version;

}

# dir_clean($dir)    {{{1
#
# does:   remove all contents of directory
#
# params: $dir - dirpath to check [Path::Tiny object or string, required]
# prints: feedback on error
# return: n/a, dies on failure
sub dir_clean ($self, $dir_param)
{    ## no critic (RequireInterpolationOfMetachars)

  # check directory param    {{{2
  my $dir;
  my $dir_reftype  = Scalar::Util::reftype $dir_param;
  my $dir_obj_type = Scalar::Util::blessed $dir_param;
  if (defined $dir_reftype) {

    # is a reference
    if (defined $dir_obj_type) {

      # is an object
      if ($dir_obj_type eq $MOD_PATH_TINY) { $dir = $dir_param; }
      else { confess "Invalid directory: is $dir_obj_type object"; }
    }
    else { confess "Invalid directory: is $dir_reftype"; }
  }
  else {
    # scalar, presumed to be string file path
    $dir = Path::Tiny::path($dir_param)->absolute;
  }
  if (not $dir) { confess 'Unable to determine directory path'; }

  # delete directory contents    {{{2
  my @children  = map { $_->canonpath } $dir->children;
  my $to_delete = @children;
  my $deleted   = File::Path::remove_tree(@children);
  if ($deleted < $to_delete) {
    confess "Tried to delete $to_delete items, deleted $deleted";
  }    # }}}2

  return;
}

# dir_copy($source_dir, $target_dir)    {{{1
#
# does:   recursively copy the contents of one directory to another
# params: $source_dir - directory to copy from
#                       [required, dirpath, must exist]
#         $target_dir - directory to copy to
#                       [required, dirpath, created if necessary]
# prints: error message on failure
# return: nil, dies on failure
sub dir_copy ($self, $source_dir, $target_dir)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess 'No target directory provided' if not $target_dir;
  confess 'No source directory provided' if not $source_dir;
  if (not -d $source_dir) {
    confess "Source directory '$source_dir' does not exist";
  }

  File::Copy::Recursive::dircopy($source_dir, $target_dir)
      or confess $ERRNO;

  return;
}

# dir_current()    {{{1
#
# does:   get current working directory
# params: nil
# prints: nil
# return: scalar string
sub dir_current ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return Path::Tiny::path($DOT)->absolute->canonpath;
}

# dir_join(@dirs)    {{{1
#
# does:   concatenates list of directories in path to string path
# params: @dirs - directory parts [required, list]
# prints: nil
# return: scalar string path
#         die on error
# usage:  my $fp = $self->dir_join($root, $dir, $subdir)
sub dir_join ($self, @dirs) {    ##no critic (RequireInterpolationOfMetachars)
  return $EMPTY_STRING if not @dirs;
  return File::Spec->catdir(@dirs);
}

# dir_list($directory)    {{{1
#
# does:   list subdirectories in directory
# params: $directory - directory path [optional, default=cwd]
# prints: nil
# return: list, die if operation fails
sub dir_list ($self, $dir) {    ## no critic (RequireInterpolationOfMetachars)
  if (not $dir) { $dir = $self->cwd(); }
  $dir = $self->path_true($dir);
  if (not -d $dir) { confess "Invalid directory '$dir'"; }
  my $f = File::Util->new();

  # method 'list_dir' fails if directory has no subdirs, so cannot test
  # for failure of method - assume "failure" == no subdirs in directory
  my @dirs;
  @dirs = $f->list_dir($dir, { dirs_only => $TRUE });
  if (@dirs) {
    @dirs = grep { !/^[.]{1,2}$/xsm } @dirs;    # exclude '.' and '..'
  }
  return @dirs;
}

# dir_make(@paths)    {{{1
#
# does:   create directory paths
# params: @paths - one or more directory paths to create [required]
# prints: error messages
# return: boolean, dies on fatal filesystem errors
sub dir_make ($self, @paths) {  ## no critic (RequireInterpolationOfMetachars)

  # check args
  return $TRUE if not @paths;

  # create directory paths
  my $success = $TRUE;
  my $options = { error => \my $errors };
  File::Path::make_path(@paths, $options);
  if ($errors && @{$errors}) {
    $success = $FALSE;
    for my $error (@{$errors}) {
      my ($dirpath, $msg) = %{$error};
      if   ($dirpath) { warn "problem creating $dirpath: $msg\n"; }
      else            { warn "error during creation: $msg\n"; }
    }
  }

  return $success;
}

# dir_name($filepath, $exists = $FALSE)    {{{1
#
# does:   extract dirpath from filepath
# params: $filepath - path from which to extract directory path
#                     [required, str, can be directory path only]
#         $exists   - die if filepath does not exist
#                     [optional, bool, default=false]
# prints: error messages
# return: scalar string
sub dir_name ($self, $filepath, $exists = $FALSE)
{    ## no critic(RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  if ($exists and not $self->file_readable($filepath)) {
    confess "Filepath '$filepath' does not exist";
  }

  return (File::Spec->splitpath($filepath))[1];
}

# dir_parent($dir)    {{{1
#
# does:   return parent directory
# params: $dir - directory path to analyse [required]
# prints: nil
# return: scalar (absolute directory path)
# note:   converts to, and returns, absolute path
sub dir_parent ($self, $dir) {  ## no critic (RequireInterpolationOfMetachars)
  if (not $dir) { confess 'No path provided'; }
  return Path::Tiny::path($dir)->absolute->parent->canonpath;
}

# dir_temp()    {{{1
#
# does:   get path of temporary directory
# params: nil
# prints: nil
# return: scalar string
sub dir_temp ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return File::Temp::tempdir(CLEANUP => $TRUE);
}

# divider($type)    {{{1
#
# does:   get divider string (dashes) as wide as current terminal
# params: $type = divider type ('top'|'bottom', optional, default='top')
# prints: nil
# return: scalar string
# note:   top divider char = '-', bottom divider = '='
sub divider ($self, $type = 'top')
{    ## no critic (RequireInterpolationOfMetachars)

  # params
  my %divider_char = (top => q{-}, bottom => q{=});
  if (not exists $divider_char{$type}) {
    croak "Invalid divider type '$type'";
  }

  # key values
  const my $TERM_MIN_WIDTH => $NUMBER_TEN;
  const my $TERM_GUTTER    => 5;

  # get divider length
  my $width = $self->term_width;
  if ($width < $TERM_MIN_WIDTH) {
    confess "Terminal < $TERM_MIN_WIDTH chars($width)";
  }
  my $length = $width - $TERM_GUTTER;

  # create divider
  my $divider = $divider_char{$type} x $length;

  return $divider;
}

# dump_var($var1[, var2[, ...]])    {{{1
#
# does:   format variable for display
# params: $varX - variable to format [optional, any variable type]
# prints: nil
# return: list of strings, each of which fits the current terminal
# usage:  say $_ for $self->dump_var($my_var);
sub dump_var ($self, @vars) {   ## no critic (RequireInterpolationOfMetachars)

  # check params
  return () if not @vars;

  # configure dumper
  # - Terse and Indent combine to minimise initial spacing
  local $Data::Dumper::Terse         = $TRUE;
  local $Data::Dumper::Indent        = 1;
  local $Data::Dumper::Deepcopy      = $TRUE;
  local $Data::Dumper::Trailingcomma = $TRUE;
  local $Data::Dumper::Sortkeys      = $TRUE;
  local $Data::Dumper::Deparse       = $TRUE;

  # convert to dumped output
  my @raw_output = split qr{\n}xsm, Dumper(@vars);

  # wrap output
  my %options = (hang => 'e=4', cont => $TRUE);
  my @output  = $self->wrap_text([@raw_output], %options);

  return @output;
}

# file_base($filepath, $exists = $FALSE)    {{{1
#
# does:   extract base name from file path
# params: $filepath - path from which to extract base name [required, str]
#         $exists   - die if param does not exist
# prints: error messages
# return: scalar string
sub file_base ($self, $filepath, $exists = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  if ($exists and not $self->file_readable($filepath)) {
    confess "Filepath '$filepath' does not exist";
  }

  return (File::Basename::fileparse($filepath, qr/[.][^.]*\z/xsm))[0];
}

# file_cat_dir($filepath, $dirpath, $exists = $FALSE)    {{{1
#
# does:   extract filename from filepath and add it to a dirpath
# params: $filepath - path from which to extract file name
#                     [required, str, can be file name only]
#         $dirpath  - path to add file to [required, str]
#         $exists   - die if either param does not exist
#                     [optional, bool, default=false]
# prints: error messages
# return: scalar string
sub file_cat_dir ($self, $filepath, $dirpath, $exists = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess 'No dirpath provided' if not $dirpath;
  confess $MSG_NO_FILEPATH      if not $filepath;
  if ($exists) {
    if (not $self->file_readable($filepath)) {
      confess "Filepath '$filepath' does not exist";
    }
    if (not -d $dirpath) {
      confess "Directory path '$dirpath' does not exist";
    }
  }

  my $file = $self->file_name($filepath);
  return File::Spec->catfile($dirpath, $file);
}

# file_cmdline_args()    {{{1
#
# does:   assume all arguments in ARGV are file globs and expand them
# params: nil
# prints: error messages
# return: list of strings
sub file_cmdline_args ($self) { ## no critic (RequireInterpolationOfMetachars)
  my @matches;                  # get unique file names
  for my $arg (@ARGV) { push @matches, glob "$arg"; }
  my @unique_matches = List::SomeUtils::uniq @matches;
  my @files =
      grep { $self->file_readable($_) } @unique_matches;    # ignore non-files

  return [@files];
}

# file_copy($source_file, $target)    {{{1
#
# does:   copy a file
# params: $source_file - file to copy
#                        [required, filepath, must exist]
#         $target      - filepath/directory to copy to
#                        [required, path, created if necessary]
# prints: error message on failure
# return: nil, dies on failure
sub file_copy ($self, $source_file, $target)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess $MSG_NO_TARGET if not $target;
  confess $MSG_NO_SOURCE if not $source_file;
  if (not $self->file_readable($source_file)) {
    confess "Source file '$source_file' does not exist";
  }

  File::Copy::Recursive::fcopy($source_file, $target) or confess $ERRNO;

  return;
}

# file_identical($fp_1, $fp_2)    {{{1
#
# does:   compare two files to see if they are identical
# params: $fp_1 - file to compare [required, filepath, must exist]
#         $fp_2 - file to compare [required, filepath, must exist]
# prints: error message on failure
# return: scalar boolean, dies on failure
sub file_identical ($self, $fp_1, $fp_2)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess 'Filepath 1 not provided' if not $fp_1;
  confess 'Filepath 2 not provided' if not $fp_2;
  for my $filepath ($fp_1, $fp_2) {
    if (not $self->file_readable($filepath)) {
      confess "Comparison file '$filepath' does not exist";
    }
  }

  # compare files
  my $compare = File::Compare::compare($fp_1, $fp_2);
  if ($compare == $FILE_COMPARE_ERROR) {
    confess "Unable to compare '$fp_1' and '$fp_2': $ERRNO";
  }

  # File::Compare::compare has reversed return values
  # - i.e., returns 0 if files identical and 1 if file not identical
  return not $compare;
}

# file_is_deb($filepath)    {{{1
#
# does:   determine whether file is a debian package file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
sub file_is_deb ($self, $filepath)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $filepath)    { confess $MSG_NO_FILEPATH; }
  if (not -r $filepath) { confess "Invalid filepath '$filepath'"; }
  my @mimetypes =
      ('application/x-deb', 'application/vnd.debian.binary-package');
  foreach my $mimetype (@mimetypes) {
    if ($self->file_is_mimetype($filepath, $mimetype)) {
      return $TRUE;
    }
  }
  return $FALSE;
}

# file_is_mimetype($filepath, $mimetype)    {{{1
#
# does:   determine whether file is a specified mimetype
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
#         $mimetype - mime type to test for [required]
# prints: nil
# return: scalar boolean
sub file_is_mimetype ($self, $filepath, $mimetype)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $mimetype) { confess 'No mimetype provided'; }
  my $filetype = $self->file_mime_type($filepath);
  if (not $filetype) { return $FALSE; }
  return $filetype =~ m{\A$mimetype\z}xsm;
}

# file_is_perl($filepath)    {{{1
#
# does:   determine whether file is a perl executable file,
#         does not detect perl module files
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
sub file_is_perl ($self, $filepath)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $filepath)    { confess $MSG_NO_FILEPATH; }
  if (not -r $filepath) { confess "Invalid filepath '$filepath'"; }

  # check for mimetype match
  my @mimetypes = ('application/x-perl', 'text/x-perl');
  foreach my $mimetype (@mimetypes) {
    if ($self->file_is_mimetype($filepath, $mimetype)) {
      return $TRUE;
    }
  }

  # mimetype detection can fail if filename has no extension
  # so look for shebang and see if it is a perl interpreter
  my $fh;
  if (not(open $fh, '<', $filepath)) {
    confess "Unable to open file '$filepath' for reading";
  }
  my @lines = <$fh>;
  if (not(close $fh)) {
    confess "Unable to close file '$filepath'";
  }
  chomp @lines;
  foreach my $line (@lines) {
    if ($line =~ /^ \s* [#] [!] (\S+) /xsm) {
      my $interpreter = $1;
      my $executable  = $self->file_name($interpreter);
      if ($executable eq 'perl') { return $TRUE; }
      last;
    }
  }
  return $FALSE;
}

# file_list([$dir[, $pattern]])    {{{1
#
# does:   list files in directory
# params: $dir     - directory path [string, optional, default=cwd]
#         $pattern - file name pattern to match
#                    [regex (qr//), optional, default=all files]
# prints: nil
# return: list, die if operation fails
sub file_list ($self, $dir = undef, $pattern = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # process parameters
  if (not $dir) { $dir = $self->cwd(); }
  $dir = $self->path_true($dir);
  if (not -d $dir) { confess "Invalid directory: $dir"; }
  if ($pattern) {
    my $dump = $self->dump_var($pattern);
    my $ref  = ref $pattern;
    if ($ref ne $CLASS_REGEXP) {
      confess "Invalid regex file pattern: $dump";
    }
    my $blessed = Scalar::Util::blessed($pattern);
    if ($blessed ne $CLASS_REGEXP) {
      confess "Invalid regex file pattern: $dump";
    }
    my $reftype = Scalar::Util::reftype($pattern);
    if ($reftype ne 'REGEXP') {
      confess "Invalid regex file pattern: $dump";
    }
  }

  # get directory contents
  my $dir_obj = Path::Tiny::path($dir);
  my @children;
  if   ($pattern) { @children = $dir_obj->children($pattern); }
  else            { @children = $dir_obj->children; }

  # filter for files
  my @fp_objects = grep { not $_->is_dir } @children;
  my @files      = map  { $_->basename } @fp_objects;

  # sort for return
  my @sorted_files = sort @files;
  return @sorted_files;
}

# file_mime_type($filepath)    {{{1
#
# does:   determine mime type of file
# params: $filepath - file to analyse [required]
#                     dies if missing or invalid
# prints: nil
# return: scalar boolean
# note:   this method previously used File::Type::mime_type but that
#         module incorrectly identifies some mp3 files as
#         'application/octet-stream'
# note:   uses File::MimeInfo: alternatives include File::MMagic and
#         File::MMagic:Magic
sub file_mime_type ($self, $filepath)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $filepath)    { confess $MSG_NO_FILEPATH; }
  if (not -r $filepath) { confess "Invalid filepath '$filepath'"; }
  return File::MimeInfo->new()->mimetype($filepath);
}

# file_move($source_file, $target)    {{{1
#
# does:   move a file
# params: $source_file - file to move
#                        [required, filepath, must exist]
#         $target      - filepath/directory to move to
#                        [required, path, created if necessary]
# prints: error message on failure
# return: nil, dies on failure
sub file_move ($self, $source_file, $target)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_TARGET if not $target;
  confess $MSG_NO_SOURCE if not $source_file;
  if (not $self->file_readable($source_file)) {
    confess "Source file '$source_file' does not exist";
  }

  # fatal error can occur if source and target filepaths are identical
  return if $source_file eq $target;

  File::Copy::Recursive::fmove($source_file, $target) or confess $ERRNO;

  return;
}

# file_name($filepath, $exists = $FALSE)    {{{1
#
# does:   extract filename from filepath
# params: $filepath - path from which to extract file name
#                     [required, str, can be file name only]
#         $exists   - die if filepath does not exist
#                     [optional, bool, default=false]
# prints: error messages
# return: scalar string
sub file_name ($self, $filepath, $exists = $FALSE)
{    ## no critic(RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  if ($exists and not $self->file_readable($filepath)) {
    confess "Filepath '$filepath' does not exist";
  }

  return (File::Spec->splitpath($filepath))[2];
}

# file_name_duplicates(@filepaths)    {{{1
#
# does:   find duplicate file names in set of filepaths, i.e., same
#         file name in different directories
# params: @filepaths - filenames to analyse [optional, str]
# prints: nil
# return: hashref: {filename => [filepath1, filepath2, ...], ...}
sub file_name_duplicates ($self, @fps)
{    ## no critic (RequireInterpolationOfMetachars)
  return {} if not @fps;

  # extract file names and use them as hash keys, with key values
  # being the corresponding file paths
  my %names;
  for my $fp (@fps) {
    my $name = $self->file_name($fp);
    if   (exists $names{$name}) { push @{ $names{$name} }, $fp; }
    else                        { push @{ $names{$name} }, [$fp]; }
  }

  # find file names with multiple associated file paths
  my @multiple = grep { scalar @{ $names{$_} } > 1 } keys %names;

  # create hash with details of these file names and paths
  my %dupes;
  for my $name (@multiple) { $dupes{$name} = $names{$name}; }

  return {%dupes};
}

# file_name_parts($filepath, $exists = $FALSE)    {{{1
#
# does:   extract base name and suffix from file path
# params: $filepath - path from which to extract base name [required, str]
#         $exists   - die if param does not exist
#                     [optional, boolean, default=false]
# prints: error messages
# return: list of strings ($base, $suffix)
# note:   suffix includes period separator
sub file_name_parts ($self, $filepath, $exists = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  if ($exists and not $self->file_readable($filepath)) {
    confess "Filepath '$filepath' does not exist";
  }

  return (File::Basename::fileparse($filepath, qr/[.][^.]*\z/xsm))[ 0, 2 ];
}

# file_read($fp)    {{{1
#
# does:   read contents of a file
# params: $fp - file path to read from
#               [string or Path::Tiny object, required]
# prints: error messages
# return: arrayref of content lines, dies on failure
sub file_read ($self, $fp) {    ## no critic (RequireInterpolationOfMetachars)

  # set vars
  if (not defined $fp) { confess $MSG_NO_FILEPATH; }
  my $fp_reftype  = Scalar::Util::reftype $fp;
  my $fp_obj_type = Scalar::Util::blessed $fp;
  my $src;

  if (defined $fp_reftype) {

    # is a reference
    if (defined $fp_obj_type) {

      # is an object
      if ($fp_obj_type eq $MOD_PATH_TINY) {
        $src = $fp;
      }
      else {
        confess "Invalid file: is $fp_obj_type object";
      }
    }
    else {
      # is a reference that is not an object
      confess "Invalid file: is $fp_reftype";
    }
  }
  else {
    # scalar, presumed to be string file path
    $src = Path::Tiny::path($fp)->absolute;
  }
  if (not $src) {
    confess 'Unable to determine source file path';
  }

  # read file
  # - slurp reads file contents into a scalar variable
  my $contents;
  try {
    $contents = $src->slurp_utf8;
  }
  catch ($err) {
    confess "Unable to read from '$src': $err";
  }
  my @lines = split /\n/xsm, $contents;

  # return file contents
  return [@lines];
}

# file_readable(@filepaths)    {{{1
#
# does:   determine whether paths are (symlinks to) valid plain
#         files and are readable
# params: @filepaths - paths to be analysed [required, str]
# prints: error messages
# return: scalar boolean, dies on failure
sub file_readable ($self, @filepaths)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess 'No filepaths' if not @filepaths;

  # cycle through filepaths
  for my $filepath (@filepaths) {
    my $path_true = $self->path_true($filepath);
    if (not(-e $path_true and -r $path_true)) { return $FALSE; }
  }

  # no unreadable files found
  return $TRUE;
}

# file_write($content, $fp, [$perm])    {{{1
#
# params: $content - file content [array reference, required]
#         $fp      - file path to write to
#                    [string or Path::Tiny object, required]
#         $perm    - permissions for file [quoted octal string, optional,
#                                          default=current umask]
# prints: nil, except on failure
# return: n/a, dies on file operation failure
# notes:  if file exists it will be silently overwritten
sub file_write ($self, $content, $fp, $perm = undef)
{    ## no critic (RequireInterpolationOfMetachars RequireFinalReturn)

  # set vars
  if (not $content)                    { confess 'No content provided'; }
  if (ref $content ne $REF_TYPE_ARRAY) { confess 'Content not an array'; }
  if (not $fp)                         { confess $MSG_NO_FILEPATH; }
  my $dest;
  my $fp_reftype  = Scalar::Util::reftype $fp;
  my $fp_obj_type = Scalar::Util::blessed $fp;
  if (defined $fp_reftype) {

    # is a reference
    if (defined $fp_obj_type) {

      # is an object
      if ($fp_obj_type eq $MOD_PATH_TINY) {
        $dest = $fp;
      }
      else {
        confess "Invalid file: is $fp_obj_type object";
      }
    }
    else {
      # is a reference that is not an object
      confess "Invalid file: is $fp_reftype";
    }
  }
  else {
    # scalar, presumed to be string file path
    $dest = Path::Tiny::path($fp)->absolute;
  }
  if (not $dest) {
    confess 'Unable to determine destination file path';
  }

  # write file
  my @lines = map {"$_\n"} @{$content};
  try {
    $dest->spew_utf8(@lines);
  }
  catch ($err) {
    confess "Unable to write to '$dest': $err";
  }

  # set file permissions
  # - combination of 'if' and Feature::Compat::Try::try confuses perlcritic
  if ($perm) {    ## no critic (ProhibitPostfixControls)
    try {
      $dest->chmod($perm);
    }
    catch ($err) {
      confess "Unable to modify permissions of '$dest': $err";
    };
  }

  return;
}

# image_add_border($image, $side, $top_bottom, $fill = 'none')    {{{1
#
# does:   add borders to image (left=right and top=bottom)
# params: $image      - image object [required, Image::Magick object]
#         $side       - width of each of the left and right borders
#                       [required, int, pixels]
#         $top_bottom - width of each of the top and bottom borders
#                       [required, int, pixels]
#         $fill       - border color [optional, str|rgb, default='none']
# prints: error messages
# return: nil, edits $image in place
# note:   no border is added if border widths are zero
sub image_add_border ($self, $i, $s, $t, $f = 'none')
{    ## no critic (RequireInterpolationOfMetachars)

  # use more intuitive variable names
  my ($image, $side, $top_bottom, $fill) = ($i, $s, $t, $f);

  # check args
  # - if no border widths provided, assume user is only resizing
  return if not($side and $top_bottom);

  # - otherwise need all values
  confess 'Empty color'                         if not $fill;
  confess 'No top/bottom border width provided' if not $top_bottom;
  confess 'No side border width provided'       if not $side;
  confess $MSG_NO_IMAGE                         if not $image;
  confess "Non-integer border width '$top_bottom'"
      if not $self->int_pos_valid($top_bottom);
  confess "Non-integer border width '$side'"
      if not $self->int_pos_valid($side);
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);
  if ($side == 0 and $top_bottom == 0) { return; }

  # prepare arguments for size function
  my $width  = $self->image_width($image);
  my $height = $self->image_height($image);
  $width  += ($side * 2);
  $height += ($top_bottom * 2);
  my %args;
  $args{$KEY_GEOMETRY}   = "${width}x${height}";
  $args{$KEY_BACKGROUND} = $fill;
  $args{$KEY_GRAVITY}    = $VAL_CENTER;

  # resize image
  my $err;
  $err = $image->Extent(%args);
  confess "Image::Magick->Extent failed: $err" if "$err";

  return;
}

# image_create($filepath, $attributes)    {{{1
#
# does:   create Image::Magick object for image file
# params: $filepath   - image file path [required, str]
#         $attributes - Image::Magick attributes [optional, hashref]
# prints: error messages
# return: Image::Magick object
sub image_create ($self, $filepath, $attributes = undef)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  confess "Invalid filepath '$filepath'"
      if not $self->file_readable($filepath);
  if ($attributes) {
    my $ref = ref $attributes;
    confess "Invalid attributes var type '$ref'" if $ref ne $REF_TYPE_HASH;
  }

  # create image
  my $image = Image::Magick->new;
  my $err;
  my %attrs = ($attributes) ? %{$attributes} : ();
  if (%attrs) {
    $err = $image->Set(%attrs);
    confess "Image::Magick->Set failed on image '$filepath': $err"
        if "$err";
  }
  $err = $image->Read($filepath);
  confess "Image::Magick->Read failed on image '$filepath': $err"
      if "$err";

  return $image;
}

# image_crop ($image, $coords)    {{{1
#
# does:   crop Image::Magick object
# params: $image  - image object [required, Image::Magick object]
#         $coords - boundary pixel coordinates
#                   [required, hash reference]
#                   with keys [all required, int values]
#                   •     top_left_x = top left pixel's x coordinate
#                   •     top_left_y = top left pixel's y coordinate
#                   • bottom_right_x = bottom-right pixel's x coordinate
#                   • bottom_right_y = bottom-right pixel's y coordinate
# prints: error messages
# return: nil, edits $image in place
sub image_crop ($self, $image, $coords_ref)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  # - need array reference
  if (not $coords_ref) {
    confess 'No boundary pixel coordinates provided';
  }
  my $ref = ref $coords_ref;
  if (not $ref) {
    confess $MSG_SCALAR_NOT_HASHREF ;
  }
  if ($ref and $ref ne $REF_TYPE_HASH) {    # not array
    confess "Args parameter is '$ref' instead of 'HASH'";
  }

  # - extract arguments
  my $top_left_x     = $coords_ref->{'top_left_x'};
  my $top_left_y     = $coords_ref->{'top_left_y'};
  my $bottom_right_x = $coords_ref->{'bottom_right_x'};
  my $bottom_right_y = $coords_ref->{'bottom_right_y'};

  # - note that coordinates can be zero, hence use of 'defined'
  confess 'No bottom-right pixel y-coord provided'
      if not defined $bottom_right_y;
  confess 'No bottom-right pixel x-coord provided'
      if not defined $bottom_right_x;
  confess 'No top_left pixel y-coordinate provided'
      if not defined $top_left_y;
  confess 'No top_left pixel x-coordinate provided'
      if not defined $top_left_x;

  # check args
  my @coords = ($top_left_x, $top_left_y, $bottom_right_x, $bottom_right_y);
  for my $coord (@coords) {
    confess "Invalid coordinate '$coord'"
        if not $self->int_pos_valid($coord);
  }
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  # convert coordinates to dimensions and offsets
  my $width    = $bottom_right_x - $top_left_x + 1;
  my $height   = $bottom_right_y - $top_left_y + 1;
  my $x_offset = $top_left_x;
  my $y_offset = $top_left_y;

  # get geometry param
  my $geometry = sprintf '%sx%s+%s+%s', $width, $height, $x_offset, $y_offset;

  # crop image
  my $err;
  $err = $image->Crop(geometry => $geometry);
  confess "Image::Magic->Crop failed: $err" if "$err";

  return;
}

# image_files_valid(@filepaths)    {{{1
#
# does:   ensure all files can be opened as images
# params: @filepaths - image file paths [optional, str list]
# prints: feedback, e.g., "Verifying $count image files:"
# prints: error messages
# return: scalar boolean
# warn:   returns true if no parameter provided
# note:   croaks of Image::Magick module unable to open file as image
sub image_files_valid ($self, @filepaths)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)
  if (not @filepaths) {
    warn "No image files to verify\n";
    return $FALSE;
  }
  my $count    = @filepaths;
  my $progress = 0;
  if ($count == 1) {
    say "Verifying image file '$filepaths[0]'"
        or confess $MSG_NO_TERM_OUTPUT ;
  }
  else {
    say "Verifying $count image files:"
        or confess $MSG_NO_TERM_OUTPUT ;
    $progress = Term::ProgressBar::Simple->new($count);
  }
  for my $filepath (@filepaths) {
    my $image = $self->image_create($filepath);  # croaks if fails
    undef $image;                                # avoid memory cache overflow
    $progress++;
  }
  undef $progress;    # ensure final messages displayed

  return $TRUE;
}

# image_height($image)    {{{1
#
# does:   get image height in pixels
# params: $image - image object [required, Image::Magick object]
# prints: error messages
# return: scalar integer
sub image_height ($self, $image)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess $MSG_NO_IMAGE    if not $image;
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  return $image->Get($PARAM_HEIGHT);
}

# image_label($image, $text, $opts)    {{{1
#
# does:   add label to image
# params: $image - image object [required, Image::Magick object]
#         $text  - label text [required, string]
#         $opts  - optional settings [optional, hash reference]
#                  has keys:
#                  •  font - label font
#                            [optional, int, default selected by ImageMagick]
#                  •  size - label font size (pt)
#                            [optional, int, default=0]
#                  • color - label font color_content
#                            [optional, string, default='black']
#                  •  edge - label location
#                            [optional, 'north|south|east|west', default='south']
#                  • space - space between edge and label (pt)
#                            [optional, int, default=0]
# prints: error messages
# return: nil, edits $image in place
sub image_label ($self, $image, $text, $opts)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  # - need array reference
  if (not $opts) { $opts = {}; }
  my $ref = ref $opts;
  if (not $ref) {
    confess $MSG_SCALAR_NOT_HASHREF ;
  }
  if ($ref and $ref ne $REF_TYPE_HASH) {    # not array
    confess "Args parameter is '$ref' instead of 'HASH'";
  }

  # - extract arguments
  my $font  = $opts->{$KEY_FONT};
  my $size  = $opts->{'size'};
  my $color = $opts->{'color'};
  my $edge  = $opts->{'edge'};
  my $space = $opts->{'space'};

  # - otherwise need all values
  confess 'No label text provided' if not $text;
  confess $MSG_NO_IMAGE            if not $image;
  confess $MSG_NOT_IMG_OBJ         if not $self->image_object($image);
  if (defined $space) {
    if (not $self->int_pos_valid($space)) {
      die "Invalid space value '$space'\n";
    }
  }
  if (not $edge) { $edge = 'south'; }
  my %valid_edge = map { $_ => $TRUE } qw(north south east west);
  confess "Invalid edge '$edge'" if not $valid_edge{$edge};
  if (defined $size) {
    die "Invalid size value '$size'\n"
        if not $self->int_pos_valid($size);
  }

  # assemble parameters
  my %params = (text => $text, gravity => $edge);
  if ($font)  { $params{$KEY_FONT}     = $font; }
  if ($size)  { $params{'pointsize'}   = $size; }
  if ($color) { $params{'stroke'}      = $color; }
  if ($space) { $params{$KEY_GEOMETRY} = '+0+' . $space; }

  my $err;

  # label image
  $err = $image->Annotate(%params);
  confess "Image::Magick->Annotate failed: $err" if "$err";

  return;
}

# image_max_dimensions(@filepaths)    {{{1
#
# does:   determine maximum width and height of images
# params: @filepaths - image file paths [optional, list]
# prints: error messages
# return: ( $width, $height )  # pixels, scalar integers
# warn:   returns (0, 0) if no parameter provided
# note:   longest width and height may be from different images
sub image_max_dimensions ($self, @filepaths)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess 'No filepaths provided' if not @filepaths;
  for my $filepath (@filepaths) {
    confess "Invalid filepath '$filepath'"
        if not $self->file_readable($filepath);
  }

  # provide feedback
  my $count    = @filepaths;
  my $progress = 0;
  if ($count == 1) {
    say "Analysing image file '$filepaths[0]'"
        or confess $MSG_NO_TERM_OUTPUT ;
  }
  else {
    say "Analysing $count image files:"
        or confess $MSG_NO_TERM_OUTPUT ;
    $progress = Term::ProgressBar::Simple->new($count);
  }

  # check each file for image dimensions
  my ($max_width, $max_height) = (0, 0);
  for my $filepath (@filepaths) {
    my $image = $self->image_create($filepath);

    # update maximum height and width if necessary
    my $width  = $self->image_width($image);
    my $height = $self->image_height($image);
    if ($width > $max_width)   { $max_width  = $width; }
    if ($height > $max_height) { $max_height = $height; }

    undef $image;    # avoid memory cache overflow
    $progress++;
  }
  undef $progress;    # ensure final messages displayed

  return ($max_width, $max_height);
}

# image_max_x($image)    {{{1
#
# does:   get maximum pixel x-coordinate for image
# params: $image - image object [required, Image::Magick object]
# prints: error messages
# return: scalar integer
sub image_max_x ($self, $image)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_IMAGE    if not $image;
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  return $self->image_width($image) - 1;
}

# image_max_y($image)    {{{1
#
# does:   get maximum pixel y-coordinate for image
# params: $image - image object [required, Image::Magick object]
# prints: error messages
# return: scalar integer
sub image_max_y ($self, $image)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_IMAGE    if not $image;
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  return $self->image_height($image) - 1;
}

# image_object($object)    {{{1
#
# does:   verify that object is an Image::Magick object
# params: $object - object to analyse [required, scalar reference]
# prints: error messages
# return: scalar boolean
sub image_object ($self, $object)
{    ## no critic (RequireInterpolationOfMetachars)

  return $FALSE if not $object;
  my $object_type = Scalar::Util::blessed $object;
  return $FALSE if not $object_type;    # not an object
  return $object_type eq 'Image::Magick';
}

# image_pixel_color($image, $x, $y, [@color])    {{{1
#
# does:   set or get color of pixel as RGB color component values (each 0-255)
# params: $image - image [required, Image::Magick object]
#         $x     - x-coordinate of pixel [required, int]
#         $y     - y-coordinate of pixel [required, int]
#         @color - rgb components
#                  [optional, required if called as setter, int 0-255]
# prints: error messages
# return: if setter - nil
#         if getter - @color, i.e., ( $red, $green, $blue )
sub image_pixel_color ($self, $image, $x, $y, @color)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  # - note pixel coordinates can be zero, hence use of 'defined'
  confess 'No y-coordinate provided'      if not defined $y;
  confess 'No x-coordinate provided'      if not defined $x;
  confess $MSG_NO_IMAGE                   if not $image;
  confess "Non-integer y-coordinate '$y'" if not $self->int_pos_valid($y);
  confess "Non-integer x-coordinate '$x'" if not $self->int_pos_valid($x);
  confess $MSG_NOT_IMG_OBJ                if not $self->image_object($image);
  my $max_x = $self->image_max_x($image);
  my $max_y = $self->image_max_y($image);
  confess "X-coordinate $x > image's largest x-coord $max_x" if $x > $max_x;
  confess "Y-coordinate $y > image's largest y-coord $max_y" if $y > $max_y;

  if (@color) {
    my $rgb = join $PARAM_COMMA_SPACE, @color;
    if (scalar @color < $RGB_ARG_COUNT) {
      confess "Incomplete color provided ($rgb)";
    }
    if (scalar @color > $RGB_ARG_COUNT) {
      confess 'Too many arguments';
    }
    my @ok_rgb = (0 .. $RGB_ARG_MAX);
    for my $component (@color) {
      if (not $self->int_pos_valid($component)) {
        confess "Non-integer color value ($rgb)";
      }
      if (not List::SomeUtils::any { $component == $_ } @ok_rgb) {
        confess "Color value out of range ($rgb)";
      }
    }
  }

  if (@color) {    # setter

    # convert values to 0-1
    for (@color) { $_ /= $RGB_ARG_MAX; }

    # set pixel color
    $self->_image->SetPixel(x => $x, y => $y, color => [@color]);
  }
  else {           # getter

    # get color component values (3-element array, values 0-1)
    my @color = $image->GetPixel(x => $x, y => $y, normalize => $TRUE);

    # convert values to 0-255
    for (@color) { $_ *= $RGB_ARG_MAX; }

    return @color;
  }

  return $TRUE;
}

# image_resize($image, $opts)    {{{1
#
# does:   resize image
# params: $image - image object [required, Image::Magick object]
#         $opts  - configuration values [required, hash reference]
#                  with keys:
#                  •    width - target width [required, int]
#                  •   height - target height [required, int]
#                  •     fill - fill color [optional, string, default='none']
#                  • preserve - whether to preserve aspect ratio
#                  •            [optional, bool, default=true]
# prints: error messages
# return: nil, edits $image in place
sub image_resize ($self, $image, $opts)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  # - need array reference
  if (not $opts) {
    confess 'No configuration values provided';
  }
  my $ref = ref $opts;
  if (not $ref) {
    confess $MSG_SCALAR_NOT_HASHREF ;
  }
  if ($ref and $ref ne $REF_TYPE_HASH) {    # not array
    confess "Args parameter is '$ref' instead of 'HASH'";
  }

  # - extract arguments
  my $width    = $opts->{$KEY_WIDTH};
  my $height   = $opts->{$KEY_HEIGHT};
  my $fill     = $opts->{'fill'};
  my $preserve = $opts->{'preserve'};

  # - if no dimensions provided, assume user is only adding borders
  return if not($width and $height);

  # - otherwise need all values
  confess 'No fill color provided'     if not $fill;
  confess 'No width provided'          if not $width;
  confess 'No height provided'         if not $height;
  confess $MSG_NO_IMAGE                if not $image;
  confess "Non-integer width '$width'" if not $self->int_pos_valid($width);
  confess "Non-integer height '$height'"
      if not $self->int_pos_valid($height);
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  # the terminology gets a little confusing here
  # - the Resize functions *scales* the image
  #   . if preserving aspect ratio the image itself will scale
  #     up or down until one dimension matches the resized
  #     dimensions, and the other is smaller (unless aspect
  #     ratios of the original image and resize dimensions
  #     match perfectly
  # - the Extent function, though, actually *resizes* the image
  #   to the new dimensions, adding fill (background) color to
  #   extend the image to the new size
  # - thus *scaling* is done by the Resize function,
  #   and *resizing* is done by the Extent function

  # prepare argument for Resize function (which *scales* image)
  my %scale_args;
  if ($preserve) { $scale_args{$KEY_GEOMETRY} = "${width}x${height}"; }
  else {
    $scale_args{$KEY_WIDTH}  = $width;
    $scale_args{$KEY_HEIGHT} = $height;
  }

  my $err;

  # scale image
  $err = $image->Resize(%scale_args);
  confess "Image::Magick->Resize failed: $err" if "$err";

  # prepare argument for Extent function (which *resizes* image)
  my %resize_args;
  $resize_args{$KEY_GEOMETRY}   = "${width}x${height}";
  $resize_args{$KEY_BACKGROUND} = $fill;
  $resize_args{$KEY_GRAVITY}    = $VAL_CENTER;

  # resize image
  $err = $image->Extent(%resize_args);
  confess "Image::Magick->Extent failed: $err" if "$err";

  return;
}

# image_width($image)    {{{1
#
# does:   get image width in pixels
# params: $image - image object [required, Image::Magick object]
# prints: error messages
# return: scalar integer
sub image_width ($self, $image)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_IMAGE    if not $image;
  confess $MSG_NOT_IMG_OBJ if not $self->image_object($image);

  return $image->Get($PARAM_WIDTH);
}

# image_write($image, $filemask)    {{{1
#
# does:   write image to file
# params: $image    - image object [required, Image::Magick object]
#         $filemask - target file mask [required, Str]
# prints: error messages
# return: nil
# note:   if file mask contains printf-like formatting it can serve
#         as basis for multiple output files
sub image_write ($self, $image, $filemask)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess 'No file mask provided' if not $filemask;
  confess $MSG_NO_IMAGE           if not $image;
  confess $MSG_NOT_IMG_OBJ        if not $self->image_object($image);

  # leftover geometry offsets can be problematic, so repage
  my $err;
  $err = $image->Set(page => '0x0+0+0');
  confess "Image::Magick->Set failed: $err" if "$err";

  # write file
  $err = $image->Write(filename => $filemask);
  confess "Image::Magick->Write failed: $err" if "$err";

  return;
}

# int_pad_width($max_int)    {{{1
#
# does:   maximum width of an integer sequence, i.e., the value that
#         would determine how much padding is necesary to ensure
#         all integers in the sequence are the same length
# params: $max_int - largest integer in sequence [required, int]
# prints: nil
# return: scalar integer
sub int_pad_width ($self, $max_int)
{    ## no critic (RequireInterpolationOfMetachars)
  return 1 if not $max_int;
  confess "Invalid integer '$max_int'"
      if not $self->int_pos_valid($max_int);
  return length $max_int;
}

# int_pos_valid($value)    {{{1
#
# does:   whether value is a positive integer
# params: $value - item to be analysed [required]
# prints: nil
# return: scalar boolean
sub int_pos_valid ($self, $value)
{    ## no critic (RequireInterpolationOfMetachars)
  return $FALSE if not defined $value;
  for ($value) {
    if    (/^[+]?0$/xsm)         { return $TRUE; }    # zero
    elsif (/^[+]?[1-9]\d*\z/xsm) { return $TRUE; }    # above zero
    else                         { return $FALSE; }
  }
  return $FALSE;
}

# int_valid($value)    {{{1
#
# does:   whether value is an integer
# params: $value - item to be analysed [required]
# prints: nil
# return: scalar boolean
sub int_valid ($self, $value)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)
  return $FALSE if not defined $value;
  for ($value) {
    if    (/^[+-]?0\z/xsm)        { return $TRUE; }    # zero
    elsif (/^[+-]?[1-9]\d*\z/xsm) { return $TRUE; }    # other int
    else                          { return $FALSE; }
  }
  return $FALSE;
}

# interact_ask($prompt, [$default])    {{{1
#
# does:   get input from user
# params: $prompt  - user prompt [required, can be multi-line (use "\n")]
#         $default - default input [optional, default=q{}]
# prints: user interaction
#         after user answers, all but first line of question
#           is removed from the screen
#         input also remains on screen
# return: user input (scalar)
# note:   intended for entering short values
#         once the line wraps the user cannot move to previous line
# uses:   Term::Clui
sub interact_ask ($self, $prompt, $default = q{})
{    ## no critic (RequireInterpolationOfMetachars)
  return Term::Clui::ask($prompt, $default);
}

# interact_choose($prompt, @options)    {{{1
#
# does:   user selects option from a menu
# params: $prompt  - menu prompt [required]
#         @options - menu options [required]
# prints: menu and user interaction
# usage:  my @options = ( 'Pick me', 'No, me!' );
#         my $value = undef;
#         while ($TRUE) {
#             $value = $self->interact_choose(
#                 "Select value:", @options,
#             );
#             last if $value;
#             say "Invalid choice. Sorry, please try again.";
#          }
# return: scalar (undef if user cancels selection)
sub interact_choose ($self, $prompt, @options)
{    ## no critic (RequireInterpolationOfMetachars)

  # process args
  if (not @options) { croak 'No menu options provided'; }

  # get user selection
  my $choice = Term::Clui::choose($prompt, @options);
  return $choice;
}

# interact_confirm($question)    {{{1
#
# does:   user answers y/n to a question
# params: $question - question to be answered with yes or no
#                     [required, can be multi-line (use "\n")]
# prints: user interaction
#         after user answers, all but first line of question
#           is removed from the screen
#         answer also remains on screen
# return: scalar boolean
# usage:  my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
#         if ( $self->interact_confirm($prompt) ) {
#             # do stuff
#         }
sub interact_confirm ($self, $question)
{    ## no critic (RequireInterpolationOfMetachars)

  if (not $question) { return $FALSE; }
  local $ENV{CLUI_DIR} = 'OFF';    # do not remember responses
  return Term::Clui::confirm($question);
}

# interact_print(msg)    {{{1
#
# does:   print message to stdout if script is interactice,
#         i.e., connected to a console, otherwise message is not printed
# params: msg - text to print [scalar, required]
# prints: message (if connected to console)
# return: nil
sub interact_print ($self, $msg)
{    ## no critic (RequireInterpolationOfMetachars)

  # IO::Interactive takes care of failed syscall
  ## no critic (RequireCheckedSyscalls)
  print {IO::Interactive::interactive} $msg;
  ## use critic
  return;
}

# interact_prompt([message])    {{{1
#
# does:   display message and prompt user to press any key
# params: message - prompt message [optional]
#                   [default='Press any key to continue...']
# prints: prompt message
# return: nil
sub interact_prompt ($self, $message = 'Press any key to continue...')
{    ## no critic (RequireInterpolationOfMetachars)
  print $message or croak;
  Term::ReadKey::ReadMode('raw');
  while ($TRUE) {
    my $key = Term::ReadKey::ReadKey(0);
    last if defined $key;
  }
  Term::ReadKey::ReadMode('restore');
  print $NEWLINE or croak;
  return;
}

# interact_say(msg)    {{{1
#
# does:   print message to stderr (with newline) if script is interactice,
#         i.e., connected to a console, otherwise message is not printed
# params: msg - text to print [scalar, required]
# prints: message with newline (if connected to console)
# return: nil
sub interact_say ($self, $msg)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # IO::Interactive takes care of failed syscall
  ## no critic (RequireCheckedSyscalls)
  say {IO::Interactive::interactive} $msg;
  ## use critic
  return;
}

# interact_warn(msg)    {{{1
#
# does:   print message (with newline) to stderr if script is interactice,
#         i.e., connected to a console, otherwise message is not printed
# params: msg - text to print [scalar, required]
# prints: message with newline to stderr (if connected to console)
# return: nil
sub interact_warn ($self, $msg)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # IO::Interactive takes care of failed syscall
  ## no critic (RequireCheckedSyscalls)
  say { IO::Interactive::interactive(*STDERR) } $msg;
  ## use critic
  return;
}

# internet_connection([$verbose])    {{{1
#
# does:   determine whether an internet connection can be found
# params: $verbose - whether to provide feedback [optional, default=false]
# prints: feedback if requested
# return: boolean
sub internet_connection ($self, $verbose = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars)
  my $connected;
  my @urls         = ('www.debian.org', 'www.uq.edu.au');
  my $max_attempts = @urls;
  my $timeout      = 1;                                     # seconds
  if ($verbose) {
    say "Checking internet connection (maximum $max_attempts attempts):"
        or croak;
  }

  foreach my $index (0 .. $#urls) {
    my $url            = $urls[$index];
    my $attempt_number = $index + 1;
    if ($verbose) { print "  Attempt $attempt_number... " or croak; }
    if (
      Net::Ping::External::ping(
        hostname => $url,
        timeout  => $timeout,    # appears to be ignored
      )
        )
    {
      $connected = $TRUE;
      if ($verbose) { say 'OK' or croak; }
      last;
    }
    else {
      if ($verbose) { say 'Failed' or croak; }
    }
  }
  if ($connected) {
    if ($verbose) { say 'Internet connection detected' or croak; }
    return $TRUE;
  }
  else {
    if ($verbose) { say 'No internet connection detected' or croak; }
    return $FALSE;
  }
}

# listify(@items)    {{{1
#
# does:   tries to convert scalar, array and hash references to scalars
# params: @items - items to convert to lists [required]
# prints: warnings for other reference types
# return: list
sub listify ($self, @items) {   ## no critic (RequireInterpolationOfMetachars)
  my (@scalars, $scalar, @array, %hash);
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
          foreach my $key (keys %hash) {
            push @scalars, $self->listify($key);
            push @scalars, $self->listify($hash{$key});
          }
        }
        else {
          my $stringified_item = Dumper($item);
          my $divider          = $self->divider;
          $self->interact_warn("Cannot listify a '$ref'\n");
          $self->interact_warn('Item dump:');
          $self->interact_warn($divider);
          $self->interact_warn($stringified_item);
          $self->interact_warn($divider);
        }
      }
    }
    else {
      push @scalars, $item;
    }
  }
  if (not @scalars) { return qw(); }
  return @scalars;
}

# list_duplicates(@values)    {{{1
#
# does:   return list of duplicate list elements
# params: @values - list to be processed [optional, list]
# prints: warning if references found in list
# return: list
# note:   non-scalar values are assumed to be unique
# note:   element order is not preserved
sub list_duplicates ($self, @values)
{    ## no critic (RequireInterpolationOfMetachars)

  my (@duplicates, @scalars);

  # assume non-scalars are unique
  for my $value (@values) {
    if   (ref $value) { push @duplicates, $value; }
    else              { push @scalars,    $value; }
  }

  # find scalar duplicates
  my %count;
  for my $value (@values) { $count{$value}++; }
  push @duplicates, grep { $count{$_} > 1 } keys %count;

  return @duplicates;
}

# pad($values[, $width[, $char[, $side]]] )    {{{1
#
# does:   left- or right-pad a value or list of values with a character
# params: $values - simple scalar or arrayref of values
#                   [empty scalar or arrayref allowed]
#                   [error if not simple scalar or arrayref]
#         $width  - integer [optional, default: longest item]
#                           [ignore if less than longest item]
#         $char   - single char [optional]
#                               [default: 0 if all int values, else ' ']
#         $side   - whether left or right padding ['left'|'right']
#                                                 [default: 'left']
# prints: nil
# return: scalar string if input is simple scalar
#         list if input is array ref
# credit: pad methods from https://www.tek-tips.com/viewthread.cfm?qid=184815
sub pad ($self, @params)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)

  # params    {{{2
  my ($values, $width, $char, $side) = @params;
  if (not $side)  { $side  = $VAL_LEFT; }
  if (not $width) { $width = 0; }

  # - $values    {{{3
  my @vals;
  my $ref = ref $values;
  if ($ref eq $REF_TYPE_ARRAY) {    # array
    my @array = @{$values};
    return () if not @array;
    push @vals, @array;
  }
  if ($ref and $ref ne $REF_TYPE_ARRAY) {    # not array
    confess "Values are '$ref' instead of 'ARRAY'";
  }
  if (not $ref) {                            # scalar
    return $EMPTY_STRING if not $values;
    push @vals, $values;
  }

  # - $width    {{{3
  confess "Invalid width '$width'" if not $self->int_pos_valid($width);
  my $max_width = length reduce { length($a) > length($b) ? $a : $b } @vals;
  if ($width == 0)         { $width = $max_width; }
  if ($width < $max_width) { $width = $max_width; }

  # - $char   {{{3
  if (defined $char) {
    if (length $char != 1) {
      confess "Want single pad char, got '$char'";
    }
  }
  else {    # decide on pad char
    if (List::SomeUtils::any { not $self->int_pos_valid($_) } @vals) {
      $char = $SPACE;    # not all integers, so use space
    }
    else {
      $char = q{0};      # all integers, so use zero
    }
  }

  # - $side    {{{3
  $side = lc $side;
  my %valid_side = map { $_ => $TRUE } qw(left right);
  confess "Expect side is 'left' or 'right', got '$side'"
      if not $valid_side{$side};    # }}}3

  # pad list    {{{2
  # - works only if $width >= longest list element
  # - need parentheses to enforce operator precedence
  ## no critic (ProhibitParensWithBuiltins)
  my @padded =
      ($side eq $VAL_LEFT)
      ? map { substr(($char x $width) . $_, $NEGATE * $width, $width) } @vals
      : map { substr($_ . ($char x $width), 0,                $width) } @vals;
  ## use critic

  # return padded value or list    {{{2
  return ($ref) ? @padded : $padded[0];    # }}}2
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
# note:   often used with method 'term_wrap' to format screen display
sub pager ($self, $lines, $prefer)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  if (not $lines) { confess 'No lines provided'; }
  my $ref_type = ref $lines;
  if ($ref_type ne $REF_TYPE_ARRAY) { confess $MSG_NOT_ARRAYREF; }
  my $default_pager;
  if ($prefer and $self->executable_path($prefer) and $prefer ne $PAGER) {
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

  return $TRUE;
}

# path_canon($path)    {{{1
#
# does:   get canonical path
# params: $path - path to canonicalise [required, str]
# prints: error messages
# return: scalar string - canonical path
# notes:  uses File::Spec->canonpath to clean up path, but this does not
#         resolve symlinks and relative paths -- for those use path_true; also
#         uses perl glob function in case tilde is present and needs
#         resolution, but this means a wildcard present in the input string can
#         potentially resolve to multiple matching files, which causes a fatal
#         error
sub path_canon ($self, $path) { ## no critic (RequireInterpolationOfMetachars)

  # expand tilde, but catch case where wildcard matches multiple results
  my @glob_matches = glob $path;
  confess "Multiple paths match '$path'" if scalar @glob_matches > 1;

  # return canonical path
  return File::Spec->canonpath($glob_matches[0]);
}

# path_copy($src, $dest)    {{{1
#
# does:   copy source file or directory to target file or directory
# params: $src  - source file or directory [required]
#                 must exist
#         $dest - destination file or directory [required]
#                 need not exist
# prints: nil, except for error message
# return: boolean success of copy
#         die if missing argument
# note:   can copy file to file or directory
#         can copy directory to directory
#         can not copy directory to existing file
sub path_copy ($self, $src, $dest)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args - missing argument is fatal
  if (not $src)  { confess 'No source provided'; }
  if (not $dest) { confess 'No destination provided'; }

  # convert to true path
  my $source      = $self->path_true($src);
  my $destination = $self->path_true($dest);

  # check args - source must exist
  if (not -e $source) {
    carp "Source '$src' does not exist";
    return $FALSE;
  }

  # check args - cannot copy directory onto file
  if (-d $source and -e $destination) {
    carp "Cannot copy directory '$src' onto file '$dest'";
    return $FALSE;
  }

  # perform copy
  # - function rmove tries very hard to perform copy,
  #   creating target directories where necessary
  return File::Copy::Recursive::rcopy($source, $destination);
}

# path_executable($exe)    {{{1
#
# does:   get path of executable
# params: $exe - short name of executable [required, str]
# prints: error messages
# return: path to executable, undef if not found
sub path_executable ($self, $exe)
{    ## no critic (RequireInterpolationOfMetachars)
  confess 'No executable name provided' if not $exe;
  return scalar File::Which::which($exe);
}

# path_join(@parts)    {{{1
#
# does:   concatenates list of directories and file to string path
# params: @parts - path parts [required, list]
# prints: nil
# return: scalar string path
#         die on error
sub path_join ($self, @parts) { ## no critic (RequireInterpolationOfMetachars)
  return $EMPTY_STRING if not @parts;
  return File::Spec->catfile(@parts);
}

# path_parts($filepath, $exists = $FALSE)    {{{1
#
# does:   extract directory path and file name from file path
# params: $filepath - path from which to extract parts [required, str]
#         $exists   - die if path does not exist
#                     [optional, boolean, default=false]
# prints: error messages
# return: list of strings ($dirpath, $filename)
sub path_parts ($self, $filepath, $exists = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  confess $MSG_NO_FILEPATH if not $filepath;
  if ($exists and not $self->file_readable($filepath)) {
    confess "Filepath '$filepath' does not exist";
  }

  my ($file, $dirpath, $suffix) = File::Basename::fileparse($filepath);
  return ($dirpath, $file . $suffix);
}

# path_remove(@paths)    {{{1
#
# does:   delete files and recursively delete directories
# params: @paths - one or more filepaths or dirpaths to delete [required]
# prints: error messages
# return: boolean, dies on fatal filesystem errors
sub path_remove ($self, @paths)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # check args
  return $TRUE if not @paths;

  # perform deletion
  my $success = $TRUE;
  my $options = { error => \my $errors };
  File::Path::remove_tree(@paths, $options);
  if ($errors && @{$errors}) {
    $success = $FALSE;
    for my $error (@{$errors}) {
      my ($file, $msg) = %{$error};
      if   ($file) { warn "problem deleting $file: $msg\n"; }
      else         { warn "error during deletion: $msg\n"; }
    }
  }

  return $success;
}

# path_true($path, $exists = $FALSE)    {{{1
#
# does:   convert relative path to absolute
# params: $path   - path to convert [required]
#         $exists - die if path does not exist
#                   [optional, bool, default=false]
# prints: nil
# return: scalar string
# note:   returns absolute filepaths unchanged
# note:   symlinks are followed
# note:   double quote filepath parameter if it is a variable
#         - if not, passing a value like './' results in an error
#           as it is somehow reduced to an empty value
sub path_true ($self, $path, $exists = $FALSE)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  confess $MSG_NO_FILEPATH if not $path;
  if ($exists and not $self->file_readable($path)) {
    confess "Path '$path' does not exist";
  }

  return Path::Tiny::path($path)->absolute->canonpath;
}

# pluralise($string, $numeric)    {{{1
#
# does:   adjust string based on provided numerical value
# params: $string - string to adjust [required]
#         $number - integer value [required]
# prints: nil
# return: scalar string
# note:   passes values straight through to Text::Pluralizer::pluralize
sub pluralise ($self, $string, $number)
{    ## no critic (RequireInterpolationOfMetachars)

  # check args
  if (not(defined $string)) { confess 'No string provided'; }
  if (not $string)          { return $EMPTY_STRING; }
  if (not $number)          { confess 'No number provided'; }
  if (not $self->int_pos_valid($number)) {
    confess "Number '$number' is not an integer";
  }

  # use Text::Pluralize
  return Text::Pluralize::pluralize($string, $number);
}

# run_command($err, @cmd)    {{{1
#
# does:   run system command and die with custom error message on failure
#
# params: $err - error message [scalar string, required, can be undef]
#         @cmd - command and arguments [list, required]
# prints: feedback
# return: n/a, dies on failure
#   note: displays command output in real time but does not capture it
#    see: shell_command()
sub run_command ($self, $err, @cmd)
{    ## no critic (RequireInterpolationOfMetachars)

  if (not @cmd) { confess $MSG_NO_COMMAND ; }
  my $divider = $self->divider;
  say $divider or confess;
  if (system @cmd) {

    say $divider or confess;
    my $cmd_str = join $SPACE, @cmd;
    if ($err) { warn "$err\n"; }
    warn "Failed command: $cmd_str\n";

    my $err = ${^CHILD_ERROR_NATIVE};

    # decode the exit status with POSIX module functions
    if (POSIX::WIFEXITED($err)) {
      carp '- exited with status ', POSIX::WEXITSTATUS($err), $NEWLINE;
    }
    my $exit_status = 1;
    if (POSIX::WIFSIGNALED($err)) {
      carp '- killed by signal ', POSIX::WTERMSIG($err), $NEWLINE;
      $exit_status = POSIX::WTERMSIG($err);
    }

    confess "Exit status: $exit_status";
  }
  say $divider or confess;

  return;
}

# script_name()    {{{1
#
# does:   get name of executing script
# params: nil
# prints: nil
# return: scalar file name
sub script_name ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return File::Util->new()->strip_path($PROGRAM_NAME);
}

# shell_command($cmd, $opts)    {{{1
#
# does:   run shell command and capture output
# params: $cmd  - command to run [string or array reference, required]
#         $opts - optional configuration [hash reference, optional] with keys:
#                   fatal: whether to die on command failure
#                          [bool, default=true]
#                  silent: whether to suppress output [bool, default=true]
#                          if false displays command, shell feedback,
#                          and error message on failure
#                 timeout: command timeout [int, default=0 (none)]
# return: Role::Utils::Dn::CommandResult object
#   note: if 'silent'=false then displays output while command is running
#    see: run_command()
sub shell_command ($self, $cmd, $opts = {})
{    ## no critic (RequireInterpolationOfMetachars)

  # process arguments
  my $var_values = $self->_shell_command_process_args($cmd, $opts);
  my ($cmd_string, $verbose, $fatal, $timeout, $div_top, $div_bottom) = (
    $var_values->{'cmd_string'}, $var_values->{'verbose'},
    $var_values->{'fatal'},      $var_values->{'timeout'},
    $var_values->{'div_top'},    $var_values->{'div_bottom'},
  );

  # initial feedback
  if ($verbose) {
    say $SPACE                   or croak;
    say "Running '$cmd_string':" or croak;
    say $div_top                 or croak;
  }

  # run command
  my ($succeed, $err, $full_ref, $stdout_ref, $stderr_ref) = IPC::Cmd::run(
    command => $cmd,
    verbose => $verbose,
    timeout => $timeout,
  );

  # provide final feedback
  # - errors supposedly displayed during execution,
  #   but show again to be sure
  if ($verbose) {
    if ($err) { warn "$err\n"; }
    say $div_bottom or croak;
    if (not $succeed) { say "Command failed\n" or croak; }
  }

  # die if command failed and fatal flag is set
  # - if verbose then have already shown error
  if ($fatal and not $succeed) {
    if   ($verbose) { confess "Shell command '$cmd_string' failed"; }
    else            { confess "Shell command '$cmd_string' failed: $err"; }
  }

  # process output
  # - err: has trailing newline
  if (defined $err) { chomp $err; }
  else { $err = $EMPTY_STRING; }   # prevent undef which fails type constraint

  # - full, stdout and stderr: appears that for at least some commands
  #   all output lines are put into a single string, separated with
  #   embedded newlines, which is then put into a single element list
  #   which is made into an array reference; these are unpacked below
  my @full;
  foreach my $chunk (@{$full_ref}) {
    chomp $chunk;
    my @lines = split /\n/xsm, $chunk;
    push @full, @lines;
  }
  my @stdout;
  foreach my $chunk (@{$stdout_ref}) {
    chomp $chunk;
    my @lines = split /\n/xsm, $chunk;
    push @stdout, @lines;
  }
  my @stderr;
  foreach my $chunk (@{$stderr_ref}) {
    chomp $chunk;
    my @lines = split /\n/xsm, $chunk;
    push @stderr, @lines;
  }

  # return results as an object
  return Role::Utils::Dn::CommandResult->new(
    success      => $succeed,
    error        => $err,
    full_output  => [@full],
    standard_out => [@stdout],
    standard_err => [@stderr],
  );
}

# _shell_command_process_args($cmd, $opts)    {{{1
#
# does:   process arguments to shell_command() and return derived values
# params: $cmd  - command to run [string or array reference, required]
#         $opts - optional configuration [hash reference, optional] with keys:
#                   fatal: whether to die on command failure
#                          [bool, default=true]
#                  silent: whether to suppress output [bool, default=true]
#                          if false displays command, shell feedback,
#                          and error message on failure
#                 timeout: command timeout [int, default=0 (none)]
# return: hashref with keys: cmd_string, verbose, fatal, timeout,
#                            div_top, div_bottom
#    see: shell_command()
sub _shell_command_process_args ($self, $cmd, $opts)
{    ## no critic (RequireInterpolationOfMetachars)

  # process arguments
  # - cmd
  if (not(defined $cmd)) { confess $MSG_NO_COMMAND ; }
  my $cmd_string;
  my $arg_type = ref $cmd;
  if ($arg_type eq $REF_TYPE_ARRAY) {
    my @cmd_args = @{$cmd};
    if (not @cmd_args) { confess 'No command arguments provided'; }
    $cmd_string = join $SPACE, @cmd_args;
  }
  elsif ($arg_type eq $EMPTY_STRING) {    # if not array ref must be string
    $cmd_string = $cmd;
  }
  else {
    confess 'Command is not a string or array reference';
  }

  # - opts
  my $ref_opts = ref $opts;
  if ($ref_opts eq $EMPTY_STRING) {
    croak 'Expected options hash reference, got a non-reference';
  }
  elsif ($ref_opts ne $REF_TYPE_HASH) {
    croak "Expected options to be a HASH reference, got a $ref_opts refernce";
  }
  my %opts_hash      = %{$opts};
  my %valid_opt_keys = map { $_ => $TRUE } qw(silent fatal timeout);
  for my $key (keys %opts_hash) {
    if (not $valid_opt_keys{$key}) { confess "Invalid options key '$key'"; }
  }

  # - verbose (silent)
  my $verbose = $FALSE;
  if (exists $opts_hash{$KEY_SILENT} and not $opts_hash{$KEY_SILENT}) {
    $verbose = $TRUE;
  }

  # - fatal
  my $fatal = $TRUE;
  if (exists $opts_hash{$KEY_FATAL} and not $opts_hash{$KEY_FATAL}) {
    $fatal = $FALSE;
  }

  # - timeout
  my $timeout = 0;
  if (exists $opts_hash{$KEY_TIMEOUT} and not $opts_hash{$KEY_TIMEOUT}) {
    $timeout = $opts_hash{KEY_TIMEOUT};
  }
  if (not $self->int_pos_valid($timeout)) {
    confess "timeout '$timeout' is not a valid positive integer";
  }

  # dividers
  my $div_top    = $self->divider('top');
  my $div_bottom = $self->divider('bottom');

  # prepare return variable
  my $retvals = {
    cmd_string => $cmd_string,
    verbose    => $verbose,
    fatal      => $fatal,
    timeout    => $timeout,
    div_top    => $div_top,
    div_bottom => $div_bottom,
  };

  return $retvals;
}

# stringify($value)    {{{1
#
# does:   convert all values to a string (may contain newlines)
#         non-scalar values are converted to scalars by
#         Data::Dumper::Simple's Dumper function
# params: $value - value to stringify [any, required]
# prints: nil
# return: scalar string
sub stringify ($self, $value)
{    ## no critic (RequireInterpolationOfMetachars ProhibitDuplicateLiteral)

  # no need to alter a string    {{{2
  my $value_type = Scalar::Util::reftype $value;
  if (not(defined $value_type)) { return $value; }

  # stringify anything else    {{{2
  return Dumper($value);

}

# string_entitise($string)    {{{1
#
# does:   convert reserved characters to HTML entities
# params: $string - string to analyse [required]
# prints: nil
# return: scalar string
sub string_entitise ($self, $string = q{})
{    ## no critic (RequireInterpolationOfMetachars)
  return HTML::Entities::encode_entities($string);
}

# string_tabify($string, [$tab_size])    {{{1
#
# does:   covert tab markers ('\t') to spaces
# params: $string   - string to convert [scalar, required]
#         $tab_size - size of tab in characters [integer, optional, default=4]
# prints: nil
# return: scalar string
sub string_tabify ($self, $string = q{}, $tab_size = 4)
{    ## no critic (RequireInterpolationOfMetachars)

  # set tab
  if ($tab_size !~ /^[1-9]\d*\z/xsm) { $tab_size = $TAB_SIZE; }
  my $tab = $SPACE x $tab_size;

  # convert tabs
  $string =~ s/\\t/$tab/gxsm;
  return $string;
}

# term_height()    {{{1
#
# does:   get terminal height in characters
# params: nil
# prints: nil
# return: Scalar integer
sub term_height ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my ($height, $width);
  my $mwh = Curses->new();
  $mwh->getmaxyx($height, $width);
  endwin();
  return $height;
}

# term_width()    {{{1
#
# does:   get terminal width in characters
# params: nil
# prints: nil
# return: Scalar integer
sub term_width ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my ($height, $width);
  my $mwh = Curses->new();
  $mwh->getmaxyx($height, $width);
  endwin();
  return $width;
}

# time_24h_valid($time)    {{{1
#
# does:   determine whether supplied time is valid 24 hour time
# params: $time - time to evaluate, 'HH:MM' or 'HHMM' format [required]
#                 leading zero can be dropped
# prints: nil
# return: boolean
sub time_24h_valid ($self, $time)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not $time) { return $FALSE; }

  # deal with case of 4-digit time, e.g., '0520'
  if ($time =~ /^ ( \d{2} ) ( \d{2} ) \z/xsm) { $time = "$1:$2"; }

  # evaluate time value
  my $value = eval { Time::Simple->new($time); 1 };
  return $value;
}

# time_now()    {{{1
#
# does:   provide current time ('HH::MM::SS')
# params: nil
# prints: nil
# return: scalar string
sub time_now ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return Time::Simple->new()->format;
}

# time_zone_from_offset($offset)    {{{1
#
# does:   determine timezone for offset
# params: $offset - timezone offset to check [required]
# prints: nil
# return: scalar string
sub time_zone_from_offset ($self, $offset)
{    ## no critic (RequireInterpolationOfMetachars)

  # get timezones for all offsets
  my @countries = DateTime::TimeZone->countries();
  my %timezone;
  foreach my $country (@countries) {
    my @names = DateTime::TimeZone->names_in_country($country);
    foreach my $name (@names) {
      my $dt             = DateTime->now(time_zone => $name,);
      my $offset_seconds = $dt->offset();
      my $offset = DateTime::TimeZone->offset_as_string($offset_seconds);
      push @{ $timezone{$offset} }, $name;
    }
  }

  # find timezones for given offset
  if (not $timezone{$offset}) {
    croak "No timezones for offset '$offset'\n";
  }
  my @timezones = sort @{ $timezone{$offset} };

  # prefer Australian timezone
  my @oz_timezones = grep {/Australia/sm} @timezones;
  if (@oz_timezones) {
    return $oz_timezones[0];
  }
  else {
    return $timezones[0];
  }
}

# time_zone_local()    {{{1
#
# does:   get local timezone
# params: nil
# prints: nil
# return: scalar string
sub time_zone_local ($self) {   ## no critic (RequireInterpolationOfMetachars)
  return DateTime::TimeZone->new(name => 'local')->name();
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
sub tools_available ($self, @tools)
{    ## no critic (RequireInterpolationOfMetachars)
  if (not @tools) { return $FALSE; }
  my @missing = grep { not $self->path_executable($_) } @tools;
  if (@missing) {
    my $missing_tools = join $PARAM_COMMA_SPACE, @missing;
    my $err = $self->pluralise(
      'Required (executable is|executables are) not available: ',
      scalar @missing)
        . $missing_tools;
    my @display = $self->wrap_text($err);
    for my $line (@display) { warn "$line\n"; }
    return $FALSE;
  }

  return $TRUE;
}

# value_boolise($value)    {{{1
#
# does:   convert value to boolean
# detail: convert 'yes', 'true' and 'on' to 1
#         convert 'no, 'false, and 'off' to 0
#         other values returned unchanged
# params: $value - value to analyse [required]
# prints: nil
# return: boolean
sub value_boolise ($self, $value)
{ ## no critic (RequireInterpolationOfMetachars RequireFinalReturn ProhibitDuplicateLiteral)
  if (not defined $value) { return $value; }    # handle special case
  for ($value) {
    if (/^yes$|^true$|^on$/ixsm)  { return 1; }    # true -> 1
    if (/^no$|^false$|^off$/ixsm) { return 0; }    # false -> 0
    return $value;
  }
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
sub vim_list_print ($self, @messages)
{    ## no critic (RequireInterpolationOfMetachars)
  const my $ERROR_INDEX  => 9;
  const my $TITLE_INDEX  => $ERROR_INDEX;
  const my $WARN_INDEX   => 8;
  const my $PROMPT_INDEX => $NUMBER_TEN;
  @messages = $self->listify(@messages);
  my ($index, $flag);
  foreach my $message (@messages) {
    for ($message) {
      ## no critic (ProhibitCascadingIfElse)
      if    (/^::title::/ixsm)  { $index = $TITLE_INDEX;  $flag = 't' }
      elsif (/^::error::/ixsm)  { $index = $ERROR_INDEX;  $flag = 'e' }
      elsif (/^::warn::/ixsm)   { $index = $WARN_INDEX;   $flag = 'w' }
      elsif (/^::prompt::/ixsm) { $index = $PROMPT_INDEX; $flag = 'p' }
      else                      { $index = 0;             $flag = 'n' }
      ## use critic
    }
    $message = substr $message, $index;
    $self->vim_print($flag, $message);
  }
  return;
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
sub vim_print ($self, $type, @messages)
{    ## no critic (RequireInterpolationOfMetachars)

  # variables
  # - messages
  @messages = $self->listify(@messages);

  # - type
  if (not $type) { $type = 'normal'; }

  # - attributes (to pass to function 'colored')
  ## no critic (ProhibitDuplicateLiteral)
  my $attributes =
        $type eq 't' ? [ 'bold', 'magenta' ]
      : $type eq 'p' ? [ 'bold', 'bright_green' ]
      : $type eq 'w' ? ['bright_red']
      : $type eq 'e' ? [ 'bold', 'white', 'on_red' ]
      :                ['reset'];
  ## use critic

  # print messages
  for my $message (@messages) {
    say Term::ANSIColor::colored($attributes, $message) or croak;
  }
  return;
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
sub vim_printify ($self, $type, $message)
{    ## no critic (RequireInterpolationOfMetachars)

  # variables
  # - message
  if (not $message) { return q{}; }

  # - type
  if (not $type) {
    $type = 'normal';    ## no critic (ProhibitDuplicateLiteral)
  }

  # - token to prepend to message
  #my $token;
  #for ($type) {
  #    if ($_ =~ /^t/ixsm) { $token = '::title::' }
  #    elsif ($_ =~ /^p/ixsm) { $token = '::prompt::' }
  #    elsif ($_ =~ /^w/ixsm) { $token = '::warn::' }
  #    elsif ($_ =~ /^e/ixsm) { $token = '::error::' }
  #    else         { $token = q{} }
  #}
  my $token =
        $type =~ /^t/ixsm ? '::title::'
      : $type =~ /^p/ixsm ? '::prompt::'
      : $type =~ /^w/ixsm ? '::warn::'
      : $type =~ /^e/ixsm ? '::error::'
      :                     q{};

  # return altered string
  return "$token$message";
}

# wrap_text($string, %options)    {{{1
#
# does:   displays screen text with word wrapping
# params: $strings - text to wrap, string or array reference
#                    [required]
#         %options - options hash [all optional]:
#         - $width:  width at which to wrap [int, default=terminal width]
#                    note: cannot be wider than terminal width
#         - $indent: size of indent [int, default=0]
#         - $hang:   size of indent of second and subsequent lines
#                    [int or string, default=$indent]
#         - $break:  regular expression giving characters to break on
#                    example: qr{[\s']} for space and quote
#                    [regexp, default=qr{[\s]}]
#         - $cont:   use continuation character [bool, default=$FALSE]
# prints: nil
# return: list of strings (no terminal slashes)
# usage:  my @output = $self->wrap_text($string, indent => 2, hang => 4);
#         my @output = $self->wrap_text([@many_strings]);
# note:   there are two formats for 'hang'; the first format is the usual
#         meaning of a hanging indent, where second and subsequent lines are
#         indented by the nominated number of spaces, accepts an integer >=0;
#         the second format is an extended hanging indent where the base
#         hanging indent is equal to the number of leading spaces in the first
#         row, optionally with an additional indent amount, accepts a string
#         like 'e=X' where the 'e' is a flag indicating use of the second
#         format style and 'X' is an integer >=0, and as a special case a
#         simple 'e' is the same as 'e=0'
# note:   continuation lines have appended character U+21A9 (↩);
#         alternatives that could be used are:
#         U+2938 (⤸), U+21A9 (↩), U+21B2 (↲), U+21B5 (↵), U+21D9 (⇙),
#         U+2926 (⤦), U+2936 (⤶), U+23CE (⏎), U+2B0B (⬋), U+2B03 (⬃)
# note:   Text::Wrap consumes break characters if a simple regexpt is provided;
#         a line consisting solely of break characters (such as a line of
#         dashes, where dashes are defined as a break character) will simply
#         disappear during processing; use a positive lookbehind construct to
#         prevent consumption of break characters
# note:   often used with method 'pager' to format screen display
sub wrap_text ($self, $strings, %options)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)

  const my $MIN_TEXT_WIDTH => 10;    ## no critic (ProhibitDuplicateLiteral)

  # handle args    {{{2
  # - $strings    {{{3
  if (not $strings) { confess 'No strings provided'; }
  my $strings_ref = ref $strings;
  my @input;
  for ($strings_ref) {
    if    ($_ eq $REF_TYPE_ARRAY) { @input = @{$strings}; }
    elsif ($_ eq $EMPTY_STRING)   { push @input, $strings; }
    else {
      my $err =
          'Input is not a string or array reference: ' . Dumper($strings);
      confess $err;
    }
  }

  # - $width    {{{3
  my $width;
  if ($options{$KEY_WIDTH}) {
    if (  $self->int_pos_valid($options{$KEY_WIDTH})
      and $options{$KEY_WIDTH} > 0)
    {
      $width = $options{$KEY_WIDTH};
    }
    else {
      my $err =
          "Invalid option '$KEY_WIDTH': " . Dumper($options{$KEY_WIDTH});
      confess $err;
    }
  }
  my $terminal_width = $self->term_width - 1;    #
  if ((not $width) or ($width > $terminal_width)) {
    $width = $terminal_width;
  }

  # - localised as per PBP, so ignore package variable warning
  local $Text::Wrap::columns = $Text::Wrap::columns;
  $Text::Wrap::columns = $width;

  # - $indent    {{{3
  my $indent = $EMPTY_STRING;
  if (exists $options{$KEY_INDENT}) {
    if (  $self->int_pos_valid($options{$KEY_INDENT})
      and $options{$KEY_INDENT} >= 0
      and (($options{$KEY_INDENT} + $MIN_TEXT_WIDTH) < $width))
    {
      $indent = $SPACE x $options{$KEY_INDENT};
    }
    else {
      my $err =
          "Invalid option '$KEY_INDENT': " . Dumper($options{$KEY_INDENT});
      confess $err;
    }
  }

  # - $hang    {{{3
  #   . positive integer regexp    {{{4
  my $int_re = qr{
        (?:                             # '()' not to capture to $1, etc.
            (?: 0 )                     # zero
            |                           # OR
            (?:                         # integer
                (?: [123456789]    )    # - being a non-zero
                (?: [0123456789] * )    # - and optional number combo
            )
        )
    }xsm;

  #    . extended hang regexp    {{{4
  my $extend_re = qr{
        (?:                          # '()' not to capture to $1, etc.
            (?: [Ee] )               # 'E' or 'e'
            (?: = ( $int_re ) ) ?    # optionally followed by '=' and integer
                                     # and capture the integer
        )
    }xsm;    # }}}4
  my $hang = $indent;
  if (exists $options{$KEY_HANG}) {
    my $valid_hang = $FALSE;

    # basic format: positive integer
    if ($self->int_pos_valid($options{$KEY_HANG})
      and (($options{$KEY_HANG} + $MIN_TEXT_WIDTH) < $width))
    {
      $hang       = $SPACE x $options{$KEY_HANG};
      $valid_hang = $TRUE;
    }

    # extended format: 'e' or 'e=X' where 'X' is a positive integer
    elsif ($options{$KEY_HANG} =~ /\A$extend_re\Z/xsm) {
      my $extend     = $1 // 0;    # provided by $extend_re
      my $base       = length $input[0] =~ s/\A(\s*).*\Z/$1/xsmr;
      my $hang_width = $base + $extend;
      if (($hang_width + $MIN_TEXT_WIDTH) < $width) {
        $hang       = $SPACE x $hang_width;
        $valid_hang = $TRUE;
      }
    }

    # invalid format
    if (not $valid_hang) {
      my $err = "Invalid option '$KEY_HANG': " . Dumper($options{$KEY_HANG});
      confess $err;
    }
  }

  # - $break    {{{3
  my $break = qr{[\s]}xsm;
  if (exists $options{$KEY_BREAK}) {
    my $candidate = $options{$KEY_BREAK};
    if (ref $candidate eq $CLASS_REGEXP) { $break = $candidate; }
  }

  # - localised as per PBP, so ignore package variable warning
  local $Text::Wrap::break = $Text::Wrap::break;
  $Text::Wrap::break = $break;

  # - $cont    {{{3
  my $cont = $FALSE;
  if (exists $options{$KEY_CONT}) {
    $cont = $options{$KEY_CONT};
  }    # }}}3

  # wrap message    # {{{2
  # - localised as per PBP, so ignore package variable warning
  local $Text::Wrap::unexpand = $Text::Wrap::unexpand;
  $Text::Wrap::unexpand = $FALSE;
  local $Text::Wrap::tabstop = $Text::Wrap::tabstop;
  $Text::Wrap::tabstop = $TAB_SIZE;
  local $Text::Wrap::huge = $Text::Wrap::huge;
  $Text::Wrap::huge = 'wrap';
  my @output;

  foreach my $line (@input) {
    my $wrapped       = Text::Wrap::wrap($indent, $hang, $line);
    my @wrapped_lines = split /\n/xsm, $wrapped;
    if ($cont && scalar @wrapped_lines > 1) {    # add continuations
      my $last_line = pop @wrapped_lines;
      foreach my $line (@wrapped_lines) { $line .= q{↩}; }
      push @wrapped_lines, $last_line;
    }
    push @output, @wrapped_lines;
  }
  chomp @output;    # }}}2

  return @output;
}    # }}}1

1;

# POD    {{{1

## no critic (ProhibitDuplicateHeadings)

__END__

=encoding utf8

=head1 NAME

Role::Utils::Dn - utility methods

=head1 VERSION

This documentation refers to Role::Utils::Dn version 0.3.

=head1 SYNOPSIS

    package My::Module;
    use Moo;
    with qw(Role::Utils::Dn);

=head1 DESCRIPTION

A library of my personal utility methods.

=head2 Previous role structure

These methods were originally provided in multiple role modules grouped by
theme. Unfortunately there were interdependencies between these role modules,
meaning the modules consumed each other. Eventually the circular dependencies
became sufficiently complex that perl began crashing with errors like "Due to a
method name conflict between roles 'Dn::Role::HasDebian' and
'Dn::Role::HasUserInteraction', the method 'getchar' must be implemented by
[the calling script]" when one of the roles was consumed.

To prevent this situation, all utility role modules were combined into one.

=head2 Thematic classification

All role methods are listed below in alphabetical order. They are listed here
in their original thematic groupings.

=head3 Array

=over

=item array_push($arrayref, @items)

add items to an arrayref

=item list_duplicates(@values)

get duplicate list items

=back

=head3 Debian/GNU

=over

=item autoconf_version( )

get autoconf version

=item changelog_from_git($dir)

get ChangeLog content from a git repository

=item changelog_version_regex( )

get regex for extracting package version from F<changelog>

=item configure_ac_version_regex( )

get regex for extracting package version from F<configure.ac>

=item debhelper_compat( )

get current debian compatibility level

=item debian_install_deb($deb)

installs debian package from a deb file

=item debian_package_version($pkg)

get current version of a debian package

=item debian_standards_version( )

get current debian standards version

=back

=head3 Image

=over

=item image_add_border($image, $side, $top_bottom, $fill = 'none')

add border to Image::Magick image

=item image_create($filepath, $attributes = undef)

create Image::Magick object from image file

=item image_crop($image, $coords)

crop Image::Magick object

=item image_files_valid(@filepaths)

ensure all image files can be opened as Image::Magick objects

=item image_height($image)

get height in pixels of Image::Magick object

=item image_label($image, $text, $opts)

add label to Image::Magick object

=item image_max_dimensions(@filepaths)

get maximum height and width of images in files

=item image_max_x($image)

get maximum pixel x-coordinate for image

=item image_max_y($image)

get maximum pixel y-coordinate for image

=item image_object($object)

check whether variable is an Image::Magick object

=item image_pixel_color($image, $x, $y, [@color])

get or set the (rgb) color of a pixel in an Image::Magick object

=item image_resize($image, $opts)

resize an Image::Magick object

=item image_width($image)

get width in pixels of Image::Magick object

=item image_write($image, $filemask)

save an Image::Object to file

=back

=head3 Number

=over

=item int_pad_width($int)

width, in characters, of an integer

=item int_pos_valid($value)

whether a given value is a valid positive integer (includes zero)

=item int_valid($value)

whether a given value is a valid integer (includes zero)

=back

=head3 Path

=over

=item cwd( )

get current directory path

=item dir_clean($dir)

delete all files and recursively delete all subdirectories in a directory

=item dir_copy($source_dir, $target_dir)

recursively copy the contents of one directory to another

=item dir_current( )

get current working directory

=item dir_join(@dirs)

concatenate list of directories in path to a string path

=item dir_list($dir)

list subdirectories in directory

=item dir_make(@paths)

create directory paths

=item dir_name($filepath, $exists = $FALSE)

extract dirpath from filepath

=item dir_parent($dir)

return parent directory

=item dir_temp( )

create and get path of temporary directory

=item file_base($filepath, $exists = $FALSE)

extract base name from file path

=item file_cat_dir($filepath, $dirpath, $exists = $FALSE)

extract filename from a filepath and add it to a directory path

=item file_cmdline_args( )

assume all arguments in ARGV are file globs and expand them

=item file_copy($source_file, $target)

copy a file

=item file_identical($fp_1, $fp_2)

compare two files to see if they are identical

=item file_is_deb($filepath)

determine whether file is a debian package file

=item file_is_perl($filepath)

determine whether file is a perl executable file

=item file_is_deb($filepath)

determine whether file is a debian package file

=item file_is_mimetype($filepath, $mimetype)

determine whether a given file is a specified mimetype

=item file_list([$directory[, $pattern]])

list files in directory, optionally listing only those matching a pattern

=item file_mime_type($filepath)

determine the mime type of a file

=item file_move($source_file, $target)

move a file

=item file_name($filepath, $exists = $FALSE)

extract filename from filepath

=item file_name_duplicates(@fps)

find duplicate file names in a set of filepaths, i.e., the same file name in
different directories

=item file_name_parts($filepath, $exists = $FALSE)

extract base name and suffix from a file path

=item file_read($fp)

read contents of a file

=item file_readable(@filepaths)

determine whether given paths are (symlinks to) valid plain files and are
readable

=item file_write($content, $fp, $perm = undef)

write file content to disk

=item script_name()

get name of executing script

=item path_canon($path)

get canonical path

=item path_executable($exe)

get path of executable

=item path_join(@parts)

concatenates a list of directories and a file to create a string path

=item path_parts($filepath, $exists = $FALSE)

extract directory path and file name from a file path

=item path_remove(@paths)

delete files and recursively delete directories

=item path_true($path, $exists = $FALSE)

convert a relative path to an absolute path

=back

=head3 Program interaction

=over

=item copy_to_clipboard($val)

copy value to system clipboard

=item internet_connection([$verbose])

determine whether an internet connection can be found

=item run_command($err, @cmd)

run shell command and die with custom error message if command fails

=item shell_command($cmd, $fatal = $TRUE, $timeout = 0)

run shell command and capture output

=item tools_available(@tools)

checks that required executables are available on the system

=back

=head3 Date/Time

=over

=item date_current_iso( )

get current date in ISO 8601 format (yyyy-mm-dd)

=item date_email ([$date], [$time], [$offset])

produce a date formatted according to RFC 2822 (Internet Message Format)

=item date_valid($date)

determine whether date is valid and in ISO format

=item time_24h_valid($time)

determine whether supplied time is valid 24 hour time

=item time_now()

provide current time ('HH::MM::SS')

=item time_zone_from_offset($offset)

determine timezone for offset, preferring Australian zones

=item time_zone_local()

get local timezone

=back

=head3 String

=over

=item pad($values[, $width[, $char[, $side]]])

left- or right-pad a value or list of values with a character

=item pluralise($string, $numeric)

adjust string based on a provided numerical value

=item stringify($val)

convert a value of any type to a string (may contain newlines)

=item string_entitise($string)

convert reserved characters to HTML entities

=item value_boolise($value)

convert value to boolean

=back

=head3 Data storage

=over

=item data_retrieve($file)

retrieves function data from storage file

=item data_store($data, $file)

store data structure in file

=back

=head3 User interaction

=over

=item divider( )

provides a string of dashes as wide as the current terminal

=item dump_var($var1[, var2[, ...]])

format variable for display

=item interact_ask($prompt,[ $default])

user provides input

=item interact_choose($prompt, @options)

user selects option from a menu

=item interact_confirm($question)

user answers y/n to a question

=item interact_print($msg)

print message to stdout if script is interactice,

=item interact_prompt($message)

prompt user to press key

=item pager($lines)

display list of lines in terminal using pager

=item term_height( )

get terminal height in characters

=item term_width( )

terminal width in characters

=item wrap_text($string, %options)

displays screen text with word wrapping

=back

=head1 ATTRIBUTES

None provided.

=head1 SUBROUTINES/METHODS

=head2 array_push($arrayref, @items)

=head3 Purpose

Add items to an array reference.

=head3 Parameters

=over

=item $arrayref

Array reference to add items to. Array reference. Required.

=item @items

Items to add to array reference. List. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

Array reference. Dies on failure.

=head2 autoconf_version( )

=head3 Purpose

Get current version of C<autoconf>.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar version number. Dies on failure.

=head2 changelog_from_git($dir)

=head3 Purpose

Get ChangeLog content from a git repository.

=head3 Parameters

=over

=item $dir

Root file of repository. It must contain a F<.git> directory. Scalar. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

List. Dies on failure.

=head2 changelog_version_regex( )

=head3 Purpose

Provides a regex for finding the package version in the F<changelog> debian
control file.

The script assumes the first line of the file is well-formed, i.e., like:

    dn-cronsudo (2.1-2) UNRELEASED; urgency=low

so that the first pair of parentheses found on the line encloses the S<"package
version"-"debian revision"> value. It similarly assumes the last line of the
entry is like:

    -- John Doe <john@doe.com>  Fri, 29 Oct 2021 17:22:13 +0930

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar regexp, e.g., qr//.

The regex includes five named captures from the most recent changelog entry:

=over

=over

=item <pkg>

package name

=item <version>

version

=item <release>

package release

=item <urgency>

package urgency

=item <maintainer>

maintainer name and email

=back

=back

=head3 Usage

The named captures can be accessed with code like:

    my $changelog_content = $changelog->slurp_utf8;
    my $re = $self->changelog_version_regex;
    if ( $changelog_content =~ $re ) {
        my $version = "$LAST_PAREN_MATCH{'version'}";
        # ...
    }

=head2 configure_ac_version_regex( )

Provides a regex for finding the package version in the F<configure.ac>
autotools file.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar regexp, e.g., qr//.

The regex includes three named captures:

=over

=over

=item <pre>

from beginning of file to version

=item <version>

version

=item <post>

from version to end of file.

=back

=back

=head3 Usage

The named captures can be accessed with code like:

    my $configure_ac_content = $configure_ac->slurp_utf8;
    my $re = $self->configure_ac_version_regex;
    if ( $configure_ac_content =~ $re ) {
        my $version = "$LAST_PAREN_MATCH{'version'}";
        # ...
    }

=head2 copy_to_clipboard($val)

=head3 Purpose

Copies a value to the system clipboard.

Non-scalar values are converted to a string by the C<Dumper> function from the
L<Data::Dumper::Simple> module.

In X-Windows systems (such as linux) the value is copied to both the primary
selection (paste with middle mouse button of shift key + middle mouse button)
and clipboard selection (ctrl+v keys or shift+ctrl+v keys).

=head3 Parameters

=over

=item $val

Value to copy to system clipboard. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

N/A. Dies on error.

=head2 cwd( )

=head3 Purpose

Get path of current directory.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 data_retrieve($file)

=head3 Purpose

Retrieve function data from a storage file.

=head3 Parameters

=over

=item $file

Path to file in which data is stored. Scalar. Required.

=back

=head3 Prints

Nil (except feedback from Storage module).

=head3 Returns

As per L<Storable/DESCRIPTION>:

=over

=item Variable reference on success

=item Undef if an I/O system error occurs

=item "Other serious errors are propagated via 'die'"

=back

=head3 Usage

    my $storage_file = '/path/to/filename';
    my $ref = $self->data_retrieve($storage_file);
    my %data = %{$ref};

=head2 data_store($data, $file)

=head3 Purpose

Store a data structure in a file.

=head3 Parameters

=over

=item $data

Data structure to be stored. Must be a reference. Required.

=item $file

File path in which to store data. Scalar. Required.

=back

=head3 Prints

Nil (except feedback from Storable module).

=head3 Returns

As per L<Storable/DESCRIPTION>:

=over

=item Boolean true on success

=item Undef for internal errors like I/O errors

=item "Serious errors are propagated as a 'die' exception"

=back

=head3 Usage

    $storage_dir = '/path/to/filename';
    $self->data_store( \%data, $storage_file );

=head2 date_current_iso( )

=head3 Purpose

Get current date in ISO 8601 format (yyyy-mm-dd).

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 date_email ([$date], [$time], [$offset])

=head3 Purpose

Produce a date formatted according to RFC 2822 (Internet Message Format).
=head3 Parameters

=over

=item $date

ISO-format date. Optional. Default: today.

=item $time

24 hour time. Leading hour zero and seconds are optional. Optional.
Default: now.

=item $offset

Timezone offset, e.g., +0930. Optional.
Default: local timezone offset.

=back

=head3 Prints

Message if fatal error.

=head3 Returns

Scalar string. Dies on failure.

Example output: 'Mon, 16 Jul 1979 16:45:20 +1000'.

head2 date_valid($date)

=head3 Purpose

Determine whether a date is valid and in ISO format.

=head3 Parameters

=over

=item $date

Date to be analysed. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 date_valid($date)

=head3 Purpose

Determine whether a date is valid and in ISO format.

=head3 Parameters

=over

=item $date

Candidate date. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 debhelper_compat( )

=head3 Purpose

Get the current debian compatibility level. This value is actually the major
version of the debian package F<debhelper>.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string integer (undef if problem encountered).

=head2 debian_install_deb($deb)

=head3 Purpose

Install debian package from a deb package file. Uses the C<dpkg> package
installer which requires root/superuser privileges.

Makes the following installation attempts in sequence:

=over

=item *

Install as though root

=item *

Install with C<sudo>

=item *

Install with C<su -c>, which requires the user to enter the superuser
password.

=back

The method returns once installation is successful.

=head3 Parameters

=over

=item $deb

Path to debian package file. Scalar string. Required.

=back

=head3 Prints

Feedback on install attempts.

=head3 Returns

Scalar boolean. Whether package was successfully installed.

=head2 debian_package_version($pkg)

=head3 Purpose

Get the version of a debian package.

WARNING: Requires that the package be installed on the current system.

=head3 Parameters

=over

=item $pkg

Name of debian package. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

Undef if C<dpkg> command fails. Dies if unable to parse the C<dpkg> output and
extract the package version.

=head2 debian_standards_version( )

=head3 Purpose

Gets the current version of the debian standards. This is actually the first
three elements of the version of the F<debian-policy> debian package.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 dir_clean($dir)

=head3 Purpose

Remove all contents of directory, deleting all files and recursively deleting
all subdirectories.

=head3 Parameters

=over

=item $dir

Path to directory whose contents are to be deleted. Path::Tiny object or scalar
string. Required.

=back

=head3 Prints

Feedback on error.

=head3 Returns

N/A. Dies on failure.

=head2 dir_copy($source_dir, $target_dir)

Recursively copy the contents of one directory to another.

=head3 Parameters

=over

=item $source_dir

Path of directory to copy from. The directory must exist or this method dies.
Scalar string. Required.

=item $target_dir

Path of directory to copy to. If this directory does not exist it is created,
recursively if necessary. Scalar string. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

Nil. Dies on failure.

=head2 dir_current( )

Get current working directory.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 dir_join(@dirs)

=head3 Purpose

Concatenate list of directories into a string path.

=head3 Parameters

=over

=item @dirs

Directory parts. List.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string directory path.

=head3 Usage

The function accepts an arbitrary number of parameters, for example:

    my $dir_path = $self->dir_join($root, $dir, $subdir)

=head2 dir_list([$directory])

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

=head2 dir_make(@paths)

=head3 Purpose

Create directory paths. Required.

=head3 Parameters

=over

=item @paths

One or more directory paths to create. Required.

=back

=head3 Prints

Error messages if path creation is unsuccessful.

=head3 Returns

Scalar boolean indicating whether path creation was successful.

The method dies if a fatal filesystem error occurs. See the documentation for
L<File::Path/"DIAGNOSTICS"> for more details.

=head2 dir_name($filepath, $exists = $FALSE)

=head3 Purpose

Extract directory path from filepath.

=head3 Parameters

=over

=item $filepath

Path from which to extract directory path. Scalar. Required.
Can be a directory path only.

=item $exists

Die if filepath does not exist. Boolean. Optional. Default: false.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar string.

=head2 dir_parent($dir)

=head3 Purpose

Returns parent of specified directory.

=head3 Parameters

=over

=item $dir

Directory path to analyse. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

The returned directory path is absolute regardless of whether the supplied
directory path was absolute or relative.

=head2 dir_temp( )

Create and get path of temporary directory.

The directory will be removed automatically on script exit.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 divider()

=head3 Purpose

Get divider string (consecutive dashes) as wide as the current terminal.

=head3 Parameters

Nil.

=head3 Prints

Feedback on error.

=head3 Returns

Scalar string. Dies on failure.

=head2 dump_var($var1[, var2[, ...]])

Formats variable(s) for display in terminal. The variable is pretty printed
using L<Data::Dumper> with module variables $Terse and $Indent set to true and
1, respectively, to minimise left-spacing (see L<Data::Dumper/"Configuration
Variables or Methods">). Each output line is wrapped to fit in the current
terminal.

=head3 Parameters

=over

=item $var1[, $var2[, ...]]

Variable(s) to be formatted. Any number of variables can be provided. If no
variables are provided an empty value will be returned.

=back

=head3 Prints

Nil.

=head3 Returns

List of scalar strings, each of which fits the current terminal.

=head3 Usage

    say $_ for $self->dump_var($my_var);

=head2 file_base($filepath, $exists = $FALSE)

Extracts base name from file path.

=head3 Parameters

=over

=item $filepath

File path from which to extract base name. Scalar string. Required.

=item $exists

Whether to die if the provided filepath does not exist. Boolean. Optional.
Default: false.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar string.

=head2 file_cat_dir($filepath, $dirpath, $exists = $FALSE)

Extract filename from filepath and add it to a dirpath.

=head3 Parameters

=over

=item $filepath

Path from which to extract file name. Can be a file name only. Scalar string.
Required.

=item $dirpath

Path to which file is added. Scalar string. Required.

=item $exists

Die if either parameter does not exist. Scalar boolean. Optional. Default:
false.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar string.

=head2 file_cmdline_args( )

Assume all arguments in ARGV are file globs and expand them to obtain a list of
file paths.

=head3 Parameters

Nil.

=head3 Prints

Error messages.

=head3 Returns

List of strings.

=head2 file_copy($source_file, $target)

Copy a file to a directory.

=head3 Parameters

=over

=item $source_file

Path of file to copy. The file must exist or this method dies. Scalar string.
Required.

=item $target

Path of directory or file to copy to. If the directory component does not exist
it is created, recursively if necessary. Scalar string. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

Nil. Dies on failure.

=head2 file_identical($filepath_1, $filepath_2)

Compare two files to see if they are identical.

=head3 Parameters

=over

=item $filepath_1

Path to file to compare. Scalar string. Required.

=item $filepath_2

Path to file to compare. Scalar string. Required.

=back

=head3 Prints

Error message if unable to compare files.

=head3 Returns

Scalar boolean. Note that method dies if the file comparison fails.

=head2 file_is_deb($filepath)

=head3 Purpose

Determine whether a file is a debian package file.

=head3 Parameters

=over

=item $filepath

File to analyse. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 file_is_mimetype($filepath, $mimetype)

=head3 Purpose

Determine whether a given file is a specified mimetype.

=head3 Parameters

=over

=item $filepath

File to analyse. Scalar string. Required.

Method dies if filepath is missing or invalid.

=item $mimetype

Mime type to test for. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean. Dies if filepath missing or invalid.

=head2 file_is_perl($filepath)

=head3 Purpose

Determines whether a file is a perl executable file.
Note: does not detect perl module files.

-head3 Parameters

=over

=item $filepath

File to analyse. Scalar.
Required (script dies if filepath is missing or invalid).

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 file_list([$directory[, $pattern]])

=head3 Purpose

List files in directory. Uses current directory if no directory is supplied.

=head3 Parameters

=over

=item $directory

Directory path. Optional. Default: current directory.

=item $pattern

File name pattern to match. Regular expression (qr//). Optional. Default: all
files.

=back

=head3 Prints

Nil.

=head3 Returns

List. Dies if operation fails.

=head2 file_mime_type($filepath)

=head3 Purpose

Determine a file's mime type.

=head3 Parameters

=over

=item $filepath

File to analyse. Scalar string. Required.

Method dies if this parameter is missing or invalid.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head3 Note

The available modules for determining file mime type all have individual
advantages and disadvantages. This method initially used the L<File::Type>
module but it incorrectly identified some mp3 files as
'application/octet-stream'. This method now uses the L<File::MimeInfo> module.
Other alternatives include the L<File::MMagic> and L<File::MMagic:Magic>
modules.

=head2 file_move($source_file, $target)

Move/rename a file.

=head3 Parameters

=over

=item $source_file

Path of file to move/rename. The file must exist or this method dies.

Scalar string. Required.

=item $target

Path of directory or file to copy to. If the directory component does not exist
it is created, recursively if necessary.

Scalar string. Required.

=back

=head3 Prints

Error message on failure.

=head3 Returns

Nil. Dies on failure.

=head2 file_name($filepath, $exists = $FALSE)

Extract filename from filepath.

=head3 Parameters

=over

=item $filepath

Path from which to extract file name. Can be a file name only. Scalar string.
Required.

=item $exists

Die if file path does not exist. Scalar boolean. Optional. Default:
false.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar string.

=head2 file_name_duplicates(@filepaths)

Find duplicate file names in a set of filepaths, i.e., files in different
directories that have the same name.

=head3 Parameters

=over

=item @filepaths

Filenames to analyse. List. Optional.

=back

=head3 Prints

Nil.

=head3 Returns

Hash reference. Has the structure:

    {
        filename => [filepath1, filepath2, ...],
        ...,
    }

=head3 Usage

    my %dupes = %{ $self->file_name_duplicates(@filepaths) };
    if ( scalar keys %dupes) {
        warn "Duplicate filename(s):\n";
        while ( ( $name, $paths ) = each %dupes ) {
            warn "- $name\n";
            for my $path ( @{$paths} ) { warn "  - $path\n"; }
        }
    }


=head2 file_name_parts($filepath, $exists = $FALSE)

Get base name and extension from file name.

=head3 Parameters

=over

=item $filepath

File path from which to extract base name and extension. Scalar string.
Required.

=item $exists

Whether to die if the provided filepath does not exist. Boolean. Optional.
Default: false.

=back

=head3 Prints

Error messages.

=head3 Returns

List of strings: ($base, $extension). Note that the extension includes the
period separating base name and suffix, so that concatenating base name and
suffix results in the original file name.

=head2 file_read($fp)

=head3 Purpose

Read contents of a file into a scalar variable.

=head3 Parameters

=over

=item $fp

Path to file to read from. String or L<Path::Tiny> object reference. Required.

=back

=head3 Prints

Error messages.

=head3 Returns

Arrayref of content lines. Dies on failure.

=head2 file_readable(@filepaths)

Determine whether paths are (symlinks to) valid plain files and are readable.

=head3 Parameters

=over

=item @filepaths

Paths to be analysed. List of strings. Required.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar boolean. Dies on failure.

=head2 file_write($content, $fp, [$perm])

=head3 Parameters

=over

=item $content

Content to be written to file. Do I<not> include terminal newlines. Array
reference. Required.

=item $fp

Destination file path. Scalar string or L<Path::Tiny> object reference.
Required.

If the file exists it will be silently overwritten.

=item $perm

Permissions for file. Quoted octal string, e.g., "0755". Optional. Default:
user's current umask.

=back

=head3 Prints

Error message on failure.

=head3 Returns

N/A. Dies on file operation failure.

=head2 image_add_border($image, $side, $top_bottom, $fill='none')

Add borders to image. The same width is used for both left and right borders.
The same width is used for both top and bottom borders. The borders are set to
the specified fill color (default is 'none', i.e., transparent).

The image is left unmodified if both side and top/bottom border widths are set
to zero.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=item $side

Width in pixels of each side border. Note: final image width will equal
original width + (2 x side border width). Scalar integer. Required.

=item $top_bottom

Width in pixels of each of the top and bottom border. Note: final image height
will equal original width + (2 x top/bottom border width). Scalar integer.
Required.

=item $fill

Border color. Further details about color names and the imagemagick color
specification can be found online
L<here|http://www.imagemagick.org/script/color.php>. Scalar string. Optional.
Default: 'none' (transparent).

=back

=head3 Prints

Error messages.

=head3 Returns

Nil. Edits $image in place.

=head2 image_create($filepath, $attributes)

Create Image::Magick object from image file.

Note that this method relies on Image::Magick reading the underlying image
file. It is possible for this operation to exhaust cache resources and cause a
fatal error. See L</"Exhausting cache resources"> for further details.

=head3 Parameters

=over

=item $filepath

Image file path. Scalar string. Required.

=item $attributes

Image::Magick attributes, e.g., 'density' and 'quality'. Further details about
settings can be found online
L<here|http://www.imagemagick.org/script/command-line-processing.php#setting>.
Hash reference. Optional.

=back

=head3 Prints

Error messages.

=head3 Returns

Image::Magick object.

=head2 image_crop($image, $coords)

Crop Image::Magick object.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=item $coords

Boundary pixel coordinates. Hash reference. Required.

Accepts the keys:

=over

=item top_left_x

Top left pixel's x-coordinate. Integer. Required.

=item top_left_y

Top left pixel's y-coordinate. Integer. Required.

=item bottom_right_x

Bottom right pixel's x-coordinate. Integer. Required.

=item bottom_right_y

Bottom right pixel's y-coordinate. Integer. Required.

=back

=back

=head3 Prints

Error messages.

=head3 Returns

Nil. Edits $image in place.

=head2 image_files_valid(@filepaths)

Determine whether all files can be opened as images, specifically, whether the
files can be read into Image::Magick objects.

Note that the Image::Magick module, which is called to read each image file,
will die if it is unable to open the file as an image. Thus, this method will
die if it encounters an invalid image file.

=head3 Parameters

=over

=item @filepaths

Image file paths. List of strings. Optional.

=back

=head3 Prints

User feedback and error messages.

=head3 Returns

Scalar boolean. Note: returns true if no parameter provided. Also note that
module crashes if it encounters an invalid image file.

=head2 image_height($image)

Get image height in pixels.

=head3 Parameters

=over

=item $image

Image::Magick object. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Scalar integer.

=head2 image_label ($image, $text, $opts)

Add text label to image.

=head3 Parameters

=over

=item $image

Image::Magick object. Required.

=item $text

Label text. String. Required.

=item $opts

Optional values. Hash reference. Optional.

Accepts the keys:

=over

=item $font

Label font name. String. Optional. Default font selected by Image::Magick.

Font names known to ImageMagick can be listed using the shell command:

    convert -list font

=item $size

Label font size in points. Integer. Optional. Default font size selected by
Image::Magick.

=item $color

Label font color. String. Optional. Default cont color selected by
Image::Magick.

Further details about color names and the imagemagick color specification can
be found online L<here|http://www.imagemagick.org/script/color.php>.

=item $edge

Label location. String. Must be one of 'north', 'south', 'east' or 'west'.
Optional. Default: 'south'.

=item $space

Space, in points, added between image edge and label. Optional. Default: 0.

=back

=back

=head3 Prints

Error messages.

=head3 Returns

Nil. Edits $image in place.

=head2 image_max_dimensions(@filepaths)

Determine maximum width and height, in pixels, among a set of images. Note that
the longest width and height may be from different images.

=head3 Parameters

=over

=item @filepaths

Image file paths. List of strings. Optional.

=back

=head3 Prints

Error messages.

=head3 Returns

List of integers: ($width, $height). Note: returns (0, 0) if no file paths
provided.

=head2 image_max_x($image)

Get maximum pixel x-coordinate from image, i.e., the x-coordinate of the
S<< bottom-right >> pixel in the image.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Scalar integer.

=head2 image_max_y($image)

Get maximum pixel y-coordinate from image, i.e., the y-coordinate of the
S<< bottom-right >> pixel in the image.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Scalar integer.

=head2 image_object($object)

=head3 Purpose

Verify that a variable is an Image::Magick object.

=head3 Parameters

=over

=item $object

The variable to analyse. Scalar reference. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 image_pixel_color($image, $x, $y, [@color])

Set or get color of specified image pixel. If color values are supplied the
pixel is set to that color. If no color values are supplied, the current pixel
color values are retrieved.

Color format is a list of three RGB color component values (red, green and
blue), in the range 0-255.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=item $x

X-coordinate of pixel. Note that origin is the top-left corner of the image.
Scalar integer. Required.

=item $y

Y-coordinate of pixel. Note that origin is the top-left corner of the image.
Scalar integer. Required.

=item @color

Three color component values (red, green and blue) in range 0-255. Note that
this parameter is a list of three items, not an array reference to a list.

=back

=head3 Prints

Error messages.

=head3 Returns

If called as setter, returns no value. The $image object is edited in place.

If called as a getter, returns a list of integers: ($red, $green, $blue).

=head2 image_resize($image, $opts)

Resize image to the largest size that will fit in the target width and height.
The aspect ratio can be preserved (default). This results in extra space being
added to the sides, or top and bottom, of the image. The specified fill color
is used for this additional added space. If aspect ratio is ignored the image
is stretched in both dimensions as far as necessary to fill the entire target
width and height; this can cause considerable image distortion.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=item $opts

Configuration options. Hash reference. Required.

Accepts the keys:

=over

=item $width

Target width in pixels. Scalar integer. Required.

=item $height

Target height in pixels. Scalar integer. Required.

=item $fill

Color used for additional space added when aspect ratio is preserved. Further
details about color names and the imagemagick color specification can be found
online L<here|http://www.imagemagick.org/script/color.php>. Scalar string.
Optional. Default: 'none' (transparent).

=item $preserve

Whether to preserve the aspect ratio. Scalar boolean. Optional. Default: true.

=back

=back

=head3 Prints

Error messages.

=head3 Returns

Nil. Edits $image in place.

=head2 image_width($image)

Get image width in pixels.

=head3 Parameters

=over

=item $image

Image::Magick object. Required.

=back

=head3 Prints

Error messages on failure.

=head3 Returns

Scalar integer.

=head2 image_write($image, $filemask)

Write image to file. In some circumstances multiple output files can be
generated; in these cases the filemask needs to contain printf-like format
codes enabling assignation of distinguishing numbers.

Note that this method relies on Image::Magick writing the output image files.
It is possible for this operation to exhaust cache resources and cause a fatal
error. See L</"Exhausting cache resources"> for further details.

=head3 Parameters

=over

=item $image

Image::Magick object. Scalar object reference. Required.

=item $filemask

Target file mask. If F<%0Nd>, F<%0No> or F<%0Nx> appears in the filemask it is
interpreted as a printf format specification and replaced with the specified
decimal, octal, or hexadecimal encoding of the scene number. For example,
F<image%03d.png>. Scalar string. Required.

=back

=head3 Prints

Error messages.

=head3 Returns

Nil. Dies on failure.

=head2 int_pad_width($int)

Determine width, in characters, of an integer sequence.

Initially intended for use in determining the width of the largest integer in a
set of integers. This width would determine how much padding is necessary to
ensure all integers in the sequence are displayed with the same length.

=head3 Parameters

=over

=item $int

Integer to be analysed. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar integer.

=head2 int_pos_valid($value)

Determine whether a given value is a positive integer. Zero is considered a
positive integer.

=head3 Parameters

=over

=item $value

Item to be analysed. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 int_valid($value)

Determine whether a given value is an integer.

=head3 Parameters

=over

=item $value

Item to be analysed. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 interact_ask($prompt[, $default])

Get input from user.

=head3 Parameters

=over

=item $prompt

User prompt. Can be multi-line (use "\n"). Scalar. Required.

=item $default

=back

=head3 Prints

User interaction. After user answers, all but the first line of the prompt is
removed from the screen. The input also remains on the screen.

=head3 Returns

Scalar string.

=head2 interact_choose($prompt, @options)

=head3 Purpose

User selects an option from a menu.

=head3 Parameters

=over

=item $prompt

Menu prompt. Scalar string.  Required.

=item @options

Menu options. List. Required.

=back

=head3 Prints

Menu and user interaction.

=head3 Usage

    my @options = ( 'Pick me', 'No, me!' );
    my $value = undef;
    while ($TRUE) {
        $value = $self->interact_choose(
            "Select value:", @options,
        );
        last if $value;
        say "Invalid choice. Sorry, please try again." or croak;
    }

=head3 Returns

Scalar. Undef if user cancels selection.

=head2 interact_confirm($question)

User answers y/n to a question.

=head3 Parameters

=over

=item $question

Question to be answered with yes or no. Can be multi-line (use "\n"). Scalar.
Required.

=back

=head3 Prints

User interaction. After user answers, all but the first line of the question is
removed from the screen. The answer also remains on the screen.

=head3 Returns

Scalar boolean.

=head3 Usage

    my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
    if ( $self->interact_confirm($prompt) ) {
        # do stuff
    }

=head2 interact_print($msg)

=head3 Purpose

Print message to stdout if script is interactice, i.e., connected to a console,
otherwise message is not printed

=head3 Parameters

=over

=item $msg

Text to print to stdout. Scalar. Required.

=back

=head3 Prints

Message to stdout if connected to a console.

=head3 Returns

Nil.

=head2 interact_prompt([message])

=head3 Purpose

Display message and prompt user to press any key.

=head3 Parameters

=over

=item message

Prompt message. Scalar. Optional. Default: 'Press any key to continue...'.

=back

=head3 Prints

Prompt message.

=head3 Returns

N/A. Dies on failure.

=head2 interact_say($msg)

=head3 Purpose

Print message (with newline) to stdout if script is interactice,
i.e., connected to a console, otherwise message is not printed

=head3 Parameters

=over

=item $msg

Text to print (with newline) to stdout. Scalar. Required.

=back

=head3 Prints

Message (with newline) to stdout if connected to a console.

=head3 Returns

Nil.

=head2 interact_warn($msg)

=head3 Purpose

Print message (with newline) to stderr if script is interactice,
i.e., connected to a console, otherwise message is not printed

=head3 Parameters

=over

=item $msg

Text to print to stderr (with newline). Scalar. Required.

=back

=head3 Prints

Message to stderr (with newline) if connected to a console.

=head3 Returns

Nil.

=head2 internet_connection([$verbose])

=head3 Purpose

Determine whether an internet connection can be found. More specifically,
checks whether it is possible to successfully ping one of the url addresses:

=over

=item *

www.debian.org

=item *

www.uq.edu.au

=back

=head3 Parameters

=over

=item $verbose

Whether to provide feedback. Optional. Default: false.

=back

=head3 Prints

Feedback if requested.

=head3 Returns

Scalar boolean.

=head2 listify(@items)

=head3 Purpose

Tries to convert scalar, array and hash references to scalar values.

=head3 Parameters

=over

=item @item

Items to convert to lists. Required.

=back

=head3 Prints

Warnings for reference types other than SCALAR, ARRAY and HASH.

=head3 Returns

List.

=head2 list_duplicates(@values)

Identify duplicate elements in a list. Note that non-scalar values are assumed
to be unique and that element order is not preserved.

=head3 Parameters

=over

=item @values

Items to be analysed. List. Optional.

=back

=head3 Prints

Nil.

=head3 Returns

List.

=head2 pad($values, $width, $char, $side)

Left- or right-pads a value, or list of values, with a character.

=head3 Parameters

=over

=item $values

Value or values to be padded. Simple scalar or arrayref.

Optional. No default (returns null value if no value/values).

Fatal error if provide other than simple scalar or arrayref.

=item $width

Pad width. Integer. Optional. Default: length of longest item.

This value is ignored if it is less than the default length.

=item $char

Pad character. Single-character string. Optional.

Default: 0 (zero) if all values are positive integers, otherwise ' ' (space).

=item $side

Whether to left or right pad. Must be 'left' or 'right'.

Optional. Default: 'left'.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string if input is simple scalar.

List if input is an array reference.

=head3 Credit

L<Tek-Tips: Pad a String|https://www.tek-tips.com/viewthread.cfm?qid=184815>.

=head2 pager($lines, [$prefer])

=head3 Purpose

Display list of lines in terminal using pager. Unless a preferred pager is
provided the pager used is determined by C<IO::Pager>.

It does not matter whether or not the lines have terminal newlines or not.

This method is often used with method 'wrap_text' to format screen display.

=head3 Parameters

=over

=item $lines

Content to display.

Array reference. Required.

=item $prefer

Preferred pager. It is used if available.

Scalar string. Optional. No default, i.e., normally follows
L<IO::Pager|IO::Pager> algorithm.

=back

=head3 Prints

Provided content, each line begins on a new line and is intelligently wrapped.

The content is paged. See L<IO::Pager|IO::Pager> for details on the algorithm
used to determine the pager used.

=head3 Return

N/A.

=head2 path_canon($path)

Get canonical path.

Uses C<canonpath> method from the L<File::Spec> module to perform a light clean
up of the path. This does not resolve symlinks and relative paths; see the
L</"path_true"> method in this module if that is required.

Also uses the perl C<glob> function (see L<perlfunc(1)>) in case a tilde is
present in the path and needs to be resolved. This means, however, that a
wildcard in the input string can potentially resolve to multiple matching
files. This causes a fatal error.

=head3 Parameters

=over

=item $path

Path to be canonicalised. String. Required.

=back

=head3 Prints

Error message if glob error referred to above should occur.

=head3 Returns

Scalar string.

=head2 path_copy($src, $dest)

=head3 Purpose

Copy a source file or directory to a target file or directory.

=head3 Parameters

=over

=item $src

Source file or directory. The file or directory must exist on disk.
Scalar. Required.

=item $dest

=back

=head3 Prints

Nil, except for error message.

=head3 Returns

Boolean success of copy operation.

=head3 Note

Can copy file to file or directory.

Can copy directory to directory.

Can not copy directory to existing file.

=head2 path_executable($exe)

Find path to executable file.

=head3 Parameters

=over

=item $exe

Short name of executable. String. Required.

=back

=head3 Prints

Error messages.

=head3 Returns

Scalar string, undef if not executable file not found in path.

Dies if no parameter provided.

=head2 path_join(@parts)

=head3 Purpose

Concatenate list of directories and a file name into a string path.

=head3 Parameters

=over

=item @parts

Path parts, i.e., directory parts followed by file name. List.

Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string directory path.

=head2 path_parts($filepath, $exists = $FALSE)

Get directory path and file name from file path.

=head3 Parameters

=over

=item $filepath

File path from which to extract directory path and file name. Scalar string.
Required.

=item $exists

Whether to die if the provided filepath does not exist. Boolean. Optional.
Default: false.

=back

=head3 Prints

Error messages.

=head3 Returns

List of strings: ($directory_path, $file_name). Note that the directory path
includes the terminal path separator, so that concatenating directory path and
file name results in the original file path.

=head2 path_remove(@paths)

=head3 Purpose

Delete files and recursively delete directories.

=head3 Parameters

=over

=item @paths

One or more file paths or directory paths to recursively delete. Required.

=back

=head3 Prints

Error messages if deletion is unsuccessful.

=head3 Returns

Scalar boolean indicating whether deletion was successful.

The method dies if a fatal filesystem error occurs. See the documentation for
L<File::Path/"DIAGNOSTICS"> for more details.

=head2 path_true($path, $exists = $FALSE)

Convert relative path to absolute path. Absolute filepaths are returned
unchanged. Symlinks are followed and converted to their true filepaths.

=head3 Parameters

=over

=item $path

Path to convert. String. Required.

Note: double quote this parameter value if it is a variable. If not, passing a
value like F<./> results in an error as it is somehow reduced to an empty
value.

=item $exists

Die if path does not exist. Boolean. Optional. Default: false.

=back

=head3 Prints

Nil.

=head3 Return

Scalar string.

=head2 pluralise($string, $numeric)

=head3 Purpose

Adjust a string based on a provided numerical value.

=head3 Parameters

=over

=item $string

Formatted string containing alterative word choices to use depending on the
numeric value provided. See L<Text::Pluralize> for details of the string
format. Scalar string. Required.

=item $number

Integer value determining whether the string represents a plural or not. See
L<Text::Pluralize> for details. Scalar positive integer. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 run_command($err, @cmd)

=head3 Purpose

Run a shell command. On failure die with a custom error message.

=head3 Parameters

=over

=item $err

Error message to display if command fails. Scalar string. Required, but can be
undef.

=item @cmd

Command and arguments to execute. List. Required.

=back

=head3 Prints

Command output, plus supplied error message if the command fails.

=head3 Returns

N/A. Dies on failure.

=head3 Usage

This is example usage for executing a single shell command:

    my @cmd = qw(debuild -i -us -uc -b);
    say q{Running '} . join( q{ }, @cmd ) . q{':} or confess;
    $self->run_command( undef, @cmd );

This is example usage for executing a series of shell commands:

    my @cmds = (
        [qw( prove -l t )],
        [qw( milla test )],
        [qw( milla build )],
    );
    for my $cmd (@cmds) {
        say q{Running '} . join( q{ }, @{$cmd} ) . q{':} or confess;
        $self->run_command( undef, @{$cmd} );
    }

=head3 Note

Displays command output in real time but does not capture it. Compare with
C<shell_command> method.

=head2 script_name()

=head3 Purpose

Get name of executing script.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar file name.

=head2 shell_command($cmd, $fatal = $TRUE, $timeout = 0)

=head3 Purpose

Run shell command and capture exit status and output.

Warning: If the command contains a pipe the command may execute successfully
but not exit. In these cases using the C<timeout> parameter may help, but at
the cost of causing the command to be stopped, generating a shell error.

=head3 Parameters

=over

=item $cmd

Command to run. Array reference or string, but note that array references are
safer at handling whitespace in command elements. Required.

=item $fatal

Whether to croak if shell command fails. Optional. Default: true.

=item timeout

Maximum execution time for command (in seconds), after which command is stopped
and exits with exit code 127. Optional. Default: 0 (means no timeout).

=back

=head3 Prints

Nil.

=head3 Returns

Role::Utils::Dn::CommandResult object.

=head3 Note

The returned object can provide stdout output, stderr output and full output
(stdout and stderr combined as initially output). In each case, the output is
provided as a list, with each list element being a line of original output.

=head3 Note

Does not display command output in real time. Compare with C<run_command>
method.

=head2 stringify($val)

Convert value to string. The resulting string may contain newlines.

Non-scalar values are converted to scalar values by the C<Dumper()> function
from the L<Data::Dumper::Simple> module.

=head3 Parameters

=over

=item $val

Value to convert. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 string_entitise($string)

=head3 Purpose

Convert reserved characters in a string to HTML entities.

=head3 Parameters

=over

=item $string

String to analyse. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 string_tabify($string, [$tab_size])

=head3 Purpose

Covert tab markers ('\t') to spaces in a string.

=head3 Parameters

=over

=item $string

String to convert. Scalar. Required.

=item $tab_size

Size of tab in characters. Integer. Optional. Default: 4.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 term_height( )

Provides height of terminal in characters.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar integer.

=head2 term_width( )

Provides width of terminal in characters.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar integer.

=head2 time_24h_valid($time)

=head3 Purpose

Determine whether the supplied time is a valid 24 hour time.

=head3 Parameters

=over

=item $time

The time to evaluate, in 'HH:MM' or 'HHMM' format, noting the leading zero can
be dropped. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar boolean.

=head2 time_now()

=head3 Purpose

Get current time ('HH::MM::SS').

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

head2 time_zone_from_offset($offset)

=head3 Purpose

Determine timezone for a given offset, preferring Australian timezones.

=head3 Parameters

=over

=item $offset

Timezone offset to check. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 time_zone_from_offset($offset)

=head3 Purpose

Determine timezone for a given offset.

=head3 Parameters

=over

=item $offset

Timezone offset to check. Scalar string. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 time_zone_local()

=head3 Purpose

Get local timezone.

=head3 Parameters

Nil.

=head3 Prints

Nil.

=head3 Returns

Scalar string.

=head2 tools_available(@tools)

=head3 Purpose

Check that required executables are available on the system.

=head3 Parameters

=over

=item @tools

Required executables. List. Optional.

=back

=head3 Prints

Message to stderr listing any unavailable tools. The error message is
word-wrapped and looks like:

    Required executable is not available: not-here
    Required executables are not available: not-here, me-either

=head3 Returns

Scalar boolean.

=head3 Usage

    if ( not $cp->tools_available( 'tar', 'gzip' ) ) { return; }

=head2 value_boolise($value)

=head3 Purpose

Convert certain values to boolean:

=over

=item convert 'yes', 'true' and 'on' to 1

=item convert 'no, 'false, and 'off' to 0

=item other values returned unchanged

=back

=head3 Parameters

=over

=item $value

Value to analyse. Scalar. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Boolean scalar.

=head2 vim_list_print(@messages)

=head3 Purpose

Prints a list of strings to the terminal screen using vim's default colour
scheme.

See method C<vim_print> for details of the colour schemes.
Each message can be printed in a different style.
Element strings need to be prepared using using the method C<vim_printify>.

There are currently five styles implemented:

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

=item @messages

Messages to display. They can contain escaped double quotes.
Scalar strings. Required.

=back

=head3 Prints

Messages in requested styles.

=head3 returns

Nil.

=head2 vim_print($type, @messages)

=head3 Purpose

Print text to terminal using vim's default colour scheme.

=head3 Parameters

=over

=item $type

Message type. Can be:

=over

=item title

=item error

=item warning

=item prompt

=item normal

=back

The provided value can be any case, and can be partial.
Scalar string. Required.

=item @messages

Content to print. Can contain escaped double quotes.

Arrays and array references in the message list are handled gracefully.

Multi-part. Required.

=back

=head3 Prints

Messages.

=head3 returns

Nil.

=head3 Usage

    $cp->vim_print( 't', "This is a title" );

=head2 vim_printify($type, $message)

=head3 Purpose

Modifies a single string to be passed to the method C<vim_list_print>.

=head3 Parameters

=over

=item $type

As per method C<vim_print>. Required.

=item $message

Content to be modified. Can contain escaped double quotes. Required.

=back

=head3 Prints

Nil.

=head3 Returns

Modified string.

=head3 Usage

    @output = $cp->vim_printify( 't', 'My Title' );

=head3 Note

The string is given a prefix that signals to the method C<vim_list_print> what
format to use. (The prefix is stripped before printing.)

=head2 wrap_text($strings, [%options])

=head3 Purpose

Wrap strings at terminal (or provided) width. Lines that continue to the
following line have an appended continuation character (U+21A9, leftwards arrow
with hook).

This method is often used with method 'pager' to format screen display.

=head3 Parameters

=over

=item $strings

Text to wrap. Single string or reference to array of strings.

String or string arrayref. Required.

=item %options

Options hash. Optional.

Hash members:

=over

=item width

Width at which to wrap. Cannot be wider than terminal width; if it is, this
width is silently discarded and the terminal width is used instead.

Scalar integer. Optional. Default: terminal width.

=item indent

Size of indent. Can be indent of first line only (if $hang is also provided) or
of all lines (if $hang is not provided). Text is indented with spaces.

Scalar integer. Optional. Default: 0.

=item hang

Size of indent of second and subsequent lines. If not provided, $indent is used
for all lines.

There are two formats for $hang. The first format is the usual meaning of a
hanging indent, where second and subsequent lines are indented by the nominated
number of spaces. This format accepts an integer >= 0.

The second format is referred to as an extended hanging indent. In this format
the base hanging indent is equal to the number of leading spaces in the first
row of input, optionally with an additional indent amount. This format accepts
a string like "e=X" (or "E=X") where the "e" (or "E") is a flag indicating use
of the extended hanging indent format and 'X' is an integer >= 0. As a special
case, a simple "e" (or "E") is the same as "e=0" (or "E=0").

Scalar integer. Optional. Default: $indent.

=item break

A regular expression defining the characters on which to break lines.

If a "simple" regexp is used, the break characters used to break lines will be
consumed. This is the preferred behaviour when the only break characters are
whitespace, but can be problematic when characters with semantic significance,
such as commas or dashes, are used. Here are examples of "simple" regexps
defining break characters:

    qr{[\s-]}    # space and dash
    qr{[\s']}    # space and apostrophe

If you do not want the break characters to be consumed, use a positive
lookbehind construct (see L<perlre/"Lookaround Assertions">). Some examples
are:

    qr{(?<=[\\\/\+-])}    # backslash, slash, plus and dash

In both simple and lookbehind regexps it may be necessary to experiment with
escapes to determine when they are necessary. There has not yet been need to
mix consumable and non-consumable break characters; if you manage to make it
work, please send me the regular expressions you devise!

Regexp. Optional. Default: qr{[\s]}.

=item cont

Whether to append a U+21A9 (leftwards arrow with hook) character to every line
which is continued on the following line.

Boolean. Optional. Default: $FALSE.

=back

=back

=head3 Prints

Nil, except error messages.

=head3 Returns

List of scalar strings (no terminal newlines).

=head3 Usage

    my @output = $self->term_wrap($long_string, indent => 2, hang => 4);
    my @output = $self->term_wrap([@many_strings]);

=head1 DIAGNOSTICS

=head2 Unable to extract debhelper major version number from version: VERSION

Occurs while attempting to extract the major part of the version number of the
F<debhelper> debian package to use as the debian compatibility level.

=head2 Unable to extract version information for package PKG
=head2 Unable to extract PKG version from OUTPUT

Occur when attempting to determine a debian packages current version by parsing
the package's status information as returned by C<dpkg -s>.

=head2 Unable to get 'debian-policy' status with dpkg
=head2 Unable to extract 3-part version from 'VERSION'

These errors occur while attempting to determine the current debian standards
version, which is actually the current version of the F<debian-policy> debian
package to the first three parts.

=head2 Invalid integer 'VALUE'

Occurs when a non-integer is provided to the C<int_pad_width> method.

=head2 Empty color
=head2 No top/bottom border width provided
=head2 No side border width provided
=head2 No bottom-right pixel y-coord provided
=head2 No bottom-right pixel x-coord provided
=head2 No top_left pixel y-coordinate provided
=head2 No top_left pixel x-coordinate provided
=head2 No fill color provided
=head2 No width provided
=head2 No height provided
=head2 No y-coordinate provided
=head2 No x-coordinate provided
=head2 No label text provided
=head2 No file mask provided
=head2 No image provided
=head2 No filepath provided

These errors occur when a required parameter to an image-related method is not
provided.

=head2 Too many arguments

Occurs when the wrong number of parameters is provided to a function.

=head2 Non-integer border width 'WIDTH'
=head2 Non-integer border width 'WIDTH'
=head2 Not an image object
=head2 Invalid filepath 'PATH'
=head2 Invalid attributes var type 'TYPE'
=head2 Invalid coordinate 'COORD'
=head2 Not an image object
=head2 Invalid space value 'SPACE'
=head2 Invalid edge 'EDGE'
=head2 Invalid size value 'SIZE'
=head2 Non-integer y-coordinate 'Y'
=head2 Non-integer x-coordinate 'X'
=head2 X-coordinate $x > image's largest x-coord COORD
=head2 Y-coordinate $y > image's largest y-coord COORD
=head2 Incomplete color provided (COLOR)
=head2 Non-integer color value (COLOR)
=head2 Non-integer width 'WIDTH'
=head2 Non-integer height 'HEIGHT'
=head2 Color value out of range (COLOR)

These errors occur when an invalid parameter value is provided to an
image-related method.

=head2 Image::Magick->METHOD failed: ERROR

These errors occur if an L<Image::Magick> method fails.

=head2 No source directory provided
=head2 No target provided
=head2 No source file provided
=head2 No filepaths
=head2 No target directory provided
=head2 No filepath provided
=head2 No dirpath provided
=head2 Filepath 1 not provided
=head2 Filepath 2 not provided
Occurs when a path is required by a function but is not provided.
=head2 Source directory 'PATH' does not exist
=head2 Source file 'PATH' does not exist
=head2 Filepath 'PATH' does not exist
=head2 Directory path 'PATH' does not exist
=head2 Invalid directory 'PATH'
=head2 Comparison file 'PATH' does not exist

Occurs when an existing path is required by a function but the provided path:

=over

=item does not exist, or

=item the executing script does not have permission to detect the path.

=back

=head2 Unable to compare 'PATH' and 'PATH': ERROR

Occurs when module function C<File::Compare::compare> issues an error.

=head2 Multiple paths match 'GLOB'

Occurs when a function requires a single path as a parameter, but also accepts
a file glob as that parameter. In such circumstances the file glob must match
only one file or this error is produced.

=head2 No executable name provided

Occurs when an executable name is required but not provided.

=head2 System error

When a disk operation, such as a file move or copy, fails, the underlying
system error is captured and reported to the user.

=head2 Not an array reference
=head2 Input is not a string or array reference
=head2 Invalid option 'OPTION'

These errors occur when an invalid parameter value is provided.

=head2 Values are 'TYPE' instead of 'ARRAY'";
=head2 Invalid width 'WIDTH'
=head2 Want single pad char, got 'STRING'
=head2 Expect side is 'left' or 'right', got 'ARG'

These errors occur when an invalid parameter value is provided.

=head2 No lines provided
=head2 No strings provided

These errors occur when a required function parameter is not provided.

=head2 Not an array reference
=head2 Input is not a string or array reference
=head2 Invalid option 'OPTION'

These errors occur when an invalid parameter value is provided.

=head2 Cannot read data file 'FILE'

This error occurs when unable to read from a data store.

=head2 Data structure is not a reference
=head2 Invalid data file path in 'FILE'

These errors occur when attempting to write a data store.

=head2 Overwriting data file 'FILE' with new data

This warning occurs when overwriting an existing data store file.

=head2 No menu options provided

Occurs when no menu options are provided to choose from.

=head2 Cannot listify a 'REF_TYPE'

Occurs when attempting to convert to scalar a value that is neither
a scalarref, arrayref, nor hashref.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Clipboard, Const::Fast, Curses, Data::Dumper::Simple,
Date::Simple, DateTime, DateTime::TimeZone, DateTime::Format::Mail, English,
Env, Feature::Compat::Try, File::Basename, File::Compare,
File::Copy::Recursive, File::Path, File::Spec, File::Temp, File::Util,
File::Which, HTML::Entities, IO::Interactive, IO::Pager, IPC::Cmd, IPC::Run,
Image::Magick, List::SomeUtils, List::Util, Moo::Role, namespace::clean, POSIX,
Path::Tiny, Scalar::Util, strictures, Symbol, Term::ANSIColor, Term::Clui,
Term::ProgressBar::Simple, Text::Wrap, Time::Simple, version.

=head2 Other

xclip.

=head1 INCOMPATIBILITIES

There are no known incompatibilities. If you discover any, please report them
to the author.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head2 Exhausting cache resources during image processing

The methods C<image_create> and C<image_write> utilise Image::Magick C<Read>
and C<Write> operations, respectively. Both operations can potentially exhaust
Image::Magick's cache resources causing fatal errors.

For example, reading a 30MB pdf file containing 30 pages has caused a fatal
error on a mid-range desktop computer system, as has attempting to write each
pdf page as a separate png image file. In each case the error is due to
inability to read from or write to the pixel cache (Image::Magick error code
445). A sample error message is:

    Exception 445: cache resources exhausted

To see the resources allocated to ImageMagick use this command:

    identify -list resource

One method of increasing the resources available to ImageMagick, and thus
avoiding cache resource exhaustion, is to increase resources allocation. On
debian systems this can be done by editing S<<
F</etc/ImageMagick-6/policy.xml>. >> Look for lines like this and change the
values appropriately:

    <policy domain="resource" name="memory" value="256MiB"/>
    <policy domain="resource" name="map" value="512MiB"/>
    <policy domain="resource" name="width" value="16KP"/>
    <policy domain="resource" name="height" value="16KP"/>
    <policy domain="resource" name="area" value="128MB"/>
    <policy domain="resource" name="disk" value="1GiB"/>


=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
