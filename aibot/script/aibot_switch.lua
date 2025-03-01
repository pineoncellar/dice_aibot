-----------------------------------------------------------------------------------------------------
-- @name         aibot_switch
-- @author       地窖上的松
-- @license      by-nc-sa 4.0
-- @description  aibot插件开关模块，监听以.aibot为前缀的发言，实现插件开关与帮助信息发送
-----------------------------------------------------------------------------------------------------
json = require("json")

order = string.match(msg.suffix, "^[%s]*(.-)[%s]*$")

function read_json(path)                            --读json
    local json_t = nil
    local file = io.open(path, "r")                 --打开外置json
    if file ~= nil then
        json_t = json.decode(file.read(file, "*a")) --将json中的数组解码为table
        io.close(file)                              --关闭json
    end
    return json_t
end

-- 构造帮助信息
mainfest = read_json(getDiceDir() .. "/mod/aibot.json")

help_msg = ""
help_msg = string.format(
    "aibot插件 by %s ver %s on %s & BERT text classification server %s with classification model %s\n\n%s\n使用：\n",
    mainfest.author,
    mainfest.ver,
    mainfest.AI_model,
    mainfest.BERT_text_classification_server_ver,
    mainfest.classification_model_ver,
    mainfest.comment)

for _, v in ipairs(mainfest.order_list) do
    help_msg = help_msg .. string.format("%s\n", v)
end
help_msg = help_msg .. ">>" .. mainfest.brief
for _, v in ipairs(mainfest.remark_list) do
    help_msg = help_msg .. string.format("\n>>%s", v)
end

raw_msg = msg.fromMsg
if msg.gid then
    channel_type = "group"
    channel_id = msg.gid
else
    channel_type = "private"
    channel_id = msg.uid
end

function set_conf(channel_type, channel_id, key, value)
    if channel_type == "group" then
        setGroupConf(channel_id, key, value)
    elseif channel_type == "private" then
        setUserConf(channel_id, key, value)
    end
end

function get_conf(channel_type, channel_id, key, defualt_value)
    if channel_type == "group" then
        return getGroupConf(channel_id, key, defualt_value)
    elseif channel_type == "private" then
        return getUserConf(channel_id, key, defualt_value)
    end
end

if order == "help" then -- 开启ai回复
    return help_msg
end

-- 限定权限
if msg.grpAuth then -- 私聊没有grpAuth，直接认为有权限
    if msg.grpAuth >= 2 or getUserConf(msg.uid, "trust", 0) >= 4 then
    else
        return '请让群聊管理发送此指令x'
    end
end

if order == "on" then -- 开启ai回复
    aibot_enable = get_conf(channel_type, channel_id, "aibot_enable", true)
    if aibot_enable then
        return 'deepseek ai回复已经开启'
    else
        set_conf(channel_type, channel_id, "aibot_enable", true)
        return 'deepseek ai回复成功开启'
    end
elseif order == "off" then -- 关闭ai回复
    aibot_enable = get_conf(channel_type, channel_id, "aibot_enable", true)
    if aibot_enable then
        set_conf(channel_type, channel_id, "aibot_enable", false)
        return 'deepseek ai回复成功关闭'
    else
        return 'deepseek ai回复已经关闭'
    end
else
    return help_msg
end

return order
