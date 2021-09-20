use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Check for required modules
sub check_module {
	my ( $modname , $modfile ) = ( $_[0] , $_[0] . ".pm" );
	$modfile =~ s/::/\//;
	printf "  %s... " , $modname;
	eval 'require "$modfile"';
	if   ($@) { print "Missing\n" ; return undef; }
	else      { print "OK\n"      ; return 1;     }
}
print "Checking for required modules:\n";
my $all_modules_present = 1;
&check_module( "Carp"                     ) or $all_modules_present = undef;
&check_module( "Curses"                   ) or $all_modules_present = undef;
&check_module( "Curses::Widgets"          ) or $all_modules_present = undef;
#&check_module( "Curses::Widgets::ListBox" ) or $all_modules_present = undef;
die "Error: Missing module(s) -- aborting Makefile.PL execution\n"
	if not $all_modules_present;

# Write makefile
WriteMakefile(
	NAME          => 'Curses::Widgets::ListBox::DnListBox',
	DISTNAME      => 'libcurses-widgets-listbox-dnlistbox-perl',
	VERSION_FROM  => 'lib/Curses/Widgets/ListBox/DnListBox.pm',
	ABSTRACT_FROM => 'Abstract',
	AUTHOR        => 'David Nebauer <david@nebauer.org>',
);
