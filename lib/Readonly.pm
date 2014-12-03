# Package for defining constants of various types

use 5.005;
use strict;
package Readonly;
$Readonly::VERSION = 0.07;    # Also change in the documentation!

# Autocroak (Thanks, MJD)
# Only load Carp.pm if module is croaking.
sub croak
{
    require Carp;
    goto &Carp::croak;
}


# ----------------
# Read-only scalars
# ----------------
package Readonly::Scalar;

sub TIESCALAR
{
    my $class = shift;
    Readonly::croak "No value specified for readonly scalar"        unless @_;
    Readonly::croak "Too many values specified for readonly scalar" unless @_ == 1;

    my $value = shift;
    return bless \$value, $class;
}

sub FETCH
{
    my $self = shift;
    return $$self;
}

*STORE = *UNTIE =
    sub {Readonly::croak "Attempt to modify a readonly scalar"};


# ----------------
# Read-only arrays
# ----------------
package Readonly::Array;

sub TIEARRAY
{
    my $class = shift;
    my @self = @_;

    return bless \@self, $class;
}

sub FETCH
{
    my $self  = shift;
    my $index = shift;
    return $self->[$index];
}

sub FETCHSIZE
{
    my $self = shift;
    return scalar @$self;
}

BEGIN {
    eval q{
        sub EXISTS
           {
           my $self  = shift;
           my $index = shift;
           return exists $self->[$index];
           }
    } if $] >= 5.006;    # couldn't do "exists" on arrays before then
}

*STORE = *STORESIZE = *EXTEND = *PUSH = *POP = *UNSHIFT = *SHIFT = *SPLICE = *CLEAR = *UNTIE =
    sub {Readonly::croak "Attempt to modify a readonly array"};


# ----------------
# Read-only hashes
# ----------------
package Readonly::Hash;

sub TIEHASH
{
    my $class = shift;

    # must have an even number of values
    Readonly::croak "May not store an odd number of values in a hash" unless (@_ %2 == 0);

    my %self = @_;
    return bless \%self, $class;
}

sub FETCH
{
    my $self = shift;
    my $key  = shift;

    return $self->{$key};
}

sub EXISTS
{
    my $self = shift;
    my $key  = shift;
    return exists $self->{$key};
}

sub FIRSTKEY
{
    my $self = shift;
    my $dummy = keys %$self;
    return scalar each %$self;
}

sub NEXTKEY
{
    my $self = shift;
    return scalar each %$self;
}

*STORE = *DELETE = *CLEAR = *UNTIE =
    sub {Readonly::croak "Attempt to modify a readonly hash"};


# ----------------------------------------------------------------
# Main package, containing convenience functions (so callers won't
# have to explicitly tie the variables themselves).
# ----------------------------------------------------------------
package Readonly;
use Exporter;
use vars qw/@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
push @ISA, 'Exporter';
push @EXPORT, qw/Readonly/;
push @EXPORT_OK, qw/Scalar Array Hash Scalar1 Array1 Hash1/;

# Predeclare the following, so we can use them recursively
sub Scalar ($$);
sub Array (\@;@);
sub Hash (\%;@);


# Shallow Readonly scalar
sub Scalar1 ($$)
{
    return tie $_[0], 'Readonly::Scalar', $_[1];
}

# Shallow Readonly array
sub Array1 (\@;@)
{
    my $aref = shift;
    return tie @$aref, 'Readonly::Array', @_;
}

# Shallow Readonly hash
sub Hash1 (\%;@)
{
    my $href = shift;

    # If only one value, and it's a hashref, expand it
    if (@_ == 1  &&  ref $_[0] eq 'HASH')
    {
        return tie %$href, 'Readonly::Hash', %{$_[0]};
    }

    # otherwise, must have an even number of values
    croak "May not store an odd number of values in a hash" unless (@_%2 == 0);

    return tie %$href, 'Readonly::Hash', @_;
}

