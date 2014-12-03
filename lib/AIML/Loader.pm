=head1 NAME

AIML::Loader - validating AIML loader object class

=head1 SYNOPSIS

   use AIML::Config;
   use AIML::Loader;

   AIML::Config::LOAD_AIML_CONFIG ( '/home/alice/programv/server.properties' );

   $loader = new AIML::Loader;

   $startup_file   = AIML::Config::getConfigPath ( 'startup' );
   $knowledge_file = AIML::Config::getConfigPath ( 'runfile' );

   print "Processing $startup_file...\n";
   print "Creating knowledge base $knowledge_file...\n";

   $success = $loader->parseFile ( $file_name );

   if ( $success )
   {
      $loader->saveKnowledge ( $know_file_name );
   }

   print "\n\nWARNINGS\n", $parser->warningString() || "\tnone\n";
   print "\n\nERRORS\n",   $parser->errorString()   || "\tnone\n";

=head1 DESCRIPTION

This module creates an AIML knowledge base by reading and processing
the tags in a XML startup file. It is an OOPPS implementation of the
semantical rules for AIML (Artificial Intelligence Markup Language)
defined in L<http://alicebot.org/TR/2001/WD-aiml/>.

C<AIML::Loader> inherits from C<AIML::Parser>, which provides the
syntactical validation. The methods C<startTag>, C<endTag> and
C<tagContent> are overwritten to handle the AIML resp. STARTUP tags.

=cut

package AIML::Loader;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use utf8;

use File::Spec;
use File::Find;
use File::Basename;

use EnglishSave;

use AIML::Common 0.09;
use AIML::Unicode 0.09;
use AIML::File 0.09;
use AIML::Parser 0.09;

@ISA = qw ( AIML::Parser );

=head1 GLOBALS

   $AIML::Loader::DEBUG = 1;

Logs all parsing activities (huge output).

=head1 EXPORT

=head2 Public Attributes

None.

=head2 Public Constructors

C<new>

=head2 Public Methods

C<startTag>, C<endTag>, C<tagContent>

C<saveKnowledge>

=cut

=head1 CONSTRUCTOR

=over 4

=item * new ( )

Creates an C<AIML::Loader>.

=cut

sub new
{
	my $proto	= shift;
	my $class	= ref($proto) || $proto;

	my $self		= $class->SUPER::new();

	$self->{_cats_loaded}	= 0;
	$self->{_cat_count}		= 0;

	$self->{_current_cat}	= {};
	$self->{_current_topic} = '';

	return $self;
}

=pod

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

Methods marked as I<B<CALLBACK>> are automatically called from
L<C<AIML::Parser>|AIML::Parser>, do not call them from outside.

=head2 Callback Methods

The following methods overwrite those of L<C<AIML::Parser>|AIML::Parser>.

=over 4

=item * startTag ( \@context, $type, \%attr ) I<CALLBACK>

