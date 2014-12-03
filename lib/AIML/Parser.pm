=head1 NAME

AIML::Parser - validating AIML parser object class

=head1 SYNOPSIS

   use AIML::Parser;

   $parser = new AIML::Parser;

   # parse a complete AIML file as is
   #
   open ( MY_AIML, 'aiml/standard/small.aiml' );
   local $/;   #   slurp
   $content = <MY_AIML>;
   close ( MY_AIML );

   $parser->parseRam ( $content );

   # parse a CONFIG file line by line
   #
   $parser->parseFile ( 'startup.xml' );

   # parse an included CONFIG file line by line
   #
   $parser->parseInclude ( 'predicates.xml' );

   # parse an AIML file line by line and print results
   #
   $parser->parseFile ( 'aiml/standard/test.aiml' );

   print "\n\nWARNINGS\n", $parser->warningString() || "\tnone\n";
   print "\n\nERRORS\n",   $parser->errorString()   || "\tnone\n";

   # parse an AIML template
   #
   $text = '<srai>MY FAVORITE <thatstar/> IS <star/></srai>';

   $parser->parseTemplate ( $text );

   # $text is completed to:
   #
   # '<template>' . $text . '</template>'

=head1 DESCRIPTION

This module provides a way to parse and validate AIML files and
expressions. It is an OOPPS implementation of the syntactical rules
for AIML (Artificial Intelligence Markup Language) defined in
L<http://alicebot.org/TR/2001/WD-aiml/>.

C<AIML::Parser> does only a syntactical validation - e.g.: which tags
can include other tags, what kind of content can a tag have, which
attributes are required, what kind of content must an attribute have
etc.

See L<AIML::Loader> and L<AIML::Responder> for how to inherit from
this class and to create semantical parsers.

=cut

package AIML::Parser;

use strict;
use warnings;
no warnings "recursion";

