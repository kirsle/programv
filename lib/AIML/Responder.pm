=head1 NAME

AIML::Responder - AIML responder object class

=head1 SYNOPSIS

   use AIML::Listener;
   use AIML::Talker;
   use AIML::Memory;
   use AIML::Responder;

   $responder = AIML::Responder->new
                (
                   listener => new AIML::Listener ( ... ),
                   talker   => new AIML::Talker   ( ... ),
                   memory   => new AIML::Memory   ( ... ),
                );

   $talker = $responder->getResponse();

   print $talker->as_string();

=head1 DESCRIPTION

This module parses an input from the C<AIML::Listener> object using
the AIML knowledge base prepared by the C<AIML::Loader> and provided
by the C<AIML::Memory> object. The response is stored by the
C<AIML::Talker> object.

Validation is not envolved, because the used AIML knowledge base is
assumed to be already validated by L<C<AIML::Loader>|AIML::Loader>.

It is an OOPPS implementation of the semantical rules for AIML
(Artificial Intelligence Markup Language) defined in
L<http://alicebot.org/TR/2001/WD-aiml/>.

C<AIML::Responder> inherits from L<C<AIML::Parser>|AIML::Parser> and
L<C<AIML::Graphmaster>|AIML::Graphmaster>. The methods C<startTag>,
C<endTag> and C<tagContent> are overwritten to handle the
template-side AIML tags.

See L<AIML::Bot> for a simpler interface.

=cut

package AIML::Responder;

use strict;
use warnings;
no warnings "recursion";

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use EnglishSave;

use AIML::Common 0.09;
use AIML::Unicode 0.09;
use AIML::Config 0.09;

use AIML::Graphmaster 0.09;
use AIML::Parser 0.09;

@ISA = qw ( AIML::Parser AIML::Graphmaster );

=head1 GLOBALS

   $AIML::Responder::DEBUG = 1;

Logs all parsing activities (huge output).

=head1 EXPORT

=head2 Public Attributes

None.

=head2 Public Constructors

C<new>

=head2 Public Methods

C<startTag>, C<endTag>, C<tagContent>

C<getResponse>

=cut

=head1 ATTRIBUTES

Do not overwrite and call attributes marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * memo ( ) I<PRIVATE> I<READONLY>

Returns the current C<AIML::Memory> object.

=item * list ( ) I<PRIVATE> I<READONLY>

Returns the current C<AIML::Listener> object.

=item * talk ( ) I<PRIVATE> I<READONLY>

Returns the current C<AIML::Talker> object.

=cut

sub memo	{ $_[0]->{memory};	}
sub list	{ $_[0]->{listener};	}
sub talk	{ $_[0]->{talker};	}

=pod

=back

=head1 CONSTRUCTOR

=over 4

=item * new ( %args )

Creates an C<AIML::Responder>.

The constructor takes a hash with three entries:

   listener => new AIML::Listener ( ... ),
   talker   => new AIML::Talker   ( ... ),
   memory   => new AIML::Memory   ( ... ).

See  L<AIML::Listener>, L<AIML::Talker> and L<AIML::Memory> for more information.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my %args		= @_;

	my $self		= $class->SUPER::new ();

	$self->{listener}	= $args{listener};
	$self->{talker}	= $args{talker};
	$self->{memory}	= $args{memory};

	die ( 'listener undefined' )						unless $self->{listener};
	die ( 'talker undefined' )							unless $self->{talker};
	die ( 'memory undefined' )							unless $self->{memory};

	$self->_reset();

	return $self;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

Methods marked as I<B<CALLBACK>> are automatically called from
L<C<AIML::Parser>|AIML::Parser>, do not call them from outside.

=head2 Main Methods

=over 4

=cut

=pod

=item * _reset ( ) I<PRIVATE>

=cut

sub _reset
{
	my $self = shift;

	$self->{_think}			= false;
}

=pod

=item * getResponse ( )

This method takes the input provided by C<list>, splits the sentences
and matches them against the patterns provided by C<memo> using
L<C<AIML::Graphmaster>|AIML::Graphmaster>.

The answer(s) is/are stored in C<talk>.

Returns the current C<AIML::Talker> object.

=cut

