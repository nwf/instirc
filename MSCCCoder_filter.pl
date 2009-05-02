use warnings;
use strict;
#use Data::Dumper;

require Instance::MasterCoder;
require Instance::MSCCCoder;
use Instance::Definitions qw( @debug_code_chars $MESSAGE_START $MESSAGE_END );

my $mc = Instance::MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END);
my $msccc = Instance::MSCCCoder->new($mc);

print "FOO ", $mc->{'code_chars'}[0], "\n";

while(my $in = <>) {
  chomp $in;
  my $enc = $msccc->encode($in);
  my $dec = $msccc->decode($enc);
  print $in, " ==> ", $enc, " ==> ", $dec, "\n";
}
