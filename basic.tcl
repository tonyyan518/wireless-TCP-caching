#this is a basic implementation of a cache at the base station
#we will set up 3 nodes: FH, BS, and MH
#packets will be sent from FH to MH via BS
#TCP will be used


# ======================================================================
# Define options
# ======================================================================
set opt(chan)           Channel/WirelessChannel    ;# channel type
set opt(prop)           Propagation/TwoRayGround   ;# radio-propagation model
set opt(netif)          Phy/WirelessPhy            ;# network interface type
set opt(mac)            Mac/802_11                 ;# MAC type
set opt(ifq)            Queue/DropTail/PriQueue    ;# interface queue type
set opt(ll)             LL                         ;# link layer type
set opt(ant)            Antenna/OmniAntenna        ;# antenna model
set opt(ifqlen)         50                         ;# max packet in ifq
set opt(nn)             1                          ;# number of mobilenodes
set opt(adhocRouting)   DSDV                       ;# routing protocol

set opt(cp)             ""                         ;# connection pattern file
set opt(sc)     "../test"    ;# node movement file. 

set opt(x)      50                            ;# x coordinate of topology
set opt(y)      70                            ;# y coordinate of topology
set opt(seed)   0.0                            ;# seed for random number gen.
set opt(stop)   250                            ;# time to stop simulation

set opt(ftp1-start)      100.0
set opt(ftp2-start)      170.0

set num_wired_nodes      1
set num_bs_nodes         1

# ============================================================================
# check for boundary parameters and random seed
if { $opt(x) == 0 || $opt(y) == 0 } {
	puts "No X-Y boundary values given for wireless topology\n"
}
if {$opt(seed) > 0} {
	puts "Seeding Random number generator with $opt(seed)\n"
	ns-random $opt(seed)
}

# create simulator instance
set ns_   [new Simulator]



# set up for hierarchical routing
$ns_ node-config -addressType hierarchical
AddrParams set domain_num_ 2           ;# number of domains
lappend cluster_num 1 1                ;# number of clusters in each domain
AddrParams set cluster_num_ $cluster_num
lappend eilastlevel  1 2              ;# number of nodes in each cluster 
AddrParams set nodes_num_ $eilastlevel ;# of each domain

set tracefd  [open wireless2-out.tr w]
set namtrace [open wireless2-out.nam w]
$ns_ trace-all $tracefd
$ns_ namtrace-all-wireless $namtrace $opt(x) $opt(y)

# Create topography object
set topo   [new Topography]

# define topology
$topo load_flatgrid $opt(x) $opt(y)

# create God
create-god [expr $opt(nn) + $num_bs_nodes]

#create wired nodes
set temp {0.0.0 }        ;# hierarchical addresses for wired domain
for {set i 0} {$i < $num_wired_nodes} {incr i} {
    set W($i) [$ns_ node [lindex $temp $i]] 
}

# configure for base-station node
$ns_ node-config -adhocRouting $opt(adhocRouting) \
                 -llType $opt(ll) \
                 -macType $opt(mac) \
                 -ifqType $opt(ifq) \
                 -ifqLen $opt(ifqlen) \
                 -antType $opt(ant) \
                 -propType $opt(prop) \
                 -phyType $opt(netif) \
                 -channelType $opt(chan) \
		 -topoInstance $topo \
                 -wiredRouting ON \
		 -agentTrace ON \
                 -routerTrace OFF \
                 -macTrace OFF 

#create base-station node
set temp {1.0.0 1.0.1 }   ;# hier address to be used for wireless
                                     ;# domain
set BS(0) [$ns_ node [lindex $temp 0]]
$BS(0) random-motion 0               ;# disable random motion

#provide some co-ord (fixed) to base station node
$BS(0) set X_ 50.0
$BS(0) set Y_ 40.0
$BS(0) set Z_ 0.0

# create mobilenodes in the same domain as BS(0)  
# note the position and movement of mobilenodes is as defined
# in $opt(sc)

#configure for mobilenodes
$ns_ node-config -wiredRouting OFF

  for {set j 0} {$j < $opt(nn)} {incr j} {
    set node_($j) [ $ns_ node [lindex $temp \
	    [expr $j+1]] ]
    $node_($j) base-station [AddrParams addr2id \
	    [$BS(0) node-addr]]
}

#create links between wired and BS nodes

#$ns_ duplex-link $W(0) $W(1) 5Mb 2ms DropTail
$ns_ duplex-link $W(0) $BS(0) 0.5Mb 100ms DropTail

#$ns_ duplex-link-op $W(0) $W(1) orient down
$ns_ duplex-link-op $W(0) $BS(0) orient left-down


# setup TCP connections
set tcp1 [new Agent/TCP]
$tcp1 set class_ 2
set sink1 [new Agent/TCPSink]
$ns_ attach-agent  $W(0) $tcp1
$ns_ attach-agent $node_(0)  $sink1
$ns_ connect $tcp1 $sink1

#create a queue
#$ns_ duplex-link-op  $BS(0) $node_(0) queuePos 0.5

set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ns_ at $opt(ftp1-start) "$ftp1 start"






# Define initial node position in nam

for {set i 0} {$i < $opt(nn)} {incr i} {

    # 20 defines the node size in nam, must adjust it according to your
    # scenario
    # The function must be called after mobility model is defined

    $ns_ initial_node_pos $node_($i) 20
}     

# Tell all nodes when the simulation ends
for {set i } {$i < $opt(nn) } {incr i} {
    $ns_ at $opt(stop).0 "$node_($i) reset";
}
$ns_ at $opt(stop).0 "$BS(0) reset";

$ns_ at $opt(stop).0002 "puts \"NS EXITING...\" ; $ns_ halt"
$ns_ at $opt(stop).0001 "stop"
proc stop {} {
    global ns_ tracefd namtrace
#    $ns_ flush-trace
    close $tracefd
    close $namtrace
}

# informative headers for CMUTracefile
puts $tracefd "M 0.0 nn $opt(nn) x $opt(x) y $opt(y) rp \
	$opt(adhocRouting)"
#puts $tracefd "M 0.0 sc $opt(sc) cp $opt(cp) seed $opt(seed)"
puts $tracefd "M 0.0 prop $opt(prop) ant $opt(ant)"

puts "Starting Simulation..."
$ns_ run

