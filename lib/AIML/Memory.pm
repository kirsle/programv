=head1 NAME

AIML::Memory - class

=head1 SYNOPSIS

   Coming soon...

=head1 DESCRIPTION

Coming soon...

=cut

package AIML::Memory;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use EnglishSave;

use AIML::Common 0.09;
use AIML::Config 0.09;
use AIML::Knowledge 0.09;
use AIML::File 0.09;

my @SAVE_KEYS =
	(
		'_predicates',
#		'_that_stack',
#		'_input_stack',
#		'_inputstar_stack',
#		'_thatstar_stack',
#		'_topicstar_stack',
#		'_pattern_stack',
		'_gossip',
	);

=head1 GLOBALS

   $AIML::Memory::DEBUG = 1;

Logs...

=head1 EXPORT

=head2 Public Attributes

=head2 Public Constructors

C<new>

=head2 Public Methods

=cut

=head1 CONSTRUCTOR

=over 4

=item * new ( %args )

Creates an C<AIML::Listener>.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my %args		= @_;

	my $self =
	{
		user_id				=> 0,
		bot_id				=> '',

		%args,

		_fh					=> undef,

		_predicates			=> {},

		_that_stack			=> [[]],
		_input_stack		=> [[]],

		_inputstar_stack	=> [],
		_thatstar_stack	=> [],
		_topicstar_stack	=> [],
		_pattern_stack		=> [],

		_gossip				=> [],
	};

	bless $self, $class;

	$self->_load();

	return $self;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=head2 Method Interface to AIML::Config

=over 4

=item * config ( ) I<PRIVATE>

=cut

sub config
{
	my $self	= shift;
	my $func	= (caller(1))[3];
	$func		=~ s/^.*::/AIML::Config::/;

	no strict 'refs';

	return $func->( @_ );
}

=pod

=item * getConfig ( )

=item * getConfigPath ( )

=cut

sub getConfig					{ shift()->config ( @_ ) };
sub getConfigPath				{ shift()->config ( @_ ) };

=pod

=back

=head2 Method Interface to AIML::Knowledge

=over 4

=item * knowledge ( ) I<PRIVATE>

=cut

sub knowledge
{
	my $self	= shift;
	my $func	= (caller(1))[3];
	$func		=~ s/^.*::/AIML::Knowledge::/;

	no strict 'refs';

	return $func->( $self->{bot_id}, @_ );
}

=pod

=item * activeBots ( )

=item * getKnowledge ( )

=item * getName ( )

=item * getPredicates ( )

=item * copyPredicates ( )

=item * getSentenceSplitters ( )

=item * getProperties ( )

=item * getSubstitutesInput ( )

=item * getSubstitutesPerson ( )

=item * getSubstitutesPerson2 ( )

=item * getSubstitutesGender ( )

=item * getPerl ( )

=item * getPatterns ( )

=item * getTemplates ( )

=cut

sub activeBots					{ shift()->knowledge ( @_ ) };
sub getKnowledge				{ shift()->knowledge ( @_ ) };
sub getName						{ shift()->knowledge ( @_ ) };
sub getPredicates				{ shift()->knowledge ( @_ ) };
sub copyPredicates			{ shift()->knowledge ( @_ ) };
sub getSentenceSplitters	{ shift()->knowledge ( @_ ) };
sub getProperties				{ shift()->knowledge ( @_ ) };
sub getSubstitutesInput		{ shift()->knowledge ( @_ ) };
sub getSubstitutesPerson	{ shift()->knowledge ( @_ ) };
sub getSubstitutesPerson2	{ shift()->knowledge ( @_ ) };
sub getSubstitutesGender	{ shift()->knowledge ( @_ ) };
sub getPerl						{ shift()->knowledge ( @_ ) };
sub getPatterns				{ shift()->knowledge ( @_ ) };
sub getTemplates				{ shift()->knowledge ( @_ ) };

=pod

=back

=head2 Other Methods

=over 4

=item * _load ( ) I<PRIVATE>

=cut

