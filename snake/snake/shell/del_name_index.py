#!/usr/bin/python
#coding:utf-8

import os
import sys
import pyutils.dbdata as db


class Index(object):
    """docstring for Index"""
    def __init__(self, server_ip, server_port):
        self.conn = db.GetConnection(server_ip, server_port)
        self.handle_player()
        self.handle_org()
        self.handle_orgready()

    def handle_player(self):
        print "handle_player start .............."
        coll = self.conn['game']["player"]
        coll.drop_index("player_name_index")
        print "handle_player end .............."

    def handle_org(self):
        print "handle_org start .............."
        coll = self.conn['game']["org"]
        coll.drop_index("org_name_index")
        print "handle_org end .............."

    def handle_orgready(self):
        print "handle_orgready start .............."
        coll = self.conn['game']["orgready"]
        coll.drop_index("orgready_name_index")
        print "handle_orgready end .............."


if __name__ == "__main__":
    server_ip = "127.0.0.1"
    server_port = 27017
    if len(sys.argv) > 1:
        server_ip = sys.argv[1]
    if len(sys.argv) > 2:
        server_port = int(sys.argv[2])
    print "del name index %s %s start .............." % (server_ip, server_port)
    Index(server_ip, server_port)
    print "del name index %s %s end .............." % (server_ip, server_port)
