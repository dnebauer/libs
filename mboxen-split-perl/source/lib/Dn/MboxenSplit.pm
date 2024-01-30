package Dn::MboxenSplit;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.014_002;
use version; our $VERSION = qv('0.1');
use namespace::clean;

use autodie qw(open close);
use Carp qw(confess);
use Date::Parse;
use Dn::InteractiveIO;
use Dn::MboxenSplit::Email;
use Email::MIME;
use Encode;
use English qw(-no_match_vars);
use File::Find::Rule;
use File::Spec;
use File::Temp;
use File::Util;
use Function::Parameters;
use LWP::Simple;
use Mail::Mbox::MessageParser;
use MooX::HandlesVia;
use MooX::Options;
use Readonly;
use Storable;
use Term::Clui;
use Term::ProgressBar::Simple;
use Text::Pluralize;
use Text::Unidecode;
use Types::Standard;
use experimental 'switch';
binmode STDOUT, ':encoding(UTF-8)';

my $io = Dn::InteractiveIO->new;
Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                          }}}1

# attributes

# mbox_uris, _mboxen                                                   {{{1
has 'mbox_uris' => (
    is            => 'ro',
    isa           => Types::Standard::ArrayRef [Types::Standard::Str],
    required      => $TRUE,
    handles_via   => 'Array',
    handles       => { _mboxen => 'elements', },
    documentation => 'Mbox file URIs',
);

# output_dir                                                           {{{1
has 'output_dir' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    required      => $TRUE,
    documentation => 'Directory in which to output mbox files',
);

# overwrite                                                            {{{1
has 'overwrite' => (
    is            => 'ro',
    isa           => Types::Standard::Bool,
    required      => $FALSE,
    default       => $FALSE,
    documentation => 'Replace/overwrite existing files',
);

# _temp_dir                                                            {{{1
has '_temp_dir' => (
    is            => 'lazy',
    isa           => Types::Standard::InstanceOf ['File::Temp::Dir'],
    documentation => 'Temporary directory for retrieved mbox files',
);

method _build__temp_dir () { return File::Temp->newdir(); }

# _add_email, _emails                                                  {{{1
has '_email_array' => (
    is  => 'rw',
    isa => Types::Standard::ArrayRef [
        Types::Standard::InstanceOf ['Dn::MboxenSplit::Email']
    ],
    lazy        => $TRUE,
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        _add_email => 'push',
        _emails    => 'elements',
    },
    documentation => 'Email messages to save',
);

# _write_count                                                         {{{1
has '_write_count' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    required      => $FALSE,
    documentation => 'Records number of files to write',
);    #                                                                }}}1

# methods

# split()                                                              {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
method split () {

    # do preliminary checks
    $self->_preliminary_checks;

    # download mbox files to temporary location
    $self->_retrieve_mboxen;

    # extract messages
    $self->_extract_messages;

    # ensure output subdirectories exist
    $self->_make_subdirectories;

    # determine which email are to be written to files
    $self->_set_emails_to_write;

    # write message files
    $self->_write_message_files;
}

# _fail($err)                                                          {{{1
#
# does:   print stack trace if interactive and exit with error status
#
# params: $err - error message [scalar string, required]
# prints: error message
# return: n/a, dies on completion
method _fail ($err) {
    if   ( $io->interactive ) { confess $err; }
    else                      { exit 1; }
}

# _preliminary_checks()                                                {{{1
#
# does:   perform preliminary checks
#
# params: nil
# prints: error message on failure
# return: n/a, dies on failure
method _preliminary_checks () {

    # output directory must exist
    my $dir = $self->output_dir;
    if ( not -d $dir ) { $io->die("Invalid directory '$dir'"); }

    return;
}