sub getResponse
{
	my $self = shift;

	my $input = $self->list->first();

	while ( $input )
	{
		$self->memo->push ( 'input', $input );

		my $raSplitters	= $self->memo->getSentenceSplitters();
		my $raSentences	= sentenceSplit ( $raSplitters, $self->memo->get ( 'that', 1 ) );
#		my $that				= $raSentences->[-1]	|| '';
		my $that				= $raSentences->[-1];
		$that = ''	unless defined $that;

		patternFitNoWildcards ( \$that );

#		if ( not $that or $that eq $self->memo->getConfig ( 'emptydefault' ) )
		if ( not $that )
		{
			$that = '*';
		}

		my $topic			= $self->memo->get ( 'topic' );

		patternFitNoWildcards ( \$topic );

#		if ( not $topic or $topic eq $self->memo->getConfig ( 'emptydefault' ) )
		if ( not $topic )
		{
			$topic = '*';
		}

		debug ( ">>> getResponse='$input', '$that', '$topic'" )	if $DEBUG;

		my $reply = $self->getReply ( $input, $that, $topic );

		debug ( "<<< getResponse='$input', '$that', '$topic'" )	if $DEBUG;
		debug ( "          reply='$reply'" )							if $DEBUG;

		#	// Push the reply onto the <that/> stack.
		#	PredicateMaster.push(THAT, reply, userid, botid);

		$self->memo->push ( 'that', $reply );

		$self->talk->add ( $reply );

		$input = $self->list->next();
	}

	return $self->talk();
}

=pod

=item * getInternalResponse ( $sInput ) I<PRIVATE>

=cut

sub getInternalResponse
{
	my $self		= shift;
	my $input	= shift;

	$input = ''		unless defined $input;

	my $bot_id			= $self->memo->{bot_id};
	my $old_listener	= $self->list;
	my $old_talker		= $self->talk;
	my $old_think		= $self->{_think};	#	BUGFIX

	my $listener	= AIML::Listener->new
							(
								input		=> $input,
								service	=> $AIML_SERVICE_AIML,
								encoding	=> $AIML_ENCODING_UTF8,
								memory	=> $self->memo,
							);
	my $talker		= AIML::Talker->new
							(
								service	=> $AIML_SERVICE_AIML,
								encoding	=> $AIML_ENCODING_UTF8,
								memory	=> $self->memo,
							);

	$self->{listener}	= $listener;
	$self->{talker}	= $talker;
	$self->{_think}	= false;					#	BUGFIX

	debug ( ">>> getInternalResponse='$input'" )								if $DEBUG;

	$self->getResponse();

	debug ( "<<< getInternalResponse='$input'" )								if $DEBUG;
	debug ( "              as_string='", $talker->as_string(), "'" )	if $DEBUG;

	$self->{listener}	= $old_listener;
	$self->{talker}	= $old_talker;
	$self->{_think}	= $old_think;			#	BUGFIX

	return $talker->as_string();
}

=pod

=item * getReply ( $sInput, $sThat, $sTopic ) I<PRIVATE>

=cut

sub getReply
{
	my $self		= shift;
	my $input	= shift;
	my $that		= shift;
	my $topic	= shift;

#	0 but defined...

	$input	= defined $input	? ( length $input	? $input	: ''	) : ''	;
	$that		= defined $that	? ( length $that	? $that	: '*'	) : '*'	;
	$topic	= defined $topic	? ( length $topic	? $topic	: '*'	) : '*'	;

	debug ( ">>> getReply='$input', '$that', '$topic'" )	if $DEBUG;

	my $xml	= $self->getMatchResult ( $input, $that, $topic ) || '';

	debug ( "<<< getReply='$input', '$that', '$topic'" )	if $DEBUG;

	debug "_inputstar_stack\n",	Dumper ( $self->memo->{_inputstar_stack} )	if $DEBUG;
	debug "_thatstar_stack\n",		Dumper ( $self->memo->{_thatstar_stack} )		if $DEBUG;
	debug "_topicstar_stack\n",	Dumper ( $self->memo->{_topicstar_stack} )	if $DEBUG;
	debug "_pattern_stack\n",		Dumper ( $self->memo->{_pattern_stack} )		if $DEBUG;

	debug ( "    template='$xml'" )								if $DEBUG;

	$self->{_output_text}	= '';

#	$self->parseRam ( '<template>' . $xml . '</template>' )		or die "Can't parse '$xml'";
	$self->parseTemplate ( $xml )		or die "Can't parse '$xml'";

	debug ( "    template='$xml'" )								if $DEBUG;
	debug ( "      output='$self->{_output_text}'" )		if $DEBUG;

	return $self->{_output_text};
}

