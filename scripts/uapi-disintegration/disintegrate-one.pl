#!/usr/bin/perl -w
#
# Disintegrate a file to extract out the userspace API bits into their own file
# in a separate directory.  The original file retains the residue.
#
# The original file is given a #include to refer to the UAPI file, and both
# headers will get guards, unless one of them is simply turned into a
# #include.
#
# Call as: disintegrate-one.pl <orig_header_file> <uapi_header_file>
#

use File::Path;
use strict;

sub reduce_file(@);

# Don't put a "don't include this in asm" notice in the following files
my %asm_includeable_linux_files = (
    "include/linux/const.h"		=> 1,
    "include/linux/elf-em.h"		=> 1,
    "include/linux/errno.h"		=> 1,
    "include/linux/serial_reg.h"	=> 1,
    );

die if ($#ARGV != 1);
my $linuxhdr = $ARGV[0];
my $uapihdr = $ARGV[1];

#
# The UAPI header file is called the same as the Linux header file as far as
# cpp is concerned - the latter just #include's the former, and if the latter
# doesn't exist, the former is used directly.
#
my $inchdr = $linuxhdr;
$inchdr =~ s@.*include/@@;

#
# Read the entire Linux header file into an array of lines.
#
open(FD, '<', $linuxhdr) or die $linuxhdr, ": $!\n";
my @lines = <FD> or die $linuxhdr, ": $!\n";
close(FD) or die $linuxhdr, ": $!\n";

my @kernellines = ();
my @uapilines = ();

#
# If the entire file is just a single #include, then don't change it
#
# We do want to create the API file _if_ the included file is an API file
#
if ($#lines == 0 && $lines[0] =~ /^#\s*include\s+<([^>]+)>/) {
    @kernellines = "#include <uapi/$1>\n";
    @uapilines = @lines;
    goto output;
}

goto output if ($#lines == -1);

#
# Attempt to disintegrate the file
# - The initial banner comment gets duplicated if there is one
# - The reinclusion guard is duplicated and modified for the API file
# - non-__KERNEL__ lines get put into the API file
#

my $nr_blocks = 0;
sub new_block($$$$)
{
    my ($type, $l, $parent, $prev) = @_;
    my %block = (
	type		=> $type,	# n = normal block, c = conditional block
	l		=> $l + 1,
	next_block	=> undef,
	prev_block	=> $prev,
	nr		=> ++$nr_blocks,
	parent		=> $parent,
    );
    $block{lines} = [] if ($type eq "n");
    $block{kernel_mark} = 0 if ($type ne "n");
    $prev->{next_block} = \%block if ($prev);
    return \%block;
}

#
# First of all, build a tree of normal blocks and conditionals
#
my $first_block = new_block("n", 0, undef, undef);
my $conditional_tree = $first_block;
my $cur_body = $first_block;
my $specified_include_point = 0;

my @conditional_stack = ();
my @body_stack = ( $first_block );

my $l = 0;

if ($lines[$l] =~ m@^/[*]@) {
    my @buffer = ();
    for (; $l <= $#lines; $l++) {
	if ($lines[$l] =~ "(.*)[*]/(.*)") {
	    push @buffer, "$1*/\n";
	    $lines[$l] = $2;
	    $l++;
	    goto got_banner_comment;
	}
	push @buffer, $lines[$l];
    }
  got_banner_comment:
    $first_block->{lines} = \@buffer;
    $first_block->{banner} = 1;
    $first_block->{next_block} = new_block("n", $l, undef, $first_block);
    $cur_body = $first_block->{next_block};
    $body_stack[0] = $cur_body;
}

for (; $l <= $#lines; $l++) {
    my $line = $lines[$l];
    my @buffer = ( $line );

    # parse out the actual CPP directive
    # - this may be split over multiple lines using backslashes and comments
    #   that have embedded newlines
    my $cpp = $line;
  restart:
    $cpp =~ s@\s+$@@g;
    $cpp =~ s@\s+@ @g;

    while ($cpp =~ m@(/[*])@) {
	my $o = index($cpp, "/*");
	if ($cpp =~ m@([*]/)@) {
	    my $c = index($cpp, "*/") + 2;
	    substr($cpp, $o, $c - $o) = "";
	} else {
	    $l++;
	    $cpp .= $lines[$l];
	    push @buffer, $lines[$l];
	    goto restart;
	}
    }

    if ($cpp =~ /^(.*)[\\]$/) {
	$l++;
	$cpp = $1 . $lines[$l];
	push @buffer, $lines[$l];
	goto restart;
    }

    $cpp =~ s@\s+$@@g;
    $cpp =~ s@\s\s+@ @g;

    if ($cpp eq "// DISINTEGRATE: INCLUDE UAPI HERE") {
	die if ($specified_include_point);

	my $marker;
	if ($#{$cur_body->{lines}} == -1) {
	    $marker = $cur_body;
	    $marker->{type} = "i";
	    $marker->{include_point} = undef;
	    delete $marker->{lines};
	} else {
	    my $marker = new_block("i", $l, $cur_body->{parent}, $cur_body);
	    $cur_body = $marker;
	    $body_stack[$#body_stack] = $marker;
	}
	die if ($marker->{lines});

	my $body_block = new_block("n", $l + 1, $cur_body->{parent}, $cur_body);
	$body_stack[$#body_stack] = $body_block;
	$cur_body = $body_block;
	$specified_include_point = 1;
	next;
    }

    my $retain_next = 0;
    if ($line =~ "(.*) // DISINTEGRATE: RETAIN\n") {
	$line = "$1\n";
	$retain_next = 1;
    }

    if ($line =~ /^#/) {
	#print "r:\e[36m", $cpp, "\e[m@@@ $l\n";

	# handle conditional macros
	if ($cpp =~ /^#\s*if/) {
	    #print "#if ", $#conditional_stack + 1, ": ", $#body_stack + 1, "\n";
	    my $cond_block = new_block("c", $l, $cur_body->{parent}, $cur_body);
	    $cond_block->{clauses} = [];	# #if..#elif..#elif..#else..#endif
	    $cond_block->{retain} = 1 if ($retain_next == 1);
	    push @conditional_stack, $cond_block;

	    my $clause = new_block("if", $l, $cond_block, undef);
	    $clause->{cpp} = $cpp;
	    push @{$clause->{lines}}, @buffer;
	    push @{$cond_block->{clauses}}, $clause;

	    my $body_block = new_block("n", $l + 1, $clause, undef);
	    $clause->{body} = $body_block;

	    $cur_body->{next_block} = $cond_block;
	    $body_stack[$#body_stack] = $cond_block;
	    push @body_stack, $body_block;

	    $cur_body = $body_block;

	    die ("Unexpected body types '",
		 join("", map {$_->{type};} @body_stack),
		 "' after #if\n")
		if ($body_stack[$#body_stack]->{type} ne "n" ||
		    $body_stack[$#body_stack - 1]->{type} ne "c");

	    if ($#conditional_stack == 0 &&
		$cpp =~ /^#\s*ifndef\s+([_A-Za-z0-9]+)/) {
		# keep an eye open for a guard's #define or an include-order check's #error
		my $macro = $1;
		$cur_body->{check_first_line} = $macro
		    if ($macro ne "__KERNEL__" && $macro !~ /^CONFIG_/);
	    }
	    next;
	}

	my $cond_block = $conditional_stack[$#conditional_stack];
	my $cur_clause = $cond_block->{clauses}->[$#{$cond_block->{clauses}}];

	if ($cpp =~ /^#\s*elif/) {
	    die if ($#conditional_stack < 0);
	    die if (exists $cond_block->{has_else});

	    my $clause = new_block("elif", $l, $cond_block, $cur_clause);
	    $clause->{cpp} = $cpp;
	    push @{$clause->{lines}}, @buffer;
	    push @{$cond_block->{clauses}}, $clause;

	    my $body_block = new_block("n", $l + 1, $clause, undef);
	    $clause->{body} = $body_block;

	    $body_stack[$#body_stack] = $body_block;
	    $cur_body = $body_block;
	    next;
	}

	if ($cpp =~ /^#\s*else/) {
	    #print "#else ", $#conditional_stack + 1, ": ", $#body_stack + 1, "\n";
	    die if ($#conditional_stack < 0);
	    die if (exists $cond_block->{has_else});
	    $cond_block->{has_else} = 1;

	    my $clause = new_block("else", $l, $cond_block, $cur_clause);
	    push @{$clause->{lines}}, @buffer;
	    push @{$cond_block->{clauses}}, $clause;

	    my $body_block = new_block("n", $l + 1, $clause, undef);
	    $clause->{body} = $body_block;

	    $body_stack[$#body_stack] = $body_block;
	    $cur_body = $body_block;
	    next;
	}

	if ($cpp =~ /^#\s*endif/) {
	    #print "#endif ", $#conditional_stack + 1, ": ", $#body_stack + 1, "\n";
	    die if ($#conditional_stack < 0);

	    my $clause = new_block("endif", $l, $cond_block, $cur_clause);
	    push @{$clause->{lines}}, @buffer;
	    push @{$cond_block->{clauses}}, $clause;

	    pop @conditional_stack;
	    pop @body_stack;
	    $cur_body = $body_stack[$#body_stack];

	    my $body_block = new_block("n", $l + 1, $cur_body->{parent}, $cur_body);

	    die "Unexpected body type '", $cur_body->{type}, "' at #endif\n"
		if ($cur_body->{type} ne "c");

	    $body_stack[$#body_stack] = $body_block;
	    $cur_body = $body_block;
	    next;
	}

	if (($cpp =~ /^#\s*define\s+([_A-Za-z0-9]+)$/ ||
	     $cpp =~ /^#\s*define\s+([_A-Za-z0-9]+)\s+1$/) &&
	    exists $cur_body->{check_first_line}
	    ) {
	    my $macro = $1;
	    #print "GUARD $macro\n";
	    if ($macro eq $cur_body->{check_first_line}) {
		$cond_block->{guard_label} = $cur_body->{check_first_line};
		$cur_clause->{guard} = \@buffer;
		delete $cur_body->{check_first_line};
		next;
	    }
	}

	if ($cpp =~ /^#\s*error/ &&
	    exists $cur_body->{check_first_line}
	    ) {
	    delete $cur_body->{check_first_line};
	    $cur_clause->{order_check} = \@buffer;
	    next;
	}
    }

    delete $cur_body->{check_first_line} if (exists $cur_body->{check_first_line});
    push @{$cur_body->{lines}}, @buffer;
}

die "Conditional level mismatch (", $#conditional_stack, ")\n"
    if ($#conditional_stack != -1);
die "Body level mismatch (", $#body_stack, ")\n"
    if ($#body_stack != 0);

###############################################################################
#
# Dump the parse tree
#
###############################################################################
sub dump_tree(@);
sub dump_tree(@)
{
    my $root = $#_ >= 0 ? $_[0] : $first_block;
    my $level = $#_ >= 1 ? $_[1] : 0;

    for (my $block = $root; $block; $block = $block->{next_block}) {
	my $l = $block->{l};
	my $nr = $block->{nr};
	my $lines = $block->{lines};
	print " " x $level;
	if ($block->{type} eq "n") {
	    if ($#{$lines} < 0) {
		print '- Empty (line ', $l, " nr ", $nr, ")\n";
	    } elsif ($#{$lines} == 0) {
		print '- Body (line ', $l, " nr ", $nr, ")\n";
	    } else {
		print '- Body (lines ', $l, "-", $l + $#{$lines} + 1, " nr ", $nr, ")";
		print " BANNER" if (exists $block->{banner});
		print "\n";
	    }
	    #print map {"\t\t\t>" . $_; } @{$block->{lines}} if (exists $block->{lines});
	} elsif ($block->{type} eq "i") {
		print '- UAPI Inclusion (line ', $l, " nr ", $nr, ")\n";
	} elsif ($block->{type} eq "c") {
	    my $clauses = $block->{clauses};
	    die "Must be at least 2 clauses\n" if ($#{$clauses} < 1);
	    print '@ Cond (line ', $l, " nr ", $nr, ") ", $#{$clauses}, " clauses";
	    if (exists $block->{kernel_mark}) {
		print " KO" if ($block->{kernel_mark} & 1);
		print " UO" if ($block->{kernel_mark} & 2);
		print " IK" if ($block->{kernel_mark} & 4);
		print " IU" if ($block->{kernel_mark} & 8);
		print " GUARD" if (exists $block->{guard});
		print " ORDER_CHECK" if (exists $block->{order_check});
		print " RETAIN" if (exists $block->{retain});
	    }
	    print "\n";
	    foreach my $clause (@{$clauses}) {
		my $nr = $clause->{nr};
		print " " x ($level + 1);
		print "#", $clause->{type}, " nr ", $nr;
		if (exists $clause->{kernel_mark}) {
		    print " KO" if ($clause->{kernel_mark} & 1);
		    print " UO" if ($clause->{kernel_mark} & 2);
		    print " IK" if ($clause->{kernel_mark} & 4);
		    print " IU" if ($clause->{kernel_mark} & 8);
		}
		print "\n";
		#print map {"\t\t\t>" . $_; } @{$clause->{lines}} if (exists $clause->{lines});
		dump_tree($clause->{body}, $level + 2);
	    }
	} else {
	    die;
	}
    }
}

###############################################################################
#
# Validate the parse tree structure
#
###############################################################################
sub validate_tree(@);
sub validate_tree(@)
{
    my ($parent, $body) = @_;

    if ($#_ == -1) {
	$parent = undef;
	$body = $first_block;
    }

    my $previous = undef;

    #print "-->validate_tree(", $parent ? $parent->{nr} : "-", ",", $body->{nr}, ")\n";

    for (my $block = $body; $block; $previous = $block, $block = $block->{next_block}) {
	my $nr = $block->{nr};

	die $nr, ": Unset parent\n" unless (exists $block->{parent});
	if (!$parent) {
	    die $nr, ": Unexpected parent\n" if ($block->{parent});
	} else {
	    die $nr, ": Missing parent\n" if (!$block->{parent});
	    die $nr, ": Incorrect parent", $block->{parent}->{nr}, "!=", $parent->{nr}, "\n"
		unless ($block->{parent} == $parent);
	}

	if ($previous) {
	    die($nr, ": Incorrect prev_block ",  $block->{prev_block}->{nr},
		" not ", $previous->{nr}, "\n")
		unless ($block->{prev_block} == $previous);
	} else {
	    die $nr, ": Unexpected prev_block ", $block->{prev_block}->{nr}, "\n"
		if ($block->{prev_block});
	}


	if ($block->{type} eq "n") {
	    die $nr, ": Missing line array\n" unless (exists $block->{lines});
	    die $nr, ": Unexpected __KERNEL__ mark\n" if (exists $block->{kernel_mark});
	    die $nr, ": Unexpected guard\n" if (exists $block->{guard});
	    die $nr, ": Unexpected order check\n" if (exists $block->{order_check});

	} elsif ($block->{type} eq "i") {
	    die $nr, ": Unexpected line array\n" if (exists $block->{lines});
	    die $nr, ": Unexpected guard\n" if (exists $block->{guard});
	    die $nr, ": Unexpected order check\n" if (exists $block->{order_check});

	} elsif ($block->{type} eq "c") {
	    die $nr, ": Unexpected line array\n" if (exists $block->{lines});
	    die $nr, ": Missing clause array\n" unless (exists $block->{clauses});

	    my $clauses = $block->{clauses};
	    my $nc = $#{$clauses};
	    die $nr, ": Must be at least 2 clauses\n" if ($nc < 1);

	    die $nr, ": Missing #if clause\n" if ($clauses->[0]->{type} ne "if");
	    die $nr, ": Missing #endif clause\n" if ($clauses->[$nc]->{type} ne "endif");
	    if ($nc >= 2) {
		for (my $i = 1; $i < $nc - 1; $i++) {
		    my $j = $clauses->[$i]->{nr};
		    die $nr, ": Missing #elif clause [$j]\n"
			if ($clauses->[$i]->{type} ne "elif");
		}

		my $j = $clauses->[$nc - 1]->{nr};
		die $nr, ": Missing #elif/#else clause [$j]\n"
		    if ($clauses->[$nc - 1]->{type} ne "elif" &&
			$clauses->[$nc - 1]->{type} ne "else");
	    }

	    foreach my $clause (@{$clauses}) {
		my $j = $clause->{nr};

		die "$j: Clause missing parent\n" unless ($clause->{parent});
		die "$j: Clause has wrong parent: ", $clause->{parent}->{nr}, "\n"
		    unless ($clause->{parent} == $block);
		die "$j: Unexpected body in #endif: ", $clause->{body}->{nr}, "\n"
		    if ($clause->{type} eq "endif" && exists $clause->{body});
		die "$j: Missing clause line array\n" unless (exists $clause->{lines});

		validate_tree($clause, $clause->{body}) if (exists $clause->{body});
	    }
	} else {
	    die "$nr: Invalid block type: '", $block->{type}, "'\n";
	}
    }

    #print "<--validate_tree()\n";
}

validate_tree();
#dump_tree(); exit 123;

###############################################################################
#
# Eliminate empty bodies from the tree
#
###############################################################################
sub discard_empties($);
sub discard_empties($)
{
    my ($block) = @_;

    while ($block) {
	die unless exists $block->{type};
	if ($block->{type} eq "n") {
	    if ($#{$block->{lines}} < 0) {
		#print "EMPTY: ", $block->{nr};
		my $parent = $block->{parent};
		my $prev = $block->{prev_block};
		my $next = $block->{next_block};
		delete $block->{type};

		if ($next) {
		    #print " next";
		    die if ($next->{prev_block} != $block);
		    $next->{prev_block} = $prev;
		}

		if ($prev) {
		    #print " prev";
		    die if ($prev->{next_block} != $block);
		    $prev->{next_block} = $next;
		} else {
		    if ($parent) {
			#print " parent(", $parent->{nr}, ")";
			die unless ($parent->{body} == $block);
			$parent->{body} = $next;
		    } else {
			#print " root";
			die "Mismatch ", $first_block->{nr}, " != ", $block->{nr}, "\n"
			    if ($first_block != $block);
			$first_block = $next;
		    }
		}
		die if ($next && $block == $next);
		$block = $next;
		#print "\n";
		next;
	    } else {
		$block = $block->{next_block};
		next;
	    }
	} elsif ($block->{type} eq "i") {
	    ;
	} elsif ($block->{type} eq "c") {
	    my $clauses = $block->{clauses};
	    die "Must be at least 2 clauses\n" if ($#{$clauses} < 1);
	    foreach my $clause (@{$clauses}) {
		discard_empties($clause->{body});
	    }
	} else {
	    die;
	}

	$block = $block->{next_block};
	next;
    }
}

discard_empties($first_block);
validate_tree();

###############################################################################
#
# Mark up single variable only __KERNEL__ conditions and percolate marks up the
# tree.
#
###############################################################################
sub mark__KERNEL__($);
sub mark__KERNEL__($)
{
    my ($first) = @_;
    my $combined_kernel_mark = 0;

    for (my $block = $_[0]; $block; $block = $block->{next_block}) {
	next if ($block->{type} ne "c");

	my $clauses = $block->{clauses};
	my $cpp = $clauses->[0]->{cpp};

	my $kernel_mark = 0;

	if ($block->{retain}) {
	    ;
	} elsif ($cpp =~ /^#\s*ifdef\s+__KERNEL__/ ||
	    ($cpp =~ /^#\s*if\s+defined\s*\(\s*__KERNEL__\s*\)/ &&
	     $cpp !~ /[|][|]|[&][&]/)) {
	    $kernel_mark |= 1 | 4;
	} elsif ($cpp =~ /^#\s*ifndef\s+__KERNEL__/ ||
		 ($cpp =~ /^#\s*if\s+!\s*defined\s*\(\s*__KERNEL__\s*\)/ &&
		  $cpp !~ /[|][|]|[&][&]/)) {
	    $kernel_mark |= 2 | 8;
	}

	if ($kernel_mark) {
	    $clauses->[0]->{kernel_mark} = $kernel_mark;
	    if ($#{$clauses} > 1) {
		die $linuxhdr, ":", $clauses->[1]->{l}, ": __KERNEL__ guard has #elif clause\n"
		    if ($#{$clauses} > 2 || $clauses->[1]->{type} eq "elif");
		$clauses->[1]->{kernel_mark} = $kernel_mark ^ 15;
		$kernel_mark = 15;
		$clauses->[2]->{kernel_mark} = $kernel_mark;
	    } else {
		$clauses->[1]->{kernel_mark} = $kernel_mark;
	    }
	}

	foreach my $clause (@{$clauses}) {
	    die $linuxhdr, ":", $clause->{l}, ": #elif contains __KERNEL__\n"
		if ($clause->{type} eq "elif" && $clause->{cpp} =~ /__KERNEL__/);

	    if (exists $clause->{body}) {
		my $k = mark__KERNEL__($clause->{body});
		if ($k) {
		    die $linuxhdr, ":", $clause->{l}, ": Body contains nested __KERNEL__\n"
			if ($kernel_mark & 3);
		    $clause->{kernel_mark} |= $k | 8;
		    $kernel_mark = $k | 8;
		}
	    }
	}

	$block->{kernel_mark} = $kernel_mark;

	$combined_kernel_mark |= $kernel_mark;
    }

    return $combined_kernel_mark & (4 | 8);
}

mark__KERNEL__($first_block);
validate_tree();
#dump_tree(); exit 123;

###############################################################################
#
# Determine reinclusion guards and validate inclusion order checks that are
# outside the guards
#
###############################################################################
sub determine_guards()
{
    for (my $block = $first_block; $block; $block = $block->{next_block}) {
	next if ($block->{type} ne "c");

	if ($block->{clauses}->[0]->{guard}) {
	    $block->{guard} = 1;
	    $block->{kernel_mark} = 8;
	    die unless (exists $block->{guard_label});
	} elsif ($block->{clauses}->[0]->{order_check}) {
	    $block->{order_check} = 1;
	    $block->{kernel_mark} = 8;
	    die $linuxhdr, ":", $block->{l}, ": Inclusion order check with multiple clauses\n"
		unless ($#{$block->{clauses}} == 1);
	    die $linuxhdr, ":", $block->{l}, ": Inclusion order check with extra body\n"
		if ($block->{clauses}->[0]->{body});
	}
    }
}

determine_guards();
#dump_tree();
validate_tree();

###############################################################################
#
# Render the two header files
#
###############################################################################
my $include_uapi_at = -1;

sub render(@);
sub render(@)
{
    my $root = $#_ >= 0 ? $_[0] : $first_block;
    my $parent_kernel_mark = $#_ >= 1 ? $_[1] : 8;

    for (my $block = $root; $block; $block = $block->{next_block}) {
	my $kernel_mark = $parent_kernel_mark;

	#push @kernellines, "KM$kernel_mark\n";

	if ($block->{type} eq "n") {
	    my $is_banner = exists $block->{banner};
	    my $lines = $block->{lines};
	    push @kernellines, @{$lines} if ($is_banner || !($kernel_mark & 8));
	    push @uapilines, @{$lines} if ($is_banner || $kernel_mark & 8);
	    next;
	}

	if ($block->{type} eq "i") {
	    push @kernellines, "#include <uapi/$inchdr>\n";
	    next;
	}

	if ($block->{type} eq "c") {
	    my $clauses = $block->{clauses};

	    if ($block->{order_check}) {
		push(@uapilines,
		     @{$clauses->[0]->{lines}},
		     @{$clauses->[0]->{order_check}},
		     @{$clauses->[1]->{lines}});
		next;
	    }

	    if ($block->{guard}) {
		push(@kernellines,
		     @{$clauses->[0]->{lines}},
		     @{$clauses->[0]->{guard}});
		push @kernellines, "\n";

		#if ($linuxhdr =~ m!^include/! &&
		#    $linuxhdr !~ m@^include/asm-generic/@ &&
		#    !exists($asm_includeable_linux_files{$linuxhdr})) {
		#    push @kernellines, "#ifdef __ASSEMBLY__\n";
		#    push @kernellines, "#error include/linux headers may not be included in .S files\n";
		#    push @kernellines, "#endif\n";
		#    push @kernellines, "\n";
		#}

		push @kernellines, "#define __EXPORTED_HEADERS__\n"
		    if ($linuxhdr eq "include/linux/types.h");

		unless ($specified_include_point) {
		    push @kernellines, "#include <uapi/$inchdr>\n";
		    $include_uapi_at = $#kernellines;
		    push @kernellines, "\n";
		}

		push(@uapilines,
		     "#ifndef _UAPI" . $block->{guard_label} . "\n",
		     "#define _UAPI" . $block->{guard_label} . "\n");

		render($block->{clauses}->[0]->{body}, $kernel_mark);
		push(@kernellines,
		     @{$clauses->[1]->{lines}});
		push(@uapilines,
		     "#endif /* _UAPI" . $block->{guard_label} . " */\n");
		next;
	    }

	    $kernel_mark = $block->{kernel_mark} if ($block->{kernel_mark});

	    if (($kernel_mark & 3) == 0) {
		# no mention of __KERNEL__ only
		foreach my $clause (@{$clauses}) {
		    my $lines = $clause->{lines};

		    push @kernellines, @{$clause->{lines}} if ($kernel_mark & 4);
		    push @uapilines, @{$clause->{lines}} if ($kernel_mark & 8);
		    render($clause->{body}, $kernel_mark)
			if (exists $clause->{body});
		}
	    } elsif (($kernel_mark & 3) == 1) {
		# #ifdef __KERNEL__
		render($block->{clauses}->[0]->{body}, 4);
	    } elsif (($kernel_mark & 3) == 2) {
		# #ifndef __KERNEL__
		push @uapilines, @{$block->{clauses}->[0]->{lines}};
		render($block->{clauses}->[0]->{body}, 8);
		push @uapilines, @{$block->{clauses}->[1]->{lines}};
	    } else {
		if ($block->{clauses}->[0]->{kernel_mark} & 1) {
		    # #ifdef __KERNEL__ ... #else
		    render($block->{clauses}->[0]->{body}, 4);

		    my @iflines = @{$block->{clauses}->[0]->{lines}};
		    $iflines[0] =~ s/#(\s*if)def/#$1ndef/;
		    $iflines[0] =~ s/#(\s*if\s+)defined/#$1!defined/;
		    push @uapilines, @iflines;
		    render($block->{clauses}->[1]->{body}, 8);
		    push @uapilines, @{$block->{clauses}->[2]->{lines}};
		} else {
		    # #ifndef __KERNEL__ ... #else
		    render($block->{clauses}->[1]->{body}, 4);

		    push @uapilines, @{$block->{clauses}->[0]->{lines}};
		    render($block->{clauses}->[0]->{body}, 8);
		    push @uapilines, @{$block->{clauses}->[2]->{lines}};
		}
	    }
	}
    }
}

render();

###############################################################################
#
# See if a file actually has anything left in it after all the blank lines,
# comments and CPP conditionals and inclusions are removed.
#
# Returns:
#  0: non-reducible
#  1: reducible to nothing
#  2: reducible to a single #include
#  3: reducible to a multiple #includes
#
###############################################################################
sub reduce_file(@)
{
    my (@lines) = @_;

    my $blocks = 0;
    my $level = 0;
    my $guarded = 0;
    my $guardname = "";
    my $guarddefline = -2;
    my $first_if = 1;
    my $includes = 0;

    for (my $l = 0; $l <= $#lines; $l++) {
	my $line = $lines[$l];
	my $suppress = 0;

	# parse out the blocks
	# - this may be split over multiple lines using backslashes and comments
	#   that have embedded newlines
	my $block = $line;
      restart:
	$block =~ s@\s+$@@g;
	$block =~ s@\s+@ @g;

	while ($block =~ m@(/[*])@) {
	    my $o = index($block, "/*");
	    if ($block =~ m@([*]/)@) {
		my $c = index($block, "*/") + 2;
		substr($block, $o, $c - $o) = "";
	    } else {
		$l++;
		$block .= $lines[$l];
		#push @buffer, $lines[$l];
		goto restart;
	    }
	}

	if ($block =~ /^(.*)[\\]$/) {
	    $l++;
	    $block = $1 . $lines[$l];
	    #push @buffer, $lines[$l];
	    goto restart;
	}

	$block =~ s@\s+$@@g;
	$block =~ s@\s\s+@ @g;

	if ($line =~ /^#/) {
	    # handle conditional macros
	    if ($block =~ /^#\s*if/) {
		$level++;
		if ($block =~ /^#\s*ifndef\s+([_A-Za-z0-9]+)/ && $first_if == 1) {
		    $guardname = $1;
		    $guarddefline = $l + 1;
		    $first_if = 0;
		    next;
		}

		$first_if = 0;
	    } elsif ($block =~ /^#\s*endif/) {
		$level--;
		next;
	    } elsif ($block =~ /^#\s*else/) {
		next;
	    } elsif ($block =~ /^#\s*elif/) {
		next;
	    } elsif ($l == $guarddefline && $block =~ /^#\s*define\s+$guardname/) {
		next;
	    } elsif ($block =~ m@^#\s*include <uapi/@) {
		next;
	    } elsif ($block =~ /^#\s*include/) {
		$includes++;
		next;
	    } elsif ($block =~ /^#error only arch headers may be included in asm/) {
		next;
	    }
 
	} elsif ($block eq "") {
	    next;
	}

	#print "[", $block, "]\n";
	$blocks++;
    }

    die $linuxhdr, ": #if/#endif level mismatch ($level)\n"
	if ($level != 0);

    return 0 if ($blocks > 0);
    return 2 if ($includes == 1);
    return 3 if ($includes > 0);
    return 1;
}

###############################################################################
#
# Attempt to slide down the #include of the UAPI file to after the #include set
# if it was added automatically (if it was manually specified, then we leave it
# where it is).
#
###############################################################################
sub slide_include_uapi()
{
    # first of all, locate the #include of the UAPI file
    my $include_uapi = $kernellines[$include_uapi_at];
    die if ($include_uapi !~ m@#include <uapi/@);

    my $here = -1;
    my $if_level = 0;
    my $cond_include = 0;
    for (my $l = $include_uapi_at + 1; $l <= $#kernellines; $l++) {
	my $line = $kernellines[$l];
	chomp $line;

	if ($line eq "") {
	} elsif ($line =~ /#\s*include\s+<([^>]*)>/) {
	    last if ($1 eq "linux/byteorder/generic.h");
	    if ($if_level == 0) {
		$here = $l;
	    } else {
		$cond_include = 1;
	    }
	} elsif ($line =~ /#\s*if/) {
	    $if_level++;
	} elsif ($line =~ /#\s*else/) {
	} elsif ($line =~ /#\s*elif/) {
	} elsif ($line =~ /#\s*endif/) {
	    $if_level--;
	    if ($if_level == 0) {
		$here = $l if ($cond_include);
		$cond_include = 0;
	    }
	} else {
	    last;
	}
    }

    if ($here > -1) {
	splice @kernellines, $include_uapi_at, 2;
	splice @kernellines, $here - 1, 0, $include_uapi;
	splice @kernellines, $here, 0, "\n" unless ($kernellines[$here] eq "\n");
    }
}

slide_include_uapi() if ($include_uapi_at > -1);

###############################################################################
#
#
#
###############################################################################
output:
    ;

#print @kernellines;
#print "_" x 79, "\n";
#print @uapilines;

my $kred = reduce_file(@kernellines);
my $ured = reduce_file(@uapilines);

#print "kred: ", $kred, "\n";
#print "ured: ", $ured, "\n";
#exit 123;

if ($ured == 2) {
    @uapilines = grep /^#\s*include/, @uapilines;
} elsif ($ured == 1) {
    @uapilines = ();
}

if ($kred == 1) {
    # if all we're doing is #include'ing the UAPI header, then we may as well
    # delete the file and let CPP include the UAPI header directly
    @kernellines = ();
    @uapilines = @lines;
}

my $uapidir = $uapihdr;
$uapidir = $1 if ($uapidir =~ m!(.*)/!);
mkpath($uapidir) if (! -d $uapidir);

if ($#kernellines >= 0) {
    # we must create a UAPI header, even if it is blank
    open(FD, '>', $uapihdr) or die "$uapihdr: $!\n";
    print FD @uapilines or die "$uapihdr: $!\n";
    close FD or die "$uapihdr: $!\n";

    my $linuxhdrorig = $linuxhdr . ".orig";
    open(FD, '>', $linuxhdrorig) or die $linuxhdrorig, ": $!\n";
    print FD @kernellines or die $linuxhdrorig, ": $!\n";
    close FD or die $linuxhdrorig, ": $!\n";
    rename $linuxhdrorig, $linuxhdr or die $linuxhdr, ": $!\n";
} else {
    rename $linuxhdr, $uapihdr or die $uapihdr, ": $!\n";
}

###############################################################################
#
# Add the file to the uapi Kbuild file
#
###############################################################################
my $uapi_kbuild = $uapidir . "/Kbuild";

die "$uapi_kbuild: Not found\n" unless (-f $uapi_kbuild);

my $hdrname;
$uapihdr =~ m@([^/]*)$@, $hdrname = $1;

open(FD, '>>', $uapi_kbuild) or die "$uapi_kbuild: $!\n";

if ($linuxhdr eq "include/linux/a.out.h" ||
    $linuxhdr eq "include/linux/kvm.h" ||
    $linuxhdr eq "include/linux/kvm_para.h"
    ) {
    print FD
	"\n",
	'ifneq ($(wildcard $(srctree)/arch/$(SRCARCH)/include/asm/', $hdrname, " \\\n",
	"\t\t", '  $(srctree)/include/asm-$(SRCARCH)/', $hdrname, " \\\n",
	"\t\t", '  $(INSTALL_HDR_PATH)/include/asm-*/', $hdrname, "),)\n",
	"header-y += ", $hdrname, "\n",
	"endif\n\n"
	or die "$uapi_kbuild: $!\n";
} else {
    print FD "header-y += $hdrname\n" or die "$uapi_kbuild: $!\n";
}

close FD or die "$uapi_kbuild: $!\n";


###############################################################################
#
# Delete the file from the include/ Kbuild file
#
###############################################################################
my $linuxdir;
$linuxhdr =~ m@(.*)/[^/]*$@, $linuxdir = $1;
my $linux_kbuild = $linuxdir . "/Kbuild";

open(FD, '<', $linux_kbuild) or die $linux_kbuild, ": $!\n";
my @kblines = <FD> or die $linux_kbuild, ": $!\n";
close(FD) or die $linux_kbuild, ": $!\n";

my $temp = $linux_kbuild . ".temp";
open(FD, '>', $temp) or die "$temp: $!\n";
foreach my $kbline (@kblines) {
    if ($kbline =~ m@^header-y\s+[+]=\s+([a-zA-Z0-9_.-]+)@) {
	next if ($1 eq $hdrname);
    }
    print FD $kbline or die "$temp: $!\n";
}
close FD or die "$temp: $!\n";
rename $temp, $linux_kbuild or die "$temp -> $linux_kbuild: $!\n";
