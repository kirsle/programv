=head1 NAME

AIML::Config - interface to the AIML configuration

=head1 SYNOPSIS

=over 4

=item * Auto-loading via httpd.conf

   PerlSetEnv  AIML_CONFIG_FILE   /home/alice/programv/server.properties
   PerlModule  AIML::Config

=item * Manual loading via Perl-Skript

   use AIML::Config;

   $AIML::Config::DEBUG = 1;   # switch to readonly hash (slow)

   AIML::Config::LOAD_AIML_CONFIG ( './server.properties' );

=item * Interface

   use AIML::Config;

   my $perl_allowed   = AIML::Config::getConfig ( 'perl-allowed' );
   #
   # true / false

   my $knowledge_file = AIML::Config::getConfigPath ( 'runfile' );
   #
   # i.e. '/home/alice/data/knowledge.data'

See L<AIML::Memory> for a method interface.

=back

=head1 DESCRIPTION

This module provides the static configuration for an AIML chatbot. The
config file to be read in contains lines in form of 'name=value'.

=cut

package AIML::Config;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

#
#	LIBS
#
use EnglishSave;
use Readonly 0.07;
use File::Spec;

use AIML::Common 0.09;
use AIML::File 0.09;

=head1 GLOBALS

   $AIML::Config::DEBUG = 1;   # switch to readonly hash (slow)

This will cause the program to mark the config data as read-only -
trying to modify it will result in a fatal error. This ensures the
structure to stay shared accross all httpd childs in a mod_perl
environment. It is very useful during development, but should be
turned of in a production environment because it slows down program
execution.

=for html <p>See <a href="http://search.cpan.org/search?dist=Readonly">Readonly.pm</a>.</p>

=head1 EXPORT

Nothing. See L<AIML::Memory> for a method interface.

=cut

#
#	INIT
#
my $ROOT_DIR			= './';

