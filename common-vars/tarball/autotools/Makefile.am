# Makefile.am for package libdncommon-vars

# Here are some useful GNU directory variables,
# their default values after deb packaging, and
# the primaries they can be used with:
#   bindir         = /usr/bin                   SCRIPTS
#   sbindir        = /usr/sbin                  SCRIPTS
#   pkgdatadir     = /usr/share/$(PACKAGE)      SCRIPTS DATA
#   libexecdir     = /usr/lib/$(PACKAGE)        SCRIPTS
#   datadir        = /usr/share                 DATA
#   localstatedir  = /var                       DATA
#   sharedstatedir = /usr/com                   DATA
#   sysconfdir     = /etc                       DATA
#   mandir         = /usr/share/man/manX        MANS
# 
# 'libdir' is not included -- it cannot be used for
# SCRIPTS or DATA
#
# 'sharedstatedir' defaults to /usr/com which is not used
# by debian -- override to /var/lib which can be done by
# adding the following rule to the defaut debian rules
# file:
# 	override_dh_auto_configure:
#		dh_auto_configure -- --sharedstatedir=/var/lib
#
# Now we define some additional useful directory variables
# apparently overlooked by GNU, their default values after
# deb packaging, and the primaries they are commonly used
# with:
#   pkglibdir      = /usr/lib/$(PACKAGE)        DATA
#   pkgconfdir     = /etc/$(PACKAGE)            DATA
#   pkgdocdir      = /usr/share/doc/$(PACKAGE)  DATA
#   pkgvardir      = /var/lib/$(PACKAGE)        DATA
pkglibdir = @libdir@/$(PACKAGE)
pkgconfdir = @sysconfdir@/$(PACKAGE)
pkgdocdir = @docdir@
pkgvardir = @localstatedir@/lib/$(PACKAGE)
#
# Some other usefule variables are:
#   @prefix@       = /usr
#   @docdir@       = /usr/share/doc/$(PACKAGE)


# Now let us assign some install locations
# [comment out unused directory targets or they
#  will be added, empty, to the deb package]

# Scripts
# -------

# User-executable scripts generally go in /usr/bin
#bin_SCRIPTS = 

# Superuser-only scripts live in /usr/sbin
#sbin_SCRIPTS = 

# Scripts run by other scripts go in /usr/lib/$(PACKAGE)
# Note GNU Coding Standards specify libexecdir for
# executables and libdir for libraries and object code
# (and definitely no executables), while FHS uses libdir
# for both -- although the debian defaults match FHS this
# is the only way to get scripts into this directory
#libexec_SCRIPTS = 

# Packaging tools will let you put scripts in
# /usr/share/$(PACKAGE) but this seems a very bad idea --
# according to the FHS </usr/share/doc/debian-policy/fhs/>
# this directory is intended for read-only architecture-
# independent data files
#pkgdata_SCRIPTS = 


# Data
# ----

# The root directory for read-only architecture-independent
# data files is /usr/share, but you should never use this
# directory -- use a package subdirectory
#data_DATA = 

# You put read-only architecture-independent data files
# for the package in /usr/share/$(PACKAGE)
#pkgdata_DATA = 


# Configuration
# -------------

# The system wide configuration directory is /etc and a
# single configuration file can be put here
sysconf_DATA = libdncommon-varsrc

# A package's config files can be put in their own
# subdirectory: /etc/$(PACKAGE)
#pkgconf_DATA = 

# Note that some applications store their rules files
# under /lib/$(PACKAGE), such as udev which stores them in
# /lib/udev/rules.d -- in such cases it may be necessary
# to override libdir to /lib


# Libraries
# ---------

# Architecture-dependent data exclusively used by an 
# application can be placed in /usr/lib/$(PACKAGE)
# (as can libraries and executables -- see
# libexec_SCRIPTS above)
#pkglib_DATA = 


# Documentation
# -------------

# Package documentation is stored under
# /usr/share/doc/$(PACKAGE)
#pkgdoc_DATA = 

# Man files are stored in the hierarchy under
# /usr/share/man
man_MANS = libdncommon-vars.1


# Variable data
# -------------

# Machine-specific data files modified while running go in
# the /var hierarchy
#localstate_DATA = 

# Architecture-independent data files modified while
# running go in the directory designated by the variable
# sharedstatedir which defaults to /usr/com -- this is not
# a valid debian directory so override it to /var/lib
# (see notes at top on directory variables)
#sharedstate_DATA = 

# Package-specific data files modified while running go in
# /var/lib/$(PACKAGE)
#pkgvar_DATA = 


# References
# ----------
# GNU Coding Standards 7.2.5 (Variables for Installation Directories)
# - package <autoconf-doc>
# - file </usr/share/doc/autoconf-doc/standards.html#Directory-Variables>
# - note that GNU CS and FHS use different concepts and at points
#   conflict with each other
# Filesystem Hierarchy Standard
# - package <debian-policy>
# - at </usr/share/doc/debian-policy/fhs/>
# - note that GNU CS and FHS use different concepts and at points
#   conflict with each other
# Autobook 14.1 (Where files are installed)
# - package <autobook>
# - file </usr/share/doc/autobook/html/>
# Automake info
# - package <automake>
