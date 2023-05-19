#!/usr/bin/perl
use utf8;

# Name : Laszlo Kiss
# Date : 01-20-08
# Divine Office Kalendarium
package horas;

#1;
#use warnings;
#use strict fs";
#use strict "subs";
#use warnings FATAL=>qw(all);

use POSIX;
use FindBin qw($Bin);
use CGI;
use CGI::Cookie;
use CGI::Carp qw(fatalsToBrowser);
use File::Basename;
use Time::Local;

#use DateTime;
use locale;
use lib "$Bin/..";
use DivinumOfficium::Main qw(liturgical_color);
use DivinumOfficium::Directorium qw(dirge);
use DivinumOfficium::Date qw(ydays_to_date);
$error = '';
$debug = '';

#*** common variables arrays and hashes
#filled  getweek()
our @dayname;    #0=Adv|{Nat|Epi|Quadp|Quad|Pass|Pent 1=winner|2=commemoratio/scriptura

#filled by getrank()
our $winner;     #the folder/filename for the winner of precedence
our $commemoratio;    #the folder/filename for the commemorated
our $scriptura;       #the folder/filename for the scripture reading (if winner is sancti)
our $commune;         #the folder/filename for the used commune
our $communetype;     #ex|vide
our $rank;            #the rank of the winner
our $vespera;         #1 | 3 index for ant, versum, oratio

#filled by precedence()
our %winner;          #the hash of the winner
our %commemoratio;    #the hash of the commemorated
our %scriptura;       #the hash for the scriptura
our %commune;         # the hash of the commune
our $rule;                                    # $winner{Rank}
our $communerule;                             # $commune{Rank}
our $duplex;                                  #1= simplex 2=semiduplex, 3=duplex 0=rest
                                              #4 = duplex majus, 5=duplex II class 6=duplex I class 7=higher
our ($initia);
our $version = 'Rubrics 1960';

require "$Bin/do_io.pl";
require "$Bin/horascommon.pl";
require "$Bin/dialogcommon.pl";
require "$Bin/webdia.pl";
require "$Bin/setup.pl";

sub kalendar_entry {
  my($date,$ver,$compare) = @_;

  $winner = $commemoratio = $scriptura = $commemoratio1 = '';
  %winner = %commemoratio = %scriptura = %commemoratio1 = {};
  $version = $ver;
  $initia = 0;
  $laudesonly = '';
  precedence($date);    #for the daily item
  my @c1 = split(';;', $winner{Rank});
  my @c2 =
    (exists($commemoratio{Rank})) ? split(';;', $commemoratio{Rank})
    : (
    exists($scriptura{Rank})
      && ($c1[3] !~ /ex C[0-9]+[a-z]*/i
      || ($version =~ /trident/i && $c1[2] !~ /vide C[0-9]/i))
    ) ? split(';;', "Scriptura: $scriptura{Rank}")
    : (exists($scriptura{Rank})) ? split(';;', "Tempora: $scriptura{Rank}")
    : splice(@c2, @c2);
  my $smallgray = "1 maroon";
  my($c1,$c2) = ('','');

  if (@c1) {
    my($h1,$h2) = split('~', setheadline($c1[0], $c1[2]));
    $c1 = "<B>".setfont(liturgical_color($c1[0], $c1[3]), $h1)."</B>"
        . setfont($smallgray, "&nbsp;&nbsp;$h2");
    $c1 =~ s/Hebdomadam/Hebd/i;
    $c1 =~ s/Quadragesima/Quadr/i;
  }

  if (@c2) {
    my($h1,$h2) = split('~', setheadline($c2[0], $c2[2]));
    $c2 = "<I>".setfont(liturgical_color($c2[0], $c2[3]), $h1)."</I>"
        . setfont($smallgray, "&nbsp;&nbsp; $h2");
  }
  if ($winner =~ /sancti/i) { ($c2, $c1) = ($c1, $c2); }

  if (dirge($version, 'Laudes', $day, $month, $year)) { $c1 .= setfont($smallblack, ' dirge'); }
  if ($version !~ /1960/ && $initia) { $c1 .= setfont($smallfont, ' *I*'); }

  if (!$c2 && $dayname[2]) {
    $c2 = setfont($smallblack, $dayname[2]);
  } elsif (!$c1 && $dayname[2]) {
    $c1 = setfont($smallblack, $dayname[2]);
  }

  if ($version !~ /1955|1960|Monastic/ && $winner{Rule} =~ /\;mtv/i) {
    $c2 .= setfont($smallblack, ' m.t.v.');
  }

  if ( $version !~ /1960|Monastic/
    && $winner =~ /Sancti/
    && exists($winner{Lectio1})
    && $winner{Lectio1} !~ /\@Commune/i
    && $winner{Lectio1} !~ /\!(Matt|Mark|Luke|John)\s+[0-9]+\:[0-9]+\-[0-9]+/i)
  {
    $c2 .= setfont($smallfont, " *L1*");
  }
  if ($compare) {
    $c2 ||= '_';
  }
  return ($c1,$c2);
}

