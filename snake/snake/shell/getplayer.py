#coding:utf-8
import commands
import os
import sys
import time

Key2Ip = {
    "h7dpro_gs10001"  :   "127.0.0.1:27022",
    "h7dpro_gs10002"  :   "127.0.0.1:27024",
    "h7dpro_gs10003"  :   "127.0.0.1:27015",
    "h7dpro_gs10004"  :   "127.0.0.1:27016",
    "h7dpro_gs10005"  :   "127.0.0.1:27014",
    "h7dpro_gs10006"  :   "127.0.0.1:27013",
    "h7dpro_gs10007"  :   "127.0.0.1:27012",
    "h7dpro_gs10008"  :   "127.0.0.1:27009",
    "h7dpro_gs10009"  :   "127.0.0.1:27008",
    "h7dpro_gs20001"  :   "127.0.0.1:27011",
}

def getaddr(server):
    return Key2Ip[server]

def dumpplayer(server, pid):
    cmd = """ssh h7d-slave-01 'mongoexport -h %s -uroot -pYXTxsaj22WSJ7wTG --authenticationDatabase admin -d game -c player -q {pid:%d} -o /home/cilu/shell/player_%d.db'"""%(getaddr(server), pid, pid)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)

    cmd = """ssh h7d-slave-01 'mongoexport -h %s -uroot -pYXTxsaj22WSJ7wTG --authenticationDatabase admin -d game -c offline -q {pid:%d} -o /home/cilu/shell/offline_%d.db'"""%(getaddr(server), pid, pid)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)

    commands.getstatusoutput("logout")


def scpplayer(pid):
    cmd = "scp h7d-slave-01:/home/cilu/shell/player_%d.db /home/cilu/waifu_db/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)
    cmd = "scp h7d-slave-01:/home/cilu/shell/offline_%d.db /home/cilu/waifu_db/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)

def scpocplayer(pid):
    cmd = "scp cilu@h7d-oc:/home/cilu/waifu_db/player_%d.db /home/cilu/waifu_db/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)
    cmd = "scp cilu@h7d-oc:/home/cilu/waifu_db/offline_%d.db /home/cilu/waifu_db/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)
     
def scpdevplayer(pid):
    cmd = "scp -P 932 cilu@h7d-develop:/home/cilu/waifu_db/player_%d.db ./shell/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)
    cmd = "scp -P 932 cilu@h7d-develop:/home/cilu/waifu_db/offline_%d.db ./shell/"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)


def loadplayer(pid):
    cmd = "mongoimport -h 127.0.0.1:27017 -uroot -pYXTxsaj22WSJ7wTG --authenticationDatabase admin -d game -c player --file ./shell/player_%d.db --mode upsert"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)
    cmd="mongoimport -h 127.0.0.1:27017 -uroot -pYXTxsaj22WSJ7wTG --authenticationDatabase admin -d game -c offline --file ./shell/offline_%d.db --mode upsert"%(pid,)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)


def dumpgame(server):
    timestamp = time.strftime("%Y-%m-%d")
    addr = getaddr(server)
    cmd = """ssh h7d-slave-01 'mongodump --gzip -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin -d game --archive=./dump/%s-%s.gz -h %s &>./dump/%s-%s.log'"""%(server, timestamp, addr, server, timestamp)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)

    addr = "127.0.0.1:27018"
    cmd = """ssh h7d-slave-01 'mongodump --gzip -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin -d game --archive=./dump/cs-%s.gz -h %s &>./dump/cs-%s.log'"""%(timestamp, addr, timestamp)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)


def scpgame(server):
    timestamp = time.strftime("%Y-%m-%d")
    cmd = """scp -l 1024 cilu@h7d-slave-01:/home/cilu/dump/%s-%s.gz /home/cilu/waifu_db/"""%(server, timestamp)
    status, result = commands.getstatusoutput(cmd)
    print("status1", status)
    cmd = """scp -l 1024 cilu@h7d-slave-01:/home/cilu/dump/cs-%s.gz /home/cilu/waifu_db/"""%(timestamp,)
    status, result = commands.getstatusoutput(cmd)
    print("status2", status)


def loadgame(server):
    timestamp = time.strftime("%Y-%m-%d")
    cmd = """mongorestore --gzip -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin --archive=/home/cilu/waifu_db/cs-%s.gz"""%(timestamp,)
    status, result = commands.getstatusoutput(cmd)
    print("loadcs", status)

    cmd = """mongorestore --gzip -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin --archive=/home/cilu/waifu_db/%s-%s.gz"""%(server, timestamp,)
    status, result = commands.getstatusoutput(cmd)
    print("load %s %s"%(server, status))

def modifygame(server1, server2):
    cmd ="""mongo -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin game --eval 'db.world.updateMany({server_id:"%s"}, {$set:{"server_id":"%s"}})'"""%(server1, server2)
    status, result = commands.getstatusoutput(cmd)
    print("modifygame", status)



if __name__ == "__main__":
    #param python getplayer dumplayer server pid
    if len(sys.argv) < 2:
        os._exit(1)
    func = sys.argv[1]
    if func == "dumpplayer":
        server, pid = sys.argv[2], sys.argv[3]
        dumpplayer(server, int(pid))
    elif func == "scpplayer":
        pid = sys.argv[2]
        scpplayer(int(pid))
    elif func == "scpocplayer":
        pid = sys.argv[2]
        scpocplayer(int(pid))
    elif func == "scpdevplayer":
        pid = sys.argv[2]
        scpdevplayer(int(pid))
    elif func == "loadplayer":
        pid = sys.argv[2]
        loadplayer(int(pid))
    elif func == "dumpgame":
        server = sys.argv[2]
        dumpgame(server)
    elif func == "scpgame":
        server = sys.argv[2]
        scpgame(server)
    elif func == "loadgame":
        server = sys.argv[2]
        loadgame(server)
    elif func == "modifygame":
        server1, server2 = sys.argv[2], sys.argv[3]
        modifygame(server1, server2)