# Deep Readonly scalar
sub Scalar ($$)
{
    my $value = $_[1];

    # Recursively check passed element for references; if any, make them Readonly
    foreach ($value)
    {
        if    (ref eq 'SCALAR') {Scalar my $v => $$_; $_ = \$v}
        elsif (ref eq 'ARRAY')  {Array  my @v => @$_; $_ = \@v}
        elsif (ref eq 'HASH')   {Hash   my %v => $_;  $_ = \%v}
    }

    return tie $_[0], 'Readonly::Scalar', $value;
}

# Deep Readonly array
sub Array (\@;@)
{
    my $aref = shift;
    my @values = @_;

    # Recursively check passed elements for references; if any, make them Readonly
    foreach (@values)
    {
        if    (ref eq 'SCALAR') {Scalar my $v => $$_; $_ = \$v}
        elsif (ref eq 'ARRAY')  {Array  my @v => @$_; $_ = \@v}
        elsif (ref eq 'HASH')   {Hash   my %v => $_;  $_ = \%v}
    }
    # Lastly, tie the passed reference
    return tie @$aref, 'Readonly::Array', @values;
}

# Deep Readonly hash
sub Hash (\%;@)
{
    my $href = shift;
    my @values = @_;

    # If only one value, and it's a hashref, expand it
    if (@_ == 1  &&  ref $_[0] eq 'HASH')
    {
        @values = %{$_[0]};
    }

    # otherwise, must have an even number of values
    croak "May not store an odd number of values in a hash" unless (@values %2 == 0);

    # Recursively check passed elements for references; if any, make them Readonly
    foreach (@values)
    {
        if    (ref eq 'SCALAR') {Scalar my $v => $$_; $_ = \$v}
        elsif (ref eq 'ARRAY')  {Array  my @v => @$_; $_ = \@v}
        elsif (ref eq 'HASH')   {Hash   my %v => $_;  $_ = \%v}
    }

    return tie %$href, 'Readonly::Hash', @values;
}


# Common entry-point for all supported data types
sub Readonly
{
    if (ref $_[0] eq 'SCALAR')
    {
        croak "Readonly scalar must have only one value" if @_ > 2;
        return tie ${$_[0]}, 'Readonly::Scalar', $_[1];
    }
    elsif (ref $_[0] eq 'ARRAY')
    {
        my $aref = shift;
        return Array @$aref, @_;
    }
    elsif (ref $_[0] eq 'HASH')
    {
        my $href = shift;
        if (@_%2 != 0  &&  !(@_ == 1  && ref $_[0] eq 'HASH'))
        {
            croak "May not store an odd number of values in a hash";
        }
        return Hash %$href, @_;
    }
    elsif (ref $_[0])
    {
        croak "Readonly only supports scalar, array, and hash variables.";
    }
    else
    {
        croak "First argument to Readonly must be a reference.";
    }
}


1;
__END__

=head1 NAME

Readonly - Facility for creating read-only scalars, arrays, hashes.

=head1 VERSION

This documentation describes version 0.07 of Readonly.pm, June 25, 2002.

=head1 SYNOPSIS

 use Readonly;

 # Read-only scalar
 Readonly::Scalar     $sca => $initial_value;
 Readonly::Scalar  my $sca => $initial_value;

 # Read-only array
 Readonly::Array      @arr => @values;
 Readonly::Array   my @arr => @values;

 # Read-only hash
 Readonly::Hash       %has => (key => value, key => value, ...);
 Readonly::Hash    my %has => (key => value, key => value, ...);
 # or:
 Readonly::Hash       %has => {key => value, key => value, ...};

 # You can use the read-only variables like any regular variables:
 print $sca;
 $something = $sca + $arr[2];
 next if $has{$some_key};

 # But if you try to modify a value, your program will die:
 $sca = 7;            # "Attempt to modify readonly scalar"
 push @arr, 'seven';  # "Attempt to modify readonly array"
 delete $has{key};    # "Attempt to modify readonly hash"

 # Alternate form:
 Readonly    \$sca => $initial_value;
 Readonly \my $sca => $initial_value;
 Readonly    \@arr => @values;
 Readonly \my @arr => @values;
 Readonly    \%has => (key => value, key => value, ...);
 Readonly \my %has => (key => value, key => value, ...);


=head1 DESCRIPTION

