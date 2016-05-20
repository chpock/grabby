# classCatalog.tcl - part of grabby
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

# Catalog states
#   initing - каталог свежесоздан
#   requesting - запрашивается
#   raw - получены сырые данные, не распарсено
#   error - ошибка
#   parsed - распарзено, возможно получаю мессаги
#   done - каталог распарсен, мессаги распарсены, ожидается занесение в базу
#   stoping - в процессе остановки
#   stop - остановлен принудительно

::oo::class create CatalogDummyClass {
  superclass PropertiesClass

  constructor { } {
    my props -url "" -param "" -key "" -query ""
  }
}

::oo::class create CatalogClass {
  superclass CatalogDummyClass NodeClass RootNodeClass

  variable Req

  variable CatalogsDone
  variable CatalogsNew

  constructor { parent } {
    nextto NodeClass $parent
    set CatalogsNew [list]
    set CatalogsDone [list]
    set Req [RequestClass new]
    nextto CatalogDummyClass
    my state "initing"
    my prop "proxy" [[my parent] prop ReqProxy]
  }

  destructor {
    foreach o [concat $CatalogsDone $CatalogsNew] {
      $o destroy
    }
    if { [info exists Req] } {
      $Req destroy
    }
    nextto RootNodeClass
    nextto NodeClass
  }

  method name { } {
    if { [my param_exists name] } {
      return [my param name]
    } {
	    if { [$Req exists URL] } {
	      return [$Req URL]
	    } {
	      return "no url"
	    }
    }
  }
     
  method evStop { } {    
    my checkstate {initing requesting raw parsed querymesssage}
    my event_clear
    if { [my state] in {initing requesting} && [$Req exists HTTPToken] } {
      ::ckl::http::reset [$Req HTTPToken]
    } {
	    my state "stoping"
	    my child event {initing queued requesting parsing raw} Stop
	    my event Stoped
	  }
  }

  method evStoped { } {
    my checkstate {stoping}
    if { ![my child llength {initing queued requesting parsing raw}] } {
      my state "stop"
	    [my parent] event ApplyCatalog
    }
  }

  method evRequest { } {
    my checkstate {initing}
    if { [info exists Req] } {
      $Req destroy
    }
    set Req [::RequestClass new]
    $Req URL [my prop url]
    $Req QUERY [my prop query]
    $Req Attempt 0
    my state "requesting"
    if { [[my parent] state] eq "initing" } {
	    log "Инициализация \fc'\fC[my name]\fc'\fd: Запрос..."
	  } {
	    log "Каталог \fc'\fC[my name]\fc'\fd: Запрос..."
	  }
    my http_request -callback [list [self] event RequestCallback] -object [self] -request $Req -parse Catalog
  }

  method evRequestCallback { } {
    my checkstate {requesting}
    lassign [$Req Status] status action
    if { $status eq "reset" } {
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

  method evParsePre { } {
    my checkstate {raw}
    if { [catch {my parse} errmsg opts] } {
      if { [my onerror] ne "ignore" } {
        [my parent] stopByReason "Аварийная остановка: ошибка разбора каталога."
      }
      my state "error"     
      log "\fRОшибка разбора каталога \fr'\fR[my name]\fr': \fd[dict get $opts -errorinfo]"
	    [my parent] event ApplyCatalog
	  } elseif { $errmsg eq "retry" } {
	    my state "initing"
	    my event Request
    } {
	    my state "parsed"
  	  my event ParsePost
  	}
  }

  method evParsePost { } {
    my checkstate {parsed}
    foreach o $CatalogsNew {
      if { [$o prop key] eq "" } {        
        $o prop key "[$o prop url][$o prop query]"
      }
      lappend CatalogsDone $o
    }
    set CatalogsNew [list]
    foreach msg [my child list "initing"] {
      if { [$msg prop_exists subject] } {
        $msg state "done"
      } elseif { [$msg prop_exists raw] } {
        $msg state "raw"
        [$msg req] RAW [$msg prop raw]
      } elseif { [$msg prop_exists node] } {
        $msg state "raw"
        [$msg req] DATA [$msg prop node]
      } elseif { [$msg prop_exists data] } {
        $msg state "raw"
        [$msg req] DATA [$msg prop data]
      } elseif { [$msg prop_exists url] && [$msg prop url] ne "" } {
	      if { [[my parent] checkmsgkey $msg] } {
  	      $msg state "old"
	      } {
	        $msg state "queued"
	      }
      } {
        error "Don't know what to do with new message."
      }
    }
    foreach msg [my child list "raw"] {
      $msg state "parsing"
      $msg event ParsePre
    }
  	if { [my child llength {old addon done error stop}] == [my child llength] } {
  	  my state "done"
  	  [my parent] event ApplyCatalog
  	} elseif { [my child llength {queued}] } {
  	  [my parent] event QueryMessage
  	}
  }

  method new { classtype args } {
    if { [catch {dict size $args}] } {
      return -code error "new: props dict is incorrect: '$classtype' '$args'"
    }
    set prop [dict create]
    set param [dict create]
    dict for {k v} $args {
      if { [string match {-param*} $k] || [string match "param*" $k] } {
        set param $v
        if { [catch {dict size $v}] } {
          return -code error "new: params dict is incorrent: '$classtype' '$args'"
        }
      } {
        dict set prop $k $v
      }
    }
    switch -- $classtype {
      "catalog" {
		    set o [::CatalogDummyClass new]
		    lappend CatalogsNew $o
      }
      "message" {
		    set o [::MessageClass new [self]]
		    [my parent] custom $o
      }
      default {
        error "Error: wrong classtype for new: $classtype $args"
      }
    }    
    $o props {*}$prop
    $o params {*}$param
    return $o
  }

  method onerror { } {
    return "stop"
  }

  method req { } {
    return $Req
  }

  method parse { } {
    return -code error "Abstract method 'parse' called for CatalogClass."
  }

  method http_request args { tailcall [my parent] http_request {*}$args }
  method db {} { return [[my parent] db] }
}

::oo::class create InitClass {
  superclass CatalogClass

  method evParsePre { } {
    my checkstate {raw initing}
    my state "initing"
    if { "process" in [info object methods [self] -all] } {
	    if { [catch {my process} errmsg opts] } {
	      if { [my onerror] ne "ignore" } {
  	      [my parent] stopByReason "Аварийная остановка: ошибка при инициализации."
    	  }
	      my state "error"
  	    log "\fRОшибка инициализации: \fd[dict get $opts -errorinfo]"
		    [my parent] event ApplyCatalog
	    } elseif { $errmsg eq "request" } {
	      my event Request
	    } {
	      my state "parsed"
	      my event ParsePost
	    }
	  } {
	    my state "parsed"
	    my event ParsePost
	  }
  }

  method evParsePost { } {
    my variable CatalogsNew
    my variable CatalogsDone
    my checkstate {parsed}
    foreach o $CatalogsNew {
      if { [$o prop key] eq "" } {        
        $o prop key "[$o prop url][$o prop query]"
      }
      lappend CatalogsDone $o
    }
    set CatalogsNew [list]    
    my state "done"
    [my parent] event ApplyCatalog
  }

}
