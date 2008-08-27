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

    my $regex = "^$MESSAGE_START(["
              . (join ("",@{$$coder{'code_chars'}}))
              ."]+)$MESSAGE_END(.*)\$";

    my $rest;
        # Note how this regex works: it will greedily consume into
        # what we think is the message, and may have to backtrack out
        # to find MESSAGE_END.  It will never prematurely terminate
        # the encoded message if it sees MESSAGE_END inside the message.
    if ( $msg =~ /$regex/ ) {
        $msg = $1;
        $rest = $2;
    } else {
        return (0, $msg);
    }

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

    return ($msg eq "", $rest);
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
