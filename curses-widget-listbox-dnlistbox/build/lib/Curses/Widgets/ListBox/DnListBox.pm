# Curses::Widgets::ListBox::DnListBox.pm -- Customised List Box Widget
#
# Adapted from Curses::Widgets::ListBox::MultiColumn.pm
# (c) 2001 Arthur Corliss <corliss@digitalmages.com>
#
# Modifications (c) 2008 David Nebauer <david@nebauer.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#####################################################################

=head1 NAME

Curses::Widgets::ListBox::DnListBox - Customised List Box Widget

=head1 MODULE VERSION

# $Id: DnListBox.pm,v 1.2 2008/09/06 04:17:38 David_Nebauer Exp $

=head1 SYNOPSIS

	use Curses::Widgets::ListBox::DnListBox;

	$lb = Curses::Widgets::ListBox::DnListBox->new({});

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

=over

=item Curses

=item Curses::Widgets

=item Curses::Widgets::ListBox

=back

=head1 DESCRIPTION

Curses::Widgets::ListBox::DnListBox is an extension of the standard
Curses::Widgets::ListBox that allows the same key to be used for
TOGGLE and FOCUSSWITCH, i.e., select item and exit with same key.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::ListBox::DnListBox;

use strict;
use vars qw( $VERSION @ISA );
use Carp;
use Curses;
use Curses::Widgets;
use Curses::Widgets::ListBox;

( $VERSION ) = ( q$Revision: 1.2 $ =~ /(\d+(?:\.(\d+))+)/ );
@ISA = qw( Curses::Widgets::ListBox );

#####################################################################
#
# Module code follows
#
#####################################################################

=head1 METHODS

=head2 new ( inherited from Curses::Widgets )

	$tm = Curses::Widgets::ListBox->new( {} );

All of the same key values apply here as they do for the parent class
Curses::Widgets::ListBox.

=cut

sub _conf {
	# Validates and initialises the new ListBox object.
	#
	# Usage:  $self->_conf( %conf );

	my $self = shift;
	my %conf = ( @_ );
	my $err = 0;

	# Make sure no errors are returned by the parent method
	$err = 1 unless $self->SUPER::_conf( %conf );

	return $err == 0 ? 1 : 0;
}

=head2 execute

	$obj->execute( $mwh );

This method puts the widget into interactive mode, which consists of
calling the B<draw> method, scanning for keyboard input, feeding it
to the B<input_key> method, and redrawing.

execute uses the widget's configuration information to allow easy
modification of its behavoiur.  First, it checks for the existance of
a INPUTFUNC key.  Setting its value to a subroutine reference allows
you to substitute any custom keyboard scanning/polling routine in leiu
of the default  B<scankey> provided by this module.

The original execute method (defined in Curses::Widgets) then checked
whether to exit due to a match on FOCUSSWITCH before processing the
input key.  This effectively prevented the same key being used for
both TOGGLE and FOCUSSWITCH, i.e., one key item selection.  This version
of execute reverses that order, first processing the input key before
checking whether to exit.  If the same key is defined for both TOGGLE and
FOCUSSWITCH it is possible to select a menu item and exit using one key.

The only argument is a handle to a valid curses window object.

B<NOTE>:  If \t is in your regex, KEY_STAB will also be a trigger for a focus
switch.

=cut

sub execute {
	my $self = shift;
	my $mwh = shift;
	my $conf = $self->{CONF};
	my $func = $$conf{'INPUTFUNC'} || \&scankey;
	my $regex = $$conf{'FOCUSSWITCH'};
	my $key;

	$self->draw( $mwh, 1 );

	while ( 1 ) {
		$key = &$func( $mwh );
		if ( defined $key ) {
			$self->input_key( $key );
			if ( defined $regex ) {
				return $key if ( $key =~ /^[$regex]/ || ( $regex =~ /\t/ 
				               && $key eq KEY_STAB ) );
			}
		}
		$self->draw( $mwh, 1 );
	}
}

1;

=head1 HISTORY

=over

=item 1999/12/29 -- Original list box widget in functional model

=item 2001/07/05 -- First incarnation in OO architecture

=item 2008/09/07 -- DnListBox derived from ListBox

=back

=head1 AUTHOR/COPYRIGHT

(c) 2008 David Nebauer <david@nebauer.org>

=cut
