# ProgramV version 0.09

## PREAMBLE

Program V was originally written by Ernest Lergon and seemingly abandoned in the
year 2002 at version 0.08; it was designed for Perl 5.6 and hasn't been able to
run, without modification, on any newer versions of Perl since then.

It has been dusted off and fixed up by Noah Petherbridge in 2014 so that it
should run without modification on modern Perl (tested on Perl 5.18). See the
file `UpdateNotes.md` for an overview of what changes were necessary to the
codebase for this to work. If you're viewing this on GitHub, check the commit
history to see what all was changed to get version 0.08 to run on Perl 5.18.

Besides that, just as before, Program V is not being actively maintained by
anybody. If my work in getting this to run on Perl 5.18 has inspired you, feel
free to fork this project and continue development, as it was released by
Ernest Lergon under the same terms as Perl itself.

## DESCRIPTION

ProgramV is a Perl implementation of an interpreter for the Artificial
Intelligence Markup Language (AIML) defined by the Alicebot and AIML
Architecture Committee of the A.L.I.C.E. AI Foundation.

It's based on the ideas of ProgramD - the current Java implementation
of AIML - but without javaness.

Many webmasters do not want to run Java on their servers, so ProgramV
might be an alternative.

The use of Perl resp. ModPerl enables a smooth integration of an AIML
chatbot in the Apache environment. Many of the server functions of
ProgramD can be delegated to the Apache core - e.g. authentification,
cookie-handling, encryption, logging etc. - so ProgramV can be limited
to the core functions of AIML: parsing, matching and responding.

FEATURES

* Smooth integration in Apache environment
* Validating AIML parser (picky 1.01 ;-)
* Very fast startup due to precompiled knowledge
* Only a few modules / objects
* Integration of Perl code in AIML
* Full logging of matching and parsing if desired
* Runs on Linux as well as on Windows
* Edit and test your bot local on Windows and run it on your Linux server
* because all files are interchangeable

CAVEATS

* No filelocking on Windows
* Only one local user for the shell (console)
* No realtime learning due to precompiled knowledge
* You must have root access to install and run
* No server side javascript yet
* No server side system commands yet
* No targeting yet
* Proprietary data format of user/log files (still...)

This package ships with a modified Alice AIML set and an excerpt of
the Standard AIML set for testing.

You can talk to our Alice on Perl at

http://alice.virtualitas.net/talk

For server installation please see README.server


## DEVELOPMENT STATE

Officially "alpha", hence the 0.0x version number, though ProgramV
should run as expected. But don't rely on anything ;-)

The package includes a new version of Readonly.pm not yet available at
CPAN.

This is a facility for creating non-modifiable variables and is useful
for configuration files, headers, etc. It can also be useful as a
development and debugging tool, for catching updates to variables that
should not be changed. Very important in a mod_perl environment, where
the knowledge data has to stay shared!

The included module EnglishSave.pm is a workaround. For more
information see http://www.virtualitas.net/perl/englishsave/.


## BUGS

Sure. Many.


## INSTALLATION

Make sure you have Perl 5.6+ installed or the unicode support won't
work. Perl is available at http://www.perl.com .

There is no automatic installation provided yet, so just fetch the
archive, put it in a subdirectory of your choice, extract it with

	gzip -cd programv-0.08.tar.gz | tar xf -	Linux
	(use something like WinZip)			Windows

and then enter the following:

	cd programv
	./shell.pl	Linux
	shell		Windows

This will fail to load the knowledge data but will tell you, which
Perl modules must be installed additionally - e.g.

	Unicode::Map8
	Unicode::String

Without changing anything, you can now build the knowledge data by
entering

	./build.pl -f server-test.properties	Linux
	./build.pl				Linux

	build -f server-test.properties		Windows
	build					Windows

The first command builds the small dataset for testing based on

	aiml/standard/dev-*.aiml.

It will issue many warnings about unknown tags, because ProgramV does
not support AIML 0.9 tags! Please ignore.

The second command builds the big data set for Alice based on

	aiml/alice/*.aiml.

It will run for 2 or 3 minutes and issue only one warning about a
duplicate pattern.

You can run the test suite with

	./tester.sh		Linux
	tester			Windows

It uses the testcase.txt from ProgramD expanded by some tests for the
Perl functionality. Moreover it creates a detailed log file.

To test the bot manually, just enter

	./shell.pl -f server-test.properties		Linux
	shell -f server-test.properties			Windows

To communicate with Alice, enter

	./shell.pl		Linux
	shell			Windows

See below for further information, how to set up your own bot.

For server installation please see README.server


## SCRIPT build.pl [-d] [-f filename]

The -d switch turns on debugging and extensive logging (slow).

With the -f switch you can provide another config file.

Default: -f server.properties

To set up a new bot "mybot" do:

1. Copy server.properties to server-mybot.properties.

2. Edit server-mybot.properties so that it reads:

	programv.startup=conf/startup-mybot.xml
	programv.runfile=data/knowledge-mybot.data

3. Create a new directory aiml/mybot/ and place your aiml files into it.

4. Copy conf/startup.xml to conf/startup-mybot.xml

5. Edit conf/startup-mybot.xml so that it reads:

	`<learn>../aiml/mybot/*.aiml</learn>`

6. Run ./build.pl -f server-mybot.properties

7. Enjoy ./shell.pl -f server-mybot.properties


## SCRIPT stats.pl [-f filename]

This script gives statitistics about your knowledge data.

With the -f switch you can provide another config file (see above).

Default: -f server.properties

It is called automatically after build.pl is successfull.


## SCRIPT shell.pl [-d] [-f filename]

The -d switch turns on debugging and extensive logging (slow).

With the -f switch you can provide another config file (see above).

Default: -f server.properties


## SCRIPT tester.sh

This script deletes ./aiml.log, ./testcase.log and ./data/user1.data
and runs

	./shell.pl -d -f server-test.properties < testcase.txt > testcase.log


## COPYRIGHT AND LICENSE

Ernest Lergon, ernest@virtualitas.net

Copyright (c) 2002 by Ernest Lergon, VIRTUALITAS Inc.

All Rights Reserved. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

If you have suggestions for improvement, please drop me a line. If you
make improvements to this software, I ask that you please send me a
copy of your changes. Thanks.