BEGIN
{
	use vars qw ( $DEBUG $VERSION );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

#
#	LIBS
#
use AIML::Common 0.09;
use AIML::File 0.09;

=head1 GLOBALS

   $AIML::Parser::DEBUG = 1;

Logs all parsing activities (huge output).

=head1 EXPORT

=head2 Public Attributes

C<filename>, C<fileline>, C<errors>, C<errorString>, C<warnings>, C<warningString>, C<xmlVersion>, C<xmlEncoding>

=head2 Public Constructors

C<new>

=head2 Public Methods

C<resetError>, C<putError>, C<putWarning>

C<parseFile>, C<parseInclude>, C<parseRam>, C<parseTemplate>

C<pushText>, C<popText>, C<pushAttr>, C<popAttr>, C<pushCondition>, C<popCondition>

C<ignore>, C<pushIgnore>, C<isIgnored>, C<popIgnore>,

C<collect>, C<pushCollect>, C<isCollected>, C<popCollect>,

C<pushEnvironment>, C<popEnvironment>

C<startDocument>, C<startTag>, C<endTag>, C<tagContent>, C<piTag>, C<endDocument>

=cut

#
#	VALIDATING DEFINITIONS
#

#
#	REGULAR EXPRESSIONS FOR AIML 1.01
#
use utf8;

my $AIMLVersion			= qr/^${AIML_VERSION}$/;
my $AIMLNamespace			= qr/^${AIML_NAMESPACE}$/;

my $Space					= qr/\x20/;
my $NormalChar				= qr/[\p{IsDigit}\p{IsLower}\p{IsUpper}]/;
my $AIMLWildcard			= qr/[\*\_]/;
my $NormalWord				= qr/${NormalChar}+?/;

my $SimplePattExprConst	= qr/(${NormalWord}|${AIMLWildcard})/;
my $SimplePattExpr		= qr/^${SimplePattExprConst}(${Space}${SimplePattExprConst})*?$/;

my $PattSideBotElem		= qr/<bot.*?\/>/;

$AIML::Parser::PattSideBotElemRegex = qr/<bot\s+?name\=\"(${NormalWord})\"\/>/;	#	see AIML::Loader!

my $MixedPattExprConst	= qr/(${NormalWord}|${AIMLWildcard}|${PattSideBotElem})/;
my $MixedPattExpr			= qr/^${MixedPattExprConst}(${Space}${MixedPattExprConst})*?$/;

my $PredName				= qr/^${NormalWord}$/;
my $PredNameHyphen		= qr/^${NormalWord}(\-${NormalWord})*?$/,
my $BooleanValue			= qr/^(true|false)$/;
my $NameOrValue			= qr/^(name|value)$/;
my $AnyValue				= qr/^.+$/;						#	watch this...
my $EmptyValue				= qr/^$/;
my $ReplaceValue			= qr/($EmptyValue|$AnyValue)/;

my $SingleIntegerConst			= qr/[1-9]+?/;			#	not 0 !
my $SingleIntegerIndex			= qr/^(${SingleIntegerConst})$/;
my $CommaSeparatedIntegerPair	= qr/^(${SingleIntegerConst}),?(${SingleIntegerConst})?$/;

my $FilePatternChar			= qr/[a-zA-Z0-9\_\-\*\.\/]/;
my $AIMLFilePattern			= qr/^${FilePatternChar}+\.aiml$/;
my $XMLFilePattern			= qr/^${FilePatternChar}+\.xml$/;

#
#	STARTUP.XML
#
my $s_program_startup	= {};
my $s_bots					= {};
my $s_bot =
{
	_attr	=>
	{
		id			=> $PredNameHyphen,
		enabled	=> $BooleanValue,
	},
};
my $s_properties			= {};
my $s_property =
{
	_attr	=>
	{
		name	=> $PredName,
		value	=> $AnyValue,
	},
	_atomic	=> 1,
};
my $s_listeners			= {};
my $s_listener =
{
	_attr	=>
	{
		type		=> $PredName,
		enabled	=> $BooleanValue,
	},
};
my $s_parameter =
{
	_attr	=>
	{
		name	=> $PredName,
		value	=> $AnyValue,
	},
	_atomic	=> 1,
};
my $s_predicates			= {};
my $s_predicates_atomic =
{
	_attr	=>
	{
		href	=> qr/^${FilePatternChar}?predicates\.xml$/
	},
	_atomic	=> 1,
};
my $s_predicate =
{
	_attr	=>
	{
		name				=> $PredName,
		default			=> $AnyValue,
		'set-return'	=> $NameOrValue,
	},
	_atomic	=> 1,
};
my $s_substitutions		= {};
my $s_substitutions_atomic =
{
	_attr	=>
	{
		href	=> qr/^${FilePatternChar}?substitutions\.xml$/
	},
	_atomic	=> 1,
};
my $s_input					= {};
my $s_gender				= {};
my $s_person				= {};
my $s_person2				= {};
my $s_substitute =
{
	_attr	=>
	{
 		find		=> $AnyValue,			#	watch!
 		replace	=> $ReplaceValue,		#	watch!
	},
	_atomic	=> 1,
};
my $s_splitters			= {};
my $s_splitters_atomic =
{
	_attr	=>
	{
		href	=> qr/^${FilePatternChar}?sentence\-splitters\.xml$/
	},
	_atomic	=> 1,
};
my $s_splitter =
{
	_attr	=>
	{
 		value	=> $AnyValue,		#	watch!
	},
	_atomic	=> 1,
};
my $s_learn =
{
	_content	=> $AIMLFilePattern,
};

#
#	DA STARTUP RULES
#
my $VALIDATE_STARTUP	=
{
	$AIML_STARTUP_MAGIC	=> $s_program_startup,
};
#
$s_program_startup->{bots}							= $s_bots;
$s_bots->{bot}											= $s_bot;
$s_bot->{properties}									= $s_properties;
$s_bot->{listeners}									= $s_listeners;
$s_bot->{predicates}									= $s_predicates;
$s_bot->{predicates_atomic}						= $s_predicates_atomic;		#	include...
$s_bot->{substitutions}								= $s_substitutions;
$s_bot->{substitutions_atomic}					= $s_substitutions_atomic;	#	include...
$s_bot->{'sentence-splitters'}					= $s_splitters;
$s_bot->{'sentence-splitters_atomic'}			= $s_splitters_atomic;		#	include...
$s_bot->{learn}										= $s_learn;
#
$s_properties->{property}							= $s_property;
#
$s_listeners->{listener}							= $s_listener;
$s_listener->{parameter}							= $s_parameter;
#
$s_predicates_atomic->{predicates}				= $s_predicates;				#	include...
$s_substitutions_atomic->{substitutions}		= $s_substitutions;			#	include...
$s_splitters_atomic->{'sentence-splitters'}	= $s_splitters;				#	include...
#
$s_predicates->{predicate}							= $s_predicate;
$s_substitutions->{input}							= $s_input;
$s_substitutions->{gender}							= $s_gender;
$s_substitutions->{person}							= $s_person;
$s_substitutions->{person2}						= $s_person2;
#
$s_input->{substitute}								= $s_substitute;
$s_gender->{substitute}								= $s_substitute;
$s_person->{substitute}								= $s_substitute;
$s_person2->{substitute}							= $s_substitute;
#
$s_splitters->{splitter}							= $s_splitter;

#	print Dumper ( $VALIDATE_STARTUP );
#	die;

#
#	AIML TAGS
#
my $aiml =
{
	_attr	=>
	{
		version => $AIMLVersion,
	},
	_optional_attr	=>
	{
		xmlns				=> $AIMLNamespace,
		'xmlns:aiml'	=> $AIMLNamespace,
	},
};

#	top-level-elements
#
my $topic =
{
	_attr	=>
	{
		name	=> $SimplePattExpr,
	},
};
my $category				= {};
my $perl						= {};

#	AIML-CATEGORY-ELEMENTS
#
my $pattern =
{
	_content		=> $MixedPattExpr,
};

my $that =
{
	_content		=> $MixedPattExpr,
};

my $template				= {};

#	AIML-TEMPLATE-ELEMENTS
#
#	atomic elements
#
my $star =
{
	_attr	=>
	{
		index => $SingleIntegerIndex,
	},
	_default_attr	=>
	{
		index	=>
		{
			_dimension	=> 1,
			_value		=> '1',
			_value1		=> '1',
		},
	},
	_atomic	=> 1,
};
my $that_atomic =
{
	_attr	=>
	{
		index => $CommaSeparatedIntegerPair,
	},
	_default_attr	=>
	{
		index	=>
		{
			_dimension	=> 2,
			_value		=> '1,1',
			_value1		=> '1',
			_value2		=> '1',
		},
	},
	_atomic	=> 1,
};
my $input =
{
	_attr	=>
	{
		index => $CommaSeparatedIntegerPair,
	},
	_default_attr	=>
	{
		index	=>
		{
			_dimension	=> 2,
			_value		=> '1,1',
			_value1		=> '1',
			_value2		=> '1',
		},
	},
	_atomic	=> 1,
};
my $thatstar =
{
	_attr	=>
	{
		index => $SingleIntegerIndex,
	},
	_default_attr	=>
	{
		index	=>
		{
			_dimension	=> 1,
			_value		=> '1',
			_value1		=> '1',
		},
	},
	_atomic	=> 1,
};
my $topicstar =
{
	_attr	=>
	{
		index => $SingleIntegerIndex,
	},
	_default_attr	=>
	{
		index	=>
		{
			_dimension	=> 1,
			_value		=> '1',
			_value1		=> '1',
		},
	},
	_atomic	=> 1,
};
my $get =
{
	_attr	=>
	{
		name => $PredName,
	},
	_atomic	=> 1,
};
my $bot =
{
	_attr	=>
	{
		name => $PredName,
	},
	_atomic	=> 1,
};

#	shortcut elements
#
my $sr =
{
	_replace	=> '<srai><star/></srai>',
	_atomic	=> 1,
};
my $person_atomic =
{
	_replace	=> '<person><star/></person>',
	_atomic	=> 1,
};
my $person2_atomic =
{
	_replace	=> '<person2><star/></person2>',
	_atomic	=> 1,
};
my $gender_atomic =
{
	_replace	=> '<gender><star/></gender>',
	_atomic	=> 1,
};

#	system defined predicates
#
my $date =
{
	_atomic	=> 1,
};
my $id =
{
	_atomic	=> 1,
};
my $size =
{
	_atomic	=> 1,
};
my $version =
{
	_atomic	=> 1,
};

#	text formatting elements
#
my $uppercase				= {};
my $lowercase				= {};
my $formal					= {};
my $sentence				= {};

#	conditional elements
#
my $condition =
{
	_optional_attr	=>
	{
		name	=> $PredName,
		value	=> $SimplePattExpr,
	},
};
my $li =
{
	_optional_attr	=>
	{
		name	=> $PredName,
		value	=> $SimplePattExpr,
	},
};
my $random					= {};

#	capture elements
#
my $set =
{
	_attr	=>
	{
		name	=> $PredName,
	},
};

my $gossip					= {};

#	symbolic reduction elements
#
my $srai						= {};

#	transformational elements
#
my $person					= {};
my $person2					= {};
my $gender					= {};

#	covert elements
#
my $think					= {};
my $learn =
{
	_content	=> $AIMLFilePattern,
};

#	external processor elements
#
my $system					= {};
my $javascript				= {};
#	$perl see above...

#	pattern-side bot elements
#
#	$bot see above...

#
#	DA AIML RULES
#
my $VALIDATE_AIML	=
{
	aiml	=> $aiml,
};

#	TOP-LEVEL-ELEMENTS
#
$aiml->{topic}					= $topic;
$aiml->{category}				= $category;
$aiml->{perl}					= $perl;					#	1.01 extended

$topic->{category}			= $category;
$topic->{perl}					= $perl;					#	1.01 extended

#	AIML-CATEGORY-ELEMENTS
#
$category->{pattern}			= $pattern;
$category->{that}				= $that;					#	pattern-side that
$category->{template}		= $template;

#	AIML-TEMPLATE-ELEMENTS
#
#	atomic elements
#
$template->{star}				= $star;
$template->{that_atomic}	= $that_atomic;		#	template-side that
$template->{input}			= $input;
$template->{thatstar}		= $thatstar;
$template->{topicstar}		= $topicstar;
$template->{get}				= $get;
$template->{bot}				= $bot;

#	shortcut elements
#
$template->{sr}				= $sr;
$template->{person_atomic}	= $person_atomic;
$template->{person2_atomic}= $person2_atomic;
$template->{gender_atomic}	= $gender_atomic;

#	system defined predicates
#
$template->{date}				= $date;
$template->{id}				= $id;
$template->{size}				= $size;
$template->{version}			= $version;

#	text formatting elements
#
$template->{uppercase}		= $uppercase;
$template->{lowercase}		= $lowercase;
$template->{formal}			= $formal;
$template->{sentence}		= $sentence;

#	conditional elements
#
$template->{condition}		= $condition;
$condition->{li}				= $li;

$template->{random}			= $random;
$random->{li}					= $li;

#	capture elements
#
$template->{set}				= $set;
$template->{gossip}			= $gossip;

#	symbolic reduction elements
#
$template->{srai}				= $srai;

#	transformational elements
#
$template->{person}			= $person;
$template->{person2}			= $person2;
$template->{gender}			= $gender;

#	covert elements
#
$template->{think}			= $think;
$template->{learn}			= $learn;

#	external processor elements
#
$template->{system}			= $system;
$template->{javascript}		= $javascript;
$template->{perl}				= $perl;					#	1.01 extended

#	pattern-side bot elements
#
$pattern->{bot}				= $bot;

#	tags containing aiml-template-elements
#
foreach my $key ( keys %$template )
{
	next	if $key =~ /^\_/;

	$uppercase->{$key}		= $template->{$key};
	$lowercase->{$key}		= $template->{$key};
	$formal->{$key}			= $template->{$key};
	$sentence->{$key}			= $template->{$key};
	$condition->{$key}		= $template->{$key};
	$li->{$key}					= $template->{$key};
	$set->{$key}				= $template->{$key};
	$gossip->{$key}			= $template->{$key};
	$srai->{$key}				= $template->{$key};
	$person->{$key}			= $template->{$key};
	$person2->{$key}			= $template->{$key};
	$gender->{$key}			= $template->{$key};
	$think->{$key}				= $template->{$key};
	$system->{$key}			= $template->{$key};
	$javascript->{$key}		= $template->{$key};
	$perl->{$key}				= $template->{$key};
}

#	local $Data::Dumper::Maxdepth = 9;
#	print Dumper ( $VALIDATE_AIML );
#	die;

=head1 FUNCTIONS

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * _known_tags ( $node ) I<PRIVATE>

Creates recursively an internal structure for validating.

=cut

my $KNOWN_TAGS = {};

sub _known_tags
{
	my $node = shift;

	foreach my $key ( keys %$node )
	{
		next	if $key =~ /^\_/;

		$KNOWN_TAGS->{$key}++;

		_known_tags ( $node->{$key} )		if $KNOWN_TAGS->{$key} == 1;
	}
}

_known_tags ( $VALIDATE_STARTUP );
_known_tags ( $VALIDATE_AIML );

#	print Dumper ( $KNOWN_TAGS );
#	die;

no utf8;

=pod

=back

=head1 CONSTRUCTOR

=over 4

=item * new ( )

Creates an C<AIML::Parser>.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my $self =
	{
		#	low level

		_file_name			=> '',
		_file_line			=> 0,

		_environment		=> [],
		_tag_stack			=> [],
		_node_stack			=> [],

		_validate_root		=> {},

		_fh					=> undef,
		_lines				=> [],

		_text					=> '',

		_unknown_tag		=> '',

		_xml_version		=> 0,
		_xml_encoding		=> '',

		#	high level

		_in_include			=> false,
		_cat_count			=> 0,

		_current_text		=> '',
		_output_text		=> '',
		_text_stack			=> [],
		_attr_stack			=> [],
		_ignore_stack		=> [],		#	do not process <tag> until </tag>
		_collect_stack		=> [],		#	load content of <tag> as is until </tag>
		_condition_stack	=> [],
	};

	bless $self, $class;

	$self->resetError();

	return $self;
}

