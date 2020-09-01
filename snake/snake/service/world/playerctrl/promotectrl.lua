--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local extend = require "base.extend"

local datactrl = import(lualib_path("public.datactrl"))

CPromoteCtrl = {}
CPromoteCtrl.__index = CPromoteCtrl
inherit(CPromoteCtrl, datactrl.CDataCtrl)

function CPromoteCtrl:New(pid)
    local o = super(CPromoteCtrl).New(self,{pid = pid})
    return o
end

function CPromoteCtrl:GetPid()
    return self:GetInfo("pid")
end

function CPromoteCtrl:OnLogin(oPlayer,bReEnter)
    local oFmtMgr = oPlayer:GetFormationMgr()
    oFmtMgr:RefreshAllFmtInfo()
    self:TriggerPromote(oPlayer,0)
end

function CPromoteCtrl:TriggerPromote(oPlayer,open)
    if not global.oToolMgr:IsSysOpen("IMPROVE") then
        return
    end
    local mRatio = {}
    local mScore = oPlayer.m_oSkillCtrl:GetScore2()
    local iEquipStrength = oPlayer.m_oEquipMgr:GetScoreByStrength()
    local iEquipSH = oPlayer.m_oEquipMgr:GetScoreBySH()
    local iEquipBase = oPlayer.m_oEquipMgr:GetScore()
    local iEquipHunShi = oPlayer.m_oEquipMgr:GetScoreByHunShi()

    table.insert(mScore,{iEquipBase,"equip_grade"})
    table.insert(mScore,{iEquipStrength,"equip_strength"})
    table.insert(mScore,{iEquipSH,"equip_sh"})
    table.insert(mScore,{oPlayer.m_oPartnerCtrl:GetScore(),"partner"})
    table.insert(mScore,{oPlayer.m_oSummonCtrl:GetScore(),"summon"})
    table.insert(mScore,{oPlayer.m_oTouxianCtrl:GetScore(),"touxian"})
    table.insert(mScore,{oPlayer.m_oRideCtrl:GetScore(),"ride"})
    table.insert(mScore,{iEquipHunShi,"equip_hunshi"})
    table.insert(mScore,{global.oScoreCache:GetScoreByKey(oPlayer, "fabaoctrl"), "fabao"})
    table.insert(mScore,{global.oScoreCache:GetScoreByKey(oPlayer, "artifactctrl"), "artifact"})
    table.insert(mScore,{global.oScoreCache:GetScoreByKey(oPlayer, "wingctrl"), "wing"})
    local iGrade = oPlayer:GetGrade()
    iGrade = math.min(#res["daobiao"]["promote"]["biaozhun"],iGrade)
    iGrade = math.max(iGrade,1)
    for _,mInfo in ipairs(mScore) do
        local iSubScore = mInfo[1]
        local sAttr = mInfo[2]
        local iStardScore = res["daobiao"]["promote"]["biaozhun"][iGrade][sAttr]
        local iRadio = math.floor(iSubScore*100/iStardScore)
        iRadio  = math.max(iRadio,0)
        iRadio = math.min(iRadio,100*100)
        table.insert(mRatio,iRadio)
    end
    local mNet ={}
    mNet.radio = mRatio
    mNet.score = oPlayer:GetScore()

    if res["daobiao"]["promote"]["biaozhun"][iGrade] then
        mNet.sumscore = res["daobiao"]["promote"]["biaozhun"][iGrade]["score"]
    else
        mNet.sumscore = 0
    end
    mNet.open = open

    local iRadio = math.floor(mNet.score*100/mNet.sumscore)
    for _,mInfo in ipairs(res["daobiao"]["promote"]["judge"]) do 
        if mInfo.radio<iRadio then
            mNet.result = mInfo.id
            break
        end
    end
    mNet.result = mNet.result or 7
    oPlayer:Send("GS2CPromote",mNet)
end