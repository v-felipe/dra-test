#!/usr/bin/perl

###############
# Usage
###############
@ARGV >= 2 or die "usage: $0 SPPRDATA1 .. SPPRDATAn\n";

###############
# Main
###############

# Create output directory
$output_dir = "data_by_ac";
$dir_permissions = "0755";
mkdir $output_dir, oct($dir_permissions)
    or warn "Can't make directory $output_dir: $!\n";

# Read in each file.  Determine what ac ids are in which files.  
foreach $file (@ARGV)
{
    if($file =~ /$output_dir/)
    {
        print STDERR "Skipping $file in output directory.\n";
    }
    elsif($file =~ /\.log/)
    {
        print "Processing $file\n";
        &add_to_ac_table($file);
    }
}

# Output a file per ac containing all its data.
&map_data_and_output();


###############
# Subroutines
###############
sub add_to_ac_table
{
    my ($logfile) = @_;

    open(INFILE, "<", $logfile)
        or die "Can't open $logfile for reading: $!\n";

    while(<INFILE>)
    {
        if($_ =~ /^MEET_TIME_ERROR\s+(\w+).+?\s+(\d+)/)
        {
            my $acid = $1;
            my $ts = $2;
            if(!exists $ac_table{$acid})
            {
                $ac_table{$acid} = { $logfile => $ts };
            }
            elsif(!exists $ac_table{$acid}{$logfile})
            {
                my $tmp = $ac_table{$acid};
                $$tmp{$logfile} = $ts;
            }
        }
    }
}

sub map_data_and_output
{
    # look at each AC entry in the hash of hashs
    while (($k_ac,$v_hklog) = each %ac_table)
    {
        my @logs = sort files_by_time keys %$v_hklog;
        &output_data_by_ac($k_ac, @logs);
    }
}

# The hashtable name must be global from the calling function.
sub files_by_time { $$v_hklog{$a} <=> $$v_hklog{$b} };

sub output_data_by_ac
{
    my($acid) = shift @_;

    my $staticname = "driver_data.log";
    my $outputfile = "$output_dir\/$acid$staticname";
    open(OUTFILE, ">", $outputfile)
        or die "Can't open $outputfile for writing: $!\n";

    foreach (@_)
    {
        open(INFILE, "<", $_)
            or die "Can't open $_ for reading: $!\n";
        while(<INFILE>)
        {
            if(/^ADVISORY_ACCEPTED\s+.*\s+0\s+0\s+0/)
            {
                # filter out repeated ADVISORY_ACCEPTED data
            }
            elsif(/$acid/)
            {
                print OUTFILE "$_";
            }
        }
    }
}
  
