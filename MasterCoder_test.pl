use warnings;
use strict;

require Instance::MasterCoder;
use Instance::Definitions qw( @debug_code_chars $MESSAGE_START $MESSAGE_END );

my $coder = Instance::MasterCoder->new(\@debug_code_chars, $MESSAGE_START, $MESSAGE_END );

print "Some handy quick tests... \n";
die unless $coder->tencode_padded($MESSAGE_START,2) eq "OO";

print "Checking T encoding machinery... \n";

foreach my $i (0 .. 24) {
    my $enc = $coder->tencode_padded($i,2);
    my $dec = $coder->tdecode($enc);

    print $i, " ", $enc, " ==> ", $dec, "\n" if $i % 10 == 0;

    die if length $enc != 2;
    die if $dec != $i;
}

print "Checking L encoding machinery for a variety of biases... \n";
print "Some warnings are normal!  We have to test that llargest()\n";
print "returns the right things.\n";

foreach my $bias ( 0 .. 2 ) {

    $$coder{'_lbias'} = $bias;
    my $limit = $coder->llargest();
    print "BIAS ",$bias," LIMIT ",$limit,"\n";

    foreach my $i (0 .. $limit) {
        my $enc = $coder->lencode($i);
        my ($deci, $decsize) = $coder->ldecode($enc . "_____");

        die if not defined $enc;

        print "  ", $i, " ", $enc, " (", length $enc, 
                   ") ==> ", $deci, " (", $decsize, ")\n"
                   if $i % 100 == 0;

        die if $deci != $i;
        die if $decsize != length $enc;
    }

    my $enc_undef = $coder->lencode($limit+1);
    die if defined $enc_undef;
}

print "Successfully completed.\n";
