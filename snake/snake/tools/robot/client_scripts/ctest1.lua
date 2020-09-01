require("tableop")
local login = require("common/login")
local ride = require("common/ride")
local scene = require("common/scene")
local chat = require("common/chat")
local wing = require("common/wing")
local summon = require("common/summon")
local equip = require("common/equip")

if client then
    client.account = client.account or tostring(math.random(1, 9999999) + 10000000)
    table_combine(client.server_request_handlers, login)
    table_combine(client.server_request_handlers, ride)
    table_combine(client.server_request_handlers, scene)
    table_combine(client.server_request_handlers, wing)
    table_combine(client.server_request_handlers, summon)
    table_combine(client.server_request_handlers, chat)
    table_combine(client.server_request_handlers, equip)
end
