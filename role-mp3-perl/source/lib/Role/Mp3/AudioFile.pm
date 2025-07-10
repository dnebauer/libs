package App::Dn::Mp3Rename::AudioFile;

# use modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean;
use autodie qw(open close);
use Carp    qw(croak);
use Const::Fast;
use English;
use MP3::Info;
use Types::Path::Tiny qw(AbsFile);
use Types::Standard;

with qw(
    App::Dn::Mp3Rename::Role
    Role::Utils::Dn
);

const my $TRUE  => 1;
const my $FALSE => 0;    # }}}1

# attributes

# filepath    {{{1
has 'filepath' => (
  is       => 'ro',
  isa      => AbsFile,
  required => $TRUE,
  coerce   => AbsFile->coercion,
  doc      => 'File path of audio track',
);

# tags    {{{1
has 'tags' => (
  is      => 'ro',
  isa     => Types::Standard::InstanceOf ['MP3::Info'],
  lazy    => $TRUE,
  default => sub {
    my $self     = shift;
    my $filename = $self->filepath->canonpath;
    return MP3::Info->new($filename);
  },
  doc => 'MP3::Info object for mp3 audio file',
);

# title    {{{1
has 'title' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self  = shift;
    my $title = $self->tags->title;
    my $ascii = $self->_make_ascii($title);
    return $self->_simplify($ascii);
  },
  doc => 'Track title',
);

# artist    {{{1
has 'artist' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self   = shift;
    my $artist = $self->tags->artist;
    my $ascii  = $self->_make_ascii($artist);
    return $self->_simplify($ascii);
  },
  doc => 'Track artist',
);

# album    {{{1
has 'album' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self  = shift;
    my $album = $self->tags->album;
    my $ascii = $self->_make_ascii($album);
    return $self->_simplify($ascii);
  },
  doc => 'Track album',
);

# year    {{{1
has 'year' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;
    my $year = $self->tags->year;
    return $self->_make_ascii($year);
  },
  doc => 'Track year',
);

# number    {{{1
has 'number' => (
  is      => 'ro',
  isa     => Types::Standard::Int,
  lazy    => $TRUE,
  default => sub {
    my $self       = shift;
    my $tag_number = $self->_make_ascii($self->tags->tracknum);
    my $filename   = $self->filepath->canonpath;

    # assume format is either 'NUM' or 'NUM/TOTAL'
    my $number;
    if ($tag_number =~ /\A(\d+)/xsm) { $number = $1; }
    else { croak "No valid track number in file '$filename'"; }

    return $number;
  },
  doc => 'Track number',
);

# disk    {{{1
has 'disk' => (
  is      => 'ro',
  isa     => Types::Standard::Int,
  lazy    => $TRUE,
  default => sub {
    my $self     = shift;
    my $filename = $self->filepath->canonpath;

    # MP3::Info object does not have a direct method for disc number
    # must use a class function to derive tag hash
    my ($TAG_VERSION, $RAW_V2) = (undef, 2);
    my $tags = MP3::Info::get_mp3tag($filename, $TAG_VERSION, $RAW_V2);
    my $tag_disk;
    ## no critic (ProhibitDuplicateLiteral)
    if   (exists $tags->{'TPOS'}) { $tag_disk = $tags->{'TPOS'}; }
    else                          { $tag_disk = 1; }
    ## use critic

    # assume format is either 'NUM' or 'NUM/TOTAL'
    my $disk;
    if   ($tag_disk =~ /\A(\d+)/xsm) { $disk = $1; }
    else                             { $disk = 1; }

    return $disk;
  },
  doc => 'Disk number',
);    # }}}1

# methods

# initialise()    {{{1
#
# does:   ensure all tags are extracted and all attributes are set
#         - can be used to ensure all tags are extracted from a file at
#           once (to avoid multiple disk operations)
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub initialise ($self) {    ## no critic (RequireInterpolationOfMetachars)

  $self->title;
  $self->artist;
  $self->album;
  $self->year;
  $self->number;
  $self->disk;

  return;
}

# new_filename($format, $num_width, $disk_width)    {{{1
#
# does:   derive new filename using a format template with
#         these possible placeholders:
#         %t = title
#         %a = artist
#         %l = album
#         %y = year
#         %n = number
#         %d = disk
# params: $format     - format template [scalar string, required
#         $num_width  - width of track number [scalar integer, required]
#         $disl_width - width of disk number [scalar integer, required]
# prints: feedback
# return: n/a, die on failure
sub new_filename ($self, $format, $num_width, $disk_width)
{    ## no critic (RequireInterpolationOfMetachars, ProhibitManyArgs)

  # mp3 files commonly have no disk number
  my $disk_num = $self->disk;
  my $disk =
      ($disk_num and $disk_width)
      ? $self->pad($disk_num, $disk_width)
      : 1;
  my %placeholders = (
    t => $self->title,
    a => $self->artist,
    l => $self->album,
    y => $self->year,
    n => $self->pad($self->number, $num_width),
    d => $disk,
  );

  # start with format template
  my $basename = $format;

  # replace placeholders
  #while (my ($char, $value) = each %placeholders) {
  for my $char (keys %placeholders) {
    my $value       = $placeholders{$char};
    my $placeholder = q{%} . $char;
    $basename =~ s/$placeholder/$value/gxsm;
  }

  # add extension
  my $ext      = '.mp3';
  my $filename = $basename . $ext;

  return $filename;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::Mp3Rename::AudioFile - mp3 file properties

=head1 VERSION

This documentation refers to dn-mp3file-rename version 0.5.

=head1 SYNOPSIS

      my $audiofile = App::Dn::Mp3Rename::AudioFile->new(filepath => $file);
      $audiofile->initialise;

=head1 DESCRIPTION

This is a helper module for L<App::Dn::Mp3Rename>.
It models some properties and behaviours of an mp3 audio file.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Properties

=head3 filepath

File path of audio track. Required.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 initialise()

=head3 Purpose

Ensure all tags are extracted and all attributes are set. It can be used to
ensure all tags are extracted from a file at once (to avoid multiple disk
operations).

=head3 Parameters

None.

=head3 Returns

Void.

=head2 new_filename($format, $num_width, $disk_width)

=head3 Purpose

Derive a new filename using a format template with placeholders as described in
L<App::Dn::Mp3Rename/DESCRIPTION>.

=head3 Parameters

=over

=item $format

Format template. Scalar string. Required.

=item $num_width

Width of track number. Scalar integer. Required.

=item $disk_width

Width of disk number. Scalar integer. Required.

=back

=head3 Prints

Feedback.

=head3 Returns

Void.

=head2 album(), artist(), disk(), number(), title(), year()

=head3 Purpose

Return an mp3 file tag value: track album, track artist, disk number,
track number, track title, and track year, respectively.

=head3 Parameters

None.

=head3 Prints

Nothing.

=head3 Returns

Scalar string. The value for track album, track artist, disk number,
track number, track title, and track year, respectively.

=head1 DIAGNOSTICS

=head2 No valid track number in file 'FILE'

The audio mp3 track number tag is empty or does not contain a valid track
number. A valid track number is either:

=over

=item *

a single positive non-zero integer, e.g., '6', or

=item *

two positive non-zero integers separated by a slash, e.g., '6/10'.

=back

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

App::Dn::Mp3Rename::Role, autodie, Carp, Const::Fast, English, MP3::Info, Moo,
namespace::clean, Role::Utils::Dn, strictures, Types::Path::Tiny,
Types::Standard, version.

=head1 AUTHOR

David Nebauer (david at nebauer dot org)

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
