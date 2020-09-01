--import module

local global = require "global"
local extend = require "base/extend"
local record = require "public.record"
local auth = import(service_path("gm/gm_auth"))

function NewGMMgr(...)
    local o = CGMMgr:New(...)
    return o
end

CGMMgr = {}
CGMMgr.__index = CGMMgr
inherit(CGMMgr, logic_base_cls())

function CGMMgr:New()
    local o = super(CGMMgr).New(self)
    return o
end

function CGMMgr:GetGmFile()
    return {
        "gm_friend",
        "gm_huodong",
        "gm_item",
        "gm_mail",
        "gm_open",
        "gm_org",
        "gm_other",
        "gm_partner",
        "gm_player",
        "gm_rank",
        "gm_reward",
        "gm_ride",
        "gm_scene",
        "gm_server",
        "gm_summon",
        "gm_task",
        "gm_war",
        "gm_world",
        "gm_shop",
        "gm_marry",
    }
end

function CGMMgr:IsGM(iPid)
    if get_server_cluster() == "outertest" then
        return true
    end
    return auth.IsGM(iPid)
end

function CGMMgr:ValidUseCommand(oMaster, sCmd)
    return auth.ValidUseCommand(oMaster, sCmd)
end

function CGMMgr:DoHelpCommand(oMaster, sCmd)
    local oNotifyMgr = global.oNotifyMgr
    local mFile = self:GetGmFile()
    local bExecute = false

    for _, sFile in pairs(mFile) do
        local oFile = import(service_path(string.format("gm/%s", sFile)))
        local mContent = oFile.Helpers[sCmd]
        local func = oFile.Commands[sCmd]

        if func then
            if not mContent then
                oMaster:Send("GS2CGMMessage", {
                    msg=string.format("指令%s没有帮助信息",sCmd)
                })
            else
                local sMsg = string.format("%s:\n指令说明:%s\n参数说明:%s\n示例:%s\n", sCmd, mContent[1], mContent[2], mContent[3])
                oMaster:Send("GS2CGMMessage", {
                    msg = sMsg,
                })
                bExecute = true
            end
            break
        end
    end

    if not bExecute then
        oMaster:Send("GS2CGMMessage", {msg = "没查到这个指令"})
    end
end

function CGMMgr:DoCommand(oMaster, sCmd, lCmdArgs)
    if not self:ValidUseCommand(oMaster, sCmd) then
        return
    end

    if sCmd == "help" then
        self:DoHelpCommand(oMaster, table.unpack(lCmdArgs))
        return
    end

    local oNotifyMgr = global.oNotifyMgr
    local mFile = self:GetGmFile()
    local bExecute = false

    for _, sFile in pairs(mFile) do
        local oFile = import(service_path(string.format("gm/%s", sFile)))
        local func = oFile.Commands[sCmd]

        if func then
            if is_production_env() and get_server_cluster() ~= "outertest" and not oFile.Opens[sCmd] then
                oNotifyMgr:Notify(oMaster:GetPid(), "该指令暂未开放")
                return
            else
                safe_call(func, oMaster, table.unpack(lCmdArgs))
                bExecute = true
                break
            end
        end
    end

    if not bExecute then
        oNotifyMgr:Notify(oMaster:GetPid(), string.format("指令%s执行失败", sCmd))
    else
        local mLog = {
            pid = oMaster:GetPid(),
            name = oMaster:GetName(),
            cmd = sCmd,
            arg = extend.Table.serialize(lCmdArgs)
        }
        record.user("gm", "gmop", mLog)
    end
end

function CGMMgr:ReceiveCmd(oMaster, sCmd)
    local mMatch = {}
    mMatch["{"] = "}"
    mMatch["\""] = "\""

    local iState = 1
    local iBegin = 1
    local iEnd = 0

    local sMatch = nil
    local iMatch = 0

    local lArgs = {}
    for i = 1, #sCmd do
        local c = index_string(sCmd, i)
        if iState == 1 then
            if c == " " then
                iEnd = i-1
                iState = 3
                if iEnd>=iBegin then
                    table.insert(lArgs, string.sub(sCmd, iBegin, iEnd))
                end
            elseif mMatch[c] then
                assert(false, string.format("ReceiveCmd fail %d %s %s", iState, c, mMatch[c]))
            end
        elseif iState == 2 then
            if iMatch <= 0 then
                if c == " " then
                    iEnd = i-1
                    iState = 3
                    if iEnd>=iBegin then
                        table.insert(lArgs, string.sub(sCmd, iBegin, iEnd))
                    end
                else
                    assert(false, string.format("ReceiveCmd fail %d %s %s", iState, c, mMatch[c]))
                end
            else
                if index_string(sCmd, i-1) == "\\" then
                    -- pass
                elseif c == mMatch[sMatch] then
                    iMatch = iMatch - 1
                elseif c == sMatch then
                    iMatch = iMatch + 1
                end
            end
        else
            -- 单词开始
            if mMatch[c] then
                iState = 2
                iBegin = i
                sMatch = c
                iMatch = 1
            elseif c ~= " " then
                iBegin = i
                iState = 1
            end
        end
    end

    if iState == 1 then
        iEnd = #sCmd
        if iEnd>=iBegin then
            table.insert(lArgs, string.sub(sCmd, iBegin, iEnd))
        end
    elseif iState == 2 then
        if iMatch <= 0 then
            iEnd = #sCmd
            if iEnd>=iBegin then
                table.insert(lArgs, string.sub(sCmd, iBegin, iEnd))
            end
        end
    end

    local sCommand = lArgs[1]
    local lCommandArgs = {}
    for k = 2, #lArgs do
        local v = lArgs[k]
        local ff, sErr = load(string.format("return %s", v), "", "bt", {})
        assert(ff, string.format("ReceiveCmd fail [%s] index:%d value:%s", sErr, k, v))
        local b, r = xpcall(ff, function ()
            -- ignore
        end)
        if not b or r == nil then
            r = v 
        end
        table.insert(lCommandArgs, r)
    end

    self:DoCommand(oMaster, sCommand, lCommandArgs)
end