if (-e "$Bin/monastic.pl") { require "$Bin/monastic.pl"; }
binmode(STDOUT, ':encoding(utf-8)');
$q = new CGI;

#*** get parameters
my $compare =  strictparam('compare') || 0;
my $officium = strictparam('officium') || 'officium.pl';

# return to Compare version iff $compare
# except there is no P Compare version
if ($compare)
{
  $officium = "C$officium" unless $officium =~ /^[PC]/;
}
else
{
  $officium =~ s/^C//;
}

# use the right date arg
my $date_arg = $officium =~ /Pofficium/? 'date1': 'date';

my $officium_name = $officium =~ /missa/ ? 'missa' : 'horas';
getini("horas");    #files, colors

# $datafolder =~ s/horas$/missa/ if ($officium_name =~ /missa/);

$date1 = strictparam('date1');
$browsertime = strictparam('browsertime');
$Readings = strictparam('readings');

$setupsave = strictparam('setup');
loadsetup($setupsave);

$ckname = ($officium_name =~ /officium/) ? "${officium_name}go" : ($Ck) ? "${officium_name}gc" : "${officium_name}g";
$csname = ($Ck) ? 'generalc' : 'general';

if (!$setupsave) {
  getcookies("${officium_name}p", 'parameters');
  getcookies($ckname, $csname);
}

set_runtime_options($csname); #$expand, $version, $lang2
set_runtime_options('parameters'); # priest, lang1 ... etc

#*** saves parameters
$setupsave = savesetup(1);
$setupsave =~ s/\r*\n*//g;

$hora = '';
$odate = $date1;

(my $command = strictparam('command')) =~ s/^pray//;
if ($command =~ /(Ante|Matutinum|Laudes|Prima|Tertia|Sexta|Nona|Vespera|Completorium|Past)/i) {
  $command = "pray" . ($compare ? $1 : $command); # Cofficium can't use Plures
}


my @ver = ();
push(@ver, strictparam('version') || strictparam('version1') || 'Rubrics 1960');
push(@ver, strictparam('version2') || 'Divino Afflatu') if ($compare);

$testmode = strictparam('testmode');
my($month,$day,$year) = split('-', strictparam($date_arg) || gettoday());
$kmonth = strictparam('kmonth') || $month;
$kyear = strictparam('kyear') || $year;
#entries 13 (placeholder) and 14 (actually) are added for the Whole Year (Totum) Option
@monthnames = (
  'Januarius', 'Februarius', 'Martius', 'Aprilis', 'Majus', 'Junius',
  'Julius', 'Augustus', 'September', 'October', 'November', 'December', '', ''
);
@monthlength = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, '', 365);
$title = "Ordo: $monthnames[$kmonth-1] $kyear";
@daynames = qw/Dom. F.II F.III F.IV F.V F.VI Sabb./;

#*** generate HTML
htmlHead($title, 2);
print << "PrintTag";
<BODY VLINK=$visitedlink LINK=$link BACKGROUND="$htmlurl/horasbg.jpg" >
<script>
// https redirect
if (location.protocol !== 'https:' && (location.hostname == "divinumofficium.com" || location.hostname == "www.divinumofficium.com")) {
    location.replace(`https:\${location.href.substring(location.protocol.length)}`);
}
</script>
<FORM ACTION="kalendar.pl" METHOD=post TARGET=_self>
<INPUT TYPE=HIDDEN NAME=setup VALUE="$setupsave">
<INPUT TYPE=HIDDEN NAME=date1 VALUE="$date1">
<INPUT TYPE=HIDDEN NAME=kmonth VALUE=$kmonth>
<INPUT TYPE=HIDDEN NAME=date VALUE="$odate">
<INPUT TYPE=HIDDEN NAME=command VALUE="$command">
<INPUT TYPE=HIDDEN NAME=officium VALUE="$officium">
<INPUT TYPE=HIDDEN NAME=browsertime VALUE="$browsertime">
<INPUT TYPE=HIDDEN NAME=compare VALUE="$compare">
<INPUT TYPE=HIDDEN NAME=readings VALUE="0">
PrintTag

