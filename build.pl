#!/usr/bin/perl

BEGIN
{
	use Getopt::Std;
	use vars qw ( $opt_d $opt_f );

	getopts ( "df:" );

	$::CONFIG_FILE	= $opt_f ? $opt_f : './server.properties';

	$::DEBUG = $opt_d ? 1 : 0;							#	special debug cases:

	$AIML::Common::DEBUG		= 1 && $::DEBUG;		#	1 = die on warnings
	$AIML::Config::DEBUG		= 1 && $::DEBUG;		#	1 = switch to readonly hash (slow)
	$AIML::File::DEBUG		= 1 && $::DEBUG;		#
	$AIML::Parser::DEBUG		= 1 && $::DEBUG;		#	1 = logs parsing (huge output)
	$AIML::Loader::DEBUG		= 1 && $::DEBUG;		#	1 = logs parsing (huge output)
	$AIML::Unicode::DEBUG	= 1 && $::DEBUG;		#

	$| = 1;

	use lib './lib';
}

use strict;
use warnings;

use Time::HiRes qw ( gettimeofday tv_interval );
use EnglishSave;

use AIML::Common 0.09;
use AIML::Config 0.09;
use AIML::Loader 0.09;

print "\nAIML Builder version $AIML::Loader::VERSION\n";
print "Reading config from $::CONFIG_FILE...\n";

my $server_prop_file = File::Spec->rel2abs ( $::CONFIG_FILE );

AIML::Config::LOAD_AIML_CONFIG ( $server_prop_file );

my $loader = new AIML::Loader();

die ( "Can't create loader" )	unless $loader;

##############################

my $file_name			= AIML::Config::getConfigPath ( 'startup' );
my $know_file_name	= AIML::Config::getConfig ( 'runfile' );
my $log_file_name		= $AIML_LOG_FILE;

print "Processing $file_name...\n";
print "Creating knowledge file $know_file_name...\n";

my ( @t0, $t1 );

@t0 = gettimeofday();

my $success = $loader->parseFile ( $file_name );

$t1 = tv_interval ( \@t0 );

print "\n...";
print "sucessfully "	if $success;
print "parsed in $t1 secs\n";

if		( $loader->errors() )
{
	print "\nThere have been errors! More information might be in $log_file_name.\n";
	print "\nKnowledge file $know_file_name NOT saved!\n";

	print "\n\nWARNINGS:\n",	$loader->warningString()	|| "\tnone\n";
	print "\n\nERRORS:\n",		$loader->errorString()		|| "\tnone\n";

	print "\n";

	exit;
}
elsif	( $loader->warnings() )
{
	print "\nThere have been warnings! More information might be in $log_file_name.\n";
	print "\nKnowledge file $know_file_name might not work as expected.\n";

	print "\n\nWARNINGS:\n",	$loader->warningString()	|| "\tnone\n";
	print "\n\nERRORS:\n",		$loader->errorString()		|| "\tnone\n";

	print "\n";
}
else
{
	print "\n\nWARNINGS:\n",	$loader->warningString()	|| "\tnone\n";
	print "\n\nERRORS:\n",		$loader->errorString()		|| "\tnone\n";

	print "\n";
}

##############################

@t0 = gettimeofday();

$loader->saveKnowledge ( $know_file_name );

$t1 = tv_interval ( \@t0 );

undef $loader;

print "\nKnowledge file $know_file_name saved in $t1 sec\n";

##############################

my $stat_file	= './stats.pl';
@ARGV				= ( '-f', $::CONFIG_FILE );

unless ( my $return = do $stat_file )
{
	warn "couldn't parse $stat_file: $EVAL_ERROR"	if $EVAL_ERROR;
	warn "couldn't do $stat_file: $OS_ERROR"			unless defined $return;
	warn "couldn't run $stat_file"						unless $return;
}

1;

__END__