Puts the loader object in the necessary start conditions and
interprets startup tags - e.g.: Collecting E<lt>patternE<gt>,
E<lt>thatE<gt> or E<lt>templateE<gt>, including config files etc.

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
			#	startup elements
			#
			/^$AIML_STARTUP_MAGIC$/	&& do {
							$self->{_in_startup}	= true;

							$self->pushText();
							last SWITCH;
						};
			/^bots$/	&& do {
							$self->{bots}		= {};
							$self->{props}		= AIML::Config::getConfig();

							$self->pushText();
							last SWITCH;
						};
			/^bot$/	&& do {
							if ( $self->{_in_startup} )
							{
							#	my $id		= $attr->{id} || $self->{props}->{'emptydefault'};
								my $id		= $attr->{id} || die "INTERNAL ERROR: no bot id";
								my $enabled	= ( $attr->{enabled} =~ /^(true|yes|1)$/i );	#	becomes flag!

								if ( exists $self->{bots}->{$id} )
								{
									$self->putError ( "Bot '$id' already defined" );
									return;
								}

								$self->{bots}->{$id} = {};

								$self->{bots}->{$id}->{bot}->{id}		= $id;
								$self->{bots}->{$id}->{bot}->{enabled}	= $enabled;

								$self->{bots}->{$id}->{aiml}				= {};

								$self->{_current_bot}	= $id;

								$self->pushIgnore ( $type )		unless $enabled;			#	do not load!

								$self->{bot}		= $self->{bots}->{$id};						#	see below !!!
								$self->{uniques}	= {};

								$self->pushText();
								last SWITCH;
							}
							else
							{
								die "NEVER COME HERE WITH '$type'";
							}
						};
			/^properties$/	&& do {
							$self->pushText();
							last SWITCH;
						};
			/^property$/	&& do {
							my $id		= $self->{_current_bot};

							my $name		= $attr->{name};
							my $value	= $attr->{value};

							$self->{bots}->{$id}->{properties}->{$name}	= $value;

							$self->pushIgnore ( $type );
							last SWITCH;
						};
			/^listeners$/	&& do {
							$self->pushIgnore ( $type );

							last SWITCH;
						};
			/^listener$/	&& do {
							die "'$type' NOT IMPLEMENTED YET...";

							$self->pushText();
							last SWITCH;
						};
			/^parameter$/	&& do {
							die "'$type' NOT IMPLEMENTED YET...";

							$self->pushText();
							last SWITCH;
						};
			/^(predicates|substitutions|sentence-splitters)$/	&& do {
							$self->pushText();

							if ( $attr->{href} )
							{
								if ( not $self->loadInclude ( $attr->{href} ) )
								{
									$self->putError ( "Include aborted" );
									return;
								}
							}

							last SWITCH;
						};
			/^predicate$/	&& do {
							my $id		= $self->{_current_bot};

							my $name			= $attr->{name};
							my $default		= $attr->{default};
							my $set_return	= $attr->{'set-return'};

							$self->{bots}->{$id}->{predicates}->{$name}	=
								{ default => $default, 'set-return' => $set_return };

							$self->pushIgnore ( $type );

							last SWITCH;
						};
			/^(input|gender|person|person2)$/	&& do {
							if ( $self->{_in_startup} )
							{
								$self->pushText();

								last SWITCH;
							}
							else
							{
								die "NEVER COME HERE WITH '$type'";
							}
						};
			/^substitute$/	&& do {
							my $parent = $context->[-1] || 'undef';

							CASE:
							{
								for ( $parent )
								{
									/^input$/	&& do { last CASE; };
									/^gender$/	&& do { last CASE; };
									/^person$/	&& do { last CASE; };
									/^person2$/	&& do { last CASE; };
									die "WRONG PARENT '$parent' FOR '$type'";
								}
							}

							my $id		= $self->{_current_bot};

							my $find		= $attr->{find};
							my $replace	= $attr->{replace};

							$self->{bots}->{$id}->{substitutes}->{$parent}->{$find}	= $replace;

							$self->pushIgnore ( $type );

							last SWITCH;
						};
			/^splitter$/	&& do {
							my $id		= $self->{_current_bot};

							my $value	= $attr->{value};

							$self->{bots}->{$id}->{'sentence-splitters'}->{$value}	= 1;

							$self->pushIgnore ( $type );

							last SWITCH;
						};
			/^learn$/	&& do {
							if ( $self->{_in_startup} )
							{
								$self->pushText();
							}
							else
							{
								$self->pushIgnore ( $type );
								$self->pushText();
							}

							last SWITCH;
						};
			#
			#	zero-level elements
			#
			/^meta$/	&& do {
							$self->pushIgnore ( $type );

							last SWITCH;
						};
			/^aiml$/	&& do {
							$self->{_in_startup}	= false;

							$self->pushText();
							last SWITCH;
						};
			#
			#	top-level elements
			#
			/^topic$/	&& do {
							my $name	= $attr->{name};

							$self->{_current_topic} = $name;

							$self->pushText();
							last SWITCH;
						};
			/^category$/	&& do {
							$self->{_cat_count}++;

							$self->{_current_cat} = {};

							$self->{_current_cat}->{topic} = $self->{_current_topic} || '*';

							$self->pushText();
							last SWITCH;
						};
			#
			#	top-level / atomic elements
			#
			/^perl$/	&& do {
							if ( $self->collect )
							{
								die "NEVER COME HERE WITH '$type'";
							}
							else
							{
								$self->pushText();
								last SWITCH;
							}
						};
			#
			#	second-level
			#
			/^pattern$/	&& do {
							$self->pushCollect ( $type );

							$self->pushText();
							last SWITCH;
						};
			/^template$/	&& do {
							$self->pushCollect ( $type );

							$self->pushText();
							last SWITCH;
						};
			#
			#	second-level / atomic
			#
			/^that$/	&& do {
							if ( $self->collect )
							{
								die "NEVER COME HERE WITH '$type'";
							}
							else
							{
								$self->pushCollect ( $type );

								$self->pushText();
								last SWITCH;
							}
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

Stores a collected E<lt>categoryE<gt>, evaluates E<lt>perlE<gt> snippets etc.

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
			#	startup elements
			#
			/^$AIML_STARTUP_MAGIC$/	&& do {
							$self->{_in_startup}	= false;

							$self->popText();
							last SWITCH;
						};
			/^(bots|properties|listeners|predicates|substitutions|sentence-splitters)$/	&& do {
							#
							#	EOT
							#
							$self->popText();
							last SWITCH;
						};
			/^(listener|parameter)$/	&& do {
							#
							#	EOT
							#
							$self->popText();
							last SWITCH;
						};
			/^bot$/	&& do {
							if ( $self->{_in_startup} )
							{
								#
								#	EOT
								#
								$self->popText();
								last SWITCH;
							}
							else
							{
								die "NEVER COME HERE WITH '$type'";
							}
						};
			/^(input|gender|person|person2)$/	&& do {
							if ( $self->{_in_startup} )
							{
								#
								#	EOT
								#
								$self->popText();
								last SWITCH;
							}
							else
							{
								die "NEVER COME HERE WITH '$type'";
							}
						};
			/^learn$/	&& do {
							#
							#	EOT
							#
							$self->popText();
							last SWITCH;
						};
			#
			#	zero-level elements
			#
			/^aiml$/	&& do {
							#
							#	EOF
							#
							$self->{_in_startup}	= true;

							$self->popText();
							last SWITCH;
						};
			#
			#	top-level elements
			#
			/^topic$/	&& do {
							$self->{_current_topic} = '';
							$self->popText();
							last SWITCH;
						};
			/^category$/	&& do {
							#
							#	EOC
							#
							$self->popText();

							my $cat		= $self->{_current_cat};
							my $bot		= $self->{bot};
							my $brain	= $bot->{aiml};

						#	$brain->{templates}	= [ $self->{props}->{'emptydefault'} ]		unless defined $brain->{templates};
							$brain->{templates}	= [ 'ZERO TEMPLATE' ]							unless defined $brain->{templates};
							$brain->{matches}		= {}	unless $brain->{matches};

							#
							#	0 but defined...
							#
							$cat->{pattern}	= defined $cat->{pattern}	? ( length $cat->{pattern}		? $cat->{pattern}		: '*'	) : '*'	;
							$cat->{that}		= defined $cat->{that}		? ( length $cat->{that}			? $cat->{that}			: '*'	) : '*'	;
							$cat->{topic}		= defined $cat->{topic}		? ( length $cat->{topic}		? $cat->{topic}		: '*'	) : '*'	;
							$cat->{template}	= defined $cat->{template}	? ( length $cat->{template}	? $cat->{template}	: ''	) : ''	;

							#
							#	replace pattern-side <bot>
							#
							foreach my $key ( qw ( pattern that topic ) )
							{
								1	while ( $cat->{$key} =~ s/<\/bot>//g );

								while ( $cat->{$key} =~ $AIML::Parser::PattSideBotElemRegex )
								{
								#	my $param = $bot->{properties}->{$1} || $self->{props}->{'emptydefault'};
									my $param = $bot->{properties}->{$1} || die "INTERNAL ERROR: no bot property $1";

									$cat->{$key} =~ s/$AIML::Parser::PattSideBotElemRegex/$param/;
								}
							}

							#
							#	make match path
							#
							flatString ( \$cat->{pattern}		);
							flatString ( \$cat->{that}			);
							flatString ( \$cat->{topic}		);
						#
						#	as is !!!
						#
						#	flatString ( \$cat->{template}	);

							$cat->{pattern}	= uppercase ( $cat->{pattern}	);
							$cat->{that}		= uppercase ( $cat->{that}		);
							$cat->{topic}		= uppercase ( $cat->{topic}	);

							my $match_path =
									$cat->{pattern}	. ' <that> ' .
									$cat->{that}		. ' <topic> ' .
									$cat->{topic};

							$cat->{match_path} = $match_path;

							debug ( "processing $type: path='$match_path'" )	if $DEBUG;

							#
							#	test duplicate pattern
							#
							my $duplicate_pattern = '';

							$self->{uniques}->{$match_path}++;

							if ( $self->{uniques}->{$match_path} > 1 )
							{
								$duplicate_pattern = "Duplicate pattern found: '$match_path'";
							}

							#
							#	ignore
							#
							if		( $duplicate_pattern and not $self->{props}->{'merge'} )
							{
								$self->putWarning ( $duplicate_pattern, ' - ignored' );

								$self->{_cat_count}--;
							}
							#
							#	or replace
							#
							elsif	( $duplicate_pattern and $self->{props}->{'merge'} )
							{
								$self->putWarning ( $duplicate_pattern, ' - merged' );

								my ( $first, $rest ) = split / /, $match_path, 2;

								if ( not exists $brain->{matches}->{$first} )
								{
									die "INTERNAL ERROR: '$first' -> '$rest' must exist!";
								}

								my $tempPos = scalar @ { $brain->{templates} };

								my $pattPos = matchArray ( $rest, $brain->{matches}->{$first} );

								if ( $pattPos < 0 )
								{
									die "INTERNAL ERROR: '$first' -> '$rest' not found in\n", Dumper ( $brain->{matches}->{$first} );
								}
								else
								{
									$brain->{matches}->{$first}->[$pattPos] = "$rest <pos> $tempPos";
								}

								push @ { $brain->{templates} }, $cat->{template};
							}
							#
							#	or add
							#
							else
							{
								my ( $first, $rest ) = split / /, $match_path, 2;

								if ( not exists $brain->{matches}->{$first} )
								{
									$brain->{matches}->{$first} = [];
								}

								my $tempPos	= scalar @ { $brain->{templates} };

								push @ { $brain->{matches}->{$first} }, "$rest <pos> $tempPos";

								push @ { $brain->{templates} }, $cat->{template};
							}

							last SWITCH;
						};
			#
			#	top-level / atomic elements
			#
			/^perl$/	&& do {
							if ( $self->collect )
							{
								die "NEVER COME HERE WITH '$type'";
							}
							else
							{
							#	if ( $self->{bot}->{perl} )
							#	{
							#		$self->putError ( "Perl package already defined" );
							#		return;
							#	}

								$self->{bot}->{perl} = ''	unless $self->{bot}->{perl};

								my $snippet = $self->{_current_text} || '';
								$self->{_current_text} = '';

								my $pkg	= perlClassName ( $self->{_current_bot} );

								$snippet = "package $pkg;\n" . $snippet;

								eval ( $snippet );	#	test it!

								if ( $EVAL_ERROR )
								{
									my @lines = split /\n/, $snippet;
									my $i = 0;
									map { $i++; $_ = "$i\:\t" . $_ . "\n"; } @lines;

									$snippet = "@lines";

									$self->putError ( "Eval error: $EVAL_ERROR in code snippet:\n", $snippet );
									return;
								}
								else
								{
									$self->{bot}->{perl} .= "\n# Global module part from " . $self->filename() . "\n";
									$self->{bot}->{perl} .= $snippet;
								}

								$self->popText();

								last SWITCH;
							}
						};
			#
			#	second-level
			#
			/^pattern$/	&& do {
							$self->{_current_cat}->{pattern}		= $self->{_current_text};
							$self->popText();
							last SWITCH;
						};
			/^template$/	&& do {
							$self->{_current_cat}->{template}	= $self->{_current_text};
							$self->popText();
							last SWITCH;
						};
			#
			#	second-level / atomic
			#
			/^that$/	&& do {
							if ( $self->collect )
							{
								die "NEVER COME HERE WITH '$type'";
							}
							else
							{
								$self->{_current_cat}->{that}			= $self->{_current_text};
								$self->popText();
								last SWITCH;
							}
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

Collects the content of all tags and loads AIML files for the tag
E<lt>learnE<gt>.

=cut

sub tagContent
{
	my $self		= shift;
	my $context	= shift;
	my $content	= shift;

	return		if $self->errors();

	SWITCH:
	{
		local $_;

		my $parent = $context->[-1] || 'undef';

		for ( $parent )
		{
			/^learn$/	&& do {
							if ( not $self->loadAiml ( $content ) )
							{
								$self->putError ( "Loading aborted" );
							}

							last SWITCH;
						};
			#
			#	default
			#
			$self->{_current_text} .= $content;
		}
	}
}

=pod

=back

=head2 Other Methods

=over 4

=item * loadInclude I<PRIVATE>

=cut

sub loadInclude
{
	my $self			= shift;
	my $file_name	= shift;

	my ( $conf_path, $file_path );

	( undef, $conf_path, undef )	= File::Spec->splitpath ( $self->filename() );		#	from parser...
	$file_path							= File::Spec->rel2abs ( $file_name, $conf_path );

	$self->parseInclude ( $file_path );

	return not $self->errors();
}

=pod

=item * loadAiml I<PRIVATE>

=cut

sub loadAiml
{
	my $self			= shift;
	my $file_path	= shift;

	my ( $conf_path );

	( undef, $conf_path, undef )	= File::Spec->splitpath ( $self->filename() );		#	from parser...
	$file_path							= File::Spec->rel2abs ( $file_path, $conf_path );

	my @files	= ();
	my $pattern	= '';

	if ( $file_path =~ /\*/ )
	{
		my ( $path, $suffix );

		( $pattern, $path, $suffix ) = fileparse ( $file_path );

		$pattern =~ s/\./\\./g;
		$pattern =~ s/\*/\.\*/g;

		find
		(
			sub
			{
				my $fullname = $File::Find::name;
				my ( $file_name, $file_path, $filesuffix ) = fileparse ( $fullname );

				return 1		unless $file_name =~ /\.aiml$/;

				return 1		unless -f $fullname;

				push @files, $fullname	if $file_name =~ /$pattern/;

				return 1;
			},
			$path
		);
	}
	else
	{
		push @files, $file_path;
	}

	debug ( "$file_path -> $pattern :\n", Dumper ( \@files ) )	if $DEBUG;

	$self->putError ( "No AIML files found for $file_path" )		unless scalar @files;

	foreach my $file_name ( sort @files )
	{
		$self->{_cat_count}		= 0;

		print "Processing $file_name...\n";

		last		unless $self->parseFile ( $file_name );

		$self->{_cats_loaded} += $self->{_cat_count};

		print "...$self->{_cat_count} cats loaded, $self->{_cats_loaded} cats so far.\n";

#		local $Data::Dumper::Indent = 1;
#		print Dumper ( $self );
#		last;
	}

	print "$self->{_cats_loaded} cats loaded.\n";

	return not $self->errors();
}

=pod

=item * saveKnowledge ( $filename )

Dumps the collected AIML knowledge base to $filename.

=cut

sub saveKnowledge
{
	my $self			= shift;
	my $file_path	= shift;

	my $root	= $self->{bots} || {};

	my $fh	= new AIML::File;

	$fh->open ( ">$file_path" )		or die "Can't open $file_path\: $OS_ERROR";

	local $Data::Dumper::Indent = 1;

	$fh->putline ( Dumper ( $root ) );

	$fh->close();
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

L<AIML::Parser>.

=cut

1;

__END__
