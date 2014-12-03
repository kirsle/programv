=head1 NAME

AIML::Graphmaster - AIML pattern matching module

=head1 SYNOPSIS

   package AIML::Responder;

   use AIML::Graphmaster;
   use AIML::Parser;

   @ISA = qw ( AIML::Parser AIML::Graphmaster );

   #   other methods...

   sub getMatchResult
   {
      my $self    = shift;
      my $input   = shift() || '';
      my $that    = shift() || '*';
      my $topic   = shift() || '*';

      #   error checks etc. omitted

      my $line         = "$input <that> $that <topic> $topic <pos>";   #   <botid>
      my $root         = $self->memo->getPatterns();
      my $star         = '';
      my $path         = '';
      my $matchState   = '<input>';

      my $pattern      = $self->match ( $root, $root, $line, $star, $path, $matchState ) || 0;

      return $self->memo->getTemplates()->[$pattern];
   }

=head1 DESCRIPTION

This module provides the methods for the pattern matching
functionality of an ALICE and is not an object class for itself.

I<This might be changed in future releases!>.

See L<AIML::Responder> for usage.

=cut

package AIML::Graphmaster;

use strict;
use warnings;
no warnings "recursion";

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use AIML::Common 0.09;
use AIML::Unicode 0.09;

=head1 GLOBALS

   $AIML::Graphmaster::DEBUG = 1;

Logs all matching activities (huge output).

=head1 EXPORT

=head2 Public Attributes

None.

=head2 Public Constructors

None.

=head2 Public Methods

C<match>

=cut

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=head2 Main Methods

=over 4

=cut

=pod

=item * constructNode ( \@patterns, $parent ) I<PRIVATE>

This private method creates a Graphmaster node on the fly.

Perl's arrays and hashes are fast but not memory efficient. There is a
remarkable overhead of internal flags and attributes, which lets the
memory usage explode, especially for an AIML knowledge base with
40.000 or more categories. Therefore the patterns are not stored
completely in a tree on loading as the classical Graphmaster algorithm
suggests, but only the first word of a pattern is used as hash entry
and the rest is stored in an array. Subsequent nodes are constructed
similar on the fly. All leaves - aka templates - are stored in one
array. The complete structure is held in memory (see
L<AIML::Knowledge>).

This is a simple example with four categories:

The aiml categories

   <category>
      <pattern>* WAS *</pattern>
      <template>When was this exactly?</template>
   </category>

   <category>
      <pattern>* YOU FOR WHAT</pattern>
      <template><srai>WHAT ARE YOU <star/> FOR</srai></template>
   </category>

   <category>
      <pattern>ASK ME WHAT * IS</pattern>
      <template>OK, what is <person/>?</template>
   </category>

   <category>
      <pattern>ASK ME WHAT MY * IS</pattern>
      <template>OK, what is your <person/>?</template>
   </category>

become

   $root =
   {
      'patterns' =>
      {
         '*' =>
            [
               'WAS * <that> * <topic> * <pos> 1',
               'YOU FOR WHAT <that> * <topic> * <pos> 2',
            ],
         'ASK' =>
            [
               'ME WHAT * IS <that> * <topic> * <pos> 3',
               'ME WHAT MY * IS <that> * <topic> * <pos> 4',
            ],
      },
      'templates' =>
         [
            'When was this exactly?',                  # pos 1
            '<srai>WHAT ARE YOU <star/> FOR</srai>',   # pos 2
            'OK, what is <person/>?',                  # pos 3
            'OK, what is your <person/>?',             # pos 4
         ]
   }

To match the input 'Ask me what he is', we find the root entry C<ASK>
first and construct the next node from the rest array before calling
C<match> recursively. The node returned by C<constructNode> looks
like:

   $node1 =
   {
      'ME' =>
         [
            'WHAT * IS <that> * <topic> * <pos> 3',
            'WHAT MY * IS <that> * <topic> * <pos> 4',
         ],
      '<parent>' => 'ASK',
   }

and will match the second word C<ME>.

