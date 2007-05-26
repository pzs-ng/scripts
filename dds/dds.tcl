##############################################################################
# dds.tcl 0.1 by d3x0c                                                       #
# This is an easy tcl script that executes daxxar's daystats script 0.5.     #
# If your perl script is not in the right path please correct it.            #
##############################################################################

set ddsbinary "/glftpd/bin/dds.pl"

if {[info exists cmdpre]} {
    if {[string is true -strict $bindnopre]} {
        bind pub o|o !daystats pub:dds
    } elseif {![string equal "!" $cmdpre]} {
        catch {unbind pub o|o !daystats pub:dds}
    }
    bind pub o|o [set cmdpre]daystats pub:dds
} else {
    bind pub o|o !daystats pub:dds
}

proc pub:dds {nick output binary chan text} { 
    global ddsbinary

    set lines [split [exec $ddsbinary]]
    foreach line $lines {
        putlog "dds.tcl; dds.pl error/warning - $line"
    }
}

putlog "dds.tcl 0.1 by d3x0c loaded (for daxxar's daystats 0.5)"
