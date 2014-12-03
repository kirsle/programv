=head1 NAME

AIML::Common - constants and functions for global use

=head1 SYNOPSIS

   use AIML::Common;

   $AIML::Common::DEBUG = 1;   # die on warnings

Please see below for L<exported|export> constants and functions.

=head1 DESCRIPTION

This module provides constants and functions for all AIML modules.

You must have Perl 5.6.0 or better installed due to Unicode support!

=cut

package AIML::Common;

use strict;
use warnings;

BEGIN
{
	use 5.6.0;

	use vars qw ( $VERSION $DEBUG );

	$VERSION	= $VERSION	= 0.09;

	$DEBUG	= 0	unless $DEBUG;

	#
	#	No locking on Windoze !!!
	#
	eval
	{
		require Fcntl;
		Fcntl->import ( ':flock' );
	};
	my $err1 = $@ || '';

	# Modern Perl has this.....
	my $err2 = undef; #not exists &flock;

	if ( $err1 or $err2 )
	{
		*CORE::GLOBAL::flock		= sub { 1 };

		*AIML::Common::LOCK_SH	= sub { 1 };
		*AIML::Common::LOCK_EX	= sub { 2 };
		*AIML::Common::LOCK_NB	= sub { 4 };
		*AIML::Common::LOCK_UN	= sub { 8 };
	}
}

#
#	PRIVATE VARS
#
my %CONSTANTS =
(
	#	change in doc too !

	AIML_LOCK_DELAY		=> 2,							#	sec

	AIML_LOG_FILE			=> './aiml.log',

	AIML_VERSION			=> 1.01,
	AIML_NAMESPACE			=> "http\:\/\/alicebot.org\/2001\/AIML",

	AIML_PROGRAM_MAGIC	=> 'programv',
	AIML_STARTUP_MAGIC	=> 'programv-startup',

	AIML_PERL_CLASS		=> 'AIML::Perl',

	AIML_MAX_SRAI			=> 128,

	AIML_ENCODING_UTF8	=> 'UTF-8',
	AIML_ENCODING_LATIN	=> 'ISO-8859-1',
	AIML_ENCODING_UTF16	=> 'UTF-16',
	AIML_ENCODING_ASCII	=> 'US-ASCII',

	AIML_SERVICE_AIML		=> 1000,
	AIML_SERVICE_TEXT		=> 1001,
	AIML_SERVICE_HTML		=> 1002,
	AIML_SERVICE_VOICE	=> 1003,
);

my $LOG_FH = undef;

#
#	LIBS
#
use Data::Dumper;
use IO::File;

use Unicode::String ();

#	see BEGIN
#
#	use Fcntl qw ( :flock );

use Carp ();

use EnglishSave;

use AIML::Unicode;

$SIG{__DIE__}	= \&die_hard;
$SIG{__WARN__}	= \&die_slow;


=head1 GLOBALS

   $AIML::Common::DEBUG = 1;   # die on warnings

This will cause the program to die on warnings using Carp::confess,
otherwise the warning will be reported with Carp::cluck. See C<die_hard>.

=head1 EXPORT

=head2 Public Constants

   $AIML_LOCK_DELAY      = 2             # sec
   $AIML_LOG_FILE        = './aiml.log'
   $AIML_VERSION         = 1.01
   $AIML_NAMESPACE       = "http\:\/\/alicebot.org\/2001\/AIML"
   $AIML_PROGRAM_MAGIC   = 'programv'
   $AIML_STARTUP_MAGIC   = 'programv-startup'
   $AIML_PERL_CLASS      = 'AIML::Perl'
   $AIML_MAX_SRAI        = 128
   $AIML_ENCODING_UTF8   = 'UTF-8'
   $AIML_ENCODING_LATIN  = 'ISO-8859-1'
   $AIML_ENCODING_UTF16  = 'UTF-16'
   $AIML_ENCODING_ASCII  = 'US-ASCII'
   $AIML_SERVICE_AIML    = 1000
   $AIML_SERVICE_TEXT    = 1001
   $AIML_SERVICE_HTML    = 1002
   $AIML_SERVICE_VOICE   = 1003

