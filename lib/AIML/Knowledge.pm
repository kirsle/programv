=head1 NAME

AIML::Knowledge - interface to the AIML knowledge

=head1 SYNOPSIS

=over 4

=item * Auto-loading via httpd.conf

   PerlSetEnv  AIML_KNOWLEDGE_FILE   /home/alice/programv/data/knowledge.data
   PerlModule  AIML::Knowledge

=item * Manual loading via Perl-Skript

   use AIML::Knowledge;

   $AIML::Knowledge::DEBUG = 1;   # switch to readonly hash (slow)

   AIML::Knowledge::LOAD_AIML_KNOWLEDGE ( 'data/knowledge.data' );

=item * Interface

   use AIML::Knowledge;

   my @bot_list  = activeBots();              # ( 'Alice', TestBot', Heinz' )
   my $knowledge = getKnowledge ( 'Alice' );  # reference to the knowledge hash

See L<FUNCTIONS|functions> for more.

=back

=head1 DESCRIPTION

This module provides the static knowledge for an AIML chatbot. The
knowledge file to be read in is a dumped hash derived from an AIML
pattern database. See L<AIML::Loader> on how to create one.

The loading time of such a structure is very fast ( 40.000 categories
approx. 2,5 seconds on my machine).

See L<AIML::Graphmaster> for the internal structure of the knowledge.

=cut

package AIML::Knowledge;

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

use AIML::Common 0.09;

=head1 GLOBALS

   $AIML::Knowledge::DEBUG = 1;   # switch to readonly hash (slow)

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

=head1 FUNCTIONS

Following functions provide an interface to the config structure.

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * LOAD_AIML_KNOWLEDGE ( $filename )

This subroutine is automagically called during startup of a ModPerl-enabled Apache server.

Example for the configuration entries in httpd.conf:

   PerlSetEnv  AIML_KNOWLEDGE_FILE   /home/alice/programv/data/knowledge.data
   PerlModule  AIML::Handler

   <Location /talk>
      SetHandler  perl-script
      PerlHandler AIML::Handler
   </Location>

To use this module in a script:

=over 4

=item * define an environment variable

   i.e. Linux:
   AIML_KNOWLEDGE_FILE=/home/alice/programv/data/knowledge.data
   export AIML_KNOWLEDGE_FILE

   i.e. Windos:
   set AIML_KNOWLEDGE_FILE=/home/alice/programv/data/knowledge.data

and just say

   use AIML::Knowledge;

in the script.

=item * OR load manually from the script

   use AIML::Knowledge;

   AIML::Config::LOAD_AIML_CONFIG ( '/home/alice/programv/data/knowledge.data' );

=item * OR use the definition from the config file

   use AIML::Config;
   use AIML::Knowledge;

   AIML::Config::LOAD_AIML_CONFIG ( '/home/alice/programv/server.properties' );

   my $knowledge_file = AIML::Config::getConfigPath ( 'runfile' );    # returns i.e. '/home/alice/data/knowledge.data'

   AIML::Config::LOAD_AIML_KNOWLEDGE ( $knowledge_file );

See L<AIML::Config> for more information about how to automate config loading.

=back

See L<AIML::Memory> for a method interface.

=cut

my	$KNOWLEDGE	= {};

LOAD_AIML_KNOWLEDGE ( $ENV{AIML_KNOWLEDGE_FILE} )		if $ENV{AIML_KNOWLEDGE_FILE};	#	autoload for mod_perl...

