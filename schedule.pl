#!/usr/bin/perl

# HTML Course schedule generator.
# Andrew Myers, January 2010.
# Modified by Steve Marschner for CS6640, August 2012.
# ...and further by Steve Marschner for CS4620, August 2014.

use strict;

my $cr = "\n";
my %cfg;

my %wd_index;

my $weekdays = 'MTWRF';

my $logo = '';

for (my $i = 0; $i <= 4; $i++) {
    $wd_index{substr($weekdays, $i, 1)} = $i + 1;
}

my @readings, my @notes, my @exams;
my @meetings, my @homeworks;
my @holidays, my @special_dates;
my %course_topics;

open (CONFIG, "schedule.cfg");
while (<CONFIG>) {
    chomp;

    my @fields = split /\s*:\s*/, $_, 2;
    if (substr($_, 0, 1) eq '#') { next; }
    if ($#fields == 0) {
	print "Syntax error: $_";
	exit 1;
    }
    if ($#fields == 1 && $fields[1] eq '') {
	my $s = $_;
	while (<CONFIG>) {
	    my $line = $_;
	    chomp;
	    if ($_ eq '.') { last; }
	    $s .= $line;
	}
	@fields = split /\s*:\s*/, $s, 2;
    }

    if ($fields[0] eq 'meeting') {
	my @data = split /;/, $fields[1];
	push @meetings, $data[0];
	$notes[$#meetings] = $data[1];
	$readings[$#meetings] = $data[2];
    } elsif ($fields[0] eq 'holiday') {
	push @holidays, $fields[1];
    } elsif ($fields[0] eq 'special_dates') {
	@special_dates = split /\s*,\s*/, $fields[1];
    } elsif ($fields[0] eq 'homework') {
	push @homeworks, $fields[1];
    } elsif ($fields[0] eq 'exam') {
	push @exams, $fields[1];
    } elsif ($fields[0] eq 'topic') {
	$course_topics{$#meetings + 1} = $fields[1];
    } else {
	$cfg{$fields[0]} = $fields[1];
    }
}

# check_holiday($m,$d) is the name of the holiday at date $m/$d, or '' if no holiday then.
sub check_holiday {
   (my $m, my $d) = @_;
   foreach my $h (@holidays) {
     (my $date, my $explain) = split / /, $h, 2;
     my ($hm, $hd) = split m@/@, $date;
     if ($hm == $m && $hd == $d) {
	return $explain;
     }
   }
   return '';
}

# check_special($m,$d) is the name of the special event at date $m/$d, or '' if none
sub check_special {
   (my $m, my $d) = @_;
   foreach my $h (@special_dates) {
     (my $date, my $explain) = split / /, $h, 2;
     my ($hm, $hd) = split m@/@, $date;
     if ($hm == $m && $hd == $d) {
	return $explain;
     }
   }
   return '';
}

sub fix_blank {
    if ($_[0] eq '') { 
	return '&nbsp;';
    } else {
	return $_[0];
    }
}

sub link_hw {
    (my $hw, my $link) = @_;
    if ($link eq '') {
	return $hw;
    } else {
	return  '<a href="#' . $link . '">' . $hw . '</a>';
    }
}

my @meeting_days; # the indices of the days of the week that the class meets

my $meeting_days = $cfg{'meeting_days'};
for (my $i = 0; $i < length($meeting_days); $i++) {
    $meeting_days[$i] = index($weekdays, substr($meeting_days, $i, 1));
}
my $weekday = index('MTWRF', $cfg{'start_weekday'});
my $wi = -1;
for (my $i = 0; $i <= $#meeting_days; $i++) {
    if ($weekday == $meeting_days[$i]) {
	$wi = $i;
    }
}
if ($wi < 0) {
    printf STDERR "Could not find start weekday $cfg{'start_weekday'} inside $cfg{'dotw'}", $cr;
}

my @holidays = ();
my $year = $cfg{'year'};

my @ditm = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
my @months = (0, "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

if ($year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0)) {
#Leap year in Gregorian calendar. Good until AD 8000.
    $ditm[2] = 29;
}

sub compare_date {
    (my $m1, my $d1, my $m2, my $d2) = @_;
    if ($m1 < $m2) { return -1; }
    if ($m1 > $m2) { return 1; }
    if ($d1 < $d2) { return -1; }
    if ($d1 > $d2) { return 1; }
    return 0;
}

sub insert_course_topics {
    (my $mi) = @_;

    if (defined($course_topics{$mi})) {
	my $topic = $course_topics{$mi};
	# print STDERR "$m/$d $topic$cr";
	print "<tr class=header>$cr";
	print "  <td colspan=6>$topic</td>$cr";
	print "</tr>$cr";
	return 1;
    }
    return 0;
}

sub insert_exams {
    (my $prevm, my $prevd, my $month, my $day) = @_;
    my $saw_exam = 0;
    foreach my $e (@exams) {
	(my $date, my $info) = split /;/, $e, 2;
	(my $m, my $d) = split m@/@, $date;
	if (&compare_date($prevm, $prevd, $m, $d) < 0 &&
	    &compare_date($m, $d, $month, $day) <= 0) {
	    print "<tr class=exam>$cr";
	    print "  <td class=day>$d</td><td class=month>$months[$m]</td>";
	    print "  <td>$info</td>";
	    print "  <td>&nbsp;</td>";
	    print "  <td class=projdue>&nbsp;</td>";
	    print "</tr>$cr";
	    $saw_exam = 1;
	}
    }
    return $saw_exam;
}

sub do_homeworks {
    (my $prevm, my $prevd, my $month, my $day) = @_;
    my $result;
    foreach my $h (@homeworks) {
	(my $name, my $link, my $out_date, my $due_date) = split /;/, $h;
	(my $om, my $od) = split m@/@, $out_date;
	(my $dm, my $dd) = split m@/@, $due_date;
	if (&compare_date($prevm, $prevd, $dm, $dd) < 0 &&
	    &compare_date($dm, $dd, $month, $day) <= 0) {
	    if ($result ne '') { $result .= ', '; }
	    $result .= &link_hw ($name, $link) . ' due';
	    if ($dm != $month || $day != $dd) {
		$result .= " $dm/$dd";
	    }
	}
	if (&compare_date($prevm, $prevd, $om, $od) < 0 &&
	    &compare_date($om, $od, $month, $day) <= 0) {
	    if ($result ne '') { $result .= ', '; }
	    $result .= &link_hw ($name, $link) . ' out';
	    if ($om != $month || $day != $od) {
		$result .= " $om/$od";
	    }
	}
    }
    return $result;
}


# srm -- Modified to produce only the table, as an HTML fragment suited to SSI

#print '<html>
#<head>
#    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
#    <title>', $cfg{'coursename'}, ' Schedule</title>
#    <link rel="stylesheet" type="text/css" href="', $cfg{'style'}, '">
#</head>
#';

#print $cfg{'logo'};

#print '<body>

#<h1><a href="', $cfg{'homepage'}, '">', $cfg{'coursename'}, '</a> ', $cfg{'semester'}, ' ', $year, ' Course Schedule</h1>

#',
#$cfg{'heading'};

print
#'<div align="center">
#<table class=schedule border="1" cellpadding="2" cellspacing="0">
'<table class=sched cellpadding="0" cellspacing="0">
  <tr>
    <th class=month colspan=2>date</td>
    <th>topic</td>
    <th>reading</td>
    <th class=projdue>assignments</td>
  </tr>', $cr;

my $month = $cfg{'start_month'};
my $day = $cfg{'start_day'};

my $mi = 0;
my $ni = 0;
my $leci = 1;
my $prevm, my $prevd; # previous date appearing on schedule (could be holiday)
my $prevmm, my $prevmd; # previous date of an actual meeting.

############### main loop ################


while ($month < $cfg{'end_month'} || $day < $cfg{'end_day'}) {
    &insert_exams($prevm, $prevd, $month, $day);
    my $holiday = &check_holiday($month, $day);
    my $odd_week = ($ni % 6 == 0 || $ni % 6 == 1 || $ni % 6 == 5);  # TODO needs to be adjusted depending on calendar
    if ($holiday ne '') {
	if ($odd_week) {
	    print '<tr class="dis odd">', $cr;
	} else {
	    print '<tr class="dis evn">', $cr;
	}
	print "  <td class=day>$day</td><td class=month>$months[$month]</td>",$cr;
	print "  <td>&mdash;$holiday&mdash;</td>",$cr;
	print "  <td>&nbsp;</td>";
	print "  <td class=projdue>&nbsp;</td>";
	print "</tr>", $cr;
	$ni++;
    } else {
	&insert_course_topics($mi);
	my $leci_pad = $leci;
	while (length($leci_pad) < 2) { $leci_pad = '0'. $leci_pad; }
	if ($odd_week)  {  
	    print '<tr class="odd">', $cr;
	} else {
	    print '<tr class="evn">', $cr;
	}
	my $unnumbered = 0;
	my $topic = &fix_blank($meetings[$mi]);
	#if ($topic =~ m/^Recitation:/) {
	#    $unnumbered = 1;
	#}
	#if ($unnumbered) {
	#    print "  <td>&nbsp;</td>$cr";
	#} else {
	#    print "  <td>$leci</td>$cr";
	#}
	print "  <td class=day>$day</td><td class=month>$months[$month]</td>",$cr;
	my $note = $notes[$mi];
	if ($note ne '') {
	    my @notefiles = split /&/, $note;
	    foreach my $notefile (@notefiles) {
		$notefile =~ s/#/$leci_pad/;
		$topic  = "$topic <a href=\"$notefile\">slides</a>",$cr;
	    }
	}
	print "  <td>$topic</td>$cr";
	my $reading = &fix_blank($readings[$mi]);
	if (!($reading =~ /^</)) {
	    $reading =~ s/-/\&ndash;/;
	}
	print "  <td>$reading</td>",$cr;
	my $extra = &do_homeworks($prevmm, $prevmd, $month, $day);
	my $special = &check_special($month, $day);
	if ($special ne '') {
	    $extra .= ' <span class=special_date>(' . $special . ')</span>';
	}
	if ($extra eq '') {
	    print "  <td class=projdue>&nbsp;</td>$cr";
	} else {
	    print "  <td class=projdue>$extra</td>$cr";
	}
	print "</tr>$cr";
	$mi++;
	$ni++;
	if (!$unnumbered) { $leci++; }
	$prevmm = $month; $prevmd = $day;
    }
    $prevm = $month;
    $prevd = $day;

    $wi++;
    if ($wi > $#meeting_days) { $wi = 0; }
    my $nwd = $meeting_days[$wi];
    $day += ($nwd - $weekday);
    if ($nwd - $weekday < 0) { $day += 7; }
    $weekday = $nwd;

    if ($day > $ditm[$month]) {
	$day -= $ditm[$month];
	$month++;
    }
}

&insert_course_topics($mi);
&insert_exams($prevm, $prevd, $cfg{'end_semester_month'},
    $cfg{'end_semester_day'});

if ($mi <= $#meetings) {
    print STDERR "Warning: the following lectures could not be scheduled:$cr";
    for (my $i = $mi; $i <= $#meetings; $i++) {
	print STDERR "  $meetings[$i]$cr";
    }
}

print '</table>', $cr;
print '</html>', $cr;

exit 0;
