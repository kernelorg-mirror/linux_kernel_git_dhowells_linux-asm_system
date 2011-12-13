#!/usr/bin/perl -w
#
# Perform header disintegration of the user API, producing commits on a
# dir-by-dir basis to GIT
#

use strict;
use File::Basename;

my $main_branch = "uapi-split";

my $UAPI = "uapi";

$ENV{UAPI} = "uapi";

my $execdir = dirname($0);

sub commit($@) {
    my ($dirname, @files) = @_;

    system("git commit -m 'UAPI: (Scripted) Disintegrate $dirname\n\nSigned-off-by: David Howells <dhowells\@redhat.com>\n' " . join(" ", @files)) == 0 or die;
}

###############################################################################
#
#
#
###############################################################################
system("git checkout $main_branch") == 0 or die;

my $curdir = "xxxxx";

my @headerlist = sort {
    dirname($a) cmp dirname($b) || $a cmp $b;
} `$execdir/genlist.pl`;

my @files = ();
foreach my $origfile (@headerlist) {
    chomp $origfile;
    if (! -f $origfile) {
	print "Skip $origfile\n";
	next;
    }

    my $odir = dirname($origfile);

    if ($odir ne $curdir) {
	print "[]";

	commit($curdir, @files) unless ($curdir eq "xxxxx");
	$curdir = $odir;
	@files = ();
    }

    print "$origfile\n";
    my $uapifile = $origfile;
    $uapifile =~ s@include/@include/$UAPI/@;
    my $udir = dirname($uapifile);

    system("$execdir/disintegrate-one.pl $origfile $uapifile") == 0 or die;

    if (-r $uapifile) {
	push @files, $uapifile;
	system("git add $uapifile") == 0 or die;
    }
    push @files, "$udir/Kbuild", $origfile, "$odir/Kbuild";
}

commit($curdir, @files) unless ($curdir eq "xxxxx");
