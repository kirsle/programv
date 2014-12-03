=head1 NAME

AIML::Listener - class

=head1 SYNOPSIS

   Coming soon...

=head1 DESCRIPTION

Coming soon...

=cut

package AIML::Listener;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use EnglishSave;

use AIML::Common 0.09;

=head1 GLOBALS

   $AIML::Listener::DEBUG = 1;

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
		input			=> '',
		service		=> undef,
		encoding		=> undef,
		memory		=> undef,

		%args,

		_input_ndx	=> 0,
		_input_list	=> [],
	};

	die ( 'memory is missing' )	unless $self->{memory};

	bless $self, $class;

	$self->init();

	return $self;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=over 4

=item * init ( ) I<PRIVATE>

=cut

sub init
{
	my $self		= shift;

	$self->{service}	||= $AIML_SERVICE_TEXT;		#	default
	$self->{encoding}	||= $AIML_ENCODING_ASCII;	#	default

	flatString ( \$self->{input} );

	$self->{input} = convertString ( $self->{input}, $self->{encoding}, $AIML_ENCODING_UTF8 );

	my $raSplitters			= $self->{memory}->getSentenceSplitters();
	my $rhSubstitutionMap	= $self->{memory}->getSubstitutesInput();

	my $input			= applySubstitutions ( $rhSubstitutionMap, $self->{input} );

	my $raSentences	= sentenceSplit ( $raSplitters, $input );

	$self->{_input_list}	= [ @$raSentences ];
	$self->{_input_ndx}	= 0;
}

=pod

=item * first ( )

=cut

sub first
{
	my $self		= shift;

	$self->{_input_ndx} = 0;

	return $self->{_input_list}->[0];
}

=pod

=item * next ( )

=cut

sub next
{
	my $self		= shift;

	$self->{_input_ndx}++;

	return $self->{_input_list}->[$self->{_input_ndx}];
}

=pod

=item * as_string ( )

=cut

#
#	EXPERIMENTAL !!!!!!!
#

sub as_string
{
	my $self = shift;

	#	collect output
	#
	my $text = $self->first();

	$text = ''	unless defined $text;

	while ( my $input = $self->next() )
	{
		$text .= "\n" . $input;
	}

	#	internal response...
	#
	if ( $self->{service} eq $AIML_SERVICE_AIML )
	{
		return $text;		#	as is...
	}

	#	que sera, sera...
	#
	if ( $self->{service} eq $AIML_SERVICE_VOICE )
	{
		die "NOT IMPLEMENTED YET";
	}

	#	prepare input
	#
	$text =~ s/\<\/\w+\:/\<\//sg;				#	strip namespace...	always?
	$text =~ s/\<\w+\:/\</sg;					#	strip namespace...	always?

	$text =~ s/\<br\>\<\/br\>/\<br\>/sg;	#	single break
	$text =~ s/\<br\/\>/\<br\>/sg;			#	for older browsers...

	#	wants html
	#
	if ( $self->{service} eq $AIML_SERVICE_HTML )
	{
		$text =~ s/\n/\<br\>/sg; 				#	exchange \n		with	<br>

		return $text;
	}

	#	wants text
	#
	if ( $self->{service} eq $AIML_SERVICE_TEXT )
	{
		$text =~ s/\<br\>/\n/sg;				#	exchange <br>	with	\n

		removeMarkup ( \$text );				#	faster pussycat - kill, kill!
		trimString ( \$text );

		return $text;
	}

	die "INTERNAL ERROR: Unknown service: ", $self->{service};
}

=pod

=item * as_is ( )

=cut

sub as_is
{
	my $self = shift;

	my $old_service = $self->{service};

	$self->{service} = $AIML_SERVICE_AIML;

	my $text = $self->as_string();

	$self->{service} = $old_service;

	return $text;
}

=pod

=item * as_text ( )

=cut

sub as_text
{
	my $self = shift;

	my $old_service = $self->{service};

	$self->{service} = $AIML_SERVICE_TEXT;

	my $text = $self->as_string();

	$self->{service} = $old_service;

	return $text;
}

=pod

=item * as_html ( )

=cut

sub as_html
{
	my $self = shift;

	my $old_service = $self->{service};

	$self->{service} = $AIML_SERVICE_HTML;

	my $text = $self->as_string();

	$self->{service} = $old_service;

	return $text;
}

=pod

=item * as_voice ( )

=cut

sub as_voice
{
	my $self = shift;

	my $old_service = $self->{service};

	$self->{service} = $AIML_SERVICE_VOICE;

	my $text = $self->as_string();

	$self->{service} = $old_service;

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

L<AIML::Talker> and L<AIML::Responder>.

=cut

1;

__END__