=pod

=back

=head1 ATTRIBUTES

=over 4

=cut

=pod

=item * filename ( ) I<READONLY>

Returns	a filename	if C<parseFile> was called
	a filename	if C<parseInclude> was called
	'MEMORY'	if C<parseRam> was called
	'TEMPLATE'	if C<parseTemplate> was called
	''	if no parsing method has been called yet

=item * fileline ( ) I<READONLY>

Returns the current line number of the parsed file, content or text.

=item * errors ( ) I<READONLY>

Returns the number or errors.

=item * errorString ( ) I<READONLY>

Returns the collected errors as one string separated by C<\n>.

=item * warnings ( ) I<READONLY>

Returns the number or warnings.

=item * warningString ( ) I<READONLY>

Returns the collected warnings as one string separated by C<\n>.

=item * xmlVersion ( ) I<READONLY>

Returns the used version as found in the E<lt>?xml...?E<gt> tag.

=item * xmlEncoding ( ) I<READONLY>

Returns the used encoding as found in the E<lt>?xml...?E<gt> tag.

=cut

sub filename		{ $_[0]->{_file_name} };
sub fileline		{ $_[0]->{_file_line} };

sub errors			{ $_[0]->{_error} };
sub errorString	{ join "\n", @ { $_[0]->{_error_msg} || [] } };

sub warnings		{ $_[0]->{_warn} };
sub warningString	{ join "\n", @ { $_[0]->{_warn_msg} || [] } };

sub xmlVersion		{ $_[0]->{_xml_version} };
sub xmlEncoding	{ $_[0]->{_xml_encoding} };

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=head2 Main Methods

=over 4

=cut

=pod

=item * resetError ( )

Clears attributes	C<errors>
	C<errorString>
	C<warnings>
	C<warningString>

=cut

sub resetError
{
	_error				=> 0,
	_error_msg			=> [],
	_warn					=> 0,
	_warn_msg			=> [],
}

