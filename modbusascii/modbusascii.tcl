package provide modbusascii 0.0.1

namespace eval ::modbusascii {
 
# Variable for the path of the script
variable home [file join [pwd] [file dirname [info script]]]
 
}

#==============================================================================
proc ::modbusascii::calculateLRC {message} {
    set result 0
    
    if { [regexp {^[[:xdigit:]]*$} $message] } {    
        for {set i 0} {$i < [string length $message]} {set i [expr $i + 2]} {
            set numeric 0x[string range $message $i [expr $i + 1]]
            set result [expr $result + $numeric]    
        }        
        set result [expr (~$result & 0xFF) + 1]
    } else {
        puts "Error calculating LRC\r\n"
        set result 0
    }
    return $result    
}

#========================================================================================
proc ::modbusascii::write_register_cmd {slave_num register_num register_data} {
    set cmd ""
    append cmd [format %02X $slave_num]
    append cmd "10"
    append cmd [format %04X $register_num]
    append cmd "000102"
    append cmd [format %04X $register_data]    
    append cmd [format %04X [::modbusascii::calculateLRC $cmd]]
    return ":${cmd}\r\n"
}
#========================================================================================
proc ::modbusascii::write_registers_cmd0 {slave_num register_num register_data} {
    set cmd ""
    append cmd [format %02X $slave_num]
    append cmd "10"
    append cmd [format %04X $register_num]
    append cmd "000204"
    append cmd [format %08X $register_data]    
    append cmd [format %04X [::modbusascii::calculateLRC $cmd]]
    return ":${cmd}\r\n"
}
#========================================================================================
proc ::modbusascii::write_registers_cmd {slave_num register_num data_list} {
    set cmd ""
    append cmd [format %02X $slave_num]
    append cmd "10"
    
    append cmd [format %04X $register_num]
    
    set list_length [llength $data_list]
    append cmd [format %04X $list_length]
    append cmd [format %02X [expr 2 * $list_length]]
    
    for {set i 0} {$i < $list_length} {incr i} {
        append cmd [format %04X [lindex $data_list $i]]
    }
    
    #append cmd "000102"
    #append cmd [format %04X $register_data]    
    append cmd [format %04X [::modbusascii::calculateLRC $cmd]]
    return ":${cmd}\r\n"
}
#==============================================================================
proc ::modbusascii::read_registers_cmd {slave_num register_num num_of_registers} {
    set cmd ""
    append cmd [format %02X $slave_num]
    append cmd "03"
    append cmd [format %04X $register_num]
    append cmd [format %04X $num_of_registers]
    append cmd [format %02X [::modbusascii::calculateLRC $cmd]]
    return ":${cmd}\r\n"
}
#==============================================================================
