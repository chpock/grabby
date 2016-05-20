# guiCommon.tcl - part of grabby
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

proc createLogGUI { id1 id2 f } {
  global W

  pack [set W($id1,$id2) [text $f.t -fg #c0c0c0 -bg #000000 -yscrollcommand "$f.s set" -exportselection 0 -wrap word -font {{Lucida Console} 11}]] -side left -expand 1 -fill both
  pack [scrollbar $f.s -command "$f.t yview"] -side left -fill y
  $W($id1,$id2) tag configure bold -font {{Lucida Console} 11 bold}
  foreach { x1 x2 } {white #ffffff #lightwhite #ffffff gray #c0c0c0 lightgray #c0c0c0 red #990000 lightred #FF3333 blue #000099 lightblue #3333FF green #006600 lightgreen #33FF33 purple #990099 lightpurple #FF33FF cyan #009999 lightcyan #33FFFF black #000000 lightblack #000000} {
    $W($id1,$id2) tag configure $x1 -foreground $x2
  }

}

proc cputs { f s } {
  set curtag ""
  set map {b blue g green r red p purple w white y yellow a gray d gray c cyan}
  while { [set cpos [string first \f $s]] != -1 } {
    if { $cpos > 0 } {
      $f insert end [string range $s 0 [expr { $cpos - 1 }]] [list $curtag]
    }
    set color [string index $s [incr cpos]]
    if { ![dict exists $map [string tolower $color]] } {
      $f insert end "!BADCOLOR!" [list $curtag]
      set color d  
    }
    set curtag [dict get $map [string tolower $color]]
    if { [string equal $color [string toupper $color]] } {
      set curtag "light$curtag"
    }
    set s [string range $s [incr cpos] end]
  }
  $f insert end $s [list $curtag]
  $f insert end "\n"
  $f see end
}