# _retrieve_mboxen()                                                   {{{1
#
# does:   retrieve mailbox files and write to temporary directory
#
# params: nil
# prints: error message on failure
# return: n/a, dies on failure
method _retrieve_mboxen () {

    # download
    my @uris = $self->_mboxen;
    if ( not @uris ) { $io->die('No uris provided'); }
    my $err        = 0;
    my $downloaded = 0;
    {                        # enable destruction of progressbar after use
        my $dir      = $self->_temp_dir->dirname;
        my $progress = Term::ProgressBar::Simple->new( scalar @uris );
        for my $uri (@uris) {
            my $file = ( File::Spec->splitpath($uri) )[2];
            my $fp = File::Spec->catfile( $dir, $file );
            $progress->message("Get $uri...");
            my $status = LWP::Simple::getstore( $uri, $fp );
            if ( LWP::Simple::is_success($status) ) {
                $downloaded++;
            }
            else {
                $io->warn("\nRetrieval failed");
                $err++;
            }
            $progress++;
        }
    }

    # deal with errors
    if ($err) {

        # display error message
        my $msg = Text::Pluralize::pluralize(
            '(Error|Errors) occurred during retrieval', $err );
        $io->warn($msg);

        # die if no files downloaded
        if ( not $downloaded ) { $io->die('No files retrieved'); }

        # have downloaded files but error(s) detected
        # if interactive check whether user wants to continue
        # if not interactive proceed anyway and hope for the best (!)
        if ( not $io->confirm('Proceed?') ) { exit; }
    }

    return;
}

# _retrieved_files()                                                   {{{1
#
# does:   gets filepaths of files in download directory
# params: nil
# prints: nil, except error messages
# return: list of file paths
method _retrieved_files () {
    my $dir   = $self->_temp_dir;
    my $opts  = { files_only => $TRUE };
    my @files = File::Util->new()->list_dir( $dir, $opts );
    my @fps   = map { File::Spec->catfile( $dir, $_ ) } @files;
    return @fps;
}

# _extract_messages()                                                  {{{1
#
# does:   extract messages from mbox files
#
# params: nil
# prints: error message on failure
# return: n/a, dies on failure
method _extract_messages () {

    # get list of mailbox files
    my @mboxes = $self->_retrieved_files;
    if ( not @mboxes ) { $io->die('No mailbox files retrieved'); }

    # read them in turn
    my $count    = scalar @mboxes;
    my $progress = Term::ProgressBar::Simple->new( scalar @mboxes );
    my $msg      = Text::Pluralize::pluralize(
        "Parsing( | $count )mailbox (file|files)...", $count );
    $progress->message($msg);
    for my $mbox (@mboxes) {
        my $mbox_file = ( File::Spec->splitpath($mbox) )[2];
        my $reader    = Mail::Mbox::MessageParser->new(
            {   file_name    => $mbox,
                enable_grep  => $TRUE,
                enable_perl  => $TRUE,
                enable_cache => $FALSE,
            }
        );
        if ( not ref $reader ) {
            $io->die("\nFatal error parsing $mbox_file: $reader");
        }
        my $fps = {};
        while ( !$reader->end_of_file ) {
            my $email = $reader->read_next_email;    # reference
                 #my $file  = $self->_email_file_name($email);
                 #$self->_add_email( $file, $email );
            my ( $dir, $name ) = $self->_email_file_path( $email, $fps );
            $self->_add_email(
                Dn::MboxenSplit::Email->new(
                    content   => $email,
                    file_dir  => $dir,
                    file_name => $name
                )
            );
            my $fp = File::Spec->catfile( $dir, $name );
            $fps->{$fp} = $TRUE;
        }
        $progress++;
    }

    # check that something was saved
    my @emails = $self->_emails;
    if ( not @emails ) { $io->die('No email messages extracted'); }

    return;
}

# _email_file_path($email_ref, $fps)                                   {{{1
#
# does:   determine file directory and name to use for email file
#
# params: $email_ref - reference to scalar email content
#                      [scalar reference, required]
#         $fps       - filepaths assigned to existing emails
#                      [hash reference, filepaths are keys, required]
# prints: error message on failure
# return: ($dir, $name);    # dies on failure
# note:   derives file dir and name from email datetime and sender
method _email_file_path ($email_ref, $fps) {

    # check param
    if ( not defined $fps ) { $self->_fail('No fps provided'); }
    if ( not $email_ref )   { $self->_fail('No email reference'); }
    if ( not ref $email_ref ) {
        $self->_fail("Not a reference ('$email_ref')");
    }
    my $ref = ref $email_ref;
    if ( $ref ne 'SCALAR' ) {
        $self->_fail("Reference is '$ref', not 'SCALAR'");
    }

    # Email::MIME strips headers from email reference
    my $copy_email_ref = Storable::dclone($email_ref);

    # get file name stem from date header
    my $email       = Email::MIME->new($copy_email_ref);
    my $date_header = Text::Unidecode::unidecode( $email->header('Date') );
    my $from_header = Text::Unidecode::unidecode( $email->header('From') );
    # - in September 2021 began getting 'No from header' errors due to
    #   no 'from' value being extracted from email with date
    #   "Fri, 1 Jan 2021 12:42:04 +0100"
    if ( not $from_header ) { $from_header = 'unknown-from-value'; }
    my ( $dir, $stem )
        = $self->_file_path_parts( $date_header, $from_header );

    # get file name
    my $name;
    my $sub_number = 1;
    while ($TRUE) {
        $name = "$stem-$sub_number.mbox";
        my $fp = File::Spec->catfile( $dir, $name );
        last if not $fps->{$fp};
        $sub_number++;
    }

    return ( $dir, $name );
}

