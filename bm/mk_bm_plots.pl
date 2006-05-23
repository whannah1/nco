#!/usr/bin/perl

# $Header: /data/zender/nco_20150216/nco/bm/mk_bm_plots.pl,v 1.11 2006-05-23 22:24:07 zender Exp $
# Script resides in nco/bm

# Purpose: 
# Script plots data from daemon-recorded benchmark info in
# sand.ess.uci.edu:/var/log/nco_benchmark.log
# That log needs to be filtered from the commandline via the parameters you want,
# typically by host, 'bench', possibly specific operator or thread number.
# The filtered data can be piped into this script which currently expects a data format like:
# commandline|timing data (the last 2 fields of the nco_benchmark.log) like so
# (assuming you're running this from a subdir below the log and perl script so as to isolate the data generated)
# 'scut' is better than 'cut'.  sand.ess.uci.edu has scut in /usr/local/bin
# 'scut -h' dumps usage
# NB: While it will process single threaded benchmarks, it's meant for multi-threaded or MPI benchmarks so the output
# (see write_gnuplot_cmds() below) is expecting 8 threads or processes to plot and best-fit over.
# NBB: Because the benchmark format and tests keep changing, I haven't put a lot of effort into trying to make this as
# robust as it could be, preferring to pre-process with bash-level commands before the data is fed to this script.

# example of 03-16-06
# grep bench nco_benchmark.log.3.16.06 |grep -i clay |scut --c1="1 3 4 2" --id1='\|' --od='|' | ./mk_bm_plots.pl --date_sng='03-16-06' --file_root='bm_LINUX_clay'

# --date_sng sets the date incorporated into the file name as well as the label on the plots,
#                allowing postprocessing of older benchmark data without inserting today's date_sng
# --file_root is the root file name string to better identify the data being generated.

# the above line selects the benchmark lines run on sand filters out the ones that include '--dap',
# ignore all those that aren't true benchmark lines (Linux is only seen on the uname output), then passes
# the remaining lines thru 'scut' which pulls the correct columns out based on the input delimiter '|' and
# uses the same ouput delimiter '|' before running the remaining lines into this script.


# It currently runs gnuplot on the datafiles it generates to produce a postscript file
# that is date-stamped in the filename and noted at the end of the run eg:
# nco.benchmarks_2005-07-14+22:37.ps.
# this multipage postscript file is best viewed in a 4-up format which can be generated by mpage:
# % mpage multipage.input.ps > 4-up.output.ps  (defaults to 4-up).
# More plots per page may be desirable but it starts toget unreadable quickly.
# It also produces a number of operator-specific data files on each run so beware that
# they'll add up quickly if you run it multiple times:

# nco_bm.2005-07-14_22:37.gnuplot............the gnuplot instructions & titles
# ncap.2005-07-14_22:37.data..............gnuplot numeric data for each NCO plot
# ncbo.2005-07-14_22:37.data                          "
# ncea.2005-07-14_22:37.data                          "
# ncecat.2005-07-14_22:37.data                        "
# ncflint.2005-07-14_22:37.data                       "
# ncpdq.2005-07-14_22:37.data                         "
# ncra.2005-07-14_22:37.data                          "
# ncrcat.2005-07-14_22:37.data                        "
# ncwa.2005-07-14_22:37.data                          "

# Above files are gnuplot commands which this script automatically plots
# but can be customized by editing the files with a text editor to make the titles
# more specific. Replot them again by simply typing:
# gnuplot < [cmdfile] (nco_bm.2005-07-14_22:37.gnuplot in the above case)

require 5.6.1 or die "This script requires Perl version >= 5.6.1, stopped";
#use Getopt::Long; # GNU-style getopt #qw(:config no_ignore_case bundling);
use strict; # Protect all namespaces
use Getopt::Long; # GNU-style getopt #qw(:config no_ignore_case bundling);

# Declare vars for strict
use vars qw( @titles @cmd_ln @nco_tim_info $thr_num %nc %tim_dta $num_nco_stz @nco_stz @clin_bits
$num_bits @nco_stz $num_nco_stz $nco_name @nco_tim_dta $gnuplot_data_file @nco_name_array
$tim_dta_end $cmdfile $ps_file $uname $op_sys $nco_vrs_sng $nco_vrs_A $nco_vrs_B $datestamp $tmp_sng
$date_sng $fle_root $filetimestamp $sngl_thr_avg %nco_avgs
);

