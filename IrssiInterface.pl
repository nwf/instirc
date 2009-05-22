use strict;
use warnings;
no warnings 'closure';


use vars qw($VERSION %IRSSI);
$| = 1;

use Irssi;
$VERSION = '0.1.4';
my $extended_version = "Instancing module v$VERSION";
my $humorous_version = "$extended_version -- A wild T=16 appears!";

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
use Data::Dumper;

#################################################################

require Instance::MasterCoder;
require Instance::HuffmanCoder;
use Instance::Definitions qw( %known_types
                    @debug_code_chars @default_code_chars
                    $instance_huffman_table1 $instance_suffix
                    $MESSAGE_START $MESSAGE_END );

my $mc_dbg = Instance::MasterCoder->new(\@debug_code_chars,   $MESSAGE_START, $MESSAGE_END);
my $mc_dfl = Instance::MasterCoder->new(\@default_code_chars, $MESSAGE_START, $MESSAGE_END);
my $hc_dbg = Instance::HuffmanCoder->new($mc_dbg, $instance_huffman_table1);
my $hc_dfl = Instance::HuffmanCoder->new($mc_dfl, $instance_huffman_table1);

# XXX Allow some kind of runtime switch between these?
my $mc = $mc_dfl;
my $hc = $hc_dfl;

#################################################################
    # XXX irssi doesn't give us any unique identifier for objects; names and
    # so on are subject to change and fascinatingly the updates don't always
    # include enough information to update your own data tables...
    #
    # Rather than track renames and play the resulting guessing game and all
    # that, we just grab the smuggled-out pointer value that irssi uses to
    # read things back in from Perl.  Things would be much easier if we
    # could use use irssi's per-object per-module data tables
    #
    # Gross, isn't it? :)

    # Hash on irssi unique value of window item.
    # Stores the ENCODED form so we aren't chronically rehashing.
    #
    # i.e. (Irssi::Irc::Server){'address'}
    # then (Irssi::Irc::Channel){'name'}
    #
    # Set by /instance command, read by inst_filter_out
    # Scanned on "window item destroy" events to drop obsoleted records.
my $instance_labels = { };

    # Hash on irssi unique value of window item.
    # Result is a hash where:
    #   The instance does not exist as a key => default display
    #   The instance exists but has value undef => punted
    #   The instance exists and has value =>
    #       value is a window item object (not identifier!) which should
    #       receive the message.
    #
    # Scanned on "window item destroy" events to drop obsoleted records,
    #     but it's not enough to scan only in the forward direction.
    #     See the below map.
my $routes = { };

    # The reverse of the above map, kinda.
    #   $$routes{$a}{$b}{'_irssi'} == $c implies that 
    #   $$routes_invmap{$$c{'_irssi'}}{$b} == $a
    #
    # This is used to handle the "window item remove" signal so
    # we can correctly drop references, rather than risk crashing
    # irssi. :)
    #
    # XXX We wish we could hook "window item destroy" instead, but
    # that doesn't produce a signal.  As it is, anybody being fancy
    # with window items stands a good chance of confusing our core.
    # This may be grounds to patch irssi upstream.
    #
my $routes_invmap = { };

#################################################################

