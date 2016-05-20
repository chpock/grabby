# common.tcl - part of grabby
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

foreach range {
  {replace {0   31 } 32 }
  {good    {32  126}    }
  {replace  127 32 }
  {replace  128 32 }
  {replace  129 195}
  {replace  130 44 }
  {replace  131 227}
  {replace  132 34  }
  {replace  133 {...}}
  {replace {134 138} 32 }
  {replace  139 60 }
  {replace  140 32 }
  {replace  141 202}
  {replace {142 144} 32 }
  {replace  145 39 }
  {replace  146 39 }
  {replace  147 34 }
  {replace  148 34 }
  {replace  149 32 }
  {replace  150 45 }
  {replace  151 45 }
  {replace  152 32 }
  {replace  153 {(tm)}}
  {replace  154 32 }
  {replace  155 62 }
  {replace  156 32 }
  {replace  157 234}
  {replace {158 160} 32 }
  {replace  161 121}
  {replace  162 89 }
  {replace  163 74 }
  {replace  164 32 }
  {good     165    }
  {replace  166 32 }
  {replace  167 32 }
  {good     168    }
  {replace  169 {(c)}}
  {good     170    }
  {replace  171 34 }
  {replace {172 174} 32 }
  {good     175    }
  {replace {176 177} 32 }
  {good    {178 180}}
  {replace {181 183} 32 }
  {good    {184 186}}
  {replace  187 34 }
  {replace  188 106}
  {replace  189 83 }
  {replace  190 115}
  {good     191}
  {good    {192 255}}
} {
  if { [llength [lindex $range 1]] == 1 } {
    set range [lreplace $range 1 1 [list [lindex $range 1] [lindex $range 1]]]  
  }
  for { set idx [lindex [lindex $range 1] 0] } { $idx <= [lindex [lindex $range 1] 1] } { incr idx } {
    if { [lindex $range 0] eq "good" } {
      set replace [encoding convertfrom cp1251 [format %c $idx]]
    } elseif { [lindex $range 0] eq "replace" } {
      if { [string is integer -strict [set replace [lindex $range 2]]] } {
        set replace [encoding convertfrom cp1251 [format %c $replace]]    
      } elseif { [lindex $range 2] ne "" } {
        set replace [lindex $range 2]
      } {
        error
      }
    } {
      error
    }
    set char2clean([encoding convertfrom cp1251 [format %c $idx]]) $replace
  }
}
unset idx range replace

#for { set i 192 } { $i <= 255 } { incr i } {
#  set cleanChars([encoding convertfrom cp1251 [format %c $i]]) [encoding convertfrom cp1251 [format %c $i]]
#}

array set namedEntities {
	nbsp \xa0 iexcl \xa1 cent \xa2 pound \xa3 curren \xa4
	yen \xa5 brvbar \xa6 sect \xa7 uml \xa8 copy \xa9
	ordf \xaa laquo \xab not \xac shy \xad reg \xae
	macr \xaf deg \xb0 plusmn \xb1 sup2 \xb2 sup3 \xb3
	acute \xb4 micro \xb5 para \xb6 middot \xb7 cedil \xb8
	sup1 \xb9 ordm \xba raquo \xbb frac14 \xbc frac12 \xbd
	frac34 \xbe iquest \xbf Agrave \xc0 Aacute \xc1 Acirc \xc2
	Atilde \xc3 Auml \xc4 Aring \xc5 AElig \xc6 Ccedil \xc7
	Egrave \xc8 Eacute \xc9 Ecirc \xca Euml \xcb Igrave \xcc
	Iacute \xcd Icirc \xce Iuml \xcf ETH \xd0 Ntilde \xd1
	Ograve \xd2 Oacute \xd3 Ocirc \xd4 Otilde \xd5 Ouml \xd6
	times \xd7 Oslash \xd8 Ugrave \xd9 Uacute \xda Ucirc \xdb
	Uuml \xdc Yacute \xdd THORN \xde szlig \xdf agrave \xe0
	aacute \xe1 acirc \xe2 atilde \xe3 auml \xe4 aring \xe5
	aelig \xe6 ccedil \xe7 egrave \xe8 eacute \xe9 ecirc \xea
	euml \xeb igrave \xec iacute \xed icirc \xee iuml \xef
	eth \xf0 ntilde \xf1 ograve \xf2 oacute \xf3 ocirc \xf4
	otilde \xf5 ouml \xf6 divide \xf7 oslash \xf8 ugrave \xf9
	uacute \xfa ucirc \xfb uuml \xfc yacute \xfd thorn \xfe
	yuml \xff}

