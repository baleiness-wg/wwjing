# Spec Delta

## Purpose

定义统一 Android 收藏客户端在不同编译模式下的可观察行为，使 kitchen 与 star 共享一套功能实现，同时保持数据空间、应用身份和模式专属入口清晰隔离。

## ADDED Requirements

### Requirement: 编译期应用模式选择

统一收藏客户端 MUST 通过编译期 `APP_TYPE` 选择 `kitchen` 或 `star` 模式，并 SHALL 使用所选模式对应的应用名称、Android 应用身份、收藏空间及原生链接通道；不支持的值 MUST 在启动前或启动时明确失败，不得静默使用另一模式。

#### Scenario: 构建 kitchen 模式

- **WHEN** 使用 `APP_TYPE=kitchen` 构建或运行统一客户端
- **THEN** 应用以 kitchen 身份运行并只读写 `cookie` 收藏空间

#### Scenario: 构建 star 模式

- **WHEN** 使用 `APP_TYPE=star` 构建或运行统一客户端
- **THEN** 应用以 star 身份运行并只读写 `star` 收藏空间

#### Scenario: APP_TYPE 不受支持

- **WHEN** 构建或启动时提供的 `APP_TYPE` 不是 `kitchen` 或 `star`
- **THEN** 系统给出明确配置错误且不以任一模式继续运行

### Requirement: 合并后保持共享收藏能力

两种模式 SHALL 提供合并前已有的登录、Android 系统分享、剪贴板识别、目录导航、收藏增删改查、搜索及链接打开能力；模式切换不得改变服务端已有收藏数据。

#### Scenario: kitchen 使用共享功能

- **WHEN** 用户以 kitchen 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `cookie` 空间

#### Scenario: star 使用共享功能

- **WHEN** 用户以 star 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `star` 空间

#### Scenario: 使用既有收藏数据

- **WHEN** 用户首次使用合并后的对应模式登录
- **THEN** 应用显示该账号在相应空间中已有的目录和收藏，无需复制或迁移条目

### Requirement: kitchen 随机推荐入口

kitchen 模式 SHALL 在收藏主页提供随机按钮；star 模式 MUST 不显示该按钮。用户触发随机操作时，客户端 SHALL 从当前认证用户的 `cookie` 空间请求一条随机收藏，并对加载、空结果及失败提供明确反馈。

#### Scenario: kitchen 请求随机收藏

- **WHEN** kitchen 用户点击随机按钮且 `cookie` 空间存在收藏
- **THEN** 客户端请求一条随机收藏并打开“今天吃什么”弹窗展示该条目

#### Scenario: cookie 空间没有收藏

- **WHEN** kitchen 用户点击随机按钮且随机接口返回空结果
- **THEN** 客户端提示暂无可推荐内容且不显示空白卡片

#### Scenario: 随机请求失败

- **WHEN** 随机接口因网络、认证或服务端错误失败
- **THEN** 客户端保留当前页面并显示可理解的失败提示

#### Scenario: star 不提供随机入口

- **WHEN** 用户以 star 模式打开收藏主页
- **THEN** 页面不显示随机按钮且不会请求随机菜谱接口

### Requirement: 低高度随机结果弹窗

随机结果 SHALL 在内容自适应且明显低于全屏的弹窗中显示，弹窗主体只包含标题区域和一个复用列表视觉样式的链接卡片；该卡片 MUST 不显示 checkbox、拖拽状态或编辑、移动、删除等操作按钮。

#### Scenario: 展示随机结果

- **WHEN** 随机接口返回一条收藏
- **THEN** 弹窗显示一个包含相同封面、标题和来源信息的精简收藏卡片，且不扩展为全屏页面

#### Scenario: 点击随机卡片

- **WHEN** 用户点击随机结果卡片
- **THEN** 客户端使用该收藏的已保存链接执行统一平台跳转

### Requirement: 已知平台定向跳转

Android 客户端 SHALL 对 Bilibili、小红书和抖音收藏使用平台对应 App 的定向跳转策略；已识别平台不得优先交给浏览器，目标 App 未安装或全部定向尝试失败时才可回退到系统外部链接处理。

#### Scenario: 打开 Bilibili 收藏

- **WHEN** 用户点击 Bilibili 完整链接或短链收藏
- **THEN** 客户端优先将 HTTPS 链接交给 Bilibili App，失败后尝试由内容标识构造的 Bilibili Deep Link，再失败则打开 Bilibili App 首页

#### Scenario: 打开小红书收藏

- **WHEN** 用户点击包含可识别笔记标识的完整小红书收藏链接
- **THEN** 客户端优先使用 `xhsdiscover://item/{ID}` 打开笔记，失败后将已保存的完整 HTTPS 链接交给小红书 App，最后才打开 App 首页

#### Scenario: 打开抖音收藏

- **WHEN** 用户点击可识别视频或图文数字标识的抖音收藏
- **THEN** 客户端优先使用 `snssdk1128://aweme/detail/{ID}`，无法识别或启动失败时打开抖音 App 首页

#### Scenario: 目标 App 未安装

- **WHEN** 已识别平台的目标 App 未安装或无法启动
- **THEN** 客户端尝试用系统外部应用处理原始 HTTP/HTTPS 链接，仍失败则保留当前页面并提示用户

### Requirement: 小红书短链保存前解析

客户端在保存 `xhslink.cn` 或 `xhslink.com` 短链前 MUST 请求元数据解析并以重定向后的完整小红书页面 URL 替换待保存链接；完整 URL SHALL 保留笔记路径及返回的查询参数，解析失败时 SHALL 阻止将未解析短链作为可直达内容保存并提示用户。

#### Scenario: 成功解析小红书短链

- **WHEN** 用户保存可重定向到小红书笔记页的短链
- **THEN** 客户端将元数据响应中的完整 `finalUrl` 写回表单并持久化该 URL，包括服务端返回的分享查询参数

#### Scenario: 小红书短链解析失败

- **WHEN** 用户保存小红书短链但无法取得有效完整笔记 URL
- **THEN** 客户端保留表单内容、阻止提交该短链并显示解析失败提示

#### Scenario: 保存完整小红书链接

- **WHEN** 用户输入的链接已是受支持的小红书完整笔记 URL
- **THEN** 客户端保留其笔记路径和查询参数并允许保存
