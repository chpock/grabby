# grabby - main app file
#
# Copyright (c) 2016 by Konstantin Kushnir <chpock@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set gui [expr { ![catch { package require Tk }] }]
proc gui args { if { $::gui } { tailcall {*}$args } }

package require TclOO
package require http
package require zlib; # for http
package require tdom
package require uri
package require md5
package require tdbc
package require tdbc::sqlite3
package require twapi
package require procarg
package require json
package require tls
package require ckl::mobphone
package require ckl::tdbc
package require ckl::http
gui package require ckl::tk

::http::config -useragent "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
::http::config -accept "text/xml,application/xml,application/rss+xml,application/rdf+xml,application/atom+xml"

source  [file join [file dirname [info script]] common.tcl]
source  [file join [file dirname [info script]] classCommon.tcl]
source  [file join [file dirname [info script]] classRequest.tcl]
source  [file join [file dirname [info script]] classCore.tcl]
source  [file join [file dirname [info script]] classBB.tcl]
source  [file join [file dirname [info script]] classCatalog.tcl]
source  [file join [file dirname [info script]] classMessage.tcl]

gui source [file join [file dirname [info script]] guiCommon.tcl]
gui source [file join [file dirname [info script]] guiCore.tcl]
gui source [file join [file dirname [info script]] guiBB.tcl]

set verbose 1

proc ::checkonline::log { id {detail {}} } {
  switch -- $id {
    INFO-REQUESTOK    { ::log "Проверка на 'онлайн' пройдена успешно." }
    INFO-TIMER        { ::log "Следующая проверка на 'онлайн' поставлена в очередь." }
    ERROR-REQUESTDATA { ::log "\fRПровека на 'онлайн' не удачна: получен мусор." }
    ERROR-REQUESTCODE { ::log "\fRПровека на 'онлайн' не удачна: ошибка в статусе." }
    INFO-REQUESTCALLBACK { ::log "Online check callback: $detail" -file }
  }
#    default {
#      ::log "$id[expr { $detail eq "" ? "" : $detail }]"
#    }
}

proc ::ckl::http::log { id {detail {}} } {
}

proc ::proxylist::log { id {detail {}} } {
  switch -- $id {
    INFO-FORCEBAN    { ::log "Принудительная смена прокси." -obj [$::core bb [lindex $detail 0]] }
    INFO-FOUNDNEW    { ::log "Найден новый прокси." -obj [$::core bb [lindex $detail 0]] }
    INFO-STARTUPDATE { ::log "Старт обновления прокси." }
    INFO-STARTCHECK  { ::log "Старт проверки прокси." }
    ERROR-UPDATEMOD  { ::log "\fRВнутренняя ошибка обновления модуля \fr'\fR[lindex $detail 0]\fr'" }
    INFO-REQPARSEGOT { ::log "Найдены прокси модуля '[lindex $detail 0]' - [lindex $detail 1] шт." }
  }
#    default {
#      ::log "$id[expr { $detail eq "" ? "" : $detail }]" -file
#    }
}

proc log { msg {args {
  {-file switch}
  {-clearfile switch}
  {-obj string}
}}} {
  global W

  if { $opts(-obj) eq "" } {
    if { [catch [list uplevel 1 {self}] opts(-obj)] } {
      set opts(-obj) $::core
    }
  }
  if { !$opts(-file) } {
    if { !$::gui } {
      if { [info object class $opts(-obj)] eq "::MessageClass" } {
        set opts(-obj) [$opts(-obj) parent]
      }
      if { [info object class $opts(-obj)] in {"::CatalogClass" "::InitClass"} } {
        set opts(-obj) [$opts(-obj) parent]
      }
      if { [info object class $opts(-obj)] eq "::BBClass" } {
        set msg "\fW\[\fd[$opts(-obj) id]\fW\]\fd $msg"
      } {
        set msg "\fW\[\fdcore\fW\]\fd $msg"
      }
		  cputs $msg
    } {
      if { [info object class $opts(-obj)] eq "::MessageClass" } {
        set opts(-obj) [$opts(-obj) parent]
      }
      if { [info object class $opts(-obj)] in {"::CatalogClass" "::InitClass"} } {
        set opts(-obj) [$opts(-obj) parent]
      }
      if { [info object class $opts(-obj)] eq "::BBClass" } {
        set f $W([$opts(-obj) id],log)
      } {
        set f $W(core,log)
      }
		  cputs $f $msg
    }
  }
  if { $opts(-clearfile) } {
    catch { file delete ./spider.log }
  }
  if { [catch {set fd [open ./spider.log a+]}] } {
#    cputs "\fr1Failed to open log file.\fd0"
    return
  }
  regsub -all "\f." $msg {} msg
  set msg [split $msg \n]
  for { set i 0 } { $i < [llength $msg] } { incr i } {
    if { $i } { 
      puts -nonewline $fd "[string repeat { } 15]| "
    } {
      puts -nonewline $fd "[clock format [clock seconds] -format "%d.%m %H:%M:%S"] | "
    }
    puts $fd [lindex $msg $i]
  }
  close $fd
}

if { ![file isdirectory ./data] } {
  file mkdir ./data
}

proc extractPhones { str } {
  set str [string map [list о 0 o 0 з 3 б 6 ч 4 ноль 0 один 1 два 2 три 3 четыре 4 пять 5 шесть 6 семь 7 восемь 8 девять 9] [string tolower $str]]
  set out [list]
  foreach phone [parse_phones $str -phones] {
		set phone [finephone $phone]
		if { $phone ne "" } { lappend out $phone }
  }
	return $out
}

proc extractEmails { str } {
  return [regexp -all -inline -- {[A-Za-z0-9._-]+@[A-Za-z0-9.-]+} $str]
}

# a href re: {<a\s+?[^><]*?href=([\"'])(.*?)\1[^><]*?>(.*?)</a>}

set core [::CoreClass new]

gui initGUI
gui initCoreGUI $core

foreach fn [glob -nocomplain -directory [file join [pwd] modules] *.tcl] {
  if { [set bbid [file rootname [lindex [file split $fn] end]]] eq "!config" } continue
  $core loadBB $bbid
  gui initBBGUI [$core bb $bbid]
  unset bbid
}
unset -nocomplain fn

if { [catch {source [file join [pwd] modules !config.tcl]} msg] } {
  log "\fRError while source config file: \fd$msg"
}

if { !$gui } {
	$core event Run
	twapi::set_console_control_handler [list apply {{ev} {	  
	  log "\fREvent '$ev' was received. Cleanup and exit."
	  $::core event Stop
	  return 1	
	}}]
	vwait forever
}