print do { # print headline
  my $vers = $ver[0];
  $vers .= " / $ver[1]" if $compare;

  my $output = << "PrintTag";
<H1>
<FONT COLOR=MAROON SIZE=+1><B><I>Divinum Officium</I></B></FONT>&nbsp;
<FONT COLOR=RED SIZE=+1>$vers</FONT>
</H1>
<P ALIGN=CENTER>
<FONT COLOR=MAROON SIZE=+1><B><I>Ordo $monthnames[$kmonth-1] A. D.</I></B></FONT>&nbsp;
<LABEL FOR=kyear CLASS=offscreen>Year</LABEL>
<INPUT TYPE=TEXT ID=kyear NAME=kyear VALUE="$kyear" SIZE=4>
<A HREF=# onclick="prevnext(-1)">&darr;</A>
<INPUT TYPE=submit NAME=SUBMIT VALUE=" " onclick="document.forms[0].submit();">
<A HREF=# onclick="prevnext(1)">&uarr;</A>
&nbsp;&nbsp;&nbsp;<A HREF=# onclick=\"setkm(14)\">Totus</A>
</P><P ALIGN=CENTER>
PrintTag

  my @mmenu;

  push(@mmenu, "<A HREF=# onclick=\"setkm(-1)\">«</A>\n") if $kmonth == 1;
  for ($i = 1; $i <= 12; $i++) {
    $mn = substr($monthnames[$i - 1], 0, 3);
    $mn = "<A HREF=# onclick=\"setkm($i)\">$mn</A>\n" unless $i == $kmonth;
    push(@mmenu, $mn)
  }
  push(@mmenu, "<A HREF=# onclick=\"setkm(13)\">»</A>\n") if $kmonth == 12;

  $output . join('&nbsp;' x 3, @mmenu)
};

print << "PrintTag";
</P><P ALIGN=CENTER>
<TABLE BORDER=$border WIDTH=90% CELLPADDING=3>
<TR><TH>Dies</TH><TH>de Tempore</TH><TH>Sanctorum</TH><TH>d.h.</TH></TR>
PrintTag
$to = $monthlength[$kmonth - 1];
if (($kmonth == 2 || $kmonth == 14) && leapyear($kyear)) { $to++; } # in February or for the whole year (14)

for ($cday = 1; $cday <= $to; $cday++) {
	my $date1 = "";
	my $d1 = "";
	if($kmonth < 13) {					# loop over the days of a single month
		$date1 = sprintf("%02i-%02i-%04i", $kmonth, $cday, $kyear);
		$d1 = sprintf("%02i", $cday);
	} else {										# loop over all days of the year
		my ($yday, $ymonth, $yyear) = ydays_to_date($cday, $kyear);
		$date1 = sprintf("%02i-%02i-%04i", $ymonth, $yday, $yyear);
		$d1 = sprintf("%02i", $yday);
		if ($yday == 1) {					# add extra headline at the start of a new month
			my $monthtitle = "$monthnames[$ymonth-1] $kyear";
			print << "PrintTag";
<TR><TH COLSPAN="4" ALIGN=CENTER><A HREF=# onclick=\"setkm($ymonth)\">$monthtitle</A></TH></TR>
PrintTag
		}
	}
  my(@c1,@c2) = ((),());
  for (0..$compare) {
    my($c1,$c2) = kalendar_entry($date1,$ver[$_],$compare);
    push(@c1,$c1); push(@c2,$c2);
  }
  my $c1 = join('<BR>', @c1);
  my $c2 = join('<BR>', @c2);
  print << "PrintTag";
<TR><TD ALIGN=CENTER><A HREF=# onclick="callbrevi('$date1');">$d1</A></TD>
<TD>$c1</TD>
<TD>$c2</TD>
<TD ALIGN=CENTER>$daynames[$dayofweek]</TD>
</TR>
PrintTag
}
print << "PrintTag";
</TABLE><BR>
PrintTag
print htmlInput('version1', $ver[0], 'options', 'versions', , "document.forms[0].submit()");
if ($compare) {
  print htmlInput('version2', $ver[1], 'options', 'versions', , "document.forms[0].submit()");
}
print "<P ALIGN=CENTER>\n" . bottom_links_menu() . "</P>\n";