# II. Entities for Symbols and Greek Letters (HTML 4.01)
array set namedEntities {
	fnof \u192 Alpha \u391 Beta \u392 Gamma \u393 Delta \u394
	Epsilon \u395 Zeta \u396 Eta \u397 Theta \u398 Iota \u399
	Kappa \u39A Lambda \u39B Mu \u39C Nu \u39D Xi \u39E
	Omicron \u39F Pi \u3A0 Rho \u3A1 Sigma \u3A3 Tau \u3A4
	Upsilon \u3A5 Phi \u3A6 Chi \u3A7 Psi \u3A8 Omega \u3A9
	alpha \u3B1 beta \u3B2 gamma \u3B3 delta \u3B4 epsilon \u3B5
	zeta \u3B6 eta \u3B7 theta \u3B8 iota \u3B9 kappa \u3BA
	lambda \u3BB mu \u3BC nu \u3BD xi \u3BE omicron \u3BF
	pi \u3C0 rho \u3C1 sigmaf \u3C2 sigma \u3C3 tau \u3C4
	upsilon \u3C5 phi \u3C6 chi \u3C7 psi \u3C8 omega \u3C9
	thetasym \u3D1 upsih \u3D2 piv \u3D6 bull \u2022
	hellip \u2026 prime \u2032 Prime \u2033 oline \u203E
	frasl \u2044 weierp \u2118 image \u2111 real \u211C
	trade \u2122 alefsym \u2135 larr \u2190 uarr \u2191
	rarr \u2192 darr \u2193 harr \u2194 crarr \u21B5
	lArr \u21D0 uArr \u21D1 rArr \u21D2 dArr \u21D3 hArr \u21D4
	forall \u2200 part \u2202 exist \u2203 empty \u2205
	nabla \u2207 isin \u2208 notin \u2209 ni \u220B prod \u220F
	sum \u2211 minus \u2212 lowast \u2217 radic \u221A
	prop \u221D infin \u221E ang \u2220 and \u2227 or \u2228
	cap \u2229 cup \u222A int \u222B there4 \u2234 sim \u223C
	cong \u2245 asymp \u2248 ne \u2260 equiv \u2261 le \u2264
	ge \u2265 sub \u2282 sup \u2283 nsub \u2284 sube \u2286
	supe \u2287 oplus \u2295 otimes \u2297 perp \u22A5
	sdot \u22C5 lceil \u2308 rceil \u2309 lfloor \u230A
	rfloor \u230B lang \u2329 rang \u232A loz \u25CA
	spades \u2660 clubs \u2663 hearts \u2665 diams \u2666}

# III. Special Entities (HTML 4.01)
array set namedEntities {
	quot \x22 amp \x26 lt \x3C gt \x3E OElig \u152 oelig \u153
	Scaron \u160 scaron \u161 Yuml \u178 circ \u2C6
	tilde \u2DC ensp \u2002 emsp \u2003 thinsp \u2009
	zwnj \u200C zwj \u200D lrm \u200E rlm \u200F ndash \u2013
	mdash \u2014 lsquo \u2018 rsquo \u2019 sbquo \u201A
	ldquo \u201C rdquo \u201D bdquo \u201E dagger \u2020
	Dagger \u2021 permil \u2030 lsaquo \u2039 rsaquo \u203A
	euro \u20AC}

# IV. Special Entities (XHTML, XML)
array set namedEntities {
	apos \u0027}


proc DoNamedMap {name endOf} {
    if {[info exist ::namedEntities($name)]} {
			return $::namedEntities($name)
    } else {
			# Put it back..
			return "&$name$endOf"
    }
}

proc DoDecMap {dec endOf} {
    scan $dec %d dec
    if {$dec <= 0xFFFD} {
			return [format %c $dec]
    } else {
			# Put it back..
			return "&#$dec$endOf"
    }
}

proc DoHexMap {hex endOf} {
    scan $hex %x value
    if {$value <= 0xFFFD} {
  		return [format %c $value]
    } else {
			# Put it back..
			return "&#x$hex$endOf"
    }
}

