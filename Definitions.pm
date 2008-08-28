use warnings;
use strict;

package Instance::Definitions;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
    %known_types 
    $MESSAGE_START $MESSAGE_END
    @default_code_chars
    @debug_code_chars
    $instance_huffman_table1
);

#################################################################
    # We specify these as numbers which MasterCoder will T-encode for
    # us so that we can see them when we switch to using debug code
    # sets.  Somewhat cheesy, I suppose, but nevertheless handy.

our $MESSAGE_START = 21;    # Encodes as ^O^O using default_code_chars
our $MESSAGE_END = 3;       # Encodes as ^O   using default_code_chars

#################################################################

our @default_code_chars = ("", "", "", "", "", "");
our @debug_code_chars = ("B", "C", "G", "O", "V", "_");

#################################################################

our %known_types = (
                    'InstanceLabelHuffman1' => 0x6,
                    'InstanceContinuationMessage' => 0x7,
                  );

#################################################################

### This is a 6-ary tree, ideally of the Huffman variety.
### Note that for convenience, plies of single characters may be
### represented as strings.  Plies of larger varieties need to
### be represented as array references.

#my $decode_table = [
#  "abcdef",
#  "ghijkl",
#  "mnopqr",
#  "stuvwx",
#  [ "y",
#    "z",
#    "-",
#    "_", 
#    ".+=&\@!",
#    "*^/\$#?" ],
#  [ "ABCDEF",
#    "GHIJKL",
#    "MNOPQR",
#    "STUVWX",
#    "YZ1234",
#    "567890"] ];

### The following version is determined by Smaug (and nwf) by
###   Ensuring one count
###   /usr/share/dict/** filtered
###   /usr/share/doc/*   filtered
###
### In particular, by...
###
### LIST='abcdefghijklmnopqrstuvwxyz'\
###      'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890'\
###      '_.+=&@!*^\$#?-'
### (echo $LIST; find /usr/share/dict /usr/share/doc -type f -exec cat {} \;\
###    | LC_ALL="C" sed -e s/[^$LIST]//g ) | perl ./huffgen.pl
###
### It was subsequently slightly re-arranged to take advantage of the
### shorter encodings available in gwillen's storage here.

our $instance_huffman_table1 = [
	"staelr",
	"0yfb.g",
	"ESAvT-",
	"=umhdp",
	[
		"c",
		"o",
		"i",
		"n",
		"M#854H",
		"P&Bx3N",
	],
	[
		"UjG796",
		"FO2kLI",
		"C_1wDR",
		"^Q+@?Z",
		"JK!\\\$V",
		"XYzW*q",
	],
];

#################################################################
1;
