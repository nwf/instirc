use warnings;

package Instance::MSCCCoder;


use Math::BaseCalc;
require Instance::HuffmanCoder;
use Instance::Definitions qw( %known_types
                    $instance_huffman_table1 );

my $MSCC_CHARS = [0,1,2,3,4,5,6,7,8,9,':',';','<','>','@','='];
my $MSCC_ES_G = 6;
my $MSCC_ES_E = 6;

#################################################################

# The constructor takes a MasterCoder object and peers inside to
# borrow the coding characters.

sub new ($$) {
  my $class = shift @_;
  my $mc = shift @_;

  return undef if not defined $mc;
  return undef if not defined $$mc{'code_chars'};

  my $hc = Instance::HuffmanCoder->new($mc, $instance_huffman_table1);

  bless {
    'mc' => $mc,
    'hc' => $hc,
    'tc' => new Math::BaseCalc(digits => $MSCC_CHARS),
    'nog' => $$mc{'code_chars'}[-1] x $MSCC_ES_G,
    'noe' => $$mc{'code_chars'}[-1] x $MSCC_ES_E,
  }, $class;
}

#################################################################

sub encode($$) {
    my ($self, $msg) = @_;

    my $mc = $$self{'mc'};
    my $tc = $$self{'tc'};

    my $res = "";

    if ($msg =~ /.*G(...).*/) {
        my $val = $tc->from_base($1);
        $res .= $mc->tencode_padded($val, $MSCC_ES_G);
    } else {
        $res .= $$self{'nog'};
    }

    if ($msg =~ /.*E(...).*/) {
        my $val = $tc->from_base($1);
        $res .= $mc->tencode_padded($val, $MSCC_ES_E);
    } else {
        $res .= $$self{'noe'};
    }

    $res .= $mc->tencode_padded( ($msg =~ /.*R.*/) ? 1 : 0, 1 ) ;

    if ($msg =~ /.*M(.).*/) {
        my $val = $tc->from_base($1);
        die "M0?" if $val == 0;
        $res .= $mc->tencode_padded($val, 1);
    } else {
        $res .= $mc->tencode_padded(0, 1);
    }

     if ($msg =~ /.*T(.*)$/) {
        my $val .= $$self{'hc'}->encode($1);
        $res .= $mc->tencode_padded(1, 1) . $val;
    } else {
        $res .= $mc->tencode_padded(0, 1);
    }
   
    return $res;
    
}

sub decode($$) {
    my ($self, $msg) = @_;

    my $mc = $self->{'mc'};
    my $tc = $$self{'tc'};

    my $res = "";

    {
        my $g = substr $msg, 0 , $MSCC_ES_G;
        if ($g ne $$self{'nog'}) {
            my $val = $mc->tdecode($g);
            $res .= "G" . sprintf "%.3d", $tc->to_base($val);
        }
    }

    {
        my $e = substr $msg, $MSCC_ES_G, $MSCC_ES_E;
        if ($e ne $$self{'noe'}) {
            my $val = $mc->tdecode($e);
            $res .= "E" . sprintf "%.3d", $tc->to_base($val);
        }
    }

    {
        my $r = substr $msg, $MSCC_ES_G + $MSCC_ES_E, 1;
        $res .= "R" if ($mc->tdecode($r) != 0);
    }
   
    {
        my $m = substr $msg, $MSCC_ES_G + $MSCC_ES_E + 1, 1;
        my $val = $mc->tdecode($m);
        $res .= "M$val" if $val != 0;
    }

    {
        my $t = substr $msg, $MSCC_ES_G + $MSCC_ES_E + 2;
        if ($mc->tdecode(substr $t, 0, 1) != 0) {
            my $val = $$self{'hc'}->decode(substr $t, 1) ;
            $res .= "T$val";
        }
    }

    return $res; 
}

1;
