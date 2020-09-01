#!/usr/bin/python
#coding:utf-8

import argparse
import os, sys
import re


p1 = re.compile("(?P<cluster>[a-zA-Z0-9]+)_(?P<server_type>[a-zA-Z]+)(?P<server_id>\d*)")

def gen_config(args):
    group_result = p1.match(args.server_key)
    if not group_result:
        return
    cluster = group_result.group("cluster").strip()
    server_type = group_result.group("server_type").strip()
    if server_type == "cs":
        gen_cs_config(args)
    elif server_type == "gs":
        gen_gs_config(args)
    elif server_type == "bs":
        gen_bs_config(args)
    elif server_type == "ks":
        gen_ks_config(args)

def gen_bs_config(args):
    with open("./config/template/bs_config.lua", "rb") as fp:
        content = fp.read()
    content = content.replace("T_SERVER_KEY", '"%s"'%args.server_key)
    with open("./config/bs_config.lua", "wb") as fp:
        fp.write(content)

def gen_cs_config(args):
    with open("./config/template/cs_config.lua", "rb") as fp:
        content = fp.read()
    content = content.replace("T_SERVER_KEY", '"%s"'%args.server_key)
    with open("./config/cs_config.lua", "wb") as fp:
        fp.write(content)

def gen_gs_config(args):
    with open("./config/template/gs_config.lua", "rb") as fp:
        content = fp.read()
    content = content.replace("T_SERVER_KEY", '"%s"'%args.server_key)
    content = content.replace("T_LOCAL_IP", '"%s"'%args.server_ip)
    with open("./config/gs_config.lua", "wb") as fp:
        fp.write(content)

def gen_ks_config(args):
    with open("./config/template/ks_config.lua", "rb") as fp:
        content = fp.read()
    content = content.replace("T_SERVER_KEY", '"%s"'%args.server_key)
    content = content.replace("T_LOCAL_IP", '"%s"'%args.server_ip)
    with open("./config/ks_config.lua", "wb") as fp:
        fp.write(content)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="generate config file")
    parser.add_argument('server_key', help="server key find in master/server.list")
    parser.add_argument('server_ip', help="dev server ip")

    args = parser.parse_args()
    gen_config(args)
