#!/usr/bin/perl -w

use strict;
use File::Basename;

my $main_branch = "uapi-split";

my $UAPI = "uapi";

$ENV{UAPI} = "uapi";

my $execdir = dirname($0);

###############################################################################
#
#
#
###############################################################################
system("git checkout $main_branch") == 0 or die;

my $curdir = "xxxxx";
my %branches = ();

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
	print "[]";
	my $br = $odir;
	$br =~ s@[/-]@__@g;

	system("git checkout $main_branch") == 0 or die;
	if (! exists($branches{$br})) {
	    system("git branch $br") == 0 or die;
	    $branches{$br} = 1;
	}
	system("git checkout $br") == 0 or die;
	$curdir = $odir;
    }

    print "$origfile\n";
    my $uapifile = $origfile;
    $uapifile =~ s@include/include/@$UAPI/@;
    my $udir = dirname($uapifile);

    system("$execdir/disintegrate-one.pl $origfile $uapifile") == 0 or die;

    my @files = ();
    if (-r $uapifile) {
	push @files, $uapifile;
	system("git add $uapifile") == 0 or die;
    }
    push @files, "$udir/Kbuild", $origfile, "$odir/Kbuild";

    system("git commit -m 'UAPI: Disintegrate $origfile\n\nSigned-off-by: David Howells <dhowells\@redhat.com>\n' " . join(" ", @files)) == 0 or die;
}

system("git checkout $main_branch") == 0 or die;
system("git merge " . join(" ", keys %branches)) == 0 or die;
system("git branch -d " . join(" ", keys %branches)) == 0 or die;
