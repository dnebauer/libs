# NAME

Dn::MboxenSplit - split mbox files into single mbox files perl email

# SYNOPSIS

    use Dn::MboxenSplit;
    my $mboxen = [
        'http://mail-archives.apache.org/mod_mbox/ant/201601.mbox',
        'file://home/me/.icedove/Mail/mail.isp.com/Archives',
    ];
    my $output = '/path/to/output/directory';
    my $ms = Dn::MboxenSplit->new(
        mbox_uris => $$mboxen, output_dir = $output );
    $ms->split;

# DESCRIPTION

Takes compound mbox files, extracts individual emails, and write individual mbox files for each email. This script was designed to make it easier for indexing programs such as recoll to index, search and display matching emails. The following steps are involved:

## Retrieve mbox files

The script uses [LWP::Simple](https://metacpan.org/pod/LWP::Simple) to retrieve mbox files specified with the `mbox_uris` attribute. This module can retrieve any URI, which means it can retrieve files from the internet (using the `http` protocol) and files from the local file system (using the <file> protocol). For example, the following can be included in the `mbox_uris` array reference:

    http://mail-archives.apache.org/mod_mbox/ant-notifications/201601.mbox
    file://home/me/.icedove/njd93d03.default/Mail/mail.isp.com/Archives

## Extract individual emails

The script uses [Mail::Mbox::MessageParser](https://metacpan.org/pod/Mail::Mbox::MessageParser) to read individual emails from the mailbox files. Compressed mailbox files are automatically decompressed. The module may fail with one of the following messages:

    Not a mailbox
    Can't open <filename>: <system error>
    Can't execute <uncompress command> for file <filename>

If the module fails the script dies, displaying the module error message.

## Write emails to individual mailbox files

A single output file is written to the output directory for each extracted email. The output directory is set in the `output_dir` attribute.

For each email the script attempts to construct a file name based on the email's date and sender:

    yymmdd-hhmmss-sender-subnumber.mbox

The date elements are extracted using [Date::Parse](https://metacpan.org/pod/Date::Parse). If that module fails to extract the date-time elements the 'yyymmdd-hhmmss' part of the file name is replaced by 'unparsable-date'.

The sender is extracted from the 'From' email header. More specifically, it assumes the 'From' header has the following structure:

    variable content (sender name is bracketed)

If a single pair of brackets is present at the end of the header the bracketed content is extracted, converted to ascii, stripped of non-alphabetic characters (including spaces), and truncated at 14 characters. If the header does not have this structure the sender part of the file name is replaced by 'unparsable sender'.

To the date-time and sender elements of the file name is added a subnumber. This starts at 1. The resulting file name is checked to see if it has already been constructed for an earlier email. If so it is repeatedly incremented by one and checked until an unused file name is reached, which is then used for the email.

Note that as a result of this file naming method it is possible to repeatedly save a growing mailbox to the same directory and be assured the same file names are being generated for each email.

# METHODS

## split()

### Purpose

Retrieve mbox files, extract individual emails and write them to individual mbox files in the specified output directory, as described above.

### Parameters

Nil.

# DIAGNOSTICS

- Error(s) occurred during retrieval

    (W) One or more mailbox files specified by the `mbox_uris` attribute could not be retrieved by <LWP::Simple>.

- Fatal error parsing <file>: <error>

    (F) The [Mail::Mbox::MessageParser](https://metacpan.org/pod/Mail::Mbox::MessageParser) failed to parse the named mailbox file. The error returned by the module is appended. According to the module's documentation the following errors may be generated:

        Not a mailbox
        Can't open <filename>: <system error>
        Can't execute <uncompress command> for file <filename>

- Invalid directory '<output\_dir>'

    (F) The directory specified on by the `output_dir` attribute did not pass perl directory test `-d`. Either it does not exists, or exists and is not a directory.

- No date header provided
- No email reference provided
- No from header provided
- Not a reference ('<scalar>')
- Reference is '<ref>', not 'SCALAR'

    (F) Internal errors generated when a method receives no, or unexpected, input. These errors should not occur in production code and indicate a serious problem. If you encounter one of these errors please submit a fully documented bug report.

- No email messages extracted

    (W) Mailbox files were successfully retrieved and parsed, but no email messages were extracted.

- No files retrieved
- No mailbox files retrieved

    (F) [LWP::Simple](https://metacpan.org/pod/LWP::Simple) was unable to retrieve any of the mailbox files specified by the `mbox_uris` attribute.

- No new message files to write

    (W) This warning does not occur if the `overwrite` attribute is set to true so existing files are overwritten. It occurs when email(s) are extracted and file names constructed, but all the file names already exist in the output directory.

- No uris provided

    (F) No URIs to mailbox files were provided using the `mbox_uris` attribute.

- Retrieval failed

    (W) One of the mailbox files specified by the `mbox_uris` attribute could not be retrieved by <LWP::Simple>. Is followed by the ["Error(s) occurred during retrieval"](#error-s-occurred-during-retrieval) warning documented above.

# DEPENDENCIES

## Perl modules

autodie, Carp, Date::Parse, Email::MIME, Encode, English, experimental, File::Spec, File::Temp, File::Util, Function::Parameters, LWP::Simple, Mail::Mbox::MessageParser, Moo, MooX::HandlesVia, MooX::Options, namespace::clean, Readonly, Storable, strictures, Term::Clui, Term::ProgressBar::Simple, Text::Pluralize, Text::Unidecode, Types::Standard, version.

# BUGS AND LIMITATIONS

Please report any bugs to the author.

# AUTHOR

David Nebauer <davidnebauer@hotkey.net.au>

# LICENSE AND COPYRIGHT

Copyright (c) 2016 David Nebauer <davidnebauer@hotkey.net.au>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