=pod

=item * putError ( [ @message ] )

Increments C<errors> and adds @message as string to C<errorString>.

The error message is supplemented with C<filename> and C<fileline>.

=cut

sub putError
{
	my $self = shift;

	$self->{_error}++;

	my $text = '';

	$text .= "@_"		if @_;
	$text .= "\n\tat " . $self->filename() . " line " . $self->fileline() . "\n";

	error ( $text )		if $DEBUG;

	push @ { $self->{_error_msg} }, $text;
};

=pod

=item * putWarning ( [ @message ] )

Increments C<warnings> and adds @message as string to C<warningString>.

The warning message is supplemented with C<filename> and C<fileline>.

=cut

sub putWarning
{
	my $self = shift;

	$self->{_warn}++;

	my $text = '';

	$text .= "@_"		if @_;
	$text .= "\n\tat " . $self->filename() . " line " . $self->fileline() . "\n";

	warning ( $text )		if $DEBUG;

	push @ { $self->{_warn_msg} }, $text;
};

=pod

=item * parseFile ( $filename )

This method parses an AIML or a startup XML file and validates it.

If the filename has the suffix C<.aiml>, the AIML validator, otherwise
the STARTUP validator is used.

All stacks are reset.

=cut

sub parseFile
{
	my $self			= shift;
	my $file_name	= shift;

	$self->pushEnvironment();

	$self->{_file_name}		= $file_name;
	$self->{_file_line}		= 0;

	$self->{_tag_stack}		= [];
	$self->{_node_stack}		= [];

	$self->{_validate_root}	= ( $file_name =~ /\.aiml$/ ) ? $VALIDATE_AIML : $VALIDATE_STARTUP;

	$self->{_fh}				= new AIML::File;
	$self->{_lines}			= [];

	$self->{_text}				= '';

	$self->{_unknown_tag}	= '';

	$self->{_xml_version}	= 1.0;							#	default
	$self->{_xml_encoding}	= $AIML_ENCODING_UTF8;		#	default

	$self->{_fh}->open ( $self->{_file_name} )	or die "Can't open ", $self->{_file_name};

	$self->parselines();

	$self->{_fh}->close();

	unless ( $self->{_error} )
	{
		my @not_closed = @ { $self->{_tag_stack} || [] };

		$self->putError ( "Tags '@not_closed' not closed" )	if @not_closed;
	}

	$self->popEnvironment();

	return not $self->{_error};
}

=pod

=item * parseInclude ( $filename )

This method parses an AIML or a startup XML file and validates it.

If the filename has the suffix C<.aiml>, the AIML validator, otherwise
the STARTUP validator is used.

The old stacks are used.

=cut

sub parseInclude				#	same as parseFile, but uses old stacks !
{
	my $self			= shift;
	my $file_name	= shift;

	$self->pushEnvironment();

	$self->{_file_name}		= $file_name;
	$self->{_file_line}		= 0;

#	$self->{_tag_stack}		= [];
#	$self->{_node_stack}		= [];

	$self->{_validate_root}	= ( $file_name =~ /\.aiml$/ ) ? $VALIDATE_AIML : $VALIDATE_STARTUP;

	$self->{_fh}				= new AIML::File;
	$self->{_lines}			= [];

	$self->{_text}				= '';

	$self->{_unknown_tag}	= '';

	$self->{_xml_version}	= 1.0;							#	default
	$self->{_xml_encoding}	= $AIML_ENCODING_UTF8;		#	default

	$self->{_fh}->open ( $self->{_file_name} )	or die "Can't open ", $self->{_file_name};

	$self->parselines();

	$self->{_fh}->close();

#	unless ( $self->{_error} )
#	{
#		my @not_closed = @ { $self->{_tag_stack} || [] };
#
#		$self->putError ( "Tags '@not_closed' not closed" )	if @not_closed;
#	}

	$self->popEnvironment();

	return not $self->{_error};
}

=pod

=item * parseRam ( $text )

This method parses an AIML text and validates it.

All stacks are reset.

=cut

sub parseRam
{
	my $self	= shift;
	my $xml	= shift;

	$self->pushEnvironment();

	$self->{_file_name}		= 'MEMORY';
	$self->{_validate_root}	= $VALIDATE_AIML;

	$self->{_xml_version}	= 1.0;							#	default
	$self->{_xml_encoding}	= $AIML_ENCODING_UTF8;		#	default

	$self->{_tag_stack}		= [];
	$self->{_file_line}		= 0;

	$self->{_lines}			= [];
	$self->{_fh}				= undef;

	$self->{_text}				= '';

	my @lines = split /\n/, $xml;

	local $_;
	map { $_ ."\n" } @lines;

	$self->{_lines}			= [ @lines ];

	$self->parselines();

	$self->popEnvironment();

	return not $self->{_error};
}

=pod

=item * parseTemplate ( $text )

This method parses an AIML text and does NOT validate it. It is
assumed, that the validation has been done during loading of an AIML
knowledge base.

$text is completed to 'E<lt>templateE<gt>$textE<lt>/templateE<gt>'.

All stacks are reset.

=cut

sub parseTemplate
{
	my $self	= shift;
	my $xml	= shift;

	$self->pushEnvironment();

	$self->{_file_name}		= 'TEMPLATE';
	$self->{_validate_root}	= undef;							#	fast mode for Responder.pm !

	$self->{_xml_version}	= 1.0;							#	always ?
	$self->{_xml_encoding}	= $AIML_ENCODING_UTF8;		#	always ?

	$self->{_tag_stack}		= [];
	$self->{_file_line}		= 0;

	$self->{_lines}			= [];
	$self->{_fh}				= undef;

	$self->{_text}				= '';

	$xml = '<template>' . $xml . '</template>';

	my @lines = split /\n/, $xml;

	local $_;
	map { $_ ."\n" } @lines;

	$self->{_lines}			= [ @lines ];

	$self->parselines();

	$self->popEnvironment();

	return not $self->{_error};
}

=pod

=back

More to come...

Please see source code for rudimentary documentation.

=over 4

=item * pushText

=item * popText

=item * pushAttr

=item * popAttr

=item * pushCondition

=item * popCondition

=item * ignore

=item * pushIgnore

=item * isIgnored

=item * popIgnore

=item * collect

=item * pushCollect

=item * isCollected

=item * popCollect

=item * pushEnvironment

=item * popEnvironment

=cut

sub pushText
{
	my $self	= shift;

	push @{$self->{_text_stack}}, $self->{_current_text};

	$self->{_current_text} = '';
}

sub popText
{
	my $self	= shift;

	$self->{_current_text} = pop @{$self->{_text_stack}} || '';
}

