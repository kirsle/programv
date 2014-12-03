#!/usr/bin/perl

BEGIN
{
	$| = 1;

	$AIML::Common::DEBUG = 1;
	$AIML::Parser::DEBUG = 1;

	use lib './lib';
}

use strict;
use warnings;

use Data::Dumper;

use AIML::Parser;

my ( $text, $p1, $p2, $p3, $fh, $output );

$text = 'This is <star/> and <pattern>BLA XXX</pattern> <bla><star index="3"/> and <topicstar/> <topicstar index="2"/> not bla</xxx> <topicstar index="3,2"/>.';

$p1 = new AIML::Parser;

#	$p1->parseRam ( $text );
#	$p1->parseTemplate ( $text );
#	print Dumper ( $p1 );
#	exit;

	$p1->parseFile ( 'aiml/standard/_test_.aiml' );
#	$p1->parseFile ( 'aiml/alice/Q.aiml' );
#	$p1->parseFile ( 'aiml/alice/5.aiml' );
#	$p1->parseFile ( 'aiml/alice/W.aiml' );
#	$p1->parseFile ( 'aiml/alice/T.aiml' );
#	$p1->parseFile ( 'aiml/alice/H.aiml' );
#	$p1->parseFile ( 'aiml/standard/dev-perl.aiml' );
#	$p1->parseFile ( 'conf/startup.xml' );
#	print Dumper ( $p1 );

print "\n\nWARNINGS\n", $p1->warningString()	|| "\tnone\n";
print "\n\nERRORS\n", $p1->errorString()		|| "\tnone\n";

print "\n\n";

1;

__END__


Total Elapsed Time = 56.05086 Seconds
         User Time = 46.85056 Seconds
Exclusive Times
%Time ExclSec CumulS #Calls sec/call Csec/c  Name
 43.9   20.60 47.201    141   0.1461 0.3348  AIML::Parser::parse_text
 40.1   18.81 18.813  13916   0.0014 0.0014  AIML::Parser::_test_copy
 3.31   1.550  2.041  27832   0.0001 0.0001  AIML::Common::convertString
 1.37   0.640  0.983  13466   0.0000 0.0001  AIML::Parser::tag_content
 1.28   0.600  3.421   7312   0.0001 0.0005  AIML::Parser::handle_start
 1.17   0.550  1.742   7129   0.0001 0.0002  AIML::Parser::handle_end
 1.15   0.540  0.710  13467   0.0000 0.0001  AIML::Parser::validate_content
 0.98   0.460  0.453  14110   0.0000 0.0000  AIML::Parser::handle_text
 0.98   0.460  0.543   7318   0.0001 0.0001  AIML::Parser::get_element_node_loop
 0.90   0.420  0.406  27412   0.0000 0.0000  Unicode::String::latin1
 0.68   0.320  0.378   7084   0.0000 0.0001  AIML::Parser::start_tag
 0.62   0.290  0.388   7084   0.0000 0.0001  AIML::Parser::end_tag
 0.60   0.280  1.396   7224   0.0000 0.0002  AIML::Parser::validate_tag
 0.58   0.270  0.249  41802   0.0000 0.0000  AIML::Parser::collect
 0.51   0.240  0.226  27846   0.0000 0.0000  AIML::Common::true


erde:/home/alice # dprofpp -u -p ./testparser.pl


Total Elapsed Time = 5.649750 Seconds
         User Time = 5.739785 Seconds
Exclusive Times
%Time ExclSec CumulS #Calls sec/call Csec/c  Name
 20.7   1.189  6.231  10616   0.0001 0.0006  AIML::Parser::parse_text
 20.2   1.160  1.483  27832   0.0000 0.0001  AIML::Common::convertString
 7.84   0.450  0.495   7318   0.0001 0.0001  AIML::Parser::get_element_node_loop
 7.14   0.410  0.865   7129   0.0001 0.0001  AIML::Parser::handle_end
 6.10   0.350  0.336  13970   0.0000 0.0000  AIML::Parser::handle_text
 5.75   0.330  0.350  13467   0.0000 0.0000  AIML::Parser::validate_content
 5.75   0.330  2.281   7312   0.0000 0.0003  AIML::Parser::handle_start
 5.58   0.320  0.293  27412   0.0000 0.0000  Unicode::String::latin1
 4.70   0.270  6.241      1   0.2695 6.2406  AIML::Parser::parselines
 4.36   0.250  0.296   7084   0.0000 0.0000  AIML::Parser::start_tag
 3.83   0.220  0.306  13466   0.0000 0.0000  AIML::Parser::tag_content
 3.14   0.180  1.182   7224   0.0000 0.0002  AIML::Parser::validate_tag
 3.14   0.180  0.186   7084   0.0000 0.0000  AIML::Parser::end_tag
 2.79   0.160  0.146  13916   0.0000 0.0000  AIML::Parser::_test_copy
 2.79   0.160  0.168   7224   0.0000 0.0000  AIML::Parser::validate_attr
erde:/home/alice #
