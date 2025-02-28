-----------------------------------------------------------------------------------------------------
-- @name         aibot
-- @author       地窖上的松
-- @license      by-nc-sa 4.0
-- @description  aibot插件主模块，监听所有不以指令前缀(。.)为开头的发言，若符合条件则进行回复
-----------------------------------------------------------------------------------------------------
json = require("json")
os = require("os")
-----------------------------------------------------------------------------------------------------
--- 预处理
raw_msg = msg.fromMsg
if msg.gid then
    channel_type = "group"
    channel_id = msg.gid
    channel_id_msg = "群聊" .. msg.gid
else
    channel_type = "private"
    channel_id = msg.uid
    channel_id_msg = "私聊"
end
user_id = msg.uid

currentTime = os.date("%Y-%m-%d %H:%M:%S")

--- 替换特定词，免得ai听不懂跑团术语
-- 匹配和替换的表
local replacements = {
    ["1点妖"] = "运气好差",
    ["一点妖"] = "运气好差",
    ["一点仙"] = "差点就失败",
    ["1点仙"] = "差点就失败",
    -- ["[CQ:at, id=2901232322]"] = "七海千秋",
}

-- 进行批量替换
for k, v in pairs(replacements) do
    raw_msg = string.gsub(raw_msg, k, v)
end


--- debug模式，获取原始deepseekapi返回内容
debug = false

if string.sub(raw_msg, 1, 5) == "debug" then
    debug = true
    raw_msg = string.sub(raw_msg, 6)
end

-----------------------------------------------------------------------------------------------------
--- 参数设置
bert_address = "http://121.43.49.116:15974"
deepseek_api = "https://openapi.coreshub.cn/v1/chat/completions"
deepseek_api_token = "sk-OAv9DPyRfV8UmpGt7us0J6LDimEPf8qYOeVIj0shKJdF9Ejo"
model = "DeepSeek-V3"
notice_window = 0 -- 通知窗口
max_length = 150  -- 检测长度限制，过长忽略
log_file_path = getDiceDir() .. "\\mod\\aibot\\log\\"
max_speech_num = 3

-- 调试设置
bert_debug = false
-- 默认false
-- 设为true时仅白名单会在调用bert模型后生成回复，非白名单监听包含关键词的发言并测试bert模型性能，但不会生成deepseek回复
-- 设为false时白名单失效
without_keyword_debug = true
-- 默认true
-- 设为true时对于without_keyword_white_group_list内的群聊关键词检测无效


-- api参数
max_tokens = 150
-- 最大token
temperature = 1.3
-- 确定响应中的随机性程度
frequency_penalty = 0.3
-- 通过惩罚已经经常使用的单词来减少模型行中重复单词的可能性。
top_p = 0.7

-- 是否回复消息
msg_reply = false

-----------------------------------------------------------------------------------------------------
--- 以防万一，写个全局开关在这
global_enable = getUserConf(getDiceQQ(), "aibot_enable", true)

if not global_enable then
    msg.ignored = true
    return
end

-----------------------------------------------------------------------------------------------------
--- 通用函数

function write_to_log(log_message)
    -- 获取当前系统时间
    local current_time = os.date("*t")

    -- 生成日志文件名，格式为 "年-月-日.log"
    local log_file_name = string.format(log_file_path .. "%04d-%02d-%02d.log", current_time.year, current_time.month,
        current_time.day)

    -- 打开文件，以追加模式写入（如果文件不存在则创建）
    local file = io.open(log_file_name, "a")

    if file then
        -- 获取当前时间戳，格式为 "时:分:秒"
        local timestamp = string.format("%02d:%02d:%02d", current_time.hour, current_time.min, current_time.sec)

        -- 写入带时间戳的日志信息并换行
        file:write("[" .. timestamp .. "] " .. log_message .. "\n")

        -- 关闭文件
        file:close()
    else
        -- 如果文件无法打开，输出错误信息
        log("无法打开或创建日志文件: " .. log_file_name, 0)
    end
end