my %CONFIG_DEFAULT	=
(
	# -----------------------------------------------------------------------------
	# MAIN PROGRAM V CONFIGURATION
	# -----------------------------------------------------------------------------

	# Bot configuration startup file (relative to working directory)
	'startup'											=> 'conf/startup.xml',

	# Bot configuration run file (relative to working directory)
	'runfile'											=> 'data/knowledge.data',

	# Overwrite categories with identical pattern:that:topic (true/false)
	'merge'												=> true,

#	# Default value for undefined predicates
#	'emptydefault'										=> '',			#	NOT ALLOWED

	# The maximum allowable time (in milliseconds) to get a response
	'response-timeout'								=> 1000,

	# Input to match if an infinite loop is found
	'infinite-loop-input'							=> 'INFINITE LOOP',

	#	NEW
	#
	# Input to match if an infinite loop is found
	'timeout-input'									=> 'RESPONSE TIMEOUT',

#	# Allow use of <system> element? (true/false)
#	'os-access-allowed'								=> false,
#
#	# Allow use of <javascript> element? (true/false)
#	'javascript-allowed'								=> false,
#
#	#	NEW
#	#
#	# Allow use of <perl> element? (true/false)
#	'perl-allowed'										=> true,

	# The string to send when first connecting to the bot
	'connect-string'									=> 'CONNECT',

#	# The string to send after an inactivity timeout
#	'inactivity-string'								=> 'INACTIVITY',
#
#	# Require namespace qualification of non-AIML elements? (true/false)
#	'non-aiml-require-namespace-qualifiers'	=> false,
#
#	# Support deprecated "AIML 0.9" tags? (true/false)
#	'deprecated-tags-support'						=> false,
#
#	#	Whether to warn about deprecated tags
#	'deprecated-tags-warn'							=> false,
#
#	# Multiplexor to use
#	#	#programd.multiplexor=org.alicebot.server.core.DBMultiplexor
#	#	programd.multiplexor=org.alicebot.server.core.FlatFileMultiplexor
#
#	# Enable the heart?
#	# * The heart can beat and let you know the bot is alive.
#	# * Right now the only kind of pulse is a message "I am alive!" printed to the console.
#	#
#	'heart.enabled'									=> false,
#
#	# Pulse rate for the heart (beats per minute)
#	'heart.pulserate'									=> 5,
#
#	#	NEW
#	#
#	# Message from the heart
#	'heart.message'									=> "I am alive!",
#
#	# Maximum size of the cache before writing to disk/database.
#	'predicate-cache.max'							=> 5000,
#
#	# command line to launch preferred browser (for testing)
#	# * leaving this value blank or commented out disables the feature
#	'browser-launch'									=> '',
#
#	# -----------------------------------------------------------------------------
#	# CONSOLE/TRACE CONFIGURATION
#	# -----------------------------------------------------------------------------
#
#	# Show information on console (true/false)
#	'console'											=> true,
#
#	# Show developer info messages on console (true/false)
#	'console.developer'								=> false,
#
#	# Developer: show caller methods even for userinfo messages (true/false)
#	# * This is an advanced debugging feature.  You likely want to
#	# * leave it set to false.
#	'console.developer.method-names-always'	=> false,
#
#	# Show match-trace messages on console (true/false)
#	'console.match-trace'							=> true,
#
#	# Show message type flags on console (true/false)
#	'console.message-flags'							=> true,
#
#	# Which bot predicate contains the bot's name
#	'console.bot-name-predicate'					=> 'name',
#
#	# Which bot predicate contains the client's name
#	'console.client-name-predicate'				=> 'name',
#
#	# Warn about non-AIML elements when loading AIML (true/false)
#	'console.warn-non-aiml'							=> true,
#
#	# How many categories will be loaded before a message is displayed
#	# * Only meaningful if programd.console=true
#	'console.category-load-notify-interval'	=> 1000,
#
#	# The date-time format to use on the console
#	# * Setting the value to blank means no timestamp will be displayed.
#	'console.timestamp-format'						=> 'H:mm:ss',
#
#	# Use interactive command-line shell (true/false)
#	'shell'												=> true,
#
#	# -----------------------------------------------------------------------------
#	# INTERPRETER CONFIGURATION
#	# -----------------------------------------------------------------------------
#
#	# Directory in which to execute <system> commands
#	'interpreter.system.directory'				=> './',
#
#	# String to prepend to all <system> calls (platform-specific)
#	# * Windows requires something like "cmd /c"; *nix doesn't (just comment out)
#	'interpreter.system.prefix'					=> '',
#
#	# JavaScript interpreter (fully-qualified class name)
#	'interpreter.javascript'						=> '',
#
#	# -----------------------------------------------------------------------------
#	# HTTP SERVER CONFIGURATION
#	# -----------------------------------------------------------------------------
#
#	# HTTP server (wrapper) to use (fully-qualified class name)
#	'httpserver.classname'							=> '',
#
#	# configuration parameter for the HTTP server (not always applicable)
#	'httpserver.config'								=> '',
#
#	# Whether to enable authentication via the http server (true/false)
#	'httpserver.authenticate'						=> false,
#
#	# Whether to automatically generate a cookie for an unknown user (true/false)
#	# * Only applicable if programd.httpserver.authenticate=true
#	'httpserver.autocookie'							=> false,
#
#	# -----------------------------------------------------------------------------
#	# RESPONDER CONFIGURATION
#	# -----------------------------------------------------------------------------
#
#	# -----------------------------------------------------------------------------
#	# HTML Responder configuration
#	# -----------------------------------------------------------------------------
#
#	# The html templates directory (relative to programd.home).
#	'responder.html.template.directory'			=> 'templates/html',
#
#	# The default chat template.
#	# * Note: Any other *.html, *.htm or *.data files in
#	#	  programd.responder.flash.template.directory will also be available if
#	#         you specify a template=name (without suffixes) parameter in the user request.
#	'responder.html.template.chat-default'		=> 'chat.html',
#
#	# The registration template.
#	'responder.html.template.register'			=> 'register.html',
#
#	# The login template.
#	'responder.html.template.login'				=> 'login.html',
#
#	# The change password template.
#	'responder.html.template.change-password'	=> 'change-password.html',
#
#	# -----------------------------------------------------------------------------
#	# Flash Responder configuration
#	# -----------------------------------------------------------------------------
#
#	# The flash templates directory (relative to programd.home).
#	'responder.flash.template.directory'		=> 'templates/flash',
#
#	# The default chat template.
#	# * Note: Any other *.flash or *.data files in
#	#	  programd.responder.flash.template.directory will also be available if
#	#         you specify a template=name (without suffixes) parameter in the user request.
#	'responder.flash.template.chat-default'	=> 'chat.flash',
#
#	# The registration template.
#	'responder.flash.template.register'			=> 'register.flash',
#
#	# The login template.
#	'responder.flash.template.login'				=> 'login.flash',
#
#	# The change password template.
#	'responder.flash.template.change-password'=> 'change-password.flash',
#
#
#	# -----------------------------------------------------------------------------
#	# AIMLWATCHER CONFIGURATION
#	# -----------------------------------------------------------------------------
#	#
#	# Enable AIML Watcher (true/false)
#	'watcher'											=> false,
#
#	# Delay period when checking changed AIML (milliseconds)
#	# * Only applicable if programd.watcher=true
#	'watcher.timer'									=> 2000,
#
#	# -----------------------------------------------------------------------------
#	# LOGGING CONFIGURATION
#	# * Not defining a value means that the logging type will be disabled.
#	# * Note that you can send different log events to the same file if desired.
#	# -----------------------------------------------------------------------------
#
#	# -----------------------------------------------------------------------------
#	# Standard (text file) logs
#	# -----------------------------------------------------------------------------
#
#	'logging.listeners.path'						=> './logs/listeners.log',
#	'logging.access.path'							=> './logs/access.log',
#	'logging.database.path'							=> './logs/database.log',
#	'logging.debug.path'								=> './logs/debug.log',
#	'logging.error.path'								=> './logs/error.log',
#	'logging.event.path'								=> './logs/event.log',
#	'logging.gossip.path'							=> './logs/gossip.log',
#	'logging.interpreter.path'						=> './logs/interpreter.log',
#	'logging.learn.path'								=> './logs/learn.log',
#	'logging.merge.path'								=> './logs/merge.log',
#	'logging.startup.path'							=> './logs/startup.log',
#	'logging.servlet.path'							=> './logs/servlet.log',
#	'logging.system.path'							=> './logs/system.log',
#	'logging.targeting.path'						=> './logs/targeting.log',
#
#	# The date-time format to use in logging
#	# * Setting the value to blank means no timestamp will be displayed.
#	'logging.timestamp-format'						=> 'yyyy-MM-dd H:mm:ss',
#
#	# The generic userid to use in logs when old responders don't have it
#	'logging.generic-username'						=> 'client',
#
#	# -----------------------------------------------------------------------------
#	# XML logs
#	# -----------------------------------------------------------------------------
#
#	# Enable chat logging to xml text files?
#	# * Be sure that the database configuration (later in this file) is valid.
#	'logging.to-xml.chat'							=> 'true',
#
#	# How many log entries to collect before "rolling over" an XML log file.
#	# * "Rolling over" means that the current file is renamed using the date & time,
#	# * and a fresh log file is created using the path name.  The new log file will
#	# * contain links to all of the previous log files of the same type.
#	'logging.xml.rollover'							=> 2000,
#
#	# Directory for XML chat logs
#	'logging.xml.chat.log-directory'				=> './logs',
#
#	# Directory for XML resources
#	'logging.xml.resource-base'					=> '../resources/',
#
#	# Path to stylesheet for viewing chat logs
#	'logging.xml.chat.stylesheet-path'			=> '../../../resources/logs/view-chat.xsl',
#
#	# Whether to roll over the chat log at restart
#	'logging.xml.chat.rollover-at-restart'		=> true,
#
#	# -----------------------------------------------------------------------------
#	# Database logs
#	# -----------------------------------------------------------------------------
#
#	# Enable chat logging to the database?
#	# * Be sure that the database configuration (later in this file) is valid.
#	'logging.to-database.chat'						=> false,
#
#	# -----------------------------------------------------------------------------
#	# TARGETING CONFIGURATION
#	# -----------------------------------------------------------------------------
#
#	# Whether to enable targeting
#	'targeting'											=> true,
#
#	# Where targeting data should be stored
#	'targeting.data.path'							=> './targets/targets.xml',
#
#	# Location of targeting aiml file
#	'targeting.aiml.path'							=> './targets/targets.aiml',
#
#	# Number of responses to wait before invoking targeting
#	'targeting.targetskip'							=> 1,
#
#	# Preferred encoding for writing targeting data XML files (default: UTF-8)
#	'targeting.data.encoding'						=> 'UTF-8',
#
#	# -----------------------------------------------------------------------------
#	# DATABASE CONFIGURATION
#	# * This is only meaningful if you are using a database-enabled Multiplexor
#	# * and/or the database-based chat logging.
#	# -----------------------------------------------------------------------------
#
#	'database.url'										=> '',
#	'database.driver'									=> '',
#
#	# The maximum number of simultaneous connections to the database
#	'database.connections'							=> 0,
#
#	# The username to access the database
#	'database.user'									=> '',
#
#	# The password for the database
#	'database.password'								=> '',
);

