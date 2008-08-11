use warnings;
use strict;

use Math::BaseCalc;
use POSIX qw( floor );

#package Irssi::Scripts::Instance::Mastercode;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
            tencode tencode_padded tdecode lencode ldecode
);

$VERSION = '0.0';

#################################################################

my $MESSAGE_START = "";
my $MESSAGE_END = "";

#################################################################

#my @code_chars = ("", "", "", "", "", "");

# This version is lovely for visual debugging.
my @code_chars = ("B", "C", "G", "O", "V", "_");
my %code_chars_rev;

my $i = 0;
foreach (@code_chars) {
	  $code_chars_rev{$_} = $i++;
}

my $code_chars_count = scalar @code_chars;

#################################################################

my $tencoder = new Math::BaseCalc(digits => \@code_chars);

sub tencode ($) { $tencoder->to_base(@_); }
sub tdecode ($) { $tencoder->from_base(@_); }

sub tencode_padded ($$) {
    my $in = shift @_;
    my $minpad = shift @_;

    my $tenc = tencode($in);
    return $code_chars[0]
                x ($minpad > length $tenc ? $minpad - length $tenc : 0)
           . $tenc;
}

sub lenc_body_len($) {
    my $in = shift @_;
    return 0 if $in == 0;
    return floor( log(($code_chars_count-1)*$in + 1) / log($code_chars_count) );
}

sub lenc_correction($) {
    my $enclen = shift @_;
    return ( ($code_chars_count**($enclen) - 1) / ($code_chars_count-1) );
}

sub lencode ($) {
    my $in = shift @_;
    my $enclen = lenc_body_len($in);

    die "Can't encode numbers that big!" if $enclen >= $code_chars_count - 1;

    return tencode($enclen) if $in == 0;

    $in -= lenc_correction($enclen);

    return tencode($enclen) . tencode_padded($in, $enclen);
}

sub ldecode($) {
    my $in = shift @_;

    my $enclen = substr($in, 0, 1);
    my $reallen = tdecode($enclen);

    die "Can't decode numbers that big!" if $reallen >= $code_chars_count - 1;

    my $encval = substr($in, 1, $reallen);

    my $realval = tdecode($encval);
    $realval += lenc_correction($reallen);

    return ( $realval, $reallen+1 )
}

#################################################################

1;