=head2 Public Functions

C<true>, C<false>

C<lock>, C<unlock>

C<debug>, C<error>, C<warning>, C<logging>

C<perlClassName>

C<convertString>, C<sentenceSplit>, C<applySubstitutions>, C<patternFit>, C<patternFitNoWildcards>, C<removeMarkup>

C<flatString>, C<trimString>, C<ltrimString>, C<rtrimString>

C<matchArray>, C<insertArray>, C<removeArray>, C<inArray>, C<equalArray>

C<maxNum>, C<minNum>

=cut

sub import
{
	no strict qw ( refs );

	my $callerpkg = caller(0);

	#	export constants
	#
	foreach my $key ( keys %CONSTANTS )
	{
		*{"$callerpkg\::$key"}		= \$CONSTANTS{$key};
	}

	#	export functions
	#
	*{"$callerpkg\::Dumper"}	= *Data::Dumper::Dumper;

	*{"$callerpkg\::true"}		= *true;
	*{"$callerpkg\::false"}		= *false;

	*{"$callerpkg\::lock"}		= *lock;
	*{"$callerpkg\::unlock"}	= *unlock;

	*{"$callerpkg\::debug"}				= *debug;
	*{"$callerpkg\::error"}				= *error;
	*{"$callerpkg\::warning"}			= *warning;
	*{"$callerpkg\::logging"}			= *logging;

	*{"$callerpkg\::perlClassName"}			= *perlClassName;

	*{"$callerpkg\::convertString"}			= *convertString;

	*{"$callerpkg\::sentenceSplit"}			= *sentenceSplit;
	*{"$callerpkg\::applySubstitutions"}	= *applySubstitutions;
	*{"$callerpkg\::patternFit"}				= *patternFit;
	*{"$callerpkg\::patternFitNoWildcards"}	= *patternFitNoWildcards;
	*{"$callerpkg\::removeMarkup"}			= *removeMarkup;

	*{"$callerpkg\::flatString"}		= *flatString;
	*{"$callerpkg\::trimString"}		= *trimString;
	*{"$callerpkg\::ltrimString"}		= *ltrimString;
	*{"$callerpkg\::rtrimString"}		= *rtrimString;

	*{"$callerpkg\::matchArray"}	= *matchArray;
	*{"$callerpkg\::insertArray"}	= *insertArray;
	*{"$callerpkg\::removeArray"}	= *removeArray;
	*{"$callerpkg\::inArray"}		= *inArray;
	*{"$callerpkg\::equalArray"}	= *equalArray;

	*{"$callerpkg\::maxNum"}	= *maxNum;
	*{"$callerpkg\::minNum"}	= *minNum;

	1;
}

=head1 FUNCTIONS

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * die_hard ( @message ) I<PRIVATE>

This function is called on a C<__DIE__> signal.

=item * die_slow ( @message ) I<PRIVATE>

This function is called on a C<__WARN__> signal
and will really die, if L<$AIML::Common::DEBUG|globals> is true.

=cut

sub die_hard
{
	CORE::die @_	if $EXCEPTIONS_BEING_CAUGHT;		#	from eval...

	Carp::confess ( @_ );

	CORE::die "die_hard: NEVER COME HERE";
}

sub die_slow
{
	CORE::die @_	if $EXCEPTIONS_BEING_CAUGHT;		#	from eval...

	if ( $DEBUG )
	{
		Carp::confess ( @_ );		#	die on warnings

		CORE::die "die_slow: NEVER COME HERE";
	}
	else
	{
		Carp::cluck ( @_ );			#	backtrace warnings
	}
}

=pod

=item * true ( )

Returns 1.

=item * false ( )

Returns 0.

=cut

sub true		{ 1; }
sub false	{ 0; }

=pod

=item * lock ( $filehandle )

Locks a filehandle. Waits for L<$AIML_LOCK_DELAY|export> sec to get the lock.

