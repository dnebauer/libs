package Dn::Menu;

use Moo;    #                                                          {{{1
use strictures 2;
use 5.014_002;
use namespace::clean;
use version; our $VERSION = qv('0.1');

use Carp qw(confess);
use charnames qw(:full);
use Curses;
use Curses::Widgets;
use Curses::Widgets::Label;
use Curses::Widgets::ListBox::DnListBox;
use Dn::Common;
use Dn::Menu::Types qw(MenuType);
use English qw(-no_match_vars);
use File::Which;
use Function::Parameters;
use List::MoreUtils qw(any first_index);
use List::Util qw(max);
use MooX::HandlesVia;
use Readonly;
use Term::ReadKey;
use Types::Standard qw(ArrayRef Bool Int Str);
use UI::Dialog;
use experimental 'switch';

my $cp = Dn::Common->new();
Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;    #                                          }}}1

# attributes

# default                                                              {{{1
has 'default' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    accessor      => '_default',
    default       => 0,
    documentation => 'Index of default selection',
);

# header                                                               {{{1
has 'header' => (
    is            => 'rw',
    isa           => Types::Standard::Str,
    accessor      => '_header',
    required      => $TRUE,
    default       => sub { $cp->scriptname },
    documentation => q{Menu header},

    # used by all menu types
);

# hotkey_col1_indent                                                   {{{1
has 'hotkey_col1_indent' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    accessor      => '_hotkey_col1_indent',
    required      => $TRUE,
    default       => 6,
    documentation => q{Indent at which to display first column of items},
);

# hotkey_gutter                                                        {{{1
has 'hotkey_gutter' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    accessor      => '_hotkey_gutter',
    required      => $TRUE,
    default       => 3,
    documentation => q{Minimum space between columns of items},
);

# hotkey_min_column_width                                              {{{1
has 'hotkey_min_column_width' => (
    is            => 'rw',
    isa           => Types::Standard::Int,
    accessor      => '_hotkey_min_column_width',
    required      => $TRUE,
    default       => 10,
    documentation => q{Minimum column width},
);

# index                                                                {{{1
has 'index' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    accessor      => '_index',
    default       => $FALSE,
    documentation => q{Whether to return item index rather than item},
);

# menu_list                                                            {{{1
has 'menu_list' => (
    is          => 'rw',
    isa         => Types::Standard::ArrayRef [Types::Standard::Str],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        _options      => 'elements',
        _option_count => 'count',
        _has_options  => 'count',
    },
    documentation => q{Menu items},
);

# number                                                               {{{1
has 'number' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    accessor      => '_number',
    default       => $FALSE,
    documentation => q{Whether to number menu items before display},

    # currently honoured only by term menus
);

# prompt                                                               {{{1
has 'prompt' => (
    is            => 'rw',
    isa           => Types::Standard::Str,
    accessor      => '_prompt',
    required      => $TRUE,
    default       => 'Select an option: ',
    documentation => 'Menu prompt',

    # used by all menu types
);

# record                                                               {{{1
has 'record' => (
    is            => 'rw',
    isa           => Types::Standard::Bool,
    accessor      => '_record',
    default       => $FALSE,
    documentation => q{Whether to write prompt and selection to terminal},

    # hotkey menus record regardless of this option
);

# type                                                                 {{{1
has 'type' => (
    is            => 'rw',
    isa           => Dn::Menu::Types::MenuType,
    accessor      => '_type',
    required      => $TRUE,
    default       => 'term',
    documentation => q{Menu type ('hotkey', 'menu' or 'gui')},
);    #                                                                }}}1

# methods

# select_option()                                                      {{{1
#
# does:   select option from menu
# params: nil
# prints: nil
# return: scalar string: selected option
#         undef: if no options provided or none selected
method select_option () {

    # must have options to select from
    if ( not $self->_has_options ) { return; }

    # check attributes
    $self->_process_attributes();

    # determine selected menu item differently depending on menu type
    for ( $self->_type ) {
        if    ($_ =~ /^hotkey\z/xsmi) {
            return $self->_select_hotkey();
        }
        elsif ($_ =~ /^term\z/xsmi) {
            return $self->_select_term();
        }
        elsif ($_ =~ /^gui\z/xsmi) {
            return $self->_select_gui();
        }
    }
}

