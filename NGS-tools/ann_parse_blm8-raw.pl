#!/usr/bin/perl -w
## ==============================================================================
## Automated annotation tools
##
## program written by
##                                      Weizhong Li, UCSD
##                                      liwz@sdsc.edu
##                                      http://weizhong-lab.ucsd.edu
## ==============================================================================

my $script_name = $0;
my $script_dir = $0;
   $script_dir =~ s/[^\/]+$//;
   $script_dir = "./" unless ($script_dir);
require "$script_dir/ann_local.pl";

use Getopt::Std;
getopts("i:a:o:e:d:c:",\%opts);
die usage() unless ($opts{i} and $opts{o} and $opts{d});

my $results_dir  = $opts{i};
my $output       = $opts{o};
my $e_cutoff     = $opts{e}; $e_cutoff = 0.001 unless (defined($e_cutoff));
my $ref_faa      = $opts{d};
my $overlap_cutoff = $opts{c};
   $overlap_cutoff = 0.5 unless (defined($overlap_cutoff));
die "blast output results dir $results_dir not found" unless (-e $results_dir);
my ($i, $j, $k, $ll, $cmd);

my $cdd_id_2_des = ();
my $cdd_id_2_len = ();

open(TMP, $ref_faa) || die "Can not open $ref_faa";

my $seq_len = 0;
my $last_ll;

while($ll=<TMP>){
  chop($ll); $ll =~ s/\s+$//;
  if ($ll =~ /^>/) {
    if ($seq_len > 0) {
      my ($cdd_id, $cog_des) = split(/\s+/, substr($last_ll,1), 2);
      $cdd_id_2_des{$cdd_id}   = $cog_des;
      $cdd_id_2_len{$cdd_id}   = $seq_len;
    }
    $last_ll = $ll;
    $seq_len = 0;
  }
  else {
    $seq_len += length($ll);
  }
}
    if ($seq_len > 0) {
      my ($cdd_id, $cog_des) = split(/\s+/, substr($last_ll,1), 2);
      $cdd_id_2_des{$cdd_id}   = $cog_des;
      $cdd_id_2_len{$cdd_id}   = $seq_len;
    }
close(TMP);

open(OUT, "> $output") || die "Can not write to $output";
my @os;
if (-d $results_dir) { ##### a directory of output files
  @os = LL_get_active_ids($results_dir);
  @os = sort @os;
  foreach $i (@os) { parse_it($i);}
}
else { ##### a single output file
  parse_it();
}
close(OUT);


#### using output from hmmscan option --domtblout  -E 0.001 --notextw --cut_tc --noali 
sub parse_it {
  my $id = shift;
  my ($i, $j, $k, $ll);
  my $tout = (defined($id)) ? "$results_dir/$id" : $results_dir;
  my $last_seq_id = "";
  my @last_e;
  my @last_b;
  open(TMP, $tout) || next;
  while($ll=<TMP>) {
    chop($ll);
    next if ($ll =~ /^#/);
    my @lls = split(/\s+/, $ll); 
    my $output_looks_like = <<EOD; 
#query                          subject         %       alnln   mis     gap     q_b     q_e     s_b     s_e     expect  bits
#0                              1               2       3       4       5       6       7       8       9       10      11
mHE-SRS012902|scaffold|86.16    gnl|CDD|226997  47.62   42      17      2       164     201     210     250     5e-04   37.6
mHE-SRS012902|scaffold|109.23   gnl|CDD|225183  47.46   236     122     1       1       236     475     708     1e-92    284
mHE-SRS012902|scaffold|109.23   gnl|CDD|224055  44.35   239     130     2       1       239     332     567     2e-84    259
mHE-SRS012902|scaffold|109.23   gnl|CDD|227321  39.50   238     140     3       1       238     324     557     9e-69    218
EOD

    my $hmm_acc  = $lls[1];
    my $seq_id   = $lls[0];
    my $e_value  = $lls[10];
    my $hmm_b    = $lls[8];
    my $hmm_e    = $lls[9];
    my $seq_b    = $lls[6];
    my $seq_e    = $lls[7];
    ($hmm_b, $hmm_e) = sort {$a<=>$b} ($hmm_b, $hmm_e); ## sort in case of translated blast
    ($seq_b, $seq_e) = sort {$a<=>$b} ($seq_b, $seq_e); ## sort in case of translated blast

    next unless ($e_value <= $e_cutoff);

    if ($seq_id ne $last_seq_id) { @last_e = (); @last_b = (); } #### start a new sequence
    my $overlap_with_before = 0;
    for ($j=0; $j<@last_b; $j++) {
      my $lb=$last_b[$j];
      my $le=$last_e[$j];
      if ( overlap1($lb,$le,$seq_b,$seq_e) > ($seq_e-$seq_b+1) * $overlap_cutoff) {
       $overlap_with_before=1; last;
      }
    }
    #print $overlap_with_before ? "$ll***\n": "$ll\n";

    next if ($overlap_with_before);
    print OUT "$ll\t$cdd_id_2_des{$hmm_acc}\n";
    push(@last_e, $seq_e);
    push(@last_b, $seq_b);
    $last_seq_id = $seq_id;
  }
  close(TMP);
}


sub overlap1 {
  my ($b1, $e1, $b2, $e2) = @_;
  return 0 if ($e2 < $b1);
  return 0 if ($b2 > $e1);
  return ( ($e1<$e2)? $e1:$e2 )-( ($b1>$b2)? $b1:$b2);
}


sub usage {
<<EOD;

Filter raw blast tab format results and add full description at end of line

$script_name -i blast_output_or_folder_of_blast_output -o output_file -e e.value_cutoff -d reference-fasta-file -c overlap-cutoff

  -i blast_output_or_folder_of_blast_output
  -o output file name
  -d reference-fasta-file
  -e cutoff value for e.value, default 0.001
  -c cutoff value for overlap, if a hit is overlap (on Query sequence coordinate) with
     a existing hit with better e.value, this hit is filtered
     default 0.5
EOD
}

