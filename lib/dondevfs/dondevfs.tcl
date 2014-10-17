# Download ON DEmand VFS
#
# Main file
# handles mounting of dondevfs filesystems
#
# Licensed under BSD license

package require dondevfs::util
package require dondevfs::handler
package require vfs

namespace eval dondevfs {}

set dondevfs::idx 0

proc dondevfs::mount {path args} {
    array set o {
        l {}
        s {}
        o {}
	umount  {}
        volume  0
        debug   0
        cache   0
        novfs   0
        passvar 0
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
            -c - -cache {
                set o(cache) 1
                set args [lrange $args 1 end]
            }
            -no - -novfs - -disablevfs {
                set o(novfs) 1
                set args [lrange $args 1 end]
            }
	    -passvar - -passvariable {
		set o(passvar) 1
                set args [lrange $args 1 end]
	    }
	    -umount - -unmount - -umountcommand - -unmountcommand {
		set o(umount) [lindex $args 1]
                set args [lrange $args 2 end]
	    }
            -l - -list - -listcommand -
            -s - -stat - -statcommand -
            -o - -open - -opencommand {
                set o([string index [lindex $args 0] 1]) [lindex $args 1]
                set args [lrange $args 2 end]
            }
            default {
                set validUsage 0
                break
            }
        }
    }
    if {($o(l) == {}) || ($o(s) == {}) || ($o(o) == {})} {
        set validUsage 0
    }
    if {!$validUsage} {
        set msg "Usage: dondevfs::mount path ?-listcommand cmd? ?-statcommand cmd? ?-opencommand cmd? ?-unmountcommand cmd? ?-passvar? ?-debug? ?-cache? ?-volume? ?-withoutvfs|-novfs?"
        error $msg $msg
    }
    set var ::dondevfs::vfs[incr ::dondevfs::idx]
    upvar #0 $var v
    array set v [array get o]
    set path [vfs::filesystem fullynormalize $path]
    set v(path) $path

    if {$o(volume)} {
        ::vfs::filesystem mount -volume $path [list ::dondevfs::_handler $var]
    }  else  {
        ::vfs::filesystem mount $path [list ::dondevfs::_handler $var]
    }
    ::vfs::RegisterMount $path [list ::dondevfs::_unmount $var]
    
    return $var
}

proc dondevfs::_unmount {var path} {
    upvar #0 $var v
    vfs::filesystem unmount $path
    unset $var
}

package provide dondevfs 1.0
