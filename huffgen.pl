use Data::Dumper;
$Data::Dumper::Indent = 0;

my $DEBUG = 1;
my $PROGRESS = 1;
my $NARY=5;

my %count;
my %icount;
my $totalcount = 0;

print STDERR "Consuming symbols...\n" if $PROGRESS;

while (<>) {
	chomp;
	foreach my $char (split //) {
		$count{$char}++;
		$totalcount++;

		print STDERR " Consumed $totalcount symbols...\r"
			if $PROGRESS and ($totalcount % 10000 == 0);
	}
}

print "\nRanking...\n" if $PROGRESS;

print STDERR Dumper(\%count)."\n" if $DEBUG;

foreach my $key (keys %count) {
	unshift @{$icount{$count{$key}}}, $key;
}

print "Filing...\n" if $PROGRESS;

print STDERR Dumper(\%icount)."\n" if $DEBUG;

my @initial;
foreach my $freq (sort { 0+$a <=> 0+$b } keys %icount) {
	foreach my $char (@{$icount{$freq}}) {
		push @initial, [$char, $freq];
	}
}

print STDERR Dumper(\@initial)."\n" if $DEBUG;

my @secondary = ();

sub grabnext {
	my ($inn, $inv) = @{$initial[0]} if exists $initial[0];
	my ($sen, $sev) = @{$secondary[0]} if exists $secondary[0];

	if (not defined $sev) {
		print STDERR "    Undef sev\n" if $DEBUG > 2;
		die if (not defined $inv);
		return shift @initial;
	} elsif (not defined $inv) {
		print STDERR "    Undef inv\n" if $DEBUG > 2;
		return shift @secondary;
	} else {
		if ($inv <= $sev) {
			print STDERR "    Inv wins\n" if $DEBUG > 2;
			return shift @initial;
		}
		print STDERR "    Sev wins\n" if $DEBUG > 2;
		return shift @secondary;
	}
}

sub numleft { return ((scalar @initial) + (scalar @secondary)) };

print "Forming Huffman tree...\n" if $PROGRESS;

while (numleft() > 1) {
	my $i = 0;
	my $cv = 0;
	my @cs = ();

    if ( numleft() < $NARY ) {
        warn "Incomplete toplevel tree with ",numleft()," nodes \n";
    }

	while ($i < $NARY and numleft() > 0) {
		my ($nn, $nv) = @{grabnext()};

		print STDERR "  Combined $nn\@$nv --- ".(numleft())."\n" if $DEBUG > 1;
		print STDERR Dumper(\@initial, \@secondary)."\n" if $DEBUG > 2;

		$cv += $nv;
		push @cs, $nn;

		$i++;
	}

	@cs = sort { length $a <=> length $b } @cs;
	my $cn = join "",@cs;

	print STDERR "GROUPING ($cn)\@$cv\n" if $DEBUG;

    if (length $cn == 5) {
        push @secondary, [" \"$cn\" ", $cv];
    } else {
	    push @secondary, [" [ $cn ] ", $cv];
    }
}

print @{$secondary[0]}[0]."\n";
