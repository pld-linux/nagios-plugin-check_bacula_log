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
# check_internet 
#
############################################################################

use strict;
use warnings;
use Getopt::Long;
use vars qw($opt_V $opt_h $opt_t $opt_F $opt_m $PROGNAME);
use lib '/usr/lib/nagios/plugins/';
use utils qw(%ERRORS &print_revision &support);
use Net::Ping;

$PROGNAME="check_bacula";

sub print_help ();
sub print_usage ();

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';
my ( $line, $prevline, $stat, $state ,$date, $msg, $status, $skip, $minbackups, $totalbackups, $okbackups, $failedbackups);

$stat="";
$date=`/bin/date +'%d-%b-%Y'`;
chomp($date);

$totalbackups = 0;
$okbackups = 0;
$failedbackups = 0;
$minbackups = 0;

#Option checking
Getopt::Long::Configure('bundling');
$status = GetOptions(
                'V'   		=> \$opt_V, 
		'version'    	=> \$opt_V,
                'h'   		=> \$opt_h, 
		'help'       	=> \$opt_h,
		'm=i'		=> \$opt_m,
		'F=s' 		=> \$opt_F, 
		'Filename=s'   	=> \$opt_F);

# Version
if ($opt_V) {
        print_revision($PROGNAME,'$Revision$');
        exit $ERRORS{'OK'};
}

# Help
if ($opt_h) {
        print_help();
        exit $ERRORS{'OK'};
}

# Filename supplied
if ($opt_F) {
        #$opt_F = shift;
	chomp($opt_F);
	$stat = $opt_F;
}

if ($opt_m) {
	$minbackups = $opt_m;
}

if ( ! -r $stat ) {
	print "Invalid log file: $stat\n";
       	exit $ERRORS{'UNKNOWN'};
}

open (FH, $stat);
$state = $ERRORS{'OK'};
$msg ="";


$skip = 1;
while (<FH>) {
	if(/Start time:.+$date/) {
		$skip = 0;
	}
	
	if($skip eq 0){
		if(/Termination:.+Backup (.+)/){
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

if($failedbackups > 0){
	$state = $ERRORS{'WARNING'};
	$msg = "Backups: $failedbackups Failed, $okbackups completed successfull ";
} elsif ($totalbackups < $minbackups) {
	$state = $ERRORS{'WARNING'};
        $msg = "Backups: Only $totalbackups ran ($minbackups expected)";
} else {
	$state = $ERRORS{'OK'};
	$msg = "Backups: $okbackups Backups completed successfull";
}


if ( $state == $ERRORS{'WARNING'} ) {
        print "WARNING - $msg\n";
} elsif ( $state == $ERRORS{'OK'} )
         { print "OK - $msg\n"; }
exit $state;


sub print_usage () {
        print "Usage: $PROGNAME -F <filename>\n";
}

sub print_help () {
        print_revision($PROGNAME,'$Revision$');
        print "Copyright (c) 2005 Guy Van Sanden\n";
        print "\n";
        print_usage();
        print "Checks todays backups of the Bacula system
-F ( --filename=FILE)
        Full path and name to servers file.\n\n";
support();
}


