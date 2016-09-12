package provide decodedata 0.0.1

namespace eval ::decodedata {
 
# Variable for the path of the script
variable home [file join [pwd] [file dirname [info script]]]
 
}

#========================================================================================
proc ::decodedata::IEEE2float {inputString} {
#
# преобразование строки в число с плавающей точкой
#
	if { [regexp {^[[:xdigit:]]{8}$} $inputString] } {
 		if {$inputString == "ffffffff"} {
			return -1000
		} else { 
	 		set hex $inputString
	 		set bin [binary format H8 $hex]
			binary scan $bin R* float
            if {$float == $float} {
                return $float
            } else {
                return 0
            }
		}
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_force {in_str} {
#
# расшифровать усилие
#
	set force ""
	if {[string equal $in_str "FF900000"]} {return -1000}
	if {[string equal $in_str "FF800000"]} {return -500}
    if {[string is integer 0x$in_str]} {
        #set tmp_force [format %.1f [expr 0.1 * [expr {[scan ${in_str}ff %x] >> 8}]]]
        set tmp_force [format %.1f [expr 0.1 * [expr {[scan ${in_str} %x] >> 0}]]]
    } else {
        return 0
    }
	#if {$tmp_force < 0} {return 0}
    if {[expr abs($tmp_force)] > 3000} {return 0}
	return $tmp_force
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_temperature {in_str} {		
#
# расшифровать температуру
#
	set temperature ""
	if {[string equal $in_str "9000"]} {return -1000}
	if {[string equal $in_str "8000"]} {return -500}
    if {[string is integer 0x$in_str]} {
        set tmp_temperature [format %.1f [expr 0.5 * [expr {[scan ${in_str}ffff %x] >> 16}]]]
    } else {
        return 0
    }
#    if {$tmp_temperature < 0} {return 0}
	return $tmp_temperature
	#return [format %.1f [expr 0.5 * [expr {[scan ${in_str}ffff %x] >> 16}]]]
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_U {in_str} {
#
# расшифровка напряжений
#
	set value ""
	if {[scan $in_str "%x" value]} {
		return [format %.1f [expr 0.1 * $value]]
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_nWind {in_str} {
#
# расшифровка направления ветра
#
	set value ""
	if {[scan $in_str "%x" value]} {
		return [expr 360 * $value / 1024]
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_tHumid {in_str} {
#
# расшифровка температуры датчика влажности
#
	set value ""	
	set ret_value ""
	if {[scan $in_str "%x" value]} {
		if {$value == 65535} {return 0}
		set ret_value [expr 0.01 * $value - 39.6]		
		return [format %.1f $ret_value]
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_Humid {in_str} {
#
# расшифровка показаний датчика влажности
#
	set value ""	
	set ret_value ""
	if {[scan $in_str "%x" value]} {
		if {$value == 65535} {return 0}
		set ret_value [expr -4 + 0.04 * $value + (-2.8 * 0.000001) * $value * $value]
		if {$ret_value < 0} { set ret_value 0}
		if {$ret_value > 100} { set ret_value 100}
		return [format %.1f $ret_value]
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc ::decodedata::decode_vWind {in_str} {
	set value ""
	if {[scan $in_str "%x" value]} {
		if {$value == 0} {
			return 0			
		} else {
			return [format %.1f [expr 1000.0 / $value]]
		}
	} else {
		return 0
	}
}
#========================================================================================