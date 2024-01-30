# NAME

Dn::Common - common methods for use by perl scripts

# SYNOPSIS

    use Dn::Common;

# DESCRIPTION

Provides methods used by Perl scripts. Can be used to create a standalone object providing these methods; or as base class for derived module or class.

# SUBROUTINES/METHODS

## abort(@messages, \[$prepend\])

### Purpose

Display console message and abort script execution.

### Parameters

- @messages

    Message lines. Respects newlines if enclosed in double quotes.

    Required.

- $prepend

    Whether to prepend each message line with name of calling script.

    Named parameter. Boolean.

    Optional. Default: false.

### Prints

Messages followed by abort message.

### Returns

Nil.

### Usage

    $cp->abort('We failed');
    $cp->abort('We failed', prepend => $TRUE);

## android\_copy\_file($source, $target, $android)

### Purpose

Copy file to or from android device.

### Parameters

- $source

    Source file path.

    Required.

- $target

    Target file or directory.

    Required.

- $android

    Which path is on android device. Must be 'source' or 'target'.

    Required.

### Prints

Nil, except error message.

### Returns

N/A, die if serious error.

### Notes

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

Method tries using `fb-adb` then `adb` and dies if both unavailable.

## android\_devices( )

### Purpose

Get attached android devices.

### Parameters

Nil.

### Prints

Nil.

### Returns

List of attached devices. (Empty list if none.)

### Note

Tries to use `fb-adb` then `adb`. If neither is detected prints an error message and returns empty list (or undef if called in scalar context).

## android\_device\_reset( )

### Purpose

Reset android device for android operations.

### Parameters

Nil.

### Prints

User feedback if no android devices available, or user has to select between multiple devices.

### Returns

Scalar string (device id), or undef if no device is set.
Boolean scalar.

### Warning

This method is called automatically whenever a method is called that requires an android device and one has not already been selected. If only one android device is available, it is selected automatically. If multiple android devices are available, the user is prompted to select one. If no android device is available, the method dies.

A selected device is used for subsequent methods that require an android device, provided the device is still available. If the previously selected android device has become unavailable, when the next method is called that requires an android device, a new device is selected as before.

For these reasons, this method should rarely need to be called directly.

## android\_file\_list($dir)

### Purpose

Get list of files in an android directory.

### Parameters

- $dir

    Android directory to obtains contents of.

    Required.

### Prints

Nil, except for error messages.

### Returns

List of file names.

### Note

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

## android\_mkdir($dir)

### Purpose

Ensure subdirectory exists on android device.

### Parameters

- $dir

    Directory to create.

    Required.

### Prints

Nil, except error messages.

### Returns

N/A, dies on failure.

### Notes

No error if directory already exists, e.g., `mkdir -p`.

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

Method tries using `fb-adb` then `adb` and dies if both unavailable.

## android\_subdir\_list($dir)

### Purpose

Get list of subdirectories in an android directory.

### Parameters

- $dir

    Android directory to obtains contents of.

    Required.

### Prints

Nil, except for error messages.

### Returns

List of subdirectory names.

### Note

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

## autoconf\_version( )

### Purpose

Gets autoconf version. Can be used as value for the autoconf macro 'AC\_PREREQ'.

### Parameters

Nil.

### Prints

Nil on successful execution.

Error message on failure.

### Returns

Scalar string. Dies on failure.

## backup\_file($file)

### Purpose

Backs up file by renaming it to a unique file name. Will simply add integer to file basename.

### Parameters

- $file

    File to back up.

    Required.

### Prints

Nil.

### Returns

Scalar filename.

## boolise($value)

### Purpose

Convert value to boolean.

Specifically, converts 'yes', 'true' and 'on' to 1, and convert 'no, 'false, and 'off' to 0. Other values are returned unchanged.

### Parameters

- $value

    Value to analyse.

    Required.

### Prints

Nil.

### Returns

Boolean.

## browse($title, $text)

### Purpose

Displays large volume of text in default editor and then returns viewer to original screen.

### Parameters

- $title

    Title is prepended to displayed text (along with some usage instructions) and is used in creating the temporary file displayed in the editor.

    Required.

- $text

    Text to display.

    Required.

### Prints

Nil.

### Returns

Nil.

## capture\_command\_output($cmd)

### Purpose

Run system command and capture output.

### Parameters

- $cmd

    Command to run. Array reference.

    Required.

### Prints

Nil.

### Returns

Dn::Common::CommandResult object.

### Note

The returned object can provide stdout output, stderr output and full output (stdout and stderr combined as initially output). In each case, the output is provided as a list, with each list element being a line of original output.

## centre\_text(\[$text\], \[$width\])

### Purpose

Centre text within specified width by inserting leading spaces.

### Parameters

- $text

    Text to centre.

    Optional. Default: empty string.

- $width

    Width of line within which to centre text.

    Optional. Default: terminal width.

### Prints

Nil, except error messages.

### Returns

Scalar string.

### Usage

    my $string = 'Centre me';
    my $centred = $cp->centre_text( $string, 20 );
    # $centred = '     Centre me'

## changelog\_from\_git($dir)

### Purpose

Get ChangLog content from git repository.

### Parameters

- $dir

    Root file of repository. Must contain `.git` subdirectory.

    Required.

### Prints

Nil, except feedback on failure.

### Returns

List of scalar strings.

## clear\_screen( )

### Purpose

Clear the terminal screen.

### Parameters

Nil.

### Prints

Nil.

### Returns

Nil.

### Usage

    $cp->clear_screen;

## config\_param($parameter)

### Configuration file syntax

This method can handle configuration files with the following formats:

- simple

        key1  value1
        key2  value2

- http-like

        key1: value1
        key2: value2

- ini file

        [block1]
        key1=value1
        key2=value2

        [block2]
        key3 = value3
        key4 = value4

    Note in this case the block headings are optional.