This is a facility for creating non-modifiable variables.  This is
useful for configuration files, headers, etc.  It can also be useful
as a development and debugging tool, for catching updates to variables
that should not be changed.

If any of the values you pass to C<Scalar>, C<Array>, or C<Hash> are
references, then those functions recurse over the data structures,
marking everything as Readonly.  Usually, this is what you want: the
entire structure nonmodifiable.  If you want only the top level to be
Readonly, use the alternate C<Scalar1>, C<Array1> and C<Hash1>
functions.


=head1 COMPARISON WITH "use constant" OR TYPEGLOB CONSTANTS

=over 1

=item *

Perl provides a facility for creating constant scalars, via the "use
constant" pragma.  That built-in pragma creates only scalars and
lists; it creates variables that have no leading $ character and which
cannot be interpolated into strings.  It works only at compile
time. You cannot take references to these constants.  Also, it's
rather difficult to make and use deep structures (complex data
structures) with "use constant".

=item *

Another popular way to create read-only scalars is to modify the symbol
table entry for the variable by using a typeglob:

 *a = \'value';

This works fine, but it only works for global variables ("my"
variables have no symbol table entry).  Also, the following similar
constructs do B<not> work:

 *a = [1, 2, 3];      # Does NOT create a read-only array
 *a = { a => 'A'};    # Does NOT create a read-only hash

=item *

Readonly.pm, on the other hand, will work with global variables and
with lexical ("my") variables.  It will create scalars, arrays, or
hashes, all of which look and work like normal, read-write Perl
variables.  You can use them in scalar context, in list context; you
can take references to them, pass them to functions, anything.

Readonly.pm also works well with complex data structures, allowing you
to tag the whole structure as nonmodifiable, or just the top level.

However, Readonly.pm does impose a performance penalty.  This is
probably not an issue for most configuration variables.  But benchmark
your program if it might be.  If it turns out to be a problem, you may
still want to use Readonly.pm during development, to catch changes to
variables that should not be changed, and then remove it for
production:

 # For testing:
 Readonly::Scalar  $Foo_Directory => '/usr/local/foo';
 Readonly::Scalar  $Bar_Directory => '/usr/local/bar';
 # $Foo_Directory = '/usr/local/foo';
 # $Bar_Directory = '/usr/local/bar';

 # For production:
 # Readonly::Scalar  $Foo_Directory => '/usr/local/foo';
 # Readonly::Scalar  $Bar_Directory => '/usr/local/bar';
 $Foo_Directory = '/usr/local/foo';
 $Bar_Directory = '/usr/local/bar';

=back 1


=head1 FUNCTIONS

=over 4

=item Readonly::Scalar $var => $value;

Creates a nonmodifiable scalar, C<$var>, and assigns a value of
C<$value> to it.  Thereafter, its value may not be changed.  Any
attempt to modify the value will cause your program to die.

A value I<must> be supplied.  If you want the variable to have
C<undef> as its value, you must specify C<undef>.

If C<$value> is a reference to a scalar, array, or hash, then this
function will mark the scalar, array, or hash it points to as being
Readonly as well, and it will recursively traverse the structure,
marking the whole thing as Readonly.  Usually, this is what you want.
However, if you want only the C<$value> marked as Readonly, use
C<Scalar1>.

=item Readonly::Array @arr => (value, value, ...);

Creates a nonmodifiable array, C<@arr>, and assigns the specified list
of values to it.  Thereafter, none of its values may be changed; the
array may not be lengthened or shortened or spliced.  Any attempt to
do so will cause your program to die.

If any of the values passed is a reference to a scalar, array, or hash, then
this function will mark the scalar, array, or hash it points to as
being Readonly as well, and it will recursively traverse the
structure, marking the whole thing as Readonly.  Usually, this is what
you want.  However, if you want only the hash C<%@arr> itself marked as
Readonly, use C<Array1>.

=item Readonly::Hash %h => (key => value, key => value, ...);

=item Readonly::Hash %h => {key => value, key => value, ...};

Creates a nonmodifiable hash, C<%h>, and assigns the specified keys
and values to it.  Thereafter, its keys or values may not be changed.
Any attempt to do so will cause your program to die.

