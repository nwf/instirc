use strict;
use warnings;
no warnings 'closure';

use vars qw($VERSION %IRSSI);
$| = 1;

use Irssi;
$VERSION = 'irssi-test v0.01';
%IRSSI = (
    authors => 'Glenn Willen',
    contact => 'gwillen@nerdnet.org',
    name => 'irssi-test',
    description => 'Heh.',
    license => 'Public domain');

# Sometimes, for some unknown reason, perl emits warnings like the following:
#   Can't locate package Irssi::Nick for @Irssi::Irc::Nick::ISA
# This package statement is here to suppress it.
{ package Irssi::Nick }

# XXX Do we want to make any guarantees about the appearance of this delimiter
# in our encoded message?
my $MAGIC_DELIM = "";
my $END_CODE = "";

#################################################################

my @code_chars = ("", "", "", "", "", "");
my %code_chars_rev = ();
my $i = 0;
foreach (@code_chars) {
  $code_chars_rev{$_} = $i++;
}

#################################################################

my $decode_table = [
  "abcdef",
  "ghijkl",
  "mnopqr",
  "stuvwx",
  [ "y",
    "z",
    "-",
    "_", 
    ".+=&\@!",
    "*^/\$#?" ],
  [ "ABCDEF",
    "GHIJKL",
    "MNOPQR",
    "STUVWX",
    "YZ1234",
    "567890"] ];

sub build_encoding_table($$$);
sub build_encoding_table($$$) {
  my ($dec_tbl, $enc_tbl, $prefix) = @_;

  if (ref $dec_tbl eq "") {
    if (length $dec_tbl == 1) {
      $enc_tbl->{$dec_tbl} = $prefix;
    } else {
      my $i = 0;
      foreach my $char (split(//, $dec_tbl)) {
        build_encoding_table($char, $enc_tbl, $prefix.$code_chars[$i++]);
      }
    }
  } else {
    my $i = 0;
    foreach my $tbl (@$dec_tbl) {
      build_encoding_table($tbl, $enc_tbl, $prefix.$code_chars[$i++]);
    }
  }
}

my $encode_table = {};
build_encoding_table($decode_table, $encode_table, "");

sub dump_decode_table($);
sub dump_decode_table($) {
  my ($tbl) = @_;

  if (ref $tbl eq "") {
    if (length $tbl == 1) {
      print $tbl;
    } else {
      print "\"$tbl\"";
    }
  } else {
    print "[";
    for my $i (0 .. 5) {
      dump_decode_table($tbl->[$i]);
    }
    print "]";
  }
}

#################################################################

sub encode_instance($) {
  my ($inst) = @_;

  my $result = "";
  foreach my $char (split(//, $inst)) {
    my $code = $encode_table->{$char};
    $result .= $code;
  }
  return $result.$END_CODE;
}

sub decode_char($$) {
  my ($char, $tbl) = @_;
  
  if (ref $tbl eq "") {
    return substr($tbl, $code_chars_rev{$char}, 1);
  } else {
    return $tbl->[$code_chars_rev{$char}];
  }
}

sub is_char($) {
  my ($char) = @_;
  return (ref $char eq "") && (length $char == 1);
}

sub decode_instance($) {
  my ($inst) = @_;

  my $lastchar = substr($inst, length($inst) - 1);
  return "" if $lastchar ne $END_CODE;
  $inst = substr($inst, 0, length($inst) - 1);

  my $result = "";
  while ($inst ne "") {
    my $tbl = $decode_table;
    while (!is_char($tbl)) {
      my $code = substr($inst, 0, 1);
      $inst = substr($inst, 1);
      $tbl = decode_char($code, $tbl);
    }
    $result .= $tbl;
  }
  return $result;
}

#################################################################

my $suppress = 0;
my $suppress2 = 0;

sub test_filter_in {
  if ($suppress) { return; }
  my $sendmsg = 1;

  my ($d, $text, $d1, $d2, $d3) = @_;
  Irssi::print("Filter_in: text is $text; ($d, $d1, $d2, $d3)");
  if ($text =~ /$MAGIC_DELIM/) {
    Irssi::print("Contains magic delimiter!");
    my ($msg, $inst) = split("$MAGIC_DELIM", $text, 2);
    my $instance = decode_instance($inst);
    my @puntlist = split(",", Irssi::settings_get_str("punt_list"));
    my $match = scalar grep { $_ eq $instance } @puntlist;
    if ($match) {
      $sendmsg = 0;
    }
    $text = "[$instance] $msg";
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
  if ($text =~ /$MAGIC_DELIM/) {
    Irssi::print("Contains magic delimiter!");
    my ($msg, $inst) = split("$MAGIC_DELIM", $text, 2);
    my $instance = decode_instance($inst);
    if (inst_punted($instance)) {
      $sendmsg = 0;
    }
    $text = "[$instance] $msg";
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
  $text .= " \@".$MAGIC_DELIM.encode_instance(Irssi::settings_get_str("current_instance"));

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
  my ($unk1, $unk2, $inst) = @_;
  punt_inst($inst);
}

sub cmd_unpunt {
  my ($unk1, $unk2, $inst) = @_;
  unpunt_inst($inst);
} 

#################################################################

Irssi::signal_add_first('message public', 'test_filter_in');
Irssi::signal_add_first('message own_public', 'test_filter_in_2');
Irssi::signal_add_first('send text', 'test_filter_out');
Irssi::command_bind('instance', 'cmd_instance');
Irssi::command_bind('punt', 'cmd_punt');
Irssi::command_bind('unpunt', 'cmd_unpunt');
Irssi::settings_add_str('lookandfeel', 'current_instance', "default");
Irssi::settings_add_str('lookandfeel', 'punt_list', "");
# XXX :-(
#Irssi::statusbar_item_register('current_instance', undef, 'current_instance');
#Irssi::statusbars_recreate_items();
#Irssi::statusbar_items_redraw('current_instance');
    
#################################################################

Irssi::print("Instancing module vNO.JUST.NO - Glenn Willen");
