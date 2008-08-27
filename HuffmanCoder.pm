use warnings;

#package Irssi::Scripts::Instance::HuffmanCoder;
package HuffmanCoder;

#################################################################

sub _build_encoding_table($$$$);
sub _build_encoding_table($$$$) {
  my ($code_chars, $dec_tbl, $enc_tbl, $prefix) = @_;

  if (ref $dec_tbl eq "") {
    if (length $dec_tbl == 1) {
      $enc_tbl->{$dec_tbl} = $prefix;
    } else {
      my $i = 0;
      foreach my $char (split(//, $dec_tbl)) {
        _build_encoding_table($code_chars, $char,
                             $enc_tbl, $prefix.$$code_chars[$i++]);
      }
    }
  } else {
    my $i = 0;
    foreach my $tbl (@$dec_tbl) {
      _build_encoding_table($code_chars, $tbl,
                            $enc_tbl, $prefix.$$code_chars[$i++]);
    }
  }

  return $enc_tbl;
}

#################################################################

# The constructor takes a MasterCoder object and peers inside to
# borrow the coding characters.  This is to make it easy on upstream
# modules, not for any technical necessity.

sub new ($$$) {
  my $class = shift @_;
  my $mastercoder = shift @_;
  my $hufftree = shift @_;

  return undef if not defined $mastercoder;
  return undef if not defined $$mastercoder{'code_chars'};

  my $enctable = _build_encoding_table($$mastercoder{'code_chars'},
                                      $hufftree, {}, "");

  bless {
    'ccr' => $$mastercoder{'code_chars_rev'},
    'dt' => $hufftree,
    'et' => $enctable,
  }, $class;
}

#################################################################

sub dump_encode_table($);
sub dump_encode_table($) {
	my $self = shift @_;

	foreach my $key (sort keys %{$$self{'et'}}) {
		printf " %s -> ", $key;
		foreach my $char (split(//, $$self{'et'}{$key})) {
			printf "%2x ", ord($char);
		}
		print "\n";
	}
}

sub _dump_decode_table_helper($);
sub _dump_decode_table_helper($) {
  my $tbl = shift @_;

  if (ref $tbl eq "") {
    if (length $tbl == 1) {
      print "'".$tbl."' ";
    } else {
      print "\"$tbl\" ";
    }
  } else {
    print "[";
    for my $i (0 .. 5) {
      _dump_decode_table_helper($tbl->[$i]);
    }
    print "] ";
  }
}

sub dump_decode_table($) {
  my ($self) = @_;
  _dump_decode_table_helper( $$self{'dt'} );
  print "\n";
}

#################################################################

sub encode($$) {
  my ($self, $in) = @_;

  my $result = "";
  foreach my $char (split(//, $in)) {
    my $code = $$self{'et'}{$char};
		return undef if not defined $code;
    $result .= $code;
  }
  return $result;
}

sub _decode_char($$$) {
  my ($ccr, $char, $tbl) = @_;

  if (ref $tbl eq "") {
    return substr($tbl, $$ccr{$char}, 1);
  } else {
    return $tbl->[$$ccr{$char}];
  }
}

sub _is_char($) {
  my ($char) = @_;
  return (ref $char eq "") && (length $char == 1);
}

sub decode($$) {
  my ($self, $inst) = @_;
  my $ccr = $$self{'ccr'};

  my $result = "";
  while ($inst ne "") {
    my $tbl = $$self{'dt'};
    while (!_is_char($tbl)) {
      my $code = substr($inst, 0, 1);
      $inst = substr($inst, 1);
      $tbl = _decode_char($ccr, $code, $tbl);
    }
    $result .= $tbl;
  }
  return $result;
}

1;