sub LOAD_AIML_KNOWLEDGE																					#	call directly for shell...
{
	my $file_name = shift;

	#
	#	load knowledge
	#
	my $VAR1 = {};		#	for eval

	my $fh = new AIML::File;

	$fh->open ( "<$file_name" )		or die "Can't open $file_name\: $OS_ERROR";

	eval ( $fh->slurp() )				or die "Can't create knowledge: $EVAL_ERROR";

	$fh->close();

	#
	#	ensure existence of first level hash entries
	#
	my @main_keys	= ( 'bot', 'predicates', 'sentence-splitters', 'properties', 'substitutes', 'perl', 'aiml' );
	my @bots			= ();

	foreach my $id ( keys % { $VAR1 || {} } )
	{
		foreach my $key ( @main_keys )
		{
			next	if exists $VAR1->{$id}->{$key};

			$VAR1->{$id}->{$key} = {}	if $key ne 'perl';
			$VAR1->{$id}->{$key} = ''	if $key eq 'perl';
		}

		push @bots, $id;
	}

	#
	#	prepare sentence-splitters
	#
	foreach my $id ( @bots )
	{
		my @splitters = ();

		foreach my $key ( keys % { $VAR1->{$id}->{'sentence-splitters'} || {} } )
		{
			next		unless $VAR1->{$id}->{'sentence-splitters'}->{$key};

			$key =~ s/\\/\\\\/g;	#	1st !!
			$key =~ s/\)/\\)/g;
			$key =~ s/\(/\\(/g;
			$key =~ s/\{/\\{/g;
			$key =~ s/\}/\\}/g;
			$key =~ s/\[/\\[/g;
			$key =~ s/\]/\\]/g;
			$key =~ s/\./\\./g;
			$key =~ s/\?/\\?/g;
			$key =~ s/\+/\\+/g;
			$key =~ s/\-/\\-/g;
			$key =~ s/\*/\\*/g;
			$key =~ s/\_/\\_/g;
			$key =~ s/\;/\\;/g;
			$key =~ s/\:/\\:/g;

			push @splitters, $key;
		}

		$VAR1->{$id}->{'sentence-splitters'} = [ @splitters ];
	}

	#
	#	prepare substitutes
	#
	foreach my $id ( @bots )
	{
		my %substitutes = ();

		foreach my $item ( keys % { $VAR1->{$id}->{'substitutes'} || {} } )
		{
			next		unless $VAR1->{$id}->{'substitutes'}->{$item};

			foreach my $key ( keys % { $VAR1->{$id}->{'substitutes'}->{$item} || {} } )
			{
				my $entry = $VAR1->{$id}->{'substitutes'}->{$item}->{$key};

				next		unless defined $entry;

				$key =~ s/\\/\\\\/g;	#	1st !!
				$key =~ s/\)/\\)/g;
				$key =~ s/\(/\\(/g;
				$key =~ s/\{/\\{/g;
				$key =~ s/\}/\\}/g;
				$key =~ s/\[/\\[/g;
				$key =~ s/\]/\\]/g;
				$key =~ s/\./\\./g;
				$key =~ s/\?/\\?/g;
				$key =~ s/\+/\\+/g;
				$key =~ s/\-/\\-/g;
				$key =~ s/\*/\\*/g;
				$key =~ s/\_/\\_/g;
				$key =~ s/\;/\\;/g;
				$key =~ s/\:/\\:/g;

				$substitutes{$item}->{$key} = $entry;
			}
		}

		$VAR1->{$id}->{'substitutes'} = { %substitutes };
	}

	#
	#	prepare perl package
	#
	foreach my $id ( @bots )
	{
		my $snippet	= $VAR1->{$id}->{perl} || '';

		next	unless $snippet;

		eval ( $snippet );	#	load it!

		if ( $EVAL_ERROR )
		{
			my @lines = split /\n/, $snippet;
			my $i = 0;
			map { $i++; $_ = "$i\:\t" . $_ . "\n"; } @lines;

			$snippet = "@lines";

			die "$EVAL_ERROR\n$snippet";
		}
		else
		{
			$VAR1->{$id}->{perl} = '';		#	we have evaluated it and don't need it any further - really ?
		}
	}

	#
	#	that's all folks
	#
	if ( $DEBUG )
	{
#		Readonly::Tree %$KNOWLEDGE, %$VAR1;
		Readonly $KNOWLEDGE, $VAR1;
	}
	else
	{
		$KNOWLEDGE = $VAR1;
	}
}