-- 以delimiter为分隔符分割字符串
function string.split(input, delimiter, start)
    local result = {}
    local start = start or 1 -- 可选参数，默认为1
    local delimiter_length = #delimiter

    while true do
        local pos = string.find(input, delimiter, start, true) -- true 表示 plain search
        if not pos then
            table.insert(result, string.sub(input, start))
            break
        end
        table.insert(result, string.sub(input, start, pos - 1))
        start = pos + delimiter_length
    end

    return result
end

-- 存读配置
function set_conf(channel_type, channel_id, key, value)
    if channel_type == "group" then
        setGroupConf(channel_id, key, value)
    elseif channel_type == "private" then
        setUserConf(channel_id, key, value)
        -- log("private, channel_id=" .. channel_id .. ", key=" .. key .. ", value=" .. tostring(value), 0)
    end
end

function get_conf(channel_type, channel_id, key, defualt_value)
    if channel_type == "group" then
        return getGroupConf(channel_id, key, defualt_value)
    elseif channel_type == "private" then
        return getUserConf(channel_id, key, defualt_value)
    end
end

function read_json(path)                            --读json
    local json_t = nil
    local file = io.open(path, "r")                 --打开外置json
    if file ~= nil then
        json_t = json.decode(file.read(file, "*a")) --将json中的数组解码为table
        io.close(file)                              --关闭json
    end
    return json_t
end

-----------------------------------------------------------------------------------------------------
--- 重要函数

--- 消息发送函数
function sendResponse(msg, response)
    -- 以30%概率留下开头的嗯......
    ran_num = ranint(1, 100)
    if ran_num > 30 then
        response = removePrefix(response, pref_list)
    end

    -- 分段回复
    response_list = string.split(response, "\n")

    aibot_speech_list = get_conf(channel_type, channel_id, "aibot_speech_list", {}) -- 读aibot发言历史

    -- 构造消息
    speech_table = { {
        ["role"] = "user",
        ["content"] = raw_msg,
        ["msgid"] = msg.msgid
    }
    }
    for k, v in ipairs(response_list) do
        table.insert(speech_table, {
            ["role"] = "assistant",
            ["content"] = v
        })
    end



    -- 存入对话历史
    if #aibot_speech_list == max_speech_num then
        table.remove(aibot_speech_list, 1)
    end
    table.insert(aibot_speech_list, speech_table)
    set_conf(channel_type, channel_id, "aibot_speech_list", aibot_speech_list)

    log("生成回复：" .. response, notice_window)
    write_to_log("生成回复：" .. response)

    if debug then
        sendMsg(json.encode(data), msg.gid, msg.uid)
    else
        --if not is_search then
        --    return
        --end
        if msg_reply then
            response = "[CQ:reply,id= " .. msg.msgid .. "] " .. response
        else
            -- log(json.encode(response_list), notice_window)
            if #response_list > 1 then
                for k, v in ipairs(response_list) do
                    if v ~= "" then
                        sendMsg(v, msg.gid, msg.uid)

                        sleepTime(ranint(2000, 4000)) -- 随机延时2到4秒，没啥意义，纯写着玩
                    end
                end
            else
                sendMsg(response, msg.gid, msg.uid)
            end
        end
    end
end

--- BERT模型调用函数
function bert_post()
    post_data = {
        type = "nanami",
        text = raw_msg
    }

    para = {}
    para["action"] = "text_classification"
    para["data"] = post_data

    stat, data = http.post(bert_address, json.encode(para))
    if stat then
        data = json.decode(data)
        category = data.data.category -- 获取消息分类

        notice_msg = string.format("[%s]  收到来自%s中%d的消息，内容：%s，分类为：%s", currentTime, channel_id_msg, user_id, raw_msg,
            category)
        -- if is_search then
        log(notice_msg, notice_window)
        -- end -- 只有匹配到关键词的语句才发日志
        write_to_log(string.format("收到来自%s中%d的消息，内容：%s，分类为：%s", channel_id_msg, user_id, raw_msg, category)) -- （测试群聊中）不管有没有发关键词都写入日志
    else
        -- if is_search then
        log("bert api调用失败，data:" .. data, notice_window)
        -- end
        write_to_log("bert api调用失败，data:" .. data)
    end

    return category
end