# _display_hotkey_menu($hotkeys_ref, $items_ref)                       {{{1
#
# does:   write menu to console
# params: $hotkeys_ref - items hotkeys [list reference, required]
# params: $items_ref - items [list reference, required]
# prints: menu
# return: scalar string
# notes:  menu consists of header, two columns of hotkey-highlighted items
#         and a prompt
# note:   here are the various parameters used to build the menu:
#
#         	                 Option 1               Option 2
#         	<- col1-indent ->           <- gutter ->           <- gutter ->
#         	                 <- column              <- column
#         					    width ->               width ->
#         	<------------ col2-indent ------------->
#         	<-------------------- terminal-width ------------------------->
# note:  user-supplied values: col1-indent, gutter, and min-column-width
#        values obtained directly by script: terminal-width
#        calculated values:
#            max-column-width
#                = ( terminal-width - ( 2 x gutter ) - col1-indent ) / 2
#            max-item-length = <longest out of all items>
#            column-width = <lesser of max-item-length and max-column-width>
#            col2-indent = col1-indent + column-width + gutter
# note:  if max-column-width < min-column-width method dies
# note:  if max-item-length > column-width some menu items will be truncated
# alert: the call to Curses method 'endwin' can cause unpredictable changes
#        to cursor location
method _display_hotkey_menu ($hotkeys_ref, $items_ref) {

    # parameter checks
    if ( not( ref $hotkeys_ref and ref $hotkeys_ref eq 'ARRAY' ) ) {
        confess 'Hotkeys are not an array reference';
    }
    if ( not( ref $items_ref and ref $items_ref eq 'ARRAY' ) ) {
        confess 'Items are not an array reference';
    }
    my @hotkeys = @{$hotkeys_ref};
    if ( not @hotkeys ) { confess 'No hotkeys provided'; }
    my @items = @{$items_ref};
    if ( not @items ) { confess 'No items provided'; }
    if ( $#hotkeys != $#items ) {
        confess 'Items count does not match hotkey count';
    }

    # set variables
    my $col = 1;
    my $item_length;
    my $menu = q{};
    my $output;
    my $item = q{};
    my $hotkey;
    my $full_line_item;
    my $next_col;
    my $width;
    my $col1_indent      = $self->_hotkey_col1_indent();
    my $min_column_width = $self->_hotkey_min_column_width();
    my $gutter           = $self->_hotkey_gutter();
    my $header           = $self->_header();

    if ($header) {
        $header = $cp->shell_underline($header);
    }
    my $prompt = $self->_prompt();

    # derive remaining required variables
    my $term_height;
    my $term_width;
    my $mwh = Curses->new();
    $mwh->getmaxyx( $term_height, $term_width );    # terminal dimensions
    endwin();
    my $max_column_width
        = ( $term_width - ( 2 * $gutter ) - $col1_indent ) / 2;
    my @item_lengths = map {length} @items;
    my $max_item_length = List::Util::max @item_lengths;

    if ( $max_column_width lt $min_column_width ) {
        my $err = "Maximum possible column width: $max_column_width\n"
            . "minimum required column width: $min_column_width";
        confess $err;
    }
    my $column_width;
    if ( $max_item_length < $max_column_width ) {
        $column_width = $max_item_length;
    }
    else {
        $column_width = $max_column_width;
    }
    my $col2_indent               = $col1_indent + $column_width + $gutter;
    my $full_line_max_item_length = ( 2 * $column_width ) + $gutter;
    $header = $cp->shorten( $header, $term_width );

    # build menu
    foreach my $index ( 0 .. $#items ) {
        $item        = $items[$index];
        $hotkey      = $hotkeys[$index];
        $item_length = length $item;

        for ($col) {
            if ($_ =~ /^1\z/xsm) {    # column 1
                if ( $item_length > $column_width ) {    # occupy entire line
                    $full_line_item = $TRUE;
                }
                else {
                    $item = q{ } x $col1_indent . $item; # add column 1 indent
                    $item = sprintf "%-${col2_indent}s", $item;    # right pad
                    $item = $self->_highlight_hotkey( $item, $hotkey );
                    if ($menu) {    # start new line
                        $menu .= qq{\n};
                    }
                    $next_col = 2;    # prepare for next loop
                }
            }
            elsif ($_ =~ /^2\z/xsm) {        # column 2
                if ( $item_length > $column_width ) {    # occupy entire line
                    $full_line_item = $TRUE;
                }
                else {
                    $item = $self->_highlight_hotkey( $item, $hotkey );
                    $next_col = 1;    # prepare for next loop
                }
            }
        }

        # special case: adding as full line item
        if ($full_line_item) {
            if ( $item_length > $full_line_max_item_length ) {
                $item = $cp->shorten( $item, $full_line_max_item_length );
            }
            $item = $self->_highlight_hotkey( $item, $hotkey );

            #$item = sprintf( "%${col1_indent}s" , $item );  # doesn't work
            $item = q{ } x $col1_indent . $item;    # add column 1 indent
            if ($menu) {                            # start new line
                $menu .= qq{\n};
            }
            $next_col       = 1;                    # prepare for
            $full_line_item = $FALSE;               #+next loop
        }
        $menu = qq{$menu$item};    # add new menu item to menu
        $col  = $next_col;         # prepare for next loop
    }
    if ($menu) {
        $menu .= qq{\n};           # start new line
    }

    # add header and prompt
    if ($header) {
        $output = qq{$header\n};
    }
    $output .= $menu;
    $output .= $prompt;

    # display
    $cp->echo_en($output);
}