The next node looks like:

   $node2 =
   {
      'WHAT' =>
         [
            '* IS <that> * <topic> * <pos> 3',
            'MY * IS <that> * <topic> * <pos> 4',
         ],
      '<parent>' => 'ME',
   }

Further recursive node construction leads to the matching template
number 3 in the end.

=cut

sub constructNode
{
	my $self		= shift;
	my $array	= shift;
	my $parent	= shift;

	$parent = ''	unless defined $parent;

	my $hash		= {};

	my ( $first, $rest, @words, $len );

	my $height = 0;

	foreach my $item ( @$array )
	{
		( $first, $rest ) = split / /, $item, 2;

		if ( $rest )
		{
			if ( not exists $hash->{$first} )
			{
				$hash->{$first} = [ $rest ];
			}
			else
			{
				push @ { $hash->{$first} }, $rest;
			}
		}
	}

	$hash->{'<parent>'} = $parent;
	$hash->{'<height>'} = $height;

	return $hash;
}

=pod

=item * match ( $node, $parent, $input, $star, $path, $matchState [, $level ] )

Searches recursively for a match in the AIML knowledge base to a given path.

The parameters:

$node	Hashref	The node where we start matching
$parent	Hashref	The parent of the node where we start matching
$input	String	The input path (possibly a substring of the original)
$star	String	Contents absorbed by a wildcard
$path	String	The path matched so far
$matchState	String	State variable tracking which part of the path we're in
$level	Integer	Level of recursion - default 0

Returns the number of the matching category, 0 otherwise.

See L<SYNOPSIS|synopsis> for a simple example, how to call C<match>,
and L<AIML::Responder> for a real implementation.

=cut

#	/**
#	*  <p>
#	*  Searches for a match in the <code>Graphmaster</code> to a given path.
#	*  </p>
#	*  <p>
#	*  This is a low-level prototype, used for internal recursion.
#	*  </p>
#	*
#	*  @see #match(String, String, String)
#	*
#	*  @param nodemapper   the nodemapper where we start matching
#	*  @param parent       the parent of the nodemapper where we start matching
#	*  @param input        the input path (possibly a sublist of the original)
#	*  @param star         contents absorbed by a wildcard
#	*  @param path         the path matched so far
#	*  @param matchState   state variable tracking which part of the path we're in
#	*  @param expiration	when this response process expires
#	*
#	*  @return the resulting <code>Match</code> object
#	*/
#	private static Match match(Nodemapper nodemapper, Nodemapper parent,
#					 List input, String star, StringBuffer path,
#					 int matchState, long expiration)

