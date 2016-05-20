# guiBB.tcl - part of grabby
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

proc initBBGUI { BB {nb {}} } {
  global W

  set id [$BB id]
  if { $nb eq "" } {
    set nb $W(core,notebook)
  }

  $nb add [set W($id,tab) [ttk::frame [% $W(core,notebook)]]] -text [$BB prop Title] -compound left

  pack [set f [ttk::frame [% $W($id,tab)]]] -side top -fill x -pady 3 -padx 3
  pack [ttk::label [% $f] -text "Статус: "] -side left
  pack [set W($id,statelabel) [ttk::label [% $f] -text ""]] -side left -expand 1 -fill x

  pack [set f [ttk::labelframe [% $W($id,tab)] -text "Журнал:"]] -side top -fill both -pady 3 -padx 3 -expand 1
  createLogGUI $id log $f
  
  pack [set f [ttk::labelframe [% $W($id,tab)] -text "Журнал сообщений:"]] -side bottom -fill x -pady 3 -padx 3
  createLogGUI $id logmessage $f

  $W($id,logmessage) configure -height 10

  ::oo::objdefine $BB {
    method state { args } {
      if { [llength $args] } {
        set _ [dict create {*}{
          initing {
            tabimg control_play_blue
            lbltxt "Инициализация"
          }
          running {
            tabimg control_play_blue
            lbltxt "Работает"
          } 
          enabled {
            tabimg control_pause_blue
            lbltxt "Пауза"
          } 
          disabled {
            tabimg cross
            lbltxt "Заблокировано"
          } 
          stoping {
            tabimg control_play_blue
            lbltxt "Останавливается"
          } 
          error {
            tabimg exclamation
            lbltxt "Ошибка"
          } 
          "" {
            tabimg exclamation
            lbltxt "Неизвестный статус"
          }
        }]

        if { [dict exists $_ [lindex $args 0]] } {
          set _ [dict get $_ [lindex $args 0]]
        } {
          set _ [dict get $_ {}]
        }

	      $::W(core,notebook) tab $::W([my id],tab) -image [img [dict get $_ tabimg]]
#	      $::W(core,statebutton) configure -image [img [dict get $_ btnimg]] -text [dict get $_ btntxt]
	      $::W([my id],statelabel) configure -text [dict get $_ lbltxt]
      }
      next {*}$args
    }
  }

  $BB state [$BB state]
}