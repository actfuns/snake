#!/usr/bin/expect

spawn sudo -s date -s [lindex $argv 0]
expect "password for"
send "hellowork\n"
expect eof
