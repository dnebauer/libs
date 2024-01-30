package Dn::MboxenSplit::Email;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;
use File::Spec;
use Function::Parameters;
use Readonly;
use Types::Standard;

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                          }}}1

# attributes

# content                                                              {{{1
has 'content' => (
    is            => 'ro',
    isa           => Types::Standard::ScalarRef,
    required      => $TRUE,
    documentation => 'Email from Mail::Mbox::MessageParser (scalar ref)',
);

# file_dir                                                             {{{1
has 'file_dir' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    required      => $TRUE,
    documentation => 'Directory for email file',
);

# file_name                                                            {{{1
has 'file_name' => (
    is            => 'ro',
    isa           => Types::Standard::Str,
    required      => $TRUE,
    documentation => 'Name of email file',
);

# file_write                                                           {{{1
has 'file_write' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    default       => $FALSE,
    documentation => 'Whether to write the email file',
);    #                                                                }}}1

# methods

# file_path()                                                          {{{1
#
# does:   provide output filepath
#
# params: nil
# prints: error message on failure
# return: scalar string, file path
method file_path () {
    return File::Spec->catfile( $self->file_dir, $self->file_name );
}    #                                                                 }}}1

1;

# POD                                                                  {{{1
__END__

=head1 NAME

Dn::MboxenSplit::Email - information about an email

=head1 SYNOPSIS

    use Dn::MboxenSplit::Email;
    # ...
    $self->add_email(
        Dn::MboxenSplit::Email->new(
            content   => $messageparser-reader->read_next_email,
            file_dir  => $dir,
            file_name => $name,
        );
    );

=head1 DESCRIPTION

Utility class holding useful information about an email.

=head1 ATTRIBUTES

=head2 content

Intended to hold the return value from C<<Mail::Mbox::MessageParser->read_next_email()>>. This is not just the email body but the entire email content, including headers.

Scalar reference. Read only. Required.

=head2 file_dir

Directory path of output email file.

Scalar string. Read only. Required.

=head2 file_name

Name of output email file.

Scalar string. Read only. Required.

=head2 file_write

Whether to write the output email file.

Scalar string. Read-write. Optional. Default: false.

=head1 METHODS

=head2 file_path()

=head3 Purpose

Provide output file path.

=head3 Returns

Scalar string. Output file path.

=head1 DEPENDENCIES

=head2 Perl modules

File::Spec, Function::Parameters, Moo, namespace::clean, Readonly, strictures, Types::Standard, version.

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

