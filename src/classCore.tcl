# classCore.tcl - part of grabby
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


# Core state
#   enabled
#   running
#   stoping

::oo::class create CoreClass {
  superclass PropertiesClass StateClass RootNodeClass

  constructor {} {
    my prop KeepLogFile false
    my state "enabled"
  }

  destructor {
    nextto RootNodeClass
    exit
  }

  method bb { bbid } {
    foreach BB [my child list] {
      if { [$BB id] eq $bbid } {
        return $BB
      }
    }
    error "Error: Can't find bb '${bbid}'."
  }

  method evRun { } {
    my checkstate {enabled}
    my state "running"
    if { [my prop KeepLogFile] } {
      log "\fG������ �������."
    } {
      log "\fG������ �������." -clearfile
    }
    foreach child [my child list {enabled}] {
      log "������ ������� \fc'\fC[$child prop Title]\fc'"
      $child event Run
    }
    my event RehashBB
  }

  method evRehashBB { } {    
    my checkstate {running stoping}
    if { ![my child llength {running initing stoping}] } {
      if { [my state] eq "stoping" } {
			  log "\fR������� ������������� �����������."
      } {
			  log "\fG��� ������� ���������."
      }
      my state "enabled"
		  if { !$::gui } { my destroy }
    }
  }

  method loadBB { bbid } {
    my checkstate {enabled}
    set obj [::BBClass new [self] $bbid]
    $obj loadBB
	  log "������� \fc'\fC[$obj prop Title]\fc' \fd���������."
  }

  method evStop { } {
    my checkstate {running}
    my state "stoping"
    my event_clear
    foreach child [my child list {running initing}] {
      log "\fR��������� ������� \fr'\fR[$child prop Title]\fr'"
      $child stopByReason "��������� �� ����������."
    }
    my event RehashBB
  }

  method evStoped { } {
    my checkstate {stoping}
    my event RehashBB
  }

}
