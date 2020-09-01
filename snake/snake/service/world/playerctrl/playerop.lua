local res = require "base.res"

-- local _mRoleRace = {}
-- local function _InitRoleRaceLookup()
--     _mRoleRace = {}
--     local mRoleType = res["daobiao"]["roletype"]
--     for _, mInfo in pairs(mRoleType) do
--         local mSclInfo = table_get_set_depth(_mRoleRace, {mInfo.school})
--         mSclInfo[mInfo.sex] = mInfo.race
--     end
-- end

-- function ParseOutRoleType(iSchool, iSex)
--     local mRoleTypeQuery = res["daobiao"]["roletype_query"]
--     local iRoleType = table_get_depth(mRoleTypeQuery, {iSchool, iSex})
--     return iRoleType
-- end

function ParseOutRace(iRoleType)
    if not iRoleType then
        return nil
    end
    local mRoleTypes = res["daobiao"]["roletype"]
    local iRace = mRoleTypes[iRoleType]["race"]
    return iRace
end
