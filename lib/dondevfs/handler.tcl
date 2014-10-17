# Download ON DEmand VFS
#
# VFS handler code
# Provides fsapi for tclvfs 
#
# Licensed under BSD license

namespace eval dondevfs {}
namespace eval dondevfs::handle {}

set dondevfs::idx 0

proc dondevfs::_handler {var cmd root relative actualpath args} {
    upvar #0 $var v
    #if {$v(debug)} {
    #    puts "Command $cmd $root $relative $actualpath [list $args]"
    #}
    return [eval [concat [list ::dondevfs::handle::$cmd $var $root $relative $actualpath] $args]]
}

proc dondevfs::handle::_call {cache var root method args} {
    upvar #0 $var v
    if {$v(cache) && $cache} {
        set k $method-[join $args -]
        if {[info exists v(cache-$k)]} {
            set rc $v(cache-$k)
        }
    }
    if {![info exists rc]} {
	if {$v(passvar)} {
	    set code {uplevel #0 [concat $v($method) [list $var] $args]}
	} else {
	    set code {uplevel #0 [concat $v($method) $args]}
	}
        if {$v(novfs)} {
            set code [list ::dondevfs::util::disableVfs [list $root] $code]
        }
        if {[catch $code err]} {
            set ei $::errorInfo
            set ec $::errorCode
            if {$v(debug)} {
                puts "Command $method error: $err"
            }
            set rc [list 1 $err $ei $ec]
        }  else  {
            set rc [list 0 $err]
        }
        if {$v(cache) && $cache} {
            set v(cache-$k) $rc
        }
    }
    if {[lindex $rc 0]} {
        error [lindex $rc 1] [lindex $rc 2] [lindex $rc 3]
    }  else  {
        return [lindex $rc 1]
    }
}

proc dondevfs::handle::_stat {var root name} {
    # TODO: some defaults
    array set s {type file ino 0 atime 0 ctime 0 mtime 0 nlink 1 size 0 csize 0 uid 0}
    if {[catch {
        array set s [_call 1 $var $root s $name]
    } err]} {
        vfs::filesystem posixerror $::vfs::posix(ENOENT)
    }
    if {$s(atime) == 0} {set s(atime) $s(mtime)}
    if {$s(ctime) == 0} {set s(ctime) $s(mtime)}
    return [array get s]
}

proc dondevfs::handle::_glob {var root name pattern} {
    upvar #0 $var v
    set rc {}
    set g {}
    if {[catch {
        set g [_call 1 $var $root l $name]
    } err]} {
        return {}
    }
    foreach g $g {
        if {[string match $pattern $g]} {
            lappend rc $g
        }
    }
    return $rc
}

proc dondevfs::handle::access {var root relative actualpath mode} {
    if {$mode & 2} {
        vfs::filesystem posixerror $::vfs::posix(EROFS)
    }
    _stat $var $root $relative
}

proc dondevfs::handle::createdirectory {var root relative actualpath} {
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc dondevfs::handle::deletefile {var root relative actualpath} {
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc dondevfs::handle::fileattributes {var root relative actualpath args} {
    switch -- [llength $a] {
        0 {
            # list strings
            return [::vfs::listAttributes]
        }
        1 {
            # get value
            set index [lindex $a 0]
            return [::vfs::attributesGet $root $relative $index]

        }
        2 {
            # set value
            incr fs(changeCount)
            if {0} {
                # handle read-only
                vfs::filesystem posixerror $::cookfs::posix(EROFS)
            }
            set index [lindex $a 0]
            set val [lindex $a 1]
            return [::vfs::attributesSet $root $relative $index $val]
        }
    }
}

proc dondevfs::handle::matchindirectory {var root relative actualpath pattern type} {
    set result {}
    if {$pattern == {}} {
        if {[catch {access $var $root $relative $actualpath 0}]} {
            return {}
        }
        set res [list $actualpath]
        set actualpath ""
    } else {
        set res [_glob $var $root $relative $pattern]
    }
    foreach p [::vfs::matchCorrectTypes $type $res $actualpath] {
        lappend result [file join $actualpath $p]
    }
    return $result
}

proc dondevfs::handle::open {var root relative actualpath mode permissions} {
    upvar #0 $var v
    if {($mode == {}) || ($mode == "r")} {
        if {[catch {
            set fh [_call 0 $var $root o $relative]
        } err]} {
            vfs::filesystem posixerror $::vfs::posix(ENOENT)
        }
        # TODO: handle close - i.e. cleanup?
        return [list $fh]
    }  else  {
        vfs::filesystem posixerror $::vfs::posix(EROFS)
    }
}

proc dondevfs::handle::removedirectory {var root relative actualpath} {
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}

proc dondevfs::handle::stat {var root relative actualpath} {
    return [_stat $var $root $relative]
}

proc dondevfs::handle::utime {var root relative actualpath args} {
    vfs::filesystem posixerror $::vfs::posix(EROFS)
}


package provide dondevfs::handler 1.0

