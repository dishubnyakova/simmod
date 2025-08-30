set ns [new Simulator]
set nf [open out.nam w]
$ns namtrace-all $nf
set f [open out.tr w]
$ns trace-all $f

# Узлы сети:
set N 5
for {set i 1} {$i < $N} {incr i} {
    set node_(s$i) [$ns node]
}
set node_(r1) [$ns node]
set node_(r2) [$ns node]

# Соединения:
$ns duplex-link $node_(s1) $node_(r1) 10Mb 2ms DropTail
$ns duplex-link $node_(s2) $node_(r1) 10Mb 3ms DropTail
$ns duplex-link $node_(r1) $node_(r2) 1.5Mb 20ms RED
$ns queue-limit $node_(r1) $node_(r2) 25
$ns queue-limit $node_(r2) $node_(r1) 25
$ns duplex-link $node_(s3) $node_(r2) 10Mb 4ms DropTail
$ns duplex-link $node_(s4) $node_(r2) 10Mb 5ms DropTail

# Агенты и приложения:
set tcp1 [$ns create-connection TCP/Vegas $node_(s1) TCPSink $node_(s3) 0]
$tcp1 set window_ 15
set tcp2 [$ns create-connection TCP/Reno $node_(s2) TCPSink $node_(s3) 1]
$tcp2 set window_ 15
set ftp1 [$tcp1 attach-app FTP]
set ftp2 [$tcp2 attach-app FTP]

# Мониторинг размера окна TCP:
set windowVsTime [open WindowVsTimeVegas w]
puts $windowVsTime "0.Color: Purple"
set qmon [$ns monitor-queue $node_(r1) $node_(r2) [open qm.out w] 0.1]
[$ns link $node_(r1) $node_(r2)] queue-sample-timeout

# Мониторинг очереди:
set redq [[$ns link $node_(r1) $node_(r2)] queue]
set tchan_ [open all.q w]
$redq trace curq_
$redq trace ave_
$redq attach $tchan_

# Добавление at-событий:
$ns at 0.0 "$ftp1 start"
$ns at 1.1 "plotWindow $tcp1 $windowVsTime"
$ns at 3.0 "$ftp2 start"
$ns at 10.0 "finish"

# Формирование файла с данными о размере окна TCP:
proc plotWindow {tcpSource file} {
    global ns
    set time 0.01
    set now [$ns now]
    set cwnd [$tcpSource set cwnd_]
    puts $file "$now $cwnd"
    $ns at [expr $now+$time] "plotWindow $tcpSource $file"
}

# Процедура finish:
proc finish {} {
    global ns nf f tchan_ windowVsTime
    
    $ns flush-trace
    close $f
    close $nf
    close $windowVsTime
    
    if { [info exists tchan_] } {
        close $tchan_
    }
    
    # подключение кода AWK:
    set awkCode {
        {
            if ($1 == "Q" && NF>2) {
                print $2, $3 >> "temp.q";
            }
            else if ($1 == "a" && NF>2) {
                print $2, $3 >> "temp.a";
            }
        }
    }
    
    set f [open temp.queue w]
    puts $f "TitleText: RED"
    puts $f "Device: Postscript"
	puts $f "0.Color: Pink"
	puts $f "1.Color: Grey"
    
    exec rm -f temp.q temp.a
    exec touch temp.a temp.q
    
    # выполнение кода AWK
    catch {exec awk $awkCode all.q}
    
    puts $f "\"current_queue"
    catch {exec cat temp.q >@ $f}
    puts $f \n
    puts $f "\"average_queue"
    catch {exec cat temp.a >@ $f}
    close $f

    # Запуск xgraph с графиками окна TCP и очереди:
    exec xgraph -bb -tk -x TIME -t "TCPVegasCWND" WindowVsTimeVegas -bg white &
    exec xgraph -bb -tk -x TIME -y QUEUE temp.queue -bg white &
    # Запуск nam
    exec nam out.nam &
    
    exit 0
}

$ns run
