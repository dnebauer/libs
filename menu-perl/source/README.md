# Perl module Dn::Menu #

Provides menus for use by Perl scripts. There are three kinds of menus
available: hotkey, terminal-based and graphical.

## hotkey ##

These menus consist of a header, two columns of options, and a prompt. One
letter of each menu option is highlighted -- the "hotkeys". An option is
selected by pressing its corresponding hotkey.

The hotkey for each option is the first character in the item that has not been
used as a hotkey in a previous item. If all characters in the item have been
used as hotkeys, an unused hotkey character is prepended to the items. For
example, "Option" may become "(x)Option".

Only 36 hotkeys are available (a--z and 0--9), so if there are more than 36
options provided the method will switch to using a terminal ('term') menu.

Menu layout is determined dynamically based on the terminal size and length of
menu items. Menu items that are too long will be truncated.

It is not possible to exit the menu without selecting an option, so it is
recommended that each hotkey menu should have a quit option.

When an option is selected the corresponding hotkey is returned.

## terminal ('term') ##

These menus consist of a header, a list of menu options, and a key legend. The
menu is Curses-based. Menu layout is determined dynamically based on terminal
size and menu item lengths. Menu items that are too long will be truncated. A
legend indicates what keys are used to control the menu.

When an option is selected it is returned. If the user exists the menu without
making a selection, undef is returned.

It is possible to number the menu items (one-based) for display.

## graphical ('gui') ##

These menus are based on the UI::Dialog module. It selects the most
sophisticated graphical menu widget available on the system.

When an option is selected it is returned. If the user exists the menu without
making a selection, undef is returned.
