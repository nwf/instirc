use warnings;
use strict;

package Instance::Definitions;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
    %known_types 
    $MESSAGE_START $MESSAGE_END
    @default_code_chars @debug_code_chars
    $instance_huffman_table1 $instance_suffix
);

#################################################################
    # We specify these as numbers which MasterCoder will T-encode for
    # us so that we can see them when we switch to using debug code
    # sets.  Somewhat cheesy, I suppose, but nevertheless handy.

our $MESSAGE_START = 12;    # Encodes as ^O^O using default_code_chars
our $MESSAGE_END = 2;       # Encodes as ^O   using default_code_chars

#################################################################

our @default_code_chars = ("", "", "", "", "");
our @debug_code_chars = ("B", "C", "O", "V", "_");

#################################################################
    # This assigns canonical names to the T-encoded type tags.
    # The range 0 to 4 is   RESERVED FOR PROTOCOL EXTENSIONS
    # The range 6 to 14 is  RESERVED FOR GLOBAL ASSIGNMENT
    # The range 18 to 19 is RESERVED FOR GLOBAL ASSIGNMENT
    # The range 20 to 24 is RESERVED FOR LOCAL EXPERIMENTS

our %known_types = (
                    'InstanceLabelHuffman1' => 5,
                    'OTRAdvertisement' => 15,
                    'MiscMessageFlags' => 16,
                    'MSFTComicChat' => 17,
                  );

#################################################################

our $instance_huffman_table1 = [
  "rsoit",  # 2 per
  "gb<>-",  
  "mane.",
  [ "Ch()=", "U\@HG#", "&j+NB", "MFL;:", "^~Q?Z" ],
  [ "'ufp/", "ldcv_" , "STARE",
     [ "I"    , "O"    ,  "wWkqx", "DPyXY", "KVJz\"" ],
     [ "01234", "56789", "%*,|!", "`\$\\{}", "[]" ] #Note three more symbols
                                                    #are possible in the last
                                                    #position here...
  ]
];

#################################################################

our $MSCC_TYPE_AA = 0;
our $MSCC_TYPE_HASH = 1;

#################################################################

1;
