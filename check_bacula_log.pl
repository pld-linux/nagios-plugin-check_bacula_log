#!/usr/bin/perl -w

############################################################################
# Nagios Check script to see if an internet connection is working
#
# Copyright (C)2005 Guy Van Sanden <nocturn00@gmail.com> - http://nocturn.vsbnet.be
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
# USAGE:
# check_bacula_log
#
############################################################################

use strict;
use warnings;
use Getopt::Long;
use POSIX qw(strftime);
use lib '/usr/lib/nagios/plugins';
use utils qw(%ERRORS &print_revision &support);

my $PROGNAME = "check_bacula_log";
my $REVISION = '$Revision$';

sub print_help();
sub print_usage();

$ENV{'PATH'} = '';
$ENV{'BASH_ENV'} = '';
$ENV{'ENV'} = '';

my $stat = "";
my $totalbackups = 0;
my $okbackups = 0;
my $failedbackups = 0;
my $minbackups = 0;

# Option checking
my %opt;
Getopt::Long::Configure('bundling');
my $status = GetOptions(
	'V'             => \$opt{V}, 
	'version'       => \$opt{V},
	'h'             => \$opt{h}, 
	'help'          => \$opt{h},
	'm=i'           => \$opt{m},
	'F=s'           => \$opt{F}, 
	'Filename=s'    => \$opt{F}
);

# Version
if ($opt{V}) {
	print_revision($PROGNAME, $REVISION);
	exit $ERRORS{'OK'};
}

# Help
if ($opt{h}) {
	print_help();
	exit $ERRORS{'OK'};
}

# Filename supplied
if ($opt{F}) {
	chomp($opt{F});
	$stat = $opt{F};
}

if ($opt{m}) {
	$minbackups = $opt{m};
}

if (! -r $stat) {
	print "Invalid log file: $stat\n";
	exit $ERRORS{'UNKNOWN'};
}

open(FH, $stat);
my $state = $ERRORS{'OK'};
my $msg ="";
my $skip = 1;
my $date = strftime("%d-%b-%Y", localtime);
while (<FH>) {
	if (/Start time:.+$date/) {
		$skip = 0;
	}
	
	if($ skip eq 0){
		if (/Termination:.+Backup (.+)/){
			if($1 =~ /OK.*/){
				$okbackups = $okbackups + 1;
			} else {
				$failedbackups = $failedbackups +1;
			}
			$totalbackups = $totalbackups + 1;
			$skip = 1;
		}
	}
}
close (FH);

if ($failedbackups > 0){
	$state = $ERRORS{'WARNING'};
	$msg = "Backups: $failedbackups failed, $okbackups completed successfully ";
} elsif ($totalbackups < $minbackups) {
	$state = $ERRORS{'WARNING'};
	$msg = "Backups: Only $totalbackups ran ($minbackups expected)";
} else {
	$state = $ERRORS{'OK'};
	$msg = "Backups: $okbackups backups completed successfully";
}

if ($state == $ERRORS{'WARNING'}) {
	print "WARNING - $msg\n";
} elsif ( $state == $ERRORS{'OK'}) {
	print "OK - $msg\n";
}
exit $state;

sub print_usage() {
	print "Usage: $PROGNAME -F <filename>\n";
}

sub print_help() {
	print_revision($PROGNAME, $REVISION);
	print "Copyright (c) 2005 Guy Van Sanden\n";
	print "Copyright (c) 2010 Elan Ruusamäe <glen\@delfi.ee>\n";
	print "\n";
	print_usage();
	print "Checks todays backups of the Bacula system
-F ( --filename=FILE)
        Full path and name to servers file.\n\n";
support();
}