Returns	C<true>	on success
	C<true>	I<without locking> on all systems not providing C<flock> - e.g.: Win95 / 98 / ME
	C<false>	otherwise

=item * unlock ( $filehandle )

Unlocks a filehandle.

=cut

sub lock
{
	my $fh = shift;

	my $flag		= ( LOCK_EX() | LOCK_NB() );
	my $delay	= int ( $CONSTANTS{AIML_LOCK_DELAY} * 10 );
	my $tenth	= 0;

	for ( ; ; )
	{
		my $lockresult = flock ( $fh, $flag );

		if ( ! $lockresult )
		{
			select ( undef, undef, undef, 0.1 );	#	Wait for 1/10 sec.
		}
		else
		{
			last;												#	We have got the lock.
		}

		$tenth++;

		if ( $tenth >= $delay )							#	Time out!
		{
			$OS_ERROR = 37;								#	No locks...
			return false;
		}
	}

	return true;
}

sub unlock	{ flock ( shift(), LOCK_UN() ) }

=pod

=item * _log ( $mark, $bot_id, $user_id, @array_of_strings ) I<PRIVATE>

Prints the array of strings with a time-stamp to the logfile.

Defaults are	$mark	'log'
	$bot_id	'?'
	$user_id	'0'

In a ModPerl evironment the logfile is C<STDERR>, otherwise it is
L<$AIML_LOG_FILE|export>. The logfile is automagically opened and closed.

=cut

sub _log
{
	my $mark		= shift;
	my $bot_id	= shift;
	my $user_id	= shift;

	my $time_stamp	= '[' . localtime() . '] ';

	$time_stamp		.= $mark		? '[' . $mark		. '] '	: '[-] ';
	$time_stamp		.= $bot_id	? '[' . $bot_id	. '] '	: '[?] ';
	$time_stamp		.= $user_id	? '[' . $user_id	. '] '	: '[0] ';

	my $log_file_name		= $CONSTANTS{AIML_LOG_FILE};
	my $fh					= undef;

	if ( $ENV{MOD_PERL} )
	{
		$fh = *STDERR;
	}
	else
	{
		unless ( defined $LOG_FH )
		{
			$LOG_FH = new IO::File;
			$LOG_FH->open ( ">$log_file_name" )		or die "Can't create $log_file_name\: $OS_ERROR";
#			$LOG_FH->open ( ">>$log_file_name" )	or die "Can't append $log_file_name\: $OS_ERROR";
		}

		$fh = $LOG_FH;

		my	$old_fh = select ( $fh );
		$| = 1;
		select ( $old_fh );

		$fh->seek ( 0, IO::File::SEEK_END );
	}

	$fh->autoflush ( 1 );

	$fh->print ( $time_stamp, @_, "\n" );
}

END
{
	$LOG_FH->close()		if defined $LOG_FH and $LOG_FH->opened();
}

=pod

=item * debug ( @array_of_strings )

Prints the array of strings with a [debug] mark to the logfile using C<logging>.

=item * error ( @array_of_strings )

Prints the array of strings with a [error] mark to the logfile using C<logging>.

=item * warning ( @array_of_strings )

Prints the array of strings with a [warn] mark to the logfile using C<logging>.

=cut

sub debug
{
	my $callerpkg = caller(0);


	logging ( 'debug', undef, undef, @_ );
}

sub error
{
	logging ( 'error', undef, undef, @_ );
}

sub warning
{
	logging ( 'warn', undef, undef, @_ );
}

=pod

=item * logging ( $mark, $bot_id, $user_id, @array_of_strings )

Prints the parameter list to the logfile using C<_log>.

Default for $mark is 'log'.

=cut

sub logging
{
	my $mark		= shift() || 'log';
	my $bot_id	= shift;
	my $user_id	= shift;

	_log ( $mark, $bot_id, $user_id, @_ );
}

=pod

=item * perlClassName ( [$bot_id] )

This function creates a class name for the AIML tag E<lt>perlE<gt>:

 $classname = perlClassName ( 'TestBot-1' ); # returns 'AIML::Perl::TestBot_1'
 $classname = perlClassName ();              # returns 'AIML::Perl::Default'