=head1 FUNCTIONS

Following functions provide an interface to the config structure.

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * LOAD_AIML_CONFIG ( $filename )

This subroutine is automagically called during startup of a ModPerl-enabled Apache server.

Example for the configuration entries in httpd.conf:

   PerlSetEnv   AIML_CONFIG_FILE   /home/alice/programv/server.properties
   PerlModule   AIML::Handler

   <Location /talk>
      SetHandler  perl-script
      PerlHandler AIML::Handler
   </Location>

To use this module in a script:

=over 4

=item * define an environment variable

   i.e. Linux:
   AIML_CONFIG_FILE=/home/alice/programv/server.properties
   export AIML_CONFIG_FILE

   i.e. Windows:
   set AIML_CONFIG_FILE=c:\alice\programv\server.properties

and just say

   use AIML::Config;

in the script.

=item * OR load manually from the script

   use AIML::Config;

   AIML::Config::LOAD_AIML_CONFIG ( '/home/alice/programv/server.properties' );

=back

B<WARNING:> Using inactive options will cause this function to die.

=cut

my	$CONFIG	= {};

LOAD_AIML_CONFIG ( $ENV{AIML_CONFIG_FILE} )				if $ENV{AIML_CONFIG_FILE};	#	autoload for mod_perl...

sub LOAD_AIML_CONFIG																					#	call directly for shell...
{
	my $file_name = shift;

	#
	#	load config
	#
	my $VAR1 = \%CONFIG_DEFAULT;

	( undef, $ROOT_DIR, undef ) = File::Spec->splitpath ( $file_name );

	my $fh = new AIML::File;

	$fh->open ( "<$file_name" )		or die "Can't open $file_name\: $OS_ERROR";

	local $_;

	while ( $_ = $fh->getline() )
	{
		chomp;
		next	unless $_;
		next	if /#/;

		my ( $key, $value ) = split /\=/, $_, 2;

		$key =~ s/^$AIML_PROGRAM_MAGIC\.//;	#	!!!!!

		die "INACTIVE OPTION '$key' USED"	unless exists $VAR1->{$key};

		$value = $value eq 'false' ? 0 : $value eq 'true' ? 1 : $value;

		$VAR1->{$key} = $value;
	}

	$fh->close;

	#
	#	check and format
	#

	my ( $file, $string, $number );

	# Make sure the startup file actually exists.
	$file											= $VAR1->{'startup'};
	$file = File::Spec->rel2abs ( $file, $ROOT_DIR );
	die ( "File $file not found" )		unless fileExists ( $file );
	$VAR1->{'startup'}						= $file;

	# Make sure the knowledge file actually exists.
	$file											= $VAR1->{'runfile'};
	$file = File::Spec->rel2abs ( $file, $ROOT_DIR );
	die ( "File $file not found" )		unless fileExists ( $file, true );	#	create
	$VAR1->{'runfile'}						= $file;

	$number										= $VAR1->{'response-timeout'};
	$number = 1000								unless $number =~ /^\d+$/;
	$number = $number > 0 ? $number : 1000;
	$VAR1->{'response-timeout'}			= $number;

	$string										= $VAR1->{'infinite-loop-input'};
	patternFitNoWildcards ( \$string );
	$VAR1->{'infinite-loop-input'}		= $string;

	$number										= $VAR1->{'timeout-input'};
	patternFitNoWildcards ( \$number );
	$VAR1->{'timeout-input'}				= $number;

	$string										= $VAR1->{'connect-string'};
	patternFitNoWildcards ( \$string );
	$VAR1->{'connect-string'}				= $string;

#	$VAR1->{'deprecated-tags-warn'}		= $VAR1->{'deprecated-tags-support'} ? $VAR1->{'deprecated-tags-warn'} : false;

#	$number										= $VAR1->{'predicate-cache.max'};
#	$number = 5000								unless $number =~ /^\d+$/;
#	$number = $number > 0 ? $number : 5000;
#	$VAR1->{'predicate-cache.max'}		= $number;

#	$VAR1->{'console.match-trace'}		= $VAR1->{'console'} ? $VAR1->{'console.match-trace'} : false;

#	$number										= $VAR1->{'console.category-load-notify-interval'};
#	$number = 1000								unless $number =~ /^\d+$/;
#	$number = $number > 0 ? $number : 1000;
#	$VAR1->{'console.category-load-notify-interval'}	= $number;

#	$number										= $VAR1->{'targeting.targetskip'};
#	$number = 1									unless $number =~ /^\d+$/;
#	$number = $number < 1 ? 1 : $number;
#	$VAR1->{'targeting.targetskip'}		= $number;

	#
	#	prepare knowledge environment
	#
	$ENV{AIML_KNOWLEDGE_FILE} = $VAR1->{'runfile'}		unless $ENV{AIML_KNOWLEDGE_FILE};

	#
	#	that's all folks
	#
	if ( $DEBUG )
	{
		Readonly $CONFIG, $VAR1;
	}
	else
	{
		$CONFIG = $VAR1;
	}
}

