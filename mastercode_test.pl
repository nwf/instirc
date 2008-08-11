use warnings;

# use Irssi::Scripts::Instance::Mastercode; ### XXX
use mastercode qw(lencode ldecode tencode_padded tdecode);

print "Checking T encoding machinery... \n";

foreach my $i (0 .. 35) {
    my $enc = tencode_padded($i,2);
    my $dec = tdecode($enc);

    print $i, " ", $enc, " ==> ", $dec, "\n" if $i % 10 == 0;

    die if length $enc != 2;
    die if $dec != $i;
}

print "Checking L encoding machinery... \n";

foreach my $i (0 .. 1554) {
    my $enc = lencode($i);
    my ($deci, $decsize) = ldecode($enc);

    print $i, " ", $enc, " (", length $enc, 
               ") ==> ", $deci, " (", $decsize, ")\n"
               if $i % 100 == 0;

    die if $deci != $i;
    die if $decsize != length $enc;

}


