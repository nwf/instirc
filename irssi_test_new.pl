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
    description => 'Allows for labeled threads of conversation over IRC.',
    license => 'Public domain');

# XXX
# Sometimes, for some unknown reason, perl emits warnings like the following:
#   Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA
# This package statement is here to suppress it.
{ package Irssi::Nick }

#################################################################

my $DEBUG_FILTERS = 0;

# Very handy for debugging.
#use Data::Dumper;

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

    # Hash on server address, then on channel visible name.
    # Stores the ENCODED form so we aren't chronically rehashing.
    #
    # i.e. (Irssi::Irc::Server){'address'}
    # then (Irssi::Irc::Channel){'visible_name'}
    #
    # Set by /instance command, read by inst_filter_out
my $instance_labels = { };

    # Hash on server address, then on channel visible name.
    # Presence in the resulting hash indicates punted status.
my $punts = { };

#################################################################

my $suppress_in = 0;
sub inst_filter_in {
  if ($suppress_in) { return; }
  my $sendmsg = 1;

    # Server is a Irssi::Irc::Server
    # src_{nick,host,channel} are strings
  my ($server, $text, $src_nick, $src_host, $src_channel) = @_;
  Irssi::print("Filter_in: text is $text; "
              ."($server, $src_nick, $src_host, $src_channel)")
    if $DEBUG_FILTERS;

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
    if (inst_punted($$server{'address'}, $src_channel, $instance_label)) {
      $sendmsg = 0;
    }
    $text = "[$instance_label] $rest";
  } else {
    $text = $rest;
  }

  if ($sendmsg) {
    my $emitted_signal = Irssi::signal_get_emitted();

    $suppress_in = 1;
    Irssi::signal_emit("$emitted_signal", $server, $text,
                        $src_nick, $src_host, $src_channel);
    $suppress_in = 0;
  }
  Irssi::signal_stop();
}

my $suppres_in_own_public = 0;
sub inst_filter_in_own_public {
  if ($suppres_in_own_public) { return; } # XXX
  my $sendmsg = 1;

    # Server is a Irssi::Irc::Server
  my ($server, $text, $target) = @_;
  Irssi::print("Filter_in_2: text is $text; ($server, $target)")
    if $DEBUG_FILTERS;

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
    if (inst_punted($$server{'address'}, $target, $instance_label)) {
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

    $suppres_in_own_public = 1;
    Irssi::signal_emit("$emitted_signal", $server, $text, $target);
    $suppres_in_own_public = 0;
  }
  Irssi::signal_stop();
}

my $suppress_out = 0;
sub inst_filter_out {
  if ($suppress_out) { return; }

  my $emitted_signal = Irssi::signal_get_emitted();

    # Server is a Irssi::Irc::Server
    # channel is a Irssi::Irc::Channel
  my ($text, $server, $channel) = @_;

  # If they lack a server or a channel, trying to resend the message will cause
  # a crash, strangely. So we don't do that.
  return if $server == 0 || $channel == 0; # XXX
  Irssi::print("Filter_out: text is $text; ($server, $channel)")
    if $DEBUG_FILTERS;

  my $instlabel = "";
  if (exists $$instance_labels{$$server{'address'}}) {
     $instlabel = $$instance_labels{$$server{'address'}}
                                   {$$channel{'visible_name'}};
     $instlabel = "" if not defined $instlabel;
  }

  $text = $mc->tlvs_to_message([$mc->tlv_wrap(
                           $known_types{'InstanceLabelHuffman1'},
                           $instlabel)
                           ] ) . $text . " \@" if "" ne $instlabel;

  $suppress_out = 1;
  Irssi::signal_emit("$emitted_signal", $text, $server, $channel);
  Irssi::signal_stop();
  $suppress_out = 0;
}

  #my $instlabel = Irssi::settings_get_str("current_instance");

#################################################################

