package Dn::Common::TermSize;

use 5.014_002;
use Moo;
use strictures 2;
use version; our $VERSION = qv('0.1');
use namespace::clean;
use Curses;
use Function::Parameters;
use Readonly;
use Types::Standard;

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;

has 'height' => (
    is            => 'lazy',
    isa           => Types::Standard::Int,
    required      => $TRUE,
    documentation => 'Terminal height',
);

method _build_height () {
    my ( $height, $width );
    my $mwh = Curses->new();
    $mwh->getmaxyx( $height, $width );
    endwin();
    return $height;
}

has 'width' => (
    is            => 'lazy',
    isa           => Types::Standard::Int,
    required      => $TRUE,
    documentation => 'Terminal width',
);

method _build_width () {
    my ( $height, $width );
    my $mwh = Curses->new();
    $mwh->getmaxyx( $height, $width );
    endwin();
    return $width;
}

1;

__END__

=head1 NAME

Dn::Common::TermSize - provide dimensions of terminal

=head1 SYNOPSIS

    use Dn::Common::TermSize;

    my $terminal_height = Dn::Common::TermSize->new()->height;

    my $ts = Dn::Common::TermSize->new();
    my $terminal_width = $ts->width();

=head1 DESCRIPTION

This module has two public attributes, C<height> and C<width>, that provide the dimensions of the current terminal.

=head1 ATTRIBUTES

=head2 height

Height of current terminal in lines.

=head2 width

Width of current terminal in characters.

=head1 CONFIGURATION AND ENVIRONMENT

Designed to be run in a terminal. Not sure what would happen if run outside a terminal...

=head1 DEPENDENCIES

=head2 Perl modules

Curses, Function::Parameters, Moo, namespace::clean, strictures, Readonly, Types::Standard, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