Use the second form, if you are sure to have defined only ONE bot in your config files.

=cut

sub perlClassName
{
	my $bot_id = shift() || 'Default';

	$bot_id =~ s/[^A-Za-z0-9]/\_/g;		#	make a Perl name

	return "$CONSTANTS{AIML_PERL_CLASS}::$bot_id";
}

=pod

=item * convertString ( $string, [$encoding_in [, $encoding_out]] )

Converts all characters in $string from $encoding_in to $encoding_out.

Possible encodings are

L<$AIML_ENCODING_UTF8|export>	1-4 byte characters (Perl internal)
L<$AIML_ENCODING_LATIN|export>	ISO 8859-1 character set (aka Latin1)
L<$AIML_ENCODING_UTF16|export>	2 byte character set + surrogates
L<$AIML_ENCODING_ASCII|export>	US-ASCII (7 bit) character set

$encoding_in	defaults to L<$AIML_ENCODING_LATIN|export>.
$encoding_out	defaults to L<$AIML_ENCODING_UTF8|export>.

Returns new encoded $string.

=cut

sub convertString
{
	my $sIn	= shift;
	my $cIn	= shift() || $CONSTANTS{AIML_ENCODING_LATIN};
	my $cOut	= shift() || $CONSTANTS{AIML_ENCODING_UTF8};

	return ''	unless defined $sIn;

	my $utf7		= $CONSTANTS{AIML_ENCODING_ASCII};
	my $latin1	= $CONSTANTS{AIML_ENCODING_LATIN};
	my $utf8		= $CONSTANTS{AIML_ENCODING_UTF8};
	my $utf16	= $CONSTANTS{AIML_ENCODING_UTF16};

	my $oOut		= undef;
	my $sOut		= '';

	CASE_IN:
	{
		local $_;

		for ( $cIn )
		{
			/^$utf7$/	&& do {
									$oOut = Unicode::String::utf7		( $sIn );
									last CASE_IN;
								};
			/^$latin1$/	&& do {
									$oOut = Unicode::String::latin1	( $sIn );
									last CASE_IN;
								};
			/^$utf8$/	&& do {
									$oOut = Unicode::String::utf8		( $sIn );
									last CASE_IN;
								};
			/^$utf16$/	&& do {
									$oOut = Unicode::String::utf16	( $sIn );
									last CASE_IN;
								};
			#	default
			die ( "unknown source encoding: $cIn" );
		}
	}

	CASE_OUT:
	{
		local $_;

		for ( $cOut )
		{
			/^$utf7$/	&& do {
									return $oOut->utf7	();
								};
			/^$latin1$/	&& do {
									return $oOut->latin1	();
								};
			/^$utf8$/	&& do {
									return $oOut->utf8	();
								};
			/^$utf16$/	&& do {
									return $oOut->utf16	();
								};
			#	default
			die ( "unknown target encoding: $cOut" );
		}
	}
}

=pod

=item * sentenceSplit ( \@splitters, $string )

This function splits $string in single sentences using each entry of @splitters.
See L<http://alicebot.org/TR/2001/WD-aiml/#section-sentence-splitting-normalizations>

Calls C<trimString>.

Returns \@array_of_strings.

=cut

sub sentenceSplit
{
	my $sentenceSplitters	= shift() || [];
	my $input					= shift;

	$input = ''		unless defined $input;

	my @old_sent	= ( $input );
	my @new_sent	= ();

	my $inputLength = length $input;

	if ( $inputLength == 0 )
	{
		push @new_sent, '';
		return \@new_sent;
	}

	foreach my $splitter ( @$sentenceSplitters )
	{
		foreach my $line ( @old_sent )
		{
			push @new_sent, split ( $splitter, $line );
		}

		@old_sent = @new_sent;
		@new_sent = ();
	}

	map { trimString ( \$_ ) } @old_sent;

	foreach my $line ( @old_sent )
	{
		push @new_sent, $line	if $line;
	}

	return \@new_sent;
}

