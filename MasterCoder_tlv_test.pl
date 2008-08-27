use warnings;
use strict;

use Definitions qw( %known_types
                    @debug_code_chars
                    $instance_huffman_table1
                    $MESSAGE_START $MESSAGE_END );
require MasterCoder;
require HuffmanCoder;
use Protoutils qw( dump_message );

my $mc = MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $hc = HuffmanCoder->new($mc, $instance_huffman_table1);

my @test_strings = ( "hi", "there", "coin", "test", "!@#\$&*.-=" );
my @tlvs = ();

foreach my $ts (@test_strings) {
  my $enc = $hc->encode($ts);
  my $tlv = $mc->tlv_wrap( $known_types{'InstanceLabelHuffman1'}, $enc);

  push @tlvs, $tlv;

  print "ENCODED '", $ts, "' into hc ", $enc, " and tlv ", $tlv, "\n";
}

my $mesg_suffix = "OOOOOh, This is some normal text, designed to be confusing.";
my $mesg = $mc->tlvs_to_message(\@tlvs) . $mesg_suffix;

print "Full encoded message is '$mesg'\n";
dump_message($mc, $mesg);

my $i = 0;
sub ilf_cb ($$) {
    my ($t,$v) = @_;

    die unless $t = $known_types{'InstanceLabelHuffman1'};

    my $dcv = $hc->decode($v);
    print "Decoded message: $dcv\n";

    die unless $test_strings[$i++] eq $dcv;
}

sub def_cb ($$) {
    my ($t,$v) = @_;
    die "Unanticipated message of type $t: $v";
}

my ($res, $rest) = $mc->tlv_run_callbacks(
              { 'default' => \&def_cb,
                $known_types{'InstanceLabelHuffman1'} => \&ilf_cb,
              },
              $mesg );

#print $mesg_suffix,"\n",$rest,"\n";

die unless $res eq 1;
die unless $rest eq $mesg_suffix;
