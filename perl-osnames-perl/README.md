Building IO::Pager debian package
=================================

Download perl distribution and extract contents
-----------------------------------------------
```
perl -MCPAN -e shell
cpan> m Perl::osnames
    Module id = Perl::osnames
    CPAN_USERID  PERLANCAR (perlancar <perlancar@gmail.com>)
    CPAN_VERSION 0.11
    CPAN_FILE    P/PE/PERLANCAR/Perl-osnames-0.11.tar.gz
    INST_FILE    (not installed)
cpan> quit
```

Use the `CPAN_FILE` value in the following command:
```
wget http://www.cpan.org/modules/by-authors/id/P/PE/PERLANCAR/Perl-osnames-0.11.tar.gz
tar zxvf Perl-osnames-0.11.tar.gz
```

Run `dh-make-perl`
------------------
While still in parent directory run dh-make-perl on distro directory
to create the files needed for the debian package:
```
dh-make-perl Perl-osnames-0.11
```

*Note there is no '.tar.gz' extension in the command.*
   
This process may end with a fatal error which can be ignored:
```
fatal: pathspec 'Perl-osnames-0.11' did not match any files
add Perl-osnames-0.11: command returned error: 128
```

Run `debuild`
-------------
Change into build directory and run debuild to build package:
```
cd Perl-osnames-0.11
debuild
```

This will likely end in error the first time:
```
dpkg-source: error: can't build with source format '3.0 (quilt)': \
no upstream tarball found at ../libperl-osnames-perl_0.11.orig.tar.\
{bz2,gz,lzma,xz}
```

Create the missing tarball:
```
cp ../Perl-osnames-0.11.tgz ../libperl-osnames-perl_0.11.orig.tar.gz
```

Now re-run 'debuild' and while it may end with a signing error
it does build the package