Warning: Mixing formats in the same file will cause a fatal error.

The key is provided as the argument to method, e.g.:
    $parameter1 = $cp->config\_param('key1');

If the ini file format is used with block headings, the block heading must be included using dot syntax, e.g.:
    $parameter1 = $cp->config\_param('block1.key1');

### Configuration file locations and names

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

### Multiple values

A key can have multiple values separated by commas:

    key1  value1, value2, "value 3"

or

    key1: value1, value2

or

    key1=value1, value2

This is different to multiple **lines** in the configuration files defining the same key. In that case, the last such line overwrites all earlier ones.

### Return value

As it is possible to retrieve multiple values for a single key, this method returns a list of parameter values. If the result is obtained in scalar context it gives the number of values - this can be used to confirm a single parameter result where only one is expected.

## cwd( )

### Purpose

Provides current directory.

### Parameters

Nil.

### Prints

Nil.

### Returns

Scalar string

## date\_email (\[$date\], \[$time\], \[$offset\])

### Purpose

Produce a date formatted according to RFC 2822 (Internet Message Format). An example such date is 'Mon, 16 Jul 1979 16:45:20 +1000'.

### Parameters

- $date

    ISO-formatted date.

    Named parameter. Optional. Default: today.

- $time

    A time in 24-hour format: 'HH:MM\[:SS\]'. Note that the following are not required: leading zero for hour, and seconds.

    Named parameter. Optional. Default: now.

- $offset

    Timezone offset. Example: '+0930'.

    Named parameter. Optional. Default: local timezone offset.

### Prints

Nil routinely. Error message if fatal error encountered.

### Returns

Scalar string, undef if method fails.

## day\_of\_week(\[$date\])

### Purpose

Get the day of week that the supplied date falls on.

### Parameters

- $date

    Date to analyse. Must be in ISO format.

    Optional. Default: today.

### Prints

Nil.

### Returns

Scalar day name.

## debian\_install\_deb($deb)

### Purpose

Install debian package from a deb file.

First tries to install using `dpkg` as if the user were root. If that fails, tries to install using `sudo dpkg`. If that fails, finally tries to install using `su -c dpkg`, which requires entry of the superuser (root) password.

### Parameters

> - $deb
>
>     Debian package file.
>
>     Required.

### Prints

Feedback.

### Returns

Scalar boolean.

## debless($object)

### Purpose

Get underlying data structure of object/blessed reference. Will only work on an object containing an underlying data structure that is a hash.

### Parameters

- $object

    Blessed reference to obtain underlying data structure of. Underlying data structure must be a hash.

    Required.

### Prints

Nil, except error message if method fails.

### Returns

Hash. Dies if method fails.

## deentitise($string)

### Purpose

Perform standard conversions of HTML entities to reserved characters.

### Parameters

- $string

    String to analyse.

    Required.

### Prints

Nil.

### Returns

Scalar string.

## denumber\_list(@list)

### Purpose

Remove number prefixes added by method 'number\_list'.

### Parameters

- @items

    List to modify.

    Required.

### Prints

Nil.

### Return

List.

## dir\_add\_dir($dir, @subdirs)

### Purpose

Add subdirectory to directory path.

### Parameters

- $dir

    Directory path to add to. The directory need not exist.

    Required.

- @subdirs

    Subdirectories to add to path.

    Required.

### Prints

Nil.

### Returns

Scalar directory path.

## dir\_add\_file($dir, $file)

### Purpose

Add file name to directory path.

### Parameters

- $dir

    Directory path to add to. The directory need not exist.

    Required.

- $file

    File name to add to path.

    Required.

### Prints

Nil.

### Returns

Scalar file path.

## dirs\_list(\[$directory\])

### Purpose

List subdirectories in directory. Uses current directory if no directory is supplied.

### Parameters

- $directory

    Directory from which to obtain file list.

    Optional. Default: current directory.

### Prints

Nil (error message if dies).

### Returns

List (dies if operation fails).

## display($string, \[$error\])

### Purpose

Displays text on screen with word wrapping.

### Parameters

- $string

    Test for display.

    Required.

- $error

    Print text to stderr rather than stdout. Boolean.

    Optional. Default: false.

### Print

Text for screen display.

### Return

Nil.

### Usage

    $cp->display($long_string);

## do\_copy($src, $dest)

### Purpose

Copy source file or directory to target file or directory.

### Parameters

- $src

    Source file or directory. Must exist.

    Required.

- $dest

    Destination file or directory. Need not exist.

    Required.

### Prints

Nil on successful operation.

Error message on failure.

### Returns

Boolean success of copy operation.

Dies if missing argument.

### Notes

Can copy file to file or directory, and directory to directory, but _not_ directory to file.

Uses the File::Copy::Recursive::rcopy function which tries very hard to complete the copy operation, including creating missing subdirectories in the target path.

## do\_rmdir($dir)

### Purpose

Removes directory recursively (like 'rm -fr').

### Parameters

- $dir

    Root of directory tree to remove.

    Required.

### Prints

Nil.

### Returns

Boolean scalar.

## do\_wrap($strings, \[%options\])

### Purpose

Wrap strings at terminal (or provided) width. Continuation lines have a prepended continuation character (U+21A9, leftwards arrow with hook).

This method is often used with method 'pager' to format screen display.

### Parameters

- $strings

    Text to wrap. Single string or reference to array of strings.

    Required.

- %options

    Options hash. Optional.

    Hash members:

    - $width

        Width at which to wrap.

        Optional. Default: terminal width.

        Note: Cannot be wider than terminal width. If it is, this width is silently discarded and the terminal width used instead.

    - $indent

        Size of indent. Can be indent of first line only (if $hang is also provided) or of all lines (if $hang is not provided). Indent is spaces.

        Optional. Default: 0.

    - $hang

        Size of indent of second and subsequent lines. If not provided, $indent is used for all lines.

        Optional. Default: $indent.

    - $break

        Characters on which to break. Cannot includes escapes (such as '\\s'). Array reference.

        Optional. Default: \[' '\].