# _file_path_parts($date_header, $from_header)                         {{{1
#
# does:   constructs file directory and name stem
#
# params: $date_header - email date header [required, scalar string]
#         $from_header - sender header [required, scalar string]
# prints: error message on failure
# return: ( $dir, $stem );    # dies on failure
method _file_path_parts ($date_header, $from_header) {

    # check param
    if ( not $from_header ) { $self->_fail('No from header'); }
    if ( not $date_header ) { $self->_fail('No date header'); }

    # get elements of file directory and name
    my ( $y, $mon, $d, $h, $min, $s ) = $self->_date_parts($date_header);
    my $from = $self->_file_name_stem_from($from_header);

    # assemble file directory
    my $dir = $self->output_dir;
    if ($y) {
        $dir = File::Spec->catdir( $dir, $y );
        if ($mon) {
            $dir = File::Spec->catdir( $dir, sprintf( '%02d', $mon ) );
        }
        else {
            $dir = File::Spec->catdir( $dir, 'month-unknown' );
        }
    }
    else {
        $dir = File::Spec->catdir( $dir, 'date-unknown' );
    }

    # assemble file name stem
    my $stem = "$y$mon$d-$h$min$s-$from";

    return ( $dir, $stem );
}

# _date_parts($date_header)                                            {{{1
#
# does:   get date parts
#
# params: $date_header - email date header [required, scalar string]
# prints: error message on failure
# return: ( $y, $mon, $d, $h, $min, $s)
# note:   year is four integers, all other return values are two integers
method _date_parts ($date_header) {

    # check param
    if ( not $date_header ) { $self->_fail('No date header'); }

    # extract date-time string components
    my ( $s, $min, $h, $d, $mon, $y ) = Date::Parse::strptime($date_header);
    if ( not defined $s ) { $s = 0; }
    for my $element ( $s, $min, $h, $d, $mon, $y ) {
        if ( not defined $element ) { return; }
    }

    # - tidy up extracted parts
    $y += 1900;
    if ( $y < 1970 ) { $y += 100; }
    $mon++;
    $mon = sprintf '%02d', $mon;
    $d   = sprintf '%02d', $d;
    $h   = sprintf '%02d', $h;
    $min = sprintf '%02d', $min;
    $s   = sprintf '%02d', $s;

    return ( $y, $mon, $d, $h, $min, $s );
}

# _file_name_stem_from($from_header)                                   {{{1
#
# does:   construct sender part of file name stem
#
# params: $from_header - sender header [required, scalar string]
# prints: error message on failure
# return: scalar string
method _file_name_stem_from ($from_header) {

    # check param
    if ( not $from_header ) { $self->_fail('No from header'); }

    # get sender part
    my $from;
    if ( $from_header =~ m{ \( ( .+ ) \) }xsm ) {
        $from = $1;                          # bracketed part
        $from =~ s{ \W }{}xsmg;              # remove non-word characters
        $from = substr $from, 0, 14;         # trim length
    }
    else {
        $from = 'unparsable-sender';
    }

    # return sender part
    return $from;
}

# _make_subdirectories()                                               {{{1
#
# does:   ensure all required output subdirectories are created
#
# params: nil
# prints: error message on failure
# return: n/a, dies on failure
method _make_subdirectories () {

    # get missing directories
    my @dirs    = map  { $_->file_dir } $self->_emails;
    my @missing = grep { not -d $_ } @dirs;

    # create missing directories
    my $opts = { if_not_exists => $TRUE };
    for my $dir (@missing) {
        if ( not File::Util->new()->make_dir( $dir, $opts ) ) {
            $io->die("Unable to create directory '$dir': $ERRNO");
        }
    }
}

