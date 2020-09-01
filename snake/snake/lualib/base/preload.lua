local skynet = require "skynet"

MY_ADDR = skynet.self()
MY_SERVER_KEY = skynet.getenv("server_key")
MY_SERVER_LOCAL_IP = skynet.getenv("server_local_ip")
MY_SERVICE_NAME = ...
IS_AUTO_OPEN_MEASURE = tonumber(skynet.getenv("AUTO_OPEN_MEASURE"))
IS_AUTO_TRACK_BASEOBJECT = tonumber(skynet.getenv("AUTO_TRACK_BASEOBJECT"))
IS_AUTO_MONITOR = tonumber(skynet.getenv("AUTO_MONITOR"))
LOG_BASE_PATH = skynet.getenv("LOG_BASE_PATH")
DB_FILE_PATH = skynet.getenv("DB_FILE_PATH")

require "base.commonop"

local tbpool = require "base.tbpool"
tbpool.Init()

local servicetimer = require "base.servicetimer"
servicetimer.Init()

require "base.reload"
require "base.timeop"
require "base.fileop"
require "base.stringop"
require "base.tableop"
require "base.vector3"

MY_SERVER_CLUSTER = get_server_cluster(MY_SERVER_KEY)
MY_SERVER_TAG = get_server_tag(MY_SERVER_KEY)
MY_SERVER_TYPE = get_server_type(MY_SERVER_KEY)
MY_SERVER_ID = get_server_id(MY_SERVER_KEY)

local basehook = require "base.basehook"
local baserecycle = require "base.baserecycle"
local interactive = require "base.interactive"
local servicesave = require "base.servicesave"
local netproto = require "base.netproto"

skynet.dispatch_finish_hook(basehook.hook)
basehook.set_base(function ()
    baserecycle.recycle()
end)

interactive.Init()
netproto.Init()
servicesave.Init()

create_folder(LOG_BASE_PATH)
create_folder(LOG_BASE_PATH..MY_SERVER_KEY)
if is_ks_server() then
    create_folder(DB_FILE_PATH)
end