proc html2text { str } {
  regsub -all -nocase -- {<script.+?</script>} $str {} str
  regsub -all -- {<[^>]*?>} $str {} str
  set new [string map [list \] \\\] \[ \\\[ \$ \\\$ \\ \\\\] $str]
  regsub -all -- {&([[:alnum:]]{2,7})(;|\M)} $new {[DoNamedMap \1 {\2}]} new
  regsub -all -- {&#([[:digit:]]{1,5})(;|\M)} $new {[DoDecMap \1 {\2}]} new
  regsub -all -- {&#x([[:xdigit:]]{1,4})(;|\M)} $new {[DoHexMap \1 {\2}]} new

  set new [subst $new]

  return [text2text $new]
}

proc text2text { str } {
  set new ""
  foreach char [split $str ""] {
    if { [info exists ::char2clean($char)] } {
      append new $::char2clean($char)
    } {
      append new { }
    }
  }
  regsub -all -- {\s+} $new { } new
  return [string trim $new]
}

proc wsplit {str sep} {
  return [split [string map [list $sep \0] $str] \0]
}

proc rsplit {str re} {
  regsub -all -- $re $str \0 str
  return [split $str \0]
}

proc finephone { phone } {
  regsub -all -- {\D} $phone {} phone
  switch -regexp -- $phone {
    {^380\d{9}$} { }
    {^0\d{9}$}   { set phone "38$phone" }
    {^80\d{9}$}  { set phone "3$phone" }
    {^(39|50|63|66|67|68|91|92|93|94|95|96|97|98|99)\d{7}$} { set phone "380$phone" }
  }
  return $phone
}

proc is_phone_correct { phone } {
  return [expr { [string match {380[1-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]} $phone] && !([string range $phone 5 end] in {0000000 1111111 2222222 3333333 4444444 5555555 6666666 7777777 8888888 9999999 1234567 7654321 3456789 1010101 0101010})}]
#  return [regexp -- {^380\d{9}$} $phone]
}

proc smartjoin { list args } {
  set xlist [list]
  foreach v $list { if { [string length $v] } { lappend xlist $v } }
  tailcall join $xlist {*}$args
}

proc cputs { s } {
  set h [::twapi::get_console_handle "stdout"]
  set map {b {blue {}} g {green {}} r {red {}} p {purple {}} w {white {}} y {yellow {}} a {gray {}} d {gray {}} c {blue green}}
  while { [set cpos [string first \f $s]] != -1 } {
    if { $cpos > 0 } {
      puts -nonewline [string range $s 0 [expr { $cpos - 1 }]]; flush stdout
    }
    set color [string index $s [incr cpos]]
    if { ![dict exists $map [string tolower $color]] } {
      puts -nonewline "!BADCOLOR!"; flush stdout
      set color d  
    }
    set bright [string equal $color [string toupper $color]]
    set color [dict get $map [string tolower $color]]
    if { [lindex $color end] eq {} } {
	    ::twapi::set_console_default_attr $h -fg[lindex $color 0] 1 -fgbright $bright
    } { 
	    ::twapi::set_console_default_attr $h -fg[lindex $color 0] 1 -fg[lindex $color 1] 1 -fgbright $bright
	  }
    set s [string range $s [incr cpos] end]
  }
  puts -nonewline $s; flush stdout
  ::twapi::set_console_default_attr $h -fggray 1 -fgbright 0
  puts ""
}

proc ::tcl::dict::lappend2 {dict args} {
	upvar 1 $dict d
  if { ![dict exists $d {*}[lrange $args 0 end-1]] } {
  	dict set d {*}[lrange $args 0 end-1] [list [lindex $args end]]
  } else {
  	::set list [dict get $d {*}[lrange $args 0 end-1]]
    ::lappend list [lindex $args end]
    dict set d {*}[lrange $args 0 end-1] $list
  }
}
proc ::tcl::dict::incr2 {dict args} {
	upvar 1 $dict d
  if { ![dict exists $d {*}[lrange $args 0 end]] } {
  	dict set d {*}[lrange $args 0 end] 1
  } else {
  	::set val [dict get $d {*}[lrange $args 0 end]]
    dict set d {*}[lrange $args 0 end] [::incr val]
  }
}
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {lappend2 ::tcl::dict::lappend2}]
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {incr2 ::tcl::dict::incr2}]
