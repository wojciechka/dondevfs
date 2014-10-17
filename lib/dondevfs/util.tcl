# Download ON DEmand VFS
#
# utility code
#
# Licensed under BSD license

namespace eval dondevfs::util {}

proc dondevfs::util::disableAllVfs {code} {
    return [disableVfs [lsort -decreasing [vfs::filesystem info]] $code 2]
}

proc dondevfs::util::disableVfs {paths code {level 1}} {
    set remount {}
    if {[llength $paths] == 0} {
        # ensure filesystems are unmounted in children first
        set paths 
    }
    foreach path $paths {
        if {![catch {vfs::filesystem info $path} info]} {
            if {![catch {vfs::filesystem unmount $path}]} {
                lappend remount $path $info
            }
        }
    }
    set c [catch {
        uplevel $level $code
    } i]
    if {$c} {
        set ei $::errorInfo
        set ec $::errorCode
    }
    
    foreach {path info} $remount {
        if {[catch {vfs::filesystem mount $path $info}]} {
        }
    }
    
    if {$c == 1} {
        error $i $ei $ec
    } else {
        # return appropriate code
        return -code [lindex {ok - return break continue} $c] $i
    }
}

package provide dondevfs::util 1.0
