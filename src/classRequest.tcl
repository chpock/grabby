# classRequest.tcl - part of grabby
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

package require tclgumbo
package require tdom
package require json

::oo::class create RequestClass {
  variable ReqStatus
  variable ReqRAW
  variable ReqDATA
  variable ReqMODE
  variable ReqMessage
  variable ReqAttempt
  variable ReqURL
  variable ReqQUERY
  variable ReqHTTPToken

  variable ReqVariables

  constructor { } {
    set ReqVariables {Status Message RAW Attempt URL DATA MODE QUERY HTTPToken}
  }

#  method reqvar { name args } {
#    if { $name in {Status Message RAW Attempt URL DOM} } {
#      if { [llength $args] == 1 } {
#        set Req$name [lindex $args 0]
#      } elseif { [llength $args] == 0 } {
#        set Req$name
#      } {
#        error "Error: req_var wrong num args: $name $args"
#      }
#    } {
#      error "Error: req_var wrong var name '${name}'."
#    }
#  }

  # Возвращает список нодов
  #  -first - возвращает парвую ноду
  #  -astext - возвращает список текстов нод (или тект первой ноды с -first)
  #  -noempty - проверка ошибок, падать если нет результата
  #  -nomulti - проверка ошибок, падать если несколько результатов
  #  -once    - комбинация -noempty -nomulti -first

  method selectNodes { select { args {
    {-astext  switch}
    {-first   switch}
    {-noempty switch}
    {-nomulti switch}
    {-once    switch}
  }}} {
    ::procarg::parse
    set nodes [$ReqDATA selectNodes $select]
    if { $opts(-once) } {
      if { [llength $nodes] > 1 || ![llength $nodes] } {
	      log "error while selecting nodes '$select' - once restrict" -file
	      log "node: [$ReqDATA asHTML]" -file
	      return -code error "error while selecting nodes '$select' - once restrict"
	    }
	    set opts(-first) 1
    }
    if { $opts(-noempty) && ![llength $nodes] } {
      log "error while selecting nodes '$select' - noempty restrict" -file
      log "node: [$ReqDATA asHTML]" -file
      return -code error "error while selecting nodes '$select' - noempty restrict"
    }
    if { $opts(-nomulti) && [llength $nodes] > 1 } {
      log "error while selecting nodes '$select' - nomulti restrict" -file
      log "node: [$ReqDATA asHTML]" -file
      return -code error "error while selecting nodes '$select' - nomulti restrict"
    }
    if { [llength $nodes] && $opts(-astext) } {
      if { $opts(-first) } {
        return [[lindex $nodes 0] asText]
      }
	    set res [list]
	    foreach node $nodes {
	      lappend res [$node asText]
	    }
	    set nodes $res     
    }
    if { $opts(-first) } {
      return [lindex $nodes 0]
    }
    return $nodes
  }

  method unknown { name args } {
    if { [string match {[A-Z]*} $name] } {
      if { $name ni $ReqVariables } {
        error "RequestCalss: unknown variable to access: '$name' '$args'"
      }
      if { ![llength $args] } {
        return [set Req$name]
      } elseif { [llength $args] == 1 } {
        return [set Req$name [lindex $args 0]]
      } {
        error "wrong args num for RequestClass: '$name' '$args'"
      }
    }
    error "unknown method '$name' for RequestClass."
  }

  method exists { name } {
    if { $name in $ReqVariables } {
      info exists Req$name
    } {
      error "RequestCalss: unknown variable to exists method: '$name'"
    }
  }

  method cleanup { } {
    unset ReqRAW
  }

  method unset { name } {
    if { $name in $ReqVariables } {
      unset Req$name
    } {
      error "RequestCalss: unknown variable to unset method: '$name'"
    }
  }

  method parse { mode } {
    switch -- $mode {
      "html" {        
        my RequestParseHTML
      }
      "json" {
        my RequestParseJSON
      }
    }
  }

  method RequestParseJSON { } {
    set ReqMODE "json"
    try {
	    set ReqDATA [json::json2dict $ReqRAW]
	  } on error { r o } {
	    unset ReqMODE
	    unset -nocomplain ReqDATA
	    return -options $o $r
	  }
  }

  method RequestParseHTML { } {
    set ReqMODE "html"
    try {
# dirty HACK!!!
#   grumbo failed on text '&#128528;', '&#128522;' etc.
      regsub -all {(&#\d{5})\d+;} $ReqRAW {\1;} ReqRAW
# end dirty HACK
			set parsed [::gumbo::parse $ReqRAW]
			set root [::gumbo::output_get_root $parsed]

			set ReqDATA [dom createDocument html]
			set rootDOM [$ReqDATA documentElement]
			$rootDOM baseURI $ReqURL

      my RequestParseHTML_ $root $rootDOM
    } on error { r o } {
      unset ReqMODE
      if { [info exists ReqDATA] } {
        $ReqDATA delete
        unset ReqDATA
      }
      return -options $o $r
    } finally {
      if { [info exists parsed] } {
        ::gumbo::destroy_output $parsed
      }
    }
  }

  method RequestParseHTML_ { from to {root 1} } {
	  set type [::gumbo::node_get_type $from]
	  switch -- $type {
			1 {
	      set tag [::gumbo::element_get_tag_name $from]
	      if { $tag eq "" } {
	        set tag "null"
	      }
	      if { !$root } {
		      set newNode [$ReqDATA createElement $tag]
		      $to appendChild $newNode
		    } {
		      set newNode $to
		    }
			  set attr [::gumbo::element_get_attributes $from]
			  if { [array exists $attr] && [array size $attr] } {
			    $newNode setAttribute {*}[array get $attr]
			  }
		    unset -nocomplain $attr
			  foreach child [::gumbo::element_get_children $from] {
			    my RequestParseHTML_ $child $newNode 0
			  }
			}
			2 {
			  set newNode [$ReqDATA createTextNode [::gumbo::text_get_text $from]]
			  $to appendChild $newNode
			}
	  }
  }

  destructor {
    if { [info exists ReqMODE] } {
      switch -- $ReqMODE {
        "html" {
          if { [info exists ReqDATA] } {
            $ReqDATA delete
          }
        }
      }
    }
  }

}
