package provide app-caller_manager 1.0
#
# Статусы
#
# "Получение списка номеров из базы"
# "Проверка связи"					
# "Настройка модема"			
# "Установка класса"			
# "Установка DATA-режима"		
# "Установка расширенных параметров"	
# "Звонок"							
# "Запрос данных"
# "Положить трубку"					
# "Сброс модема"						
#
#
#
#========================================================================================
#
#	Для создания старпака
#
set dirname [file dirname [info script]]
set tmpdir  [file join $::env(TEMP) __monitoring__]
file mkdir $tmpdir
foreach dll {libmySQL.dll} {
    if { ![file exists [file join $tmpdir $dll]] } {
        file copy -force [file join $dirname bin $dll] $tmpdir
    }
}
set ::env(PATH) "$tmpdir;$env(PATH)"

package require mysqltcl
#package require tclodbc
package require decodedata
package require modbusascii
#==============================================================================
proc modem_manager {argv} {	
	#set comport [lindex $argv 0]
	#open_port $comport	
}
#==============================================================================
proc serial_receiver {} {
# 
	global working_mode
	global data
	global serial			
	
    if { [eof $serial] } {         
		catch {close $serial}
        return
    }

	if {[catch {read $serial} ans]} {
		set ans ""
	}
	
	if {$ans != ""} {
		append data $ans
	}
	
	check_etap_completed
	
}
#==============================================================================
proc on_status_changed {name1 name2 op} {
	global status
	global serial
	global port_id
	global newStatusRegister
	global write_request
    
    global phoneToCall
    global reservePhoneToCall
    global postList
    global callEnabled
    global writeEnabled
    global time_priem_zvonka period_zvonka

	global timeshift
	
	set waiting_time 0
	put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Статус: $status"
	switch $status {
        "Получение списка номеров из базы"  {
                                                if {[llength $postList] == 0} {
                                                    set db_port {3306}
                                                    set db_host {127.0.0.1}
                                                    set db_user {frost}
                                                    set db_password {frost}																	
                                                
                                                    if [catch {mysqlconnect -host $db_host -port $db_port -user $db_user -password $db_password -db monitoringdata -encoding utf-8} mysql_handler] {
                                                        put_to_log "[clock format [clock seconds] -format %T] -- Не могу соединиться с базой данных"
                                                        break
                                                    } else {
                                                        mysqlexec $mysql_handler {SET NAMES 'utf8'}
                                                        mysqlexec $mysql_handler {SET character_set_client='utf8'}
                                                        mysqlexec $mysql_handler {SET character_set_connection='utf8'}
                                                        
                                                        set sql "SELECT phoneNumber, mainPhoneNumber, reservePhoneNumber, callingInterval, lastCallingTime, TIME_PRIEM_ZVONKA, PER_ZVONKA FROM post_parameters"
                                                        
                                                        set postList [mysqlsel $mysql_handler $sql -list]
                                                        mysqlclose $mysql_handler	                                                                                                       
                                                        #put_to_log "[clock format [clock seconds] -format %T] -- new postList -> $postList"  
                                                    }
                                                }
                                                
                                                set currentPost [lindex $postList 0]
                                                set postList [lreplace $postList 0 0]
                                                set callingInterval [lindex $currentPost 3]
                                                set qwerty [lindex $currentPost 4]
                                                set time_priem_zvonka [lindex $currentPost 5]
                                                set period_zvonka [lindex $currentPost 6]
                                                set lastCallingTime [clock scan [lindex $currentPost 4] -format "%Y-%m-%d %T"]
#                                                set currentTime [expr [clock seconds] - 3600]
                                                set currentTime [expr [clock seconds] - $timeshift]
                                                put_to_log "lastCallingTime -> $lastCallingTime\ncurrentTime -> $currentTime"
                                                
                                                set delta [expr $currentTime - $lastCallingTime]
                                                set intervalSeconds [expr 60 * $callingInterval]
                                                put_to_log "$delta <----> $intervalSeconds"
                                                
                                                if {$delta < $intervalSeconds} {
                                                    set callEnabled 0
                                                } else {
                                                    set callEnabled 1
                                                }
                                                                                                
                                                #put_to_log "[clock format [clock seconds] -format %T] -- postList -> $postList"
                                                set phoneToCall [lindex $currentPost 1]
                                                set reservePhoneToCall [lindex $currentPost 2]
                                                
                                                set waiting_time 15
												after [expr $waiting_time * 1000] err_timer
                                            }
		"Проверка связи"					{
												set cmd "AT\r"												
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 5
												after [expr $waiting_time * 1000] err_timer
											}
		"Настройка модема"					{																				
												set cmd "ATE0\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 1							
												after [expr $waiting_time * 1000] err_timer												
											}		
		"Установка класса"					{																				
												set cmd "AT+FCLASS=0\r"
                                                #set cmd "AT\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 1										
												after [expr $waiting_time * 1000] err_timer
											}		
		"Установка DATA-режима"				{
												set cmd "AT+CSNS=0\r"
                                                #set cmd "AT\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 1
												after [expr $waiting_time * 1000] err_timer
											}
		"Установка расширенных параметров"	{
												set cmd "AT+CRC=1;+CLIP=1\r"
                                                #set cmd "AT\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 1
												after [expr $waiting_time * 1000] err_timer
											}									
		"Звонок"						    {
												#set cmd "ATD+79372417364\r"
                                                set cmd "ATD${phoneToCall}\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
											}
        "Звонок на резервный"			    {
												#set cmd "ATD+79372417364\r"
                                                set cmd "ATD${reservePhoneToCall}\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
											}                                            
		"Запрос данных 1" 					{
												set cmd ":010300000019E3\r\n"
												puts -nonewline $serial $cmd
												flush $serial
                                                set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
											}                                            
        "Запрос данных 2" 					{
												set cmd ":01031000002EBE\r\n"
												puts -nonewline $serial $cmd
												flush $serial
                                                set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
											}                                                                                        
        "Запрос данных 3" 					{
												set cmd ":010320000003D9\r\n"
												puts -nonewline $serial $cmd
												flush $serial
                                                set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
											}
        "Установка параметров поста"        {        
                                                #set cmd ":010320000003D9\r\n"
                                                set cmd [::modbusascii::write_registers_cmd 1 23 [list [expr 60 * $time_priem_zvonka] [expr 60 * $period_zvonka]]]
												puts -nonewline $serial $cmd
												flush $serial
                                                set waiting_time 60
												after [expr $waiting_time * 1000] err_timer
                                            }
        "Режим команд"                      {
                                                set cmd "+++"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 10
												after [expr $waiting_time * 1000] err_timer        
                                            }
		"Положить трубку"					{
												set cmd "ATH0\r\n"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 1
												after [expr $waiting_time * 1000] err_timer
											}
		"Сброс модема"						{
												set cmd "ATZ\r"
												puts -nonewline $serial $cmd
												flush $serial
												set waiting_time 5
												after [expr $waiting_time * 1000] err_timer
											}
	}						
	#($status != "Получить данные") ||
	
	if {$status != "Ожидание"} {
	#	
		if {$status != "Получить данные"} {
		#	
			#puts stdout "Status is $status\n"
			
		}
	}
	
	if {$status != "Ожидание"} {
		
	}
	
	if {$status == "Снять трубку"} {
		#after [expr 30 * 1000] err_timer
	}
	
	if {$status == "Сброс модема"} {
		#after [expr $waiting_time * 1000] err_timer
	}
	
	if {$status == "Проверка связи"} {
		#after [expr $waiting_time * 1000] err_timer
	}
	
	#if {$status == "Снять трубку"} {after [expr 30 * 1000] err_timer}
		
}
 #==============================================================================
 proc err_timer {} {
 #
	global serial
	global status
	
	switch $status {
    "Запрос данных 1" -
    "Запрос данных 2" -
    "Запрос данных 3"   {
                        set status "Режим команд"
                        }
    "Звонок"            {
                        set status "Звонок на резервный"
                        } 
    "Получение списка номеров из базы" {
                                        set status  "Настройка модема"
                                        } 
    default             {
                        set status "Проверка связи"
                        }
    }
    
}
#==============================================================================
#========================================================================================
proc check_etap_completed {} {
	global status data
	global port_id
    global callEnabled
    global writeEnabled
	
	switch $status {
        "Проверка связи"					{
												set response "OK\r\n"
												set next_status "Получение списка номеров из базы"
											}
        "Получение списка номеров из базы"  {
                                                set data ""
                                                after cancel err_timer
                                                #put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Выполнено: $status"
                                                set status "Настройка модема"
                                                return
                                            }		
		"Настройка модема"					{																				
												set response "OK\r\n"
												set next_status "Установка класса"
											}		
		"Установка класса"					{																				
												set response "OK\r\n"
												set next_status "Установка DATA-режима"
											}		
		"Установка DATA-режима"				{
												set response "OK\r\n"
												set next_status "Установка расширенных параметров"
											}
		"Установка расширенных параметров"	{
												set response "OK\r\n"
                                                
                                                if {$callEnabled == 0} {
                                                    set next_status "Получение списка номеров из базы"                                                    
                                                } else {
                                                    set next_status "Звонок"
                                                }
											}
		"Звонок"    						{
												set response ".*CONNECT.*\r\n"
												set next_status "Запрос данных 1"
											}
        "Звонок на резервный"				{
												set response ".*CONNECT.*\r\n"
												set next_status "Запрос данных 1"
											}                                            
		"Запрос данных 1" 					{
												set response "\r\n"
												set next_status "Запрос данных 2"
											}
        "Запрос данных 2" 					{
												set response "\r\n"
												set next_status "Запрос данных 3"
											}
        "Запрос данных 3" 					{
												set response "\r\n"
                                                if {$writeEnabled == 1} {
                                                    set next_status "Установка параметров поста"
                                                } else {
                                                    set next_status "Режим команд"
                                                }
											} 
        "Установка параметров поста"        {
                                                set response "\r\n"
                                                set next_status "Режим команд"
                                            }
        "Режим команд"                      {
                                                set response "OK\r\n"
												set next_status "Положить трубку"
                                            }
		"Положить трубку"					{
												set response "OK\r\n"
												set next_status "Сброс модема"
											}
		"Сброс модема"						{
												set response "OK\r\n"
												set next_status "Получение списка номеров из базы"
											}
	}		
	
	if {[regexp $response $data]} {			
		if {$status == "Запрос данных 3"} {
			after cancel err_timer
			put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> $data"
			#parse_and_save $data
		}
        if {$status == "Запрос данных 2"} {
			after cancel err_timer
			put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> $data"
			parse_000 $data
		}
        if {$status == "Запрос данных 1"} {
			after cancel err_timer
			put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> $data"
			#parse_000 $data
            set writeEnabled [is_write_enabled $data]
		}
		#put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Выполнено: $status <> Ответ: [string trim $data]"
        set data ""
		after cancel err_timer
		
		set status $next_status
	} else {
        if {$status == "Звонок"} {
            if {[regexp ".*NO .*\r\n" $data]} {                
                after cancel err_timer
                put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Нет связи: $status <> Ответ: [string trim $data]"
                set data ""
                set status "Звонок на резервный"
            }
        }
        if {$status == "Звонок на резервный"} {
            if {[regexp ".*NO .*\r\n" $data]} {                
                after cancel err_timer
                put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Нет связи: $status <> Ответ: [string trim $data]"
                set data ""
                set status "Положить трубку"
            }
        }
    }
	
}
#==============================================================================
proc is_write_enabled {message} {
    global time_priem_zvonka period_zvonka    
    # 0x0017 time_priem_zvonka 
    # 0x0018 period_zvonka
    set local_time_priem_zvonka [expr 0x[string range $message 99 102] / 60]
    set local_period_zvonka [expr 0x[string range $message 103 106] / 60]
    
    if {$local_time_priem_zvonka != $time_priem_zvonka} {
        #put_to_log "local_time_priem_zvonka != time_priem_zvonka"
        return 1
    }
    if {$local_period_zvonka != $period_zvonka} {
        #put_to_log "local_period_zvonka != period_zvonka"
        return 1
    }
    
    
    return 0
}
#==============================================================================
proc parse_000 {message} {
    global phoneToCall

    for {set i 0} {$i < 10} {incr i} {
        #set F${i} [::decodedata::decode_force [string range $message [expr 9 + $i * 12] [expr 9 + $i * 12 + 5] ]]        
        set F${i} [::decodedata::decode_force [string range $message [expr 7 + $i * 12] [expr 7 + $i * 12 + 7] ]]                
        set T${i} [::decodedata::decode_temperature [string range $message [expr 15 + $i * 12] [expr 15 + $i * 12 + 3]]]                
    }
    
    set t_vlagn [::decodedata::decode_tHumid  [string range $message 127 130 ]]
    set vlagn [::decodedata::decode_Humid  [string range $message 131 134]]
    
    set napr_vetr [::decodedata::decode_nWind [string range $message 135 138]]
    set skor_vetr [::decodedata::decode_vWind [string range $message 139 142]]
    set napr_pit [::decodedata::decode_U [string range $message 145 146]]
    set t_ds18s20 [::decodedata::decode_temperature [string range $message 147 150]]
    set u_zar [::decodedata::decode_U [string range $message 153 154]]
    set u_bat [::decodedata::decode_U [string range $message 157 158]]
    set zaryad [format %.1f [::decodedata::IEEE2float [string range $message 159 166]]]
    set razryad [format %.1f [::decodedata::IEEE2float [string range $message 167 174]]]
    set t_iptv [format %.1f [::decodedata::IEEE2float [string range $message 175 182]]]
    set v_iptv [format %.1f [::decodedata::IEEE2float [string range $message 183 190]]]
    if {$v_iptv > 100} {set v_iptv 98}
    
    put_to_log "[clock format [clock seconds] -format %T] -- \n
    F0 -> $F0; F1 -> $F1; F2 -> $F2; F3 -> $F3; F4 -> $F4;\n
    F5 -> $F5; F6 -> $F6; F7 -> $F7; F8 -> $F8; F9 -> $F9;\n
    humidSHT75 -> $vlagn; t_humidSHT75 -> $t_vlagn; napr_vetr -> $napr_vetr; skor_vetr -> $skor_vetr;\n
    napr_pit -> $napr_pit; t_ds18s20 -> $t_ds18s20; u_zar -> $u_zar; u_bat  -> $u_bat; \n
    zaryad -> $zaryad; razryad -> $razryad; t_iptv -> $t_iptv; v_iptv -> $v_iptv"
    
    set db_port {3306}
    set db_host {127.0.0.1}
    set db_user {frost}
    set db_password {frost}																	

    if [catch {mysqlconnect -host $db_host -port $db_port -user $db_user -password $db_password -db monitoringdata -encoding utf-8} mysql_handler] {
        put_to_log "[clock format [clock seconds] -format %T] -- Не могу соединиться с базой данных"
        break
    } else {
        mysqlexec $mysql_handler {SET NAMES 'utf8'}
        mysqlexec $mysql_handler {SET character_set_client='utf8'}
        mysqlexec $mysql_handler {SET character_set_connection='utf8'}
                                                                            
        set sql "UPDATE post_parameters SET lastCallingTime = NOW() WHERE phoneNumber = $phoneToCall"
        if {[catch {mysqlexec $mysql_handler $sql} tmpError]} {
					put_to_log "[clock format [clock seconds] -format %T] -- Ошибка $tmpError\nЗапрос: $sql"
        }
        
        set sql "INSERT INTO monitoringtable (dateOfMeasurement, phoneNumber, nWind, vWind, tHumid, vlagn, uPit, uBat, uZar, T_DS18S20, t_IPTV, v_IPTV, F0, F1, F2, F3, F4, F5, F6, F7, F8, F9, T0, T1, T2, T3, T4) VALUES (NOW(), "
        append sql $phoneToCall ", "
        append sql $napr_vetr ", "
        append sql $skor_vetr ", "
        append sql $t_vlagn ", "
        append sql $vlagn ", "
        append sql $napr_pit ", "
        append sql $u_bat ", "
        append sql $u_zar ", "
        append sql $t_ds18s20 ", "
        append sql $t_iptv ", "
        append sql $v_iptv ", " 
        append sql $F0 ", "
        append sql $F1 ", "
        append sql $F2 ", "
        append sql $F3 ", "
        append sql $F4 ", "
        append sql $F5 ", "
        append sql $F6 ", "
        append sql $F7 ", "
        append sql $F8 ", "
        append sql $F9 ", "
        append sql $T0 ", "
        append sql $T1 ", "
        append sql $T2 ", "
        append sql $T3 ", "
        append sql $T4 ") "
        
        if {[catch {mysqlexec $mysql_handler $sql} tmpError]} {
			put_to_log "[clock format [clock seconds] -format %T] -- Ошибка $tmpError\nЗапрос: $sql"
        }
        
        mysqlclose $mysql_handler	                                                                                                            
    }
    
}

