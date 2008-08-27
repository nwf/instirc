use warnings;
use strict;

use Definitions qw( %known_types
                    @debug_code_chars
                    $instance_huffman_table1 );
require MasterCoder;
require HuffmanCoder;
use Protoutils qw( tlv_wrap tlvs_to_message dump_message run_callbacks );

my $mc = MasterCoder->new(\@debug_code_chars);
my $hc = HuffmanCoder->new($mc, $instance_huffman_table1);

my @test_strings = ( "hi", "there", "coin", "test", "!@#\$&*.-=" );
my @tlvs = ();

foreach my $ts (@test_strings) {
  my $enc = $hc->encode($ts);
  my $tlv = tlv_wrap( $mc, $known_types{'InstanceLabelHuffman1'}, $enc);

  push @tlvs, $tlv;

  print "ENCODED '", $ts, "' into hc ", $enc, " and tlv ", $tlv, "\n";
}

my $mesg_suffix = "This is some normal text.";
my $mesg = tlvs_to_message(\@tlvs) . $mesg_suffix;

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

my ($res, $rest) = run_callbacks($mc,
              { 'default' => \&def_cb,
                $known_types{'InstanceLabelHuffman1'} => \&ilf_cb,
              },
              $mesg );

die unless $res eq 1;
die unless $rest eq $mesg_suffix;