=pod

=item * _substitute ( $string, \@subst_keys, \%subst ) I<PRIVATE>

Recursive function called by C<applySubstitutions>.

=cut

sub _substitute
{
	my $string	= shift;
	my $keys		= shift() || [];
	my $map		= shift() || {};

	$string = ''		unless defined $string;

	return $string		unless length $string;

	$string = ' ' . $string . ' ';

	my $touched	= '';

	foreach my $key ( @$keys )
	{
		my $entry = $map->{$key};

		next	unless defined $entry;

		if ( $string =~ /^(.*?)($key)(.*?)$/i )
		{
			my $first	= $1 || '';
			my $old		= $2 || '';
			my $new		= $entry;
			my $rest		= $3 || '';

			$first	=~ s/^ //;
			$rest		=~ s/ $//;

			$touched  =
				_substitute ( $first, $keys, $map ) .
				$new .
				_substitute ( $rest, $keys, $map );
		}

		last	if $touched;
	}

	$string	=~ s/^ //;
	$string	=~ s/ $//;

	$touched = $string	unless $touched;

	return $touched;
}

=pod

=item * applySubstitutions ( \%subst, $string )

This function takes a hash of substitions of the form
C<$subst-E<gt>{'find_expr'} = 'replace_expr'> and changes $string.
See L<http://alicebot.org/TR/2001/WD-aiml/#section-substitution-normalizations>

Calls C<flatString>.

Calls C<_substitute>.

Returns $string changed.

=cut

sub applySubstitutions
{
	my $substitutionMap	= shift() || {};
	my $string				= shift;

	$string = ''	unless defined $string;

	return $string		unless length $string;

	flatString ( \$string );

	my @substitutionList = reverse sort { length $a <=> length $b } keys %$substitutionMap;

	return $string		unless @substitutionList;

#	print "IN  '$string'\n";

	$string = _substitute ( $string, \@substitutionList, $substitutionMap );

	flatString ( \$string );

#	print "OUT  '$string'\n";

	return $string;
}

=pod

=item * patternFit ( \$string )

Calls C<removeMarkup>.

Replaces all non-normal characters and non-AIML wildcards with spaces.
See L<http://alicebot.org/TR/2001/WD-aiml/#section-normal-characters> and
L<http://alicebot.org/TR/2001/WD-aiml/#section-aiml-wildcards>.

Calls C<flatString>.

=cut

sub patternFit
{
	my $string = shift;

	removeMarkup ( $string );

	use utf8;

	$$string =~ s/[^\p{IsDigit}\p{IsLower}\p{IsUpper}\*\_]/ /g;

	no utf8;

	flatString ( $string );
}

=pod

=item * patternFitNoWildcards ( \$string )

Calls C<removeMarkup>.

Replaces all non-normal characters with spaces.
I<Removes AIML wildcards as well!>
See L<http://alicebot.org/TR/2001/WD-aiml/#section-normal-characters>.

Calls C<flatString>.

=cut

sub patternFitNoWildcards
{
	my $string = shift;

	removeMarkup ( $string );

	use utf8;

	$$string =~ s/[^\p{IsDigit}\p{IsLower}\p{IsUpper}]/ /g;

	no utf8;

	flatString ( $string );
}

=pod

=item * removeMarkup ( \$string )

Removes all E<lt>tagsE<gt>.

=cut

sub removeMarkup
{
	my $string = shift;

	$$string =~ s/<[^>]+>//sg;
}

=pod

=item * flatString ( \$string )

Replaces returns with newlines.

Replaces double newlines with single newlines.

Replaces newlines with spaces.

Calls C<trimString>.

=cut

sub flatString
{
	my $string = shift;

	1	while $$string	=~ s/\r/\n/sg;
	1	while $$string	=~ s/\n\n/\n/sg;
	1	while $$string	=~ s/\n/ /sg;

	trimString ( $string );
}

=pod

=item * trimString ( \$string )

Calls C<ltrimString>.

Calls C<rtrimString>.