sub pushAttr
{
	my $self	= shift;
	my $attr	= shift;

	my $hash = { % { $attr || {} } };		#	copy !

	push @{$self->{_attr_stack}}, $hash;
}

sub popAttr
{
	my $self	= shift;

	return pop @{$self->{_attr_stack}} || {};
}

sub pushCondition
{
	my $self	= shift;

	my @text	= @ { $self->{_condition_text} || [] };
	my @attr	= @ { $self->{_condition_attr} || [] };

	local $_;
	map { $_ = { % { $_ || {} } } } @attr;		#	copy !

	push @{$self->{_condition_stack}}, { text => [ @text ], attr => [ @attr ] };

	$self->{_condition_text} = [];
	$self->{_condition_attr} = [];
}

sub popCondition
{
	my $self	= shift;

	my $cond = pop @{$self->{_condition_stack}} || {};

	$self->{_condition_text} = $cond->{text} || [];
	$self->{_condition_attr} = $cond->{attr} || [];
}

sub ignore	{ scalar @ { $_[0]->{_ignore_stack} || [] } }

sub pushIgnore
{
	my $self	= shift;
	my $type	= shift() || die;

	push @{$self->{_ignore_stack}}, $type;
}

sub isIgnored
{
	my $self	= shift;
	my $type	= shift() || die;

	return $type eq ( $self->{_ignore_stack}->[-1] || '<undef>' );
}

sub popIgnore
{
	my $self	= shift;

	pop @{$self->{_ignore_stack}};
}

sub collect	{ scalar @ { $_[0]->{_collect_stack} || [] } }

sub pushCollect
{
	my $self	= shift;
	my $type	= shift() || die;

	push @{$self->{_collect_stack}}, $type;
}

sub isCollected
{
	my $self	= shift;
	my $type	= shift() || die;

	return $type eq ( $self->{_collect_stack}->[-1] || '<undef>' );
}

sub popCollect
{
	my $self	= shift;

	pop @{$self->{_collect_stack}};
}

sub pushEnvironment
{
	my $self	= shift;

	my $hash	=
		{
			#	low level

			_file_name		=> $self->{_file_name},
			_file_line		=> $self->{_file_line},

			_tag_stack		=> [ @ { $self->{_tag_stack} || [] } ],		#	copy!
			_node_stack		=> [ @ { $self->{_node_stack} || [] } ],		#	copy!

			_validate_root	=> $self->{_validate_root},

			_fh				=> $self->{_fh},
			_lines			=> [ @ { $self->{_lines} || [] } ],				#	copy!

			_text				=> $self->{_text},

			_unknown_tag	=> $self->{_unknown_tag},

			_xml_version	=> $self->{_xml_version},
			_xml_encoding	=> $self->{_xml_encoding},

			#	high level - none...
	};

	push @ { $self->{_environment} }, $hash;
}

sub popEnvironment
{
	my $self	= shift;

	my $hash	= pop @ { $self->{_environment} };

	foreach my $key ( keys % { $hash || {} } )
	{
		$self->{$key} = $hash->{$key};
	}
}

=pod

=back

=head2 Callback Methods

The following methods do nothing and must be overwritten.

The parameter B<\@context> is always a reference to an array of tag types. E.g.:

   [ 'aiml', 'topic', 'category', 'template', 'srai' ]

or

   [ 'programv-startup', 'bots', 'bot', 'properties' ]

and might be empty.

=over 4

=item * startDocument ( \@context )

Called at the start of the parse.

=item * startTag ( \@context, $type, \%attr )

Called for every start tag with a second parameter of the element
type. The third parameter is a reference to a hash holding optional
attribute values supplied for that element.

=item * endTag ( \@context, $type )

Called for every end tag with a second parameter of the element type.

=item * tagContent ( \@context, $content );

Called just before start or end tags with accumulated non-markup text in
the $content parameter.

=item * piTag ( \@context, $type, $data )

Called for processing instructions. The PI and the data are sent as
2nd and 3rd parameters respectively.

=item * endDocument ( \@context )

Called at conclusion of the parse.

=cut

sub startDocument	{};
sub startTag		{};
sub endTag			{};
sub tagContent		{};
sub piTag			{};
sub endDocument	{};

=pod

=back

=head2 Other Methods

=over 4

=item * start_document I<PRIVATE>

=item * start_tag I<PRIVATE>

=item * end_tag I<PRIVATE>

=item * tag_content I<PRIVATE>

=item * pi_tag I<PRIVATE>

=item * end_document I<PRIVATE>

=item * get_line I<PRIVATE>

=item * get_chunk I<PRIVATE>

=item * get_element_node I<PRIVATE>

=item * validate_attr I<PRIVATE>

=item * validate_tag I<PRIVATE>

=item * validate_content I<PRIVATE>

=item * attr2hash I<PRIVATE>

=item * parselines I<PRIVATE>

=item * parse_text I<PRIVATE>

=item * handle_text I<PRIVATE>

=item * handle_comment I<PRIVATE>

=item * handle_cdata I<PRIVATE>

=item * handle_start I<PRIVATE>

=item * handle_end I<PRIVATE>

=item * handle_pi I<PRIVATE>

=cut

#
#	PARSER CALLBACK METHODS - LOW LEVEL
#
sub start_document
{
	my $self		= shift;

	my @context	= @ { $self->{_tag_stack} || [] };

	if ( $DEBUG )
	{
		my $text =
			sprintf "% 6d %s start_document '%s' XML version=%s encoding=%s",
				$self->fileline(),
				"@context",
				$self->filename(),
				$self->xmlVersion(),
				$self->xmlEncoding();

		debug $text;
	}

	$self->startDocument ( \@context );
}

sub start_tag
{
	my $self		= shift;
	my $type		= shift;
	my $attr		= shift;

	my @context		= @ { $self->{_tag_stack} || [] };

	my $ignored		= '';
	my $collected	= '';

	if ( $self->ignore )
	{
		$ignored	= "IGNORED";

		$self->pushIgnore ( $type );
	}

	if ( $self->collect )
	{
		$collected = "COLLECTED";

		$self->pushCollect ( $type );
	}

	if ( $DEBUG )
	{
		my $attr_s = Dumper ( $attr );

		flatString ( \$attr_s );

		$attr_s =~ s/^.*?\{(.*?)\}.*$/$1/;

		my $text =
			sprintf "% 6d %s \\\\ start_tag '%s' (%s) %s %s",
				$self->fileline(),
				"@context",
				$type,
				$attr_s,
				$ignored,
				$collected;

		debug $text;
	}

	return	if $ignored;

	if ( $self->collect )
	{
		my $tag = '<' . $type;

		foreach my $key ( keys % { $attr || {} } )
		{
			$tag .= ' ' . $key . '="' . $attr->{$key} . '"';
		}

		$tag .= '>';

		$self->{_current_text} .= $tag;
		return;
	}

	$self->startTag ( \@context, $type, $attr );
}