=pod

=item * getName ( [ $name ] )

Returns the value of the requested property as string.

If property is not found, returns the property value or ''.

If no name is given, returns a reference to the complete config hash.

=cut

sub getConfig
{
	my $name = shift;

	return $CONFIG		unless $name;

#	my $value = $CONFIG->{emptydefault};

	my $value;

	if ( exists $CONFIG->{$name} )
	{
		$value = $CONFIG->{$name};
	}
	else
	{
		error ( "Unknown option '$name'" );
	}

	$value = ''		unless defined $value;

	return $value;
}

=pod

=item * getConfigPath ( [ $name | $filename ] )

Returns the absolute filepath of the requested property as string.

If property is not found, returns the full path of the given parameter.

If no name is given, returns the root directory of the installation.

=cut

sub getConfigPath
{
	my $name		= shift() ||  '';
	my $value;

	if ( exists $CONFIG->{$name} )
	{
		$value = $CONFIG->{$name};
	}
	else
	{
		$value = $name;
	}

	return File::Spec->rel2abs ( $value, $ROOT_DIR );
}

=pod

=back

=head1 AUTHOR / COPYRIGHT

Ernest Lergon, L<ernest@virtualitas.net>.

Copyright (c) 2002 by Ernest Lergon, VIRTUALITAS Inc.
L<http://www.virtualitas.net>

AIML - Artificial Intelligence Markup Language
Copyright (c) 1995-2002, A.L.I.C.E. AI Foundation
L<http://www.alicebot.org>

All Rights Reserved. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

If you have suggestions for improvement, please drop me a line.  If
you make improvements to this software, I ask that you please send me
a copy of your changes. Thanks.

=head1 SEE ALSO

L<AIML::Knowledge>, L<AIML::Memory>.

=for html <p><a href="http://search.cpan.org/search?dist=Readonly">Readonly.pm</a>.</p>

=cut

1;

__END__