### Prints

Nil, except error messages.

### Returns

List of scalar strings (no terminal newlines).

### Usage

    my @output = $cp->do_wrap($long_string, indent => 2, hang => 4);
    my @output = $cp->do_wrap([@many_strings]);

## echo\_e($string)

### Purpose

Use shell command 'echo -e' to display text in console. Escape sequences are escaped.

### Parameters

- $text

    Text to display. Scalar string.

    Required.

### Prints

Text with shell escape sequences escaped.

### Returns

Nil.

## echo\_en($string)

### Purpose

Use shell command 'echo -en' to display text in console. Escape sequences are escaped. No newline is appended.

### Parameters

- $text

    Text to display. Scalar string.

    Required.

### Prints

Text with shell escape sequences escaped and no trailing newline.

### Returns

Nil.

## ensure\_no\_trailing\_slash($dir)

### Purpose

Remove trailing slash ('/'), if present, from directory path.

### Parameters

- $dir

    Directory path to analyse.

    Required.

### Prints

Nil.

### Returns

Scalar string (directory path).

Undef if no directory path provided.

## ensure\_trailing\_slash($dir)

### Purpose

Ensure directory has a trailing slash ('/').

### Parameters

- $dir

    Directory path to analyse.

    Required.

### Prints

Nil.

### Returns

Scalar string (directory path).

Undef if no directory path provided.

## entitise($string)

### Purpose

Perform standard conversions of reserved characters to HTML entities.

### Parameters

- $string

    String to analyse.

    Required.

### Prints

Nil.

### Returns

Scalar string.

## executable\_path($exe)

### Purpose

Get path of executable.

### Parameters

- $exe

    Short name of executable.

    Required.

### Prints

Nil.

### Return

Scalar filepath: absolute path to executable if executable exists.

Scalar boolean: returns undef If executable does not exist.

## extract\_key\_value($key, @items)

### Purpose

Provided with a list that contains a key-value pair as a sequential pair of elements, return the value and the list-minus-key-and-value.

### Parameters

- $key

    Key of the key-value pair.

    Required.

- @items

    The items containing key and value.

    Required.

### Prints

Nil.

### Returns

List with first element being the target value (undef if not found) and subsequent elements being the original list minus key and value.

### Usage

    my ($value, @list) = $cp->($key, @list);

## file\_used\_by($file)

### Purpose

Get ids of processes using a specified file.

### Parameters

- $file

    File or filepath. Can be relative or absolute.

    Required.

### Prints

Nil, except error messages.

### Returns

List of pids.

### Note

Uses shell utility `fuser`.

## files\_list(\[$directory\])

### Purpose

List files in directory. Uses current directory if no directory is supplied.

### Parameters

- $directory

    Directory path.

    Optional. Default: current directory.

### Prints

Nil.

### Returns

List. Dies if operation fails.

## find\_files\_in\_dir($dir, $pattern)

### Purpose

Finds file in directory matching a given pattern. Note that only the nominated directory is searched -- the search does not recurse into subdirectories.

### Parameters

- $dir

    Directory to search.

    Required.

- $pattern

    File name pattern to match. It can be a glob or a regular expression.

    Required.

### Prints

Nil.

### Returns

List of absolute file paths.

## future\_date($date)

### Purpose

Determine whether supplied date occurs in the future, i.e, today or after today.

### Parameters

- $date

    Date to compare. Must be ISO format.

    Required.

### Prints

Nil. (Error if invalid date.)

### Return

Boolean. (Dies if invalid date.)

## get\_filename($filepath)

### Purpose

Get filename from filepath.

### Parameters

- $filepath

    Filepath to analyse. Assumed to have a filename as the last element in the path.

    Required.

### Prints

Nil.

### Returns

Scalar string (filename).

### Note

This method simply returns the last element in the path. If it is a directory path, and there is no trailing directory separator, the final subdirectory in the path is returned. It is potentially possible to check the path at runtime to determine whether it is a directory path or file path. The disadvantage of doing so is that the method would then not be able to handle _virtual_ filepaths.

## get\_last\_directory($dirpath)

### Purpose

Get last directory from a directory path.

### Parameters

- $dirpath

    Directory path to analyse.

    Required.

### Prints

Nil, except error messages.

### Returns

Scalar path (dies on failure).

## get\_path($filepath)

### Purpose

Get path from filepath.

### Parameters

- $filepath

    File path.

    Required.

### Prints

Nil.

### Returns

Scalar path.

## input\_ask($prompt, \[$default\], \[$prepend\])

### Purpose

Obtain input from user.

This method is intended for entering short values. Once the entered text wraps to a new line the user cannot move the cursor back to the previous line.

Use method 'input\_large' if the value is likely to be longer than a single line.

### Parameters

- $prompt

    User prompt. If user uses 'prepend' option (see below) the script name is prepended to the prompt.

- $default

    Default input.

    Optional. Default: none.

- $prepend

    Whether to prepend the script name to the prompt.

    Named parameter. Boolean.

    Optional. Default: false.

### Prints

User interaction.

### Returns

User's input (scalar).

### Usage

    my $value;
    my $default = 'default';
    while (1) {
        $value = $self->input_ask( "Enter value:", $default );
        last if $value;
    }

## input\_choose($prompt, @options, \[$prepend\])

### Purpose

User selects option from a menu.

### Parameters

- $prompt

    Menu prompt.

    Required.

- @options

    Menu options.

    Required.

- $prepend

    Flag indicating whether to prepend script name to prompt.

    Named parameter. Scalar boolean.

    Optional. Default: false.