=pod

=item * getMatchResult ( $sInput, $sThat, $sTopic ) I<PRIVATE>

=cut

sub getMatchResult
{
	my $self		= shift;
	my $input	= shift;
	my $that		= shift;
	my $topic	= shift;

#	0 but defined...

	$input	= defined $input	? ( length $input	? $input	: ''	) : ''	;
	$that		= defined $that	? ( length $that	? $that	: '*'	) : '*'	;
	$topic	= defined $topic	? ( length $topic	? $topic	: '*'	) : '*'	;

	patternFit ( \$input	);
	patternFit ( \$that	);
	patternFit ( \$topic	);

	my $line			= "$input <that> $that <topic> $topic <pos>";	#	<botid>
	my $root			= $self->memo->getPatterns();
	my $star			= '';
	my $path			= '';
	my $matchState	= '<input>';

	$self->{_time_out} = time + int ( $self->memo->getConfig ( 'response-timeout' ) / 1000 );

	my $pattern	= $self->match ( $root, $root, $line, $star, $path, $matchState ) || 0;

	if ( not $pattern )		#	time out
	{
		$line	= $self->memo->getConfig ( 'timeout-input' ) . ' <that> * <topic> * <pos>';
		$path	= '';

		$self->{_time_out} = time + int ( $self->memo->getConfig ( 'response-timeout' ) / 1000 );

		$pattern	= $self->match ( $root, $root, $line, $star, $path, $matchState ) || 0;
	}

	$pattern = 0	unless $pattern;

	return $self->memo->getTemplates()->[$pattern];
}

=pod

=back

=head2 Callback Methods

The following methods overwrite those of L<C<AIML::Parser>|AIML::Parser>.

=over 4

=item * startTag ( \@context, $type, \%attr ) I<CALLBACK>

Puts the responder object in the necessary start conditions and
interprets AIML tags - e.g.: Collecting E<lt>liE<gt> for
E<lt>conditionE<gt>, getting atomic tags like E<lt>dateE<gt> or
switching E<lt>thinkE<gt> etc.

=cut