A list of keys and values may be specified (with parentheses in the
synopsis above), or a hash reference may be specified (curly braces in
the synopsis above).  If a list is specified, it must have an even
number of elements, or the function will die.

If any of the values is a reference to a scalar, array, or hash, then
this function will mark the scalar, array, or hash it points to as
being Readonly as well, and it will recursively traverse the
structure, marking the whole thing as Readonly.  Usually, this is what
you want.  However, if you want only the hash C<%h> itself marked as
Readonly, use C<Hash1>.

=item Readonly \$var => $value;

=item Readonly \@arr => (value, value, ...);

=item Readonly \%h => (key => value, ...);

=item Readonly \%h => {key => value, ...};

The C<Readonly> function is an alternate to the C<Scalar>, C<Array>,
and C<Hash> functions.  It has the advantage (if you consider it an
advantage) of being one function.  That may make your program look
neater, if you're initializing a whole bunch of constants at once.
You may or may not prefer this uniform style.  It has the disadvantage
of requiring a reference as its first parameter, so you have to supply
a backslash.  You may or may not consider this ugly.

=item Readonly::Scalar1 $var => $value;

=item Readonly::Array1 @arr => (value, value, ...);

=item Readonly::Hash1 %h => (key => value, key => value, ...);

=item Readonly::Hash1 %h => {key => value, key => value, ...};

These alternate functions create shallow Readonly variables, instead
of deep ones.  For example:

 Readonly::Array1 @shal => (1, 2, {perl=>'Rules', java=>'Bites'}, 4, 5);
 Readonly::Array  @deep => (1, 2, {perl=>'Rules', java=>'Bites'}, 4, 5);

 $shal[1] = 7;           # error
 $shal[2]{APL}='Weird';  # Allowed! since the hash isn't Readonly
 $deep[1] = 7;           # error
 $deep[2]{APL}='Weird';  # error, since the hash is Readonly


=back


=head1 EXAMPLES

 # SCALARS:

 # A plain old read-only value
 Readonly::Scalar $a => "A string value";

 # The value need not be a compile-time constant:
 Readonly::Scalar $a => $computed_value;


 # ARRAYS:

 # A read-only array:
 Readonly::Array @a => (1, 2, 3, 4);

 # The parentheses are optional:
 Readonly::Array @a => 1, 2, 3, 4;

 # You can use Perl's built-in array quoting syntax:
 Readonly::Array @a => qw/1 2 3 4/;

 # You can initialize a read-only array from a variable one:
 Readonly::Array @a => @computed_values;

 # A read-only array can be empty, too:
 Readonly::Array @a => ();
 Readonly::Array @a;        # equivalent


 # HASHES

 # Typical usage:
 Readonly::Hash %a => (key1 => 'value1', key2 => 'value2');

 # A read-only hash can be initialized from a variable one:
 Readonly::Hash %a => %computed_values;

 # A read-only hash can be empty:
 Readonly::Hash %a => ();
 Readonly::Hash %a;        # equivalent

 # If you pass an odd number of values, the program will die:
 Readonly::Hash %a => (key1 => 'value1', "value2");
     --> dies with "May not store an odd number of values in a hash"


=head1 EXPORTS

By default, this module exports the following symbol into the calling
program's namespace:

 Readonly

The following symbols are available for import into your program, if
you like:

 Scalar  Scalar1
 Array   Array1
 Hash    Hash1


=head1 REQUIREMENTS

 Perl 5.005
 Carp.pm (included with Perl)
 Exporter.pm (included with Perl)


=head1 ACKNOWLEDGEMENTS

Thanks to Slaven Rezic for the idea of one common function (Readonly)
for all three types of variables (13 April 2002).

Thanks to Ernest Lergon for the idea (and initial code) for
deeply-Readonly data structures (21 May 2002).


=head1 AUTHOR / COPYRIGHT

Eric J. Roode, eric@myxa.com

Copyright (c) 2001-2002 by Eric J. Roode. All Rights Reserved.  This module
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

If you have suggestions for improvement, please drop me a line.  If
you make improvements to this software, I ask that you please send me
a copy of your changes. Thanks.


=cut