sub inst_punted($$$) {
  my ($server,$channel,$inst) = @_;

  return 0 if not exists $$punts{$server};
  return 0 if not exists $$punts{$server}{$channel};
  return 1 if exists $$punts{$server}{$channel}{$inst};
  return 0;
}

sub punt_inst($$$) {
  my ($server,$channel,$inst) = @_;
  $$punts{$server}{$channel}{$inst} = undef;
}

# my @puntlist = split(",", Irssi::settings_get_str('punt_list'));
# Irssi::settings_set_str('punt_list', join(",", @puntlist));

sub unpunt_inst($$$) {
  my ($server,$channel,$inst) = @_;
  delete $$punts{$server}{$channel}{$inst};
}

#################################################################

sub cmd_common_startup ($$) {
  my ($server, $witem) = @_;

  if (not defined $witem or $witem == 0) {
    Irssi::print("Can't run without a window item");
    return 0;
  }

  if (not defined $$witem{'visible_name'}) {
    $witem->print("Can't run without a visible name");
    return 0;
  }

  if (not defined $server or $server == 0) { 
    $witem->print("Can't run without a server");
    return 0;
  }

  if (not defined $$server{'address'}) {
    $witem->print("Server has no address?");
    return 0;
  }

  return 1;
}

sub cmd_instance {
  my ($inst, $server, $witem) = @_;

  return if not cmd_common_startup($server,$witem);

  if ($inst eq "") {
    delete $$instance_labels{$$server{'address'}}{$$witem{'visible_name'}};
    $witem->print("No longer using a default instance tag.");
    return;
  }

  my $enc = $hc->encode($inst);
  if (not defined $enc) {
    $witem->print("Can't set instance to '$inst'");
    return;
  }

  $$instance_labels{$$server{'address'}}{$$witem{'visible_name'}} = $enc;

  $witem->print("Default instance is now '$inst'.");
}
#Irssi::settings_set_str('current_instance', $_[0]);

sub cmd_punt {
  my ($inst, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);
  punt_inst($$server{'address'},$$witem{'visible_name'},$inst);
}

sub cmd_unpunt {
  my ($inst, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);
  unpunt_inst($$server{'address'},$$witem{'visible_name'},$inst);
} 

sub cmd_inst_say {
  my ($args, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);

  my @split = split /\s+/, $args, 2;
  if (scalar @split != 2) {
    $witem->print("Need at least an instance and a message.");
    return;
  }

  my ($inst, $text) = @split;

  my $instenc = $hc->encode($inst);
  if (not defined $instenc) {
    $witem->print("Instance '$inst' is unencodable; message not sent.");
    return;
  }

  $text = $mc->tlvs_to_message([$mc->tlv_wrap(
                           $known_types{'InstanceLabelHuffman1'},
                           $instenc)
                           ] ) . $text . " \@" if "" ne $inst;

  $suppress_out = 1;
  Irssi::signal_emit("send text", $text, $server, $witem);
  $suppress_out = 0;
}

#################################################################

Irssi::signal_add_first('message public', 'inst_filter_in');
Irssi::signal_add_first('message own_public', 'inst_filter_in_own_public');
Irssi::signal_add_first('send text', 'inst_filter_out');
Irssi::command_bind('instance', 'cmd_instance');
Irssi::command_bind('instsay', 'cmd_inst_say');
Irssi::command_bind('punt', 'cmd_punt');
Irssi::command_bind('unpunt', 'cmd_unpunt');

# The old way of storing these...
#Irssi::settings_add_str('lookandfeel', 'current_instance', "default");
#Irssi::settings_add_str('lookandfeel', 'punt_list', "");

# XXX :-(
#Irssi::statusbar_item_register('current_instance', undef, 'current_instance');
#Irssi::statusbars_recreate_items();
#Irssi::statusbar_items_redraw('current_instance');
    
#################################################################

Irssi::print("Instancing module v0.0.3 -- Explosions Less Extremely Probable");