Replaces tabs with spaces.

Replaces double spaces with a single space.

=cut

sub trimString
{
	my $string = shift;

	ltrimString ( $string );
	rtrimString ( $string );

	1	while $$string	=~ s/\t/ /sg;
	1	while $$string	=~ s/  / /sg;
}

=pod

=item * ltrimString ( \$string )

Removes leading spaces and tabs.

=cut

sub ltrimString
{
	my $string = shift;

	1	while $$string	=~ s/^ //m;
	1	while $$string	=~ s/^\t//m;
}

=pod

=item * rtrimString ( \$string )

Removes trailing spaces and tabs.

=cut

sub rtrimString
{
	my $string = shift;

	1	while $$string	=~ s/ $//m;
	1	while $$string	=~ s/\t$//m;
}

=pod

=item * matchArray ( $string, \@array_of_strings [, $case] )

Matches $string with the beginning of each item in @array_of_strings.
If $case is true, the match is case-sensitive.

Returns	position	of the match
	-1	otherwise

=cut

sub matchArray
{
	my $item		= shift;
	my $array	= shift;
	my $case		= shift;

	my $pos		= 0;

	$item =~ s/\\/\\\\/g;	#	1st !!
	$item =~ s/\)/\\)/g;
	$item =~ s/\(/\\(/g;
	$item =~ s/\{/\\{/g;
	$item =~ s/\}/\\}/g;
	$item =~ s/\[/\\[/g;
	$item =~ s/\]/\\]/g;
	$item =~ s/\./\\./g;
	$item =~ s/\?/\\?/g;
	$item =~ s/\+/\\+/g;
	$item =~ s/\-/\\-/g;
	$item =~ s/\*/\\*/g;
	$item =~ s/\_/\\_/g;
	$item =~ s/\;/\\;/g;
	$item =~ s/\:/\\:/g;

	my $regex	= $case ? qr/^$item/	: qr/^$item/i;

	foreach my $entry ( @$array )
	{
		return $pos		if $entry =~ $regex;

		$pos++;
	}

	return -1;
}

=pod

=item * insertArray ( \@array, $position, $item )

Adds $item at $position to @array starting at 0.

=cut

sub insertArray
{
	my $array	= shift;
	my $pos		= shift;
	my $add		= shift;

	splice ( @$array, $pos, 0, $add );
}

=pod

=item * removeArray ( \@array, $position )

Removes the item at $position from @array starting at 0.

=cut

sub removeArray
{
	my $array	= shift;
	my $pos		= shift;

	splice ( @$array, $pos, 1 );
}

=pod

=item * inArray ( $string, \@array_of_strings )

Returns	C<true>	if $string is an exact member of @array_of_strings
	C<false>	otherwise

=cut

sub inArray
{
	my $item		= shift;
	my $array	= shift;

	foreach my $entry ( @$array )
	{
		return true		if $item eq $entry;
	}

	return false;
}

=pod

=item * equalArray ( \@array1, \@array2 )

Returns	C<true>	if @array1 and @array2 have the same length and every string of @array1 is equal to every string of @array2
	C<false>	otherwise.

=cut

sub equalArray
{
	my $array1	= shift;
	my $array2	= shift;

	return false	unless @$array1 == @$array2;

	for ( my $i = 0; $i < @$array1; $i++ )
	{
		return false	unless $array1->[$i] eq $array2->[$i];
	}

	return true;
}

=pod

=item * maxNum ( $number1, $number2 )

Returns	$number1	if $number1 E<gt> $number2
	$number2	otherwise

=cut

sub maxNum
{
	my $a = shift;
	my $b = shift;

	return $a	if $a > $b;
	return $b	if $a <= $b;
}

=pod

=item * minNum ( $number1, $number2 )

Returns	$number1	if $number1 E<lt> $number2
	$number2	otherwise

=cut

sub minNum
{
	my $a = shift;
	my $b = shift;

	return $a	if $a < $b;
	return $b	if $a >= $b;
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

L<AIML::Unicode>.

=cut

1;

__END__