### Prints

Menu and user interaction.

### Returns

Return value depends on the calling context:

- scalar

    Returns scalar (undef if choice cancelled).

- list

    Returns list (empty list if choice cancelled).

### Usage

    my $value = undef;
    my @options = ( 'Pick me', 'No, me!' );
    while ($TRUE) {
        $value = $self->input_choose( "Select value:", @options );
        last if $value;
        say "Invalid choice. Sorry, please try again.";
    }

## input\_confirm($question, \[$prepend\])

### Purpose

User answers y/n to a question.

### Parameters

- $question

    Question to elicit user response. If user uses 'prepend' option (see below) the script name is prepended to it.

    Can be multi-line, i.e., enclose in double quotes and include '\\n' newlines. After the user answers, all but first line of question is removed from the screen. For that reason, it is good style to make the first line of the question a short summary, and subsequent lines can give additional detail.

    Required.

- $prepend

    Whether to prepend the script name to the question.

    Boolean.

    Optional. Default: false.

### Prints

User interaction.

### Return

Scalar boolean.

### Usage

    my $prompt = "Short question?\n\nMore\nmulti-line\ntext.";
    if ( input_confirm($prompt) ) {
        # do stuff
    }

## input\_large($prompt, \[$default\], \[$prepend\])

### Purpose

Obtain input from user.

This method is intended for entry of data likely to be longer than a single line. Use method 'input\_ask' if entering a simple (short) value. An editor is used to enter the data. The default editor is used. If no default editor is set, vi(m) is used.

When the editor opens it displays some boilerplate, the prompt, a horizontal rule (a line of dashes), and the default value if provided. When the editor is closed all lines up to and including the first horizontal rule are deleted. The user can get the same effect by deleting in the editor all lines up to and including the first horizontal rule.

Use method 'input\_ask' if the prompt and input will fit on a single line.

### Parameters

- $prompt

    User prompt. If user uses 'prepend' option (see below) the script name is prepended to the prompt.

- $default

    Default input.

    Optional. Default: none.

- $prepend

    Whether to prepend the script name to the prompt.

    Named parameter. Boolean.

    Optional. Default: false.

### Prints

User interaction.

### Returns

User's input as list, split on newlines in user input.

### Usage

Here is a case where input is required:

    my @input;
    my $default = 'default';
    my $prompt = 'Enter input:';
    while (1) {
        @input = $self->input_large( $prompt, $default );
        last if @input;
        $prompt = "Input is required\nEnter input:";
    }

## internet\_connection(\[$verbose\])

### Purpose

Checks to see whether an internet connection can be found.

### Parameters

- $verbose

    Whether to provide user feedback during connection attempts.

    Optional. Default: false.

### Prints

Feedback if requested, otherwise nil.

### Returns

Boolean.

## is\_android\_directory($path)

### Purpose

Determine whether path is an android directory.

### Parameters

- $path

    Path to check.

    Required.

### Prints

Nil, except error messages.

### Returns

Boolean (dies if no path provided).

### Note

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

## is\_android\_file($path)

### Purpose

Determine whether path is an android file.

### Parameters

- $path

    Path to check.

    Required.

### Prints

Nil, except error messages.

### Returns

Boolean (dies if no path provided).

### Note

