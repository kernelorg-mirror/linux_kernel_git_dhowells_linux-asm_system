#!/usr/bin/perl -w
#
# Perform header disintegration of the user API, producing commits on a
# dir-by-dir basis to StGIT
#

use strict;
use File::Basename;

my $UAPI = "uapi";

$ENV{UAPI} = "uapi";

my $execdir = dirname($0);

sub new_patch($$) {
    my ($dirname, $patchname) = @_;

    system("stg new $patchname -m 'UAPI: (Scripted) Disintegrate $dirname' --sign") == 0 or die;
}

#
# Changes must be committed first
#
system("git diff --quiet") == 0 or die "Uncommitted changes; aborting\n";

###############################################################################
#
#
#
###############################################################################
if (system("stg id begin-marker") == 0) {
    system("stg del begin-marker..") == 0 or die;
}

system("stg new begin-marker -m \"Begin userspace API extraction\"") == 0 or die;

###############################################################################
#
#
#
###############################################################################
my $curdir = "xxxxx";

my @headerlist = sort {
    dirname($a) cmp dirname($b) || $a cmp $b;
} `$execdir/genlist.pl`;

foreach my $origfile (@headerlist) {
    chomp $origfile;
    if (! -f $origfile) {
	print "Skip $origfile\n";
	next;
    }

    my $odir = dirname($origfile);
    if ($odir ne $curdir) {
	unless ($curdir eq "xxxxx") {
	    system("stg ref") == 0 or die;
	}
	$curdir = $odir;

	print "[$curdir]\n";

	my $patchname = $curdir;
	$patchname =~ s@/@__@g;

	new_patch($curdir, "uapi-dis-" . $patchname);
    }

    print "$origfile\n";
    my $uapifile = $origfile;
    $uapifile =~ s@include/@include/$UAPI/@;
    my $udir = dirname($uapifile);

    system("$execdir/disintegrate-one.pl $origfile $uapifile") == 0 or die;

    if (-r $uapifile) {
	system("stg add $uapifile") == 0 or die;
    }
}

unless ($curdir eq "xxxxx") {
    system("stg ref") == 0 or die;
}
