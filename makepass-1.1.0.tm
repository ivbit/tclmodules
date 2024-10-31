# \
Intellectual property information START \
\
Copyright (c) 2024 Ivan Bityutskiy \
\
Permission to use, copy, modify, and distribute this software for any \
purpose with or without fee is hereby granted, provided that the above \
copyright notice and this permission notice appear in all copies. \
\
THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES \
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF \
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR \
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES \
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN \
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF \
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. \
\
Intellectual property information END

# \
Description START \
\
The module provides 'makepass' ensemble command which is used to produce a \
string with random elements from one of the lists stored in the main \
dictionary. The intended use is to store random characters in those lists and \
produce unique passwords out of them. The user only has to add/remove an entry \
to/from the main dictionary, everything else is generated automatically. The \
key associated with the list entry will be used to generate a subcommand for \
'makepass' ensemble command, for example 'makepass norm'. Subcommands can be \
imported into namespace: 'namespace eval ns {namespace import ::makepass::*}'. \
Public interface consists of 'makepass' and 'makepass::pkgconfig' commands. \
Installation: \
OS: GNU/Linux only. \
Place the module file into one of directories returned by \
join [tcl::tm::path list] \n \
Or add a custom directory to the Tcl module path with \
tcl::tm::path add [file normalize ~/myTclModules] \
Usage: \
package require makepass \
makepass::pkgconfig list \
makepass::pkgconfig get norm \
makepass norm \
makepass norm 12 \
\
Description END

package require Tcl 8.6-

namespace eval makepass {
  namespace eval core {
    # Main dictionary START
    variable data [
      dict create \
        alnum [
          list 0 1 2 3 4 5 6 7 8 9 A B C D E F \
               G H I J K L M N O P Q R S T U V \
               W X Y Z a b c d e f g h i j k l \
               m n o p q r s t u v w x y z
        ] \
        norm [
          list # $ % & ( ) * + - . 0 1 2 3 4 5 6   \
               7 8 9 : \; = > ? @ A B C D E F G H  \
               I J K L M N O P Q R S T U V W X Y   \
               Z \[ \] ^ _ a b c d e f g h i j k l \
               m n o p q r s t u v w x y z \{ | \}
        ] \
        greek [
          list Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π   \
               Ρ Σ Τ Υ Φ Χ Ψ Ω α β γ δ ε ζ η θ   \
               ι κ λ μ ν ξ ο π ρ σ ς τ υ φ χ ψ ω
        ] \
        rus [
          list А Б В Г Д Е Ё Ж З И Й К Л М Н О П \
               Р С Т У Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я   \
               а б в г д е ё ж з и й к л м н о   \
               п р с т у ф х ц ч ш щ ъ ы ь э ю я
        ]
    ]
    # Main dictionary END

    # Procedure definitions START
    proc checklen {len keylen} {
      set len [
        string trimleft [
          string trim $len
        ] 0
      ]
      if {
        [string is integer -strict $len] &&
        [string is digit -strict $len] &&
        $len > 0 &&
        $len <= $keylen
      } {
        return $len
      } {
        return $keylen
      }
    }

    # \
    Procedure returns a list of random numbers in range (0..$max-1) suitable \
    for use by 'lindex' command. 8 bytes == 64 bit integer, amount specified \
    in '$bytes' gets multiplied by 8 to convert it into amount of bytes to \
    be read, then it gets multiplied by 10 (total 80) to 'chan read' enough \
    bytes for producing a string with all unique characters in it and it's \
    length to be equal to number specified in '$bytes'.
    proc getrandom {bytes max} {
      set urandom [open /dev/urandom rb]
      binary scan [
        chan read $urandom [expr {$bytes * 80}]
      ] mu* rlist
      chan close $urandom
      foreach num $rlist {
        lappend result [expr {$num % $max}]
      }
      return $result
    }

    proc makepass {key len keylen} {
      set charset [dict get [set [namespace current]::data] $key]
      set len [checklen $len $keylen]
      set password {}
      foreach num [getrandom $len $keylen] {
        set char [lindex $charset $num]
        if {![string match *\\${char}* $password]} { 
          append password $char
        }
      }
      set password [string range $password 0 $len-1]
      return $password
    }
    # Procedure definitions END
  }
  # namespace eval core END
  
  # Protecting 'throw' command by escaping '$subcommand' with 'list' command.
  proc pkgconfig {subcommand {key *}} {
    set subcommand [list $subcommand]
    switch $subcommand {
      get {
        dict get $core::data $key
      }
      list {
        lsort -dictionary [dict keys $core::data $key]
      }
      default {
        throw "TCL LOOKUP INDEX subcommand $subcommand" \
          "Bad subcommand \"$subcommand\": must be \"get\" or \"list\"."
      }
    }
  }

  # Initialize the module
  proc init {} {
    foreach key [pkgconfig list] {
      dict set core::data ${key}len [
        set keylen [
          llength [pkgconfig get $key]
        ]
      ]
      lappend subcommands $key
      try "
          proc $key {{password_length $keylen}} {
            tailcall core::makepass $key \$password_length $keylen
          }
      "
    }
    namespace export {*}$subcommands
    namespace ensemble create -subcommands $subcommands
    rename [namespace current]::init {}
  }

  init
  package provide makepass 1.1.0
}
# namespace eval makepass END

# END OF MODULE