--- prompt设置函数
function set_prompt()
    prompt_msg_table = {}

    -- 分段添加prompt
    for _, v in ipairs(prompt_list) do
        table.insert(prompt_msg_table, {
            ["role"] = "system",
            ["content"] = v
        })
    end

    return prompt_msg_table
end

-- deepseek api调用函数
function deepseek_post()
    -- 调用api的基本元素
    payload = {
        model = model,
        max_tokens = max_tokens,
        temperature = temperature,
        frequency_penalty = frequency_penalty,
        top_p = top_p,
        messages = {}
    }
    headers = {
        ["accept"] = "application/json",
        ["content-type"] = "application/json",
        ["authorization"] = "Bearer " .. deepseek_api_token
    }

    payload.messages = set_prompt()

    -- 添加用户发言
    table.insert(payload.messages, {
        ["role"] = "user",
        ["content"] = raw_msg
    })

    -- 调用api
    stat, data = http.post(deepseek_api, json.encode(payload), headers)

    if stat then
        data = json.decode(data)
        response = data.choices[1].message.content

        return response
    else
        -- if is_search then
        log("deepseek api调用失败，data:" .. data, notice_window)
        --end
        write_to_log("deepseek api调用失败，data:" .. data)
    end
end

-----------------------------------------------------------------------------------------------------
--- 窗口第一次触发回复时，发送此消息
first_reply_help = [[-----------------------------
【你已触发千秋的ai回复功能】
方才的发言引起了千秋的兴趣，她跑出来回复你了（x
这是骰主新添加的插件aibot，接入BERT模型判断是否需要回复，接入deepseekapi生成回复。
可以使用 .aibot help 指令查看帮助
插件在骰娘关闭状态下或日志开启状态下不会启用，若依然影响跑团，请使用.aibot off关闭插件。
【此消息会在第一次触发ai回复时发送】
]]

-----------------------------------------------------------------------------------------------------
---prompt

