package.path = package.path --.. ";../?.lua;"
package.cpath = package.cpath .. ";./build/clualib/?.so"
local json = require "cjson"
local task_topology = require("shell/maintain/utils/task_topology")

local sGamedataPath = ...
-- local sTaskGroup = ...
local sTaskGroup = "story"
if not sGamedataPath then
    sGamedataPath = "daobiao/gamedata/server/data"
end

local oTopology = task_topology.NewTaskTopology()
if not oTopology:Init(sGamedataPath, sTaskGroup) then
    os.exit(1)
end
local mTaskRiver = oTopology:TaskTopology()
local mAllPieces = oTopology:WalkOutPiecesList(mTaskRiver)

local jTasks = json.encode({
    task = mTaskRiver,
    pieces = mAllPieces,
})

local sMiddleFilePath = "maintain/datafile/"
local sMiddleFileName = "task_pieces_data.json"
os.execute("mkdir -p " .. sMiddleFilePath)
local f = io.open(sMiddleFilePath .. sMiddleFileName, "wb")
f:write(jTasks)
f:close()

print("middle file at: " .. sMiddleFilePath .. sMiddleFileName)
