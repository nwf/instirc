use strict;

use Data::Dumper;
use Instance::Definitions qw( %known_types
                    @default_code_chars
                    $instance_huffman_table1
                    $MESSAGE_START $MESSAGE_END );
require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Protoutils qw( dump_message );

my $mc = Instance::MasterCoder->new(\@default_code_chars, $MESSAGE_START, $MESSAGE_END);
my $hc = Instance::HuffmanCoder->new($mc, $instance_huffman_table1);

my $cmsg_from;

my $taglines = 0;
my %tags = ( );
sub cb_it ($$) {
    my ($t,$v) = @_;
    die unless $t = $known_types{'InstanceLabelHuffman1'};

    $taglines++;

    my $dcv = $hc->decode($v);
    $tags{$dcv} = 0 if not exists $tags{$dcv};
    $tags{$dcv}++;
}

my $botlines = 0;
my %bots = ( );
sub cb_mmf ($$) {
    my ($t,$v) = @_;
    my $dcv = $mc->tdecode($v);
    my $is_bot = $dcv & 1 if ($dcv > 2);

    if($is_bot) {
        $botlines++;
        $bots{$cmsg_from}++ if defined $cmsg_from;
    }
}


while(my $text = <STDIN>) {
    chomp $text;

    # CTCP
    $text =~ s///g;

    $cmsg_from = $text =~ /^([^<]*<\s*([^>]+)>|.*-!- ([^ ]+) )/
                    ? ($2 or $3) : undef;

    my ($succ, $rem) = $mc->tlv_run_callbacks(
        {
            $known_types{'InstanceLabelHuffman1'} => \&cb_it,
            $known_types{'MiscMessageFlags'} => \&cb_mmf,
        },
        $text
    );
}

print "TOTAL OF $taglines INSTANCE LABELS:\n";
foreach my $l (sort { $tags{$b} <=> $tags{$a} } (keys %tags)) {
    print "  $l : $tags{$l}\n";
}
print "TOTAL OF $botlines MMF BOT TAGS:\n";
foreach my $b (sort { $bots{$b} <=> $bots{$a} } (keys %bots)) {
    print "  $b : $bots{$b}\n";
}
