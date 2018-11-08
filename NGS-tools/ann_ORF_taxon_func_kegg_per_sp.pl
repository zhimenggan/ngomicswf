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

# Given the ORF KO annotation (by ann_ORF_taxon_func.pl)
# This script read in Brite file (e.g. ko00001.keg  ko00002.keg  ko01000.keg  ko02000.keg),
# and calculate abundance of KO, ko, class, modules etc
# these .keg file are from KEGG database /kegg/kegg-brite/ko/

use Getopt::Std;
getopts("i:k:a:o:e:d:s:t:r:c:K:",\%opts);
die usage() unless ($opts{i} and $opts{k} and $opts{o} and $opts{r});

my $ORF_ann_file = $opts{i}; #### blast alignment file in m8 format
my $keg_file     = $opts{k}; #### e.g. ko00001.keg  ko00002.keg  ko01000.keg  ko02000.keg
my $output       = $opts{o}; #### output prefix kegg abundance file
my $ORF_depth    = $opts{d}; #### ORF depth
my $ref_KOs      = $opts{r}; #### single-copy house keeping gene
my $tmp_dir      = "$output.dir.$$";
my $ref_KO_cov_cutoff = $opts{c}; #### skip species unless with enough ref hits
   $ref_KO_cov_cutoff = 0.3 unless ($ref_KO_cov_cutoff);
my $key_col      = $opts{K}; $key_col =9 unless(defined($key_col));

my ($i, $j, $k, $ll, $cmd);
my $worker_script = "$script_dir/ann_ORF_taxon_func_kegg.pl -i $tmp_dir/in.txt -d $ORF_depth -k $keg_file -r $ref_KOs -o $tmp_dir/out"; 
if (-e $tmp_dir) {
  $cmd = `rm -rf $tmp_dir`;
}
$cmd = `mkdir $tmp_dir`;

my %single_copy_KOs = ();
open(TMP, $ref_KOs) || die "can not open $ref_KOs";
while($ll=<TMP>){ 
  if ($ll =~ /^\w\s+(K\d+)\s/) {
    $single_copy_KOs{$1} = 1;
  }
}
close(TMP);
my $num_ref_ko = scalar keys %single_copy_KOs;
my $num_ref_ko_cutoff = $num_ref_ko * $ref_KO_cov_cutoff;

my $last_sp = "";
my $orf_ann = "";
my %KO_hits = ();

my %org_2_txt;
my %org_2_KO;
my $col_name = "species";

open(TMP, $ORF_ann_file) || die "can not open $ORF_ann_file";
while($ll=<TMP>) {
  if ($ll =~ /^#/) {
    $col_name = (split(/\t/,$ll))[$key_col];
    next;
  }

  my @lls = split(/\t/, $ll);
  my $this_sp = $lls[$key_col];
  my $KO = $lls[11+7]; #### if hit KO
  $org_2_txt{$this_sp} .= $ll;
  $org_2_KO{$this_sp}{$KO} = 1 if (($KO =~ /^K\d+/) and $single_copy_KOs{$KO});
}
foreach $i (keys %org_2_txt) {
  if (not ($i =~ /\d+/)) {
    print STDERR "not valid species, $i\n";
    next;
  }
  my $n = scalar keys %{ $org_2_KO{$i} };
  if ($n >= $num_ref_ko_cutoff) {
    run_this($org_2_txt{$i}, $i, $col_name);
  }
  else {
    print STDERR "not enough ref KO hits ($n) for species, $i\n";
  }
}
close(TMP);

$cmd = `rm -rf $tmp_dir`;


sub run_this {
  my ($txt, $sp, $col_name) = @_;
  my ($i, $j, $k, $ll, $cmd);
  $sp =~ s/[^\w| ]/_/g;

  open(OUT, "> $tmp_dir/in.txt") || die "can not write to $tmp_dir/in.txt";
  print OUT $txt;
  close(OUT);

  $cmd = `$worker_script`;
  opendir(DIR, $tmp_dir) || die "can not read dir $tmp_dir";
  my @files = grep {/^out/} readdir(DIR);
  closedir(DIR);

  foreach $i (@files) {
    next if ($i =~ /-full-des$/); #### skip the super long format
    $j = $i; 
    $j =~ s/^out.//; $j = "$output.$j"; #### $j is target output
    if (not -e $j) {
      $cmd = `head -n 1 $tmp_dir/$i | sed "s/^/#$col_name\\t/" > $j`;
    }
    $cmd = `grep -v "^#" $tmp_dir/$i | sed "s/^/$sp\\t/" >> $j`;
  }
}

sub usage {
<<EOD;
geneate kegg annotation per species

$script_name -i ORF_annotation_file -k .keg_file -o output -r single-copy-ref-gene-list

  options:
    -i ORF_annotation_file, generated by ann_ORF_taxon_func.pl
    -k .keg file, e.g. ko00001.keg  ko00002.keg  ko01000.keg  ko02000.keg
    -o output prefix,
    -d ORF depth file
    -r .keg file, contains a list of KOs of single copy house-keeping gene 
       as reference to calculate relative abundance. 
       e.g. there are 55 KOs M00178  Ribosome, bacteria [PATH:map03010] [BR:ko03011]
    -c cutoff , default 0.3, skip species unless with enough ref hits
    -K key column (0'based) for key taxa, default 9 at species level,
       8 will be at genus level
       7 will be at family level
       0 will be species level taxid
       1 will be strain level taxid
       10 will be strain
EOD
}
