#!/usr/bin/python
#coding:utf-8

import pyutils.dbdata as db

PRODUCT_MAP = {
	"com.cilu.dhxx.gold_6" : 6,
	"com.cilu.dhxx.gold_30" : 30,
	"com.cilu.dhxx.gold_98" : 98,
	"com.cilu.dhxx.gold_198" : 198,
	"com.cilu.dhxx.gold_328" : 328,
	"com.cilu.dhxx.gold_648" : 648,
	"com.cilu.dhxx.giftbag_1" : 1,
	"com.cilu.dhxx.giftbag_3" : 3,
	"com.cilu.dhxx.giftbag_6" : 6,
	"com.cilu.dhxx.giftbag_10" : 10,
	"com.cilu.dhxx.giftbag_60" : 60,
	"com.cilu.dhxx.card_18" : 18,
	"com.cilu.dhxx.card_30" : 30,	
	"com.cilu.dhxx.grow_88" : 88,
	"com.cilu.dhxx.grow_98" : 98,
}


class CPayCount(object):
	def __init__(self):
		self.m_sDB = "cs_pay"
		self.m_mResult = {}

	def pay_count(self):
		conn = db.GetConnection()
		coll = conn[self.m_sDB]["pay"]
		for data in coll.find():
			data = db.AfterLoad(data)
			account = data["account"]
			channel = data["demi_channel"]
			productId = data["product_key"]
			amount = data["product_amount"]
			sKey = self.gen_key(account, channel)
			m = self.m_mResult.get(sKey)
			if m is None:
				m = {"account":account, "channel":channel, "paycount":0}
				self.m_mResult[sKey] = m

			price = PRODUCT_MAP.get(productId)
			if price is None:
				print "not find productId %s" % (productId)

			m["paycount"] += price * amount


	def pay_count2(self):
		conn = db.GetConnection()
		coll = conn[self.m_sDB]["old_pay"]
		for data in coll.find({"serverkey":"pro_gs10001"}):
			data = db.AfterLoad(data)
			account = data["account"]
			channel = data["demi_channel"]
			productId = data["product_key"]
			amount = data["product_amount"]
			sKey = self.gen_key(account, channel)
			m = self.m_mResult.get(sKey)
			if m is None:
				m = {"account":account, "channel":channel, "paycount":0}
				self.m_mResult[sKey] = m

			price = PRODUCT_MAP.get(productId)
			if price is None:
				print "not find productId %s" % (productId)

			m["paycount"] += price * amount


	def pay_vivo(self):
		conn = db.GetConnection()
		coll = conn[self.m_sDB]["vivo_pay"]
		for data in coll.find():
			data = db.AfterLoad(data)
			account = data["account"]
			channel = data["demi_channel"]
			productId = data["product_key"]
			amount = data["product_amount"]
			sKey = self.gen_key(account, channel)
			m = self.m_mResult.get(sKey)
			if m is None:
				m = {"account":account, "channel":channel, "paycount":0}
				self.m_mResult[sKey] = m

			price = PRODUCT_MAP.get(productId)
			if price is None:
				print "not find productId %s" % (productId)

			m["paycount"] += price * amount

	def gen_key(self, account, channel):
		return "%d-%s" % (channel, account) 


	def show_resutl(self):
		for key, m in self.m_mResult.items():
			print " %d  %d  %s" % (m.get("channel"), m.get("paycount"), m.get("account"))


	def write_mongo(self):
		conn = db.GetConnection()
		coll = conn[self.m_sDB]["cbt_pay"]
		coll.ensure_index([("account", 1), ("channel", 1)])
		for key, m in self.m_mResult.items():
			insert_info = db.BeforeSave({"account":m.get("account"), "channel":m.get("channel"), "paycount":m.get("paycount")})
			coll.insert(insert_info)


	def write_file(self):
		f = open("cbt_pay.txt", "a")
		# f.write("channel  paycount  account\n")
		for key, m in self.m_mResult.items():
			f.write("%s %d %d \n" % (m.get("account"), m.get("channel"), m.get("paycount")))
		f.close()


if __name__ == "__main__":
    print "begin paycount start .............."
    obj = CPayCount()
    obj.pay_count()
    obj.pay_count2()
    obj.pay_vivo()
    # obj.show_resutl()
    obj.write_mongo()
    # obj.write_file()
    print "begin paycount end .............."
