local global = require "global"
local skynet = require "skynet"

--打开神器
function C2GSArtifactOpenUI(oPlayer, mData)
    global.oArtifactMgr:OpenArtifactUI(oPlayer)
end

--神器升级
function C2GSArtifactUpgradeUse(oPlayer, mData)
    global.oArtifactMgr:UpgradeUseAll(oPlayer, mData.goldcoin==1)
end

--神器强化
function C2GSArtifactStrength(oPlayer, mData)
    global.oArtifactMgr:StrengthArtifact(oPlayer, mData.goldcoin==1)
end

--器灵觉醒
function C2GSArtifactSpiritWakeup(oPlayer, mData)
    local iSpirit = mData.spirit_id
    local bGoldCoin = mData.goldcoin==1
    global.oArtifactMgr:ArtifactSpiritWakeup(oPlayer, iSpirit, bGoldCoin)
end

--器灵重置技能
function C2GSArtifactSpiritResetSkill(oPlayer, mData)
    local iSpirit = mData.spirit_id
    local bGoldCoin = mData.goldcoin==1
    global.oArtifactMgr:ArtifactResetSkill(oPlayer, iSpirit, bGoldCoin)
end

--保存器灵技能
function C2GSArtifactSpiritSaveSkill(oPlayer, mData)
    local iSpirit = mData.spirit_id
    global.oArtifactMgr:ArtifactSaveSkill(oPlayer, iSpirit)
end

--设置跟随器灵
function C2GSArtifactSetFollowSpirit(oPlayer, mData)
    local iSpirit = mData.spirit_id
    global.oArtifactMgr:SetFollowSpirit(oPlayer, iSpirit)
end

--设置参战器灵
function C2GSArtifactSetFightSpirit(oPlayer, mData)
    local iSpirit = mData.spirit_id
    global.oArtifactMgr:SetFigthSpirit(oPlayer, iSpirit)
end