# _set_emails_to_write()                                               {{{1
#
# does:   determine which emails to write to file and set write flags
#
# params: nil
# prints: error message on failure
# return: n/a, dies on failure
method _set_emails_to_write () {

    # simple if set to overwrite - write all files
    if ( $self->overwrite ) {
        my $count = 0;
        for my $email ( $self->_emails ) {
            $email->file_write($TRUE);
            $count++;
        }
        $self->_write_count($count);
        return;
    }

    # remaining case writes output file only if it does not already exist
    my %existing = map { ( $_ => $TRUE ) }
        File::Find::Rule->file()->in( $self->output_dir );
    my $count = 0;
    for my $email ( $self->_emails ) {
        my $fp = $email->file_path;
        if ( not $existing{$fp} ) {
            $email->file_write($TRUE);
            $count++;
        }
    }
    $self->_write_count($count);
    return;
}

# _write_message_files()                                               {{{1
#
# does:   write message files
#
# params: nil
# prints: error message on failure
# return: scalar boolean, success of module
method _write_message_files () {

    # check count
    my $count = $self->_write_count;
    if ( not defined $count ) { $self->_fail('No count found'); }
    if ( $count eq 0 ) {
        $io->say('No new message files to write');
        return $TRUE;
    }

    # write files
    my $progress = Term::ProgressBar::Simple->new($count);
    my $msg      = Text::Pluralize::pluralize(
        "Writing( | $count )email (file|files)...", $count );
    $progress->message($msg);
    for my $email ( $self->_emails ) {
        my $content = ${ $email->content };
        open my $fh, '>', $email->file_path;
        print {$fh} Encode::encode( 'UTF-8', $content );
        close $fh;
        $progress++;
    }

    return $TRUE;
}    #                                                                 }}}1

1;

# POD                                                                  {{{1
__END__

=head1 NAME

Dn::MboxenSplit - split mbox files into single mbox files per email

=head1 SYNOPSIS

    use Dn::MboxenSplit;
    my $mboxen = [
        'http://mail-archives.apache.org/mod_mbox/ant/201601.mbox',
        'file://home/me/.icedove/Mail/mail.isp.com/Archives',
    ];
    my $output = '/path/to/output/directory';
    my $ms = Dn::MboxenSplit->new(
        mbox_uris => $mboxen, output_dir = $output );
    $ms->split;

=head1 DESCRIPTION

Takes compound mbox files, extracts individual emails, and write individual
mbox files for each email. A subdirectory structure in the output directory
groups emails by year and date, preventing any single directory from holding
too many files.

This script was designed to make it easier for indexing programs such as recoll
to index, search and display matching emails. The following steps are involved:

=head2 Retrieve mbox files

The script uses L<LWP::Simple> to retrieve mbox files specified with the
C<mbox_uris> attribute. This module can retrieve any URI, which means it can
retrieve files from the internet (using the C<http> protocol) and files from
the local file system (using the <file> protocol). For example, the following
can be included in the C<mbox_uris> array reference:

    http://mail-archives.apache.org/mod_mbox/ant-notifications/201601.mbox
    file://home/me/.icedove/njd93d03.default/Mail/mail.isp.com/Archives

=head2 Extract individual emails

The script uses L<Mail::Mbox::MessageParser> to read individual emails from the
mailbox files. Compressed mailbox files are automatically decompressed. The
module may fail with one of the following messages:

    Not a mailbox
    Can't open <filename>: <system error>
    Can't execute <uncompress command> for file <filename>

If the module fails the script dies, displaying the module error message.

=head2 Write emails to individual mailbox files

A single output file is written to the output directory for each extracted
email. The output directory is set in the C<output_dir> attribute.

Some indexing and synchronising apps have difficulty dealing with large numbers
of files in a single directory. To prevent this happening with the output
directory, a subdirectory tree is created in it. See L</"Output directory has
subdirectory structure"> below.

For each email the script attempts to construct a file name based on the
email's date and sender:

    yymmdd-hhmmss-sender-subnumber.mbox

The date elements are extracted using L<Date::Parse>. If that module fails to
extract the date-time elements the 'yyymmdd-hhmmss' part of the file name is
replaced by 'unparsable-date'.

The sender is extracted from the 'From' email header. More specifically, it assumes the 'From' header has the following structure:

    variable content (sender name is bracketed)

