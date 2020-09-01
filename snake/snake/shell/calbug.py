#!/usr/bin/python
#coding:utf-8

#mongoexport -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin -d gamelog201711 -c money -q "{'subtype':'vigor','reason':'元宝转精气'}" --port 27017 -o vigo2.json
#mongoimport -u root -p YXTxsaj22WSJ7wTG --authenticationDatabase admin -d gamelog -c money --port 27017 ~/debug/vigo2.json

import os
import sys
import pyutils.dbdata as db

class CDebug(object):
    def __init__(self):
        self.m_sDB = "gamelog"
        self.m_mVigo = {}

    def cal_vigo(self):
        conn = db.GetConnection()
        coll = conn[self.m_sDB]["money"]
        for data in coll.find({'subtype':'vigor','reason':'元宝转精气'}):
            pid = data["pid"]
            add = data["vigor_add"]
            if not pid in self.m_mVigo:
                self.m_mVigo[pid] = add
            else:
                self.m_mVigo[pid] += add

    def write_vigo(self,output):
        f = open(output, "a")
        for pid, count in self.m_mVigo.iteritems():
            f.write("%s %d\n" % (pid, count))
        f.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        os._exit(1)
    print "begin debug start .............."
    obj = CDebug()
    obj.cal_vigo()
    obj.write_vigo(sys.argv[1])
    print "begin debug end .............."
