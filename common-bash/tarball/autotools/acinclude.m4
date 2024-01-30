dnl Name:     DN_PERL_MODULE
dnl Purpose:  Check for presence of perl module
dnl Requires: Perl -- can check for it with:
dnl               AC_PATH_PROG(myperl, perl)
dnl               test -z "${myperl}" && AC_MSG_ERROR([Perl is required])
dnl Actions:  If module not found, configure aborts with error status
dnl Params:   Module name is essential
dnl           Module minimum version is optional
dnl Usage:    DN_PERL_MODULE(MODULE-NAME)
dnl           DN_PERL_MODULE(MODULE-NAME, MODULE-VERSION)
AC_DEFUN([DN_PERL_MODULE],
[
	dnl Give feedback
	module_string=""
	if test "x$1" != "x" ; then
		module_string="$1"
		test "x$2" != "x" && module_string="${module_string} (>=$2)"
	fi
	AC_MSG_CHECKING([for perl module ${module_string}])

	dnl Must have module name
	if test "x$1" = "x" ; then
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([No module name supplied])
	fi
	
	dnl Assemble module string (param 1 = name, param 2 = version)
	module="$1"
	test "x$2" != "x" && module="${module} $2"

	dnl Now do test for perl module
	dnl Unusual construction of command 'cmd' is to prevent '$@' being
	dnl interpolated as the bash inbuilt variable holding all function
	dnl parameters
	cmd="\$"
	cmd="${cmd}@"
	cmd="perl -e 'eval \"use ${module}\" ; exit 1 if ${cmd};'"
	if $( eval "${cmd}" ) ; then
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
		AC_MSG_ERROR([Perl module ${module_string} is required])
	fi
])
