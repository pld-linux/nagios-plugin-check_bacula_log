#!/usr/bin/perl -w
############################################################################
# Nagios Check script to see if an internet connection is working
#
# Copyright (C)2005 Guy Van Sanden <nocturn00@gmail.com> - http://nocturn.vsbnet.be
# Copyright (C)2010 Elan Ruusamäe <glen@pld-linux.org>
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
# SETUP:
# Depending on your setup, you may need to tweak permissions so Nagios (or
# Nagios NRPE) would be able to access the log. For example:
# setfacl -m g:nagcmd:r-x /var/log/bacula
# setfacl -m g:nagcmd:r-- /var/log/bacula/log
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
my $minbackups = 1;

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

my $state = $ERRORS{'OK'};
my $msg ="";
my $date = strftime("%d-%b-%Y", localtime);

# all messages start with Build OS and end with Termination.
#  Build OS:               i686-pld-linux-gnu PLD/Linux 2.0 (Ac)
#  JobId:                  2087
#  Job:                    stimpy.example.org.2010-01-22_02.05.01.42
#  Backup Level:           Incremental, since=2010-01-18 02:05:04
#  Client:                 "stimpy.example.org-fd" 2.4.4 (28Dec08) x86_64-pld-linux-gnu,PLD/Linux,
#  FileSet:                "stimpy.example.org -FullSet" 2009-10-31 02:05:00
#  Pool:                   "stimpy.example.org-IncPool" (From Job IncPool override)
#  Storage:                "stimpy.example.org-File" (From Job resource)
#  Scheduled time:         22-Jan-2010 02:05:01
#  Start time:             22-Jan-2010 02:05:02
#  End time:               22-Jan-2010 02:35:12
#  Elapsed time:           30 mins 10 secs
#  Priority:               10
#  FD Files Written:       0
#  SD Files Written:       0
#  FD Bytes Written:       0 (0 B)
#  SD Bytes Written:       0 (0 B)
#  Rate:                   0.0 KB/s
#  Software Compression:   None
#  VSS:                    no
#  Storage Encryption:     no
#  Volume name(s):
#  Volume Session Id:      166
#  Volume Session Time:    1262187014
#  Last Volume Bytes:      1,280 (1.280 KB)
#  Non-fatal FD errors:    0
#  SD Errors:              0
#  FD termination status:
#  SD termination status:  Waiting on FD
#  Termination:            *** Backup Error ***

my %job;
my @errordetails;
open(my $fh, '<', $stat);
while (<$fh>) {
	if (my($key, $val) = /^\s{2}(\S[^:]+):\s+(.+)$/) {
		$job{$key} = $val;

		# "Termination" is the last key
		# if have full info in %job, do some processing
		next unless $key eq 'Termination';

		# want only todays jobs
		next unless $job{'Start time'} =~ m/^\Q$date\E\s/;

		# only backup jobs (not restore), ignore Cancelled jobs
		if (my($status) = $job{'Termination'} =~ /Backup (.*?)(?:\s\*\*\*)?$/) {
			if ($status ne 'Canceled') {
				if ($status =~ /OK/){
					$okbackups = $okbackups + 1;
				} else {
					$failedbackups = $failedbackups + 1;
					# leave out date from job name
					# supported date formats:
					# Bacula 2.4: BackupCatalog.2010-10-25_02.10.00.46
					# Bacula 5.0: BackupCatalog.2010-10-25_02.10.00_46
					my ($jobname) = $job{'Job'} =~ /^(.+)\.\d{4}-\d{2}-\d{2}_\d{2}\.\d{2}\.\d{2}[_.]\d{2}/;
					my ($backuplevel) = $job{'Backup Level'} =~ /^([^,]+)/;
					push(@errordetails, "$status: $jobname/$backuplevel");
				}
				$totalbackups = $totalbackups + 1;
			}
		}

		# clear the job
		undef %job;
	}
}
close($fh);

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

# append error details
$msg .= "(".join("; ", @errordetails).")" if @errordetails;

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
