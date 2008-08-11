use warnings;

#package Irssi::Scripts::Instance::Tagger1;

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

my $decode_table = [
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

sub build_encoding_table($$$);
sub build_encoding_table($$$) {
  my ($dec_tbl, $enc_tbl, $prefix) = @_;

  if (ref $dec_tbl eq "") {
    if (length $dec_tbl == 1) {
      $enc_tbl->{$dec_tbl} = $prefix;
    } else {
      my $i = 0;
      foreach my $char (split(//, $dec_tbl)) {
        build_encoding_table($char, $enc_tbl, $prefix.$code_chars[$i++]);
      }
    }
  } else {
    my $i = 0;
    foreach my $tbl (@$dec_tbl) {
      build_encoding_table($tbl, $enc_tbl, $prefix.$code_chars[$i++]);
    }
  }
}

my $encode_table = {};
build_encoding_table($decode_table, $encode_table, "");

sub dump_encode_table($);
sub dump_encode_table($) {
	my ($tbl) = @_;

	foreach my $key (sort keys %$tbl) {
		printf " %s -> ", $key;
		foreach my $char (split(//, $tbl->{$key})) {
			printf "%2x ", ord($char);
		}
		print "\n";
	}
}

sub dump_decode_table($);
sub dump_decode_table($) {
  my ($tbl) = @_;

  if (ref $tbl eq "") {
    if (length $tbl == 1) {
      print $tbl." ";
    } else {
      print "\"$tbl\" ";
    }
  } else {
    print "[";
    for my $i (0 .. 5) {
      dump_decode_table($tbl->[$i]);
    }
    print "] ";
  }
}

#################################################################

sub encode_instance($) {
  my ($inst) = @_;

  my $result = "";
  foreach my $char (split(//, $inst)) {
    my $code = $encode_table->{$char};
		return undef if not defined $code;
    $result .= $code;
  }
  return $result.$END_CODE;
}

sub decode_char($$) {
  my ($char, $tbl) = @_;
  
  if (ref $tbl eq "") {
    return substr($tbl, $code_chars_rev{$char}, 1);
  } else {
    return $tbl->[$code_chars_rev{$char}];
  }
}

sub is_char($) {
  my ($char) = @_;
  return (ref $char eq "") && (length $char == 1);
}

sub decode_instance($) {
  my ($inst) = @_;

	my $lec = length($END_CODE);
	my $lin = length($inst);

	return "" if $lin <= $lec;

  my $lastchars = substr($inst, $lin - $lec);
  return "" if $lastchars ne $END_CODE;

  $inst = substr($inst, 0, $lin - $lec);

  my $result = "";
  while ($inst ne "") {
    my $tbl = $decode_table;
    while (!is_char($tbl)) {
      my $code = substr($inst, 0, 1);
      $inst = substr($inst, 1);
      $tbl = decode_char($code, $tbl);
    }
    $result .= $tbl;
  }
  return $result;
}

1;