# _assign_hotkeys(@items)                                              {{{1
#
# does:   assign hotkeys to each item
# params: @items - items to assign hotkeys to [required]
# prints: nil
# return: list - ( \@hotkeys, \@hotkeyed_items )
# note:   if none of the characters in a menu item can serve as hotkey
#         (because they have all been assigned to other items) an available
#         hotkey is prepended to the items, e.g., 'option' becomes '(z) option'
# note:   the returned list @hotkeyed_items has prepended hotkeys where
#         necessary, but highlight codes have NOT been inserted
method _assign_hotkeys (@items) {
    if ( not @items ) { return; }
    my @possible_hotkeys = ( 'a' .. 'z', 0 .. 9 );
    my @hotkeys;

    # assign hotkeys to item characters where possible
    foreach my $item (@items) {
        my $assigned_hotkey = $FALSE;
        my @chars = split //xsm, $item;
        foreach my $char (@chars) {
            if ( not( any {/^$char\z/xsm} @hotkeys ) ) {
                push @hotkeys, $char;
                $assigned_hotkey = $TRUE;
                last;
            }
        }
        if ( not $assigned_hotkey ) {    # no hotkey in item
            push @hotkeys, q{};
        }
    }

    # where hotkey not assigned add hotkey character to item
    # example: 'option' becomes '(z) option'
    foreach my $index ( 0 .. $#items ) {
        if ( not $hotkeys[$index] ) {
            my $assigned_hotkey = $FALSE;
            foreach my $char (@possible_hotkeys) {
                if ( not( any {/^$char\z/xsmi} @hotkeys ) ) {
                    $hotkeys[$index] = $char;
                    $items[$index]   = '(' . $char . ')' . $items[$index];
                    $assigned_hotkey = $TRUE;
                    last;
                }
            }
            if ( not $assigned_hotkey ) {
                confess qq{Unable to assign hotkey to item '$items[$index]'};
            }
        }
    }

    # sanity check list lengths
    if ( $#hotkeys != $#items ) {
        confess 'Hotkey count not equal to item count';
    }

    # return hotkeys and hotkeyed items
    return ( [@hotkeys], [@items] );
}

