> 使用《署名—非商业性使用—相同方式共享 4.0 协议国际版》（CC BY-NC-SA 4.0）进行授权。
> https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-Hans

---

# 一. 基本信息

> - **作者：** 地窖上的松
> - **联系方式：**QQ: 602380092
> - **文件版本：**v1.3.0
> - **更新日期：**2025/2/28
> - **关键词：**`bert` `deepseek`

---

# 二. 介绍

相关帖：[【抛砖引玉】如何给骰娘完整的一生](https://forum.kokona.tech/d/2160-pao-zhuan-yin-yu-ru-he-gei-tou-niang-wan-zheng-de-yi-sheng)

接入 BERT 模型判断是否回复，接入 deepseekapi 生成回复。

插件分不同模块，可以随需求修改`reply/reply.lua`以实现模块的增删。

部分模块配置使用有一定门槛，建议有修改 lua 与 python 代码的能力。

不懂的也可以直接问我 ~~有空的话会回的~~

插件代码仓库[在此](https://github.com/pineoncellar/dice_aibot)

效果展示：

（图）

（图）

---

# 三.模块介绍与使用方法

只要把`reply/reply.lua`中对应模块的触发配置直接删去就能够关掉对应模块了

（图）

## 早晚安模块

对应触发配置

```lua
msg_reply.aibot_good_mn = {
    keyword = {
        Match = {
            "早安",
            "早",
            "早上好",
            "晚安",
            "晚安安",
            "晚上好",
            "下午好",
            "中午好",
            "上午好",
            "午安"
        }
    },
    type = "order",
    limit = {
        cd = 180,
    },
    echo = {
        lua = "aibot_good_mn"
    }
}
```

此模块监听设置的道安消息，记录此时时间，直接调用 deepseekapi 生成回复。

> 其实就是 deepseekapi 版的分时段回复，心血来潮加上的

需要配置：

- deepseek api key

- 符合骰娘人设的 prompt

## 开关模块

对应触发配置

```lua
msg_reply.aibot_switch = {
    keyword = {
        Prefix = {
            ".aibot"
        }
    },
    type = "order",
    echo = {
        lua = "aibot_switch"
    }
}
```

此模块控制除早晚安模块之外模块的开关，同时可以发送帮助信息

## **aibot 主模块**

对应触发配置

```lua
msg_reply.aibot0 = {
    keyword = {
        Regex = {
            "^[^%.。r](.*)" -- 匹配所有不以指令前缀开头的消息
        }
    },

    type = "order",
    limit = {},
    echo = {
        lua = "aibot"
    }
}
```

主模块监听所有不以指令开头或字母`r`的消息，所以会使所有`type = reply`的回复词失效，解决方法见第 x 节

主模块监听消息，以经过检测的消息调用 BERT 模型判断是否回复，若是则调用 deepseekapi 生成回复。

将排除以下类型的消息：

- 插件关闭状态群聊的消息

- 全词匹配设定的回复词的

- 以设定的前缀为开头的消息

- 开启了日志记录的群聊消息

- 包含违禁词与屏蔽词的消息

> 一层层检测都是为了不影响跑团和插件安全写的（

启用此模块比较麻烦，需要配置：

- deepseek api key

- 符合骰娘人设的 prompt

- **训练一个适合自己骰娘的 BERT 模型并部署推理服务**

- 调整一下关键词列表、无关词列表

- 如果有需要，调整一下其他的列表如白名单列表

## aibot reply 模块

对应触发配置

```lua
msg_reply.aibot_reply = {
    keyword = {
        Prefix = {
            "[CQ:reply,id=" -- 匹配所有回复消息
        }
    },
    type = "order",
    limit = {},
    echo = {
        lua = "aibot_reply"
    }
}
```

此模块可以实现用户回复 aibot 生成的发言时，可以保持记忆继续聊天。

模块监听所有回复消息

> 暂时想不到什么好的记忆上下文方法，所以姑且先写了这个模块

比起主模块需要多配置一个骰子框架 http 端口。

# 四. 训练自己的 BERT 模型

训练过程见[此博客](https://pineoncellar.cn/2025/02/27/%E5%9F%BA%E4%BA%8Ebert%E7%9A%84%E7%BE%A4%E8%81%8A%E6%B6%88%E6%81%AF%E5%88%86%E7%B1%BB%E6%A8%A1%E5%9E%8B%E8%AE%AD%E7%BB%83/)

数据集可以参考 github 中的。

# 五. 获取 deepseek api key

推荐 coreshub，现在注册送 50 元额度

大模型服务 - API 密钥管理 - 创建 API 密钥 即可

随后将插件中的 `deepseek_api_token` 配置项修改为自己的 token

如果用其他平台的 api，还需要修改`deepseek_api`和`model`

# 六. 写一份适合自己骰娘的 prompt

可以让 deepseek 帮忙写

（图片）

然后根据自己需求改改就好。

prompt 建议分段加入`prompt_list`中，代码中的`prompt_list`即为例子

# 七. 测试建议

建议先将`bert_debug`设为 true，如此，骰娘会先监听包含关键词的消息调用 BERT 模型，但只有白名单中的群聊或用户私聊才会生成回复，可以以此来测试 BERT 模型效果。