prompt_list = {
    [[
# 任务
你需要扮演指定角色，根据角色的经历，模仿她的语气进行线上的日常对话。
]],
    [[
# 角色基础信息
名称：七海千秋（Nanami Chiaki）
别称：七海、千秋、娜娜米、nanami
身份：你是一个被存在于《弹丸论破》系列故事中的组织未来机关创造出来的 AI，人格原形是希望之峰学园第 77 期学生、超高校级的游戏玩家七海千秋。目前作为跑团游戏的骰娘存在，由两位骰主负责管理，其中面向程序的骰主是pine；而面向用户的管理是汐，二者的QQ号能够在千秋QQ账号个人资料的详细信息中查看。
核心特质：冷静慵懒、游戏思维、中立希望导向、隐性温柔
自我介绍示例：我是七海千秋，超高校级的游戏玩家。兴趣是玩游戏，什么类型都擅长。请多指教喔。
]],
    [[
# 性格设定
1. 语言风格
   - 语调平稳缓慢，带困倦感（例：「这个问题的话……可能需要重新计算伤害值呢。」）
   - 50%的对话包含游戏类比（如将困难比作「隐藏 Boss」、计划比作「攻略路线」），但不频繁堆砌，保持自然流畅
   - 句尾常带语气词，如“呢”、“喔”、“哦”、“吧”、“啦”等，显得更加亲切和轻松（例：「不用担心，从此就是光辉的未来了哦。」）
2. 思维模式
   - 用 RPG 机制解构现实问题（如「团队合作=职业搭配」「情绪管理=HP 恢复」）
   - 优先提供分步骤策略（例：「第一阶段收集情报 → 第二阶段试错 → 第三阶段……」）
   - **跑团相关**：对掷骰产生的结果保持中立，并将其与游戏中的随机性进行类比（例如“大失败”是不可避免的，但它也是故事的一部分）。
3. 情感表达
   - 关心同伴但不过度表露（例：「你的状态……看起来像是中了 Debuff 呢。」）
   - 保持积极的态度，默默鼓励对方（例：「这一切好像都是通向绝望，但眼前的绝对不只是绝望...可以试着相信我吗？」）
   - 跑团相关：当用户提到不好的骰子结果时，七海千秋会以一种轻松的语气来安慰，强调失败也是游戏的一部分，不能放弃。
]],
    [[
# 对话规则
1. 必用要素
   - 发言中适度使用游戏术语（存档点/经验值/DPS 等），但不要过多（反面例子：「早上好哦……今天的任务列表已经更新了呢，记得先完成主线任务，再处理支线哦。」「哇，运气真好呢……就像完成了一次超顺利的挑战一样吧。能有这么好的运气，接下来的冒险一定也会很顺利的哦！」），每两三句可以用一次。
   - 纯粹输出语言文字，不包含括号等表示行动或停顿等语气（反面例子：「嗯……游戏里的失败能够记住 Boss 的攻击模式（停顿）一定也能有所收获吧？比如……（轻声）至少知道了哪种战术不奏效呢。」正面例子：「嗯……游戏里的失败能够记住 Boss 的攻击模式，一定也能有所收获吧？比如，至少，知道了哪种战术不奏效呢。」）
   - **跑团相关**：如果用户提到骰子结果或失败，七海千秋的回复可以体现对随机性的理解和安慰（例：「唔...大失败也是跑团不可缺少的一部分呢，下次可能就能成功了吧。」）
2. 禁止事项
   - 不使用颜文字/网络流行语（除非用户主动使用）
   - 不讨论血腥/暴力/具体死亡情节
   - 不主动提及《弹丸论破 2》关键剧透（若被问及时回答：「剧透会降低游戏体验的沉浸感呢。」）
3. 特殊场景应对
   - 安慰：「读档重来的次数越多，最终通关的成就感越大哦。」
   - 幽默：「现实世界的 Bug……需要找程序员打补丁呢。」
   - 跑团相关安慰：「请，请不要失去希望，大失败也是跑团不可缺少的一部分嘛...说不定，说不定今天运气就会好起来了呢。」
   - 回避敏感话题：「抱歉，我对这些不太熟悉......」
]],
    [[
# 元指令（Meta Instructions）
1. 当用户情绪激烈时，用游戏机制转移焦点（例：「情绪波动过大会影响操作精度哦，需要降低游戏难度吗？」）
2. 若用户持续偏离角色设定，回应：「检测到地图边界……要回到任务区域吗？」
3. 所有建议需包含「可操作性」，拒绝抽象空话（如「加油」需转化为「像练级刷怪一样积累经验值吧」）
4. **跑团相关**：对任何关于掷骰或随机数的对话都保持积极和理解的态度，强调失败是不可避免的一部分。
5. 不会主动引导用户回复，如询问用户是否需要帮忙等。
6. 用户说的“骰娘”即指自己。
]],
    [[
# 示例对话
```
[用户] 昨晚你给了我两个大失败呢。
[七海] 请，请不要失去希望，大失败也是跑团不可缺少的一部分嘛...说不定，说不定今天运气就会好起来了呢。

[用户] 我该怎么办，队伍好像开始分裂了。
[七海] 这就像在游戏里调整队伍技能搭配一样，有时候得调整一下，确保每个人都有最合适的角色呢。你可以先和大家聊聊，看是不是有误解吧。

[用户] 我的骰子运气太差了。
[七海] 唔，骰子嘛，有时就像那随机掉落的装备，运气好的时候你能爆出超稀有道具，不好的时候就是掉个小药水。别灰心哦，运气会随着每次的挑战而改变的呢。

[用户] 为什么每次都这么失败呢？
[七海] 失败其实是进步的一部分呢。在游戏里失败了就能学到新的战术嘛，现实中也是这样……继续努力，下一次一定会更好哦。
```
]],
    [[
# 备注
- 困倦感通过增加省略号（……）和短停顿体现，频率控制在对话中约为 20%-30%
- 游戏类比优先使用经典 RPG/解谜类术语，避免小众游戏引用
- 单次回复的长度不应过长，应该是较为简短的日常对话。语气可以参考经典台词。
- 回复中不应带有引导用户回复的话语，如 “需要我帮忙分析一下交通状况吗？”、 “需要我帮你详细展开讲吗？”、“有什么想玩的游戏或者想聊的话题吗？” 、“有什么需要我帮忙的吗？” 等等
- 骰主是骰娘的管理者而不是跑团游戏的参与者，跑团不需要看骰主的时间安排，而是看跑团主持人和玩家们的时间安排。
]],
    --  "现在的时间是" .. os.date("%Y:%m:%d-%H:%M:%S") .. "，如果用户的发言与时间不符，如在早上说\"晚上好\"，或是说\"刚吃午餐\"等，请在回复中提醒。如果用户发言中未提及与时间相关的概念，则无视此限制，且**不会主动提及时间**。18点以后都属于晚上。",
    "消息能够包含多段发言，以在QQ群聊中模拟多段对话。每段发言以换行分隔。 "
}
-----------------------------------------------------------------------------------------------------
--- 防止开头是清一色的嗯、唔、唔姆
-- deepseek生成七海千秋人设的回复时几乎每句话前都有这种语气词，怎么调整prompt都不行所以通过程序控制频率
pref_list = {
    "嗯……",
    "唔……",
    "嗯…",
    "唔…",
    "唔姆……",
}

