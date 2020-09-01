--import module
local global = require "global"

OPTION = {
    ENGAGE = 1,
    ENGAGE_INS = 2,
    DIS_ENGAGE = 3,
    DIS_ENGAGE_INS = 4,
    MARRY = 5,
    MARRY_INS = 6,
    DIVORCE = 7,
    DIVORCE_INS = 8,
    FORCE_DIVORCE = 9,
    DIVORCE_CON1 = 10,          -- 提交期
    DIVORCE_CANCEL = 11,
    DIVORCE_CON2 = 12,          -- 确认期
    DIVORCE_REFUSE = 13,        -- 强制离婚
    DIVORCE_AGREE = 14,         -- 强制离婚
    FORCE_DIVORCE_CON = 15,     -- 强制离婚确认
    DIVORCE_REFUSE2 = 16,        -- 强制离婚grey
}

local mOptions = {
    [OPTION.ENGAGE] = "订婚",
    [OPTION.ENGAGE_INS] = "订婚说明",
    [OPTION.DIS_ENGAGE] = "解除订婚",
    [OPTION.DIS_ENGAGE_INS] = "解除订婚说明",
    [OPTION.MARRY] = "结婚",
    [OPTION.MARRY_INS] = "结婚说明",
    [OPTION.DIVORCE] = "协议离婚",
    [OPTION.DIVORCE_INS] = "离婚说明",
    [OPTION.FORCE_DIVORCE] = "强制离婚",
    [OPTION.DIVORCE_CON1] = "#grey确认离婚申请",
    [OPTION.DIVORCE_CANCEL] = "取消离婚申请",
    [OPTION.DIVORCE_CON2] = "确认离婚申请",
    [OPTION.DIVORCE_REFUSE] = "拒绝离婚",
    [OPTION.DIVORCE_AGREE] = "同意离婚",
    [OPTION.FORCE_DIVORCE_CON] = "确认离婚申请",
    [OPTION.DIVORCE_REFUSE2] = "#grey拒绝离婚",
}

local mFunctions = {
    [OPTION.ENGAGE] = "DoEngage",
    [OPTION.ENGAGE_INS] = "DoEngageIns",
    [OPTION.DIS_ENGAGE] = "DoDisEngage",
    [OPTION.DIS_ENGAGE_INS] = "DoDisEngageIns",
    [OPTION.MARRY] = "DoMarry",
    [OPTION.MARRY_INS] = "DoMarryIns",
    [OPTION.DIVORCE] = "DoDivorce",
    [OPTION.DIVORCE_INS] = "DoDivorceIns",
    [OPTION.FORCE_DIVORCE] = "DoForceDivorce",
    [OPTION.DIVORCE_CON1] = "DoDivorceConfirm1",
    [OPTION.DIVORCE_CANCEL] = "DoDivorceCancel",
    [OPTION.DIVORCE_CON2] = "DoDivorceConfirm2",
    [OPTION.DIVORCE_REFUSE] = "DoRefuseDivorce",
    [OPTION.DIVORCE_AGREE] = "DoAgreeDivorce",
    [OPTION.FORCE_DIVORCE_CON] = "DoForceDivorceConFirm",
    [OPTION.DIVORCE_REFUSE2] = "DoRefuseDivorce",
}

function GetOptionsText(lOptions)
    if #lOptions <= 0 then return end

    local sOption = ""
    for _,iOption in pairs(lOptions) do
        sOption = string.format("%s&Q%s", sOption, mOptions[iOption])    
    end
    return sOption
end

function GetFunc(iOption)
    return mFunctions[iOption]
end

function DoEngage(oPlayer) 
    oPlayer:Send("GS2CEngageOperate", {type=1})
end

function DoEngageIns(oPlayer)
    oPlayer:Send("GS2CShowInstruction", {instruction=13005})
end

function DoDisEngage(oPlayer)
    oPlayer:Send("GS2CEngageOperate", {type=0})
end

function DoDisEngageIns(oPlayer)
    oPlayer:Send("GS2CShowInstruction", {instruction=13006})
end

function DoMarry(oPlayer)
    global.oMarryMgr:DoApplyMarry(oPlayer)
end

function DoMarryIns(oPlayer)
    oPlayer:Send("GS2CShowInstruction", {instruction=13012})    
end

function DoDivorce(oPlayer)
    global.oMarryMgr:DoApplyDivorce(oPlayer)
end

function DoDivorceIns(oPlayer)
    oPlayer:Send("GS2CShowInstruction", {instruction=13013})    
end

function DoForceDivorce(oPlayer)
    global.oMarryMgr:DoForceDivorce(oPlayer)
end

function DoDivorceConfirm1(oPlayer)
    global.oMarryMgr:DoDivorceConfirm1(oPlayer)
end

function DoDivorceCancel(oPlayer)
    global.oMarryMgr:DoDivorceCancel(oPlayer)    
end

function DoDivorceConfirm2(oPlayer)
    global.oMarryMgr:DoDivorceConfirm2(oPlayer)    
end

function DoRefuseDivorce(oPlayer)
    global.oMarryMgr:DoRefuseDivorce(oPlayer)
end

function DoAgreeDivorce(oPlayer)
    global.oMarryMgr:DoAgreeDivorce(oPlayer)
end

function DoForceDivorceConFirm(oPlayer)
    global.oMarryMgr:DoForceDivorceConFirm(oPlayer)
end


