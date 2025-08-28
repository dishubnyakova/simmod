set ns [new Simulator]
$ns rtproto DV
set nf [open out.nam w]
$ns namtrace-all $nf
set f [open out.tr w]
$ns trace-all $f

set N 5
for {set i 0} {$i < $N} {incr i} {
	set n($i) [$ns node]
}
for {set i 0} {$i < $N} {incr i} {
	$ns duplex-link $n($i) $n([expr ($i+1)%$N]) 1Mb 10ms DropTail
}
set n5 [$ns node]
$ns duplex-link $n(1) $n5 1Mb 10ms DropTail
# tcp n(0)
set tcp1 [new Agent/TCP/Newreno]
$ns attach-agent $n(0) $tcp1 
# ftp присоединение к агенту tcp1
set ftp [new Application/FTP]
$ftp attach-agent $tcp1
# создание агента-получателя для tcp1
set sink1 [new Agent/TCPSink/DelAck] 
$ns attach-agent $n5 $sink1
$ns connect $tcp1 $sink1

proc finish {} {
        global ns f nf
        $ns flush-trace
        close $f
        close $nf
        exec nam out.nam &
        exit 0
}

$ns at 0.5 "$ftp start"
$ns rtmodel-at 1.0 down $n(0) $n(1)
$ns rtmodel-at 2.0 up $n(0) $n(1)
$ns at 4.5 "$ftp stop" 
$ns at 5.0 "finish"

$ns run