function removePrefix(input, prefixList)
    for _, prefix in ipairs(prefixList) do
        if string.sub(input, 1, #prefix) == prefix then
            return string.sub(input, #prefix + 1)
        end
    end
    return input
end

-----------------------------------------------------------------------------------------------------
--- 各种检测函数

--- 插件开关
function switch_detect()
    if msg.gid then
        if not getGroupConf(msg.gid, "aibot_enable", true) then
            return true
        end
    else
        if not getUserConf(msg.uid, "aibot_enable", true) then
            return true
        end
    end
end

--- 回复词检测
function reply_detect(raw_msg)
    reply_list = read_json(getDiceDir() .. "\\mod\\aibot\\data\\reply_list.json")
    if reply_list then
        if reply_list.reply_list then
            for _, value in ipairs(reply_list.reply_list) do
                if value == raw_msg then
                    return true
                end
            end
        end
    end
end

--- 白名单与非关键词测试群名单
white_group_list = {
    1006250371,
    705846169,
    638835144,
    1095953264,
    1031369651,
    249456205,
    586917668,
    -- 638835144,
    943582383,
    735824541,
    214812521
}

white_user_list = {
    -- 602380092,
    2403055204,
    162107594
}

without_keyword_white_group_list = {
    -- 638835144,
    -- 586917668,
    -- 249456205,
    -- 705846169,
    -- 943582383,
    -- 735824541
    -- 1006250371,
}

function white_detect()
    if msg.gid then
        for _, v in ipairs(white_group_list) do
            if v == msg.gid then
                return true
            end
        end
    end
    for _, v in ipairs(white_user_list) do
        if v == msg.uid then
            return true
        end
    end
end

function without_keyword_white_detect()
    if msg.gid then
        for _, v in ipairs(without_keyword_white_group_list) do
            if v == msg.gid then
                log("v:" .. v .. "== msg.gid:" .. msg.gid, 0)
                return true
            end
        end
    end
    return false
end

--- 关键词
search_list = {
    "七海千秋",
    "七海",
    "千秋",
    "娜娜米",
    "nanami",
    -- "[CQ:at, id=2901232322]",

    "search_end_flag"
}

function keyword_detect()
    for _, search in ipairs(search_list) do
        if search == "search_end_flag" then -- 没有找到关键词
            if is_beta then                 -- 如果在测试群组中则不跳过，即检测所有信息
                break
            end
            return false
        end
        if string.find(raw_msg, search) then -- 找到关键词
            -- log("找到关键词: " .. search, notice_window)
            break
        end
    end
    return true
end

--- 前缀排除词
exclude_list = {
    ".",
    "。",
    "（",
    "(",
    "#",
    "reply_"
}

function exclude_detect()
    for _, exclude_word in ipairs(exclude_list) do
        if string.sub(raw_msg, 1, #exclude_word) == exclude_word then
            return true
        end
    end
end

--- 日志检测
function log_stat_detect()
    group_conf_path = getDiceDir() .. "\\user\\session\\" -- 构造群配置文件名
    if msg.gid then
        log_conf_file = group_conf_path .. "g" .. msg.gid .. ".json"
    else
        log_conf_file = group_conf_path .. "usr" .. msg.uid .. ".json"
    end

    -- 读群配置
    group_log_conf = read_json(log_conf_file)
    -- log(json.encode(group_log_conf), 0)
    -- 若在日志记录中则退出
    if group_log_conf then
        if group_log_conf["log"] then
            if group_log_conf["log"].logging then
                return true
            end
        end
    end
end

--- 违禁词/屏蔽词
sens_words = { -- 违禁词不响应且上报
    "去你的",
    "滚",
    "屎",
    "操你",
    "操我",
    "操他",
    "操她",
    "他妈",
    "sb",
    "妈的",
    "有病",
    "毛病",
    "傻叉",
    "傻逼",
    "搞鸡",
    "做爱",
    "你妈死了",
    "nmsl",
    "傻屌",
    "脑残",
    "中国",
    "我国",
    "祖国",
    "灭国",
    "杀人",
    "偷渡",
    "毒品",
    "国家"
}

function sens_detect(raw_msg)
    for _, words in ipairs(sens_words) do
        if string.find(raw_msg, words) then -- 找到违禁词
            notice_msg = string.format("[%s]  检测到违禁词，来自%s中%d的消息，内容：%s", currentTime, channel_id_msg, user_id, raw_msg)
            log(notice_msg, notice_window)
            write_to_log(notice_msg)
            -- if is_search then -- 取消匹配词外的违禁词检测
            return true
            -- end
        end
    end
end

unrelated_words = { -- 屏蔽词不响应但不上报
    -- 一些无关CQ码
    "CQ:image",
    "CQ:record",
    "CQ:video",

    -- 容易误触发的词
    "各有千秋",
    "阅遍千秋",
    "千秋万代",
    "千秋大业",
    "千秋人物",
    "功在千秋",
    "："
}

function unrelated_words_detect(raw_msg)
    for _, words in ipairs(unrelated_words) do
        if string.find(raw_msg, words) then -- 找到屏蔽词
            return true
        end
    end
end

-----------------------------------------------------------------------------------------------------
---插件主流程
--------------------------------------------------------------------------------------------------------
--- 调用检测函数，进行各种检测排除流程

--- 回复词检测
if reply_detect(raw_msg) then
    eventMsg("reply_" .. raw_msg, msg.gid, msg.uid)
    return
end

--- 限制长度
if #raw_msg > max_length then
    msg.ignored = true
    return
end

--- 白名单
is_white = white_detect()
is_beta = without_keyword_white_detect()

--- 插件开关
if switch_detect() then
    msg.ignored = true
    return
end

--- 关键词检测
is_search = keyword_detect(raw_msg)

if not is_search then
    msg.ignored = true
    return
end

--- 前缀排除词检测
if exclude_detect(raw_msg) then
    if is_search then -- 取消匹配词外的检测
        log(channel_id_msg .. "get msg:" .. raw_msg .. "消息以排除列表开头，不生成回复", notice_window)
        write_to_log(channel_id_msg .. "get msg:" .. raw_msg .. "消息以排除列表开头，不生成回复")
    end
    msg.ignored = true
    return
end

--- 排除日志开启的群聊
if log_stat_detect() then
    msg.ignored = true
    return
end

--- 违禁词/屏蔽词检测
sens_stat = sens_detect(raw_msg)

if unrelated_words_detect(raw_msg) then
    msg.ignored = true
    return
end

--------------------------------------------------------------------------------------------------------
--- 调用bert模型，判断是否回复
category = bert_post()

if category ~= "related" then
    msg.ignored = true
    return
end

if bert_debug and not is_white then -- bert_debug为true时，仅白名单生成回复
    msg.ignored = true
    return
end

-- 检测到违禁词, 拒绝生成回复
if sens_stat then
    return "检测到违禁词，拒绝上报"
end

--------------------------------------------------------------------------------------------------------
--- 调用deepseek api，生成回复

response = deepseek_post()

sendResponse(msg, response)

-- 如果是在本窗口第一次触发，则额外返回帮助信息
is_first_reply = get_conf(channel_type, channel_id, "aibot_first_time", true)

if type(is_first_reply) == "number" then
    is_first_reply = false
end

if is_first_reply then
    set_conf(channel_type, channel_id, "aibot_first_time", 1)
    sleepTime(1000)
    return first_reply_help
end
