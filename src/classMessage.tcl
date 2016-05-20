# classMessage.tcl - part of grabby
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

# Message states:
#  initing - свежесозданое сообщение
#  queued  - запланировано получение по запросу
#  requesting - мессага в процессе запроса
#  parsing - запланирован парзинг, но не завершен еще
#  raw     - данные получены
#  done    - инфа пропарзена и готова к заливке
#  stoping - в процессе остановки
#  stop    - остановлено
#  error   - ошибка в сообщении

::oo::class create MessageClass {
  superclass PropertiesClass NodeClass EventsClass

  variable Req

  constructor { parent } {
    set Req [RequestClass new]
    nextto NodeClass $parent
    my state "initing"
    my prop "proxy" [[[my parent] parent] prop ReqProxy]
  }

  destructor {
    if { [info exists Req] } {
      $Req destroy
    }
    nextto NodeClass
  }

  method evStop { } {
    my checkstate {initing queued requesting parsing raw}
    my event_clear
    if { [my state] eq "requesting" && [$Req exists HTTPToken] } {
      ::ckl::http::reset [$Req HTTPToken]
    } {
	    my state "stop"
  	  [my parent] event Stoped
  	}
  }

  method evParsePre { } {
    my checkstate {parsing}
    if { [catch {my parse} errmsg opts] } {
      if { [my onerror] ne "ignore" } {
        [[my parent] parent] stopByReason "Аварийная остановка: ошибка разбора сообщения."
      }
      my state "error"     
      log "\fRОшибка разбора сообщения: \fd[dict get $opts -errorinfo]"
	  } elseif { $errmsg eq "retry" } {
	    my state "queued"
    } {
	    my state "done"
  	}
	  [my parent] event ParsePost
  }

  method evRequest { } {
    my checkstate {requesting}
    if { [info exists Req] } {
      $Req destroy
    }
    set Req [::RequestClass new]
    $Req URL [my prop url]
    if { [my prop_exists query] } {
	    $Req QUERY [my prop query]
	  } {
	    $Req QUERY ""
	  }
    $Req Attempt 0
    my http_request -callback [list [self] event RequestCallback] -object [self] -request $Req -parse Message
  }

  method evRequestCallback { } {
    my checkstate {requesting stoping}
    lassign [$Req Status] status action
    if { $status eq "reset" || [my state] eq "stoping" } {
      my state "stop"
      [my parent] event ApplyCatalog
    } elseif { $status eq "ok" } {
      my state "raw"
      my event ParsePre
    } elseif { $status eq "error" } {
	    log "\fRОшибка запроса каталога \fr'\fR[my name]\fr':\fd [$Req Message]"
      if { $action eq "stop" } {
     	  my state "error"
        [my parent] event ApplyCatalog
      }
    }
  }

  method evRequestCallback { } {
    my checkstate {requesting}
    lassign [$Req Status] status action
    if { $status eq "reset" } {
      my state "stop"
      [my parent] event Stoped
    } elseif { $status eq "ok" } {
      my state "raw"
      [my parent] event ParsePost
    } elseif { $status eq "error" } {
	    log "\fRОшибка запроса сообщения \fr'\fR[$Req URL]\fr':\fd [$Req Message]"
      if { $action eq "stop" } {
     	  my state "error"
        [my parent] event ParsePost
      }
    }
  }

  method phone { args } {
    if { [llength $args] == 2 || [llength $args] == 3 } {
      if { [llength $args] == 3 } {
        if { [lindex $args 2] ne "-lazy" } {
		      return -code error "phones method 'phones name ?-lazy?' : wrong args '$args'"
        }
        set prop "phonelazy"
      } {
        set prop "phone"
      }
      if { [my prop_exists $prop] } {
        set phones [my prop_get $prop]
      } {
        set phones [dict create]
      }
      foreach phone [lindex $args 0] {
        if { ![dict exists $phones $phone] || [dict get $phones $phone] eq "" } {
          dict set phones $phone [lindex $args 1]
        }
      }
      if { [dict size $phones] } {
        my prop_set $prop $phones
      }
    } {
      return -code error "phones method 'phones name ?-lazy?' : wrong args '$args'"
    }
  }

  method req { } { return $Req }

  method parse { } {
    return -code error "Abstract method 'parse' called for MessageClass."
  }

  method onerror { } {
    return "stop"
  }

  method http_request args { tailcall [my parent] http_request {*}$args }
  method db {} { return [[parent] db] }

}
