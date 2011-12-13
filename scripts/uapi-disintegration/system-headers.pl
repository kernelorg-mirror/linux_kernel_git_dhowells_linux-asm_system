#!/usr/bin/perl -w

use File::Find;

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
system("stg delete uapi-convert-include-quote-to-angle");

#
# Set up the patch under StGIT
#
system("stg new -m '" .
       "UAPI: (Scripted) Convert #include \"...\" to #include <path/...> in kernel system headers\n" .
       "\n" .
       "Convert #include \"...\" to #include <path/...> in kernel system headers.\n" .
       "\n" .
       "scripts/uapi-disintegrate/system-headers.pl was used\n" .
       "' --sign uapi-convert-include-quote-to-angle"
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
%headers = ();
sub find_header()
{
    $headers{$File::Find::name} = 1 if ($_ =~ /[.]h$/);
}

find(\&find_header, @sys_header_dirs);

#print join("\n", sort keys %headers), "\n";

foreach my $hdr (sort grep { $_ !~ m@arch/um/@} keys %headers) {
    my $dir = $hdr;
    $dir =~ m@(^.*/)@, $dir = $1;

    open FD, '<', $hdr or die "open $hdr: $!\n";
    my @lines = <FD>;
    close FD or die;

    my $printed_name = 0;
    my $alter_header = 0;

    for (my $l = 0; $l <= $#lines; $l++) {
	my $line = $lines[$l];

	if ($line =~ /^(#\s*include\s+)["]([^"]+)["](.*[\n])/) {
	    #print $1, '@', $2, '@', $3;

	    if (!$printed_name) {
		#print "[[[ $hdr [\e[36m$dir\e[m] ]]]\n";
		$printed_name = 1;
	    }

	    my $pre = $1;
	    my $name = $2;
	    my $post = $3;

	    my $inc = undef;
	    my $base = "??";
	    my $path = "??";
	    my $realpath = "??";
	    my $do_existence_check = 1;

	    if ($name eq "platform/acenv.h") {
		# ACPI includes this relative to the current dir
		$inc = $dir . $name;
	    } elsif ($name =~ m@^[a-z].*/@) {
		# We found something like "linux/foo.h" so just accept as is
		$base = "";
		$realpath = $path = $name;
		$do_existence_check = 0;
		goto no_disassemble;
	    } elsif ($name =~ m@^[.][.]/@) {
		# We found something like "../foo.h" so we jam the dir on the
		# front and then remove "dir/.." pairs
		$inc = $dir . $name;
		while ($inc =~ m@[^/]*/[.][.]/@) {
		    $inc =~ s@[^/]*/[.][.]/@@;
		}
	    } elsif ($name !~ m@/@) {
		# We found something like "foo.h" so we again stick the dir on
		# the front and then cut off the "include/" prefix.
		if ($name =~ m@^drm_@) {
		    # Unless it's a DRM header - the drm stuff adds
		    # -Iinclude/drm to the build flags rather than use
		    # <drm/foo.h> for some reason
		    $inc = "include/drm/$name";
		} else {
		    $inc = $dir . $name;
		}
	    } else {
		die "Don't handle \"$name\"\n";
	    }

	    $inc =~ m@(.*include/)(.*/[^/]*)@, $base = $1, $path = $2;

	    $realpath = $path;
	    if ($dir =~ m@^arch/cris/@ && $path =~ m@^arch-v[0-9]+/(arch/.*)@) {
		$realpath = $1;
	    } elsif ($dir =~ m@^arch/sh/@ && $path =~ m@^mach-[^/]+/(mach/.*)@) {
		$realpath = $1;
	    }

	  no_disassemble:
	    print $hdr, ": ", $name, " -> \e[36m", $base, "\e[m", $path;

	    if ($do_existence_check && ! -f $inc) {
		if (($hdr eq "arch/powerpc/include/asm/bootx.h" && $name eq "linux_type_defs.h") ||
		    ($hdr eq "include/acpi/platform/acenv.h" && $name =~ /ac[a-z]*[0-9]*[.]h/) ||
		    ($hdr eq "include/linux/jbd.h" && $name eq "jfs_compat.h") ||
		    ($hdr eq "include/linux/jbd2.h" && $name eq "jfs_compat.h") ||
		    ($hdr eq "include/video/cvisionppc.h" && $name eq "pm2fb.h") ||
		    ($hdr eq "include/drm/via_drm.h" && $name eq "via_drmclient.h")
		    ) {
		    print " \e[33mnot present\e[m\n";
		} else {
		    print " \e[31mnot found\e[m\n";
		    die;
		}
	    } else {
		$lines[$l] = $pre . "<" . $realpath . ">" . $post;
		$alter_header = 1;
		print "\n";
	    }
	}
    }

    if ($alter_header) {
	my $temp = $hdr . ".syshdr";
	open FD, '>', $temp or die "create $temp: $!\n";
	print FD @lines or die "write $temp: $!\n";
	close FD or die "close $temp: $!\n";
	rename $temp, $hdr or die "move $temp -> $hdr: $!\n";
    }
}

#
# Commit the changes
#
system("stg ref") == 0 or die;

exit 0;