$date_sng = "";
$fle_root = "nco.benchmarks";

my $rcd=Getopt::Long::Configure('no_ignore_case'); # Turn on case-sensitivity
&GetOptions(
	'date_sng=s'    => \$date_sng,    # datestamp string to add to labels and filename
	'file_root=s'   => \$fle_root,    # filename root (combined with $date_sng, and other)
);

$filetimestamp = $date_sng;
if ($date_sng eq ""){ $filetimestamp = `date +%F_%R`; chomp $filetimestamp; }
print "date_sng: $date_sng and file_root: $fle_root \n";

$thr_num = 0;
$tim_dta_end = 2; # number of variables to be plotted (to expand if start adding more rusage() vars)
                  # setting it to '2' will only plot wallclock seconds.  Setting it higher will plot
                  # more of the variables listed below.

@titles = ("    threads", "     1/t(n)", "    t(wall s)", "  t(user s)", "  t(system s)", "\n");

my $wait = <STDIN>;

my $linect = 0;
while (<>) {
	if ($_ =~ '^#') {
#		print "skipping line $linect: $_\n";
	} else { # split the line on the '|'s into
#		print "\n\nworking on: $_\n";
		($uname, $cmd_ln[$linect],$nco_tim_info[$linect], $nco_vrs_sng,) = split(/\|/,$_,5);
		#my $splitcnt = split(/]/,$_);
		#print "splitcnt = $splitcnt\n";
#debugging only!
#  		print "uname: $uname\n";
#  		print "version: $nco_vrs_sng\n";
#  		print "cmd: $cmd_ln[$linect]\n";
#  		print "timing data: $nco_tim_info[$linect]\n";
	}
	$linect++;
}

print "processed $linect lines\n";

# get OS name that should be the same for all lines:
my $uname_cnt = split(/\s+/,$uname);
$op_sys = $_[0];
print "operating system = $op_sys\n";
$datestamp = $filetimestamp;
chomp $datestamp;
chomp $nco_vrs_sng;

my @L = split(/[ \/]/,$nco_vrs_sng);
$nco_vrs_A = $L[2]; $nco_vrs_B = $L[3];
print "nco_vrs_sng = $nco_vrs_sng and nco_vrs_A = $nco_vrs_A and nco_vrs_B = $nco_vrs_B\n";


for (my $i=0; $i<$linect;$i++) {
	# process the commandline to see how many threads were requested
	if ($cmd_ln[$i] =~ "thr" || $cmd_ln[$i] =~ "mpi") {
#		print "working on $cmd_ln[$i]\n";
		$num_bits = @clin_bits = split /\s/,$cmd_ln[$i]; # split the cmd_ln into ws-delim bits
#		# then look for the thread number
#		print "numbits = $num_bits\n";
		my $notfound = 1;
		my $bit_cnt = 0;
		while ($bit_cnt < $num_bits && $notfound) {
			if ($clin_bits[$bit_cnt] =~ "thr" || $clin_bits[$bit_cnt] =~ "mpi") {
				my @tn = split(/[= ]/,$clin_bits[$bit_cnt]);
				$thr_num = $tn[1];
#				print "threads = $thr_num \n";
				$notfound = 0;
			}
			$bit_cnt++;
		}
	} else {
#		print "line $i [$cmd_ln[$i]] has no thread spec - treat as special case of 0\n";
		$thr_num = 0;
		# yadda yada yadda
	}
	# now process the timing info into %tim_dta{nco_name}{time_type}{bm_run_date?}
	# split the line into nco stanzas
#	print "timing info: $nco_tim_info[$i]\n";
	chomp $nco_tim_info[$i]; chop $nco_tim_info[$i];
#	print "post-chop, timing info: $nco_tim_info[$i]^\n";

	$num_nco_stz = @nco_stz = split(/:/, $nco_tim_info[$i]);
	my $cnt = 0;
	foreach my $chunk (@nco_stz) {
		$chunk =~ s/,/ /g;
		$chunk =~ s/\s+/ /g;
#		print "processed chunk = $chunk\n";
		   @nco_tim_dta = split(/\s+/,$chunk);
		   $nco_name_array[$cnt] = $nco_name = $nco_tim_dta[0];
		my $walltime = $nco_tim_dta[3]; # wall = [0]
		my $realtime = $nco_tim_dta[4]; # real = [1]
		my $usertime = $nco_tim_dta[5]; # user = [2]
		my $systime  = $nco_tim_dta[6]; # sys  = [3]

		# @nco_tim_dta should now have [name][#success][#fail][wall][real][user][sys]
		# so copy the tasty bits into the big array
#		print "i = $i\n";
		if ($thr_num == 0) { $thr_num = 1}
		else {
		$nco_avgs{$nco_name} = 0; # initializes hash
		$tim_dta{$nco_name}[0][$i] = $thr_num;}
		$tim_dta{$nco_name}[1][$i] = $walltime;
		$tim_dta{$nco_name}[2][$i] = $realtime;
		$tim_dta{$nco_name}[3][$i] = $usertime;
		$tim_dta{$nco_name}[4][$i] = $systime;
		#print "for: $nco_tim_dta[0]\nwall = $tim_dta{$nco_name}[0][$linect]\nreal = $tim_dta{$nco_name}[1][$linect]\nuser = $tim_dta{$nco_name}[2][$linect]\nsyst = $tim_dta{$nco_name}[3][$linect]\n\n";
		$cnt++;
	}
}

