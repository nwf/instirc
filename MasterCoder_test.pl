use warnings;
use strict;

# use Irssi::Scripts::Instance::Mastercode; ### XXX
require MasterCoder;
use Definitions qw( @debug_code_chars );

my $coder = MasterCoder->new(\@debug_code_chars);

print "Checking T encoding machinery... \n";

foreach my $i (0 .. 35) {
    my $enc = $coder->tencode_padded($i,2);
    my $dec = $coder->tdecode($enc);

    print $i, " ", $enc, " ==> ", $dec, "\n" if $i % 10 == 0;

    die if length $enc != 2;
    die if $dec != $i;
}

print "Checking L encoding machinery... \n";

foreach my $i (0 .. 1554) {
    my $enc = $coder->lencode($i);
    my ($deci, $decsize) = $coder->ldecode($enc);

    print $i, " ", $enc, " (", length $enc, 
               ") ==> ", $deci, " (", $decsize, ")\n"
               if $i % 100 == 0;

    die if $deci != $i;
    die if $decsize != length $enc;

}