See method ["android\_device\_reset"](#android_device_reset) regarding selection of android device for this method.

## is\_boolean($value)

### Purpose

Determine whether supplied value is boolean.

Specifically, checks whether value is one of: 'yes', 'true', 'on', 1, 'no, 'false, 'off' or 0.

### Parameters

- $value

    Value to be analysed.

    Required.

### Prints

Nil.

### Returns

Boolean. (Undefined if no value provided.)

## is\_deb($filepath)

### Purpose

Determine whether file is a debian package file.

### Parameters

- $filepath

    File to analyse.

    Required. Method dies if $filepath is not provided or is invalid.

### Prints

Nil.

### Returns

Scalar boolean.

## is\_mp3($filepath)

### Purpose

Determine whether file is an mp3 file.

### Parameters

- $filepath

    File to analyse.

    Required. Method dies if $filepath is not provided or is invalid.

### Prints

Nil.

### Returns

Scalar boolean.

## is\_mp4($filepath)

### Purpose

Determine whether file is an mp4 file.

### Parameters

- $filepath

    File to analyse.

    Required. Method dies if $filepath is not provided or is invalid.

### Prints

Nil.

### Returns

Scalar boolean.

## is\_perl($filepath)

### Purpose

Determine whether file is a perl file.

### Parameters

- $filepath

    File to analyse.

    Required. Method dies if $filepath is not provided or is invalid.

### Prints

Nil.

### Returns

Scalar boolean.

## join\_dir($dir)

### Purpose

Concatenate list of directories in path to string path.

### Parameters

- $dir

    Directory parts. Array reference.

    Required.

### Prints

Nil.

### Returns

Scalar string directory path. (Dies on error.

## kde\_desktop( )

### Purpose

Determine whether the KDE desktop is running.

### Parameters

Nil

### Prints

Nil.

### Returns

Boolean scalar.

## konsolekalendar\_date\_format(\[$date\])

### Purpose

Get date formatted in same manner as konsolekalendar does in its output. An example date value is 'Tues, 15 Apr 2008'. The corresponding strftime format string is '%a, %e %b %Y'.

### Parameters

- $date

    Date to convert. Must be in ISO format.

    Optional, Default: today.

### Prints

Nil.

### Returns

Scalar date string.

## kill\_process($pid)

### Purpose

Kill a specified process.

### Parameters

- $pid

    Id of process to kill.

    Required.

### Prints

Nil, except error messages.

### Returns

List ($success, $error\_message).

## listify(@items)

### Purpose

Tries to convert scalar, array and hash references in list to sequences of simple scalars. For other reference types a warning is issued.

### Parameters

- @items

    Items to convert to simple list.

### Prints

Warning messages for references other than scalar, array and hash.

### Returns

Simple list.

## local\_timezone( )

### Purpose

Get local timezone.

### Parameters

Nil.

### Prints

Nil.

### Returns

Scalar string.

## logger($message, \[$type\])

### Purpose

Display message in system log.

There are four message types: 'debug', 'notice', 'warning' and 'error'. Not all message types appear in all system logs. On Debian, for example, /var/log/messages records only notice and warning log messages while /var/log/syslog records all log messages.

Method dies if invalid message type is provided.

### Parameters

- $message

    Message content.

    Required.

- $type

    Type of log message. Must be one of 'debug', 'notice', 'warning' and 'error'.

    Method dies if invalid message type is provided.

    Optional. Default: 'notice'.

### Prints

Nil.

### Returns

Nil. Note method dies if invalid message type is provided.

### Usage

    $cp->logger('Widget started');
    $cp->logger( 'Widget died unexpectedly!', 'error' );

## make\_dir($dir\_path)

### Purpose

Make directory recursively.

### Parameters

- $dir\_path

    Directory path to create.

    Required.

### Prints

Nil.

### Return

Scalar boolean. If directory already exists returns true.

## moox\_option\_bool\_is\_true($value)

### Purpose

Determine whether a boolean MooX::Option is true.

A simple truth check on such a value does not work because MooX::Option's false value, an empty array reference, evaluates in perl as true.

### Parameters

- $value

    Option value.

    Required.

### Prints

Nil, except error message on failure.

### Returns

N/A, dies on failure.

## msg\_box(\[$msg\], \[$title\])

### Purpose

Display message in gui message box.

### Parameters

- $msg

    Message to display.

    Optional. Default: 'Press OK button to proceed'.

- $title

    Title of message box.

    Optional. Default: name of calling script.

### Prints

Nil.

### Returns

N/A.

## notify(@messages, \[$prepend\])

### Purpose

Display console message.

### Parameters

- @messages

    Message lines. Respects newlines if enclosed in double quotes.

    Required.

- $prepend

    Whether to prepend each message line with name of calling script.

    Named parameter. Boolean.

    Optional. Default: false.

### Prints

Messages.

### Returns

Nil.

### Usage

    $cp->notify('File path is:', $filepath);
    $cp->notify('File path is:', $filepath, prepend => $TRUE);

## notify\_sys\_type($type)

## notify\_sys\_title($title)

## notify\_sys\_icon\_path($icon)

### Purpose

Set default values for `notify_sys` method parameters `type`, `title` and `icon`, respectively. Applies to subsequent calls to `notify_sys`. Overridden by parameters supplied in subsequent `notify_sys` method calls.

## notify\_sys($message, \[$title\], \[$type\], \[$icon\], \[$time\])

### Purpose

Display message to user in system notification area

### Parameters

- $message

    Message content.

    Note there is no guarantee that newlines in message content will be respected.

    Required.

- $title

    Message title.

    Named parameter. Optional. Defaults to attribute `notify_sys_title` if available, otherwise to name of calling script.

- $type

    Type of message. Must be one of 'info', 'question', 'warn' and 'error'.

    Named parameter. Optional. Defaults to attribute `notify_sys_type` if available, otherwise to 'info'.

- $icon

    Message box icon filepath.

    Named parameter. Optional. Defaults to attribute `notify_sys_icon_path` if available, otherwise to a default icon provided for each message type.

- $time

    Message display time (msec).

    Named parameter. Optional. Default: 10,000.

### Prints

Nil.

### Returns

Boolean: whether able to display notification.

### Usage

    $cp->notify_sys('Operation successful!', title => 'Outcome')

### Caution

Do not call this method from a spawned child process -- the 'show()' call in the last line of this method causes the child process to hang without any feedback to user.

## now( )

### Purpose

Provide current time in format 'HH::MM::SS'.

### Parameters

Nil.

### Prints

Nil.

### Returns

Scalar string.

## number\_list(@items)

### Purpose

Prefix each list item with element index. The index base is 1.

The prefix is left padded with spaces so each is the same length.

Example: 'Item' becomes ' 9. Item'.

### Parameters

- @items

    List to be modified.

    Required.

### Prints

Nil.

### Returns

List.

## offset\_date($offset)

### Purpose

Get a date offset from today. The offset can be positive or negative.

### Parameters

- $offset

    Offset in days. Can be positive or negative.

    Required.

### Prints

Nil.

### Returns

ISO-formatted date.

## pager($lines, \[$prefer\])

### Purpose

Display list of lines in terminal using pager. Unless a preferred pager is provided the pager used is determined by `IO::Pager`.

It does not matter whether or not the lines have terminal newlines or not.

This method is often used with method 'do\_wrap' to format screen display.

### Parameters

- $lines

    Content to display. Array reference.

    Required.

- $prefer

    Preferred pager. It is used if available.

    Optional. No default, i.e., normally follows [IO::Pager](https://metacpan.org/pod/IO::Pager) algorithm.

### Prints

Provided content, each line begins on a new line and is intelligently wrapped.

The content is paged. See [IO::Pager](https://metacpan.org/pod/IO::Pager) for details on the algorithm used to determine the pager used.

### Return

N/A.

## parent\_dir($dir)

### Purpose

Get parent directory of a directory path.

Whether the provided directory path is absolute or relative, the returned parent directory path is absolute.

### Parameters

- $dir

    Directory path to analyse. May be relative or absolute.

    Required.

### Prints

Nil.

### Returns

Scalar (absolute directory path).

## path\_split($path)

### Purpose

Split directory or file path into component parts.

### Parameters

- $path

    Directory or file path to split. Need not exist.

    Required.

### Prints

Nil.

### Returns

List.

## pid\_command($pid)

### Purpose

Get command for a specified process id.

### Parameters

- $pid

    Process id for which to obtain command.

    Required.

### Prints

Nil, except error messages.

### Returns

Scalar string (process command).

## pid\_running($pid)

### Purpose

Determines whether process id is running.

Note that the process table is reloaded each time this method is called, so it can be called repeatedly in dynamic situations where processes are starting and stopping.

### Parameters

- $pid

    Process ID to search for.

    Required.

### Prints

Nil.

### Returns

Boolean scalar.

## pluralise($string, $number)

### Purpose

Adjust string based on provided numerical value. Note that this method is a simple wrapper of [Text::Pluralize::pluralize](https://metacpan.org/pod/Text::Pluralise#pluralize).

### Parameters

- $string

    String to adjust based on the numeric value provided.

    Required.

- $number

    Numeric value used in adjusting the string provided. Must be a positive integer (including zero).

    Required.

### Prints

Nil.

### Returns

Scalar string.

## process\_children($pid)

### Purpose

Get child processes of a specified pid.

### Parameters

- $pid

    PID to analyse.

    Required.

### Prints

Nil, except error messages.

### Returns

List of pids.

## process\_ids($cmd\_re, \[$silent\])

### Purpose

Get pids for process command.

### Parameters

- $cmd\_re

    Value to match against process commands in ps output. Regular expression.

    Required.

- $silent

    Whether to suppress warnings. Note: by default warnings are issued if there is no match or there are multiple matches found.

    Named parameter. Optional. Default: false.

### Prints

Warning messages if other than a single matching pid found.

### Returns

List of scalar integers (pids).

## process\_parent($pid)

### Purpose

Get parent process of a specified pid.

### Parameters

- $pid

    PID to analyse.

    Required.

### Prints

Nil, except error messages.

### Returns

Scalar integer (PID).

## process\_running($regex)

### Purpose

Determines whether process is running. Matches on process command.

Note that the process table is reloaded each time this method is called, so it can be called repeatedly in dynamic situations where processes are starting and stopping.

### Parameters

- $regex

    Regular expression to match to command in `ps aux` output.

    Required.

### Prints

Nil.

### Returns

Boolean scalar.

## prompt(\[message\])

### Purpose

Display message and prompt user to press any key.

### Parameters

- Message

    Message to display.

    Optional. Default: 'Press any key to continue...'.

### Prints

Message.

### Returns

Nil.

## push\_arrayref($arrayref, @items)

### Purpose

Add items to array reference.

### Parameters

- $arrayref

    Array reference to add to.

    Required.

- @items

    Items to add to array reference.

    Required.

### Prints

Nil, except error messages.

### Returns

Array reference. (Method dies on failure.)

## restore\_screensaver(\[$title\])

### Purpose

Restore suspended screensaver. Currently handles xscreensaver and kde screensaver.

As a result of the method used to suspend the kde screensaver, it can only be restored by the same process that suspended it (see method 'suspend\_screensaver'), or when that process exits.

### Parameters

- $title

    Message box title. Note that feedback is given in a popup notification (see method `notify_sys`).

    Optional. Default: name of calling script.

### Prints

User feedback indicating success or failure.

### Returns

Boolean. Whether able to successfully suspend the screensaver.

Note that if none of the supported screensavers is detected, the return value is true, i.e., it is presumed there is no screensaver.

## retrieve\_store($file)

### Purpose

Retrieves function data from storage file.

### Parameters

- $file

    File in which data is stored.

    Required.

### Prints

Nil (except feedback from Storage module).

### Returns

Reference to stored data structure.

### Usage

    my $storage_file = '/path/to/filename';
    my $ref = $self->retrieve_store($storage_file);
    my %data = %{$ref};

## run\_command\_silent($silent)

## run\_command\_fatal($fatal)

### Purpose

Set default values for `run_command` method parameters `silent` and `fatal`, respectively. Applies to subsequent calls to `run_command`. Overridden by parameters supplied in subsequent `run_command` method calls.

## run\_command($cmd, \[$silent\], \[$fatal\])

### Purpose

Run a system command.

The default behaviour is to display the command, shell feedback between horizontal dividers and, if the command failed, an error message.

Note that shell feedback is displayed only after command execution completes -- for a long-running command this can result in an apparently unresponsive terminal.

### Parameters

- $cmd

    Command to run. Array reference.

    Required.

- $silent

    Suppress output of command feedback. If the command fails and 'fatal' is enabled, a traceback is displayed. Boolean.

    Named parameter. Optional. Defaults to attribute `run_command_silent` if defined, otherwise to false.

- $fatal

    Whether to halt script execution if the command fails. Boolean.

    Named parameter. Optional. Defaults to attribute `run_command_fatal` if defined, otherwise to false.

### Prints

Command to be executed, shell output and, if the command failed, an error message. This output can be suppressed by 'silent'. Note that even if 'silent' is selected, if the command fails while 'fatal' is set, an error traceback is displayed.

### Returns

In scalar context: boolean.

In list context: boolean, error message.

## save\_store($ref, $file)

### Purpose

Store data structure in file.

### Parameters

- $ref

    Reference to data structure (usually hash or array) to be stored.

- $file

    File path in which to store data.

### Prints

Nil (except feedback from Storable module).

### Returns

Boolean.

### Usage

    my $storage_dir = '/path/to/filename';
    $self->save_store( \%data, $storage_file );

## scriptname( )

### Purpose

Get name of executing script.

### Parameters

Nil.

### Prints

Nil.

### Returns

Scalar string.

## sequential\_24h\_times($time1, $time2)

### Purpose

Determine whether supplied times are in chronological sequence, i.e., second time occurs after first time. Assume both times are from the same day.

### Parameters

- $time1

    First time to compare. 24 hour time format.

    Required.

- $time2

    Second time to compare. 24 hour time format.

    Required.

### Prints

Nil. (Error if invalid time.)

### Returns

Boolean (Dies if invalid time.)

## sequential\_dates($date1, $date2)

### Purpose

Determine whether supplied dates are in chronological sequence.

Both dates must be in ISO format or method will return failure. It is recommended that date formats be checked before calling this method.

### Parameters

- $date1

    First date. ISO format.

    Required.

- $date2

    Second date. ISO format.

    Required.

### Prints

Nil. Error message if dates not in ISO-format.

### Returns

Boolean.

## shared\_module\_file\_milla($dist, $file)

### Purpose

Obtains the path to a file in a module's shared directory. Assumes the module was built using dist-milla and the target file was in the build tree's 'share' directory.

Converts the filepath to a url using the file:// protocol. For example, `/path/to/file` converts to `file:///path/to/file`.

### Parameters

- $dist

    Module name. Uses "dash" format. For example, module My::Module would be `My-Module`.

    Required.

- $file

    Name of file to search for.

    Required.

### Prints

Nil.

### Returns

Scalar. (If not found returns undef, so can also function as scalar boolean.)

## shell\_underline($string)

### Purpose

Underline string using shell escapes.

### Parameters

- $string

    String to underline. Scalar string.

    Required.

### Prints

Nil.

### Returns

Scalar string: string with enclosing shell commands.

## shorten($string, \[$limit\], \[$cont\])

### Purpose

Truncate text with ellipsis if too long.

### Parameters

- $string

    String to shorten.

    Required.

- $length

    Length at which to truncate. Must be integer > 10.

    Optional. Default: 72.

- $cont

    Continuation sequence placed at end of truncated string to indicate shortening. Cannot be longer than three characters.

    Optional. Default: '...'.

### Prints

Nil.

### Returns

Scalar string.

## suspend\_screensaver(\[$title\], \[$msg\])

### Purpose

Suspend screensaver. Currently handles xscreensaver and kde screensaver.

As a result of the method used to suspend and restore the kde screensaver, it can only be restored by the same process that suspended it (see method 'restore\_screensaver'), or when that process exits.

### Parameters

- $title

    Message box title. Note that feedback is given in a popup notification (see method `notify_sys`).

    Optional. Default: name of calling script.

- $msg

    Message explaining suspend request. It is passed to the screensaver object and is not seen by the user.

    Named parameter.

    Optional. Default: 'request from $PID'.

### Prints

User feedback indicating success or failure.

### Returns

Boolean. Whether able to successfully suspend the screensaver.

### Usage

    $cp->suspend_screensaver('Playing movie');
    $cp->suspend_screensaver(
        'Playing movie', msg => 'requested by my-movie-player'
    );

## tabify($string, \[$tab\_size\])

### Purpose

Covert tab markers ('\\t') in string to spaces. Default tab size is four spaces.

### Parameters

- $string

    String in which to convert tabs.

    Required.

- $tab\_size

    Number of spaces in each tab. Integer.

    Optional. Default: 4.

### Prints

Nil.

### Returns

Scalar string.

## temp\_dir( )

### Purpose

Create a temporary directory.

### Parameters

Nil.

### Prints

Nil.

### Returns

Scalar directory path.

## term\_size( )

### Purpose

Get dimensions of current terminal.

### Parameters

Nil.

### Prints

Nil.

### Returns

A Dn::Common::TermSize object.

### Usage

    my $height = $cp->term_size->height;
    my $width = $cp->term_size->width;

    my $ts = $cp->term_size;
    my ( $height, $width ) = ( $ts->height, $ts->width );

## timezone\_from\_offset($offset)

### Purpose

Determine timezone for offset. In most cases an offset matches multiple timezones. The first matching Australian timezone is selected if one is present, otherwise the first matching timezone is selected.

### Parameters

- $offset

    Timezone offset to check. Example: '+0930'.

    Required.

### Prints

Error message if no offset provided or no matching timezone found.

### Returns

Scalar string (timezone), undef if no match found.

## today( )

### Purpose

Get today as an ISO-formatted date.

### Parameters

Nil.

### Prints

Nil.

### Returns

ISO-formatted date.

## tools\_available(@tools)

### Purpose

Check that required executables are available on system.

### Parameters

- @tools

    Required executables. List.

    Optional.

### Prints

Message to stderr if any tools not available, otherwise nil.

### Returns

Scalar boolean.

### Usage

    if ( not $cp->tools_available( 'tar', 'gzip' ) ) { return; }

### Note

The error message looks like:

    Required executable is not available: not-here

or

    Required executables are not available: not-here, me-either

## trim($string)

### Purpose

Remove leading and trailing whitespace.

### Parameters

- $string

    String to be converted.

    Required.

### Prints

Nil.

### Returns

Scalar string.

## true\_path($filepath)

### Purpose

Converts relative to absolute filepaths. Any filepath can be provided to this method -- if an absolute filepath is provided it is returned unchanged. Symlinks will be followed and converted to their true filepaths.

If the directory part of the filepath does not exist the entire filepath is returned unchanged. This is a compromise. There may be times when you want to normalise a non-existent path, i.e, to collapse '../' parent directories. The 'abs\_path' function can handle a filepath with a nonexistent file. Unfortunately, however, it will silently return an empty result if an invalid directory is included in the path. Since safety should always take priority, the method will return the supplied filepath unchanged if the directory part does not exist.

WARNING: If passing a variable to this function it should be double quoted. If not, passing a value like './' results in an error as the value is somehow reduced to an empty value.

### Parameters

- $filepath

    Path to analyse. If a variable should be double quoted (see above).

    Required.

### Prints

Nil

### Returns

Scalar filepath.

## valid\_24h\_time($time)

### Purpose

Determine whether supplied time is valid.

### Parameters

- $time

    Time to evaluate. Must be in 'HH:MM' format (leading zero can be dropped) or 'HHMM' format (cannot drop leading zero).

    Required.

### Prints

Nil.

### Returns

Boolean.

## valid\_date($date)

### Purpose

Determine whether date is valid and in ISO format.

### Parameters

- $date

    Candidate date.

    Required.

### Prints

Nil.

### Returns

Boolean.

## valid\_email($email)

### Purpose

Determine validity of an email address.

### Parameters

- $email

    Email address to validate.

    Required.

### Prints

Nil.

### Return

Scalar boolean.

## valid\_integer($value)

### Purpose

Determine whether supplied value is a valid integer.

### Parameters

- $value

    Value to test.

    Required.

### Prints

Nil.

### Returns

Boolean.

## valid\_positive\_integer($value)

### Purpose

Determine whether supplied value is a valid positive integer (zero or above).

### Parameters

- $value

    Value to test.

    Required.

### Prints

Nil.

### Returns

Boolean.

## valid\_timezone\_offset($offset)

### Purpose

Determine whether a timezone offset is valid.

### Parameters

- $offset

    Timezone offset to analyse. Example: '+0930'.

    Required.

### Prints

Nil.

### Returns

Scalar boolean.

## valid\_web\_url($url)

### Purpose

Determine validity of a web url.

### Parameters

- $url

    Web address to validate.

    Required.

### Prints

Nil.

### Return

Scalar boolean.

## vim\_list\_print(@messages)

### Purpose

Prints a list of strings to the terminal screen using vim's default colour scheme.

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

### Parameters

- @messages

    Each element of the list can be printed in a different style. Element strings need to be prepared using the 'vim\_printify' method. See the 'vim\_printify' method for an example.

    Required.

### Prints

Messages in requested styles.

### Returns

Nil.

## vim\_print($type, @messages)

### Purpose

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

### Parameters

- $type

    Type of text. Determines colour scheme.

    Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

    Required.

- @messages

    Content to display.

    Supplied strings can contain escaped double quotes.

    Required.

### Prints

Messages in the requested colour scheme.

### Returns

Nil.

### Usage

    $cp->vim_print( 't', 'This is a title' );

## vim\_printify($type, $message)

### Purpose

Modifies a single string to be included in a List to be passed to the 'vim\_list\_print' method. The string is given a prefix that signals to 'vim\_list\_print' what format to use. The prefix is stripped before the string is printed.

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

### Parameters

- $type

    Type of text. Determines colour scheme.

    Must be one of: 'title', 'error', 'warning', 'prompt' and 'normal'. Case-insensitive. Can supply a partial value, down to and including just the first letter.

    Required.

- $message

    Content to modify.

    Supplied string can contain escaped double quotes.

    Required.

### Prints

Nil.

### Returns

Modified string.

### Usage

    $cp->vim_printify( 't', 'This is a title' );

## write\_file($file, $content, \[$silent\], \[$fatal\], \[$no\_newline\])

### Purpose

Write provided content to a file.

### Parameters

- $file

    Path of file to create.

    Required.

- $content

    Content to write to file. Scalar or array reference.

    Required.

- $silent

    Whether to suppress feedback.

    Named parameter. Optional. Default: false.

- $fatal

    Whether to die on write failure.

    Named parameter. Optional. Default: false.

- $no\_newline

    Whether to not add a terminal newline where missing.

    Named parameter. Optional. Default: false.

### Prints

Feedback:

> - if write operation is successful
>
>         "Wrote file '$file'"
>
> - if write operation fails
>
>         "Unable to write '$file'"

### Returns

Boolean success.

### Note

If $fatal is set to true and the write operation fails, an error message is provided regardless of the value of $silent.

## yesno($question, \[$title\])

### Purpose

Ask yes/no question in gui dialog.

Note that aborting the dialog (by pressing Escape) has the same effect as selecting 'No' -- returning false.

### Parameters

- $question

    Question to be answered. Is displayed unaltered, i.e., include terminal question mark.

    Required.

- $title

    Dialog title.

    Optional. Default: script name.

### Prints

Nil.

### Returns

Scalar boolean.

# DEPENDENCIES

## Perl modules

Carp, Config::Simple, Curses, Cwd, Data::Dumper::Simple, Data::Structure::Util, Data::Validate::URI, Date::Simple, DateTime, DateTime::Format::Mail, DateTime::TimeZone, Desktop::Detect, Dn::Common::CommandResult, Dn::Common::TermSize, Dn::Common::Types, Email::Valid, English, Env, experimental, File::Basename, File::chdir, File::Copy, File::Copy::Recursive, File::Find::Rule, File::MimeInfo, File::Path, File::Spec, File::Temp, File::Util, File::Which, Function::Parameters, HTML::Entities, IO::Pager, IPC::Cmd, IPC::Open3, IPC::Run, List::MoreUtils, Logger::Syslog, namespace::clean, Moo, MooX::HandlesVia, Net::DBus, Net::Ping::External, Proc::ProcessTable, Readonly, Scalar::Util, Storable, strictures, Term::ANSIColor, Term::Clui, Term::ReadKey, Test::NeedsDisplay, Text::Pluralize, Text::Wrap, Time::HiRes, Time::Simple, Type::Utils, Types::Path::Tiny, Types::Standard, UI::Dialog, version.

## Utilities

adb | fb-adb, autoconf, echo, fuser, su, sudo.

## Debian packaging

Two of the modules that Dn::Common depends on are not available from the standard debian repository: `Text::Pluralize` and `Time::Simple`. Debian packages for these modules, `libtext-pluralize-perl` and `libtime-simple-perl` respectively, are available from the same provider of the debian package for this module, `libdn-common-perl`.

# BUGS AND LIMITATIONS

Report to module author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer <davidnebauer@hotkey.net.au>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