If a single pair of brackets is present at the end of the header the bracketed
content is extracted, converted to ascii, stripped of non-alphabetic characters
(including spaces), and truncated at 14 characters. If the header does not have
this structure the sender part of the file name is replaced by 'unparsable
sender'.

To the date-time and sender elements of the file name is added a subnumber.
This starts at 1. The resulting file name is checked to see if it has already
been constructed for an earlier email. If so it is repeatedly incremented by
one and checked until an unused file name is reached, which is then used for
the email.

Note that as a result of this file naming method it is possible to repeatedly
save a growing mailbox to the same directory and be assured the same file names
are being generated for each email.

=head2 Output directory has subdirectory structure

As noted above, the number of files in the output directory is reduce by using
a subdirectory structure based on file year and month. Here is an example:

    output_dir
    |-- 2014
    |   |-- 01
    |   |-- 03
    |   |-- 07
    |   |-- 10
    |   `-- month-unknown
    `-- date-unknown

Particular month and year subdirectories are created only when needed, i.e., an
email was sent in that month of that year. Unneeded month and year
subdirectories are not created.

If an email has a year but no month, it is saved to a subdirectory of that year
named F<month-unknown>. If an email has no year, i.e., no date at all, it is
saved to a subdirectory of the output directory called F<date-unknown>. The
F<month-unknown> and F<year-unknown> subdirectories are only created if needed.

=head1 ATTRIBUTES

=head2 mbox_uris

Comma-separated list of URIs of mbox files to split. Note that URIs can use any
of the standard transport protocols, including C<http> for internet files and
C<file> for local filesystem files.

Scalar string. Required.

=head2 output_dir

Directory into which output files are to be written. The directory must exist.

Scalar string. Required.

=head2 overwrite

Whether to replace (overwrite) existing output files.

Boolean. Optional. Default: false.

=head1 METHODS

=head2 split()

=head3 Purpose

Retrieve mbox files, extract individual emails and write them to individual
mbox files in the specified output directory, as described above.

=head3 Parameters

Nil.

=head1 DIAGNOSTICS

=over

=item Error(s) occurred during retrieval

(W) One or more mailbox files specified by the C<mbox_uris> attribute could not
be retrieved by <LWP::Simple>.

=item Fatal error parsing <file>: <error>

(F) The L<Mail::Mbox::MessageParser> failed to parse the named mailbox file.
The error returned by the module is appended. According to the module's
documentation the following errors may be generated:

    Not a mailbox
    Can't open <filename>: <system error>
    Can't execute <uncompress command> for file <filename>

=item Invalid directory '<output_dir>'

(F) The directory specified on by the C<output_dir> attribute did not pass perl
directory test C<-d>. Either it does not exists, or exists and is not a
directory.

=item No count found

=item No date header provided

=item No email reference provided

=item No from header provided

=item Not a reference ('<scalar>')

=item Reference is '<ref>', not 'SCALAR'

(F) Internal errors generated when a method receives no, or unexpected, input.
These errors should not occur in production code and indicate a serious
problem. If you encounter one of these errors please submit a fully documented
bug report.

=item No email messages extracted

(W) Mailbox files were successfully retrieved and parsed, but no email messages
were extracted.

=item No files retrieved

=item No mailbox files retrieved

(F) L<LWP::Simple> was unable to retrieve any of the mailbox files specified by
the C<mbox_uris> attribute.

=item No new message files to write

(W) This warning does not occur if the C<overwrite> attribute is set to true so
existing files are overwritten. It occurs when email(s) are extracted and file
names constructed, but all the file names already exist in the output
directory.

=item No uris provided

(F) No URIs to mailbox files were provided using the C<mbox_uris> attribute.

=item Retrieval failed

(W) One of the mailbox files specified by the C<mbox_uris> attribute could not
be retrieved by <LWP::Simple>. Is followed by the L</"Error(s) occurred during
retrieval"> warning documented above.

=back

=head1 DEPENDENCIES

=head2 Perl modules

autodie, Carp, Date::Parse, Dn::InteractiveIO, Email::MIME, Encode, English,
experimental, File::Find::Rule, File::Spec, File::Temp, File::Util,
Function::Parameters, LWP::Simple, Mail::Mbox::MessageParser, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Readonly, Storable,
strictures, Term::Clui, Term::ProgressBar::Simple, Text::Pluralize,
Text::Unidecode, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2016 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim:fdm=marker