sub demangle_and_check_routes($$$) {
  my ( $srv, $channame, $text ) = @_;

  my $target = undef;
  my $instance_label = undef;
  my $warn_initial = 0;
  my $is_bot = 0;
  my @unknowns = ( );
    # Last one wins approach to instance labels.  Sending more than one
    # really ought be an error.
  my ($res, $rest) = $mc->tlv_run_callbacks(
              { $known_types{'InstanceLabelHuffman1'} => 
                sub ($$) {
                  my ($t,$v) = @_;
                  $instance_label = $hc->decode($v);
                }
              , $known_types{'MiscMessageFlags'} => 
                sub ($$) {
                  my ($t,$v) = @_;
                  my $dec = $mc->tdecode($v);
                  $is_bot = $dec & 1 if ($dec > 2);
                }
              , 'warn_initial' => sub () { $warn_initial = 1; }
              , 'default' => 
                sub ($$) { my ($t,$v) = @_; push @unknowns, $t; }
              },
              $text );

  if (Irssi::settings_get_bool("instance_warn_initial") and $warn_initial) {
    Irssi::print("Instancer: warning: $channame sends initial message");
  }

  if (Irssi::settings_get_bool("instance_warn_unknown")
      and (scalar @unknowns) != 0) {
    Irssi::print("Instancer: warning: unknown message types " . (join " ",@unknowns));
  }

  # XXX This is pretty hacky.
  if ($res and $is_bot) {
    $rest = "{bot} " . $rest;
  }

  if ($res and defined $instance_label) {
    $rest =~ s/^(.*)$instance_suffix$/$1/;

    # Find window item given server and name
    my $witem = $srv->window_item_find($channame);

    if (not defined $witem) {
        Irssi::print("No witem while decoding?");
        return (undef, undef, $text);
    }

    # override channel name; this may undefine the target.
    if (inst_routed($witem, $instance_label)) {
        Irssi::print("Instance $instance_label is routed...");

        # See if we have a target.
        my $rtarget = inst_route_target($witem, $instance_label);
        if(defined $rtarget) {

            Irssi::print("Instance $instance_label has target...");
            # Override target 
            $target = $$rtarget{'name'} 
        } else {
            $rest = undef;
        }
    }

    return ($target, $instance_label, $rest);
  }

  return (undef, undef, $text);
}

my $suppress_in = 0;
sub inst_filter_in {
  if ($suppress_in) { return; }

    # Server is a Irssi::Irc::Server
    # src_{nick,host,channel} are strings
  my ($server, $text, $src_nick, $src_host, $src_channel) = @_;
  Irssi::print("Filter_in: text is $text; "
              ."($server, $src_nick, $src_host, $src_channel)")
    if $DEBUG_FILTERS;

  my ($newtarget, $ilabel, $newtext)
    = demangle_and_check_routes( $server,
                                 $src_channel,
                                 $text );

  if (not defined $newtext) {
    Irssi::signal_stop();
    return;
  }

  if (defined $newtarget) {
    $src_channel = $newtarget;
  } elsif (defined $ilabel) {
    $newtext = "[$ilabel] $newtext";
  }

  my $emitted_signal = Irssi::signal_get_emitted();

  $suppress_in = 1;
  Irssi::signal_emit("$emitted_signal", $server, $newtext,
                      $src_nick, $src_host, $src_channel);
  $suppress_in = 0;
  Irssi::signal_stop();
}

my $suppres_in_own_public = 0;
sub inst_filter_in_own_public {
  if ($suppres_in_own_public) { return; } # XXX

    # Server is a Irssi::Irc::Server
  my ($server, $text, $target) = @_;
  Irssi::print("Filter_in_own: text is $text; ($server, $target)")
    if $DEBUG_FILTERS;

  my ($newtarget, $ilabel, $newtext)
    = demangle_and_check_routes( $server,
                                 $target,
                                 $text );

  if (not defined $newtext) {
    Irssi::signal_stop();
    return;
  }

  if (defined $newtarget) {
    $target = $newtarget;
  } elsif (defined $ilabel) {
    $newtext = "[$ilabel] $newtext";
  }

  my $emitted_signal = Irssi::signal_get_emitted();

  $suppres_in_own_public = 1;
  Irssi::signal_emit("$emitted_signal", $server, $newtext, $target);
  $suppres_in_own_public = 0;
  Irssi::signal_stop();
}

my $suppress_in_private = 0;
sub inst_filter_in_private {
  if ($suppress_in_private) { return; }

    # Server is a Irssi::Irc::Server
    # src_{nick,host,channel} are strings
  my ($server, $text, $src_nick, $src_host) = @_;
  Irssi::print("Filter_in_private: text is $text; "
              ."($server, $src_nick, $src_host)")
    if $DEBUG_FILTERS;

  my ($newtarget, $ilabel, $newtext)
    = demangle_and_check_routes( $server,
                                 $src_nick,
                                 $text );

  if (not defined $newtext) {
    Irssi::signal_stop();
    return;
  }

  # XXX note no spport for routing messages here.
  if (defined $ilabel) {
    $newtext = "[$ilabel] $newtext";
  }

  my $emitted_signal = Irssi::signal_get_emitted();

  $suppress_in_private = 1;
  Irssi::signal_emit("$emitted_signal", $server, $newtext,
                      $src_nick, $src_host);
  $suppress_in_private = 0;
  Irssi::signal_stop();
}

