# Dusting off the code

This file contains update notes of how I got the old dusty code (from 2002,
designed for Perl 5.6) up and running in 2014 on Perl 5.18.

--------------------------------------------------------------------------------

Getting the original 0.08 release of Program V up and running from scratch:

* Install Perl dependencies `Unicode::String` and `Unicode::Map8`
  Fedora: `yum install perl-Unicode-String perl-Unicode-Map8`

You'd initially get this error message when running `build.pl` at this point:

```
[~/g/programv]$ perl build.pl
Constant subroutine AIML::Common::LOCK_SH redefined at lib/AIML/Common.pm line 52.
Prototype mismatch: sub AIML::Common::LOCK_SH () vs none at lib/AIML/Common.pm line 52.
Constant subroutine AIML::Common::LOCK_EX redefined at lib/AIML/Common.pm line 53.
Prototype mismatch: sub AIML::Common::LOCK_EX () vs none at lib/AIML/Common.pm line 53.
Constant subroutine AIML::Common::LOCK_NB redefined at lib/AIML/Common.pm line 54.
Prototype mismatch: sub AIML::Common::LOCK_NB () vs none at lib/AIML/Common.pm line 54.
Constant subroutine AIML::Common::LOCK_UN redefined at lib/AIML/Common.pm line 55.
Prototype mismatch: sub AIML::Common::LOCK_UN () vs none at lib/AIML/Common.pm line 55.
Died at lib/AIML/Unicode.pm line 102.
Compilation failed in require at lib/AIML/Common.pm line 109.
BEGIN failed--compilation aborted at lib/AIML/Common.pm line 109.
Compilation failed in require at build.pl line 32.
BEGIN failed--compilation aborted at build.pl line 32.
```

Looking at AIML::Unicode line 102:

```perl
my $changer = do ( $pkg ) or die;
```

In this instance, the value of `$pkg` is `unicode/To/Upper.pl` which apparently
is not found. But doing a `locate Upper.pl` finds this file in
`/usr/share/perl5/unicore/To/Upper.pl` - a big difference seems to be the
spelling of `unicore` vs. `unicode`

I edited `AIML::Unicode` to change the file names (lines 76-78) to spell it as
`unicore` and this fixes it.

The `build.pl` runs now but it complains of some AIML syntax errors, such as

```
ERRORS:
Content 'DANS DIFFÉRENTES LANGUES' for tag 'pattern' is not valid
	at /home/noah/git/programv/conf/../aiml/alice/D.aiml line 303
```

I fixed the two files that it complains about and `build.pl` runs successfully.
Now I can run `shell.pl` and get an interactive chat session with an Alice bot!

As for all those Perl warnings about `AIML::Common::LOCK_SH`, I can only
imagine these were caused by the fact that file locking (`flock`) must've been
a new concept in Perl 5.6, and there was some code that attempts to load these
modules in, and on failure, will shim them by manually defining the constants
such as `LOCK_SH`.

On modern Perl there's no issues importing `flock` which brings these constants
in, but the error checking is itself erroneous (more Perl 5.6isms) which causes
the module to re-define these constants thinking that it had failed to import
them.

I just dummied out the other error check:

```diff
- my $err2 = not exists &flock;
+ # Modern Perl has this.....
+ my $err2 = undef; #not exists &flock;
```
