# Creating an object Simulator
set ns [new Simulator]

# Opening for record out.nam for nam-visualisation
set nf [open out.nam w]

# All the results will be recorded in variable nf
$ns namtrace-all $nf

# Opening for record a tracin-file out.tr for registration all of the results
set f [open out.tr w]

# All the registred results will be recorded in variable f
$ns trace-all $f

# Two nodes R1 and R2
set r1 [$ns node]
set r2 [$ns node]

# Parameters for TCP
Agent/TCP set window_ 32
Agent/TCP set packetSize_ 500

# Connecting between the nodes and queue size
$ns simplex-link $r1 $r2 20Mb 15ms RED
$ns simplex-link $r2 $r1 15Mb 20ms DropTail
$ns queue-limit $r1 $r2 300

# N=20
set N 20

# Adding agents and apps and FTP over TCP Reno
for {set i 0} {$i < $N} {incr i} {
	set n1($i) [$ns node]
	$ns duplex-link $n1($i) $r1 100Mb 20ms DropTail
	set n2($i) [$ns node]
	$ns duplex-link $n2($i) $r2 100Mb 20ms DropTail

	set tcp($i) [$ns create-connection TCP/Reno $n1($i) TCPSink $n2($i) $i]
	set ftp($i) [$tcp($i) attach-source FTP]
}

# Monitoring window size TCP
set windowVsTimeFirst [open windowVsTimeRenoFirst w]
puts $windowVsTimeFirst "0.Color: Black"

set windowVsTimeAll [open windowVsTimeRenoAll w]
puts $windowVsTimeAll "0.Color: Black"

set qmon [$ns monitor-queue $r1 $r2 [open qm.out w] 0.1]; 
[$ns link $r1 $r2] queue-sample-timeout;

# Monitoring queue
set redq [[$ns link $r1 $r2] queue]
$redq set thresh_ 75
$redq set maxthresh_ 150
$redq set q_weight_ 0.002
$redq set linterm_ 10

set tchan_ [open all.q w]
$redq trace curq_
$redq trace ave_
$redq attach $tchan_

# Procedure finish
proc finish {} {
	global tchan_
	# Connecting code AWK
	set awkCode {
	{
		if ($1 == "Q" && NF>2) {
			print $2, $3 >> "temp.q";
			set end $2
		}
		else if ($1 == "a" && NF>2)
		print $2, $3 >> "temp.a";
	}
}

set f [open temp.q w]
puts $f "0.Color: black"
close $f

set f [open temp.a w]
puts $f "0.Color: black"
close $f

# If files are already existing, we're deleting them and creating new
if { [info exists tchan_] } {
	close $tchan_
}

exec rm -f temp.q temp.a
exec touch temp.q temp.a

# Execution of code AWK
exec awk $awkCode all.q

# Starting Xgraph with graphics of the windows TCP and queues
exec xgraph -bb -tk -x t(s) -y CWND(pkt) -t "TCPRenoCWNDOn1stLink" windowVsTimeRenoFirst -bg white -fg black &
exec xgraph -bb -tk -x t(s) -y CWND(pkt) -t "TCPRenoCWNDOnAllSources" windowVsTimeRenoAll -bg white -fg black &
exec xgraph -bb -tk -x t(s) -y "Queue Length (pkt)" -t "ChangeOfSizeOfQueueOnLink(R1-R2)" temp.q -bg white &
exec xgraph -bb -tk -x t(s) -y "Queue Avg Length (pkt)" -t "ChangeOfSizeOfAvgQueueOnLink(R1-R2)" temp.a -bg white &
exec nam out.nam &
exit 0
}

# Formation of file with TCP window size data
proc plotWindow {tcpSource file} {
	global ns
	set time 0.01
	set now [$ns now]
	set cwnd [$tcpSource set cwnd_]
	puts $file "$now $cwnd"
	$ns at [expr $now+$time] "plotWindow $tcpSource $file"
}

# Adding at-actions
for {set i 0} {$i < $N} {incr i} {
	$ns at 0.0 "$ftp($i) start"
	$ns at 0.0 "plotWindow $tcp($i) $windowVsTimeAll"
}
$ns at 0.0 "plotWindow $tcp(1) $windowVsTimeFirst"
$ns at 20.0 "finish"

# Starting model
$ns run
