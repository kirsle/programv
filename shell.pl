#!/usr/bin/perl

BEGIN
{
	use strict;
	use warnings;

	$| = 1;

	use lib './lib';

	use Getopt::Std;
	use vars qw ( $opt_d $opt_f );

	getopts ( "df:" );

	$::CONFIG_FILE	= $opt_f ? $opt_f : './server.properties';

	$::DEBUG = $opt_d ? 1 : 0;							#	special debug cases:

	$AIML::Bot::DEBUG				= 1 && $::DEBUG;		#
	$AIML::Common::DEBUG			= 1 && $::DEBUG;		#	1 = die on warnings
	$AIML::Config::DEBUG			= 1 && $::DEBUG;		#	1 = switch to readonly hash (slow)
	$AIML::File::DEBUG			= 1 && $::DEBUG;		#
	$AIML::Knowledge::DEBUG		= 1 && $::DEBUG;		#	1 = switch to readonly hash (slow)
	$AIML::Listener::DEBUG		= 1 && $::DEBUG;		#
	$AIML::Memory::DEBUG			= 1 && $::DEBUG;		#
	$AIML::Parser::DEBUG			= 1 && $::DEBUG;		#	1 = logs parsing (huge output)
	$AIML::Graphmaster::DEBUG	= 1 && $::DEBUG;		#	1 = logs matching tree (slow)
	$AIML::Responder::DEBUG		= 1 && $::DEBUG;		#
	$AIML::Shell::DEBUG			= 0 && $::DEBUG;		#	1 = logs ALL keystrokes to ./shell.log (very huge output)
	$AIML::Talker::DEBUG			= 1 && $::DEBUG;		#
	$AIML::Unicode::DEBUG		= 1 && $::DEBUG;		#

#	$AIML::Shell::DEBUG			= 1;

}

use strict;
use warnings;

use AIML::Shell 0.09;

my $shell = new AIML::Shell ( config_file => $::CONFIG_FILE );

die ( "Can't create shell" )	unless $shell;

$shell->run();

1;

__END__
