use Instance::Definitions qw( %known_types
                    @debug_code_chars
                    $instance_huffman_table1
                    $MESSAGE_START $MESSAGE_END );
require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Protoutils qw( dump_message );

my $mc = Instance::MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $hc = Instance::HuffmanCoder->new($mc, $instance_huffman_table1);

while(my $text = <>) {
  chomp $text;

  my $enc = $hc->encode($text);
  my $tlv = $mc->tlv_wrap( $known_types{'InstanceLabelHuffman1'}, $enc);

  my @tlvs = ( );

  push @tlvs, $tlv;

  $enc = $mc->tencode(3);
  $tlv = $mc->tlv_wrap( $known_types{'MiscMessageFlags'}, $enc);

  push @tlvs, $tlv;

  my $mesg = $mc->tlvs_to_message(\@tlvs) . $mesg_suffix;

  print $text, ":", $mesg, "\n";
}
