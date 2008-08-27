use warnings;
use strict;

use Math::BaseCalc;
use POSIX qw( floor );

#package Irssi::Scripts::Instance::Mastercoder;
package MasterCoder;

#################################################################

sub new ($$) {
  my $class = shift @_;
  my $code_chars = shift @_;

  return undef if not defined $code_chars;

  my $i = 0;
  my $code_chars_rev = {};
  foreach (@$code_chars) {
    $$code_chars_rev{$_} = $i++;
  }

  my $tencoder = new Math::BaseCalc(digits => $code_chars);

  bless {
    # Treat as read only exports, please
   'code_chars' => $code_chars,
   'code_chars_rev' => $code_chars_rev,
   'code_chars_count' => scalar @$code_chars,

    # Treat as private; you shouldn't use this; use
    # ->tencode and ->tdecode instead.
   '_tencoder' => $tencoder,
  }, $class;
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
    return POSIX::floor( log(($ccc-1)*$in + 1) / log($ccc) );
}

sub _lenc_correction($) {
    my $self = shift @_;
    my $enclen = shift @_;
    my $ccc = $$self{'code_chars_count'};
    return ( ($ccc**($enclen) - 1) / ($ccc-1) );
}

sub lencode ($$) {
    my $self = shift @_;
    my $in = shift @_;
    my $enclen = $self->_lenc_body_len($in);

    my $ccc = $$self{'code_chars_count'};

    die "Can't encode numbers that big!" if $enclen >= $ccc - 1;

    return $self->tencode($enclen) if $in == 0;

    $in -= $self->_lenc_correction($enclen);

    return $self->tencode($enclen) . $self->tencode_padded($in, $enclen);
}

sub ldecode($$) {
    my $self = shift @_;
    my $in = shift @_;

    my $enclen = substr($in, 0, 1);
    my $reallen = $self->tdecode($enclen);

    my $ccc = $$self{'code_chars_count'};

    die "Can't decode numbers that big!" if $reallen >= $ccc - 1;

    my $encval = substr($in, 1, $reallen);

    my $realval = $self->tdecode($encval);
    $realval += $self->_lenc_correction($reallen);

    return ( $realval, $reallen+1 )
}

#################################################################

1;
