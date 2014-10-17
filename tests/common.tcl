package require dondevfs

proc _dondevfs_glob_dir {prefix path} {
    dondevfs::util::disableAllVfs {
        set p [file join $prefix $path]
        glob -tails -directory $p *
    }
}

proc _dondevfs_stat_dir {prefix path} {
    dondevfs::util::disableAllVfs {
        set p [file join $prefix $path]
        file lstat $p s
        return [array get s]
    }
}

proc _dondevfs_open_dir {prefix path} {
    dondevfs::util::disableAllVfs {
        set p [file join $prefix $path]
        return [open $p]
    }
}
