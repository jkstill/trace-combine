
# Chronological Operations from Multiple 10046 Trace Files

Sometimes it is useful to get a chronological list of events from multiple trace files.

The oracle utility ```trcsess``` will combine trace files, but does not show a timestamp and session per line.

## trace-combined-sequential.pl

This script will read the trace file created by ```trcsess``` and create output that shows the timestamp and PID per line.

## trace-sequential.pl

This script will read a single 10046 trace file from STDIN and provide operations with timestamps.

## Usage

Currently these scripts work only with ISO8601 trace file timestamps.

eg: 2019-07-09T09:57:07.704095-07:00

The timestamps are cumulative; the elapsed time per operation is added to the current timestamp.

These are only an approximation as time is regularly 'lost' in Oracle trace files due to some untracked operations.

Even so, the operations should appear in order (mostly)

There are two example trace files in the trace directory that can be used to test these scripts

Run this command to create main.trc:

```
trcsess output=main.trc service=examples.jks.com trace/*.trc
```

Next use trace-combined-sequential.pl to create output.

The file 'main.trc' is expected to be in the current directory.

```bash

>  ./trace-combined-sequential.pl
2019-07-09 09:57:07.703523|9850|PARSING|#140472196919200|50vxqdkj4zu1w|select user#,password,datats#,tempts#,type#,defrole,resource$,pt
2019-07-09 09:57:07.703523|9850|PARSE|#140472196919200|50vxqdkj4zu1w|select user#,password,datats#,tempts#,type#,defrole,resource$,pt
2019-07-09 09:57:07.703523|9850|EXEC|#140472196919200|50vxqdkj4zu1w|select user#,password,datats#,tempts#,type#,defrole,resource$,pt
2019-07-09 09:57:07.703523|9850|FETCH|#140472196919200|50vxqdkj4zu1w|select user#,password,datats#,tempts#,type#,defrole,resource$,pt
2019-07-09 09:57:07.703523|9850|PARSING|0sbbcuruzd66f|select /*+ rule */ bucket_cnt, row_cnt, cache_cnt, null_cnt, tim
2019-07-09 09:57:07.703523|9850|EXEC|#140472196198512|0sbbcuruzd66f|select /*+ rule */ bucket_cnt, row_cnt, cache_cnt, null_cnt, tim
...
2019-07-09 09:57:07.703523|9850|PARSING|#140472196892576|fdryt1559xpbc|SELECT COUNT(*) JH_COUNT FROM HR.JOB_HISTORY
2019-07-09 09:57:07.704129|9854|PARSE|#140176600436752|fdryt1559xpbc|SELECT COUNT(*) JH_COUNT FROM HR.JOB_HISTORY
2019-07-09 09:57:07.704129|9854|EXEC|#140176600436752|fdryt1559xpbc|SELECT COUNT(*) JH_COUNT FROM HR.JOB_HISTORY
2019-07-09 09:57:07.704129|9854|FETCH|#140176600436752|fdryt1559xpbc|SELECT COUNT(*) JH_COUNT FROM HR.JOB_HISTORY
2019-07-09 09:57:07.704129|9854|PARSING|#140176600292208|04kug40zbu4dm|select policy#, action# from aud_object_opt$ where object# = :1
...
2019-07-09 09:57:08.690155|9850|FETCH|#140472196194824|NA|NA
2019-07-09 09:57:08.690155|9850|EXEC|#140472196892576|NA|NA
2019-07-09 09:57:08.690155|9850|FETCH|#140472196892576|NA|NA
2019-07-09 09:57:09.694425|9854|EXEC|#140176600439648|NA|NA
2019-07-09 09:57:09.694425|9854|FETCH|#140176600439648|NA|NA
2019-07-09 09:57:09.694425|9854|EXEC|#140176600436752|NA|NA
2019-07-09 09:57:09.694425|9854|FETCH|#140176600436752|NA|NA
2019-07-09 09:57:09.694425|9854|EXEC|#140176600439648|NA|NA
```

Whenever possible the sql_id and partial SQL statement are shown.

Sometimes the parsed SQL does not appear in the trace file and is shown as NA as it has already been parsed previously  in another session.

While the use of ```alter system flush shared_pool``` may help, there is no guarantee that all session trace files will include the parsed SQL statement.
				      
# Fields per line

The fields in each row are delimited with a pipe '|'.

Format:

timestamp|ospid|operation|cursor_id|sql_id|sql_statement

Only the first 128 characters of the SQL statement are shown.


## Timestamp

As seen in main.trc

## OS PID

Timestamps appear in main.trc like this:

```*** 2019-07-09T09:57:07.703515-07:00```

## Operation

Currently only PARSING, PARSE, EXEC and FETCH are shown

## Cursor ID

The ID of the cursor per session.

Please note that this can change during a session due to re-parsing;

## SQL_ID

The sql_id from the trace file, if available.

## SQL Statement


The SQL statement from the trace file, if available.



