# Download ON DEmand VFS
#
# s3cmd handler
# Allows mounting S3 shares in Tcl leveraging s3cmd
# for accessing the S3 resources
#
# Licensed under BSD license

package require dondevfs

namespace eval dondevfs::s3cmd {}

proc dondevfs::s3cmd::mount {path args} {
    array set o {
        volume  0
        debug   0
	s3path  {}
	s3cmd   {s3cmd}
    }
    set validUsage 1
    while {[llength $args] > 0} {
        switch -- [lindex $args 0] {
            -v - -vol - -volume {
                set o(volume) 1
                set args [lrange $args 1 end]
            }
            -d - -dbg - -debug {
                set o(debug) 1
                set args [lrange $args 1 end]
            }
	    -ac - -auto - -autocommand {
		# workaround for scripts that change PATH and may interfere
		# with s3cmd invocation
		set _s3cmd [lindex [auto_execok s3cmd] end]
		if {[file exists $_s3cmd]} {
		    set fh [open $_s3cmd r]
		    gets $fh shebang
		    close $fh
		    set s3python [auto_execok python]
		    if {[regexp {^#!(.*)$} $shebang - s3python]} {
			set s3python [string trim $s3python]
			regsub {/usr/bin/env\s+} $s3python {} s3python
			set s3python [auto_execok [lindex $s3python 0]]
		    }
		    set o(s3cmd) [concat $s3python $_s3cmd]
		}
                set args [lrange $args 1 end]
	    }
	    -s3 - -s3path - -remote {
                set o(s3path) [lindex $args 1]
                set args [lrange $args 2 end]
	    }
	    -cfg - -s3cfg {
                set o(s3cfg) [lindex $args 1]
                set args [lrange $args 2 end]
	    }
            default {
                set validUsage 0
                break
            }
        }
    }
    if {($o(s3path) == {})} {
        set validUsage 0
    }
    if {!$validUsage} {
        set msg "Usage: dondevfs::s3cmd::mount path -s3path remote ?-s3cfg path? ?-debug? ?-volume?"
        error $msg $msg
    }
    set path [vfs::filesystem fullynormalize $path]
    set cmd [list ::dondevfs::mount $path -passvar -novfs]
    lappend cmd -listcommand dondevfs::s3cmd::globcmd
    lappend cmd -statcommand dondevfs::s3cmd::statcmd
    lappend cmd -opencommand dondevfs::s3cmd::opencmd
    lappend cmd -unmountcommand dondevfs::s3cmd::_unmount
    if {$o(volume)} {
	lappend cmd -volume
    }
    if {$o(debug)} {
	lappend cmd -debug
    }
    set var [uplevel #0 $cmd]
    upvar #0 $var v
    set v(s3cmd-s3path) [string trimright $o(s3path) /]
    set v(s3cmd-s3cfg) $o(s3cfg)
    set v(s3cmd-s3cmd) $o(s3cmd)
    if {![file exists $v(s3cmd-s3cfg)]} {
	set v(s3cmd-s3cfg) [file normalize ~/.s3cfg]
    }
    if {![file exists $v(s3cmd-s3cfg)]} {
	catch {vfs::unmount $path}
	error "Unable to find .s3cfg file"
    }
    if {[catch {
	_init $var
    } err]} {
	catch {vfs::unmount $path}
	error "Unable to query s3cmd file listing: $err"
    }
}

proc dondevfs::s3cmd::_unmount {var} {
    unset ${var}.g
    unset ${var}.f
}

proc dondevfs::s3cmd::_init {var} {
    upvar #0 $var v ${var}.g g ${var}.f f
    set output [_s3cmd $var 600 ls -r "$v(s3cmd-s3path)/"]
    set idx [expr {[string length $v(s3cmd-s3path)] + 1}]
    foreach line [split [string trim $output] \n] {
        if {[regexp {^(.*?)(s3://.*)$} [string trim $line] - info p]} {
            set p [string range $p $idx end]
            set mt [clock scan [join [lrange $info 0 end-1]]]
            if {[regexp {^(.*)/$} p - p]} {
                set f($p) [list type directory size 4096 mtime $mt]
            } else {
                set f($p) [list type file size [lindex $info end] mtime $mt]
            }
            set dp {}
            foreach d [lrange [split $p /] 0 end-1] {
                lappend dp $d
                set da([join $dp /]) 1
            }
        }
    }
    foreach d [array names da] {
        if {$d != {}} {
            if {![info exists f($d)]} {
                set f($d) [list type directory size 4096 mtime 0]
            }
        }
    }
    foreach d [array names f] {
        set d [split $d /]
        set dp [join [lrange $d 0 end-1] /]
        lappend g($dp) [lindex $d end]
    }
    foreach {k kv} [array get g] {
        set kv [lsort -unique $kv]
        while {([llength $kv] > 0) && (([lindex $kv 0] == {}) || ([lindex $kv 0] == {.}) || ([lindex $kv 0] == {..}))} {
            set kv [lrange $kv 1 end]
        }
        set g($k) $kv
    }
}

proc dondevfs::s3cmd::_s3cmd {var timeout args} {
    upvar #0 $var v
    set rc {}
    set ok 0
    foreach try {1 2 3} {
	set rc {}
	set ctimeout [expr {[clock seconds] + $timeout}]
	if {[catch {
	    set fh [open "|[concat $v(s3cmd-s3cmd) [list -c $v(s3cmd-s3cfg)] $args [list </dev/null 2>@1]]" r]
	    fconfigure $fh -blocking 0 -buffering none
	} err]} {
	    continue
	}
	set ok 0
	# the read has to be done as sync operation not to mess with Tcl event loop
	while {[clock seconds] < $ctimeout} {
	    after 500
	    catch {set eof 1 ; append rc [read $fh] ; set eof [eof $fh]}
	    if {$eof} {
		fconfigure $fh -blocking 1 -buffering none
		if {![catch {close $fh} err]} {
		    set ok 1
		}
		break
	    }
	}
	if {$ok} {
	    break
	} else {
	    after ${try}0000
	    continue
	}
    }
    if {!$ok} {
	error "Unable to run s3cmd: $err"
    }
    return $rc
}

proc dondevfs::s3cmd::globcmd {var path} {
    upvar #0 $var v ${var}.g g ${var}.f f
    if {[info exists g($path)]} {
        return $g($path)
    } else {
        return {}
    }
}

proc dondevfs::s3cmd::statcmd {var path} {
    upvar #0 $var v ${var}.g g ${var}.f f
    if {[info exists f($path)]} {
        return $f($path)
    } else {
        error "No such file $path"
    }
}

proc dondevfs::s3cmd::opencmd {var path} {
    upvar #0 $var v
    array set s [statcmd $var $path]
    set download 1
    set vpath [file join $v(path) $path]
    if {[file exists $vpath]} {
	set download 0
	file stat $vpath ls
	foreach t {type size mtime} {
	    if {$ls($t) != $s($t)} {
		set download 1
	    }
	}
    }
    if {$download} {
        download $var $path $vpath
	# set mtime to ensure it is valid next time
	file mtime $vpath $s(mtime)
    }
    return [open $vpath]
}


proc dondevfs::s3cmd::download {var path vpath} {
    upvar #0 $var v
    set ok 0
    array set s [statcmd $var $path]
    # assume at least 100kB/s transfer and 60s gap
    set timeout [expr {60 + int($s(size) / 100000)}]
    file mkdir [file dirname $vpath]
    _s3cmd $var $timeout get -f $v(s3cmd-s3path)/$path $vpath
}

package provide dondevfs::s3cmd 1.0

