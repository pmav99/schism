#!/usr/bin/perl -w

#For netcdf4 outputs, and allow parallelization.
#Do harmonic analysis for all nodes; drives read_output8_allnodes_simple and tidal_analysis
#Run in dir where hgrid.gr3 is.
#Needs inputs: hgrid.gr3, include.gr3 (hgrid based; to focus on a region or subsample)
#combined schout_*.nc, and drives ha_sub.pl (in each parallel task)
#And also arguments to this script. 
#Make sure the batch script, compiled executables are for same system
#Outputs: amp_[m2,k1].gr3, pha_[m2,k1].gr3

if (@ARGV != 7) {
    print "Usage: $0 [full path to read_output8_allnodes_simple] [full path to tidal_analysis] 
          [full path to qsub batch script] [full path to tidal_const.dat] [# of tasks] [start stack]
          [end stack]\n";
    print "Example: $0 /sciclone/home10/yinglong/bin/read_output8_allnodes_simple /sciclone/home10/yinglong/bin/tidal_analysis 
          /sciclone/home10/yinglong/run_comb /sciclone/home10/yinglong/Scripts/Harmonic_Analysis/SCHISM/NCOutputs/tidal_const.dat.days
          3 2 4\n";
    exit(1);
}

$extract_code=$ARGV[0];
$ha_code=$ARGV[1];
$batch=$ARGV[2];
$tidal_const=$ARGV[3];
$tasks=$ARGV[4];
$start=$ARGV[5];
$end=$ARGV[6];

$pi=3.14159267989;

#Inputs
open(GRID,"<include.gr3") or die "Cannot open grid file\n";
@include=<GRID>; close(GRID);
open(GRID,"<hgrid.gr3") or die "Cannot open grid file\n";
@all_lines=<GRID>; close(GRID);

($ne,$np)=split(" ",$all_lines[1]);
$count=0;
for($i=1;$i<=$np;$i++)
{
  ($_,$_,$_,$fl[$i-1])=split(" ",$include[$i+1]);

  if($fl[$i-1]>0.1)
  {
    $count=$count+1; 
  } #if
} #for $i
print "# of output pts= $count\n";
$pts_per_task=int($count/$tasks); #except for the last task
$pts_last_task=$count-($tasks-1)*$pts_per_task;

#Init
for($t=1;$t<=$tasks;$t++)
{
  for($i=1;$i<=$np;$i++) { $filter[$i-1][$t-1]=0;}
  
} #for $t

$count=0;
for($i=1;$i<=$np;$i++)
{
  if($fl[$i-1]>0.1)
  {
    $count=$count+1;
    $t=int(($count-1)/$pts_per_task); #task ID (0-based)
    if($t>$tasks-1) {$t=$tasks-1;}
    $filter[$i-1][$t]=1;
    #Creat local-to-global mapping
    $local_index=$count-$t*$pts_per_task; #1 based
    $l2g[$local_index-1][$t]=$i;
  } #if
} #for $i


#Ouptut filter_flag
for($t=1;$t<=$tasks;$t++)
{
  $id=sprintf('%03d',$t);
  $filter_flag="filter_flag_"."$id";
  system "rm -f $filter_flag";
  open(F,">$filter_flag");
  for($i=1;$i<=$np;$i++) {print F "$filter[$i-1][$t-1]\n"; }
  close(F);
} #for $t

system "rm -f EXTRACT_* scrn.out_*";
for($t=1;$t<=$tasks;$t++)
{
  $id=sprintf('%03d',$t);
  system "rm -f run_$id; cp -L $batch run_$id";
  open(RUN,"<run_$id") or die "Cannot open run_$id\n";
  @run=<RUN>; close(RUN);  

  if($t<$tasks) {$npts=$pts_per_task;}
  else {$npts=$pts_last_task;}

  open(RUN2,">run_$id");
  foreach $a (@run)
  {
    if($a =~ "mvp" || $a =~ "~/bin") {print RUN2 "./ha_sub.pl $extract_code $ha_code $tidal_const $t $start $end $npts >& scrn.out_$id\n";}
    elsif($a =~ "#PBS" && $a =~ "-N") {print RUN2 "#PBS -N EXTRACT_$id\n";}
    else {print RUN2 $a;}
  }
  close(RUN2);

  system "qsub run_$id";
} #for $t

#Init final outputs as junk
for($i=1;$i<=$np;$i++)
{
 $amp[0][$i]=-9999;
 $amp[1][$i]=-9999;
 $pha[0][$i]=-9999;
 $pha[1][$i]=-9999;
}

#Check if all are done
for($t=1;$t<=$tasks;$t++)
{
  $id=sprintf('%03d',$t);
  $done=0; #init
  while($done==0)
  {
    sleep 10; #sec
    if(-e "scrn.out_$id")
    {
      open(OUT,"<scrn.out_$id") or die "Cannot open scrn.out_$id\n";
      @out=<OUT>; close(OUT);
      foreach $a (@out)
      {
        if($a =~ "Done ha_sub") { $done=1; }
      } 
    }
  } #while

  open(OUT1,"<M2_$id") or die "Cannot open M2_$id\n";
  open(OUT2,"<K1_$id") or die "Cannot open K1_$id\n";
  @m2=<OUT1>; close(OUT1);
  @k1=<OUT2>; close(OUT2);

  #@amp[const index][global node # (1 based)]
  foreach $a (@m2)
  {
    ($indx,$_,$amplitude,$phase)=split(" ",$a);
    $tmp=$l2g[$indx-1][$t-1];
    $amp[0][$tmp]=$amplitude;
    $pha[0][$tmp]=$phase*180/$pi;
  }#foreach 
  foreach $a (@k1)
  {
    ($indx,$_,$amplitude,$phase)=split(" ",$a);
    $tmp=$l2g[$indx-1][$t-1];
    $amp[1][$tmp]=$amplitude;
    $pha[1][$tmp]=$phase*180/$pi;
  }#foreach 
} #for $t

print "Done all HA; starting final assembly...\n";

open(AMP1,">amp_m2.gr3");
open(PHA1,">pha_m2.gr3");
open(AMP2,">amp_k1.gr3");
open(PHA2,">pha_k1.gr3");
print AMP1 @all_lines[0..1];
print AMP2 @all_lines[0..1];
print PHA1 @all_lines[0..1];
print PHA2 @all_lines[0..1];

for($i=1;$i<=$np;$i++)
{
  ($_,$x,$y,$_)=split(" ",$all_lines[$i+1]);
  print AMP1 "$i $x $y $amp[0][$i]\n";
  print AMP2 "$i $x $y $amp[1][$i]\n";
  print PHA1 "$i $x $y $pha[0][$i]\n";
  print PHA2 "$i $x $y $pha[1][$i]\n";
} #for $i
print AMP1 @all_lines[$np+2..$ne+$np+1];
print AMP2 @all_lines[$np+2..$ne+$np+1];
print PHA1 @all_lines[$np+2..$ne+$np+1];
print PHA2 @all_lines[$np+2..$ne+$np+1];
close(AMP1); close(PHA1); close(AMP2); close(PHA2);
