lappend auto_path [file join $env(HOME) caller_manager lib decodedata]
lappend auto_path [file join $env(HOME) caller_manager lib modbusascii]

  package ifneeded app-caller_manager 1.0 [list source [file join $dir caller_manager.tcl]]