my $suppres_in_own_private = 0;
sub inst_filter_in_own_private {
  if ($suppres_in_own_private) { return; } # XXX

    # Server is a Irssi::Irc::Server
  my ($server, $text, $target) = @_;
  Irssi::print("Filter_in_own_private: text is $text; ($server, $target)")
    if $DEBUG_FILTERS;

  my ($newtarget, $ilabel, $newtext)
    = demangle_and_check_routes( $server,
                                 $target,
                                 $text );

  if (not defined $newtext) {
    Irssi::signal_stop();
    return;
  }

  # XXX note no spport for routing messages here.
  if (defined $ilabel) {
    $newtext = "[$ilabel] $newtext";
  }

  my $emitted_signal = Irssi::signal_get_emitted();

  $suppres_in_own_private = 1;
  ### XXX known bug, should send to newtarget, but see the above
  ### inst_filter_in_private for why I'm not quite sure how to do this.
  ### (is $src_nick the corresponding thing for $target?)
  ###
  ### Also listed in TODO as a Known Bug.
  Irssi::signal_emit("$emitted_signal", $server, $newtext, $target);
  $suppres_in_own_private= 0;
  Irssi::signal_stop();
}


sub get_instance_label ($$) {
  my ($srvname, $channame) = @_;
  my $instlabel = undef;
  if (exists $$instance_labels{$srvname}) {
     $instlabel = $$instance_labels{$srvname}{$channame};
  }
  $instlabel = "" if not defined $instlabel;
  return $instlabel;
}

sub generate_outgoing($$) {
    my ($text, $instlabel) = @_;

    my $framedlabel = $mc->tlvs_to_message([$mc->tlv_wrap(
                           $known_types{'InstanceLabelHuffman1'},
                           $instlabel)]);

    $text = $text . $instance_suffix . $framedlabel;
}

my $suppress_out = 0;
sub inst_filter_out {
  if ($suppress_out) { return; }

    # Server is a Irssi::Irc::Server
    # channel is a Irssi::Irc::Channel
  my ($text, $server, $channel) = @_;

  # If they lack a server or a channel, trying to resend the message will cause
  # a crash, strangely. So we don't do that.
  return if $server == 0 || $channel == 0; # XXX
  Irssi::print("Filter_out: text is $text; ($server, $channel)")
    if $DEBUG_FILTERS;

  my $instlabel = get_instance_label($$server{'address'},
                                     $$channel{'name'});

  $text = generate_outgoing($text, $instlabel) if "" ne $instlabel;

  $suppress_out = 1;
  my $emitted_signal = Irssi::signal_get_emitted();
  Irssi::signal_emit("$emitted_signal", $text, $server, $channel);
  Irssi::signal_stop();
  $suppress_out = 0;
}

  #my $instlabel = Irssi::settings_get_str("current_instance");

#################################################################

sub inst_routed($$) {
  my ($witem,$inst) = @_;
  return 0 if not exists $$routes{$$witem{'_irssi'}};
  return 1 if     exists $$routes{$$witem{'_irssi'}}{$inst};
  return 0;
}

sub inst_route_target($$) {
  my ($witem,$inst) = @_;
  return undef if not exists $$routes{$$witem{'_irssi'}};
  return $$routes{$$witem{'_irssi'}}{$inst};
}

sub route_inst($$$$) {
  my ($witem,$inst,$target) = @_;
  $$routes{$$witem{'_irssi'}}{$inst} = $target;
  if ( not exists $$routes_invmap{$$target{'_irssi'}} )
  {
    $$routes_invmap{$$target{'_irssi'}} = { $inst => $$witem{'_irssi'} } ;
  } else {
    $$routes_invmap{$$target{'_irssi'}}{$inst} = $$witem{'_irssi'};
  }
}

sub punt_inst($$) {
  my ($witem,$inst) = @_;
  $$routes{$$witem{'_irssi'}}{$inst} = undef;
}