# _process_attributes()                                                {{{1
#
# does:   ensure attributes are suitable for use
# params: nil
# prints: nil
# return: nil
method _process_attributes () {

    # ensure prompt is formatted
    $self->_format_prompt();

    # ensure default is within list range
    my @items = $self->_options;
    if ( not( $self->_default ~~ [ 0 .. $#items ] ) ) {
        $self->_default(0);
    }

    # hotkey-specific
    if ( $self->_type eq 'hotkey' ) {

        # if too many hotkey items switch to term menu
        if ( $self->_option_count > 36 ) {
            say q{Menu has } . $self->_option_count . q{ options};
            say q{Hotkey menus cannot have more than 36 options};
            say q{Switching to terminal menu ('term') instead};
            $self->_type('term');
            $cp->prompt;
        }
    }
}

# _record_results($selection)                                          {{{1
#
# does:   print results on display
# params: $selection - option selected by user [required]
# prints: results
# return: nil
method _record_results ($selection) {
    if ( not $self->_record ) { return; }
    my $report = $self->_prompt;
    if ($selection) {
        $report .= $selection;
    }
    else {
        $report .= '[No option selected]';
    }
    say $report;
}

# _select_hotkey()                                                     {{{1
#
# does:   display hotkey menu and select menu option
# params: nil
# prints: menu
# return: scalar string: selected option
# note:   it is not possible to exit the menu without selecting an option
#         so there is no return code that signifies no option selected
# usage:  my $option = Dn::Menu->new(
#             type => 'hotkey',
#             prompt => 'Select on of these options: ',
#             header => 'Option Handler',
#             menu_list => [@options],
#         )->select_option();
#         if ( not $option ) { confess 'No option selected'; }
method _select_hotkey () {

    # set variables
    my ( $hotkeys_ref, $items_ref )
        = $self->_assign_hotkeys( $self->_options );
    my @hotkeys = @{$hotkeys_ref};
    my @items   = $self->_options;
    my %hotkeyed_items;
    while ( my ( $index, $hotkey ) = each @hotkeys ) {
        $hotkeyed_items{$hotkey} = $items[$index];
    }

    # display menu
    $self->_display_hotkey_menu( $hotkeys_ref, $items_ref );

    # get user selection
    my $hotkey;
    ReadMode('raw');
    while (1) {
        $hotkey = ReadKey(0);
        if (    $hotkey
            and ( $hotkey ne qq{\n} )
            and ( any {/$hotkey/xsm} @hotkeys ) )
        {
            last;
        }
    }
    ReadMode('restore');

    # get menu option matching selected hotkey
    my $option = $hotkeyed_items{$hotkey};
    if ( not $option ) { confess qq{Invalid hotkey '$hotkey' selected}; }

    # get index of selected option
    my $index = List::MoreUtils::first_index {/^$option\z/xsm} @items;

    # echo selected menu option to screen
    $cp->echo_e($option);

    # return value
    return ( $self->_index ) ? $index : $option;
}

# _select_term()                                                       {{{1
#
# does:   display curses-based menu in terminal
# params: nil
# prints: menu
# return: scalar integer: index of selected option
#         undef: if no option selected
# usage:  my $option = Dn::Menu->new(
#             type => 'term',
#             prompt => 'Select on of these options: ',
#             header => 'Option Handler',
#             menu_list => [@options],
#         )->select_option();
#         if ( not $option ) { confess 'No option selected'; }
# alert:  the call to Curses method 'endwin' can cause unpredictable
#         changes to cursor location
method _select_term () {
    binmode STDOUT, ':encoding(UTF-8)';    # will be outputting unicode chars
    my $up         = "\N{UPWARDS ARROW}";
    my $down       = "\N{DOWNWARDS ARROW}";
    my @items      = $self->_options;
    my $header     = $self->_header;
    my $prompt     = $self->_prompt;
    my $default    = $self->_default;
    my $mwh        = Curses->new();
    my $key_legend = qq{Move=$up$down  Select=[Enter]  Abort=[Esc]};

    # set layout dimensions:
    #
    #                    TERM WIDTH
    #   --------------------------------------------------
    #  |             GUTTER TOP                           |
    #  | G    -prompt-------------------------------  G   | T
    #  | U L | Option 1                             | U R | E
    #  | T E | Option 2                             | T I | R
    #  | T F  --------------------------------------  T G | M
    #  | E T         GUTTER MIDDLE                    E H |
    #  | R    -Keys:--------------------------------  R T | H
    #  |     | Move: ^v ...                         |     | E
    #  |      --------------------------------------      | I
    #  |             GUTTER BOTTOM                        | G
    #  |                                                  | H
    #  |                                                  | T
    #  |                                                  |
    #   --------------------------------------------------

    my $gutter_top = my $gutter_middle = my $gutter_bottom = 1;
    my $gutter_left       = my $gutter_right       = 1;
    my $widget_vert_fixed = my $widget_horiz_fixed = 2;

    # rows|columns occupied by widget that is not menu/text content
    my $term_height = my $term_width = undef;

    # terminal actual size (in lines/cols)
    my $min_text_width = 11;
    my $min_menu_height = my $key_lines = 1;

    # programmer-determined minima for menu/text width and content height
    my $fixed_height_needs
        = $gutter_top
        + $widget_vert_fixed
        + $gutter_middle
        + $widget_vert_fixed
        + $key_lines
        + $gutter_bottom;
    my $fixed_width_needs
        = $gutter_left + $widget_horiz_fixed + $gutter_right;

    # fixed vert/horiz space required by gutters and widget borders

    # die if terminal too small for menu
    $mwh->getmaxyx( $term_height, $term_width );    # terminal dimensions
    my $min_term_height = $fixed_height_needs + $min_menu_height;
    my $min_term_width  = $fixed_width_needs + $min_text_width;
    if ( $term_width < $min_term_width or $term_height < $min_term_height ) {
        my $err
            = q{term is }
            . $term_width . q{x}
            . $term_height
            . q{ but must be at least }
            . $min_term_width . q{x}
            . $min_text_width
            . q{ to display menu};
        confess $err;
    }

    # determine menu height
    my $desired_menu_height = scalar @items;
    my $max_menu_height     = $term_height - $fixed_height_needs;
    my $menu_height;
    if ( $desired_menu_height < $max_menu_height ) {
        $menu_height = $desired_menu_height;
    }
    else {
        $menu_height = $max_menu_height;
    }

    # determine keys box vertical displacement
    my $keys_box_vertical_displacement
        = $gutter_top + $widget_vert_fixed + $menu_height + $gutter_middle;

    # determine menu width
    my @candidate_text_widths = map {length} @items;    # max item width
    push @candidate_text_widths, length $header;
    push @candidate_text_widths, length $prompt;
    push @candidate_text_widths, length $key_legend;
    my $desired_text_width = List::Util::max @candidate_text_widths;
    $desired_text_width++;
    my $max_text_width = $term_width - $fixed_width_needs;
    my $text_width;

    if ( $desired_text_width < $max_text_width ) {
        $text_width = $desired_text_width;
    }
    else {
        $text_width = $max_text_width;
    }

    # number menus if requested
    my @display_items;
    if ( $self->_number ) {
        @display_items = $cp->number_list(@items);
    }
    else {
        @display_items = map {$_} @items;
    }

    # truncate text where necessary
    @display_items = map { $cp->shorten( $_, $text_width ) } @display_items;
    $prompt     = $cp->shorten( $prompt,     $text_width );
    $key_legend = $cp->shorten( $key_legend, $text_width );
    $header     = $cp->shorten( $header,     $text_width );

    # prepare for widget display
    # - noecho and curs_set cannot be called as objects (see Curses manpage)
    noecho();            # do not echo key presses
    $mwh->keypad(1);     # necessary or cursor keys abort menu
    curs_set(0);         # do not show cursor
    $mwh->leaveok(1);    # need fn or menu does not return value
                         #+but it can be set to either 0 or 1!

    # display header
    my $header_display = 0;
    my $header_indent = ( ( $text_width - length $header ) / 2 ) + 2;

    # '+2' for left borders of enclosing box and menu
    $mwh->attrset(A_NORMAL);
    $mwh->attron( COLOR_PAIR( select_colour(qw/ white black /) ) );
    $mwh->attron(A_BOLD);
    $mwh->attron(A_UNDERLINE);
    $mwh->addstr( 0, $header_indent, "$header" );
    $mwh->attrset(A_NORMAL);

    # display key legend
    my $label = Curses::Widgets::Label->new(
        {   CAPTION    => 'Keys:',     # header (in border) [default: undef]
            CAPTIONCOL => 'red',       # header colour [default: undef]
            BORDER     => 1,           # whether border displayed [default: 1]
            BORDERCOL  => 'white',     # border colour [default: undef]
            COLUMNS    => $text_width,

            # width in characters [default: 10]
            LINES => $key_lines,       # height in characters [default: 1]
            VALUE => $key_legend,

            # label text [default: '']
            FOREGROUND => 'black',        # foreground colour [default: undef]
            BACKGROUND => 'white',        # background colour [default: undef]
            X          => $gutter_left,

            # horizontal right displacement of menu
            #+within terminal [default: unknown]
            Y => $keys_box_vertical_displacement,

            # vertical downward displacement of menu
            #+within terminal [default: unknown]
            ALIGNMENT => 'L',    # alignment 'R'|'C'|'L' [default: 'C']
        }
    );
    $label->draw($mwh);

    # display menu
    my $lb = Curses::Widgets::ListBox::DnListBox->new(
        {   CAPTION    => "$prompt",     # header (in border) [default: undef]
            CAPTIONCOL => 'yellow',      # header colour [default: undef]
            COLUMNS    => $text_width,

            # width in characters [default: 10]
            LINES => $menu_height,

            # height in characters [default: 3]
            INPUTFUNC  => \&scankey,     # function scanning for keystrokes
                                         #+[default: \&scankey]
            FOREGROUND => 'black',       # foreground colour [default: undef]
            BACKGROUND => 'white',       # background colour [default: undef]
            SELECTEDCOL =>
                'magenta',    # colour of selected option [default: undef]
            BORDER      => 1,          # whether border displayed [default: 1]
            BORDERCOL   => 'white',    # border colour [default: undef]
            FOCUSSWITCH => "\e\n",     # keys that exit menu [default: "\t"]
                                       #+note: tab=\t, esc=\e, newline=\n
            TOGGLE => "\n",        # keys that select option [default: "\n\s"]
                                   #+note: string literal "\s" is unknown
            X      => $gutter_left,

            # horizontal right displacement of menu
            #+within terminal [default: unknown]
            Y => $gutter_top,

            # vertical downward displacement of menu
            #+within terminal [default: unknown]
            TOPELEMENT => 0,    # index of element displayed on first line
                                #+(not honoured) [default: 0]
            LISTITEMS => [@display_items],

            # menu items [default: []]
            CURSORPOS => $default,   # menu item cursor starts on [default: 0]
            VALUE => [],    # menu item initially selected [default: []]
        }
    );

    # cannot call isendwin or endwin as object methods (see Curses manpage)
    $lb->draw( $mwh, 1 );
    $lb->execute($mwh);
    endwin();               # kills main window
    my $index = $lb->getField('VALUE');    # get index of selected item
         # should never be a multi-select listbox, but check for it anyway
    if ( ref $index eq 'ARRAY' ) {
        $index = ${$index}[0];
    }

    # report result if requested and return result
    # - test using 'defined' because zero is returned if first option selected
    if ( defined $index ) {
        my $selection = $items[$index];
        $self->_record_results($selection);
        return ( $self->_index ) ? $index : $selection;
    }
    else {
        $self->_record_results();
        return;
    }
}

# _select_gui()                                                        {{{1
#
# does:   display gui menu
# params: nil
# prints: nil
# return: scalar integer: index of selected option
#         undef: if no option is selected
# usage:  my $option = Dn::Menu->new(
#             type => 'gui',
#             prompt => 'Select on of these options: ',
#             header => 'Option Handler',
#             menu_list => [@options],
#         )->select_option();
#         if ( not $option ) { confess 'No option selected'; }
# *warn*: in 2017-12 kdialog redirected return value to stdout, causing
#         a failure cascade, so demoted kdialog in preference order
# *warn*: zenity behaves differently depending on whether it is called
#         from a terminal or not; if called outside a terminal it always
#         reports the last menu item regardless of what is selected,
#         while behaving normally when called in a terminal
method _select_gui () {

    # set variables
    my @items                 = $self->_options;
    my $header                = $self->_header;
    my $prompt                = $self->_prompt;
    my $list_height           = scalar @items;
    my @candidate_text_widths = map {length} @items;
    push @candidate_text_widths, length $prompt;
    my $width = List::Util::max @candidate_text_widths;    # maximum width
    my @widget_preference = grep { File::Which::which $_ }
        qw/gdialog cdialog whiptail ascii kdialog zenity/;

    # create dialog container
    my $scaling = 20;
    my $ui      = UI::Dialog->new(
        title       => $header,
        backtitle   => $header,
        height      => ( $list_height + 10 ) * $scaling,
        width       => $width * $scaling,
        list_height => $list_height * $scaling,
        order       => [@widget_preference],
    );

    # build item list for menu
    # - tag is index+1 because cannot have tag of zero, because
    #   zero is UI::Dialog's error code
    my @ui_list;
    foreach my $index ( 0 .. $#items ) {
        my $tag = $index + 1;
        push @ui_list, $tag => $items[$index];
    }

    # select from menu
    my $index = $ui->menu(
        text => $prompt,
        list => [@ui_list],
    );

    # report result if requested and return result
    if ($index) {
        $index--;    # because tag was incremented earlier
        my $selection = $items[$index];
        $self->_record_results($selection);
        return ( $self->_index) ? $index : $selection;
    }
    else {
        $self->_record_results(0);
        return;
    }
}

# _highlight_hotkey($string, $hotkey)                                  {{{1
#
# does:   highlights hotkey in string
# params: $string - string to analyse [required]
#         $hotkey - key in string to highlight [required]
# prints: nil
# return: scalar string
method _highlight_hotkey ($string, $hotkey) {

    # check variables
    if ( not $string ) { return; }
    if ( not $hotkey ) { return $string; }
    my $index = index lc $string, lc $hotkey;
    if ( $index == -1 ) { return $string; }
    my $highlight_on  = q{\033[0;31m};
    my $highlight_off = q{\033[0m};

    # do highlighting
    my $before_hotkey = substr $string, 0, $index;
    my $hotkey = substr $string, $index, 1;
    $hotkey = $highlight_on . $hotkey . $highlight_off;
    my $after_hotkey = substr $string, $index + 1;
    return $before_hotkey . $hotkey . $after_hotkey;
}

# _format_prompt($prompt)                                              {{{1
#
# does:   ensure prompt has form 'Prompt text: ' unless prompt is a question,
#         in which case it will be given the form 'Prompt question? '
# params: nil
# prints: nil
# return: nil (edits prompt attribute directly)
method _format_prompt () {
    my $prompt = $self->_prompt;

    # remove trailing spaces, colons and periods
    while ( $prompt =~ /[\s:\N{FULL STOP}]$/xsm ) {
        chop $prompt;
    }

    # append colon (but not to questions)
    my $last_char = substr $prompt, -1;
    if ( $last_char eq q{?} ) {
        $prompt .= q{ };
    }
    else {
        $prompt .= q{: };
    }

    # set new prompt
    $self->_prompt($prompt);
}    #                                                                 }}}1

1;

# POD                                                                  {{{1

__END__

=head1 NAME

Dn::Menu - menus for use by perl scripts

=head1 SYNOPSIS

    use Dn::Menu;
    # ...
    my $favourite_banana = Dn::Menu->new(
        type      => 'gui',
        header    => 'Bananas in Pyjamas',
        prompt    => 'Select your favourite',
        menu_list => ['B1', 'B2'],
    )->select_option();

=head1 DESCRIPTION

Provides menus for use by Perl scripts. There are three kinds of menus
available: hotkey, terminal-based and graphical.

=head2 MENU TYPES

=head3 hotkey

These menus consist of a header, two columns of options, and a prompt. One
letter of each menu option is highlighted -- the "hotkeys". An option is
selected by pressing its corresponding hotkey.

The hotkey for each option is the first character in the item that has not been
used as a hotkey in a previous item. If all characters in the item have been
used as hotkeys, an unused hotkey character is prepended to the items. For
example, "Option" may become "(x)Option".

Only 36 hotkeys are available (a-z and 0-9), so if there are more than 36
options provided the method will switch to using a terminal ('term') menu.

Menu layout is determined dynamically based on the terminal size and length of
menu items. Menu items that are too long will be truncated.

It is not possible to exit the menu without selecting an option, so it is
recommended that each hotkey menu should have a quit option.

When an option is selected the corresponding hotkey is returned.

=head3 terminal ('term')

These menus consist of a header, a list of menu options, and a key legend. The
menu is Curses-based. Menu layout is determined dynamically based on terminal
size and menu item lengths. Menu items that are too long will be truncated. A
legend indicates what keys are used to control the menu.

When an option is selected it is returned. If the user exists the menu without
making a selection, undef is returned.

It is possible to number the menu items (one-based) for display.

=head3 graphical ('gui')

These menus are based on the UI::Dialog module. It selects the most
sophisticated graphical menu widget available on the system.

When an option is selected it is returned. If the user exists the menu without
making a selection, undef is returned.

=head1 ATTRIBUTES

Used as part of object creation. For example:

    my $favourite_banana = Dn::Menu->new(
        type       => 'gui',
        header     => 'Bananas in Pyjamas',
        prompt     => 'Select your favourite',
        menu_list => ['B1', 'B2'],
    )->select_option();

=head2 menu_list => $list_ref

Menu items. List reference.

Required.

=head2 type => $type

Must be one of 'hotkey', 'menu' or 'gui'.

Optional. Default = 'term'.

=head2 index => $bool

Whether to return (zero-based) index of selected item rather than the item
itself. Boolean, but returns undef if user aborts.

Optional. Default: false.

I<Warning:> When using this attribute it is possible to return zero as a valid
selection. This means it is not possible to use a simple truth test to
determine whether the user selected a value or aborted. That is, this will not
work reliably:

    if ( not $selection ) { die "No selection\n"; }

Instead, test whether the returned value is defined:

    if ( not defined $selection ) { die "No selection\n"; }

I<Warning:> When using a hotkey menu, the index returned is the index of the
first item that matches the selected item. For menus with unique items this
will always return the index of the selected item. This cannot be guaranteed
for menus with duplicated items.

For example, consider a hotkey menu with items 'apple', 'pear', 'orange',
'pear'. If the user selects the last item the index returned is 1 rather than
3.

=head2 header => $string

Menu header/title. String.

Optional. Default = script name.

=head2 prompt => $string

Menu prompt. Will be "tidied" to ensure it ends with ': ' or, for questions, '?
'. String.

Optional. Default: 'Select an option: '.

=head2 record => $bool

Whether to write prompt and selection to console. Has no effect on hotkey menus
where prompt and selection are always printed to console. Boolean.

Optional. Default: false.

=head2 number => $bool

Whether menu option in 'term' menus should be numbered (one-based index).
Boolean.

Optional. Default: false.

=head2 default => $int

Index (zero-based) of the default menu item. If the index is greater than the
options list size it is reset to zero.

Optional. Default: 0.

=head2 hotkey_col1_indent => $int

Indent at which to display first column of items in hotkey menus.

Intended only for advanced users. Alter with caution.

Optional. Default: 6.

=head2 hotkey_min_column_width => $int

Minimum hotkey column width.

Intended only for advanced users. Alter with caution.

Optional. Default: 10.

=head2 hotkey_gutter => $int

Minimum space between columns of items.

Intended only for advanced users. Alter with caution.

Optional. Default: 3.

=head1 SUBROUTINES/METHODS

=head2 select_option()

=head3 Purpose

Display menu and enable user to select option.

=head3 Parameters

Nil.

=head3 Prints

Prompt and selection to console depending on menu type and attribute setting.

=head3 Returns

Scalar string: selected option (undef if no option selected).

=head1 DEPENDENCIES

Carp, charnames, Curses, Curses::Widgets, Curses::Widgets::Label,
Curses::Widgets::ListBox::DnListBox, Dn::Common, English, experimental,
File::Which, Function::Parameters, List::MoreUtils, List::Util, Moo,
MooX::HandlesVia, namespace::clean, Readonly, strictures, Term::ReadKey,
Types::Standard, UI::Dialog, version.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 AUTHOR

David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 David Nebauer E<lt>davidnebauer@hotkey.net.auE<gt>

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: fdm=marker :
