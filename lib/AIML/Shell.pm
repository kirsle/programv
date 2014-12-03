=head1 NAME

AIML::Shell - class

=head1 SYNOPSIS

   Coming soon...

=head1 DESCRIPTION

Coming soon...

=cut

package AIML::Shell;

use strict;
use warnings;

BEGIN
{
	die "Use ", __PACKAGE__, " not in a mod_perl environment!"		if $ENV{MOD_PERL};

	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use Fcntl;
use File::Spec;
use EnglishSave;
use Term::ReadKey;

use Time::HiRes qw ( gettimeofday tv_interval );

use AIML::Common 0.09;
use AIML::Config 0.09;
use AIML::Knowledge 0.09;
use AIML::Bot 0.09;

#
#	OPEN I/O
#

#	this wurks not for pipes on windoze!
#
#	if ( $OSNAME =~ /Win32/i )
#	{
#		sysopen ( IN,	'CONIN$',	O_RDWR )		or die "Unable to open console input: $OS_ERROR";
#		sysopen ( OUT,	'CONOUT$',	O_RDWR )		or die "Unable to open console output: $OS_ERROR";
#	}
#	else
#	{
#		*IN	= *STDIN;
#		*OUT	= *STDOUT;
#	}

*IN	= *STDIN;
*OUT	= *STDOUT;

IN->autoflush ( 1 );
OUT->autoflush ( 1 );

binmode IN;
binmode OUT;

#
#	PRIVATE VARS
#

my $HELP_TEXT =<<'EOT';

	Type your query and hit <return>
	Characters will always be inserted

	Keys:
	left arrow     one character left
	right arrow    one character right
	backspace      delete left character
	up arrow       recall last input
	down arrow     recall next input
	Ctrl-C         exit shell

	Commands:
	/help				this text
	/exit				exit shell

EOT

my @CHARS_IN = ();

												#				console		telnet	windows

my $BREAK		= "\x03";				#				^C				^C			^C

my $BELL			= "\x07";				#	<beep>

my $ESCAPE		= "\x1B";				#				^[				^[			^[
my $ESCAPE2		= "\x5B";				#	[

my $ARROW_LEFT	= "\x1B\x5B\x44";		#				^[ [ D		^[ [ D	^@ = \x00 ????
my $ARROW_UP	= "\x1B\x5B\x41";		#				^[ [ A		^[ [ A	^@
my $ARROW_RIGHT= "\x1B\x5B\x43";		#				^[ [ C		^[ [ C	^@
my $ARROW_DOWN	= "\x1B\x5B\x42";		#				^[ [ B		^[ [ B	^@
my $BACKSPACE	= "\x08";				#	<8>		127			^H			^H
my $DELETE		= "\x7F";				#	<127>		^[ [ 3 ~		127		^@

												#	<enter>	^J				^J			^M

my $CR			= "\x0D";				#	^J
my $LF			= "\x0A";				#	^M

my $WIN_ARROW_LEFT	= "\x1B\x5B\x31\x44";		#	^[ [ 1 D
my $WIN_ARROW_RIGHT	= "\x1B\x5B\x31\x43";		#	^[ [ 1 C

my $UP			= "\x1C";
my $DOWN			= "\x1D";
my $LEFT			= "\x1E";
my $RIGHT		= "\x1F";


my @INPUT_STACK		= ();
my $INPUT_STACK_POS	= 0;

=head1 GLOBALS

   $AIML::Shell::DEBUG = 1;

Logs each keystroke (huge output).

=head1 EXPORT

=head2 Public Attributes

=head2 Public Constructors

C<new>

=head2 Public Methods

=cut

=head1 CONSTRUCTOR

=over 4

=item * new ( %args )

Creates an C<AIML::Shell>.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my %args		= @_;

	$args{config_file}	= './server.properties'	unless $args{config_file};
	$args{config_file}	= File::Spec->rel2abs ( $args{config_file} );

	die ( "File $args{config_file} not found" )	unless -e $args{config_file};

	my $self		=
	{
		config_file	=> $args{config_file},
	};

	bless $self, $class;

	$self->_setup();

	return $self;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=over 4

=item * _setup ( ) I<PRIVATE>

=cut

sub _setup
{
	my $self = shift;

	AIML::Config::LOAD_AIML_CONFIG ( $self->{config_file} );		#	direct loading...

	my $knowledge_file = AIML::Config::getConfigPath ( 'runfile' );

	my ( @t0, $t1 );

	@t0 = gettimeofday();

	AIML::Knowledge::LOAD_AIML_KNOWLEDGE ( $knowledge_file );	#	direct loading...

	$t1 = tv_interval ( \@t0 );

	foreach my $bot_id ( AIML::Knowledge::activeBots() )
	{
		$self->{bot_id}		= $bot_id;
		$self->{bot_prompt}	= AIML::Knowledge::getName ( $bot_id ) .  ' > ';

		last;		#	take first one...
	}

	$self->{user_id}		= 1;

	$self->{user_prompt}	= 'user > ';

	while ( length $self->{user_prompt} > length $self->{bot_prompt} )
	{
		$self->{bot_prompt} =~ s/ > $/  > /;
	}

	while ( length $self->{user_prompt} < length $self->{bot_prompt} )
	{
		$self->{user_prompt} =~ s/ > $/  > /;
	}

	print OUT "\nAIML Shell version $VERSION\n\n";

	print OUT "using configuration file : $self->{config_file}\n";
	print OUT "using knowledge file     : $knowledge_file\n";
	print OUT "working with bot         : $self->{bot_id}\n";
	print OUT "user no.                 : $self->{user_id}\n";
	print OUT "\t", scalar @ { AIML::Knowledge::getTemplates ( $self->{bot_id} ) || [] };
	print OUT " categories loaded in $t1 sec\n";

#		my @stats = stat ( IN );
#
#		print Dumper ( \@stats );
#		die;
#
#	FILE:							STDIN:
#
#				 0,					 0,	  0 dev      device number of filesystem
#				 0,					 0,	  1 ino      inode number
#				 33206,				 8192,  2 mode     file mode  (type and permissions)
#				 1,					 1,	  3 nlink    number of (hard) links to the file
#				 0,					 0,	  4 uid      numeric user ID of file's owner
#				 0,					 0,	  5 gid      numeric group ID of file's owner
#				 0,					 0,	  6 rdev     the device identifier (special files only)
#				 3969,				 0,	  7 size     total size of file, in bytes
#				 1026055500,		 0,	  8 atime    last access time in seconds since the epoch
#				 1026054916,		 0,	  9 mtime    last modify time in seconds since the epoch
#				 1024499158,		 0,	 10 ctime    inode change time (NOT creation time!) in seconds since the epoch
#				 '',					 '',	 11 blksize  preferred block size for file system I/O
#				 ''					 ''	 12 blocks   actual number of blocks allocated

	if ( ( stat ( IN ) ) [7] )		#	has filesize?
	{
		$self->{_batch_mode}	= true;

		debug "BATCH MODE!"		if $DEBUG;
	}
	else
	{
		$self->{_batch_mode}	= false;

		debug "CONSOLE MODE!"	if $DEBUG;
	}
}

=pod

=item * getChar ( ) I<PRIVATE>

=cut

sub getChar
{
	my $self		= shift;

	my $key		= '';
	my $sub_key = '';

	{
		debug "Credo\tk=$key\ts=$sub_key"		if $DEBUG;

		if ( $OSNAME =~ /Win32/i )
		{
			$key = getc ( IN );

			$key = $BREAK		if not defined $key;

			if		( $key eq $LF )		#	unix testcase.txt !!!
			{
				$key = $CR;
			}
			elsif	( $key eq $CR )		#	windows testcase.txt !!!
			{
				$key = getc ( IN );		#	read $LF !

				debug ( sprintf "Wcr\t key = %#+04x", ord ( $key ) )		if $DEBUG;

				$key = $CR;
			}
			else
			{
				#	ok
			}
		}
		else
		{
			while ( not defined ( $key = ReadKey ( -1, \*IN ) ) )
			{
				# No key yet
			}

			if		( $key eq $LF )		#	unix testcase.txt !!!
			{
				$key = $CR;
			}
			elsif	( $key eq $CR )		#	windows testcase.txt !!!
			{
				redo;							#	read $LF !
			}
			else
			{
				#	ok
			}
		}

		debug ( sprintf "\t key = %#+04x", ord ( $key ) )		if $DEBUG;

		debug "C1\tk=$key\ts=$sub_key"		if $DEBUG;

		if ( $sub_key )
		{
			debug "\tsub_key added"		if $DEBUG;

			$sub_key .= $key;
			redo	unless length $sub_key == 3;
		}

		if ( $key eq $ESCAPE )
		{
			debug "\tkey is ESCAPE"		if $DEBUG;

			$sub_key = $key;
			redo;
		}

		if ( $key lt "\x20" )
		{
			debug "\tkey is CONTROL"		if $DEBUG;

			redo	if ( $key ne $BREAK ) and ( $key ne $BACKSPACE ) and ( $key ne $DELETE ) and ( $key ne $CR );
		}

		if ( length $sub_key == 3 )
		{
			if ( $sub_key eq $ARROW_UP )
			{
				debug "\tsub_key is ARROW_UP"		if $DEBUG;

				return $UP;
			}
			elsif ( $sub_key eq $ARROW_DOWN )
			{
				debug "\tsub_key is ARROW_DOWN"		if $DEBUG;

				return $DOWN;
			}
			elsif ( $sub_key eq $ARROW_LEFT )
			{
				debug "\tsub_key is ARROW_LEFT"		if $DEBUG;

				print OUT $sub_key;		#	echo
				return $LEFT;
			}
			elsif ( $sub_key eq $ARROW_RIGHT )
			{
				debug "\tsub_key is ARROW_RIGHT"		if $DEBUG;

				print OUT $sub_key;		#	echo
				return $RIGHT;
			}
			else
			{
				#
				#	ignore
				#
				debug "\tsub_key is ignored..."		if $DEBUG;

				print OUT $BELL;
				$sub_key = '';
				redo;
			}
		}
	}

	if ( $OSNAME =~ /Win32/i )
	{
		if ( $self->{_batch_mode} )
		{
			print OUT $key;

			if ( $key eq $CR )
			{
				print OUT $LF;
			}
		}
	}
	else
	{
		print OUT $key;		#	echo
	}

	debug "C2\tk=$key\ts=$sub_key"		if $DEBUG;

	return $key;
}

=pod

=item * getInput ( ) I<PRIVATE>

=cut

sub getInput
{
	my $self		= shift;
	my $prompt	= shift()	|| 'INPUT > ';

	print OUT $prompt;

	$self->{term_pos} = 0;

	my $text 	= undef;
	my @chars	= ();
	my $key		= undef;

	while ( defined ( $key = $self->getChar() ) )
	{
		last		if $key eq $CR;

		if ( $key eq $BREAK )
		{
			return undef;
		}

		debug "I1\tk=$key\tp=$self->{term_pos}"		if $DEBUG;

		if ( ( $key eq $UP ) or ( $key eq $DOWN ) )
		{
			debug "INPUT is UP or DOWN"		if $DEBUG;

			if ( @INPUT_STACK )
			{
				$INPUT_STACK_POS--	if $key eq $UP;
				$INPUT_STACK_POS++	if $key eq $DOWN;

				$INPUT_STACK_POS = $INPUT_STACK_POS < 0					? $#INPUT_STACK	: $INPUT_STACK_POS;
				$INPUT_STACK_POS = $INPUT_STACK_POS > $#INPUT_STACK	? 0					: $INPUT_STACK_POS;

				if ( my $line = $INPUT_STACK[$INPUT_STACK_POS] )
				{
					my $control = ( $OSNAME =~ /Win32/i ) ? $WIN_ARROW_LEFT : $ARROW_LEFT;

					for ( 1 .. $self->{term_pos} - 1 )
					{
						print OUT $control, ' ', $control;
					}

					print OUT $line;

					@chars = split //, $line;

					$self->{term_pos} = @chars + 1;
				}
			}

			debug "\t\tp=$self->{term_pos}\t@chars"		if $DEBUG;

			next;
		}

		if ( ( $key eq $LEFT ) or ( $key eq $BACKSPACE ) )
		{
			debug "INPUT is LEFT or BACKSPACE"		if $DEBUG;

			$self->{term_pos}--;

			if ( $self->{term_pos} < 0 )
			{
				$self->{term_pos} = 0;

				my $control = ( $OSNAME =~ /Win32/i ) ? $WIN_ARROW_RIGHT : $ARROW_RIGHT;

				print OUT $BELL, $control;

				next;
			}

			next	if $key eq $LEFT;
		}

		if ( $key eq $RIGHT )
		{
			debug "INPUT is RIGHT"		if $DEBUG;

			$self->{term_pos}++;

			if ( $self->{term_pos} > scalar @chars )
			{
				$self->{term_pos}--;

				my $control = ( $OSNAME =~ /Win32/i ) ? $WIN_ARROW_LEFT : $ARROW_LEFT;

				print OUT $BELL, $control;

				next;
			}

			next;
		}

		if ( $key eq $BACKSPACE )
		{
			debug "INPUT is BACKSPACE"		if $DEBUG;

			debug "B4\t@chars"		if $DEBUG;

			my $old_len = scalar @chars;

			removeArray ( \@chars, $self->{term_pos} );

			debug "AF\t@chars"		if $DEBUG;

			my $cnt = 0;

			for ( my $i = $self->{term_pos}; $i < $old_len; $i++ )
			{
				print OUT $chars[$i] || ' ';
				$cnt++;
			}

			print OUT ' ';	#	delete last char
			$cnt++;

			my $control = ( $OSNAME =~ /Win32/i ) ? $WIN_ARROW_LEFT : $ARROW_LEFT;

			print OUT $control x $cnt;

			next;
		}

		debug "INSERT..."		if $DEBUG;

		debug "B4\t@chars"		if $DEBUG;

		insertArray ( \@chars, $self->{term_pos}, $key );

		debug "AF\t@chars"		if $DEBUG;

		$self->{term_pos}++;

		debug "I2\tk=$key\tp=$self->{term_pos}"		if $DEBUG;

		my $new_len = scalar @chars;

		my $cnt = 0;

		for ( my $i = $self->{term_pos}; $i < $new_len; $i++ )
		{
			print OUT $chars[$i] || ' ';
			$cnt++;
		}

		my $control = ( $OSNAME =~ /Win32/i ) ? $WIN_ARROW_LEFT : $ARROW_LEFT;

		print OUT $control x $cnt;
	}

	return ''			unless @chars;

	$text = join '', @chars;

	@CHARS_IN = @chars			if $DEBUG;

	return undef		if $text eq '/exit';

	push @INPUT_STACK, $text;

	return $text;
}

=pod

=item * run ( )

=cut

sub run
{
	my $self = shift;

	debug '>>>>>>>>>>>>>>>>>>>>>> ', __PACKAGE__, ' started'		if $DEBUG;

	print OUT $HELP_TEXT;

	my $input			= '';
	my $response		= '';
	my $user_prompt	= $self->{user_prompt};

	$response = $self->response ( AIML::Config::getConfig ( 'connect-string' ) );

	$self->print ( $response );

	unless ( $OSNAME =~ /Win32/i )
	{
		ReadMode 4, \*IN;		#	Turn off controls keys
	}

	debug "======================================================================="		if $DEBUG;

	while ( defined ( $input = $self->getInput ( $user_prompt ) ) )
	{
		debug Dumper ( \@CHARS_IN )			if $DEBUG;
		@CHARS_IN = map { ord } @CHARS_IN	if $DEBUG;
		debug Dumper ( \@CHARS_IN )			if $DEBUG;

		if ( $input eq '/help' )
		{
			print OUT $HELP_TEXT;
			next;
		}

		$response = $self->response ( $input );

		$self->print ( $response );

		debug "======================================================================="		if $DEBUG;
	}

	print OUT "\n\nThank you for running me.\nYou made a little program very happy.\n\n";

	debug '>>>>>>>>>>>>>>>>>>>>>> ', __PACKAGE__, ' stopped'		if $DEBUG;
}

END
{
	unless ( $OSNAME =~ /Win32/i )
	{
		ReadMode 0, \*IN;		#	Reset tty mode before exiting
	}
}

=pod

=item * response ( ) I<PRIVATE>

=cut

sub response
{
	my $self		= shift;
	my $input	= shift;

	$input = ''		unless defined $input;

	debug __PACKAGE__, "::response ( '$input' )"		if $DEBUG;

	my $bot_id	= $self->{bot_id};
	my $user_id	= $self->{user_id};

	my $bot			= AIML::Bot->new
							(
								user_id			=> $user_id,
								bot_id			=> $bot_id,
							);

	my $talker = $bot->getResponse
							(
								$input,

								$AIML_SERVICE_TEXT,			#	IN
								$AIML_ENCODING_LATIN,		#	IN

								$AIML_SERVICE_TEXT,			#	OUT
								$AIML_ENCODING_LATIN,		#	OUT
							);

	defined $talker	or die ( "Talker not defined" );

	$self->{response_time} = $bot->{response_time} || 0;

	$bot->save();		#	free lock on memory !!!

	return $talker->as_string();
}

=pod

=item * print ( ) I<PRIVATE>

=cut

sub print
{
	my $self		= shift;
	my $output	= shift;

	$output = ''		unless defined $output;

	my $time = $self->{response_time} || 0;

	CORE::print OUT ' ' x length ( $self->{bot_prompt} ),  '( Response in ', int ( $time * 1000 ),  " msec )\n";

	my @lines = split /\n/, $output;

	foreach my $line ( @lines )
	{
		CORE::print OUT $self->{bot_prompt}, $line, "\n";
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

L<AIML::Bot>.

=cut

1;

__END__