sub end_tag
{
	my $self	= shift;
	my $type	= shift;

	my @context		= @ { $self->{_tag_stack} || [] };

	my $ignored		= '';
	my $collected	= '';

	if ( $self->ignore )
	{
		$self->popIgnore();

		$ignored	= "IGNORED";
	}

	if ( $self->collect )
	{
		$collected = "COLLECTED";

		$self->popCollect();
	}

	if ( $DEBUG )
	{
		my $text =
			sprintf "% 6d %s // end_tag '%s' %s %s",
				$self->fileline(),
				"@context",
				$type,
				$ignored,
				$collected;

		debug $text;
	}

	return	if $ignored;		#	!!!

	if ( $self->collect )		#	!!!
	{
		$self->{_current_text} .= '</' . $type . '>';
		return;
	}

	$self->endTag ( \@context, $type );
}

sub tag_content
{
	my $self		= shift;
	my $content	= shift() || '';

	my @context		= @ { $self->{_tag_stack} || [] };

	if ( $DEBUG )
	{
		my $ignored		= '';
		my $collected	= '';

		if ( $self->ignore )
		{
			$ignored	= "IGNORED";
		}

		if ( $self->collect )
		{
			$collected = "COLLECTED";
		}

		my $text =
			sprintf "% 6d %s || tag_content '%s' %s %s",
				$self->fileline(),
				"@context",
				length ( $content ) > 42 ? substr ( $content, 0, 42 ) . '...' : $content,
				$ignored,
				$collected;

		debug $text;
	}

	return	if $self->ignore;

	if ( $self->collect )
	{
		$self->{_current_text} .= $content;
		return;
	}

	$self->tagContent ( \@context, $content );
}

sub pi_tag
{
	my $self		= shift;
	my $type		= shift;
	my $data		= shift() || '';

	my @context		= @ { $self->{_tag_stack} || [] };

	if ( $DEBUG )
	{
		my $ignored		= '';
		my $collected	= '';

		if ( $self->ignore )
		{
			$ignored	= "IGNORED";
		}

		if ( $self->collect )
		{
			$collected = "COLLECTED";
		}

		my $text =
			sprintf "% 6d %s || pi_tag '%s' (%s) %s %s",
				$self->fileline(),
				"@context",
				$type,
				$data,
				$ignored,
				$collected;

		debug $text;
	}

	return	if $self->ignore;

	if ( $self->collect )
	{
		$self->{_current_text} .= '<?' . $type;
		$self->{_current_text} .= ' ' . $data		if $data;
		$self->{_current_text} .= '?>';
		return;
	}

	$self->piTag ( \@context, $type, $data );
}

sub end_document
{
	my $self		= shift;

	my @context	= @ { $self->{_tag_stack} || [] };

	if ( $DEBUG )
	{
		my $text =
			sprintf "% 6d %s end_document '%s'",
				$self->fileline(),
				"@context",
				$self->filename();

		debug $text;
	}

	$self->endDocument ( \@context );
}

#
#	PRIVATE METHODS
#
sub get_line
{
	my $self	= shift;

	my $line = undef;

	if ( defined $self->{_fh} )
	{
		$line = $self->{_fh}->getline();
	}
	else
	{
		$line = shift @ { $self->{_lines} || [] };
	}

	if ( defined $line )
	{
		$line = convertString ( $line, $self->{_xml_encoding}, $AIML_ENCODING_UTF8 );

		$self->{_file_line}++;
	}

	return $line;
}

sub get_chunk
{
	my $self		= shift;
	my $rText	= shift;
	my $regex	= shift;

	my $line = undef;

	while ( $$rText !~ $regex )
	{
		$line = $self->get_line();

		last	unless defined $line;

		$$rText .= $line;
	}
}

sub get_element_node
{
#	print 'get_element_node ', Dumper ( \@_ );

	my $self		= shift;
	my $element	= shift;
	my $atomic	= shift;

#	print "get_element_node ( $element, $atomic )\n";

	die "NEVER COME HERE WITH '$element' for '$self->{_file_name}'"		unless defined $self->{_validate_root};

	my ( $parent, $node );

	my $error	= 0;
	my @stack	= ();

	$parent	= $self->{_node_stack}->[-1];
	$parent	= $self->{_validate_root}		unless defined $parent;

	$node		= $parent->{$element};

#	local $Data::Dumper::Maxdepth = 2;
#	print Dumper ( $node );

	if ( defined $node )
	{
		if		( $atomic and not $node->{_atomic} )
		{
			$node		= $parent->{ $element . '_atomic' };

			$error = 1	unless defined $node;
		}
		elsif	( not $atomic and $node->{_atomic} )
		{
			$error = 2;
		}
	}
	else
	{
		if		( $atomic )
		{
			$node		= $parent->{ $element . '_atomic' };

			$error = 2	unless defined $node;
		}
		else
		{
			$error = 3;
		}
	}

	@stack = @ { $self->{_tag_stack} || [] }		if $error;

	if		( $error == 1 )
	{
		$self->putError ( "In context '@stack' tag '$element' must have content" );
		return undef;
	}
	elsif	( $error == 2 )
	{
		$self->putError ( "In context '@stack' tag '$element' must be atomic" );
		return undef;
	}
	elsif	( $error == 3 )
	{
		$self->putError ( "Wrong context '@stack' for tag '$element'" );
		return undef;
	}
	else
	{
		return $node;
	}
}

sub validate_attr
{
	my $self		= shift;
	my $element	= shift;
	my $attr		= shift;
	my $node		= shift;

	if ( defined $node->{_attr} )
	{
		foreach my $key ( keys % { $node->{_attr} || {} } )
		{
			if ( not exists $attr->{$key} )													#	attribute missing !
			{
				if (	$node->{_default_attr} and
						$node->{_default_attr}->{$key} )										#	has default ?
				{
					$attr->{$key} = $node->{_default_attr}->{$key}->{_value};		#	use default !
				}
				else
				{
					$self->putError ( "Attribute '$key' for tag '$element' missing" );

					return false;
				}
			}
			elsif ( $attr->{$key} =~ $node->{_attr}->{$key} )							#	wellformed attribute !
			{
				if (	$node->{_default_attr} and
						$node->{_default_attr}->{$key} and
						$node->{_default_attr}->{$key}->{_dimension} )					#	has default index attribute ?
				{
					my ( $ndx1, $ndx2 ) = ( $1 || 0, $2 || 0 );

					if ( not $ndx1 )
					{
						$ndx1 = $node->{_default_attr}->{$key}->{_value1};				#	use default !
					}

					if ( not $ndx2 )
					{
						$ndx2 = $node->{_default_attr}->{$key}->{_value2};				#	use default !
					}

					if ( $node->{_default_attr}->{$key}->{_dimension} == 1 )			#	single index ?
					{
						$attr->{$key} = "$ndx1";
					}
					else
					{
						$attr->{$key} = "$ndx1,$ndx2";
					}
				}
			}
			else
			{
				$self->putError ( "Attribute '$key\=$attr->{$key}' for tag '$element' is not valid" );

				return false;
			}
		}
	}
	elsif ( defined $node->{_optional_attr} )
	{
		foreach my $key ( keys % { $node->{_optional_attr} || {} } )
		{
			next	unless exists $attr->{$key};

			if ( not $attr->{$key} =~ $node->{_optional_attr}->{$key} )
			{
				$self->putError ( "Optional attribute '$key\=$attr->{$key}' for tag '$element' is not valid" );

				return false;
			}
		}
	}
	else
	{
		if ( scalar keys % { $attr || {} } )
		{
			$self->putError ( "No attributes allowed for tag '$element'" );

			return false;
		}
	}

	return true;
}