=pod

=item * activeBots ( )

Returns a list of botids as array of strings.

=cut

sub activeBots
{
	my @bots = ();

	foreach my $id ( keys % { $KNOWLEDGE || {} } )
	{
		next	unless $KNOWLEDGE->{$id}->{bot}->{enabled};

		push @bots, $id;
	}

	return @bots;
}

=pod

=item * getKnowledge ( $bot_id )

Returns a reference to the hash containing the complete knowledge of
this bot. Better use the following subs to access special parts of the
knowledge.

=cut

sub getKnowledge
{
	my $bot_id	= shift;

	return undef	unless $bot_id;
	return undef	unless defined $KNOWLEDGE;
	return undef	unless exists $KNOWLEDGE->{$bot_id};

	return $KNOWLEDGE->{$bot_id};									#	hash !
}

=pod

=item * getName ( $bot_id )

Returns the name or id of the requested bot as string.

=cut

sub getName
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return ''	unless $bot;

	return ( $bot->{'properties'}->{'name'} || $bot->{'bot'}->{'id'} || '' );	#	string !
}

=pod

=item * getPredicates ( $bot_id )

Returns a reference to the predicates hash.

=cut

sub getPredicates
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'predicates'} || {} );
}

=pod

=item * copyPredicates ( $bot_id )

Returns a reference to a writeable copy of the predicates hash.

=cut

sub copyPredicates
{
	my $bot_id	= shift;

	my $ro_pred = getPredicates ( $bot_id );

	my $VAR1 = Dumper ( $ro_pred );

	my $rw_pred = eval ( $VAR1 )	or die $EVAL_ERROR;

	return $rw_pred;
}

=pod

=item * getSentenceSplitters ( $bot_id )

Returns a reference to the sentence splitters array.

=cut

sub getSentenceSplitters
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return ()	unless $bot;

	return ( $bot->{'sentence-splitters'} || [] );		#	array !
}

=pod

=item * getProperties ( $bot_id )

Returns a reference to the properties hash.

=cut

sub getProperties
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'properties'} || {} );
}

=pod

=item * getSubstitutesInput ( $bot_id )

Returns a reference to the substitutes for input hash.

=cut

sub getSubstitutesInput
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'substitutes'}->{'input'} || {} );
}

=pod

=item * getSubstitutesPerson ( $bot_id )

Returns a reference to the substitutes for person hash.

=cut

sub getSubstitutesPerson
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'substitutes'}->{'person'} || {} );
}

=pod

=item * getSubstitutesPerson2 ( $bot_id )

Returns a reference to the substitutes for person2 hash.

=cut

sub getSubstitutesPerson2
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'substitutes'}->{'person2'} || {} );
}

=pod

=item * getSubstitutesGender ( $bot_id )

Returns a reference to the substitutes for gender hash.

=cut

sub getSubstitutesGender
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'substitutes'}->{'gender'} || {} );
}

=pod

=item * getPerl ( $bot_id )

Returns the perl package source to be evaluated as string.

=cut

sub getPerl
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return ''	unless $bot;

	return ( $bot->{'perl'} || '' );							#	string !
}

=pod

=item * getPatterns ( $bot_id )

Returns a reference to the patterns hash (level 0).

=cut

sub getPatterns
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return {}	unless $bot;

	return ( $bot->{'aiml'}->{'matches'} || {} );		#	hash !
}

=pod

=item * getTemplates ( $bot_id )

Returns a reference to the templates array.

=cut

sub getTemplates
{
	my $bot_id	= shift;

	my $bot		= getKnowledge ( $bot_id );

	return []	unless $bot;

	return ( $bot->{'aiml'}->{'templates'} || [] );		#	array !
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

L<AIML::Config>, L<AIML::Memory>, L<AIML::Graphmaster>,

=for html <p><a href="http://search.cpan.org/search?dist=Readonly">Readonly.pm</a>.</p>

=cut

1;

__END__
