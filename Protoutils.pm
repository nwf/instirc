use warnings;
use strict;

#package Irssi::Scripts::Instance::Protoutils;
package Protoutils;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
    tlv_wrap tlvs_to_message
    run_callbacks
    dump_message
);



use Definitions qw( $MESSAGE_START $MESSAGE_END );

#################################################################

sub tlv_wrap($$$) {
    my ($coder, $type, $message) = @_;

    return $coder->tencode_padded($type,2)
         . $coder->lencode(length $message)
         . $message;
}

sub tlvs_to_message($){
    my ($tlvs) = @_;

    my $mesg = $MESSAGE_START;

    foreach my $tlv (@$tlvs) {
       $mesg = $mesg . $tlv; 
    }

    return $mesg . $MESSAGE_END;
}

sub run_callbacks($$$) {
    my ($coder, $cbs, $msg) = @_;

    return if (0 ne index $msg, $MESSAGE_START);
    $msg = substr($msg, length $MESSAGE_START);

    while( $msg ne "" )
    {
        last if length $msg < 2;
        my $tenc = substr($msg, 0, 2);
        my $msg2 = substr($msg, 2); 
        my $t = $coder->tdecode($tenc);

        my ($l, $lenclen) = $coder->ldecode($msg2);
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

    return $msg eq "";
}

sub dump_message($$) {
    my ($coder, $msg) = @_;
    run_callbacks($coder,
                  {'default' => sub {
                                  my ($t,$v) = @_;
                                  print "T=$t, V=$v\n";
                                }},
                  $msg);
}

#################################################################

1;
