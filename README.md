需要的系统是	
CentOS 7.2

★关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service

1安装宝塔

yum install -y wget && wget -O install.sh http://download.bt.cn/install/install.sh && sh install.sh


Nginx1.1.4
php5.4

mongodb 这个在软件管理 

mongodb安装好后复制下面的

mongo
use admin
db.createUser({user:"root",pwd:"YXTxsaj22WSJ7wTG",roles:[{role:"root",db:"admin"}]})
exit


2.上传snake.zip 到home  不是根目录


解压snake.zip

3.上传pymongo-3.5.1.tar.gz到home
解压pymongo-3.5.1.tar.gz


复制下面的

tar -zxvf pymongo-3.5.1.tar.gz
pip install DBUtils
cd /home/pymongo-3.5.1
python setup.py install

pip install setuptools


4.大家先在电脑上解压sh.tgz 然后把解压的文件拖进home/snake目录

all_start.sh
bs_kill.sh
bs_run.sh
cs_kill.sh
cs_run.sh
gs_kill.sh
gs_run.sh
Makefile
open_gate.sh   共9个


5.chmod -R 777 /home

放全部端口 1:65535

启动游戏
cd /home/snake
./all_start.sh

关闭游戏
pkill skynet

客户端

解包客户端里面的script，修改CServerPhoneCtrl.lua里面ID1001开头的就可以了，然后打包回去
