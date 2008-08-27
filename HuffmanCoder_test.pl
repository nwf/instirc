use warnings;
use strict;
#use Data::Dumper;

# use Irssi::Scripts::Instance::Mastercode; ### XXX
require MasterCoder;
require HuffmanCoder;
use Definitions qw( @debug_code_chars $instance_huffman_table1 
                    $MESSAGE_START $MESSAGE_END );

my $mastercoder = MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $huffmancoder = HuffmanCoder->new($mastercoder, $instance_huffman_table1);

#print "Dumping encoding table:\n";
#$huffmancoder->dump_encode_table();

#print "Dumping decoding table:\n";
#$huffmancoder->dump_decode_table();

#print Dumper($huffmancoder);

my @test_strings = ( "hi", "there", "coin", "test", "!@#\$&*.-=" );

foreach my $ts (@test_strings) {
  my $enc = $huffmancoder->encode($ts);
  my $dec = $huffmancoder->decode($enc);

  print $ts, " ==> ", $enc, " ==> ", $dec, "\n";

  die if $dec ne $ts;
}
