#!/usr/bin/python
#coding:utf-8

import sys
import os
import subprocess

def date_reboot(date):
    subprocess.Popen('./shell/date_reboot.sh "%s"' % date, preexec_fn=os.setsid, close_fds=True, shell=True)
    sys.exit(0)

if __name__ == "__main__":
    date = sys.argv[1]
    date_reboot(date)