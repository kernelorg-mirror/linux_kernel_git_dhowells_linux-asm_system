#!/usr/bin/perl -w

use File::Find;

#
# Changes must be committed first
#
system("git diff --quiet") == 0 or die "Uncommitted changes; aborting\n";

#
# Delete the old patch under StGIT
#
system("stg delete uapi-convert-drivers_gpu-includes");

#
# Set up the patch under StGIT
#
system("stg new -m '" .
       "UAPI: (Scripted) Convert #include \"...\" to #include <path/...> in drivers/gpu/\n" .
       "\n" .
       "Convert #include \"...\" to #include <path/...> in drivers/gpu/.\n" .
       "\n" .
       "scripts/uapi-disintegrate/drm-headers.pl was used\n" .
       "' --sign uapi-convert-drivers_gpu-includes"
    ) == 0 or die;

#
# Find all the .c and .h files under drivers/gpu/
#
%files = ();
sub find_file()
{
    $files{$File::Find::name} = 1 if ($_ =~ /[.][ch]$/);
}

find(\&find_file, "drivers/gpu");

#print join("\n", sort keys %files), "\n";

foreach my $file (sort keys %files) {
    my $dir = $file;
    $dir =~ m@(^.*/)@, $dir = $1;

    open FD, '<', $file or die "open $file: $!\n";
    my @lines = <FD>;
    close FD or die;

    my $printed_name = 0;
    my $alter_file = 0;

    for (my $l = 0; $l <= $#lines; $l++) {
	my $line = $lines[$l];

	if ($line =~ /^(#\s*include\s+)["]([^"]+)["](.*[\n])/) {
	    my $pre = $1;
	    my $name = $2;
	    my $post = $3;

	    # If the included file really is in this directory, then "..." is
	    # correct.
	    next if (-f $dir.$2);
	    next if ($name =~ /.*_reg_safe[.]h/);

	    if (!$printed_name) {
		print "[[[ \e[36m$file\e[m ]]]\n";
		$printed_name = 1;
	    }

	    my $path = "??";

	    if ($name =~ m@[.][.]@) {
		die;
	    } else {
		# Look in the system include paths for it
		if (-f "include/$name") {
		    $path = $name;
		} elsif (-f "include/drm/$name") {
		    $path = "drm/$name";
		} else {
		    print STDERR "Can't locate '$name' in sysinc paths\n";
		    $path = $name;
		}
	    }

	    print $file, ": ", $name, " -> ", $path, "\n";
	    $lines[$l] = $pre . "<" . $path . ">" . $post;
	    $alter_file = 1;
	}
	elsif ($line =~ /^(#\s*include\s+)[<]([^\/>]+)[>](.*[\n])/) {
	    my $pre = $1;
	    my $name = $2;
	    my $post = $3;

	    if (!$printed_name) {
		print "[[[ \e[36m$file\e[m ]]]\n";
		$printed_name = 1;
	    }

	    my $path = "??";

	    if ($name =~ m@[.][.]@) {
		die;
	    } else {
		# Look in the system include paths for it
		if (-f "include/drm/$name") {
		    $path = "drm/$name";
		} else {
		    print STDERR "Can't locate '$name' in sysinc paths\n";
		    $path = $name;
		}
	    }

	    print $file, ": ", $name, " -> ", $path, "\n";
	    $lines[$l] = $pre . "<" . $path . ">" . $post;
	    $alter_file = 1;
	}

    }

    if ($alter_file) {
	my $temp = $file . ".drminc";
	open FD, '>', $temp or die "create $temp: $!\n";
	print FD @lines or die "write $temp: $!\n";
	close FD or die "close $temp: $!\n";
	rename $temp, $file or die "move $temp -> $file: $!\n";
    }
}

#
# Commit the changes
#
system("stg ref") == 0 or die;

exit 0;
