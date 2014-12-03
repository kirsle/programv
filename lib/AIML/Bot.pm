=head1 NAME

AIML::Bot - AIML bot object class

=head1 SYNOPSIS

   use AIML::Common;
   use AIML::Bot;

   ( $input, $bot_id, $user_id ) = @ARGV;

   $bot = AIML::Bot->new
          (
             user_id => $user_id,
             bot_id  => $bot_id,
          );

   $talker = $bot->getResponse
             (
                $input,

                $AIML_SERVICE_TEXT,   # IN
                $AIML_ENCODING_LATIN, # IN

                $AIML_SERVICE_TEXT,   # OUT
                $AIML_ENCODING_LATIN, # OUT
             );

   $response_time = $bot->{response_time} || 0;

   $bot->save();

   print 'Reponse in ', $response_time, " msec\n";

   print $talker->as_string();

=head1 DESCRIPTION

This module provides a simple interface to the complete chatbot
functionality of an ALICE.

See L<AIML::Shell> or L<AIML::Handler> for concrete implementations.

=cut

package AIML::Bot;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use Time::HiRes qw ( gettimeofday tv_interval );

use EnglishSave;

use AIML::Common 0.09;

use AIML::Memory 0.09;
use AIML::Listener 0.09;
use AIML::Talker 0.09;
use AIML::Responder 0.09;

=head1 GLOBALS

   $AIML::Bot::DEBUG = 1;

Logs calls to C<getResponse>.

=head1 EXPORT

=head2 Public Attributes

None.

=head2 Public Constructors

C<new>

=head2 Public Methods

C<getResponse>, C<save>

=cut

=head1 CONSTRUCTOR

=over 4

=item * new ( %args )

Creates an C<AIML::Bot>.

The constructor takes a hash with one or two entries:

     bot_id   => 'TestBot-1',
   [ user_id  => 12345 ].

A missing C<bot_id> is a fatal error. If C<user_id> is missing, a new
user is assumed.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my %args		= @_;

	my $self =
	{
		user_id		=> 0,
		bot_id		=> '',

		%args,
	};

	die ( 'bot id undefined' )					unless $self->{bot_id};

	bless $self, $class;
}

=pod

=back

=head1 ATTRIBUTES

Do not overwrite and call attributes marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * listener ( ) I<READONLY>

Autocreates and returns the current C<AIML::Listener> object. Only
valid after a call to C<getResponse>!

=item * talker ( ) I<READONLY>

Autocreates and returns the current C<AIML::Talker> object. Only
valid after a call to C<getResponse>!

=item * memory ( ) I<READONLY>

Autocreates and returns the current C<AIML::Memory> object.

=item * responder ( ) I<READONLY>

Autocreates and returns the current C<AIML::Responder> object. Only
valid after a call to C<getResponse>!

Autocreates C<listener>, C<talker> and C<memory> as well.

=cut

sub listener
{
	my $self = shift;

	unless ( defined $self->{listener} )
	{
		$self->{listener}	= AIML::Listener->new
									(
										input		=> $self->{_input},
										service	=> $self->{_service_in},
										encoding	=> $self->{_encoding_in},
										memory	=> $self->memory(),
									);
	}

	return $self->{listener};
}

sub talker
{
	my $self = shift;

	unless ( defined $self->{talker} )
	{
		$self->{talker}	= AIML::Talker->new
									(
										service	=> $self->{_service_out},
										encoding	=> $self->{_encoding_out},
										memory	=> $self->memory(),
									);
	}

	return $self->{talker};
}

sub memory
{
	my $self = shift;

	unless ( defined $self->{memory} )
	{
		$self->{memory}	= AIML::Memory->new
									(
										user_id	=> $self->{user_id},
										bot_id	=> $self->{bot_id},
									);
	}

	return $self->{memory};
}

sub responder
{
	my $self = shift;

	unless ( defined $self->{responder} )
	{
		$self->{responder}	= AIML::Responder->new
									(
										listener	=> $self->listener(),
										talker	=> $self->talker(),
										memory	=> $self->memory(),
									);
	}

	return $self->{responder};
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * _clear ( ) I<PRIVATE>

=cut

sub _clear
{
	my $self = shift;

	$self->{responder}	= undef,
	$self->{memory}		= undef,
	$self->{listener}		= undef;
	$self->{talker}		= undef;
}

=pod

=item * _init ( ) I<PRIVATE>

=cut

sub _init
{
	my $self = shift;

	$self->_clear();
	$self->responder();
}

=pod

=item * getResponse ( $input [, $service_in [, $encoding_in [, $service_out [, $encoding_out ]]]] )

This method takes the input string and returns the output in an C<AIML::Talker> object.

The parameters default to:

$input	''
$service_in	L<C<$AIML_SERVICE_TEXT>|AIML::Common/export>
$encoding_in	L<C<$AIML_ENCODING_LATIN>|AIML::Common/export>
$service_out	L<C<$AIML_SERVICE_TEXT>|AIML::Common/export>
$encoding_out	L<C<$AIML_ENCODING_LATIN>|AIML::Common/export>

=cut

sub getResponse
{
	my $self				= shift;
	my $input			= shift;
	my $service_in		= shift;
	my $encoding_in	= shift;
	my $service_out	= shift;
	my $encoding_out	= shift;

	$input = ''		unless defined $input;

	debug __PACKAGE__, "::getResponse ( '$input' )"		if $DEBUG;

	$self->{_input}			= $input;
	$self->{_service_in}		= $service_in		|| $AIML_SERVICE_TEXT;
	$self->{_encoding_in}	= $encoding_in		|| $AIML_ENCODING_LATIN;
	$self->{_service_out}	= $service_out		|| $AIML_SERVICE_TEXT;
	$self->{_encoding_out}	= $encoding_out	|| $AIML_ENCODING_LATIN;

	$self->_init();

	my ( @t0, $t1 );

	@t0 = gettimeofday();

	$self->responder->getResponse();

	$t1 = tv_interval ( \@t0 );

	$self->{response_time} = $t1;

	$self->{user_id}	= $self->memory->{user_id};

	return $self->talker();
}

=pod

=item * DESTROY ( ) I<PRIVATE>

This method is automatically called on destruction of an C<AIML::Bot> object.

Tries to call C<save>, which might be to late here...

=cut

sub DESTROY
{
	my $self = shift;

	$self->save();
}

=pod

=item * save ( )

This method saves the user environment. See L<AIML::Memory> for details.

Must be called from outside to unlock resources!

See L<AIML::Shell> and L<AIML::Handler> for examples.

=cut

sub save
{
	my $self = shift;

	$self->{memory}->save()		if defined $self->{memory};
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

L<AIML::Listener>, L<AIML::Memory>, L<AIML::Talker>,
L<AIML::Responder> and L<AIML::Shell> or L<AIML::Handler>.

=cut

1;

__END__
