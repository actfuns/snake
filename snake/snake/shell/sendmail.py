import email
import smtplib
import os
import sys
import httplib
import urllib
import json

from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

class CMyEmail(object):
    def __init__(self, env):
        self.user = "h7@cilugame.com"
        self.pwd = "d5UGxFFMM3mEX3uk"
        self.to_list = [
            "weicheng.cao@cilugame.com",
            "gan.chen@cilugame.com",
            "li.duan@cilugame.com",
            "zhongla.liu@cilugame.com",
            "yi.xiong@cilugame.com",
            "cilugamedebug@163.com",
            "hongjie.zhao@cilugame.com",
        ]
        self.cc_list = []
        self.tag = "h7-server-error"
        self.title = ""
        self.content = ""
        self.wechat_url = "http://172.19.252.150:80/logsend/weixin/4"
        self.wechat_ip = "172.19.252.150"
        #self.wechat_url = "http://10.23.174.158:80/logsend/weixin/4"
        #self.wechat_ip = "10.23.174.158"


    def send_mail(self):
        try:
            server = smtplib.SMTP_SSL("smtp.exmail.qq.com", port=465, timeout=6)
            server.login(self.user, self.pwd)
            server.sendmail("From <%s>"%self.user, self.to_list, self.get_attach())
            server.close()
            print ("send email success")
        except Exception,e:
            print ("send email failed", e)


    def get_attach(self):
        attach = MIMEMultipart()
        if self.tag:
            attach["Subject"] = self.tag
        if self.user:
            attach["From"] = self.user
        if self.to_list:
            attach["To"] = ";".join(self.to_list)
        if self.cc_list:
            attach["Cc"] = ";".join(self.cc_list)
        if self.content:
            doc = MIMEText(self.content)
            doc["Context-Type"] = "application/octet-stream"
            attach.attach(doc)

        return attach.as_string()

    def send_wechat(self):
        body = json.dumps({'message':self.content, 'title':self.title})
        header = {'Host':self.wechat_ip, 'Content-type':"application/json"}
        conn = httplib.HTTPConnection(self.wechat_ip)
        conn.request(method="POST", url=self.wechat_url, body=body, headers=header)
        response = conn.getresponse()
        res = response.read()
        print res


if __name__ == "__main__":
    if len(sys.argv) == 4:
        env = sys.argv[1]
        title = sys.argv[2]
        content = sys.argv[3]
        if not env or not content or not title:
            os._exit(1)

        mail_box = CMyEmail(env)
        mail_box.title = title
        mail_box.content = content
        #mail_box.send_mail()
        mail_box.send_wechat()

