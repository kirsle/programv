=head1 NAME

AIML::Unicode - Functions for UTF8 String Case Changing

=head1 SYNOPSIS

   $upper    = uppercase ( 'uppercase' );            # returns 'UPPERCASE'
   $lower    = lowercase ( 'lOwErCaSe' );            # returns 'lowercase'
   $formal   = formal    ( 'proper name' );          # returns 'Proper Name'
   $sentence = sentence  ( 'this is a sentence' );   # returns 'This is a sentence'

=head1 DESCRIPTION

This module provides functions to change the case of UTF8 strings.

=cut

package AIML::Unicode;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $VERSION $DEBUG %CONSTANTS );

	$VERSION	= $VERSION	= 0.09;

	$DEBUG	= 0	unless $DEBUG;
}

use utf8;
use charnames ':full';

use Unicode::String		();
use Unicode::CharName	();
use Unicode::Map8			();

use EnglishSave;

=head1 GLOBALS

   $AIML::Unicode::DEBUG = 1;

No debugging functionality provided yet.

=head1 EXPORT

=head2 Public Functions

C<uppercase>, C<lowercase>, C<formal>, C<sentence>

=cut

sub import
{
	no strict qw ( refs );

	my $callerpkg = caller(0);

	#	export functions
	#
	*{"$callerpkg\::uppercase"}			= *uppercase;
	*{"$callerpkg\::lowercase"}			= *lowercase;
	*{"$callerpkg\::formal"}				= *formal;
	*{"$callerpkg\::sentence"}				= *sentence;

	1;
}

#
#	PRIVATE VARS
#
my ( $TO_UPPER, $TO_LOWER, $TO_TITLE, $TO_DIGIT );

$TO_UPPER	= _load_case ( 'unicore/To/Upper.pl' );
$TO_LOWER	= _load_case ( 'unicore/To/Lower.pl' );
$TO_TITLE	= _load_case ( 'unicore/To/Title.pl' );

#	MEMO: 	unicode/To/Digit.pl

=head1 FUNCTIONS

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * _load_case ( $package ) I<PRIVATE>

This function loads the necessary case change tables at compile time.

=cut

sub _load_case
{
	my $pkg = shift;

	my $changer = do ( $pkg ) or die;

	my @lines = split /\n/, $changer;

	$changer = {};

	foreach my $line ( @lines )
	{
		my ( $key, $border, $value )	= split /\t/, $line;

		$key		||= 0;
		$border	||= 0;
		$value	||= 0;

		$key		= hex $key;
		$border	= hex $border;
		$value	= hex $value;

		if ( $border )
		{
#			printf "$pkg\tk=0x%04x\tb=0x%04x\tv=0x%04x\n",
#				$key, $border, $value;

			my $offset = $key - $value;

			foreach my $key2 ( $key .. $border )
			{
#				printf "\tborder\tk=0x%04x\to=0x%04x\tv=0x%04x\n",
#					$key2, $offset, $key2 - $offset;

				$changer->{$key2} = $key2 - $offset;
			}
		}
		else
		{
#			printf "$pkg\tk=0x%04x\tb=0x%04x\tv=0x%04x\n",
#				$key, $border, $value;
#
#			printf "\t\t\t\tk=0x%04x\to=0x%04x\tv=0x%04x\n",
#				$key, 0, $value;

			$changer->{$key} = $value;
		}
	}

#	use Data::Dumper;
#	print "\n$pkg\n", Dumper ( $changer ), "\n";

	return $changer;
}

=pod

=item * uppercase ( $string )

Returns a case changed string.

'uppercase'	becomes	'UPPERCASE'

See L<http://alicebot.org/TR/2001/WD-aiml/#section-uppercase>.

=cut

sub uppercase
{
	return _change_case ( shift(), $TO_UPPER );
}

=pod

=item * lowercase ( $string )

Returns a case changed string.

'lOwErCaSe'	becomes	'lowercase'

See L<http://alicebot.org/TR/2001/WD-aiml/#section-lowercase>.

=cut

sub lowercase
{
	return _change_case ( shift(), $TO_LOWER );
}

=pod

=item * _change_case ( $string ) I<PRIVATE>

The secret worker.

=cut

sub _change_case
{
	my $str_in	= shift;
	my $changer	= shift() || {};

	return ''		unless defined $str_in;

	my $str_out = '';

	my $str_obj = Unicode::String::utf8 ( $str_in );

	my @char_list = $str_obj->unpack;

	my ( $char_in, $char_out );

	foreach $char_in ( @char_list )
	{
		if ( $char_out = $changer->{$char_in} )
		{
			$str_out .= Unicode::String::uchr ( $char_out );

#			printf "found\t0x%04x\t0x%04x\t'%s'\n", $char_in, $char_out, $str_out;
		}
		else
		{
			$str_out .= Unicode::String::uchr ( $char_in );

#			printf "as is\t0x%04x\t0x%04x\t'%s'\n", $char_in, 0, $str_out;
		}
	}

	return "$str_out";	#	!!!
}

=pod

=item * formal ( $string )

Returns a case changed string.

'proper name'	becomes	'Proper Name'

See L<http://alicebot.org/TR/2001/WD-aiml/#section-formal>.

=cut

sub formal
{
	my $str_in	= shift;

	return ''		unless defined $str_in;

	my @words = split / /, $str_in;

	foreach my $word ( @words )
	{
		my $u = Unicode::String::utf8 ( $word );

		my $first	= $u->substr ( 0, 1 );
		my $rest		= $u->substr ( 1 );

		$first	= ''		unless defined $first;
		$rest		= ''		unless defined $rest;

		$word = _change_case ( "$first", $TO_TITLE ) . _change_case ( "$rest", $TO_LOWER );	#	!!!
	}

	return join ( ' ', @words );
}

=pod

=item * sentence ( $string )

Returns a case changed string.

'this is a sentence'	becomes	'This is a sentence'

'dies ist ein Satz'	becomes	'Dies ist ein Satz' (!)

See L<http://alicebot.org/TR/2001/WD-aiml/#section-sentence>.

=cut

sub sentence
{
	my $str_in	= shift;

	return ''		unless defined $str_in;

	my $u = Unicode::String::utf8 ( $str_in );

	my $first	= $u->substr ( 0, 1 );
	my $rest		= $u->substr ( 1 );

	$first	= ''		unless defined $first;
	$rest		= ''		unless defined $rest;

	return _change_case ( "$first", $TO_UPPER ) . "$rest";	#	!!!
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

L<AIML::Parser>, L<AIML::Loader>, L<AIML::Responder> and L<AIML::Graphmaster>.

=cut

1;

__END__
