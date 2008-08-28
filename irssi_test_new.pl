use strict;
use warnings;
no warnings 'closure';

use vars qw($VERSION %IRSSI);
$| = 1;

use Irssi;
$VERSION = 'irssi-test v0.01';
%IRSSI = (
    authors => 'Glenn Willen and Nathaniel Filardo',
    contact => 'gwillen@nerdnet.org and nwf@cs.jhu.edu',
    name => 'irssi-instances',
    description => 'Heh.',
    license => 'Public domain');

# Sometimes, for some unknown reason, perl emits warnings like the following:
#   Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA
# This package statement is here to suppress it.
{ package Irssi::Nick }

#################################################################

require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Definitions qw( %known_types
                    @debug_code_chars @default_code_chars
                    $instance_huffman_table1
                    $MESSAGE_START $MESSAGE_END );

my $mc_dbg = Instance::MasterCoder->new(\@debug_code_chars,   $MESSAGE_START, $MESSAGE_END);
my $mc_dfl = Instance::MasterCoder->new(\@default_code_chars, $MESSAGE_START, $MESSAGE_END);
my $hc_dbg = Instance::HuffmanCoder->new($mc_dbg, $instance_huffman_table1);
my $hc_dfl = Instance::HuffmanCoder->new($mc_dfl, $instance_huffman_table1);

# XXX Allow some kind of runtime switch between these?
my $mc = $mc_dfl;
my $hc = $hc_dfl;

#################################################################

my $suppress = 0;
my $suppress2 = 0;

sub test_filter_in {
  if ($suppress) { return; }
  my $sendmsg = 1;

  my ($d, $text, $d1, $d2, $d3) = @_;
  Irssi::print("Filter_in: text is $text; ($d, $d1, $d2, $d3)");

  my $instance_label = undef;
  my ($res, $rest) = $mc->tlv_run_callbacks(
              { $known_types{'InstanceLabelHuffman1'} => 
                sub ($$) {
                  my ($t,$v) = @_;
                  $instance_label = $hc->decode($v);
                }
              },
              $text );

  if ($res and defined $instance_label) {
    my @puntlist = split(",", Irssi::settings_get_str("punt_list"));
    my $match = scalar grep { $_ eq $instance_label } @puntlist;
    if ($match) {
      $sendmsg = 0;
    }
    $text = "[$instance_label] $rest";
  } else {
    $text = $rest;
  }

  if ($sendmsg) {
    my $emitted_signal = Irssi::signal_get_emitted();

    $suppress = 1;
    Irssi::signal_emit("$emitted_signal", $d, $text, $d1, $d2, $d3);
    $suppress = 0;
  }
  Irssi::signal_stop();
}

sub test_filter_in_2 {
  if ($suppress2) { return; } # XXX
  my $sendmsg = 1;

  my ($d, $text, $target) = @_;
  Irssi::print("Filter_in_2: text is $text; ($d, $target)");

  my $instance_label = undef;
  my ($res, $rest) = $mc->tlv_run_callbacks(
              { $known_types{'InstanceLabelHuffman1'} => 
                sub ($$) {
                  my ($t,$v) = @_;
                  $instance_label = $hc->decode($v);
                }
              },
              $text );

  if ($res and defined $instance_label) {
    if (inst_punted($instance_label)) {
      $sendmsg = 0;
    }
    # Chop off the " @" we may or may not have put at the end.
    $rest =~ s/^(.*) \@$/$1/;
    $text = "[$instance_label] $rest";
  } else {
    $text = $rest;
  }

  if ($sendmsg) {
    my $emitted_signal = Irssi::signal_get_emitted();

    $suppress2 = 1;
    Irssi::signal_emit("$emitted_signal", $d, $text, $target);
    $suppress2 = 0;
  }
  Irssi::signal_stop();
}

sub test_filter_out {
  if ($suppress) { return; }

  my $emitted_signal = Irssi::signal_get_emitted();

  my ($text, $a, $b) = @_;
  # If they lack a server or a channel, trying to resend the message will cause
  # a crash, strangely. So we don't do that.
  return if $a == 0 || $b == 0; # XXX
  Irssi::print("Filter_out: text is $text; ($a, $b)");

  $text = $mc->tlvs_to_message([$mc->tlv_wrap(
                           $known_types{'InstanceLabelHuffman1'},
                           $hc->encode(Irssi::settings_get_str("current_instance")))
                           ] ) . $text . " \@";

  $suppress = 1;
  Irssi::signal_emit("$emitted_signal", $text, $a, $b);
  Irssi::signal_stop();
  $suppress = 0;
}

#sub current_instance {
#  my ($item, $get_size_only) = @_;
#
#  $item->default_handler($get_size_only, "message", 0, 1);
#}

#################################################################

sub inst_punted($) {
  my ($inst) = @_;

  my @puntlist = split(",", Irssi::settings_get_str("punt_list"));
  my $match = scalar grep { $_ eq $inst } @puntlist;

  return ($match > 0);
}

sub punt_inst($) {
  my ($inst) = @_;

  Irssi::print("punting: $inst");

  if ($inst =~ /,/) {
    Irssi::print("Warning: Can't punt comma!");
    return;
  }
  my @puntlist = split(",", Irssi::settings_get_str('punt_list'));
  push @puntlist, $inst;
  Irssi::settings_set_str('punt_list', join(",", @puntlist));
}

sub unpunt_inst($) {
  my ($inst) = @_;

  Irssi::print("unpunting: $inst");

  if ($inst =~ /,/) {
    Irssi::print("Warning: Can't unpunt comma!");
    return;
  }

  my @puntlist = split(",", Irssi::settings_get_str('punt_list'));
  @puntlist = grep { $_ ne $inst } @puntlist;
  Irssi::settings_set_str('punt_list', join(",", @puntlist));
}

#################################################################

sub cmd_instance {
  pop @_;
  pop @_; # XXX
  Irssi::print("instance: $_[0]");
  Irssi::settings_set_str('current_instance', $_[0]);
}

sub cmd_punt {
  my ($inst, $unk1, $unk2) = @_;
  punt_inst($inst);
}

sub cmd_unpunt {
  my ($inst, $unk1, $unk2) = @_;
  unpunt_inst($inst);
} 

#################################################################

Irssi::signal_add_first('message public', 'test_filter_in');
Irssi::signal_add_first('message own_public', 'test_filter_in_2');
Irssi::signal_add_first('send text', 'test_filter_out');
Irssi::command_bind('instance', 'cmd_instance');
Irssi::command_bind('punt', 'cmd_punt');
Irssi::command_bind('unpunt', 'cmd_unpunt');
# XXX :-(
Irssi::settings_add_str('lookandfeel', 'current_instance', "default");
Irssi::settings_add_str('lookandfeel', 'punt_list', "");
# XXX :-(
#Irssi::statusbar_item_register('current_instance', undef, 'current_instance');
#Irssi::statusbars_recreate_items();
#Irssi::statusbar_items_redraw('current_instance');
    
#################################################################

Irssi::print("Instancing module v0.0.1 -- Explosions Extremely Probable");
