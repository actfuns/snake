local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local res = require "base.res"
local record = require "public.record"

require "skynet.manager"

local logiccmd = import(service_path("logiccmd.init"))
local relationobj = import(service_path("relationobj"))
local challengeobj = import(service_path("challengeobj"))
local trial = import(service_path("trial"))
local mentoring = import(service_path("mentoring"))
local singlewar = import(service_path("singlewar"))

skynet.start(function()
    interactive.Dispatch(logiccmd)
    net.Dispatch()

    if is_gs_server() then
        global.oMentoring = mentoring.NewMentoring()
        global.oRelationObj = relationobj.NewRelationObj()
        global.oSingleWarMatch = singlewar.NewSingleWarMatch()
        global.oChallengeObj = challengeobj.NewChallengeObj()
        global.oChallengeObj:LoadDb()
        global.oTrialMatchMgr = trial.NewTrialMatch()
        global.oTrialMatchMgr:LoadDb()
    end

    skynet.register ".recommend"
    interactive.Send(".dictator", "common", "Register", {
        type = ".recommend",
        addr = MY_ADDR,
    })

    record.info("recommend service booted")
end)
