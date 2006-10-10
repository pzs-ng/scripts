## Configuration

set psxcnc(NUKEWIPE) "/glftpd/bin/psxc-nukewipe"
set psxcnc(CMDPRE) "!PS"
set psxcnc(SITENAME) "\[PS\]"

######## End Configuration #########

bind pub o|o [set psxcnc(CMDPRE)]nukewipe psxc_nukewipe

proc psxc_nukewipe {nick uhost hand chan argv} {
    global psxcnc
    putquick "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKECLEANER:\037 Hold on - cleaning nukes on site..."
    catch {exec $psxcnc(NUKEWIPE) $chan $args} psxclines
    if { $psxcline == "child process exited abnormally" } { putserv "privmsg $chan :error..."; return }
    foreach psxcline [split $psxclines "\n" ] {
      putserv "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKECLEANER:\037 $psxcline"
    }
    putquick "PRIVMSG $chan :\002$psxcnc(SITENAME)\002 - \037NUKECLEANER:\037 Done."
}
putlog "Loaded: psxc-nukeclean v0.01 psxc(C)2006"


