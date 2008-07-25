use warnings;

# use Irssi::Scripts::Instance::Coder; ### XXX
use code;

while (my $inst = <>) {
	chomp $inst;

	my $enc = Irssi::Scripts::Instance::Coder::encode_instance($inst);

	unless (defined $enc) {
		print "Unable to encode input.\n";
		next;
	}

	my $dec = Irssi::Scripts::Instance::Coder::decode_instance($enc);

	print $inst.">>".$dec."(".(length $enc)."):";

	foreach my $char (split(//, $enc)) {
		printf " %2X", ord($char);
	}
	print "\n";

	die unless ($inst eq $dec);
}
