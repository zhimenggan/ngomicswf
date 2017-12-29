#!/usr/bin/perl
## =========================== NGS tools ==========================================
## NGS tools for metagenomic sequence analysis
## May also be used for other type NGS data analysis
##
##                                      Weizhong Li, UCSD
##                                      liwz@sdsc.edu
## http://weizhongli-lab.org/
## ================================================================================


use Getopt::Std;
getopts("s:o:d:r:",\%opts);
die usage() unless ($opts{s});

my $assembly_file    = $opts{s};
my $output           = $opts{o};
my $read_length      = $opts{r}; $read_length=150 unless ($read_length);
my $default_x        = $opts{d}; $default_x  =1   unless ($default_x);

my ($i, $j, $k, $ll, $cmd);

open(TMP, $assembly_file) || die "can not open $assembly_file";
my @assembly_ids = ();
my %assembly_2_len = ();
my $seq_id;
while($ll=<TMP>){
  chop($ll);
  if ($ll =~ /^>/) {
    $seq_id = substr($ll,1);
    $seq_id =~ s/\s.+$//;
    $assembly_2_len{$seq_id} = 0;
    push(@assembly_ids, $seq_id);
  }
  else {
    $ll =~ s/\s+$//;
    $assembly_2_len{$seq_id}  += length($ll);
  }
}
close(TMP);

my %assembly_reads_mapped = ();
while($ll=<>){
  if ($ll =~ /^\@/) { #### headers
    next;
  }
  else { #### alignment
    chop($ll);
    my @lls = split(/\t/,$ll);
    my $rid = $lls[2];    if ($rid eq "*") {  next; }

    $assembly_reads_mapped{$rid} ++;
  } #### alignment section
}


my $fh = "STDOUT";
if ($output) {
  open(OUT, ">$output") || die "Can not write to $OUT";
  $fh = "OUT";
}
foreach $i (@assembly_ids) {
  my $depth = $default_x;
  if ($assembly_2_len{$i} and $assembly_reads_mapped{$i}) {
    $depth = $assembly_reads_mapped{$i} * $read_length / $assembly_2_len{$i};
  }
  print OUT "$i\t$depth\n";
}
close(OUT) if ($output);

sub usage {
<<EOD
Given a sam file of reads to assembles generated by 
  bwa mem reference R1.fa_or_fq R2.fa_or_fq 
This script takes the sam from STDIN and calculate the depth of coverage 
for each contig / scaffold sequence

The depth of coverage is total number of reads * read length / length of contig

usage:
  $script_name  -s fasta_file_of_assembly -o output_depth_coverage 

  options
    -o output file, default STDOUT
    -s fasta file of assembly
    -r read length, default 150
    -d default depth, default 1
       if a contig is not found in the sam file, use this value

EOD
}
########## END usage

