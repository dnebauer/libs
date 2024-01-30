package Dn::Cards;

use Moo;
use strictures 2;
use 5.006;
use 5.22.1;
use version; our $VERSION = qv('0.1');
use namespace::clean;

1;

# POD                                                                  {{{1

__END__

=encoding utf8

=head1 NAME

Dn::Cards - a library to aid in using images for game card production

=head1 SYNOPSIS

    use Dn::Cards;
    ...

=head1 DESCRIPTION

A collection of modules and scripts used to aid in processing images for use in
making game cards. The library was designed with a specific use case in mind:
preparing image files for upload to L<Printer's
Studio|http://www.printerstudio.com/unique-ideas/blank-playing-cards.html> for
manufacturing custom game cards.

This library contains the following primary modules: Dn::Cards,
Dn::Cards::ExtractPdfPages, Dn::Cards::Resize, Dn::Cards::UniquefyImages and
Dn::Cards::ExtractImages. Three of these modules have submodules.

This library contains the following scripts: dn-cards-images-extract,
dn-cards-pdf-extract, dn-cards-resize and dn-cards-uniquefy.

See individual man pages for further details.

Although this library was designed with a specific use case in mind, the
scripts and, in particular, the modules, were designed to have as wide an
application as possible.

=head1 ATTRIBUTES

None are provided.

=head1 METHODS

None are provided.

=head1 CONFIGURATION AND ENVIRONMENT

There are no configuration files used. There are no module/role settings.

=head1 DEPENDENCIES

=head2 Perl modules

Moo, namespace::clean, strictures, version.

=head2 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2017 David Nebauer (david at nebauer dot org)

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:fdm=marker
