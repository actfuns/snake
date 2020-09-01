require("tableop")
--local login = require("common/task/login")
local login = require("common/login")
local scene = require("common/task/scene")
local taskhandler = require("common/task/taskhandler")
local item = require ("common/item")

if client then
    client.account = client.account or tostring(math.random(1, 9999999) + 10000000)
    local shield = client.shield
    shield.GS2CEnterAoi = true
    shield.GS2CLeaveAoi = true
    shield.GS2CPropChange = true
    shield.GS2CEnterScene = true
    shield.GS2CShowScene = true

    table_combine(client.server_request_handlers, login)
    table_combine(client.server_request_handlers, scene)
    table_combine(client.server_request_handlers, item)
    table_combine(client.server_request_handlers, taskhandler)
end