sub validate_tag
{
#	print 'validate_tag ', Dumper ( \@_ );

	my $self		= shift;
	my $element	= shift;
	my $attr		= shift;
	my $atomic	= shift;

	return true		unless defined $self->{_validate_root};	#	fast mode for Responder.pm !

	my $node = $self->get_element_node ( $element, $atomic );

	return false	unless $node;

#	print "node found\n";

	return false	unless $self->validate_attr ( $element, $attr, $node );

#	print "attr ok\n";

	if ( defined $node->{_replace} )
	{
#		print ">>>>>>>>>>>>> START REPLACE\t", $self->fileline(), "\n";

		my $replace = $node->{_replace};

		my @lines	= @ { $self->{_lines} || [] };		#	save
		my $fh		= $self->{_fh};

		$self->{_lines}	= [];									#	reset
		$self->{_fh}		= undef;

		$self->parse_text ( \$replace );

		$self->{_lines}	= [ @lines ];						#	restore
		$self->{_fh}		= $fh;

#		print "<<<<<<<<<<<<< END REPLACE\t", $self->fileline(), "\n";

		return false;		#	skip further processing of this element...
	}

	push @ { $self->{_node_stack} }, $node;

	return true;
}

sub validate_content
{
#	print 'validate_content ', Dumper ( \@_ );

	my $self	= shift;
	my $text	= shift()	|| '';

	return true		unless defined $self->{_validate_root};	#	fast mode for Responder.pm !

	my $node		= $self->{_node_stack}->[-1];

	return false	unless defined $node;

	if ( defined $node->{_content} )
	{
		unless ( $text =~ $node->{_content} )
		{
			my $element	= $self->{_tag_stack}->[-1] || 'undef';

			$self->putError ( "Content '$text' for tag '$element' is not valid" );
			return false;
		}
	}

	return true;
}

