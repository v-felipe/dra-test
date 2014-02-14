#!/usr/bin/perl

###############
# Usage
###############
@ARGV == 4 or die "usage: $0 ACID TEXTMSGFILE SPPRDATA CSPDATA\n";

###############
# Globals
###############
($acid, $msgtxt, $spprdatalog, $cspdata) = @ARGV;
$seperator = "---------------------------------------------";

###############
# Input Files 
###############
undef $/;

open(INFILE, "<", $msgtxt)
    or die "Can't open $msgtxt for reading: $!\n";

@records = split /^-+$/m, <INFILE>;

open(INFILE, "<", $spprdatalog)
    or die "Can't open $spprdatalog for reading: $!\n";

@log_records = split(/\n+/, <INFILE>);

open(INFILE, "<", $cspdata)
    or die "Can't open $cspdata for reading: $!\n";

@csp_records = split /.*?\*\*/, <INFILE>;

###############
# Main
###############
&load_csp_hashtable(@csp_records);
#print "$#log_records $log_records[1]\n";
($ac_not_frozen, $ac_frozen) = &find_index_before_frozen($acid);
#print "$ac_not_frozen, $ac_frozen\n";

$first_msg_index = &find_next_msg_for_ac(0, $acid);

# Compare records by timestamp and merge
$msg_data_index = $first_msg_index;
$log_data_index = $ac_not_frozen;
$msg_time = &get_timestamp_from_msg_block($msg_data_index,$acid); 
$log_time = &get_timestamp_from_data_entry($log_data_index,$acid); 

while($msg_time > 0 || $log_time > 0)
{
    # Print data from msg file.
    #print "$msg_time\t$log_time\n";
    if($log_time == -1 || $msg_time < $log_time)
    {
        &print_msg_block($records[$msg_data_index]);
        $msg_data_index = &find_next_msg_for_ac($msg_data_index + 1, $acid);
        $msg_time = &get_timestamp_from_msg_block($msg_data_index,$acid); 
    }
    # Print SPPR log entry
    elsif($msg_time == -1 || $msg_time > $log_time) 
    {
        $next_timestamp_index =
            &find_next_log_entry_for_ac($log_data_index + 1,$acid);
        &print_log_entry_range(
            $log_data_index, $next_timestamp_index, $seperator,$acid);
        $log_data_index = $next_timestamp_index;
        $log_time = &get_timestamp_from_data_entry($log_data_index,$acid); 
    }
    # Print SPPR log entry or multiple prior to printing msg data
    # with an equivalent timestamp
    else # equal
    {
        # output log data and get next index
        print "$log_records[$log_data_index]\n";
        print "$seperator\n";
        $log_data_index++;

        # Get index for next MTE log entry
        $next_timestamp_index =
            &find_next_log_entry_for_ac($log_data_index,$acid);

        # output any log entries upto the next timestamp
        &print_log_entry_range(
            $log_data_index, $next_timestamp_index, $seperator,$acid);

        # Get timestamp from next MTE log entry
        $log_data_index = $next_timestamp_index;
        $log_time = &get_timestamp_from_data_entry($log_data_index,$acid); 
    }
}

###############
# Subroutines
###############
#create hash table for csp data
sub load_csp_hashtable
{
    my (@csprecords) = @_;

    #$total = $#csprecords;

    foreach $csp_record (@csprecords)
    {
        if($csp_record =~ /(?:PA)+.*?(?:$acid)/s &&
            $csp_record =~ /0\.E\.\*\n+\s+0:\s+(?:.+)\s+\|(\d{10})/s)
        {
            #print "$1: $csp_record\n";
            $pa_by_time{$1} = $csp_record;
        }
    }
}

sub print_msg_block
{
    my ($msg_record) = @_;
    my $result = 0;
    my $time_index = 0;

    print "$msg_record\n";
    print "$seperator\n";

    if ($msg_record =~ /PA_CTAS/s)
    {
        if ($msg_record =~ /source\s+:\s+:\s+(\d+)/)
        { 
            $time_index = $1;
        }
        
        if (exists $pa_by_time{$time_index})
        {
            print "$pa_by_time{$time_index}\n";
            print "$seperator\n";
            $result = 1;
        }
    }
    $result;
}

sub get_timestamp_from_msg_block
{
    my($record_num, $acid) = @_;
    my $record = $records[$record_num];
    my $timestamp = 0;

    if($record_num >= @records)
    {
        return -1;
    }

    if($record =~ /(?:$acid)/)
    {
        $record =~ /(Message\s+Capture\s+Time\s+:\s+)(\d+)(.+)/; 
        $timestamp = $2;
    }
    $timestamp; 
}

sub get_timestamp_from_data_entry
{
    my($record_num, $acid) = @_;
    my $log_record = $log_records[$record_num];
    my $timestamp = 0;

    if($record_num >= @log_records)
    {
        return -1;
    }

    if($log_record =~ /^MEET_TIME_ERROR\s+(?:$acid).+?\s+(\d+)/) 
    {
        $timestamp = $1;
    }
    elsif($log_record =~ /^ADVISORY_ACCEPTED\s+(?:$acid).+?\s+(\d+)/)
    {
        $timestamp = $1;
    }

    $timestamp; 
}

sub find_index_before_frozen
{
    my($acid) = @_;
    my $previous = -1;

    for ($i = 0; $i < @log_records; $i++)
    {
        if($log_records[$i] =~ 
           /^MEET_TIME_ERROR\s+(?:$acid).+?\s+\d+\s+(\d)/)
        {
            if ($1 == 1)
            {
                #Found log entry with frozen set to 1;
                last;
            }
            else
            {
                $previous = $i;
            }
        }
    }
    if($previous == -1)
    {
        # SPPR is supposed to output MTE even when the AC is
        # not frozen.  Right now it's not doing that.
        $previous = $i;
    }

    ($previous, $i);
}

sub find_next_msg_for_ac 
{
    my($index, $acid) = @_;
    my $i = 0;

    for ($i = $index; $i < @records; $i++)
    {
        if($records[$i] =~ /(?:$acid)/)
        {
            #print "$i: $records[$i]\n";
            last;
        }
    }
    $i;
}

sub find_next_log_entry_for_ac 
{
    my($index, $acid) = @_;
    my $i = 0;

    for ($i = $index; $i < @log_records; $i++)
    {
        if($log_records[$i] =~ /^MEET_TIME_ERROR\s+(?:$acid)/  ||
            $log_records[$i] =~ /^ADVISORY_ACCEPTED\s+(?:$acid)/)
        {
            #print "$i: $log_records[$i]\n";
            last;
        }
    }
    $i;
}

sub print_log_entry_range
{
    my ($start, $end, $seperator, $acid) = @_;
    my $i = 0;

    for ($i = $start; $i < $end; $i++)
    {
        if($log_records[$i] =~ /$acid/)
        {
            print "$log_records[$i]\n";
            print "$seperator\n";
            #print "$i ";
        }
    }
    #print "\n";
}