# $testmode = 'Regular' unless $testmode;
# print option_selector("testmode", "document.forms[0].submit();", $testmode, qw(Regular Seasonal));
if ($savesetup > 1) { print "&nbsp;&nbsp;&nbsp;<A HREF=# onclick=\"readings();\">Readings</A>"; }
if ($error) { print "<P ALIGN=CENTER><FONT COLOR=red>$error</FONT></P>\n"; }
if ($debug) { print "<P ALIGN=center><FONT COLOR=blue>$debug</FONT></P>\n"; }
print << "PrintTag";
</FORM>
PrintTag
if ($Readings) { Readings(); }
if ($compare) {
  print '<P ALIGN=CENTER><A HREF="#" onclick="callkalendar(0)">Single Calendar</A>';
} else {
  print '<P ALIGN=CENTER><A HREF="#" onclick="callkalendar(1)">Compare Calendars</A>'; 
}
print "\n</BODY></HTML>";

#*** horasjs()
# javascript functions called by htmlhead
sub horasjs {
  print << "PrintTag";

<SCRIPT TYPE='text/JavaScript' LANGUAGE='JavaScript1.2'>

function callbrevi(date) {
  if (!date) date = '';
  var officium = "$officium";
  if (!officium || !officium.match('.pl')) officium = "officium.pl";
  document.forms[0].$date_arg.value = date;
  document.forms[0].action = ((officium.match(/missa/)) ? '../missa/' : '' ) + officium;
  document.forms[0].target = "_self"
  document.forms[0].submit();
}

//calls compare kalendar
function callkalendar(c) {
  document.forms[0].action = 'kalendar.pl';
  document.forms[0].compare.value = c;
  document.forms[0].target = "_self"
  document.forms[0].submit();
}

function prevnext(d) {
  document.forms[0].kyear.value = parseInt(document.forms[0].kyear.value) + d;
}

function setkm(km) {
  document.forms[0].kmonth.value = km;
  if (km == -1) {
    document.forms[0].kmonth.value = 12;
    document.forms[0].kyear.value--;
  }
  else {
    if (km == 13) {
      document.forms[0].kmonth.value = 1;
      document.forms[0].kyear.value++;
    }
  }
  document.forms[0].submit();
}

function setky(ky) {
  document.forms[0].kyear.value = ky;
  document.forms[0].submit();
}

function readings() {
  document.forms[0].readings.value = 1;
  document.forms[0].submit();
}
</SCRIPT>
PrintTag
}

sub Readings {
  my @months = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  my @days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  my $savehora = $hora;
  $hora = 'Laudes';
  print "<TABLE>\n";
  print "<TR><TD COLSPAN=3 ALIGN=CENTER><I>Readings $kmonth-$kyear</I></TD></TR>\n";

  for (my $kday = 1; $kday <= $months[$kmonth - 1]; $kday++) {
    my $date1 = sprintf("%02i-%02i-%04i", $kmonth, $kday, $kyear);
    $d1 = sprintf("%02i", $kday);
    $winner = $commemoratio = $scriptura = '';
    %winner = %commemoratio = %scriptura = {};
    $initia = 0;
    precedence($date1);    #for the daily item
    my $line = "$d1 $days[$dayofweek] : ";
    if ($dayofweek == 0) { $line = "<B>$line</B>"; }
    $line = "<TR><TD>$line</TD><TD>";

    foreach $i (1, 2, 3) {
      my $w = lectio($i, 'Latin');
      if ($w =~ /!([0-9]*\s*[a-z]+ [0-9]+:[0-9]+)/i) { $line .= "$1, " }
    }
    print "$line</TD><TD><I>$dayname[1]</I><\TD><\TR>>\n";
  }
  print "<\TABLE>\n";
  $hora = $savehora;
}
