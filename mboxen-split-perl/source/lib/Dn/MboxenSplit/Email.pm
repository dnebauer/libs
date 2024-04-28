package Dn::MboxenSplit::Email;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.2');
use namespace::clean;

use Const::Fast;
use File::Spec;
use Types::Standard;

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# attributes

# content    {{{1
has 'content' => (
  is       => 'ro',
  isa      => Types::Standard::ScalarRef,
  required => $TRUE,
  doc      => 'Email from Mail::Mbox::MessageParser (scalar ref)',
);

# file_dir    {{{1
has 'file_dir' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Directory for email file',
);

# file_name    {{{1
has 'file_name' => (
  is       => 'ro',
  isa      => Types::Standard::Str,
  required => $TRUE,
  doc      => 'Name of email file',
);

# file_write    {{{1
has 'file_write' => (
  is      => 'rw',
  isa     => Types::Standard::Bool,
  default => $FALSE,
  doc     => 'Whether to write the email file',
);    # }}}1

# methods

# file_path()    {{{1
#
# does:   provide output filepath
#
# params: nil
# prints: error message on failure
# return: scalar string, file path
sub file_path ($self) {    ## no critic (RequireInterpolationOfMetachars)
  return File::Spec->catfile($self->file_dir, $self->file_name);
}                          # }}}1

1;

# POD    {{{1
__END__

=head1 NAME

Dn::MboxenSplit::Email - information about an email

=head1 VERSION

This documentation applies to module Dn::MboxenSplit::Email version 0.2.

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

Intended to hold the return value from
S<< C<Mail::Mbox::MessageParser->read_next_email()> >>.
This is not just the email body but the entire email content,
including headers.

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

=head1 SUBROUTINES/METHODS

=head2 file_path()

=head3 Purpose

Provide output file path.

=head3 Returns

Scalar string. Output file path.

=head1 DIAGNOSTICS

This module emits no custom warnings or errors.

=head1 CONFIGURATION AND ENVIRONMENT

This module does not rely on any configuration files or environmental
variables.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 DEPENDENCIES

=head2 Perl modules

Const::Fast, File::Spec, Moo, namespace::clean, strictures, Types::Standard,
version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2016 David Nebauer E<lt>david@nebauer.orgE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim:fdm=marker
