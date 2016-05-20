# classBB.tcl - part of grabby
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

# BB state
#   enabled  - ББ активирован, в режиме паузы, требует события Run для запуска
#   disabled - ББ деактивирована
#   error    - При загрузке/инициализации/работе возникли ошибки, ББ заблокирована
#   initing  - Режим инициализации
#   running  - Рабочий режим
#   stoping  - Остановка

::oo::class create BBClass {
  superclass PropertiesClass NodeClass RequestClass RootNodeClass
  variable db
  variable ID
  variable CustomMethods
  variable Cookies
  variable StopReason

  variable DebugReqCounter

  variable ProxyMaxRequests
  variable ProxyTimeout

  constructor { parent bbid } {
    set Cookies [dict create]
    set ID $bbid
    set CustomMethods [dict create]
    set DebugReqCounter 0
    set StopReason ""
    # Действия при ошибках
    my prop OnError [list]
    # Добавляемые поля в таблицу
    my prop AddFields [list]
    # Проверка на дубликаты сообщений по хэшу сабжа и телефонов
    my prop MessageUseHash 1
    # Титул для вкладки с ББ
    my prop Title $bbid
    # Параметры запросов
    # Автоматически использовать прокси для запросов
    my prop ReqProxy 0
    my prop ReqMaxCatalogs 5
    my prop ReqMaxMessages 20
    # Количество повторений запроса, 0 - бесконечно
    my prop ReqMaxAttempts 0
    my prop ReqContinueTimeout 15000
    my prop ReqTimeout 10000
    my prop ReqAutoParseCatalog "html"
    my prop ReqAutoParseMessage "html"
    my prop ReqAutoParseBB      "html"
    my prop ReqCookies 1
    # Параметры прокси
    # Количество запросов, после которых переключать прокси (50 запросов по умолчанию)
    my prop ProxyMaxRequests 50
    # После какого времени прокси вытаскивается из бана для этой ББ (1 час по умолчанию)
    my prop ProxyTimeout [expr { 60*60 }]
    # Запись сырых данных запросов url в файл
    my prop ReqLog 0
    nextto NodeClass $parent
    my state "disabled"
  }

  destructor {
    nextto RootNodeClass
    nextto NodeClass
  }

  method id { } {
    set ID
  }

  method loadBB { } {
    my state "disabled"
    set fn [file join [pwd] modules ${ID}.tcl]
    set me [self]
    if { [catch {source $fn} msg] } {
      my state "error"  
	    log "\fRError while source file \fr'\fR$fn\fr':\fd $msg"
    } {
      my custom [self]
      if { "constructor" in [info object methods [self] -all] } {
        if { [catch {my constructor} msg] } {
			    log "\fRError while construct object \fr'\fR$ID\fr:\fd $msg"
			    my state "error"
        }
      }
    }
    unset me
  }

  method custom { args } {
    if { [llength $args] == 1 } {
      set classid [info object class [lindex $args 0]]
      if { [dict exists $CustomMethods $classid] } {
        dict for { method code } [dict get $CustomMethods $classid] {
          ::oo::objdefine [lindex $args 0] [list method $method {} $code]
        }
      }
    } elseif { [llength $args] == 3 } {
      set classid [lindex $args 0]
      if { [string range $classid 0 1] ne "::" } {
        set classid "::${classid}Class"
      }
	    dict set CustomMethods $classid [lindex $args 1] [lindex $args 2]
    } {
      error "\fRError while define custom methods. Arguments: \fd$args"
    }
#    puts "CustomMethods: $CustomMethods"
  }

  method stopByReason { reason } {
    my event_clear
    set StopReason $reason
    my event Stop
  }
  
  method OpenDB { } {
    set db [tdbc::sqlite3::connection create [self namespace]::db "./data/${ID}.sqlite3" -timeout 100000]
    #$bbdb allrows {PRAGMA synchronous = OFF}
    $db allrows {PRAGMA synchronous = FULL}
    $db allrows {PRAGMA cache_size = 100000}
    #$bbdb allrows {PRAGMA synchronous = NORMAL}
    $db allrows {PRAGMA count_changes = OFF}

 	  $db allrows {DROP TABLE IF EXISTS category}

	  $db allrows {CREATE TABLE IF NOT EXISTS catalog (
	    url TEXT NOT NULL DEFAULT '',
	    query TEXT NOT NULL DEFAULT '',
	    key TEXT NOT NULL,
	    param TEXT NOT NULL DEFAULT '',
	    state INTEGER NOT NULL DEFAULT 0, 
	    registred_dt TIMESTAMP NOT NULL DEFAULT (strftime('%s','now')), 
	    id INTEGER PRIMARY KEY AUTOINCREMENT)}

	  $db allrows {CREATE INDEX IF NOT EXISTS idx_catalog_key ON catalog(key)}

	  $db allrows {CREATE TABLE IF NOT EXISTS message (
	    url TEXT, 
	    query TEXT,
	    hash TEXT NOT NULL,
	    key TEXT,
	    param TEXT,
	    _date DATETIME, 
	    _subject TEXT, 
	    _city TEXT,
	    _state TEXT, 
	    _address TEXT,
	    registred_dt DATETIME NOT NULL DEFAULT (strftime('%s','now')), 
	    id INTEGER PRIMARY KEY AUTOINCREMENT)}

	  $db allrows {CREATE TABLE IF NOT EXISTS messageclone (
	    key TEXT NOT NULL,
	    id_message INTEGER NOT NULL)}
	  $db allrows {CREATE INDEX IF NOT EXISTS idx_messageclone_key ON messageclone(key)}

	  if { ![dict exists [$db columns message] "key"] } {
	    $db allrows {ALTER TABLE message ADD COLUMN key TEXT}
	  }
	  if { ![dict exists [$db columns message] "query"] } {
	    $db allrows {ALTER TABLE message ADD COLUMN query TEXT}
	  }
	  if { ![dict exists [$db columns message] "param"] } {
	    $db allrows {ALTER TABLE message ADD COLUMN param TEXT}
	  }

	  $db allrows {DROP INDEX IF EXISTS idx_message_url}

	  $db allrows {CREATE INDEX IF NOT EXISTS idx_message_hash ON message(hash)}
	  $db allrows {CREATE INDEX IF NOT EXISTS idx_message_url_query ON message(url,query)}
	  $db allrows {CREATE INDEX IF NOT EXISTS idx_message_key ON message(key)}

	  $db allrows {CREATE TABLE IF NOT EXISTS phone (
	    registred_dt DATETIME NOT NULL DEFAULT (strftime('%s','now')), 
	    number TEXT,
	    name TEXT, 
	    id_message INTEGER NOT NULL)}
	  $db allrows {CREATE INDEX IF NOT EXISTS idx_phone_number ON phone(number)}
	  $db allrows {CREATE INDEX IF NOT EXISTS idx_phone_id_message ON phone(id_message)}

	  if { ![dict exists [$db columns phone] "id_addon"] } {
	    $db allrows {ALTER TABLE phone ADD COLUMN id_addon INTEGER DEFAULT NULL}
	  }
	  $db allrows {CREATE UNIQUE INDEX IF NOT EXISTS idx_phone_id_addon ON phone(id_addon)}

    foreach col [my prop AddFields] {
      regsub -all {[^_\w\d]} $col {} col 
      if { [dict exists [$db columns message] "_$col"] } continue
      $db allrows "ALTER TABLE message ADD COLUMN _$col"
    }

    $db allrows {CREATE TEMP TABLE catalog_temp(
      key TEXT NOT NULL)}
    $db allrows {CREATE UNIQUE INDEX idx_catalog_temp_key ON catalog_temp(key)}

  }

  method CloseDB { } {
    $db close
    unset db
  }

  method evRun { } {
    my checkstate {enabled}
    set StopReason ""
    my state "initing"
    log "Инициализация..."
    foreach fn [glob -nocomplain "debug.[my id].*.*.log"] { catch { file delete $fn } }
    my OpenDB
    set cat [::InitClass new [self]]
    my custom $cat
    if { ![llength [$db allrows {SELECT * FROM catalog WHERE state = 0 ORDER BY id DESC LIMIT 1}]] } {
  	  $db allrows {DELETE FROM catalog}
  	}
  	$db allrows {DELETE FROM catalog_temp}
    $cat event ParsePre
  }

  method evInitPost { } {
    my checkstate {initing}
    my state "running"
    if { [llength [$db allrows {SELECT * FROM catalog WHERE state = 0 ORDER BY id DESC LIMIT 1}]] } {
	    log "Продолжаю обработку..."
	  } {
	    log "Начинаю новую обработку..."
  	  $db allrows {DELETE FROM catalog}
  	  if { [my prop_exists StartURL] && [set url [my prop StartURL]] != "" } {
	    	$db allrows {INSERT INTO catalog (url,key) VALUES(:url,:url)}
	    }
	  }
    my event QueryCatalog
    [my parent] event RehashBB
  }

  method evStop { } {
    my checkstate {running initing}
    my event_clear
    if { $StopReason ne "" } {
      log "\fR$StopReason"
      set StopReason ""
    }
    if { [my child llength] } {
      my state "stoping"
      foreach child [my child list {initing requesting raw parsed}] {
        $child event_clear
        $child event Stop
      }
      if { [my child llength {error done stop}] } {
        my event ApplyCatalog
      }
    } {
      my event Stoped  
	  }
  }

  method evStoped { } {
    my checkstate {running initing stoping}
    if { ![my child llength] } {
      if { [my state] eq "stoping" } {
        log "\fRОбработка остановлена"
      } {
		    log "\fGОбработка завершена"
		  }
	    my state "enabled"
	    my CloseDB
	    set Cookies [dict create]
	    [my parent] event RehashBB
    }
  }

  method evQueryCatalog { } {
    my checkstate {running}
    while { [my child llength] < [my prop ReqMaxCatalogs] } {
	    set catrec [lindex [$db allrows {SELECT * FROM catalog WHERE state = 0 AND NOT EXISTS(SELECT 1 FROM catalog_temp where catalog_temp.key = catalog.key) ORDER BY id DESC LIMIT 1}] 0]
	    if { ![llength $catrec] } break
      set cat [::CatalogClass new [self]]
      my custom $cat
      $cat prop url [dict get $catrec url]
      $cat prop key [dict get $catrec key]
      $cat prop param [dict get $catrec param]
      $cat prop query [dict get $catrec query]
      $db allrows {INSERT INTO catalog_temp (key) VALUES (:key)} $catrec
      $cat event Request
    }
		if { ![my child llength] } {
		  my event Stoped
	  }
  }

  method evApplyCatalog { } {
    my checkstate {running initing stoping}
    if { [my state] eq "initing" } {
      if { [my child llength "error"] > 0 } {
        my stopByReason "Ошибка инициализации"
      }
    }

    foreach cat [my child list {stop}] {
      if { [my state] eq "initing" } {
	      log "\fRИнициализация остановлена."
      } {
	      log "\fRКаталог \fc'\fC[$cat name]\fc': \fRобработка остановлена."
	    }
      $cat destroy
    }
    foreach cat [my child list {error}] {
      if { [my state] eq "initing" } {
	      log "\fRИнициализация завершилась с ошибкой."
      } {
	      log "\fRОбработка каталога \fr'\fR[$cat name]\fr'\fR завершилась с ошибкой."
	    }
      $cat destroy
    }

    foreach cat [my child list done] {
      $db begintransaction
      set CatOld 0
 	    set CatNew 0
      foreach xcat [set [info object namespace $cat]::CatalogsDone] {
        set key [$xcat prop key]
        if { [llength [$db allrows {SELECT 1 FROM catalog WHERE key = :key}]] } {
          incr CatOld
          continue
        }
        set url [$xcat prop url]
        set param [$xcat prop param]
        set query [$xcat prop query]
        $db allrows {INSERT INTO catalog (url,key,param,query) VALUES (:url,:key,:param,:query)}
        incr CatNew
      }
	
 	    foreach msg [$cat child list "done addon nophone"] {
# 	      unset -nocomplain hash url key datetime subject city state address phone name k v
        unset -nocomplain msgid newmessage newphone
 	      foreach var {url key datetime subject city state address phone phonelazy} {
 	        if { ![$msg prop_exists $var] || [set $var [$msg prop_get $var]] eq "" } {
 	          unset -nocomplain $var
 	        }
 	      }

 	      if { [info exists phonelazy] } {
 	        dict for {k v} $phonelazy {
 	          if { ![info exists phone] || ![dict exists $phone $k] } {
 	            dict set phone $k $v
 	          }
 	        }
 	      }

 	      if { ![info exists phone] } {
 	        $msg state "nophone"
 	        continue
 	      }

 	      if { [my prop MessageUseHash] } {
 	        # тут проверка на хэш, если добавляем новую мессагу - обязательно с ключем и хэшем если есть, объявлем переменную 'newmessage'
			    regsub -all {[^\w\d]} "[$msg prop subject][lsort -dictionary -increasing -stride 2 -index 0 [$msg prop phone]]" {} hash
			    if { [string length $hash] == 0 } {
			      log "\fRError! hash is empty!"
			      $msg state error
			      continue
			    }
		      # hash is like blob for sqlite3 without this hack
		      set hash [string range "0[binary encode base64 [string range [::md5::md5 $hash] 0 8]]" 1 end]		      
		      if { [set msgid [$db onevalue "SELECT id FROM message WHERE hash = :hash LIMIT 1"]] ne "" } {
		        $msg state "old"
		        if { [info exists key] } {
		          if { [$db onevalue "SELECT 1 FROM message WHERE key = :key AND hash = :hash LIMIT 1"] eq "" && \
		               [$db onevalue "SELECT 1 FROM messageclone WHERE key = :key LIMIT 1"] eq "" } {
		            $db allrows "INSERT INTO messageclone (key,id_message) VALUES (:key,:msgid)"
		          }
		        }
		        continue
		      } {
		        unset msgid
		      }
		    } {
		      set hash ""
		    }

		    if { ![info exists msgid] && [info exists key] } {
		      if { [set msgid [$db onevalue "SELECT id FROM message WHERE key = :key LIMIT 1"]] eq "" && \
		           [set msgid [$db onevalue "SELECT id_message FROM messageclone WHERE key = :key LIMIT 1"]] eq "" } {
		        unset msgid
		      } {
		        $msg state "addon"
		      }
		    }
		    if { ![info exists msgid] } {
		      $db allrows "INSERT INTO message (hash,key) VALUES (:hash,:key)"
		      set msgid [$db onevalue "SELECT last_insert_rowid()"]
		      set newmessage 1
		    } elseif { [info exists key] && $hash ne "" } {
		      $db allrows "UPDATE message SET hash = :hash WHERE id = :msgid"
		    }

		    foreach {k v clean} {url url 0 _date datetime 0 _subject subject 1 _city city 1 _state state 1 _address address 1} {
		      if { [info exists $v] } {
		        if { $clean } {
		          set $v [text2text [set $v]]
		        }
		        $db allrows "UPDATE message SET $k = :$v WHERE id = :msgid AND $k IS NULL"
		      }
		    }
        unset k v clean
		    foreach col [my prop AddFields] {
    		  regsub -all {[^_\w\d]} $col {} col
          if { [$msg prop_exists $col] && [$msg prop_get $col] ne "" } {
            $db allrows "UPDATE message SET _$col = :1 WHERE id = :msgid AND _$col IS NULL" [list msgid $msgid 1 [$msg prop_get $col]]
          }
        }
        unset -nocomplain col

		    foreach { phone name } $phone {
		      set name [text2text $name]
		      if { [info exists phonelazy] && [dict exists $phonelazy $phone] && [llength [$db allrows "SELECT 1 FROM phone WHERE id_message = :msgid AND number = :phone LIMIT 1"]] } \
		        continue
		      if { [llength [$db allrows "SELECT 1 FROM phone WHERE id_message = :msgid AND number = :phone AND name = :name LIMIT 1"]] } \
		        continue

		      set newphone 1
		      if { [info exists newmessage] } {
		        $db allrows "INSERT INTO phone (number,name,id_message) VALUES (:phone,:name,:msgid)"
		      } {
		        $db allrows "INSERT INTO phone (number,name,id_message,id_addon) VALUES (:phone,:name,:msgid,(select ifnull(max(id_addon),0)+1 from phone))"
		      }
		    }
        unset -nocomplain phone name

		    if { ![info exists newphone] && [$msg state] in {done addon} } {
		      $msg state "old"
		    }

 	    }

 	    set MsgOld [$cat child llength "old"]
 	    set MsgNew [$cat child llength "done"]
 	    set MsgErr [$cat child llength "error"]
 	    set MsgAdd [$cat child llength "addon"]
 	    set MsgNPH [$cat child llength "nophone"]

      set key [$cat prop key]
      $db allrows {UPDATE catalog SET state = 1 WHERE key = :key}
      $db allrows {DELETE FROM catalog_temp WHERE key = :key}
      if { [my state] eq "initing" } {
	      log "\fGИнициализация прошла успешно."
      } {
	      log "Каталог \fc'\fC[$cat name]\fc' \fdобработан."
	    }
      log "  Cat\[New: $CatNew\; Old: $CatOld\] Msg\[New: $MsgNew\; Add: $MsgAdd\; Old: $MsgOld\; Err: $MsgErr\] No phone\[$MsgNPH\]"
      $cat destroy

      $db commit
    }

    if { [my state] eq "initing" } {
      my event InitPost
    } elseif { [my state] eq "running" } {
	    my event QueryCatalog
	  } {
	    my event Stoped
	  }
  }

  method checkmsgkey { msg } {
    if { [$msg prop_exists key] && [set key [$msg prop_get key]] ne "" && \
         ([llength [$db allrows {SELECT 1 FROM message WHERE key = :key LIMIT 1}]] ||
          [llength [$db allrows {SELECT 1 FROM messageclone WHERE key = :key LIMIT 1}]]) } {
      return 1
    } {
      return 0
    }
  }

  method evQueryMessage { } {
    my checkstate {running}
    set reqcount 0
    set queue [list]
    foreach cat [my child list {parsed}] {
      incr reqcount [$cat child llength "requesting"]
      lappend queue {*}[$cat child list "queued"]
    }
    while { $reqcount < [my prop ReqMaxMessages] } {
      if { ![llength $queue] } break
      set msg [lindex $queue 0]
      incr reqcount
      set queue [lrange $queue 1 end]
      $msg state "requesting"
      $msg event Request
    }
  }

  method http_request { { args {
    {-callback  string -allowempty false}
    {-object    string -allowempty false}
    {-request   string -allowempty false}
    {-parse     string -default {}}
  }}} {
    ::procarg::parse
	  set headers [list \
	    {Accept-Encoding} {gzip;q=1.0,deflate;q=0.9,compress;q=0.8,identity;q=0.5,*;q=0.1} \
      {Accept-Language} {ru-RU} \
    ]
    if { [my prop ReqCookies] && [dict size $Cookies] } {
	    set cook [list]
	    dict for {k v} $Cookies {
	      lappend cook "${k}=${v}"
#	      log "SET Cookie: $k = $v"
	    }
	    lappend headers "Cookie" [join $cook "; "]
      unset cook
    }
    set cmd [list \
	    ::ckl::http::geturl [$opts(-request) URL] \
  	    -timeout [my prop ReqTimeout] \
    	  -strict 0 \
      	-headers $headers \
      	-checkonline \
    ]
    if { [$opts(-object) prop proxy] } {
      lappend cmd -proxytag $ID
      if { ![info exists ProxyMaxRequests] || [my prop ProxyMaxRequests] != $ProxyMaxRequests } {
        ::ckl::http::configproxy $ID MaxRequests [set ProxyMaxRequests [my prop ProxyMaxRequests]]
      }
      if { ![info exists ProxyTimeout] || [my prop ProxyTimeout] != $ProxyTimeout } {
        ::ckl::http::configproxy $ID Timeout [set ProxyTimeout [my prop ProxyTimeout]]
      }
    }
    if { [$opts(-request) exists QUERY] && [$opts(-request) QUERY] ne "" } {
      lappend cmd -query [$opts(-request) QUERY]
    }
    if { [my prop ReqLog] } {
      set fd [open "debug.[my id].[format %04d [incr DebugReqCounter]].out.log" w]
      fconfigure $fd -encoding utf-8
      puts $fd $cmd
      close $fd
    }
    $opts(-request) HTTPToken [{*}$cmd -callback [list [self] http_callback $opts(-callback) $opts(-object) $opts(-request) $opts(-parse) $DebugReqCounter]]
  }

  method http_callback { callback obj req parse dbg token } {
    if { $dbg } {
      catch {
	      set fd [open "debug.[my id].[format %04d $dbg].inMETA.log" w]
	      fconfigure $fd -encoding utf-8
	      foreach {mk mv} [::ckl::http::meta $token] {
	        puts $fd "${mk}: $mv"
	      }
	      close $fd
	      set fd [open "debug.[my id].[format %04d $dbg].inDATA.log" w]
	      fconfigure $fd -encoding utf-8
	      if { [my prop_exists Encoding] && [set enc [my prop Encoding]] ne "" } {
	        puts -nonewline $fd [encoding convertfrom $enc [::ckl::http::data $token]]
	      } {
		      puts -nonewline $fd [::ckl::http::data $token]
		    }
	      close $fd
	    }
    }
    $req unset HTTPToken
    set onerror [my prop OnError]
    if { [dict exists $onerror Request $parse] } {
      set onerror [dict get $onerror Request $parse]
    } {
      set onerror [list]
    }
    switch -- [::ckl::http::status $token] {
      "ok" {
        if { [my prop ReqCookies] } {
	        foreach {mk mv} [::ckl::http::meta $token] {
	          if { $mk ne "Set-Cookie" } continue
#           log "Meta:$mk '${mv}'"
	          set mv [split [lindex [split $mv "\;"] 0] =]
	          dict set Cookies [string trim [lindex $mv 0]] [string trim [join [lrange $mv 1 end] =]]
#	          log "SET [string trim [lindex $mv 0]] [string trim [join [lrange $mv 1 end] =]]" -file
    	    }
          unset -nocomplain mk mv
        }
        if { [::ckl::http::ncode $token] == 200 } {          
          if { [my prop_exists Encoding] && [set enc [my prop Encoding]] ne "" } {
            if { [catch {encoding convertfrom $enc [::ckl::http::data $token]} [info object namespace $req]::ReqRAW] } {
              log "Error while convert from enc '$enc'..." -file
              log "Data: [::ckl::http::data $token]" -file
              set errmsg "ERROR! Cant convert body from encoding '$enc'."
            }
          } {
            set [info object namespace $req]::ReqRAW [::ckl::http::data $token]
          }
          if { $parse ne "" } {
            if { ![my prop_exists ReqAutoParse$parse] } {
              set errmsg "ERROR! Bad auto parse type: '${parse}'"
            } {
              switch -- [my prop ReqAutoParse$parse] {
                "html" {
                  if { [catch {$req parse "html"} errmsg] } {
                    set errmsg "ERROR! while auto parse: $errmsg"
                  } {
                    unset errmsg
                  }
                }
                "json" {
                  if { [catch {$req parse "json"} errmsg] } {
                    set errmsg "ERROR! while auto parse: $errmsg"
                  } {
                    unset errmsg
                  }
                }                
                "" {
                }
                default {
                  set errmsg "ERROR! Bad auto parse mode: '[my prop ReqAutoParse$parse]'"
                }
              }
            }
          }
          if { ![info exists errmsg] } {
	          ::ckl::http::cleanup $token
	          $req Status [list ok]
	          tailcall {*}$callback
	        } {
            set force_skip 1
	        }
        } {
	        if { [::ckl::http::ncode $token] in {500 404} } {
  	        set force_skip 1
    	    }
    	    set errmsg "ERROR! HTTP code: [::ckl::http::ncode $token]."
	        foreach {mk mv} [::ckl::http::meta $token] {
  	        log "Meta:$mk '${mv}'" -file
    	    }
        }
      }
      "error" - "ierror" {
	      set errmsg "ERROR! [::ckl::http::error $token]."
      }
      "timeout" {
	      set errmsg "ERROR! Timeout."
      }
      "reset" {
        set errmsg "RESET"
        set reset_skip 1
      }
      default {
	      set errmsg "ERROR! Unknown, status: [http::status $token]."
      }
    }
    ::ckl::http::cleanup $token
    $req Attempt [expr { [$req Attempt] + 1 }]
    if { [$obj prop proxy] && ![info exists reset_skip] } {
      ::ckl::http::forcebanproxy $ID
      unset -nocomplain force_skip
      append errmsg " Switch proxy."
    }
#    if { [info exists force_skip] || [info exists reset_skip] || ([my prop ReqMaxAttempts] > 0 && [$req Attempt] >= [my prop ReqMaxAttempts]) } { }
    if { [info exists reset_skip] } {
      $req Status [list reset stop]
      $req Message "Reset connection by self."
    } elseif { [my prop ReqMaxAttempts] > 0 && [$req Attempt] >= [my prop ReqMaxAttempts] } {
      $req Status [list error stop]
      $req Message "$errmsg Force stop."
    } {
      $req Status [list error continue]
      $req Message "$errmsg Continue after [expr { [my prop ReqContinueTimeout] / 1000 }] secs [$req Attempt]/[my prop ReqMaxAttempts]"
      after [my prop ReqContinueTimeout] [list [self] http_request -callback $callback -object $obj -request $req -parse $parse]
    }
    tailcall {*}$callback
  }

  method db {} { return $db }
}