sub match
{
	my $self			= shift;
	my $node			= shift;
	my $parent		= shift;
	my $input		= shift;
	my $star			= shift;
	my $path			= shift;
	my $matchState	= shift;
	my $level		= shift() || 0;

	if ( time >= $self->{_time_out} )
	{
		return 0;
	}

	my $in_indent	= "\\";
	my $out_indent	= '/';

	if ( $DEBUG )
	{
		$in_indent .= "\\" x ( $level - 1 )	if $level;
		$in_indent .= "$level"					if $level;

		$out_indent .= '/' x ( $level - 1 )	if $level;
		$out_indent .= "$level"					if $level;

		$in_indent .= "\t";
		$out_indent .= "\t";

		debug
			$in_indent,
			" input: '$input'",
			" star: '$star'",
			" path: '$path'",
			" state: '$matchState'";
	}

#	// Return null if expiration has been reached.
#	if (System.currentTimeMillis() >= expiration)
#	{
#		return null;
#	}
#
#	// Halt matching if this node is higher than the length of the input.
#	if (input.size() < nodemapper.getHeight())
#	{
#		return null;
#	}

#	// The match object that will be returned.
#	Match match;

	my $match = 0;

#	// If no more tokens in the input, see if this is a template.
#	if (input.size() == 0)
#	{
#		// If so, the star is from the topic, and the path component is the topic.
#		if (nodemapper.containsKey(TEMPLATE))
#		{
#			 //Trace.devinfo("nodemapper contains template");
#			 match = new Match();
#			 match.setBotID(path.toString());
#			 match.setNodemapper(nodemapper);
#			 return match;
#		}
#		else
#		{
#			 return null;
#		}
#	}

#
#	missing topic_star !!
#
#	if ( $input eq '<botid>' )
#	{
#		if ( exists $node->{'<pos>'} )
#		{
#			my $num = $node->{'<pos>'}->[0] || 0;
#
#			$match = 0 + $num;
#
#			debug ( $out_indent, "MATCHED 1 '$path'" )		if $DEBUG;
#			return $match;
#		}
#		else
#		{
#			debug ( $out_indent, "NO MATCH 1 FOR '$path'" )		if $DEBUG;
#			return 0;
#		}
#	}

#	[Thu May 30 18:49:27 2002] [debug] node=$VAR1 = {
#          '<height>' => 0,
#          '<parent>' => '<pos>'
#        };
#
#	[Thu May 30 18:49:27 2002] [debug] parent=$VAR1 = {
#          '<pos>' => [
#                       '41221'
#                     ],
#          '<height>' => 0,
#          '<parent>' => 'TOPIC'
#        };

	if ( not $input )
	{
		if ( $node->{'<parent>'} eq '<pos>' )
		{
#			debug ( 'node=', Dumper ( $node ) );
#			debug ( 'parent=', Dumper ( $parent ) );

			my $num = $parent->{'<pos>'}->[0] || 0;

			$match = 0 + $num;

#			debug ( $out_indent, "MATCHED 1 '$path'" )		if $DEBUG;

			if ( $DEBUG )
			{
				my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
				my $match_path		= @match_stack ? $match_stack[-1] : '';

				debug ( $out_indent, "1 MATCHED '$path' -> '$match_path'" );
			}

			return $match;
		}
		else
		{
#			debug ( $out_indent, "NO MATCH 1 FOR '$path'" )		if $DEBUG;

			if ( $DEBUG )
			{
				my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
				my $match_path		= @match_stack ? $match_stack[-1] : '';

				debug ( $out_indent, "1 NO MATCH FOR '$path' -> '$match_path'" );
			}

			return 0;
		}
	}


#	// Take the first word of the input as the head.
#	String head = ((String)input.get(0)).trim();
#
#	// Take the rest as the tail.
#	List tail = input.subList(1, input.size());

	my @tail	= split / /, $input;
	my $head	= shift @tail;

	my $upper_head = uppercase ( $head );	#	!!!


#	/*
#		See if this nodemapper has a _ wildcard.
#		_ comes first in the AIML "alphabet".
#	*/
#	if (nodemapper.containsKey(UNDERSCORE))
#	{
#		// If so, construct a new path from the current path plus a _ wildcard.
#		StringBuffer newPath = new StringBuffer();
#		synchronized(newPath)
#		{
#			 newPath.append(path);
#			 newPath.append(' ');
#			 newPath.append('_');
#		}
#
#		// Try to get a match with the tail and this new path, using the head as the star.
#		match = match((Nodemapper)nodemapper.get(UNDERSCORE), nodemapper,
#					  tail, head, newPath, matchState, expiration);
#
#	// If that did result in a match,
#		if (match != null)
#		{
#			 // capture and push the star content appropriate to the current match state.
#			 switch (matchState)
#			 {
#				  case S_INPUT :
#						if (star.length() > 0)
#						{
#							 match.pushInputStar(star);
#						}
#						break;
#
#				  case S_THAT :
#						if (star.length() > 0)
#						{
#							 match.pushThatStar(star);
#						}
#						break;
#
#				  case S_TOPIC :
#						if (star.length() > 0)
#						{
#							 match.pushTopicStar(star);
#						}
#						break;
#			 }
#			 // ...and return this match.
#			 return match;
#		}
#	}

	if ( exists $node->{'_'} )
	{
		my $newPath = $path ? $path . ' ' . '_' : '_';	#	BUGFIX

		my $newNode = $self->constructNode ( $node->{'_'}, '_' );

		$level++;
		$match = $self->match ( $newNode, $node, "@tail", $head, $newPath, $matchState, $level );
		$level--;

		if ( $match )
		{
			SWITCH:
			{
				for ( $matchState )
				{
					/^<input>$/	&& do {
										if ( length $star > 0 )
										{
											#	access to AIML::Responder::memo works, but is not clean OO...
											#
											#	maybe we should use a match-object here too...
											#
											push @ { $self->memo->{_inputstar_stack} }, $star;
										}
										last SWITCH;
									};
					/^<that>$/	&& do {
										if ( length $star > 0 )
										{
											push @ { $self->memo->{_thatstar_stack} }, $star;
										}
										last SWITCH;
									};
					/^<topic>$/	&& do {
										if ( length $star > 0 )
										{
											push @ { $self->memo->{_topicstar_stack} }, $star;
										}
										last SWITCH;
									};
				}
			}

#			debug ( $out_indent, "MATCHED 2 '$path'" )		if $DEBUG;

			if ( $DEBUG )
			{
				my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
				my $match_path		= @match_stack ? $match_stack[-1] : '';

				debug ( $out_indent, "2 MATCHED '$path' -> '$match_path'" );
			}

			return $match;
		}
	}

#	/*
#		The nodemapper may have contained a _, but this led to no match.
#		Or it didn't contain a _ at all.
#	*/
#	if (nodemapper.containsKey(head))
#	{
#		/*
#			 Check now whether this is a marker for the <that>,
#			 <topic> or <botid> segments of the path.  If it is,
#			 set the match state variable accordingly.
#		*/
#		if (head.startsWith(MARKER_START))
#		{
#			 if (head.equals(THAT))
#			 {
#				  matchState = S_THAT;
#			 }
#			 else if (head.equals(TOPIC))
#			 {
#				  matchState = S_TOPIC;
#			 }
#			 else if (head.equals(BOTID))
#			 {
#				  matchState = S_BOTID;
#			 }
#
#			 // Now try to get a match using the tail and an empty star and empty path.
#			 match = match((Nodemapper)nodemapper.get(head), nodemapper,
#								tail, EMPTY_STRING, new StringBuffer(), matchState, expiration);
#
#			 // If that did result in a match,
#			 if (match != null)
#			 {
#				  // capture and push the star content appropriate to the *previous* match state.
#				  switch (matchState)
#				  {
#						case S_THAT :
#							 if (star.length() > 0)
#							 {
#								  match.pushInputStar(star);
#							 }
#							 // Remember the pattern segment of the matched path.
#							 match.setPattern(path.toString());
#							 break;
#
#						case S_TOPIC :
#							 if (star.length() > 0)
#							 {
#								  match.pushThatStar(star);
#							 }
#							 // Remember the that segment of the matched path.
#							 match.setThat(path.toString());
#							 break;
#
#						case S_BOTID :
#							 if (star.length() > 0)
#							 {
#								  match.pushTopicStar(star);
#							 }
#							 // Remember the topic segment of the matched path.
#							 match.setTopic(path.toString());
#							 break;
#
#				  }
#				  // ...and return this match.
#				  return match;
#			 }
#		}
#		/*
#			 In the case that the nodemapper contained the head,
#			 but the head was not a marker, it must be that the
#			 head is a regular word.  So try to match the rest of the path.
#		*/
#		else
#		{
#			 // Construct a new path from the current path plus the head.
#			 StringBuffer newPath = new StringBuffer();
#			 synchronized(newPath)
#			 {
#				  newPath.append(path);
#				  newPath.append(' ');
#				  newPath.append(head);
#			 }
#
#			 // Try to get a match with the tail and this path, using the current star.
#			 match = match((Nodemapper)nodemapper.get(head), nodemapper,
#								tail, star, newPath, matchState, expiration);
#
#			 // If that did result in a match, just return it.
#			 if (match != null)
#			 {
#				  return match;
#			 }
#		}
#	}

#	if ( exists $node->{$head} )
	if ( exists $node->{$upper_head} or exists $node->{$head} )	#	XXX or <xxx> !!!
	{
		if ( $head =~ /^</ )
		{
			 if ( $head eq '<that>' )
			 {
				  $matchState = $head;
			 }
			 elsif ( $head eq '<topic>' )
			 {
				  $matchState = $head;
			 }
#			 elsif ( $head eq '<botid>' )
			 elsif ( $head eq '<pos>' )
			 {
				  $matchState = $head;
			 }
			 else
			 {
			 	die 'We should never come here...';
			 }

			my $newNode = $self->constructNode ( $node->{$head}, $head );
			my $newPath = '';

			$level++;
			$match = $self->match ( $newNode, $node, "@tail", '', $newPath, $matchState, $level );
			$level--;

			if ( $match )
			{
				SWITCH:
				{
					for ( $matchState )
					{
						/^<that>$/	&& do {
											if ( length $star > 0 )
											{
												push @ { $self->memo->{_inputstar_stack} }, $star;

											}
											push @ { $self->memo->{_pattern_stack} }, $path;
											last SWITCH;
										};
						/^<topic>$/	&& do {
											if ( length $star > 0 )
											{
												push @ { $self->memo->{_thatstar_stack} }, $star;
											}
											push @ { $self->memo->{_that_stack} }, [ $path ];
											last SWITCH;
										};
#						/^<botid>$/	&& do {
						/^<pos>$/	&& do {
											if ( length $star > 0 )
											{
												push @ { $self->memo->{_topicstar_stack} }, $star;
											}
											push @ { $self->memo->{_topic_stack} }, [ $path ];
											last SWITCH;
										};
					 	die 'We should never come here...';
					}
				}

#				debug ( $out_indent, "MATCHED 3 '$path'" )		if $DEBUG;

				if ( $DEBUG )
				{
					my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
					my $match_path		= @match_stack ? $match_stack[-1] : '';

					debug ( $out_indent, "3 MATCHED '$path' -> '$match_path'" );
				}

				return $match;
			 }
		}
		else
		{
			my $newPath = $path ? $path . ' ' . $head : $head;	#	BUGFIX

#			my $newNode = $self->constructNode ( $node->{$head}, $head );
			my $newNode = $self->constructNode ( $node->{$upper_head}, $upper_head );

			$level++;
			$match = $self->match ( $newNode, $node, "@tail", $star, $newPath, $matchState, $level );
			$level--;

			if ( $match )
			{
#				debug ( $out_indent, "MATCHED 4 '$path'" )		if $DEBUG;

				if ( $DEBUG )
				{
					my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
					my $match_path		= @match_stack ? $match_stack[-1] : '';

					debug ( $out_indent, "4 MATCHED '$path' -> '$match_path'" );
				}

				return $match;
			}
		}
	}

#	/*
#		The nodemapper may have contained the head, but this led to no match.
#		Or it didn't contain the head at all.  In any case, check to see if
#		it contains a * wildcard.  * comes last in the AIML "alphabet".
#	*/
#	if (nodemapper.containsKey(ASTERISK))
#	{
#		// If so, construct a new path from the current path plus a * wildcard.
#		StringBuffer newPath = new StringBuffer();
#		synchronized(newPath)
#		{
#			 newPath.append(path);
#			 newPath.append(' ');
#			 newPath.append('*');
#		}
#
#		// Try to get a match with the tail and this new path, using the head as the star.
#		match = match((Nodemapper)nodemapper.get(ASTERISK), nodemapper,
#						  tail, head, newPath, matchState, expiration);
#
#		// If that did result in a match,
#		if (match != null)
#		{
#			 // capture and push the star content appropriate to the current match state.
#			 switch (matchState)
#			 {
#				  case S_INPUT :
#						if (star.length() > 0)
#						{
#							 match.pushInputStar(star);
#						}
#						break;
#
#				  case S_THAT :
#						if (star.length() > 0)
#						{
#							 match.pushThatStar(star);
#						}
#						break;
#
#				  case S_TOPIC :
#						if (star.length() > 0)
#						{
#							 match.pushTopicStar(star);
#						}
#						break;
#			 }
#			 // ...and return this match.
#			 return match;
#		}
#	}
#
#	/*
#		The nodemapper has failed to match at all: it contains neither _, nor the head,
#		nor *.  However, if it itself is a wildcard, then the match continues to be
#		valid and can proceed with the tail, the current path, and the star content plus
#		the head as the new star.
#	*/
#	if (nodemapper.equals(parent.get(ASTERISK)) || nodemapper.equals(parent.get(UNDERSCORE)))
#	{
#		return match(nodemapper, parent, tail, star + SPACE + head, path, matchState, expiration);
#	}
#
#	/*
#	If we get here, we've hit a dead end; this null match will be passed back up the
#	recursive chain of matches, perhaps even hitting the high-level match method
#	(which will react by throwing a NoMatchException), though this is assumed to be
#	the rarest occurence.
#	*/
#	return null;
#}

	if ( exists $node->{'*'} )
	{
		my $newPath = $path ? $path . ' ' . '*' : '*';	#	BUGFIX

		my $newNode = $self->constructNode ( $node->{'*'}, '*' );

		$level++;
		$match = $self->match ( $newNode, $node, "@tail", $head, $newPath, $matchState, $level );
		$level--;

		if ( $match )
		{
			SWITCH:
			{
				for ( $matchState )
				{
					/^<input>$/	&& do {
										if ( length $star > 0 )
										{
											push @ { $self->memo->{_inputstar_stack} }, $star;
										}
										last SWITCH;
									};
					/^<that>$/	&& do {
										if ( length $star > 0 )
										{
											push @ { $self->memo->{_thatstar_stack} }, $star;
										}
										last SWITCH;
									};
					/^<topic>$/	&& do {
										if ( length $star > 0 )
										{
											push @ { $self->memo->{_topicstar_stack} }, $star;
										}
										last SWITCH;
									};
				}
			}

#			debug ( $out_indent, "MATCHED 5 '$path'" )		if $DEBUG;

			if ( $DEBUG )
			{
				my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
				my $match_path		= @match_stack ? $match_stack[-1] : '';

				debug ( $out_indent, "5 MATCHED '$path' -> '$match_path'" );
			}

			return $match;
		 }
	}

	if ( ( ( $node->{'<parent>'} || '' ) eq '*' ) or ( ( $node->{'<parent>'} || '' ) eq '_' ) )
	{
		my $newStar	= $star ? $star . ' ' . $head : $head;	#	BUGFIX

		$level++;
		$match = $self->match ( $node, $parent, "@tail", $newStar, $path, $matchState, $level );
		$level--;

#		debug ( $out_indent, "MATCHED 6 '$path'" )			if $DEBUG and $match;
#		debug ( $out_indent, "NO MATCH 6 FOR '$path'" )		if $DEBUG and not $match;

		if ( $DEBUG )
		{
			my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
			my $match_path		= @match_stack ? $match_stack[-1] : '';

			if ( $match )
			{
				debug ( $out_indent, "6 MATCHED '$path' -> '$match_path'" );
			}
			else
			{
				debug ( $out_indent, "6 NO MATCH FOR '$path' -> '$match_path'" );
			}
		}

		return $match;
	}
	else
	{
#		debug ( $out_indent, "NO MATCH 7 FOR '$path'" )		if $DEBUG;

		if ( $DEBUG )
		{
			my @match_stack	= @ { $self->memo->{_pattern_stack} || [] };
			my $match_path		= @match_stack ? $match_stack[-1] : '';

			debug ( $out_indent, "7 NO MATCH FOR '$path' -> '$match_path'" );
		}

		return 0;
	}
}

=pod

=back

=head1 ACKNOWLEDGEMENTS

Thanks for the algorithm of C<match>, which was shamelessly stolen
from the Graphmaster.match Java implementation of ProgramD by Noel
Bush at A.L.I.C.E. AI Foundation and implemented in Perl.

See L<http://www.alicebot.org/downloads/>

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

L<AIML::Responder>, L<AIML::Knowledge>.

=cut

1;

__END__
