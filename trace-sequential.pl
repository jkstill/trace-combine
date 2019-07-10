#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use IO::File;
use DateTime;
use POSIX qw( strftime );

# would use Try::Tiny, but not installed in Oracle Perl

my $debug=0;

my %sql=();
my %sqlByCursorID=();
my @ops=();

=head1 trcsess

  This script gets chronolical operations from a single 10046 trace file, with timestamps

=cut

# get first pid
my $pid;
while(<STDIN>) {
	#print;
	($pid) = ( $_  =~ /pid:\s+([0-9]+),\s/);
	last if $pid;
}

print "pid: $pid\n" if $debug;
die "Could not find first Unix process id in main.trc\n" unless $pid;

my ($cursorID, $sqlID, $timestamp, $dt);

while(<STDIN>) {
	my $line=$_;
	chomp $line;

	if ( $line =~ /\*\*\*\s+.*pid:\s+([0-9]+)/ ) {
		($pid) = ($line =~ /pid:\s+([0-9]+)\s/);
		print "pid: $pid\n" if $debug;
		next;
	}


	if ( $line =~ /\*\*\*\s+[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}/ ) {
		#($pid) = ($line =~ /pid:\s+([0-9]+)\s/);
		print "line: $line\n" if $debug;

		my ($year, $month, $day, $hour, $minute, $second, $microsecond) = parseDateStr($line);
		$dt = createDate($second,$minute,$hour,$day,$month,$year,$microsecond);
		$timestamp = getDate($dt);
		print "time: $timestamp\n" if $debug;	

		next;
	}

	my $sqlStatement;
	if ( $line =~ /PARSING IN CURSOR/ ) {
		($cursorID, $sqlID) = ( $line =~ /PARSING IN CURSOR (#[0-9]+) .* sqlid='([[:alnum:]]{13})'/ );
		# sql statement is always line following PARSING
		$sqlStatement = <STDIN>;
		chomp $sqlStatement;

		print "sqlid: $sqlID\n" if $debug;
		print "cursor: $cursorID\n" if $debug;

		# cursor IDs can be associated with different SQL statements in the same session when cursors opened/closed/reparsed
		# so always update the cursor ID
		$sql{$sqlID} = $sqlStatement;
		$sqlByCursorID{${sqlID}.${pid}.${cursorID}} = $sqlID;

		push @ops, qq{$timestamp|$pid|PARSING|$cursorID|$sqlID|} . substr($sqlStatement,0,64);
		next;
	}
	
	if ( $line =~ /^(EXEC|FETCH|PARSE)/ ) {
		my ($op, $remainder) = split(/\s+/,$line);
		my ($cursorID) = split(/:/,$remainder);
		my ($elapsedMicroseconds) = ( $remainder =~ /:c=[0-9]+,e=([0-9]+),/ );
		print "OP: $op  Cursor: $cursorID\n" if $debug;

		$dt->add( nanoseconds => $elapsedMicroseconds * 1000);
		$timestamp = getDate($dt);

		#print "line: $line\n";
		#print "elapsed: $elapsedMicroseconds\n";

		# sometimes the parsed SQL does not appear in the trace file, as it has already been parsed previously
		# in another session - use 'alter system flush shared_pool' may help
		# other sessions run at the same time for testing can still caused parsing to not appear in other sessions
		print "sqlid: $sqlID\n" if $debug;
		print "pid: $pid\n" if $debug;
		print "cursor: $cursorID\n" if $debug;


		if ( exists $sqlByCursorID{${sqlID}.${pid}.${cursorID}} ) {
			print "cursorID found\n" if $debug;
			my $chkSqlID = $sql{$sqlByCursorID{${sqlID}.${pid}.${cursorID}}};
			if ($chkSqlID) {
				print "SQL by cursorID found\n" if $debug;
				#push @ops, qq{$timestamp|$pid|$op|$sqlID|} . substr($sql{$sqlByCursorID{${sqlID}.${pid}.${cursorID}}},0,64);
				push @ops, qq{$timestamp|$pid|$op|$cursorID|$sqlID|} . substr($chkSqlID,0,64);
			} else {
				print "SQL by PID NOT found\n" if $debug;
				push @ops, qq{$timestamp|$pid|$op|$cursorID|NA|NA};
			}
		} else {
			print "SQL By cursorID NOT found\n" if $debug;
			push @ops, qq{$timestamp|$pid|$op|$cursorID|NA|NA};
		}
	}
	
	print '=' x 128, "\n" if $debug;
}

print 'SQL: ', Dumper(\%sql) if $debug;
print 'CURSOR ', Dumper(\%sqlByCursorID) if $debug;
print 'OPS ', Dumper(\@ops) if $debug;


foreach my $line ( @ops ) { print "$line\n" }

# pass DateTime type
# or dateStr of ISO8601 format
sub getDate {
	my $dt = shift;;
	my ($year, $month, $day, $hour, $minute, $second, $microsecond);

	if (ref($dt)) {
		($second,$minute,$hour,$day,$month,$year,$microsecond)
			= ($dt->second,$dt->minute,$dt->hour,$dt->day,$dt->month,$dt->year,$dt->nanosecond / 1000);
	} else {
		($year, $month, $day, $hour, $minute, $second, $microsecond) = parseDateStr($dt);
	}

	return formatDate($second,$minute,$hour,$day,$month,$year,$microsecond);
}

# oracle trace date string
sub parseDateStr {
	my $dateStr = shift;

	#my ($year, $month, $day, $hour, $minute, $second, $microsecond)
	#= ( $dateStr =~ /^\*{0,3}\s*([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]{6})/ );

	my @dateParts = ( $dateStr =~ /^\*{0,3}\s*([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]{6})/ );

	return @dateParts;
}

sub formatDate {
	my ($second,$minute,$hour,$day,$month,$year, $microsecond) = @_;
	return sprintf("%s.%06.0f", strftime("%Y-%m-%d %H:%M:%S", ($second,$minute,$hour,$day,$month-1,$year-1900) ), $microsecond);
}

sub createDate {
	my ($second,$minute,$hour,$day,$month,$year, $microsecond) = @_;

	return  DateTime->new(
		year      => $year,
		month     => $month,
		day       => $day,
		hour      => $hour,
		minute    => $minute,
		second    => $second,
		nanosecond => $microsecond * 1000
	);
}
