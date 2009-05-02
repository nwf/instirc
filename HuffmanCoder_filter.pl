use warnings;
use strict;
#use Data::Dumper;

require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Definitions qw( @debug_code_chars $instance_huffman_table1 
                    $MESSAGE_START $MESSAGE_END );

my $mastercoder = Instance::MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $huffmancoder = Instance::HuffmanCoder->new($mastercoder, $instance_huffman_table1);

while(my $in = <>) {
  chomp $in;
  my $enc = $huffmancoder->encode($in);
  # my $dec = $huffmancoder->decode($enc);
  print $in, " ==> ", $enc, " (", length $enc, ")\n" ; # " ==> ", $dec, "\n";
}
