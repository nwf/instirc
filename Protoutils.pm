use warnings;
use strict;

package Instance::Protoutils;

use Instance::Definitions qw( %known_types
                    @debug_code_chars
                    $instance_huffman_table1
                    $MESSAGE_START $MESSAGE_END );
require Instance::MasterCoder;
require Instance::HuffmanCoder;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
    dump_message
);

#################################################################

sub dump_message($$) {
    my ($mc, $msg) = @_;
    my $hc = Instance::HuffmanCoder->new($mc, $instance_huffman_table1);
    my ($succ, $rem) = $mc->tlv_run_callbacks(
                  {'default' => sub {
                                  my ($t,$v) = @_;
                                  print "T=$t" ;
                                  while(my ($k,$v) = each %known_types) {
                                    print " ($k)" if $v == $t;
                                  }
                                  print ", V=$v";
                                  { 
                                    my $hdv = $hc->decode($v);
                                    print " (H1:$hdv)" if defined $hdv;

                                    my $tdv = $mc->tdecode($v);
                                    print " (T:$tdv)" if defined $tdv;

                                    my @ldv = $mc->ldecode($v);
                                    my $ldv = join ",", @ldv if defined $ldv[0];
                                    print " (L:$ldv)" if $#ldv >= 0 and defined $ldv[0];
                                  }
                                  print "\n";
                                }},
                  $msg);
    print "Parser failure!\n" if not defined $succ or not $succ;
    print "Remainder: $rem\n" if defined $rem and length $rem > 0;
}

#################################################################

1;
