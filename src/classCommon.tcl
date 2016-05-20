# classCommon.tcl - part of grabby
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


::oo::class create PropertiesClass {
  variable Props

  method prop_set { name val } {
    set Props($name) $val
  }

  method prop_get { name } {
    set Props($name)
  }

  method prop_exists { name } {
    info exists Props($name)
  }

  method prop { name args } {
    if { [llength $args] == 1 } {
      my prop_set $name [lindex $args 0]
    } elseif { [llength $args] == 0 } {
      my prop_get $name
    } {
      return -code error "prop: wrong args num - '$name' '$args'"
    }
  }

  method props { args } {
    if { [catch {
      dict for { k v } $args {
        if { [string index $k 0] eq "-" } {
          set k [string range $k 1 end]
        }
        my prop_set $k $v
      }
    }] } {
      return -code error "props: wrong args - '$args'"
    }
  }

  method param { name args } {
    if { [llength $args] == 1 } {
      my param_set $name [lindex $args 0]
    } elseif { [llength $args] == 0 } {
      my param_get $name
    } {
      return -code error "param: wrong args num - '$name' '$args'"
    }
  }

  method param_set { name val } {
    if { [my prop_exists "param"] } {
      set param [my prop_get "param"]
      dict set param $name $val
      my prop_set "param" $param
    } {
      my prop_set "param" [dict create $name $val]
    }
    return $val
  }

  method param_get { name } {
    return [dict get [my prop_get "param"] $name]
  }

  method param_exists { name } {
    if { ![my prop_exists param] || ![dict exists [my prop_get param] $name] } {
      return 0
    } {
      return 1
    }
  }

  method params { args } {
    if { [my prop_exists "param"] } {
      set param [my prop_get "param"]
    } {
      set param [dict create]
    }
    if { [catch {
      dict for { k v } $args {
        if { [string index $k 0] eq "-" } {
          set k [string range $k 1 end]
        }
        dict set param $k $v
      }
      my prop_set "param" $param
    }] } {
      return -code error "params: wrong args - '$args'"
    }
  }

}

::oo::class create StateClass {
  variable State

  constructor { } {
    set State ""
  }

  method state { args } {
    if { ![llength $args] } {
      set State
    } elseif { [llength $args] == 1 } {
      set State [lindex $args 0]
    } {
      error "Error while set state of object: Arguments: $args"
    }
  }

  method checkstate { statelist } {
    if { $State ni $statelist } {      
      log "ERROR! wrong state '$State' for event [uplevel 1 {self class}]::[lindex [info level -1] 1] \([uplevel 1 {self}]\). Allowed states: '[join $statelist {', '}]'" -file
      return -level 2 -code error "wrong state '$State' for event [uplevel 1 {self class}]::[lindex [info level -1] 1] \([uplevel 1 {self}]\). Allowed states: '[join $statelist {', '}]'"
    }
  }

}

::oo::class create NodeClass {
  superclass StateClass
  variable Parent

  constructor { parent } {
    set Parent $parent
    nextto StateClass
    $Parent child add [self]
  }

  method parent { } {
    set Parent
  }

  method state { args } {
    if { [llength $args] } {
      set ostate [my state]
      set nstate [lindex $args 0]
      $Parent child switch $ostate $nstate [self]
    }
    nextto StateClass {*}$args
  }

  destructor {
    $Parent child remove [self]
  }

}

::oo::class create EventsClass {
  method event { ev } {
    global eventdb
    set ev ev$ev
    set evid [list [self] $ev]
    if { [array exists eventdb] && [info exists eventdb($evid)] } {
      after cancel $eventdb($evid)
      unset eventdb($evid)
      log "Requeue event $ev on [self]..." -file
    } {
      log "Queue event $ev on [self]..." -file
    }
    set eventdb($evid) [after 1 [list apply {{ obj ev } {
      unset ::eventdb([list $obj $ev])
      log "Fire event $ev on $obj ..." -file
      $obj $ev
      update idletasks
    }} [self] $ev]]
  }

  method event_clear { } {
    global eventdb
    foreach evid [array names eventdb] {
      if { [lindex $evid 0] eq [self] } {
        log "Clear event [lindex $evid 1] on [self]." -file
        after cancel $eventdb($evid)
        unset eventdb($evid)
      }
    }
  }

}

::oo::class create RootNodeClass {
  superclass EventsClass
  variable Childrens            
  method child { args } {
    switch -- [lindex $args 0] {
      "add" {
        lappend Childrens([[lindex $args 1] state]) [lindex $args 1]
      }
      "remove" {
        set stid [[lindex $args 1] state]
        set idx [lsearch -exact $Childrens($stid) [lindex $args 1]]
        set Childrens($stid) [lreplace $Childrens($stid) $idx $idx]
      }
      "switch" {
        set idx [lsearch -exact $Childrens([lindex $args 1]) [lindex $args 3]]
        set Childrens([lindex $args 1]) [lreplace $Childrens([lindex $args 1]) $idx $idx]
        lappend Childrens([lindex $args 2]) [lindex $args 3]
      }
      "list" {
        set res [list]
        if { [llength $args] == 1 } {
          if { [array exists Childrens] } {
            foreach stid [array names Childrens] {
              lappend res {*}$Childrens($stid)
            }
          }
        } {
	        foreach stid [lindex $args 1] {
  	        if { [info exists Childrens($stid)] } {
	  	        lappend res {*}$Childrens($stid)
	    	    }
	        }
	      }
        return $res
      }
      "llength" {
        return [llength [my child list {*}[lrange $args 1 end]]]
      }
      "event" {
        foreach o [my child list [lindex $args 1]] {
          $o event [lindex $args 2]
        }
      }
    }
  }

  destructor {
    foreach o [my child list] {
      $o destroy
    }
  }

  method event_clear { } {
    foreach child [my child list] {
      $child event_clear
    }
    nextto EventsClass
  }

}
