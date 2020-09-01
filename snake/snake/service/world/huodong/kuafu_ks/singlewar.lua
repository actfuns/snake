local global = require "global"
local res = require "base.res"
local interactive = require "base.interactive"
local record = require "public.record"
local extend = require "base.extend"
local net = require "base.net"
local gamedefines = import(lualib_path("public.gamedefines"))
local huodong = import(service_path("huodong.singlewar"))


function NewHuodong(sHuodongName)
    return CHuodong:New(sHuodongName)
end

CHuodong = {}
CHuodong.__index = CHuodong
CHuodong.m_sTempName = "蜀山论道"
inherit(CHuodong, huodong.CHuodong)

function CHuodong:New(sHuodongName)
    local o = super(CHuodong).New(self, sHuodongName)
    return o
end

function CHuodong:IsKSGameStart()
    local iCurrTime = get_time()
    return iCurrTime >= self.m_iPrepareTime and iCurrTime < self.m_iEndTime
end

function CHuodong:ValidJoinKSGame(oPlayer)
    local iText = self:ValidJoinGame(oPlayer)
    return iText == 1
end

function CHuodong:JoinKSGame(oPlayer)
    self:JoinGame(oPlayer)
end

function CHuodong:TryTransferHome(oPlayer)
    global.oWorldMgr:TryBackGS(oPlayer)
end

function CHuodong:NotifyGameStart()
    super(CHuodong).NotifyGameStart(self)
    -- TODO

    -- global.oWorldMgr:OnStartHuodong(self.m_sName, )
end