sub _load
{
	my $self = shift;

	$self->{_predicates}	= $self->copyPredicates();
	$self->{_fh}			= undef;

	$self->new_user_id()		unless $self->{user_id};

	if ( $self->{user_id} )
	{
		local $Data::Dumper::Indent = 1;

		my $file_name = $self->getConfigPath ( 'data/user' . $self->{user_id} . '.data' );

		my $VAR1 = {};		#	for eval

		my $fh = AIML::File->new();

		unless ( -e $file_name )
		{
			$fh->open ( "> $file_name" )		or die "Can't create $file_name\: $OS_ERROR";
			$fh->putline ( Dumper ( $VAR1 ) );
			$fh->close;
		}

		$fh->open ( "+< $file_name" )		or die "Can't open $file_name\: $OS_ERROR";

		my $memory = $fh->slurp();

		eval ( $memory );

		if ( $EVAL_ERROR )
		{
			my @lines = split /\n/, $memory;
			my $i = 0;
			map { $i++; $_ = "$i\:\t" . $_ . "\n"; } @lines;

			$memory = "@lines";

			die "Can't create memory: $EVAL_ERROR\n", $memory;
		}

		$self->{_fh} = $fh;

		foreach my $key ( keys % { $VAR1 || {} } )
		{
			$self->{$key} = $VAR1->{$key};
		}
	}
	else
	{
		die "Can't create user id";
	}
}

=pod

=item * DESTROY ( ) I<PRIVATE>

This method is automatically called on destruction of an C<AIML::Memory> object.

Tries to call C<save>, which might be to late here...

=cut

sub DESTROY
{
	my $self = shift;

	$self->save();					#	This is to late because of references to
										#	AIML::Memory in other objects still alive
										#	-> 'No locks' !
										#	See AIML::Bot::save
}

=pod

=item * save ( )

=cut

sub save
{
	my $self = shift;

	return false	unless defined $self->{_fh};
	return false	unless $self->{_fh}->opened();

	local $Data::Dumper::Indent = 1;

	my $memory = {};

	foreach my $key ( @SAVE_KEYS )
	{
		$memory->{$key} = $self->{$key};		#	don't dump AIML::Memory object directly...
	}

	#
	#	forget
	#
	while ( scalar @ { $memory->{_predicates}->{input}->{values} || [] } > 42 )	#	forget value....
	{
		shift @ { $memory->{_predicates}->{input}->{values} };
	}

	while ( scalar @ { $memory->{_predicates}->{that}->{values} || [] } > 42 )	#	forget value....
	{
		shift @ { $memory->{_predicates}->{that}->{values} };
	}

	$self->{_fh}->putline ( Dumper ( $memory ) );

	$self->{_fh}->close;

	return true;
}

=pod

=item * new_user_id ( ) I<PRIVATE>

=cut

sub new_user_id
{
	my $self = shift;

	my $file_name = $self->getConfigPath ( 'data/uid' );

	my $fh = AIML::File->new();

	my $user_id = 0;

	unless ( -e $file_name )
	{
		$fh->open ( "> $file_name" )		or die "Can't create $file_name\: $OS_ERROR";
		$fh->putline ( $user_id );
		$fh->close;
	}

	$fh->open ( "+< $file_name" )		or die "Can't open $file_name\: $OS_ERROR";

	chomp ( $user_id = $fh->getline );

	$user_id++;

	$fh->truncate ( 0 );
	$fh->putline ( $user_id );
	$fh->close;

	$self->{user_id} = $user_id;
}

=pod

=item * nameOrValue ( ) I<PRIVATE>

=cut

sub nameOrValue
{
	my $self		= shift;
	my $name		= shift() || '';
	my $value	= shift;

	die ( 'name missing' )		unless $name;

	$value	= ''		unless defined $value;

	my $set_return = $self->{_predicates}->{$name}->{'set-return'};

	$set_return = ''		unless defined $set_return;

	return $name	if $set_return eq 'name';

	return $value;
}

=pod

=item * set ( ) I<PRIVATE>

=cut