sub attr2hash
{
#	print 'attr2hash ', Dumper ( \@_ );

	my $self	= shift;
	my $attr	= shift;

	my %hash	= ();

	while ( $attr =~ /((?:\w|_|-)+)\s*=\s*((?:\w|\d|_|-)+|".*?")/g )
	{
		my $name	= $1;
		my $val	= $2;

		$val	=~ s/(^["']|["']$)//g;

		#	special markup				only here?
		#
		$val =~ s/&quot;/\"/sg;
		$val =~ s/&gt;/\>/sg;
		$val =~ s/&lt;/\</sg;
		$val =~ s/&amp;/\&/sg;

		$hash{$name} = $val;
	}

#	print $attr, " ->\n", Dumper ( \%hash );

	return %hash;
}

sub parselines
{
	my $self	= shift;

	my $text = '';

	$self->start_document();

	return	if $self->{_error};

	while ( my $line = $self->get_line() )
	{
		$text .= $line;

		$self->parse_text ( \$text );

		return	if $self->{_error};
	}

	$self->handle_text ( $text );							#	the rest...

	return	if $self->{_error};

	$self->end_document();
}

sub parse_text
{
	my $self			= shift;
	my $rText		= shift;

	my ( $bg, $cont );

	my $regex = qr/^(.*?)<(\/?[^>]*?)>(.*)/s;		#	bg<cont>text OR bg</cont>text

	while ( true )
	{
		return	if $self->{_error};

		( $bg, $cont ) = ( '', '' );

		$self->get_chunk ( $rText, $regex );

		if ( $$rText =~ $regex )
		{
			( $bg, $cont, $$rText ) = ( $1, $2, $3 );
		}
		else
		{
			return;												#	eof
		}

		$self->handle_text ( $bg );

		return	if $self->{_error};

		#	process tag
		#
		if			( $cont =~ /^!--/s )						#	begin comment tag ?
		{
			$self->handle_comment ( $cont, $rText );
		}
		elsif		( $cont =~ /^!\[CDATA\[/s )			#	begin cdata tag ?
		{
			$self->handle_cdata ( $cont, $rText );
		}
		elsif		( $cont =~ /^!/s )						#	begin dtd tag ?
		{
			die "DTD tag '<$cont>' not supported yet.";
		}
		elsif		( $cont =~ /^\?/s )						#	pi tag ?
		{
			$self->handle_pi ( $cont, $rText );
		}
		elsif		( $cont =~ /^\w+/s )						#	start tag ?
		{
			$self->handle_start ( $cont, $rText );
		}
		elsif		( $cont =~ /^\/\w+/s )					#	end tag ?
		{
			$self->handle_end ( $cont, $rText );
		}
		else														#	what else ?
		{
			$self->handle_text ( "<$cont>" );
		}

		return	if $self->{_error};
	}
}

sub handle_text
{
	my $self	= shift;
	my $text	= shift;

	return	if $self->{_unknown_tag};

	return	unless $text;

	$self->{_text} .= $text;
}

sub handle_comment
{
	my $self		= shift;
	my $cont		= shift;
	my $rText	= shift;

	return	if $self->{_unknown_tag};

	if ( $cont =~ /^!--.*?--$/s )						#	complete comment tag ?
	{
		return;													#	skip
	}
	elsif ( $cont =~ /^!--/s )							#	begin comment tag
	{
		my $regex = qr/.*?-->(.*)/s;

		$self->get_chunk ( $rText, $regex );

		if ( $$rText =~ $regex )
		{
			$$rText = $1;
		}
		else
		{
			$self->putError ( "Tag '<$cont' not closed" );
		}
	}
	else
	{
		die "INTERNAL ERROR: '$cont'";
	}

	#	skip
}

sub handle_cdata
{
	my $self		= shift;
	my $cont		= shift;
	my $rText	= shift;

	return	if $self->{_unknown_tag};

	if ( $cont =~ /^!\[CDATA\[(.*?)\]\]$/s )	#	complete cdata tag ?
	{
		$cont = $1;
	}
	elsif ( $cont =~ /^!\[CDATA\[(.*)/s )		#	begin cdata tag
	{
		$cont = $1 . '>';		#	!!!

		my $regex = qr/(.*?)\]\]>(.*)/s;

		$self->get_chunk ( $rText, $regex );

		if ( $$rText =~ $regex )
		{
			$cont		.= $1;
			$$rText	= $2;
		}
		else
		{
			$self->putError ( "Tag '<$cont' not closed" );
		}
	}
	else
	{
		die "INTERNAL ERROR: '$cont'";
	}

	return	if $self->{_error};

	$self->handle_text ( $cont );
}

sub handle_start
{
	my $self		= shift;
	my $cont		= shift;
	my $rText	= shift;

	return	if $self->{_unknown_tag};

	if ( $self->{_text} )
	{
		if ( $self->validate_content ( $self->{_text} ) )
		{
			$self->tag_content ( $self->{_text} );
		}

		$self->{_text} = '';
	}

	my ( $tag, $attr, $atomic );

	if ( $cont =~ /^(\S*?)\s(.*)/s )					#	has attributes ?
	{
		( $tag, $attr ) = ( $1, $2 );
	}
	else
	{
		( $tag, $attr ) = ( $cont, '' );
	}

	$atomic	=		( $tag	=~ s/\s*?\/$// );		#	is atomic ?
	$atomic	||=	( $attr	=~ s/\s*?\/$// );

	$tag = lc ( $tag );

	my $is_aiml = 0;

	$is_aiml++		if $tag =~ s/^\/aiml\:/\//s;
	$is_aiml++		if $tag =~ s/^aiml\://s;

	if ( not $KNOWN_TAGS->{$tag} )
	{
		$attr = $attr ? ' ' . $attr : '';

		my $element = '';

		$tag = 'aiml:' . $tag		if $is_aiml;

		$element .= "<";
		$element .= "$tag$attr";
		$element .= '/'				if $atomic;
		$element .= '>';

		if		( $is_aiml )							#	forward compatible processing...
		{
			$self->putWarning ( "Unknown AIML start tag '$element' skipped" );

			$self->{_unknown_tag} = $tag;				#	skip all content untill </aiml:tag> !

			$self->handle_end ( $tag )		if $atomic;
			return;
		}
		elsif	( $element =~ /^\<\w+\:/ )	#	namespace attached...
		{
			$self->handle_text ( $element );
			return;
		}
		else												#	really unknown...
		{
			$self->putError ( "Unknown start tag '$element'" );
			return;
		}
	}

	my %hash = $self->attr2hash ( $attr );

	return	unless $self->validate_tag ( $tag, \%hash, $atomic );

	$self->start_tag ( $tag, \%hash );

	push @{$self->{_tag_stack}}, $tag;

	$self->handle_end ( $tag )		if $atomic;
}

sub handle_end
{
	my $self		= shift;
	my $cont		= shift;
	my $rText	= shift;

	my $tag = $cont;

	$tag =~ s/^\///;

	$tag = lc ( $tag );

	if ( $self->{_unknown_tag} eq $tag )
	{
		$self->{_unknown_tag} = '';
		return;
	}
	return	if $self->{_unknown_tag};

	if ( $self->{_text} )
	{
		if ( $self->validate_content ( $self->{_text} ) )
		{
			$self->tag_content ( $self->{_text} );
		}

		$self->{_text} = '';
	}

	my $is_aiml = 0;

	$is_aiml++		if $tag =~ s/^\/aiml\:/\//s;
	$is_aiml++		if $tag =~ s/^aiml\://s;

	if ( not $KNOWN_TAGS->{$tag} )
	{
		my $element = '';

		$tag = 'aiml:' . $tag		if $is_aiml;

		$element .= "<";
		$element .= "/";
		$element .= "$tag";
		$element .= '>';

		if		( $is_aiml )							#	forward compatible processing...
		{
			$self->putError ( "Unknown AIML end tag '$element'" );	#	tag mismatch !
			return;
		}
		elsif	( $element =~ /^\<\/\w+\:/ )	#	namespace attached...
		{
			$self->handle_text ( $element );
			return;
		}
		else
		{
			$self->putError ( "Unknown end tag '$element'" );
			return;
		}
	}

	pop @ { $self->{_node_stack} };

	my $expected	= pop @{$self->{_tag_stack}} || 'undef';

	my $error		= 0;

	$error++		unless $expected eq $tag;

	$self->putError ( "Tag '$expected' not closed, found '$tag' instead" )		if $error;

	return	if $error;

	$self->end_tag ( $tag );
}

sub handle_pi
{
	my $self		= shift;
	my $cont		= shift;
	my $rText	= shift;

	return	if $self->{_unknown_tag};

	if ( $cont =~ /^\?(.*?)\?$/s )				#	complete pi tag ?
	{
		$cont = $1;
	}
	elsif ( $cont =~ /^\?/s )						#	begin pi tag
	{
		my $regex = qr/(.*?)\?>(.*)/s;

		$self->get_chunk ( $rText, $regex );

		if ( $$rText =~ $regex )
		{
			$cont		= $1;
			$$rText	= $2;
		}
		else
		{
			$self->putError ( "Tag '<$cont' not closed" );
		}
	}
	else
	{
		die "INTERNAL ERROR: '$cont'";
	}

	return	if $self->{_error};

	my ( $tag, $data );

	if ( $cont =~ /^(\S*?)\s(.*)/s )				#	has data ?
	{
		( $tag, $data ) = ( $1, $2 );
	}
	else
	{
		( $tag, $data ) = ( $cont, '' );
	}

	if ( $tag eq 'xml' )								#	try to get xml version and encoding
	{
		my $attr	= $data || '';

		my %hash = $self->attr2hash ( $attr );

		$self->{_xml_version}	= $hash{version}		if exists $hash{version};
		$self->{_xml_encoding}	= $hash{encoding}		if exists $hash{encoding};
	}

	$self->pi_tag ( $tag, $data );
}

=pod

=back

=head1 ACKNOWLEDGEMENTS

=for html <p>
Thanks to Petr Kubanek for basic pure Perl parser ideas in
<a href="http://search.cpan.org/search?dist=XML-Clean">XML::Clean</a>.</p>

=for html <p>
Thanks to Larry Wall and Clark Cooper for the module
<a href="http://search.cpan.org/search?dist=XML-Parser">XML::Parser</a>
which inspired me a lot.</p>

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

L<AIML::Loader> and L<AIML::Responder>.

=cut

1;

__END__