write_nco_data();
write_gnuplot_cmds();
print "\nexecuting the gnuplot on $cmdfile\n";
system "gnuplot < $cmdfile";
print "\n========================================\nThe benchmark plots should be in:\n  $ps_file\n====\n";

my $mpage ="";my $up4ps_file = "";
$mpage = `which mpage`; chomp $mpage;
if ($mpage =~ /bin/ ){
	$up4ps_file = "4-up_" . $ps_file;
	system "$mpage -4 $ps_file > $up4ps_file";
	print "\n========================================\nThe 4-up benchmark plots should be in:\n  $up4ps_file.\n====\n";
} else {
	print "\n\nIf you install mpage, you can generate 4-up postscript plots by running mpage on $ps_file\n\n";
}

my $ps2pdf = "";
$ps2pdf = `which ps2pdf`; chomp $ps2pdf;
if ($ps2pdf =~ /bin/ ){
	my $pdf_file = $ps_file;
	$pdf_file =~ s/\.ps/\.pdf/;
	if ($mpage =~ /bin/ ) { $ps_file = $up4ps_file; }
	system "$ps2pdf $ps_file > $pdf_file";
	print "\n========================================\nThe PDF'ed benchmark plots should be in:\n  $pdf_file\n====\n";
} else {
	print "\n\nIf you install ps2pdf, this script can convert the postscript plots to PDF.\n\n";
}



sub write_nco_data {
# need to write one datafile for each nco of the form:
# thread   wall  real  user  sys   and   other   rusage   params    spread    across    the    top
# and then 1 gnuplot command file to read them all in and plot them
	#open the file

	for (my $r=0; $r<$num_nco_stz;$r++) {
		$nco_name = $nco_name_array[$r];
		my $datafile = "$nco_name.$filetimestamp.data";
		print "datafile name: $datafile\n";
		open(DAT, ">$datafile") or die "\nUnable to open command file '$datafile' in current dir - check permissions on it\nor the directory you are in.\n stopped";
		for (my $i = 0; $i <= $tim_dta_end; $i++){ print DAT $titles[$i];}
		print DAT "\n";

# what we want to do is 1st get an average for the case of thr/prc=1, then use that value to normalize
# the rest of the values to, and take the inverse of that normalized value to plot so the line goes
# up to the right (hopefully). so need to
# 1) generate avg for thr=1 for each of the nco slabs
# 2) generate normalized vlaues for each nco slab along the
# 3) invert them, write THOSE values to the data file and then everything's the same.
# 		could include the unmodified vlaues as well I guess.
		my $sum = 0; my $N=0;
		for (my $i=0; $i<$linect; $i++){ # calc the avg
			if ($tim_dta{$nco_name}[0][$i] == 1) {
				print "val= $tim_dta{$nco_name}[1][$i]\n";
				$sum += $tim_dta{$nco_name}[1][$i]; $N++;
			}
		}
	 	$sngl_thr_avg=2;
		if ($N > 0 && $sum > 0){
			$sngl_thr_avg = $sum / $N;
			$nco_avgs{$nco_name} = $sngl_thr_avg; # record for label in gnuplot commands.
			print "$nco_name: avg=$sngl_thr_avg (where sum: $sum, N: $N\n";
		} else {
			print "\n\nWarning: for $nco_name, there were no values with thr=1\n";
		}
#	in $tim_dta{$nco_name}[A][B], A=0 ->threads/processes, A=1 -> wallclock seconds
#	                              B=values from across the tests (goes from 0-># lines processed
		for (my $i=0; $i<$linect; $i++) {
			printf DAT "%10d ",$tim_dta{$nco_name}[0][$i]; # print the # thr/procs
			# print the values for each thr/proc; ends up like
			# 1 73.4
			# 1 75.6 etc
			for (my $e=1; $e<$tim_dta_end; $e++) {
				my $nrmlz = 0;
				if ($tim_dta{$nco_name}[$e][$i] > 0 ) {
					$nrmlz = 1/($tim_dta{$nco_name}[$e][$i] / $sngl_thr_avg);
				}
				printf DAT "%10.3f   %10.3f", $nrmlz, $tim_dta{$nco_name}[$e][$i];
				# (1/($tim_dta{$nco_name}[$e][$i] / $sngl_thr_avg))
			}
			print DAT "\n";
		}
	}
}


