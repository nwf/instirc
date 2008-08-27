use warnings;
use strict;

#package Irssi::Scripts::Instance::Protoutils;
package Protoutils;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw(
    dump_message
);

#################################################################

sub dump_message($$) {
    my ($coder, $msg) = @_;
    $coder->tlv_run_callbacks(
                  {'default' => sub {
                                  my ($t,$v) = @_;
                                  print "T=$t, V=$v\n";
                                }},
                  $msg);
}

#################################################################

1;
