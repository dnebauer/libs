# configure.in for libdncommon-bash project

# --------------------------------------------------------------------

# Process this file with autoconf to produce a configure script
AC_PREREQ([2.71])
AC_INIT([Library of bash functions],
        [5.24],
        [david@nebauer.org],
        [libdncommon-bash],
)
AM_INIT_AUTOMAKE([foreign])

# --------------------------------------------------------------------

# Checks for programs/files
mypath="/usr:/usr/bin:/usr/local/bin"

dnl Compulsory
dnl ==========
dnl
dnl vim executable
AC_PATH_PROG(myvim, vim)
test -z "${myvim}" && AC_MSG_ERROR([Library requires vim])

dnl sed
AC_PATH_PROG(mysed, sed)
test -z "${mysed}" && AC_MSG_ERROR([Library requires sed to run])

# --------------------------------------------------------------------

# Variable substitution

# pkg
# - package name
pkg="${PACKAGE}"
AC_SUBST(pkg)

# bin_dir
# - user executables
# - default value in built deb package: /usr/bin
bin_dir="${prefix}/bin"
AC_SUBST(bin_dir)

# sbin
# - superuser executables
# - default value in built deb package: /usr/sbin
sbin_dir="${prefix}/sbin"
AC_SUBST(sbin_dir)

# data_dir
# - read-only architecture-independent data files
# - default value in built deb package: /usr/share
data_dir="${prefix}/share"
AC_SUBST(data_dir)

# pkgdata_dir
# - package read-only architecture-independent data files
# - default value in built deb package: /usr/share/${PACKAGE}
pkgdata_dir="${prefix}/share/${PACKAGE}"
AC_SUBST(pkgdata_dir)

# arch_triplet
# - multiarch implementation changes layout of /lib and /usr/lib
# - it adds an architecture-dependent subdirectory
# - this subdirectory name is often referred to as the 'triplet'
#   or 'arch-triplet'
# - the triplet value is obtained using:
#       dpkg-architecture -qDEB_HOST_MULTIARCH
arch_triplet="$( dpkg-architecture -qDEB_HOST_MULTIARCH )"
AC_SUBST(arch_triplet)

# lib_dir
# - root for hierarchy of libraries
# - includes multiarch triplet
# - default value in built deb package: /usr/lib/<triplet>
#   but occasionally overridden to /lib in important packages, e.g., udev
lib_dir="${prefix}/lib/${arch_triplet}"
AC_SUBST(lib_dir)

# pkglib_dir
# - package executables run by other executables, not user,
#   and package libraries
# - includes multiarch triplet
# - default value in built deb package: /usr/lib/${arch_triplet}/${PACKAGE}
#   but occasionally overridden to /lib/${PACKAGE}
#   in important packages, e.g., udev
pkglib_dir="${prefix}/lib/${arch_triplet}/${PACKAGE}"
AC_SUBST(pkglib_dir)

# libexec_dir
# - root for hierarchy of (a) executables run by other executables, not user
# - default value in built deb package: /usr/libexec
libexec_dir="${prefix}/libexec"
AC_SUBST(libexec_dir)

# pkglibexec_dir
# - package executables run by other executables, not user
# - default value in built deb package: /usr/lib/${PACKAGE}
pkglibexec_dir="${prefix}/libexec/${PACKAGE}"
AC_SUBST(pkglibexec_dir)

# icons_dir
# - debian main icon directory
# - default value in built deb package: /usr/share/icons
# - note no app subdirectory in icons directory
icons_dir="${prefix}/share/icons"
AC_SUBST(icons_dir)

# localstate_dir
# - arch-independent data files modified while running
# - default value in built deb package: /var
localstate_dir="${localstatedir}"
AC_SUBST(localstate_dir)

# sharedstate_dir
# - machine-specific data files modified while running
# - default value in built deb package: /usr/com
#   but this is not a valid debian directory so commonly overriden to
#   /var/lib in debian rules file
sharedstate_dir="${sharedstatedir}"
AC_SUBST(sharedstate_dir)

# pkgvar_dir
# - package-specific data files modified while running
# - default value in built deb package: /var/lib/${PACKAGE}
pkgvar_dir="${localstatedir}/lib/${PACKAGE}"
AC_SUBST(pkgvar_dir)

# sysconf_dir
# - system configuration files
# - default value in built deb package: /etc
sysconf_dir="${sysconfdir}"
AC_SUBST(sysconf_dir)

# pkgconf_dir
# - package configuration files
# - default value in built deb package: /etc/${PACKAGE}
pkgconf_dir="${sysconfdir}/${PACKAGE}"
AC_SUBST(pkgconf_dir)

# pkgdoc_dir
# - package documentation
# - default value in built deb package: /usr/share/doc/${PACKAGE}
pkgdoc_dir="${prefix}/share/doc/${PACKAGE}"
AC_SUBST(pkgdoc_dir)

# man_dir
# - manpage files
# - default value in built deb package: /usr/share/man
man_dir="${prefix}/share/man"
AC_SUBST(man_dir)

# vim_ftplugin
# - vim filetype plugin files
# - default value in built deb package: /usr/share/vim/addons/ftplugin
vim_ftplugin="${prefix}/share/vim/addons/ftplugin"
AC_SUBST(vim_ftplugin)

# vim_doc
# - vim help files
# - default value in built deb package: /usr/share/vim/addons/doc
vim_doc="${prefix}/share/vim/addons/doc"
AC_SUBST(vim_doc)

# vim_libdncb
# - additional plugin files (other than ftplugin files)
# - default value in built deb package: /usr/share/vim/addons/libdncommon-bash
vim_libdncb="${prefix}/share/vim/addons/${PACKAGE}"
AC_SUBST(vim_libdncb)

# vim_reg
# - vim registry directory
# - default value in built deb package: /usr/share/vim/registry
vim_reg="${prefix}/share/vim/registry"
AC_SUBST(vim_reg)

# --------------------------------------------------------------------

# Create files
AC_CONFIG_FILES([
				Makefile man/Makefile libs/Makefile
				vim/Makefile misc/Makefile store/Makefile

				libs/liball libs/libarrays libs/libcontrol
				libs/libconvert libs/libdevices libs/libdvd
				libs/libfiles libs/libinternet
				libs/liblists libs/libnumbers
				libs/libprogram-interaction libs/libstrings
				libs/libtime libs/libuser-interaction
				libs/libvariables
				
				man/libdncommon-bash.1

				vim/sh_libdncommon-bash.vim
				vim/libdncommon-bash-shell-ftplugin.txt
				vim/funcdict vim/funcload.vim
				vim/libdncommon-bash.yaml
                vim/libfile-functions.vim

				misc/error.xpm misc/info.xpm
				misc/question.xpm misc/warn.xpm
				misc/alert-tone-3-pulses.wav misc/dramatic_chord.wav

				store/perlfuncdata store/dn-bashcom-funcdata
				store/dn-bashcom-funcdata.1
				])
AC_OUTPUT