# now munge into appro formats
# 1st write the gnuplot commands to read in and plot the file - should be a separate fnc().
sub write_gnuplot_cmds {
	# need to write 1 command file that plots all the files to a single postscript file
	#open file
#	my $filetimestamp = `date +%F_%R`; chomp $filetimestamp;
	$cmdfile = "nco_bm.$filetimestamp.gnuplot";
	$ps_file = $fle_root . "_" . $filetimestamp . ".ps";
	print "cmdfile name: $cmdfile\n\n";
	open(CMD, ">$cmdfile") or die "\nUnable to open command file '$cmdfile' in current dir - check permissions on it\nor the directory you are in.\n stopped";
	print CMD << "HEADER";
# auto-generated data for nco benchmark plots to postscript
#  created $filetimestamp
# called from this perl script as: system ("gnuplot $cmdfile");
# input file has the format:<nco>.datestamp.data
set xrange [0:9]
# make sure that axis starts at 0
set yrange [0:3.5]
set xlabel "Number of threads or processes"
set ylabel "1/time (normalized to 1 thread)
set key box
set terminal postscript landscape color
set output '$ps_file'
HEADER

	# now write the plot cmds to plot each column
	for (my $r=0; $r< $num_nco_stz; $r++){
		my $tail = ", \\\n";
		#print "set output 'bench.$nco_name_array[$r].ps'\n"
#		print "\n\n";
		print CMD "set title \"$nco_name_array[$r] on $op_sys using multiple threads / processes\\nfor NCO version: $nco_vrs_sng, on $filetimestamp\"\n";

		my $datafile = "$nco_name_array[$r].$filetimestamp.data";
		for (my $e=0; $e<($tim_dta_end-1);$e++) {
			my $plot_str = "plot";
			if ($e > 0) {$plot_str = "";}
			if ($e > ($tim_dta_end-3)) { $tail = "\n"; }
			my $col = $e + 2;
			print CMD "m=0;b=0\nf(x) = m*x + b\nfit [0:8] f(x) \"$datafile\" using 1:2 via m,b\n";
			# note that in the printf-like formatting below, the var has to immediately follow the format
			# ie: \"%d\", dvar, \"%f\", fvar, \"%s\", svar
			# it is NOT like printf's "%d %f %s", dvar, fvar, svar
			print CMD "unset label\nset label \"Scaling = %4.3f \", m , \"(Avg s @ 1 thr: %5.2f)\", $nco_avgs{$nco_name_array[$r]}  at 1, 2.5\n";
			print CMD "$plot_str '$datafile' using 1:$col title \"$titles[$col - 1]\", m*x+b title \"lin fit\" \n#new plot\n"; # :$lbl with labels center offset 0,1
		}
	}
	close (CMD);
}

# grab the nco version and conmogrify it into something like: "3.0.1 / 20051003"
# just requires a string variable to absorb the string returned
sub vrs_sng_get{
	my @nco_vrs;
	my $tmp_sng = `ncks --version  2>&1 |  grep 'ncks version'`; # long string sep by a newline.
	$tmp_sng =~ s/\n/ /g;
	my @tmp_lst = split (/\s+/, $tmp_sng);
	$nco_vrs[0] = $tmp_lst[4];
	$nco_vrs[0] =~ s/"//g;
	$nco_vrs[1] = $tmp_lst[scalar(@tmp_lst) - 1];
	# print "NCO release version: $nco_vrs[0], NCO date version: $nco_vrs[1]\n";
	$tmp_sng = "$nco_vrs[0]" . " / " . "$nco_vrs[1]";
	return $tmp_sng;
}