sub set
{
	my $self		= shift;
	my $name		= shift() || '';
	my $value	= shift;
	my $index	= shift() || '';

	die ( 'name missing' )		unless $name;

	$index	=~ /^(\d+)$/;
	my $ndx1 = $1 ? $1 : 1;

	die ( 'index negative' )	if $ndx1 < 0;

	$value	= ''		unless defined $value;

#	print "set ( $name, $value, $index )\n";

#	if ( not exists $self->{_predicates}->{$name} )
#	{
#		$self->{_predicates}->{$name}->{values} = [ '' ];
#	}

#	print "_precdicates=\n", Dumper ( $self->{_predicates} );

#	if ( not scalar @ { $self->{_predicates}->{$name}->{values} } )
	if ( not scalar @ { $self->{_predicates}->{$name}->{values} || [] } )
	{
#		$self->{_predicates}->{$name}->{values} = [ '' ];
		$self->{_predicates}->{$name}->{values} = [];
	}

	debug ( "IN  set ( '$name', '$value', '$index', [-$ndx1] ->\n", Dumper ( $self->{_predicates}->{$name}->{values} ) )	if $DEBUG;

	foreach my $i ( 0 .. ( $ndx1 - 1 ) )
	{
		next	if exists $self->{_predicates}->{$name}->{values}->[$i];

		$self->{_predicates}->{$name}->{values}->[$i] = undef;
	}

	$self->{_predicates}->{$name}->{values}->[-$ndx1] = $value;

	debug ( "OUT set ( '$name', '$value', '$index', [-$ndx1] ->\n", Dumper ( $self->{_predicates}->{$name}->{values} ) )	if $DEBUG;

	return $self->nameOrValue ( $name, $value );
}

=pod

=item * push ( ) I<PRIVATE>

=cut

sub push
{
	my $self		= shift;
	my $name		= shift() || '';
	my $value	= shift;

	die ( 'name missing' )		unless $name;

	$value	= ''		unless defined $value;

#	if ( not exists $self->{_predicates}->{$name} )
	if ( not scalar @ { $self->{_predicates}->{$name}->{values} || [] } )
	{
		$self->{_predicates}->{$name}->{values} = [];
	}

	CORE::push @ { $self->{_predicates}->{$name}->{values} }, $value;
}

=pod

=item * get ( ) I<PRIVATE>

=cut

sub get
{
	my $self		= shift;
	my $name		= shift() || '';
	my $index	= shift() || '';

	die ( 'name missing' )		unless $name;

	$index =~ /^(\d+)$/;

	my $ndx1 = $1 ? $1 : 1;

	die ( 'index negative' )	if $ndx1 < 0;

	my $value = '';

#	if ( not exists $self->{_predicates}->{$name} )
	if ( not scalar @ { $self->{_predicates}->{$name}->{values} || [] } )
	{
#		$self->{_predicates}->{$name}->{values} = [ '' ];
		$self->{_predicates}->{$name}->{values} = [];
	}

	debug ( "get ( '$name', '$value', '$index', [-$ndx1] ->\n", Dumper ( $self->{_predicates}->{$name}->{values} ) )	if $DEBUG;

	$value = $self->{_predicates}->{$name}->{values}->[-$ndx1];

	$value = $self->{_predicates}->{$name}->{default}		unless defined $value;

#	$value = $self->getConfig ( 'emptydefault' )				unless defined $value;
#
#	BUGFIX
	$value = ''															unless defined $value;

	return $value;
}

=pod

=item * getStar ( )

=cut

sub getStar
{
	my $self		= shift;
	my $index	= shift() || '';

	$index =~ /^(\d+)$/;

	my $ndx1 = $1 ? $1 : 1;

#	my $text = $self->{_inputstar_stack}->[-$ndx1] || "getSTAR${ndx1}undef";

	my $text = $self->{_inputstar_stack}->[-$ndx1];

	debug ( "getStar '$index', [$ndx1]\n", Dumper ( $self->{_inputstar_stack} ) )		if $DEBUG;

#	$text = "getSTAR${ndx1}undef"				unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getSTAR ( $ndx1 ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getThat ( )

=cut

sub getThat
{
	my $self		= shift;
	my $index	= shift() || '';

	$index =~ /^(\d+)\,?(\d?)$/;

	my $ndx1 = $1 ? $1 : 1;
	my $ndx2 = $2 ? $2 : 1;

#	my $text = $self->{_that_stack}->[-$ndx1][$ndx2] || "getTHAT${ndx1}${ndx2}undef";

	my $raSplitters	= $self->getSentenceSplitters();
	my $raSentences	= sentenceSplit ( $raSplitters, $self->get ( 'that', $ndx1 ) );

	debug ( "getThat '$index', [$ndx1,$ndx2]\n", Dumper ( $raSentences ) )		if $DEBUG;

#	my $that				= $raSentences->[-$ndx2] || "getTHAT${ndx1}${ndx2}undef";

	my $that				= $raSentences->[-$ndx2];

#	$that = "getTHAT${ndx1}${ndx2}undef"	unless defined $that;

	unless ( defined $that )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getTHAT ( $ndx1, $ndx2 ) = undef" );

		$that = '';
	}

	return $that;
}

