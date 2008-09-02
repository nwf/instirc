use warnings;
use strict;

use Math::BaseCalc;
use POSIX qw( floor );

package Instance::MasterCoder;

#################################################################

sub new ($$$$) {
  my $class = shift @_;
  my $code_chars = shift @_;
  my $msgprefix = shift @_;
  my $msgsuffix = shift @_;

  return undef if not defined $code_chars;

  my $i = 0;
  my $code_chars_rev = {};
  foreach (@$code_chars) {
    $$code_chars_rev{$_} = $i++;
  }

  my $tencoder = new Math::BaseCalc(digits => $code_chars);

  my $self = bless {
    # Treat as read only exports, please
   'code_chars' => $code_chars,
   'code_chars_rev' => $code_chars_rev,
   'code_chars_count' => scalar @$code_chars,

    # Treat as private; you shouldn't use this; use
    # ->tencode and ->tdecode instead.
   '_tencoder' => $tencoder,

    # Treat as private, though you may set this
    # once at construction if you really feel like it.
   '_lbias' => 1,
  }, $class;

  $$self{'msg_prefix'} = $self->tencode($msgprefix);
  $$self{'msg_suffix'} = $self->tencode($msgsuffix);

  return $self;
}

#################################################################

sub tencode ($$) { (shift @_)->{'_tencoder'}->to_base(@_); }
sub tdecode ($$) { (shift @_)->{'_tencoder'}->from_base(@_); }

sub tencode_padded ($$$) {
    my $self = shift @_;
    my $in = shift @_;
    my $minpad = shift @_;

    my $tenc = $self->tencode($in);

    return @{$$self{'code_chars'}}[0]
                x ($minpad > length $tenc ? $minpad - length $tenc : 0)
           . $tenc;
}

#################################################################

sub _lenc_body_len($$) {
    my $self = shift @_;
    my $in = shift @_;

    my $ccc = $$self{'code_chars_count'};

    return 0 if $in == 0;
    return POSIX::floor( log(($ccc-1)*$in + 1) / log($ccc) ) - $$self{'_lbias'};
}

sub _lenc_correction($) {
    my $self = shift @_;
    my $enclen = shift @_;
    my $ccc = $$self{'code_chars_count'};
    return ( ($ccc**($enclen) - 1) / ($ccc-1) );
}

sub lencode ($$) {
    my $self = shift @_;
    my $in = (shift @_);
    $in += $self->_lenc_correction($$self{'_lbias'});
    my $enclen = $self->_lenc_body_len($in);

    my $ccc = $$self{'code_chars_count'};

    warn "Can't encode numbers that big!" if $enclen >= $ccc - 1;
    return undef if $enclen >= $ccc - 1;

    $in -= $self->_lenc_correction($enclen+$$self{'_lbias'});

    return $self->tencode($enclen) if $in == 0
                                  and $enclen == 0
                                  and $$self{'_lbias'} == 0;

    return $self->tencode($enclen)
         . $self->tencode_padded($in, $enclen+$$self{'_lbias'});
}

sub ldecode($$) {
    my $self = shift @_;
    my $in = shift @_;

    my $enclen = substr($in, 0, 1);
    my $reallen = $self->tdecode($enclen);

    my $ccc = $$self{'code_chars_count'};

    warn "Can't decode numbers that big!" if $reallen >= $ccc - 1;
    return (undef, undef) if length $in < $reallen or $reallen >= $ccc - 1;

    $reallen += $$self{'_lbias'};

    my $encval = substr($in, 1, $reallen);

    my $realval = $self->tdecode($encval);
    $realval += $self->_lenc_correction($reallen);
    $realval -= $self->_lenc_correction($$self{'_lbias'});

    return ( $realval, $reallen+1 )
}

sub llargest($) {
    my $self = shift @_;

    my $ccc = $$self{'code_chars_count'};
    return $self->_lenc_correction($ccc + $$self{'_lbias'} - 1)
         - $self->_lenc_correction($$self{'_lbias'})
         - 1;
}

#################################################################

    # Takes an already encoded message (encoded somehow by the
    # outside, e.g. with a HuffmanCoder or by using tencode or
    # lencode directly) and wraps it inside a TLV record.
sub tlv_wrap($$$) {
    my ($self, $type, $message) = @_;

    ### XXX We really ought ensure that the T-encoded forms are
    ### exactly, rather than just at least, two symbols wide.

    return $self->tencode_padded($type,2)
         . $self->lencode(length $message)
         . $message;
}

    # Takes a reference to an array of TLVs and concatenates them,
    # framing the whole result as required by protocol.
sub tlvs_to_message($$){
    my ($self, $tlvs) = @_;

    my $mesg = "";

    foreach my $tlv (@$tlvs) {
       $mesg = $mesg . $tlv; 
    }

    my $lenc = $self->lencode(length $mesg);

    return $$self{'msg_prefix'}.$lenc.$mesg.$$self{'msg_suffix'};
}

sub tlv_run_callbacks($$$) {
    my ($self, $cbs, $msg) = @_;

        # Note how this regex works: it will greedily consume into
        # what we think is the message, and may have to backtrack out
        # to find msg_suffix.  It will never prematurely terminate
        # the encoded message if it sees msg_prefix inside the message.
    my $regex = "^".$$self{'msg_prefix'}."(["
              . (join ("",@{$$self{'code_chars'}}))
              ."]+)".$$self{'msg_suffix'}."(.*)\$";

        # This regex is a little different.  It nongreedly consumes the
        # ordinary text and will repeatedly backtrack in the presence of
        # multiple message prefix sigils.
    my $regex2 = "^(.*?)"
               . $$self{'msg_prefix'}."(["
               . (join ("",@{$$self{'code_chars'}}))
               ."]+)".$$self{'msg_suffix'}."\$";

    my ($tlvstr, $rest) = (undef, undef);
    if ( $msg =~ /$regex/ ) {
        $tlvstr = $1;
        $rest = $2;
    } elsif ( $msg =~ /$regex2/ ) {
        $tlvstr = $2;
        $rest = $1;
    } else {
        return (0, $msg);
    }

      # That's meta-l, not the conductive solid.
    my ($metal, $metallen) = $self->ldecode($tlvstr);
    return (0, $msg) if (length $tlvstr) < $metallen + $metal;
      # So here's an interesting connundrum.  It might be that
      # the additional text we insert after ours looks like a
      # message end.  Therefore, once we have extracted metal,
      # we need to check that there's a msg_suffix where there
      # should be.
    if ((length $tlvstr) > $metallen + $metal) {
      my $ssws = substr($tlvstr, $metallen + $metal);
      return (0, $msg) if (index $ssws, $$self{'msg_suffix'});

      # Now put what should be on $rest back on it.
      $rest = substr($tlvstr, $metallen + $metal) . $rest;
    }
    $msg = substr($tlvstr, $metallen, $metal);


    while( $msg ne "" )
    {
        last if length $msg < 2;
        my $tenc = substr($msg, 0, 2);
        my $msg2 = substr($msg, 2); 
        my $t = $self->tdecode($tenc);

        my ($l, $lenclen) = $self->ldecode($msg2);
        last if not defined $l;
        my $msg3 = substr($msg2, $lenclen);

        last if length $msg3 < $l;
        my $v = substr($msg3, 0, $l);
        $msg = substr($msg3, $l);

        if (exists $$cbs{$t}) {
            $$cbs{$t}($t, $v);
        } elsif (exists $$cbs{'default'}) {
            $$cbs{'default'}($t, $v);
        }
    }

    return ($msg eq "", $rest);
} 
 
#################################################################

1;
