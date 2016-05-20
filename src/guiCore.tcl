# guiCore.tcl - part of grabby
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

proc initCoreGUI { core {nb ""} } {
  global W

  if { $nb eq "" } {
    set nb $W(core,notebook)
  }

  $nb add [set W(core,tab) [ttk::frame [% $W(core,notebook)]]] -text "Главная" -compound left

  pack [set f [ttk::frame [% $W(core,tab)]]] -side top -fill x -pady 3 -padx 3
  pack [ttk::label [% $f] -text "Статус: "] -side left
  pack [set W(core,statelabel) [ttk::label [% $f] -text ""]] -side left -expand 1 -fill x
  pack [set W(core,statebutton) [ttk::button [% $f] -text "" -compound left]] -side right -padx 3

  pack [set f [ttk::labelframe [% $W(core,tab)] -text "Журнал:"]] -side top -fill both -pady 3 -padx 3 -expand 1

  createLogGUI core log $f

  $W(core,log) configure -width 120

  ::oo::objdefine $core {
    method state { args } {
      if { [llength $args] } {
        set _ [dict create {*}{
          running {
            tabimg control_play_blue
            btnimg control_pause_blue
            btntxt "Остановка"
            btnstt !disabled
            lbltxt "Задания выполняются"
          } 
          enabled {
            tabimg control_pause_blue
            btnimg control_play_blue
            btntxt "Запуск"
            btnstt !disabled
            lbltxt "Пауза"
          }
          stoping {
            tabimg control_pause_blue
            btnimg control_play_blue
            btntxt "Запуск"
            btnstt disabled
            lbltxt "Процесс остановки заданий"
          } 
          "" {
            tabimg exclamation
            btnimg exclamation
            btntxt "Ошибка"
            btnstt disabled
            lbltxt "Неизвестный статус"
          }
        }]

        if { [dict exists $_ [lindex $args 0]] } {
          set _ [dict get $_ [lindex $args 0]]
        } {
          set _ [dict get $_ {}]
        }

	      $::W(core,notebook) tab $::W(core,tab) -image [img [dict get $_ tabimg]]
	      $::W(core,statebutton) configure -image [img [dict get $_ btnimg]] -text [dict get $_ btntxt]
	      $::W(core,statebutton) state [dict get $_ btnstt]
	      $::W(core,statelabel) configure -text [dict get $_ lbltxt]
      }
      next {*}$args
    }
  }

  $core state [$core state]

  $W(core,statebutton) configure -command {
    $::W(core,statebutton) state disabled
    if { [$::core state] eq "enabled" } {
      $::core event Run
    } {
      $::core event Stop
    }
  }

}

proc initGUI { {tl .} } {
  global W

  pack [set W(core,notebook) [ttk::notebook [% $tl]]] -expand 1 -fill both
  wm title $tl "Паук"
}