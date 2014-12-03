#!/usr/bin/perl

BEGIN
{
	use Getopt::Std;
	use vars qw ( $opt_f );

	getopts ( "f:" );

	$::CONFIG_FILE	= $opt_f ? $opt_f : './server.properties';

	$| = 1;

	use lib './lib';
}

use strict;
use warnings;

use Time::HiRes qw ( gettimeofday tv_interval );
use EnglishSave;

use AIML::Common 0.07;
use AIML::Config 0.07;

print "\nAIML Statistic version $AIML::Config::VERSION\n";
print "Reading config from $::CONFIG_FILE...\n";

my $server_prop_file = File::Spec->rel2abs ( $::CONFIG_FILE );

AIML::Config::LOAD_AIML_CONFIG ( $server_prop_file );

my $file_name			= AIML::Config::getConfigPath ( 'startup' );
my $know_file_name	= AIML::Config::getConfig ( 'runfile' );
my $log_file_name		= $AIML_LOG_FILE;

print "Reading knowledge file $know_file_name...\n";

my ( @t0, $t1 );

@t0 = gettimeofday();

my $root = readRoot ( $know_file_name );

$t1 = tv_interval ( \@t0 );

print "\nKnowledge file $know_file_name loaded in $t1 sec\n";

print "\nStatistics:\n";
print "====================================================================\n";

foreach my $bot ( sort keys %$root )
{
	print "\nTHE BOT '$bot':\n";

	my $enabled = 0;

	foreach my $key ( sort keys % { $root->{$bot} || {} } )
	{
		next	if $key eq 'aiml';

		if ( $key eq 'bot' )
		{
			print "bot $root->{$bot}->{$key}->{id} is ";

			$enabled = $root->{$bot}->{$key}->{enabled};

			if ( $enabled ) 	{ print "enabled\n"; }
			else					{ print "NOT enabled\n"; }
		}
		elsif ( $key eq 'perl' )
		{
			print "bot perl package is ";

			if ( $root->{$bot}->{$key} gt '' )	{ print "used\n"; }
			else											{ print "NOT used\n"; }
		}
		elsif ( $key eq 'substitutes' )
		{
			my $count = scalar keys % { $root->{$bot}->{$key} || {} };

			print "$count\t$key\n";

			foreach my $subkey ( sort keys % { $root->{$bot}->{$key} || {} } )
			{
				my $count = scalar keys % { $root->{$bot}->{$key}->{$subkey} || {} };

				print "\t$count\t$subkey\n";
			}
		}
		else
		{
			my $count = scalar keys % { $root->{$bot}->{$key} || {} };

			print "$count\t$key\n";
		}
	}

	if ( $enabled )
	{
		print "--------------------------------------------------------------------\n";

		my $brain = $root->{$bot}->{aiml};

		my $totals =
		{
			'<levels>'		=> 0,
			'<words>'		=> 0,
			'<that>'			=> 0,
			'<topic>'		=> 0,
			'<template>'	=> 0,
			'<pattern>'		=> 0,
			'<filled>'		=> {},
			'<unique>'		=> {},
			'<orphaned>'	=> {},
		};

		countNew ( $brain, $totals )	if $brain;

		print "\nTOTAL:\n";
	#	print $totals->{'<levels>'		}, "\tlevels\n";
	#	print $totals->{'<words>'		}, "\tfirst words in pattern\n";
		print $totals->{'<words>'		}, "\ttop level words in pattern\n";
	#	print $totals->{'<that>'		}, "\tthats\n";
	#	print $totals->{'<topic>'		}, "\ttopics\n";
		print $totals->{'<pattern>'	}, "\tpatterns\n";
		print $totals->{'<template>'	} - 1, "\ttemplates\n";				#	we have a ZERO TEMPLATE...

		print $totals->{'<template>'} - $totals->{'<pattern>'} - 1, "\ttemplates - patterns\t(= duplicate patterns)";

		if ( AIML::Config::getConfig ( 'merge' ) )	{ print " merged\n"; }
		else														{ print " skipped\n"; }

		print scalar keys % { $totals->{'<unique>'} || {} }, "\tunique patterns\t\t(?= patterns)\n";

		my $orphaned = 0;

		for ( my $tpos = 1; $tpos < $totals->{'<template>'}; $tpos++ )	#	we have a ZERO TEMPLATE...
		{
			$orphaned++		unless $totals->{'<orphaned>'}->{$tpos};
		}

		print "$orphaned\torphaned templates\t(?= duplicate patterns)\n";

		my $found	= 0;
		my $text		= '';

		foreach my $pattern ( sort keys % { $totals->{'<unique>'} || {} } )
		{
			if ( $totals->{'<unique>'}->{$pattern} > 1 )
			{
				$text .= "'$pattern'\n";
				$found++;
			}
		}

		if ( $found )
		{
			print "\nWARNING: DUPLICATE PATTERNS!\n";

			print $text;

			print "$found duplicate patterns found\n";
		}
	}

	print "====================================================================\n";
}

#################

sub countNew
{
	my ( $new_brain, $totals ) = @_;

	foreach my $key ( keys % { $new_brain->{matches} || {} } )
	{
		$totals->{'<words>'}++;

		my $patcnt = scalar @ { $new_brain->{matches}->{$key} || [] };

		$totals->{'<pattern>'}	+= $patcnt;

		$totals->{'<filled>'}->{$patcnt}++;

		foreach my $item ( @ { $new_brain->{matches}->{$key} || [] } )
		{
			my @line = split /<pos>/, $item;

			my $pattern = $key . ' ' . $line[0];

			my $tpos		= 0 + $line[1];

			$totals->{'<unique>'}->{$pattern}++;

			$totals->{'<orphaned>'}->{$tpos}++;
		}
	}

	$totals->{'<template>'}	= scalar @ { $new_brain->{templates} || [] };
}

sub readRoot
{
	my $file = shift;

	local $/;	#	slurp
	no strict;	#	for eval

	open ( INFILE, "<$file" )		or die "Can't open $file\: $OS_ERROR";

	my $root = undef;

	$root = eval ( <INFILE> )		or die "Can't create brain: $EVAL_ERROR";

	close INFILE;

	return $root;
}

1;

__END__
