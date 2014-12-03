=head1 NAME

AIML::File - class for lockable file objects

=head1 SYNOPSIS

   use AIML::File;

   # text file object

   $fh = new AIML::File;
   if ( $fh->open ( "< template.html" ) )   # locks file
   {
      $text = $fh->slurp();                 # reads whole file

      $fh->close;                           # unlocks file
   }

   # counter file object

   $fh = new AIML::File;
   if ( $fh->open ( "+< counter.data" ) )   # locks file
   {
      chomp ( $counter = $fh->getline );

      $counter++;

      $fh->putline ( $counter );            # truncates file
                                            # and writes one line

      $fh->close;                           # unlocks file
   }

   # log file object

   $fh = new AIML::File ( ">> log.data" );  # opens and locks file
   if ( not defined $fh )
   {
      die "Can't open log.data for update";
   }

   ... routine part 1 ....

   $fh->addline ( 'routine 1 completed' );  # adds one line to the end of file

   ... routine part 2 ....

   $fh->addline ( 'routine 2 completed' );  # adds another line to the end of file

   ... etc ...

   $fh->close;                              # unlocks file

   # exported functions

   if ( not fileExists ( 'old.file' )       # check existence
   {
      die "old.file doesn't exist";
   }

   if ( not fileExists ( 'new.file', 1 )    # auto-create file
   {
      die "Can't create new.file";
   }

   if ( not pathExists ( '/home/alice/data' )
   {
      die "Directory /home/alice/data does not exist";
   }


=head1 DESCRIPTION

This class provides two useful functions and an object oriented
interface to lockable filehandles.

C<AIML::File> inherits from C<IO::File>. The methods C<open> and
C<close> are overwritten to handle locking.

See L<AIML::Common> for the locking functions used here.

Special care has been taken for files created on Windows to be read on
Linux.

=cut

package AIML::File;

use strict;
use warnings;

BEGIN
{
	use vars qw ( $DEBUG $VERSION @ISA );

	$VERSION = $VERSION = 0.09;

	$DEBUG = 0	unless $DEBUG;
}

use IO::File();
use EnglishSave;
use AIML::Common;

@ISA = qw ( IO::File );

my $CR		= "\x0D";				#	^J
my $LF		= "\x0A";				#	^M
my $CRLF		= $CR . $LF;

=head1 GLOBALS

   $AIML::File::DEBUG = 1;

No debugging functionality provided yet.

=head1 EXPORT

=head2 Public Functions

C<fileExists>, C<pathExists>

=head2 Public Constructors

C<new>

=head2 Public Methods

C<open>, C<close>

C<slurp>, C<getline>, C<getlines>, C<putline>, C<addline>

=cut

sub import
{
	no strict qw ( refs );

	my $callerpkg = caller(0);

	#	export functions
	#
	*{"$callerpkg\::fileExists"}	= *fileExists;
	*{"$callerpkg\::pathExists"}	= *pathExists;
}

=head1 FUNCTIONS

Do not overwrite and call functions marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * fileExists ( $file_name [, $create_flag ] )

Checks the existence of $file_name.

If $create_flag is L<C<true>|AIML::Common/item_true>, tries to create $file_name if it doesn't
exist.

Returns	L<C<true>|AIML::Common/item_true>	on success
	L<C<false>|AIML::Common/item_false>	otherwise

=cut


sub fileExists
{
	my $file_name		= shift;
	my $create_flag	= shift;

	return true		if -f $file_name;		#	is file

	return false	unless $create_flag;

	my $oFile = new AIML::File ();
	$oFile->open ( ">$file_name" );
	$oFile->close();

	return fileExists ( $file_name );
}

=pod

=item * pathExists ( $file_path )

Checks the existence of $file_path.

Returns	L<C<true>|AIML::Common/item_true>	on success
	L<C<false>|AIML::Common/item_false>	otherwise

=cut

sub pathExists
{
	my $file_path		= shift;

	return true		if -d $file_path;		#	is directory

	return false;
}

=pod

=back

=head1 CONSTRUCTOR

=over 4

=item * new ( [ $file_name [, $mode [, $perms ] ] ] ) INHERITED

Creates an C<AIML::File>.  If it receives any parameters, they are passed to
the method C<open>; if the open fails, the object is destroyed.  Otherwise,
it is returned to the caller.

=back

=head1 METHODS

Do not overwrite and call methods marked as I<B<PRIVATE>> from outside.

=over 4

=cut

=pod

=item * open ( $file_name [, $mode [, $perms ] ] )

C<open> accepts one, two or three parameters.  With one parameter,
it is just a front end for the built-in C<open> function.  With two or three
parameters, the first parameter is a filename that may include
whitespace or other special characters, and the second parameter is
the open mode, optionally followed by a file permission value.

If C<open> receives a Perl mode string ("E<gt>", "+E<lt>", etc.)
or a ANSI C fopen() mode string ("w", "r+", etc.), it uses the basic
Perl C<open> operator (but protects any special characters).

If C<open> is given a numeric mode, it passes that mode
and the optional permissions value to the Perl C<sysopen> operator.
The permissions default to 0666.

Returns	L<C<true>|AIML::Common/item_true>	on success
	L<C<false>|AIML::Common/item_false>	if L<C<IO::File::open>|IO::File/item_open> fails
	L<C<false>|AIML::Common/item_false>	if L<C<AIML::Common::lock>|AIML::Common/item_lock> fails

=cut

sub open
{
	my $self = shift;

	umask 0111;	#	rw-rw-rw- !!!!!!!!!

	$self->SUPER::open ( @_ )	or return false;

	lock ( $self )					or return false;

	$self->seek ( 0, IO::File::SEEK_SET );
	$self->autoflush ( 1 );

	return true;
}

=pod

=item * close ( )

Unlocks and closes the C<AIML::File>.

Returns	L<C<true>|AIML::Common/item_true>	on success
	L<C<false>|AIML::Common/item_false>	if L<C<AIML::Common::unlock>|AIML::Common/item_unlock> fails
	L<C<false>|AIML::Common/item_false>	if L<C<IO::File::close>|IO::File/item_close> fails

=cut

sub close
{
	my $self = shift;

	unlock ( $self )				or return false;

	$self->SUPER::close ( @_ )	or return false;

	return true;
}

=pod

=item * slurp ( )

Returns a string containing the whole file with platform specific record separators.

=cut

sub slurp
{
	my $self = shift;

	$self->seek ( 0, IO::File::SEEK_SET );

	local $INPUT_RECORD_SEPARATOR;			#	slurp

	my $text = <$self>;

	$text =~ s/$CRLF/\n/sg;

	return $text;
}

=pod

=item * getline ( )

Returns one line of C<AIML::File> with platform specific record separator.

=cut

sub getline
{
	my $self = shift;

	my $line = $self->SUPER::getline();

	return undef	unless defined $line;

	$line =~ s/$CRLF/\n/sg;

	return $line;
}

=pod

=item * getlines ( )

Returns all lines of C<AIML::File> with platform specific record separators.

=cut

sub getlines
{
	my $self = shift;

	my @lines = $self->SUPER::getlines();

	return ()	unless @lines;

	map { s/$CRLF/\n/sg } @lines;

	return @lines;
}

=pod

=item * putline ( $line | @lines )

Truncates the C<AIML::File> and writes one or more lines to it.

=cut

sub putline
{
	my $self = shift;

	$self->truncate ( 0 );
	$self->seek ( 0, IO::File::SEEK_SET );
	$self->print ( @_, "\n" );
}

=pod

=item * addline ( $line | @lines )

Writes one or more lines to the end of C<AIML::File>.

=cut

sub addline
{
	my $self = shift;

	$self->seek ( 0, IO::File::SEEK_END );
	$self->print ( @_, "\n" );
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

L<AIML::Common>, L<IO::File>, L<IO::Handle>, L<IO::Seekable>.

=cut

1;

__END__
