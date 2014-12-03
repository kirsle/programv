=head1 NAME

AIML::Handler - ModPerl handler for an AIML interpreter

=head1 SYNOPSIS

   # httpd.conf

   <VirtualHost>
      PerlSetEnv   AIML_CONFIG_FILE   /home/alice/programv/server.properties

      PerlModule   AIML::Handler

      <Location /talk>
         SetHandler   perl-script
         PerlHandler  AIML::Handler
      </Location>
   </VirtualHost>

=head1 DESCRIPTION

This module provides a server interface to an ALICE. It runs only
under Apache's mod_perl.

See L<README.server> on how to configure httpd.conf.

See C<handler> below for more information.

=cut

package AIML::Handler;

use strict;
use warnings;

BEGIN
{
	die "Use ", __PACKAGE__, " only in a mod_perl environment!"		unless $ENV{MOD_PERL};

	use vars qw ( $DEBUG $VERSION @ISA $TEMPLATE );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use Apache ();

use EnglishSave;

use AIML::Common 0.09;
use AIML::Config 0.09;
use AIML::Knowledge 0.09;
use AIML::Bot 0.09;

$TEMPLATE =								#	quick'n'dirty...
{
	filename	=>	AIML::Config::getConfigPath ( 'templates/html/talk.html' ),
	changed	=> time / ( 60 * 60 * 24 ),
	text		=> '',

};

AIML::Handler->getTemplate();

=head1 GLOBALS

   $AIML::Handler::DEBUG = 1;

Logs calls.

=head1 EXPORT

=head2 Public Attributes

None.

=head2 Public Constructors

C<new>

=head2 Public Methods

C<handler>

=head1 CONSTRUCTOR

=over 4

=item * new ( )

Creates an C<AIML::Handler>.

=cut

sub new
{
	my $class = shift;
	bless {@_}, $class;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

Methods marked as I<B<CALLBACK>> are automatically called from
C<Apache>, do not call them from outside.

=head2 Callback Method

=over 4

=item * handler ( $request ) I<B<CALLBACK>>

This method is called from the Apache server. The query can be send as
GET or POST request and contains the fields:

C<input>	The string entered by the user
C<user_id>	The user number from previous call.
C<bot_id>	The bot id from previous call.

If no field is given, the pattern defined in
C<programv.connect-string> is used, a new user id is created and the
first enabled bot is used.

The template is 'templates/html/talk.html' - hardcoded yet!

It can be changed without restarting Apache.

=cut

sub handler ($$)
{
	my $self		= shift;
	my $request	= shift;

	debug '>>>>>>>>>>>>>>>>>>>>>> ', __PACKAGE__, ' started'		if $DEBUG;

	unless ( ref($self) ) { $self = $self->new; }

	$self->{request} = $request;

	$self->_setup();

	my $response = '';

	unless ( $self->{input} and $self->{user_id} )
	{
		$self->{input} = AIML::Config::getConfig ( 'connect-string' );
	}

	$self->response();

	$self->print ( $self->{output} );

	debug '<<<<<<<<<<<<<<<<<<<<<< ', __PACKAGE__, ' stopped'		if $DEBUG;

	return Apache::Constants::OK();
}

=pod

=back

=head2 Other Methods

=over 4

=item * _setup ( ) I<PRIVATE>

=cut

sub _setup
{
	my $self = shift;

   $self->{request}->register_cleanup ( \&cleanup );

	my %in = $self->{request}->method eq 'POST' ? $self->{request}->content : $self->{request}->args;

#	debug Dumper ( \%in );

	$self->{input}		= defined $in{input} ? $in{input} : '';
	$self->{bot_id}	= $in{bot_id}	|| '';
	$self->{user_id}	= $in{user_id}	|| 0;

	unless ( $self->{bot_id} )
	{
		foreach my $bot_id ( AIML::Knowledge::activeBots() )
		{
			$self->{bot_id}		= $bot_id;

			last;		#	take first one...
		}
	}
}

=pod

=item * cleanup ( $request ) I<PRIVATE>

=cut

sub cleanup
{
	my $request	= shift;

	my $bot		= $request->pnotes ( 'bot' );

	return	unless $bot;

	my $input	= $bot->listener->as_text();
	my $output	= $bot->talker->as_text();

	flatString ( \$input );
	flatString ( \$output );

	logging ( undef, $bot->{bot_id}, $bot->{user_id}, '[input] ', $input );
	logging ( undef, $bot->{bot_id}, $bot->{user_id}, '[', int ( $bot->{response_time} * 1000 ), '] ', $output );

	$bot->save();		#	free lock on memory !!!
}

=pod

=item * response ( ) I<PRIVATE>

=cut

sub response
{
	my $self		= shift;

	my $input	= $self->{input};
	my $bot_id	= $self->{bot_id};
	my $user_id	= $self->{user_id};

	my $bot		= AIML::Bot->new
							(
								user_id			=> $user_id,
								bot_id			=> $bot_id,
							);

	$self->{request}->pnotes ( 'bot', $bot );

	my $talker = $bot->getResponse
							(
								$input,

								$AIML_SERVICE_TEXT,			#	IN
								$AIML_ENCODING_LATIN,		#	IN

								$AIML_SERVICE_HTML,			#	OUT
								$AIML_ENCODING_LATIN,		#	OUT
							);

	defined $talker	or die ( "Talker not defined" );

	$self->{response_time}	= $bot->{response_time}	|| 0;
	$self->{user_id}			= $bot->{user_id}			|| 0;

	$self->{output}			= $talker->as_string() || '';
}

=pod

=item * print ( $output ) I<PRIVATE>

This method prepares the template 'templates/html/talk.html' (hardcoded yet!) by
replacing the placeholder variables with the actual values.

So you are free how to position them.

In this template you'll find five placeholder variables:

C<alice.user_id.var>	current user id
C<alice.bot_id.var>	bot to talk to
C<alice.response_time.var>	duration of matching process
C<alice.input.var>	last user input
C<alice.output.var>	bot's answer

The processed template is then sent to the client.

=cut

sub print
{
	my $self		= shift;
	my $output	= shift;

	$output = ''		unless defined $output;

	my $input	= $self->{input};
	my $user_id	= $self->{user_id};
	my $bot_id	= $self->{bot_id};

	my $text		= $self->getTemplate();

	my $mTime	= $self->{response_time} || 0;
	my $sTime	= int ( $mTime * 1000 );

	$text			=~ s/(alice\.user_id\.var)/$user_id/;
	$text			=~ s/(alice\.bot_id\.var)/$bot_id/;
	$text			=~ s/(alice\.response_time\.var)/$sTime/;
	$text			=~ s/(alice\.input\.var)/$input/;
	$text			=~ s/(alice\.output\.var)/$output/;

	$self->{request}->print ( $text );
}

=pod

=item * getTemplate ( ) I<PRIVATE>

=cut

sub getTemplate
{
	my $self = shift;

	$self->readTemplate();

	return $TEMPLATE->{text};
}

=pod

=item * readTemplate ( ) I<PRIVATE>

=cut

sub readTemplate
{
	my $self	= shift;

	my $age	= -M $TEMPLATE->{filename};		#	in days...

	if	( $age < $TEMPLATE->{changed} )
	{
		my $fh = new AIML::File;

		$fh->open ( $TEMPLATE->{filename} )		or die "Can't open $TEMPLATE->{filename}\: $OS_ERROR";

		$TEMPLATE->{text} = $fh->slurp();

		$fh->close();

		if ( ref ( $self ) )
		{
			logging ( undef, $self->{bot_id}, $self->{user_id},
							$TEMPLATE->{filename}, ' re-read: ', $age, ' < ', $TEMPLATE->{changed} );
		}

		$TEMPLATE->{changed} = $age;
	}
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

L<AIML::Responder>, L<AIML::Knowledge>.

=cut

1;

__END__
