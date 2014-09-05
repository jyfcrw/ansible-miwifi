#!/usr/bin/env lua

local ubus = require "ubus"
local https = require "ssl.https"
local json = require "json"
local base = _G
local new_ip
local old_ip
local domain_id
local record_id
local base_opts

local host = "https://dnsapi.cn/"
local record_line = "默认" -- chinese: mo ren [default]

-- +++++ Please Modify Custom Parameters ++++++
local target_domain = "your domain name"
local target_record = "your choosen sub domain name"
local login_email = "your dnspod username"
local login_password = "your dnspod password"
-- ++++++++++++++++++++++++++++++++++++++++++++

function getNewIp()
    local conn = ubus.connect()
    local status = conn:call("network.interface.wan", "status", {})
    conn:close()
    local ip = unpack(status["ipv4-address"])["address"]
    return ip
end

function getDomain()
    function findDomainByName(i, d)
        if d["name"] == target_domain then
            return d
        end
    end
    local res, c, h, s = https.request("https://dnsapi.cn/Domain.List", base_opts)
    if c ~= 200 then
        return
    end
    local tres = json.decode(res)
    local scode = tres["status"]["code"]
    if base.tonumber(scode) ~= 1 then
        return
    end
    local domain = table.foreach(tres["domains"], findDomainByName);
    return domain
end

function getRecord()
    function findRecordByName(i, r)
        if r["name"] == target_record then
            return r
        end
    end
    local opts = string.format(base_opts.."&domain_id=%s&lang=en", domain_id)
    local res, c, h, s = https.request("https://dnsapi.cn/Record.List", opts)
    if c ~= 200 then
        return
    end
    local tres = json.decode(res)
    local scode = tres["status"]["code"]
    if base.tonumber(scode) ~= 1 then
        return
    end
    local record = table.foreach(tres["records"], findRecordByName);
    return record
end

function updateDns()
    local opts = string.format(base_opts.."&domain_id=%s&record_id=%s&sub_domain=%s&value=%s&record_line=%s", domain_id, record_id, target_record, new_ip, record_line)
    local res, c, h, s = https.request("https://dnsapi.cn/Record.Ddns", opts)
    if c ~= 200 then
        return
    end
    local tres = json.decode(res)
    local scode = tres["status"]["code"]
    if base.tonumber(scode) ~= 1 then
        print("*!* sorry, update dns failed.")
        return
    end
    print("*update successful.")
end

function showtable(t)
    for k, v in pairs(t) do
        print("" ..  k .. "= " .. tostring(v))
    end
    -- table.foreach(tres["status"], function(i, v) print (i, v) end);
end

function main()
    base_opts = string.format("login_email=%s&login_password=%s&format=json", login_email, login_password)
    new_ip = getNewIp()
    print("*get new ip address is " .. new_ip)

    local domain = getDomain()
    domain_id = domain["id"]
    print("*get \"" .. target_domain .. "\" domain id is " .. domain_id)

    local record = getRecord()
    record_id = record["id"]
    old_ip = record["value"]
    print("*get \"" .. target_record .. "\" record id is " .. record_id)
    print("*get old ip address is " .. old_ip)

    if not old_ip or old_ip == new_ip then
        print("*needn't to update. done.")
        return
    end

    updateDns()
    print("*done.")
end

main()
