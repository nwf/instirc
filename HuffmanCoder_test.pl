use warnings;
use strict;
#use Data::Dumper;

require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Definitions qw( @debug_code_chars $instance_huffman_table1 
                    $MESSAGE_START $MESSAGE_END );

my $mastercoder = Instance::MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $huffmancoder = Instance::HuffmanCoder->new($mastercoder, $instance_huffman_table1);

#print "Dumping encoding table:\n";
#$huffmancoder->dump_encode_table();

#print "Dumping decoding table:\n";
#$huffmancoder->dump_decode_table();

#print Dumper($huffmancoder);

my @test_strings = ( "abcdefghijklmnopqrstuvwxyz"
                   , "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                   , "1234567890!@#\$%^&*()"
                   , ",<.>/?;:'\"[]{}=+-_`~\\|"
                   );

foreach my $ts (@test_strings) {
  my $enc = $huffmancoder->encode($ts);
  my $dec = $huffmancoder->decode($enc);

  print $ts, " ==> ", $enc, " ==> ", $dec, "\n";

  die if $dec ne $ts;
}