=pod

=item * getInput ( )

=cut

sub getInput
{
	my $self		= shift;
	my $index	= shift() || '';

	$index =~ /^(\d+)\,?(\d?)$/;

	my $ndx1 = $1 ? $1 : 1;
	my $ndx2 = $2 ? $2 : 1;

	my $raSplitters	= $self->getSentenceSplitters();
	my $raSentences	= sentenceSplit ( $raSplitters, $self->get ( 'input', $ndx1 ) );

	debug ( "getInput '$index', [$ndx1,$ndx2]\n", Dumper ( $raSentences ) )		if $DEBUG;

	my $text				= $raSentences->[-$ndx2];

#	$text = "getINPUT${ndx1}${ndx2}undef"	unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getINPUT ( $ndx1, $ndx2 ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getThatstar ( )

=cut

sub getThatstar
{
	my $self		= shift;
	my $index	= shift() || '';

	$index =~ /^(\d+)$/;

	my $ndx1 = $1 ? $1 : 1;

#	my $text = $self->{_thatstar_stack}->[-$ndx1] || "getTHATSTAR${ndx1}undef";

	my $text = $self->{_thatstar_stack}->[-$ndx1];

#	$text = "getTHATSTAR${ndx1}undef"		unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getTHATSTAR ( $ndx1 ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getTopicstar ( )

=cut

sub getTopicstar
{
	my $self		= shift;
	my $index	= shift() || '';

	$index =~ /^(\d+)$/;

	my $ndx1 = $1 ? $1 : 1;

	debug ( "getTopicstar '$index', [$ndx1]\n", Dumper ( $self->{_topicstar_stack} ) )	if $DEBUG;

#	my $text = $self->{_topicstar_stack}->[-$ndx1] || "getTOPICSTAR${ndx1}undef";

	my $text = $self->{_topicstar_stack}->[-$ndx1];

#	$text = "getTOPICSTAR${ndx1}undef"		unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getTOPICSTAR ( $ndx1 ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getGet ( )

=cut

sub getGet
{
	my $self		= shift;
	my $name		= shift() || 'undefined';

	my $text = $self->get ( $name );

#	$text = "getGET${name}undef"				unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getGET ( $name ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getBot ( )

=cut

sub getBot
{
	my $self		= shift;
	my $name		= shift() || 'undefined';

	my $props	= $self->getProperties ( $self->{bot_id} ) || {};

	my $text		= $props->{$name};

#	$text = "getBOT${name}undef"				unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getBOT ( $name ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getDate ( )

=cut

sub getDate
{
	my $self		= shift;

	my $text		= localtime;

	return $text;
}

=pod

=item * getId ( )

=cut

sub getId
{
	my $self		= shift;

	my $text		= $self->{user_id};

#	$text = "getIDundef"							unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getID () = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getSize ( )

=cut

sub getSize
{
	my $self		= shift;

	my $text		= scalar @ { $self->getTemplates() || [] };

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getSize () = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * getVersion ( )

=cut

sub getVersion
{
	my $self		= shift;

	my $text		= $VERSION;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "getVersion () = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * setGet ( )

=cut

sub setSet
{
	my $self		= shift;
	my $name		= shift() || 'undefined';
	my $text		= shift;

	$text = $self->set ( $name, $text );

#	$text = "setSET${name}undef"				unless defined $text;

	unless ( defined $text )
	{
		logging ( undef, $self->{bot_id}, $self->{user_id}, "setSET ( ${name} ) = undef" );

		$text = '';
	}

	return $text;
}

=pod

=item * setGossip ( )

=cut

sub setGossip
{
	my $self		= shift;
	my $text		= shift;

	$text	= ''		unless defined $text;

	CORE::push @ { $self->{_gossip} }, $text;

	return $text;
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

L<AIML::Responder>, L<AIML::Config> and L<AIML::Knowledge>.

=cut

1;

__END__