# my @puntlist = split(",", Irssi::settings_get_str('punt_list'));
# Irssi::settings_set_str('punt_list', join(",", @puntlist));

    # This also deals with unpunting.
sub unroute_inst($$) {
  my ($witem,$inst) = @_;

  return if not inst_routed($witem,$inst);
  my $target = inst_route_target($witem,$inst);

  delete $$routes{$$witem{'_irssi'}}{$inst};

  if (scalar keys %{$$routes{$$witem{'_irssi'}}} == 0) { 
    delete $$routes{$$witem{'_irssi'}}
  }

  if (defined $target) {
    # Delete reverse map
    delete $$routes_invmap{$$target{'_irssi'}}{$inst};
  }
}

#################################################################

sub cmd_common_startup ($$) {
  my ($server, $witem) = @_;

  if (not defined $witem or $witem == 0) {
    Irssi::print("Can't run without a window item");
    return 0;
  }

  if (not defined $$witem{'name'}) {
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
  my ($args, $server, $witem) = @_;

  return if not cmd_common_startup($server,$witem);

  if ($args eq "") {
    delete $$instance_labels{$$server{'address'}}{$$witem{'name'}};
    $witem->print("No longer using a default instance tag.");
    return;
  }

  my ($inst, $msg) = split(/ /, $args, 2);

  my $enc = $hc->encode($inst);
  if (not defined $enc) {
    $witem->print("Can't set instance to '$inst'");
    return;
  }

  $$instance_labels{$$server{'address'}}{$$witem{'name'}} = $enc;

  $witem->print("Default instance is now '$inst'.");

  if (defined $msg && $msg ne "") {
    cmd_inst_say($args, $server, $witem);
  }
}
#Irssi::settings_set_str('current_instance', $_[0]);

sub cmd_punt {
  my ($inst, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);
  punt_inst($witem,$inst);
}

sub cmd_unpunt {
  my ($inst, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);
  unroute_inst($witem,$inst);
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

  $text =  generate_outgoing($text, $instenc) if "" ne $inst;

  $suppress_out = 1;
  Irssi::signal_emit("send text", $text, $server, $witem);
  $suppress_out = 0;
}

sub cmd_isplit {
  my ($args, $server, $witem) = @_;
  return if not cmd_common_startup($server,$witem);

  # TODO Create new window
  # TODO Bind as target
}

sub cmd_debug_routes {
  my ($args, $server, $witem) = @_;

  Irssi::print (Dumper($routes));
  Irssi::print (Dumper($routes_invmap));
}

#################################################################

Irssi::settings_set_str("ctcp_version_reply",
    'irssi v$J - running on $sysname $sysarch with '.$extended_version);

# TODO Hook window item remove

Irssi::signal_add_first('message public', 'inst_filter_in');
Irssi::signal_add_first('message own_public', 'inst_filter_in_own_public');
Irssi::signal_add_first('message private', 'inst_filter_in_private');
Irssi::signal_add_first('message own_private', 'inst_filter_in_own_private');
Irssi::signal_add_first('send text', 'inst_filter_out');
Irssi::command_bind('instance', 'cmd_instance');
Irssi::command_bind('instsay', 'cmd_inst_say');
Irssi::command_bind('punt', 'cmd_punt');
Irssi::command_bind('debugroutes', 'cmd_debug_routes');
Irssi::command_bind('unpunt', 'cmd_unpunt');

    # Set to recieve warnings about initial TLV streams
    # (older protocol)
Irssi::settings_add_bool('instance','instance_warn_initial', 1);
    # Set to recieve warnings about unknown TLV types
    # (newer protocols)
Irssi::settings_add_bool('instance','instance_warn_unknown', 1);

# The old way of storing these...
#Irssi::settings_add_str('lookandfeel', 'current_instance', "default");
#Irssi::settings_add_str('lookandfeel', 'punt_list', "");

# XXX :-(
#Irssi::statusbar_item_register('current_instance', undef, 'current_instance');
#Irssi::statusbars_recreate_items();
#Irssi::statusbar_items_redraw('current_instance');
    
#################################################################

Irssi::print($humorous_version);
