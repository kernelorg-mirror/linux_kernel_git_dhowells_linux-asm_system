#!/usr/bin/perl -w

use File::Find;
use File::Path;
use strict;

my @sys_header_dirs = (
    "include"
    );

#
# Changes must be committed first
#
system("git diff --quiet") == 0 or die "Uncommitted changes; aborting\n";

#
# Delete the old patch under StGIT
#
system("stg delete uapi-set-up-Kbuild");

#
# Set up the patch under StGIT
#
system("stg new -m '" .
       "UAPI: (Scripted) Set up UAPI Kbuild files\n" .
       "\n" .
       "Set up empty UAPI Kbuild files to be populated by the header splitter using\n" .
       "scripts/uapi-disintegrate/set-up-Kbuild.pl\n" .
       "' --sign uapi-set-up-Kbuild"
    ) == 0 or die;

#
# Find all the system header directories under arch
#
opendir DIR, "arch" or die;
push @sys_header_dirs,
    map { "arch/$_/include"; }
sort grep { -d "arch/$_/include"; }
grep { $_ !~ /^[.]/ }
readdir DIR;
closedir DIR;

#
# Find all the header files
#
my %kbuilds = ();
sub find_Kbuild()
{
    $kbuilds{$File::Find::name} = 1 if ($_ =~ /Kbuild$/);
}

find(\&find_Kbuild, @sys_header_dirs);

#print join("\n", sort keys %kbuilds), "\n";

foreach my $kbuild (sort grep { $_ !~ m@arch/um/@} keys %kbuilds) {

    my $uapi_kbuild = $kbuild;
    $uapi_kbuild =~ s@include/@include/uapi/@;

    print "[[[ $uapi_kbuild ]]]\n";

    open FD, '<', $kbuild or die "open $kbuild: $!\n";
    my @old = <FD>;
    close FD or die;

    my @new = ();

    if ($#old > -1) {
	if ($old[0] =~ /^#/) {
	    for (my $l = 0; $l <= $#old; $l++) {
		last if ($old[$l] !~ /^#/);
		push @new, $old[$l];
	    }
	    push @new, "\n";
	}

	push @new, map {
	    my $x = $_;
	    $x =~ s@include/@include/uapi/@;
	    $x;
	} grep { $_ =~ m@^include@; } @old;

	push @new, "\n" if ($#new > -1);

	push @new, grep { $_ =~ m@header-y\s+[+]=\s+[a-z0-9A-Z-]+/\s*@; } @old;
    }

    #print @new;

    my $uapidir = $uapi_kbuild;
    $uapidir = $1 if ($uapidir =~ m!(.*)/!);
    mkpath($uapidir) if (! -d $uapidir);

    open FD, '>', $uapi_kbuild or die "create $uapi_kbuild: $!\n";
    print FD "# UAPI Header export list\n" or die "write $uapi_kbuild: $!\n";
    print FD @new or die "write $uapi_kbuild: $!\n";
    close FD or die "close $uapi_kbuild: $!\n";
    system("stg add $uapi_kbuild") == 0 or die;
}

#
# Commit the changes
#
system("stg ref") == 0 or die;

exit 0;
