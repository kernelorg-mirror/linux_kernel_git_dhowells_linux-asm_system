#!/usr/bin/perl -w

use File::Find;

#
# We assume that only Kbuild files in include directories are pertinent to
# determining which headers are UAPI headers.
#
@kbuilds = ();
%headers = ();
sub find_Kbuild()
{
    push(@kbuilds, $File::Find::name) if ($_ eq "Kbuild");
    $headers{$File::Find::name} = 1 if ($_ =~ /[.]h$/ || $_ =~ /[.]agh$/);
}

find(\&find_Kbuild, "arch", "include");

# Read the common arch list
open FD, '<include/asm-generic/Kbuild.asm' or die "open Kbuild.asm: $!\n";
my @kbuild_asm = <FD>;
close FD or die;

my %uapihdrs = ();

foreach my $i (sort(grep { $_ !~ m@uapi/@ } @kbuilds)) {
    #print "[[[ $i ]]]\n";

    my $dir = $i;
    $dir =~ m@(^.*)/@, $dir = $1;

    open FD, '<', $i or die "open $i: $!\n";
    my @lines = <FD>;
    close FD or die;

    for (my $l = 0; $l <= $#lines; $l++) {
	my $line = $lines[$l];

	# parse out the blocks
	# - this may be split over multiple lines using backslashes
	my $block = $line;
      restart:
	$block =~ s@#.*$@@;
	$block =~ s@\s+$@@g;
	$block =~ s@\s+@ @g;

	if ($block =~ /^(.*)[\\]$/) {
	    $l++;
	    $block = $1 . $lines[$l];
	    goto restart;
	}

	$block =~ s@\s+$@@g;
	$block =~ s@\s\s+@ @g;

	if ($block =~ m@^include include/asm-generic/Kbuild.asm@) {
	    push @lines, @kbuild_asm;
	}

	if ($block =~ m@^header-y\s*[+:]?=\s*(.*)@ ||
	    $block =~ m@^opt-header\s*[+:]?=\s*(.*)@ ||
	    $block =~ m@^asm-headers\s*[+:]?=\s*(.*)@
	    ) {
	    foreach $h (map { "$dir/" . $_ } grep m@[^/]$@, split /\s+/, $1) {
		if (exists $headers{$h}) {
		    $uapihdrs{$h} = 1;
		}
	    }
	}
    }
}

if ($#ARGV == -1) {
    # no arguments: all listed header files
    print map { $_ . "\n"; } sort keys %uapihdrs;
} else {
    # any arguments: all unlisted header files
    print map { $_ . "\n"; } sort grep { !exists $uapihdrs{$_}; } keys %headers;
}