sub startTag
{
	my $self		= shift;
	my $context	= shift;
	my $type		= shift;
	my $attr		= shift;

	return		if $self->errors();

	SWITCH:
	{
		local $_;

		for ( $type )
		{
			#
			#	no zero-level elements here
			#

			#
			#	no top-level elements here
			#

			#
			#	second-level
			#
			/^template$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	atomic elements
			#
			/^star$/	&& do {
							$self->{_current_text}	.= $self->memo->getStar ( $attr->{index} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^that$/	&& do {
							$self->{_current_text}	.= $self->memo->getThat ( $attr->{index} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^input$/	&& do {
							$self->{_current_text}	.= $self->memo->getInput ( $attr->{index} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^thatstar$/	&& do {
							$self->{_current_text}	.= $self->memo->getThatstar ( $attr->{index} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^topicstar$/	&& do {
							$self->{_current_text}	.= $self->memo->getTopicstar ( $attr->{index} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^get$/	&& do {
							$self->{_current_text}	.= $self->memo->getGet ( $attr->{name} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^bot$/	&& do {
							$self->{_current_text}	.= $self->memo->getBot ( $attr->{name} );

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			#
			#	no atomic shortcuts here, see AIML::Loader
			#

			#
			#	system-defined predicates
			#
			/^date$/	&& do {
							$self->{_current_text}	.= $self->memo->getDate();

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^id$/	&& do {
							$self->{_current_text}	.= $self->memo->getId();

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^size$/	&& do {
							$self->{_current_text}	.= $self->memo->getSize();

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^version$/	&& do {
							$self->{_current_text}	.= $self->memo->getVersion();

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			#
			#	text formatting elements
			#
			/^uppercase$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^lowercase$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^formal$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^sentence$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	conditional elements
			#
			/^condition$/	&& do {
							$self->pushCondition();

							if ( exists $attr->{name} and exists $attr->{value} )
							{
								#
								#	block condition
								#
								my $stored_value	= $self->memo->getGet ( $attr->{name} );
								my $test_value		= $attr->{value};

							#	$test_value =~ s/\*/\.\*\?/g;
							#	$test_value =~ s/\_/\.\*\?/g;
							#
							#	BUGFIX:
							#
							#	.*?		match any character (except newline) 0 or more times non-greedy
							#				including blanks!
							#
							#	Although AIML::Parser is checking for empty value attributes,
							#	it might be safer to write here:
							#
							#	[^ ]+?	match non-blank 1 or more times non-greedy
							#
							#	so	"*"			becomes	"[^ ]+?"
							#		"any word"	becomes	"any word"
							#		"* word"		becomes	"[^ ]+? word"
							#		"word _"		becomes	"word [^ ]+?"
							#
								$test_value =~ s/\*/\[\^ \]\+\?/g;
								$test_value =~ s/\_/\[\^ \]\+\?/g;

								unless ( $stored_value =~ /^$test_value$/i )	#	or must we srai here????
								{
									$self->pushIgnore ( $type );

									$self->popCondition();

									last SWITCH;
								}
							}

							$self->pushAttr ( $attr );
							$self->pushText();
							last SWITCH;
						};
			/^random$/	&& do {
							$self->pushCondition();
							$self->pushText();
							last SWITCH;
						};
			/^li$/	&& do {
							my $parent = $context->[-1] || 'undef';

							$self->pushCollect ( $type );
							$self->pushAttr ( $attr );
							$self->pushText();
							last SWITCH;
						};
			#
			#	capture elements
			#
			/^set$/	&& do {
							$self->pushAttr ( $attr );
							$self->pushText();
							last SWITCH;
						};
			/^gossip$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	symbolic reduction elements
			#
			/^srai$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	transformational elements
			#
			/^person$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^person2$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^gender$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	covert elements
			#
			/^think$/	&& do {
							$self->pushText();

							$self->{_think}			= true;

							last SWITCH;
						};
			/^learn$/	&& do {
							#
							#	for now
							#
							$self->{_current_text}	.= "[$type ignored]";
							$self->pushIgnore ( $type );
							last SWITCH;
						};
			#
			#	external processor elements
			#
			/^system$/	&& do {
							#
							#	for now
							#
							$self->{_current_text}	.= "[$type ignored]";
							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^javascript$/	&& do {
							#
							#	for now
							#
							$self->{_current_text}	.= "[$type ignored]";
							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^perl$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			#
			#	default
			#
			die "NEVER COME HERE WITH '$type'";
		}
	}
}

=pod

=item * endTag ( \@context, $type ) I<CALLBACK>

Processes the AIML tags - e.g.: Choosing E<lt>conditionE<gt> or
E<lt>randomE<gt>, evaluating E<lt>perlE<gt> snippets, doing
E<lt>sraiE<gt> etc.

=cut

sub endTag
{
	my $self		= shift;
	my $context	= shift;
	my $type		= shift;

	return		if $self->errors();

	SWITCH:
	{
		local $_;

		for ( $type )
		{
			#
			#	no zero-level elements here
			#

			#
			#	no top-level elements here
			#

			#
			#	second-level
			#
			/^template$/	&& do {
							$self->{_output_text}	.= $self->{_current_text}		unless $self->{_think};

#							debug sprintf
#								(
#									"output='%s', current='%s', think='%s'",
#
#									$self->{_output_text}	|| '[EMPTY]',
#									$self->{_current_text}	|| '[EMPTY]',
#									$self->{_think}			|| '0',
#								);

							$self->popText();
							last SWITCH;
						};
			#
			#	atomic elements
			#

			#
			#	no atomic shortcuts here, see AIML::Loader
			#

			#
			#	system-defined predicates
			#

			#
			#	text formatting elements
			#
			/^uppercase$/	&& do {
							my $text = uppercase ( $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^lowercase$/	&& do {
							my $text = lowercase ( $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^formal$/	&& do {
							my $text = formal ( $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^sentence$/	&& do {
							my $text = sentence ( $self->{_current_text} );;

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			#
			#	conditional elements
			#
			/^condition$/	&& do {
							my $attr = $self->popAttr();
							my $text = '';

							if ( exists $attr->{name} and exists $attr->{value} )
							{
								#
								#	block condition
								#
								$text = $self->{_current_text};
							}
							elsif ( exists $attr->{name} and not exists $attr->{value} )
							{
								#
								#	single-predicate condition
								#
								my $i = 0;
								foreach my $li_attr ( @ { $self->{_condition_attr} || [] } )
								{
									if ( exists $li_attr->{value} )
									{
										my $stored_value	= $self->memo->getGet ( $attr->{name} );
										my $test_value		= $li_attr->{value};

									#	$test_value =~ s/\*/\.\*\?/g;
									#	$test_value =~ s/\_/\.\*\?/g;
									#
									#	BUGFIX:
									#
										$test_value =~ s/\*/\[\^ \]\+\?/g;
										$test_value =~ s/\_/\[\^ \]\+\?/g;

										if ( $stored_value =~ /^$test_value$/i )	#	or must we srai here????
										{
											$text = $self->{_condition_text}->[$i];
											last;
										}
									}
									else
									{
										#	default
										$text = $self->{_condition_text}->[$i];
										last;
									}
									$i++;
								}
							}
							elsif ( not exists $attr->{name} and not exists $attr->{value} )
							{
								#
								#	Multi-predicate Condition
								#
								my $i = 0;
								foreach my $li_attr ( @ { $self->{_condition_attr} || [] } )
								{
									if ( exists $li_attr->{name} and exists $li_attr->{value} )
									{
										my $stored_value	= $self->memo->getGet ( $li_attr->{name} );
										my $test_value		= $li_attr->{value};

									#	$test_value =~ s/\*/\.\*\?/g;
									#	$test_value =~ s/\_/\.\*\?/g;
									#
									#	BUGFIX:
									#
										$test_value =~ s/\*/\[\^ \]\+\?/g;
										$test_value =~ s/\_/\[\^ \]\+\?/g;

										if ( $stored_value =~ /^$test_value$/i )	#	or must we srai here????
										{
											$text = $self->{_condition_text}->[$i];
											last;
										}
									}
									else
									{
										#	default
										$text = $self->{_condition_text}->[$i];
										last;
									}
									$i++;
								}
							}
							else
							{
								die "NEVER COME HERE WITH '$type'";
							}

							$self->popCondition();
							$self->popText();

							my $old_text				= $self->{_current_text};	#	so far
							my $old_output				= $self->{_output_text};	#	save

							my $xml						= $text;

							$self->{_current_text}	= '';
							$self->{_output_text}	= '';

							#	$self->parseRam ( '<template>' . $xml . '</template>' )		or die "Can't parse '$xml'";
							$self->parseTemplate ( $xml )		or die "Can't parse '$xml'";

							$self->{_current_text}	= $old_text . $self->{_output_text};	#	add

							$self->{_output_text}	= $old_output;		#	and restore

							last SWITCH;
						};
			/^random$/	&& do {
							my $size	= scalar @ { $self->{_condition_text} || [] };
							my $ndx	= int ( rand ( $size ) );
							my $text	= $self->{_condition_text}->[$ndx];

							$self->popCondition();

							$self->popText();

							my $old_text				= $self->{_current_text};	#	so far
							my $old_output				= $self->{_output_text};	#	save

							my $xml						= $text;

							$self->{_current_text}	= '';
							$self->{_output_text}	= '';

							#	$self->parseRam ( '<template>' . $xml . '</template>' )		or die "Can't parse '$xml'";
							$self->parseTemplate ( $xml )		or die "Can't parse '$xml'";

							$self->{_current_text}	= $old_text . $self->{_output_text};	#	add

							$self->{_output_text}	= $old_output;		#	and restore

							last SWITCH;
						};
			/^li$/	&& do {
							my $parent = $context->[-1] || 'undef';

							my $attr = $self->popAttr();

							push @ { $self->{_condition_text} }, $self->{_current_text};
							push @ { $self->{_condition_attr} }, $attr;

							$self->popText();

							last SWITCH;
						};
			#
			#	capture elements
			#
			/^set$/	&& do {
							my $attr = $self->popAttr();
							my $text = $self->memo->setSet ( $attr->{name}, $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^gossip$/	&& do {
							$self->memo->setGossip ( $self->{_current_text} );

							my $text = $self->{_current_text};

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			#
			#	symbolic reduction elements
			#
			/^srai$/	&& do {
							$self->{_srai_calls}++;

							debug ( '>>> SRAI *** ', $self->{_srai_calls} )		if $DEBUG;

							my $new_input	= $self->{_current_text};	#	from srai content
							my $old_output	= $self->{_output_text};	#	save

							my $text			= '';

							$self->{_current_text}	= '';					#	init
							$self->{_output_text}	= '';					#	init

							if ( $self->{_srai_calls} > $AIML_MAX_SRAI )
							{
								$new_input = $self->memo->getConfig ( 'infinite-loop-input' );
							}

							####################################################
							#	do your thing
							#
							$text = $self->getInternalResponse ( $new_input );
							#
							####################################################

							$self->{_output_text}	= $old_output;		#	and restore

							$self->popText();

							$text = ''	unless defined $text;	#	might be '0' !!

							$self->{_current_text}	.= $text;

							debug ( '<<< SRAI *** ', $self->{_srai_calls} )		if $DEBUG;

							$self->{_srai_calls}--;

							last SWITCH;
						};
			#
			#	transformational elements
			#
			/^person$/	&& do {
							my $rhSubstitutionMap	= $self->memo->getSubstitutesPerson();
							my $text						= applySubstitutions ( $rhSubstitutionMap, $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^person2$/	&& do {
							my $rhSubstitutionMap	= $self->memo->getSubstitutesPerson2();
							my $text						= applySubstitutions ( $rhSubstitutionMap, $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			/^gender$/	&& do {
							my $rhSubstitutionMap	= $self->memo->getSubstitutesGender();
							my $text						= applySubstitutions ( $rhSubstitutionMap, $self->{_current_text} );

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			#
			#	covert elements
			#
			/^think$/	&& do {
							$self->{_think}			= false;

							$self->popText();

							last SWITCH;
						};
			/^learn$/	&& do {
							#
							#	for now ignored
							#
							last SWITCH;
						};
			#
			#	external processor elements
			#
			/^system$/	&& do {
							#
							#	for now ignored
							#
							last SWITCH;
						};
			/^javascript$/	&& do {
							#
							#	for now ignored
							#
							last SWITCH;
						};
			/^perl$/	&& do {
							my $snippet = $self->{_current_text} || '';

							my $pkg	= perlClassName ( $self->memo->{bot_id} );

							$snippet = "package $pkg;\n" . $snippet;

							my $text = undef;

							$text = eval ( $snippet );		#	run it!

							if ( $EVAL_ERROR )
							{
								my @lines = split /\n/, $snippet;
								my $i = 0;
								map { $i++; $_ = "$i\:\t" . $_ . "\n"; } @lines;

								$snippet = "@lines";

								$self->putWarning ( "$EVAL_ERROR\n$snippet" );

							#	$text = $self->memo->getConfig ( 'emptydefault' );
								$text = '';
							}
							else
							{
							#	$text = $self->memo->getConfig ( 'emptydefault' )		unless defined $text;
								$text = ''															unless defined $text;
							}

							$self->popText();

							$self->{_current_text}	.= $text;

							last SWITCH;
						};
			#
			#	default
			#
			die "NEVER COME HERE WITH '$type'";
		}
	}
}

=pod

=item * tagContent ( \@context, $content ) I<CALLBACK>

Collects the content of all tags.

=cut

sub tagContent
{
	my $self		= shift;
	my $context	= shift;
	my $content	= shift;

	return		if $self->errors();

	$self->{_current_text} .= $content;
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

L<AIML::Bot>, L<AIML::Listener>, L<AIML::Memory>, L<AIML::Talker>,
L<AIML::Graphmaster>, L<AIML::Loader>, L<AIML::Parser>.

=cut

1;

__END__
