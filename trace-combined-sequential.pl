#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use IO::File;
# would use Try::Tiny, but not installed in Oracle Perl

my $debug=0;

my $fh = IO::File->new();
$fh->open('main.trc',O_RDONLY) or die "cannot read main.trc - $!\n";

my %sql=();
my %sqlByCursorID=();
my @ops=();

=head1 trcsess

 Use trcsess to combine 2 or more trace files:

   trcsess output=main.trc service=examples.gzk.com trace_1.trc tracce_2.trc ...
	or
   trcsess output=main.trc service=examples.gzk.com *_ora_*.trc


 The file main.trc is then read by this script to create an output of SQL executions by session, in chronological order

 The first line of main.trc should look like this:


   *** [ Unix process pid: 9850 ]


=cut

my $pidLine=<$fh>;
print "$pidLine\n" if $debug;

# get pid
my ($pid) = ($pidLine =~ /pid:\s+([0-9]+)\s/);
print "pid: $pid\n" if $debug;
die "Could not find first Unix process id in main.trc\n" unless $pid;

my ($cursorID, $sqlID, $timestamp);

while(<$fh>) {
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

		my ($year, $month, $day, $hour, $minute, $second, $microsecond) 
			= ( $line =~ /\*\*\*\s+([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]{6})/ );

		$timestamp=qq{$year-$month-$day $hour:$minute:$second.$microsecond};
		print "time: $timestamp\n" if $debug;	

		next;
	}

	my $sqlStatement;
	if ( $line =~ /PARSING IN CURSOR/ ) {
		($cursorID, $sqlID) = ( $line =~ /PARSING IN CURSOR (#[0-9]+) .* sqlid='([[:alnum:]]{13})'/ );
		# sql statement is always line following PARSING
		$sqlStatement = <$fh>;
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
		print "OP: $op  Cursor: $cursorID\n" if $debug;

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


