#!/usr/bin/python
#coding:utf-8
import subprocess
import os.path
import sys
import time
import signal

SERVER_KEY_LIST = {
    "./shell/master/rsync_conf.sh" : 1,
    "./shell/gen_config.sh" : 1,
}

NON_SERVER_KEY = {
    "./shell/bs_close.sh" : 1,
    "./shell/bs_run.sh" : 1,
    "./shell/bs_start.sh" : 1,
    "./shell/cs_close.sh" : 1,
    "./shell/cs_run.sh" : 1,
    "./shell/cs_start.sh" : 1,
    "./shell/gs_close.sh" : 1,
    "./shell/gs_run.sh" : 1,
    "./shell/gs_start.sh" : 1,
    "./shell/open_gate.sh" : 1,
    "./shell/ks_close.sh" : 1,
    "./shell/ks_run.sh" : 1,
    "./shell/ks_start.sh" : 1,
    "./shell/open_gate_ks.sh" : 1,
    "./shell/pull_data.sh" : 1,
}

FILTER_SERVER_TYPE = {
    "./shell/bs_close.sh" : ["bs"],
    "./shell/bs_run.sh" : ["bs"],
    "./shell/bs_start.sh" : ["bs"],
    "./shell/cs_close.sh" : ["cs"],
    "./shell/cs_run.sh" : ["cs"],
    "./shell/cs_start.sh" : ["cs"],
    "./shell/gs_close.sh" : ["gs"],
    "./shell/gs_run.sh" : ["gs"],
    "./shell/gs_start.sh" : ["gs"],
    "./shell/open_gate.sh" : ["gs"],
    "./shell/ks_close.sh" : ["ks"],
    "./shell/ks_run.sh" : ["ks"],
    "./shell/ks_start.sh" : ["ks"],
    "./shell/open_gate_ks.sh" : ["ks"],
    "./shell/pull_data.sh" : ["bs"],
}

def GetServerType(sServerKey):
    p = subprocess.Popen("./shell/master/info/get_server_type.sh %s" % sServerKey, shell=True, stdout=subprocess.PIPE)
    outdata, _ = p.communicate()
    if outdata:
        outdata = outdata.strip("\n")
    return outdata

def GetServerIp(sServerKey):
    p = subprocess.Popen("./shell/master/info/get_ip.sh %s" % sServerKey, shell=True, stdout=subprocess.PIPE)
    outdata, _ = p.communicate()
    return outdata

def IsKnownServerKey(sServerKey):
    p = subprocess.Popen("./shell/master/info/is_known_server_key.sh %s" % sServerKey, shell=True, stdout=subprocess.PIPE)
    outdata, _ = p.communicate()
    if outdata:
        return True
    return False

def GetServerkeysFromList(sServerList):
    lServers = []
    sFilePath = "./shell/master/list/" + sServerList + ".list"
    if os.path.exists(sFilePath):
        with open(sFilePath, "r") as f:
            for line in f:
                lServers.append(line.strip("\n"))
        return lServers
    return lServers

def TransServerKey(sServerKey, sShell):
    ret = ""
    if sShell in NON_SERVER_KEY:
        pass
    elif sShell in SERVER_KEY_LIST:
        ret = sServerKey
    else:
        ret = GetServerType(sServerKey)
    return ret

def FilterServer(lServers, sShell):
    if sShell in FILTER_SERVER_TYPE:
        ret = []
        lServerType = FILTER_SERVER_TYPE[sShell]
        for sServerKey in lServers:
            if GetServerType(sServerKey) in lServerType:
                ret.append(sServerKey)
        return ret
    else:
        return lServers

def TransCmd(bRemote, sServerKey, sShell, lArgs):
    sArgs = " ".join(lArgs)
    serverarg = TransServerKey(sServerKey, sShell)
    if serverarg:
        sArgs = "%s %s" % (serverarg, sArgs)

    if not bRemote:
        sShort = "%s %s" % (sShell, sArgs)
        sCmd = sShort
    else:
        sIp = GetServerIp(sServerKey)
        if not sIp:
            return
        sShort = "%s %s" % (sShell, sArgs)
        sCmd = """ssh -o ConnectTimeout=5 -fnp 932 cilu@%s "
cd %s;
%s;
"
""" % (sIp, sServerKey, sShort)
    return sCmd, sShort

def preexec_func():
    os.setsid()
    signal.signal(signal.SIGINT, signal.SIG_IGN)

def ServerExec(bRemote, sServers, sShell, lArgs):
    lServers = GetServerkeysFromList(sServers)
    if lServers:
        pass
    elif IsKnownServerKey(sServers):
        lServers.append(sServers)

    lServers = FilterServer(lServers, sShell)
    if lServers:
        lSubs = []
        lResult = []
        for sServerKey in lServers:
            sCmd, sShort = TransCmd(bRemote, sServerKey, sShell, lArgs)
            if not sCmd:
                print "shell exec error server key %s"%sServerKey
                continue

            result = "[%s] exec [%s]：\n" % (sServerKey, sShort)
            p = subprocess.Popen(sCmd, shell=True, stdout=subprocess.PIPE, preexec_fn=preexec_func)
            lSubs.append(p)
            lResult.append(result)

        def handle_sigint(signum, frame):
            print("receive sigint kill subprocess")
            for p in lSubs:
                os.killpg(os.getpgid(p.pid), signal.SIGKILL)
            sys.exit(0)
        signal.signal(signal.SIGINT, handle_sigint)

        for idx, p in enumerate(lSubs):
            outdata, _ = p.communicate()
            print(lResult[idx] + outdata)
    else:
        print "no servers distribute!!!"

def LocalExec(sServers, sShell, lArgs):
    ServerExec(False, sServers, sShell, lArgs)

def RemoteExec(sServers, sShell, lArgs):
    ServerExec(True, sServers, sShell, lArgs)

if __name__ == "__main__":
    sLocal = sys.argv[1]
    sServers = sys.argv[2]
    sShell = sys.argv[3]
    lArgs = sys.argv[4:]
    if sLocal == "local":
        LocalExec(sServers, sShell, lArgs)
    else:
        RemoteExec(sServers, sShell, lArgs)