proc open_port {comport} {
	global flag
	global serial
	global port_speed
	global status
	
	set prefix "\\\\.\\"
	set serial_port [append prefix $comport]

	if { [catch {open $serial_port  {r+}} serial] } {
	# невозможно открыть порт
		put_to_log "[clock format [clock seconds] -format %T] -- Error: cannot open $comport. Program terminated."
		close $logfile
		after 2000
		exit
	} else {
	# порт открыт, работаем дальше		
		put_to_log "[clock format [clock seconds] -format %T] -- $comport is open"
	}
	fconfigure $serial -mode 9600,n,8,1 \
			-blocking 0 \
			-buffering full \
			-translation {binary binary}
	fileevent $serial readable serial_receiver
	
	#set status "Получить номер датчика"
}
#========================================================================================
#========================================================================================
proc put_to_log {message} {
	#set logfile [open monitoring_1.log a]
	regsub -all {\/} [clock format [clock seconds] -format %D] {_} result
	set logfile [open monitoring_${result}.log a]
	puts $logfile $message
	close $logfile
}
#========================================================================================
#========================================================================================
proc parse_and_save {incoming_data} {
#
#	Распарсить полученную посылку и отобразить данные
#	
	set caller_number ""
	global num_posts post_phone
	global db_host db_user db_password db_port
	global port_id
	set working_mode "DATA"
	
	#set logfile [open my.log a]
	
	#regsub -all {\/} [clock format [clock seconds] -format %D] {_} result
	#set logfile [open monitoring_${result}.log a]
	
	#put_to_log "[clock format [clock seconds] -format %T] -- $port_id -> Parsing in mode $working_mode"	
	
	switch $working_mode {
		"DATA"	{
					set data_list [split_string $incoming_data [add0D0A ""]]
					put_to_log "[clock format [clock seconds] -format %T] -- $data_list"
					for {set i 0} {$i <= [expr [llength $data_list] - 1]} {incr i} {
						set temp [lindex $data_list [expr $i]]
						if {[regexp {^[0-9]{11}:$} $temp]} {
							# номер телефона
							set caller_number [string range $temp 0 10]
						}
						if {[regexp {^[[:xdigit:]]{240}$} $temp]} {
							# данные
								
								set sensors_data0 [string range $temp 0 119]; # первая половина посылки
								set sensors_data1 [string range $temp 120 239]; # вторая половина посылки
								# извлечение данных из первой половины посылки
								set vectors [hex2int [extract_param "vectors" $temp "5sensors"]]
								# показания датчика 
								for {set sensor_number 0} {$sensor_number < 5} {incr sensor_number} {
									set F${sensor_number} 		[::decodedata::decode_force 		[extract_param "F${sensor_number}" $temp "5sensors"]]
									set F${sensor_number}max 	[::decodedata::decode_force 		[extract_param "F${sensor_number}max" $temp "5sensors"]]
									set F${sensor_number}min 	[::decodedata::decode_force 		[extract_param "F${sensor_number}min" $temp "5sensors"]]
									set F${sensor_number}srd 	[::decodedata::decode_force 		[extract_param "F${sensor_number}srd" $temp "5sensors"]]
									set T${sensor_number} 		[::decodedata::decode_temperature 	[extract_param "T${sensor_number}" $temp "5sensors"]]
								}

								set razryad [expr abs([::decodedata::IEEE2float [string range $sensors_data0 104 111]] / 3600.0)]
								# событие, вызвавшее передачу
								set cause [hex2int [string range $sensors_data0 116 117]]
								#
								# извлечение данных из второй половины посылки								
								# направление ветра
								set nWind [::decodedata::decode_nWind [string range $sensors_data1 76 79]]
								# скорость ветра
								set vWind [::decodedata::decode_vWind [string range $sensors_data1 80 83]]
								# напряжение питания контроллера
								set uPit [::decodedata::decode_U [string range $sensors_data1 84 85]]
								# температура датчика влажности
								#set tHumid [::decodedata::decode_tHumid [string range $sensors_data1 86 89]]
								set tHumid [format %.1f $T2]
								# влажность
								set humid [::decodedata::decode_Humid [string range $sensors_data1 90 93]]
								# внешняя температура
								set tOut [::decodedata::decode_temperature [string range $sensors_data1 94 97]]
								# напряжение зарядки
								set uZar [::decodedata::decode_U [string range $sensors_data1 98 99]]
								# напряжение батареи
								set uBat [::decodedata::decode_U [string range $sensors_data1 100 101]]
								# заряд батреи
								set zaryad [expr abs([::decodedata::IEEE2float [string range $sensors_data1 102 109]] / 3600.0)]
								#++++++++++++++++++++++++++++++++++++++++++++++++++++
								# отображение в соответствующих полях		
								if {[info exists caller_number]} {
									#set post [expr [lsearch -exact $post_phone $caller_number] + 1]
									for {set num_sensor 0} {$num_sensor <= 4} {incr num_sensor} {
										#set force_entry "\$F"
										#append force_entry $num_sensor
										#show_force $post $num_sensor [expr [set force_entry]]
										
										#set temperature_entry "\$T"
										#append temperature_entry $num_sensor
										#show_temperature $post $num_sensor [expr [set temperature_entry]]
									}
									
									#show_weather $post 0 $nWind
									#show_weather $post 1 $vWind
									#show_weather $post 2 $humid
									#show_weather $post 3 $tHumid
									#show_weather $post 4 $tOut
									
									#show_rec_parameters $post 0 $uPit
									#show_rec_parameters $post 1 $uBat
									#show_rec_parameters $post 2 $uZar
									#show_rec_parameters $post 3 $zaryad
									#show_rec_parameters $post 4 $razryad	
																
								#++++++++++++++++++++++++++++++++++++++++++++++++++++
								#++++++++++++++++++++++++++++++++++++++++++++++++++++

									set param_list [list $caller_number $F0 $F1 $F2 $F3 $F4 $T0 $T1 $T2 $T3 $T4 $nWind $vWind $uPit $tOut $humid $uBat $zaryad $razryad $vectors $cause $tHumid $uZar]
									put_to_db "MySQL" $param_list
								
								#++++++++++++++++++++++++++++++++++++++++++++++++++++
									#.log.log delete 0.0 end; update
									#.log.log insert end "[clock format [clock seconds] -format %T] -- Получены данные с номера $caller_number\n"; .log.log see end; update
									put_to_log "[clock format [clock seconds] -format %T] -- Получены данные с номера $caller_number, причина $cause"
									break
								}
						}
					}
				}
		"GPRS"	{}
	}
	#close $logfile
}
#========================================================================================
proc extract_param {param_name, pkg, pkg_type} {
	switch $pkg_type {
		"5sensors" {
			switch $param_name {
				"F0" 	{set part 0; set begin_index 20; set end_index 25}
				"F0max" {set part 0; set begin_index 26; set end_index 31}
				"F0min" {set part 0; set begin_index 32; set end_index 37}
				"F0srd" {set part 0; set begin_index 38; set end_index 43}
				"T0" 	{set part 0; set begin_index 44; set end_index 47}

				"F1" 	{set part 0; set begin_index 48; set end_index 53}
				"F1max" {set part 0; set begin_index 54; set end_index 59}
				"F1min" {set part 0; set begin_index 60; set end_index 65}
				"F1srd" {set part 0; set begin_index 66; set end_index 71}
				"T1" 	{set part 0; set begin_index 72; set end_index 75}

				"F2" 	{set part 0; set begin_index 76; set end_index 81}
				"F2max" {set part 0; set begin_index 82; set end_index 87}
				"F2min" {set part 0; set begin_index 88; set end_index 93}
				"F2srd" {set part 0; set begin_index 94; set end_index 99}
				"T2" 	{set part 0; set begin_index 100; set end_index 103}

				"F3" 	{set part 1; set begin_index 20; set end_index 25}
				"F3max" {set part 1; set begin_index 26; set end_index 31}
				"F3min" {set part 1; set begin_index 32; set end_index 37}
				"F3srd" {set part 1; set begin_index 38; set end_index 43}
				"T3" 	{set part 1; set begin_index 44; set end_index 47}

				"F4" 	{set part 1; set begin_index 48; set end_index 53}
				"F4max" {set part 1; set begin_index 54; set end_index 59}
				"F4min" {set part 1; set begin_index 60; set end_index 65}
				"F4srd" {set part 1; set begin_index 66; set end_index 71}
				"T4" 	{set part 1; set begin_index 72; set end_index 75}

				"vectors" 	{set part 0; set begin_index 12; set end_index 15}
				"razryad" 	{set part 0; set begin_index 104; set end_index 111}
				"cause" 	{set part 0; set begin_index 116; set end_index 117}

				"nWind" 	{set part 1; set begin_index 76; set end_index 79}
				"vWind" 	{set part 1; set begin_index 80; set end_index 83}				
				"uPit" 		{set part 1; set begin_index 84; set end_index 85}
				"tHumid" 	{set part 1; set begin_index 86; set end_index 89}
				"humid" 	{set part 1; set begin_index 90; set end_index 93}
				"tOut" 		{set part 1; set begin_index 94; set end_index 97}
				"uZar" 		{set part 1; set begin_index 98; set end_index 99}
				"uBat" 		{set part 1; set begin_index 100; set end_index 101}
				"zaryad" 	{set part 1; set begin_index 102; set end_index 109}

			}			
		}
		"10sensors" {
			switch $param_name {
				"F0"	{set part 0; set begin_index 22; set end_index 27}
				"F1"	{set part 0; set begin_index 32; set end_index 37}
				"F2"	{set part 0; set begin_index 42; set end_index 47}
				"F3"	{set part 0; set begin_index 52; set end_index 57}
				"F4"	{set part 0; set begin_index 62; set end_index 67}
				"F5"	{set part 0; set begin_index 72; set end_index 77}
				"F6"	{set part 0; set begin_index 82; set end_index 87}
				"F7"	{set part 0; set begin_index 92; set end_index 97}
				"F8"	{set part 1; set begin_index 22; set end_index 27}
				"F9"	{set part 1; set begin_index 32; set end_index 37}

				"T0"	{set part 0; set begin_index 28; set end_index 31}
				"T1"	{set part 0; set begin_index 38; set end_index 41}
				"T2"	{set part 0; set begin_index 48; set end_index 51}
				"T3"	{set part 0; set begin_index 58; set end_index 61}
				"T4"	{set part 0; set begin_index 68; set end_index 71}
				"T5"	{set part 0; set begin_index 78; set end_index 81}
				"T6"	{set part 0; set begin_index 88; set end_index 91}
				"T7"	{set part 0; set begin_index 98; set end_index 101}
				"T8"	{set part 1; set begin_index 28; set end_index 31}
				"T9"	{set part 1; set begin_index 38; set end_index 41}

				"vectors"	{set part 0; set begin_index 12; set end_index 15}
				"rarzyad"	{set part 0; set begin_index 104; set end_index 111}				
				"cause"		{set part 0; set begin_index 116; set end_index 117}
				"nWind"		{set part 1; set begin_index 76; set end_index 79}
				"vWind"		{set part 1; set begin_index 80; set end_index 83}
				"uPit"		{set part 1; set begin_index 84; set end_index 85}
				"tHumid"	{set part 1; set begin_index 86; set end_index 89}
				"humid"		{set part 1; set begin_index 90; set end_index 93}
				"tOut"		{set part 1; set begin_index 94; set end_index 97}
				"uZar"		{set part 1; set begin_index 98; set end_index 99}
				"uBat"		{set part 1; set begin_index 100; set end_index 101}
				"zaryad"	{set part 1; set begin_index 102; set end_index 109}
				"t_IPTV"	{set part 1; set begin_index 54; set end_index 61}
				"h_IPTV"	{set part 1; set begin_index 62; set end_index 69}
			}
		}
	}
#	set sensors_data0 [string range $pkg 0 119]
#	set sensors_data1 [string range $pkg 120 239]
#	set sensors_data${part} [string range $pkg [expr 120 * $part] [expr 120 * $part + 119]]
#	set extracted [string range [set sensors_data${part}] $begin_index $end_index]
	set extracted [string range [string range $pkg [expr 120 * $part] [expr 120 * ($part + 1) - 1]] $begin_index $end_index]

	return $extracted

}
#========================================================================================
proc p2c {in_data} {
	regsub -all {\.} $in_data {,} result	
	return $result
}
#========================================================================================
proc put_to_db {db_name param_list} {

	switch $db_name {
    	"MySQL"	{
	# сохранение в базе MySQL					
			set db_port {3306}
			set db_host {127.0.0.1}
			set db_user {frost}
			set db_password {frost}																	
		
			if [catch {mysqlconnect -host $db_host -port $db_port -user $db_user -password $db_password -db monitoringdata -encoding utf-8} mysql_handler] {
				put_to_log "[clock format [clock seconds] -format %T] -- Не могу соединиться с базой данных"
				break
			} else {
				mysqlexec $mysql_handler {SET NAMES 'utf8'}
				mysqlexec $mysql_handler {SET character_set_client='utf8'}
				mysqlexec $mysql_handler {SET character_set_connection='utf8'}
																					
				set sql [build_insert_query $param_list]
				
				put_to_log "[clock format [clock seconds] -format %T] -- $sql"
				if {[catch {mysqlexec $mysql_handler $sql} tmpError]} {
					put_to_log "[clock format [clock seconds] -format %T] -- Ошибка $tmpError\nЗапрос: $sql"
				}
				mysqlclose $mysql_handler
			}
		}

		"ACCESS" {

			set phoneNumber [lindex $param_list 0]


			set driver {Microsoft Access Driver (*.mdb)}
			set fileName "Главный.mdb"
			# Connect to the database.

			set connectString DRIVER=$driver
			append connectString \; DBQ=[file nativename $fileName]
			append connectString \; {FIL=MS Access}			
			if [catch {database db $connectString} tmp_error] {
				put_to_log "[clock format [expr [clock seconds] - 3600] -format %T] -- Не могу соединиться с базой данных: $tmp_error\n"
				break
			}

			set sql "SELECT Таблица FROM Посты WHERE Номер='$phoneNumber' ; "

			db statement stmt $sql
	    	set records [stmt run]
    		stmt drop
	
			if {[llength $records] == 1} {
				
			} else {
				put_to_log "[clock format [clock seconds] -format %T] -- Invalid phone number!"
			}

			set sql [build_insert_query $param_list]
				
			put_to_log "[clock format [clock seconds] -format %T] -- $sql"

			db statement storeIT $sql
			if {[catch {storeIT run $parsed_data} errores] == 1} {
		   		put_to_log "MS Access error:\n$errores"				
		 	} else {
    			put_to_log "OK, Record Stored" 
			}
        	db disconnect

			put_to_log "Data saved to $table_name\n"


		}

	}
}
#========================================================================================
proc build_insert_query {param_list} {
	set sql "INSERT INTO monitoringtable (dateOfMeasurement, phoneNumber, F0, F1, F2, F3, F4, T0, T1, T2, T3, T4, nWind, vWind, uPit, tOkr, vlagn, uBat, zaryad, razryad, vectors, cause, tHumid, uZar) VALUES (NOW(), "
    for {set i 0} {$i < [expr [llength $param_list] - 1]} {incr i}
	{
		append sql [lindex $param_list $i] ", "
	}   	
	append sql [lindex $param_list [expr [llength $param_list] - 1]] ") "
	return $sql
}
#========================================================================================
proc add0D0A {str} {
#
#	Добавить к исходной строке символы 0x0D 0x0A
#
	set new_str $str
	append new_str [format %c 13] 	
	append new_str [format %c 10] 	
	return $new_str
}
#========================================================================================
#========================================================================================
proc hex2int {in_str} {
#
# преобразование шестнадцатиричного числа в целое
#
	set hex ""
	if {[scan $in_str "%x" hex]} {
		return $hex
	} else {
		return 0
	}
}
#========================================================================================
#========================================================================================
proc split_string {in_string substring} {
#
#	Разбивка строки по подстроке
#
	set splitchar "_"
	set list [split [string map [list $substring $splitchar] $in_string] $splitchar]
	return $list
}
#========================================================================================
#========================================================================================
proc decode_force {in_str} {
#
# расшифровать усилие
#
	set force ""
	if {[string equal $in_str "900000"]} {return -1000}
	if {[string equal $in_str "800000"]} {return -500}
	set tmp_force [format %.0f [expr 0.1 * [expr {[scan ${in_str}ff %x] >> 8}]]]
	if {$tmp_force < 0} {return 0}
	return $tmp_force
}
#========================================================================================
#========================================================================================
proc show_force {num_post num_sensor force} {
#
# показать усилие
#
	global force${num_sensor}_$num_post
	
	switch $force {
		-1000	{set force${num_sensor}_$num_post "Не подключен"}
		-500	{set force${num_sensor}_$num_post "Не отвечает"}
		default	{set force${num_sensor}_$num_post $force}
	}
	update		
}
#========================================================================================
#========================================================================================
proc decode_temperature {in_str} {		
#
# расшифровать температуру
#
	set temperature ""
	if {[string equal $in_str "9000"]} {return -1000}
	if {[string equal $in_str "8000"]} {return -500}
	return [format %.1f [expr 0.5 * [expr {[scan ${in_str}ffff %x] >> 16}]]]
}
#========================================================================================
#========================================================================================
proc show_temperature {num_post num_sensor temperature} {
#
# показать температуру
#
	global temperature${num_sensor}_$num_post
	
	switch $temperature {
		-1000	{set temperature${num_sensor}_$num_post "Не подключен"}
		-500	{set temperature${num_sensor}_$num_post "Не отвечает"}
		default	{set temperature${num_sensor}_$num_post $temperature}
	}
	
	update		
}
#========================================================================================
#========================================================================================
proc show_weather {num_post num_sensor weather} {
#
# показать параметры погоды
#
	global weather${num_sensor}_$num_post
	
	if {$weather == -500.0} {set weather${num_sensor}_$num_post "Не подключен"; update; return}
	set weather${num_sensor}_$num_post $weather; update		
}
#========================================================================================
#========================================================================================
proc show_rec_parameters {num_post num_sensor rec_parameters} {
#
# показать параметры приемника
#
	global rec_parameters${num_sensor}_$num_post
	
	set rec_parameters${num_sensor}_$num_post [format %.1f $rec_parameters]; update		
}
#========================================================================================
#========================================================================================
proc decode_U {in_str} {
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
proc decode_nWind {in_str} {
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
proc decode_tHumid {in_str} {
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
proc decode_Humid {in_str} {
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
proc decode_vWind {in_str} {
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
#========================================================================================
proc IEEE2float {inputString} {
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
			return $float
		}
	} else {
		return 0
	}
}
#========================================================================================

global port_id
set comport [lindex $argv 0]
set port_id $comport
open_port $comport	

global status

global phoneToCall
global postList
global callEnabled
global writeEnabled

global timeshift
set timeshift 3600

set postList {}
set callEnabled 1
set writeEnabled 0

trace variable status w on_status_changed
set status "Проверка связи"
#set status "Получение списка номеров из базы"
vwait forever