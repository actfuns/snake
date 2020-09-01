local res = require "data"
local tprint = require('extend').Table.print
local tserialize = require('extend').Table.serialize

local funcs = {}

function funcs.StartPos(robot)
    return 101
end

function funcs.EndPos(robot)
    return 100 + robot.m_iSize
end

function funcs.IsEquiped(robot)
    local lItemIDs = {}
    for id, info in pairs(robot.m_mItemIDs) do
        if info.pos < funcs.StartPos(robot) then
            return true
        end
    end
    return false
end

function funcs.GetItem(robot)
    if robot.m_iSize > robot.m_iItemCnt then
        robot:run_cmd("C2GSGMCmd", {cmd="clone 10028 1"})
    end
end

function funcs.UseItem(robot)
    for id, info in pairs(robot.m_mItemIDs) do
        if info.pos >= funcs.StartPos(robot) then
            if info.sid == 10028 then
                robot:run_cmd("C2GSItemUse", {itemid=id})
                break
            end
        end
    end
end

function funcs.ArrageItem(robot)
    robot:run_cmd("C2GSItemArrage", {})
end

function funcs.Equip(robot)
    for id, info in pairs(robot.m_mItemIDs) do
        if info.pos > funcs.StartPos(robot) then
            if info.sid > 21000 and info.sid < 23000 then
                robot:run_cmd("C2GSItemUse", {itemid=id, exarg="EQUIP:W"})
                break
            end
        end
    end
end

function funcs.UnEquip(robot)
    for id, info in pairs(robot.m_mItemIDs) do
        if info.pos < funcs.StartPos(robot) then
            robot:run_cmd("C2GSItemUse", {itemid=id, exarg="EQUIP:U"})
            break
        end
    end
end

local itemop = {}

itemop.GS2CLoginRole = function(self, args)
    self.m_iSex = args.role.sex
    self.m_iSchool = args.role.school
    self.m_iShape = args.role.model_info.shape
    for _, info in pairs(res["roletype"]) do
        if info.shape == self.m_iShape and table_in_list(info.school, self.m_iSchool) then
            self.m_iRace = info.race
            self.m_iRoleType = info.roletype
            break
        end
    end
    self:run_cmd("C2GSGMCmd", {cmd="choosemap"})
end

itemop.GS2CLoginItem = function(self, args)
    self.m_iSize = args.extsize + 50
    self.m_mItemIDs = {}
    self.m_mItemPos = {}
    self.m_iItemCnt = 0
    local lItems = args.itemdata
    for _, mInfo in ipairs(lItems) do
        self.m_mItemIDs[mInfo.id] = {
            id = mInfo.id,
            sid = mInfo.sid,
            amount = mInfo.amount,
            pos = mInfo.pos,
        }
        self.m_mItemPos[mInfo.pos] = self.m_mItemIDs[mInfo.id]
        self.m_iItemCnt = self.m_iItemCnt + 1
    end

    self:sleep(10)

    local lItems = {}
    local iCnt = 0
    local iEquipCnt = 0
    local iMaxCnt = 80
    local iMaxEquipCnt = 10
    for sid=21000, 23000 do
        local info = res["item"][sid]
        if info and info.equipLevel <= 40 then
            local bMatch = true
            if info.roletype ~= 0 then
                if info.roletype ~= self.m_iRoleType then
                    bMatch = false
                end
            else
                if info.sex ~= 0 and self.m_iSex ~= info.sex then
                    bMatch = false
                end
                if info.race ~= 0 and info.race ~= self.m_iRace then
                    bMatch = false
                end
            end
            if info.school ~= 0 and self.m_iSchool ~= info.school then
                bMatch = false
            end
            if bMatch then
                table.insert(lItems, {sid, 1})
                iEquipCnt =  iEquipCnt + 1
                if iEquipCnt > iMaxEquipCnt then
                    break
                end
            end
        end
    end
    for sid, info in pairs(res["item"]) do
        if sid > 21000 and sid < 23000 then
            goto continue
        elseif sid > 10000 then
            table.insert(lItems, {sid, info["maxOverlay"] or 1})
            iCnt = iCnt + 1
            if iCnt > iMaxCnt then
                break
            end
        end
        ::continue::
    end

    self:run_cmd("C2GSGMCmd", {cmd=string.format("init_item_robot %s", tserialize(lItems))})

    self:sleep(10)

    self:fork(function ()
        while true do
            self:sleep(math.random(3,6))
            local r = math.random(1, 100)
            if r <= 30 then
                funcs.GetItem(self)
            elseif r <= 50 then
                funcs.UseItem(self)
            elseif r <= 70 then
                funcs.Equip(self)
            elseif r <= 90 then
                funcs.UnEquip(self)
            else
                funcs.ArrageItem(self)
            end
        end
    end)
end

itemop.GS2CAddItem = function(self, args)
    local mInfo = args.itemdata
    self.m_mItemIDs[mInfo.id] = {
        id = mInfo.id,
        sid = mInfo.sid,
        amount = mInfo.amount,
        pos = mInfo.pos,
    }
    self.m_mItemPos[mInfo.pos] = self.m_mItemIDs[mInfo.id]
    self.m_iItemCnt = self.m_iItemCnt + 1
end

itemop.GS2CDelItem = function(self, args)
    local mInfo = self.m_mItemIDs[args.id]
    if not mInfo then
        return
    end
    self.m_mItemIDs[mInfo.id] = nil
    self.m_mItemPos[mInfo.pos] = nil
    self.m_iItemCnt = self.m_iItemCnt - 1
end

itemop.GS2CItemAmount = function(self, args)
    if not self.m_mItemIDs[args.id] then
        return
    end
    self.m_mItemIDs[args.id]["amount"] = args.amount
end

itemop.GS2CItemArrange = function(self, args)
    local lPosInfo = args.pos_info
    for _, mInfo in ipairs(lPosInfo) do
        local mOldInfo = self.m_mItemIDs[mInfo.itemid]
        if mOldInfo then
            self.m_mItemPos[mOldInfo.pos] = nil
            mOldInfo.pos = mInfo.pos
            self.m_mItemPos[mInfo.pos] = self.m_mItemIDs[mInfo.itemid]
        end
    end
end

itemop.GS2CItemExtendSize = function (self, args)
    self.m_iSize = args.extsize + 50
end

return itemop
