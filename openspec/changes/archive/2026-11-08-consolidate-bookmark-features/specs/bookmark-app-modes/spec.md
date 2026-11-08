# Spec Delta

## MODIFIED Requirements

### Requirement: 合并后保持共享收藏能力

两种模式 SHALL 提供登录、Android 系统分享、剪贴板识别、目录导航、收藏增删改查、搜索、图片展示及链接打开能力；模式切换不得改变服务端已有收藏数据。

#### Scenario: 编辑中收到剪贴板新链接

- **WHEN** 用户正在新增或编辑收藏，应用从其他 App 返回并检测到新的剪贴板链接
- **THEN** 应用弹出切换确认框，确认后才替换当前草稿，取消则保留当前输入

#### Scenario: 当前目录新增收藏

- **WHEN** 用户在某个目录中点击新增收藏或从该目录接收分享链接
- **THEN** 新草稿默认选中当前目录

#### Scenario: kitchen 使用共享功能

- **WHEN** 用户以 kitchen 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `cookie` 空间

#### Scenario: star 使用共享功能

- **WHEN** 用户以 star 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `star` 空间

#### Scenario: 使用既有收藏数据

- **WHEN** 用户首次使用合并后的对应模式登录
- **THEN** 应用显示该账号在相应空间中已有的目录和收藏，无需复制或迁移条目

### Requirement: 已知平台定向跳转

Android 客户端 SHALL 对 Bilibili、小红书和抖音收藏优先尝试对应 App 的 HTTPS、Deep Link 或 App 首页跳转；所有定向方式失败后才回退系统外部链接。

#### Scenario: 打开小红书短链已解析收藏

- **WHEN** 收藏的 URL 是已解析的完整小红书笔记 URL
- **THEN** 客户端使用 `xhsdiscover://item/{ID}` 或视频 Deep Link 打开对应内容，不直接优先打开浏览器

#### Scenario: 打开 Bilibili 收藏

- **WHEN** 用户点击 Bilibili 完整链接或短链收藏
- **THEN** 客户端优先将 HTTPS 链接交给 Bilibili App，失败后尝试内容 Deep Link，再失败则打开 Bilibili App 首页

#### Scenario: 打开小红书收藏

- **WHEN** 用户点击包含可识别笔记标识的完整小红书收藏链接
- **THEN** 客户端优先使用 `xhsdiscover://item/{ID}` 打开笔记，失败后将完整 HTTPS 链接交给小红书 App，最后才打开 App 首页

#### Scenario: 打开抖音收藏

- **WHEN** 用户点击可识别视频或图文数字标识的抖音收藏
- **THEN** 客户端优先使用抖音 Deep Link，无法识别或启动失败时打开抖音 App 首页

#### Scenario: 目标 App 未安装

- **WHEN** 已识别平台的目标 App 未安装或无法启动
- **THEN** 客户端尝试用系统外部应用处理原始 HTTP/HTTPS 链接，仍失败则保留当前页面并提示用户

### Requirement: 表单智能自动识别元数据

移动端收藏表单 SHALL 在有效链接被分享、粘贴或打开时自动异步识别标题、描述和封面；识别结果 SHALL 写入 `images` 数组并在保存后异步持久化。

#### Scenario: 点击粘贴后自动识别

- **WHEN** 用户在收藏表单粘贴有效链接
- **THEN** 客户端自动调用平台专用或通用元数据解析，并回填标题、描述和图片 URL

#### Scenario: 小红书 Logo 替换

- **WHEN** 小红书页面的 `og:image` 是平台 Logo 且页面或脚本中存在真实 CDN 图片
- **THEN** 服务端过滤 Logo 并返回真实 `sns-webpic` 或 `sns-img` 图片 URL

#### Scenario: 抖音短链客户端解析

- **WHEN** 用户输入或粘贴 `v.douyin.com` 短链
- **THEN** 客户端优先在本地跟随重定向并请求抖音详情接口提取原始高清封面直链与标题，回填至表单

#### Scenario: 保存时完整持久化封面

- **WHEN** 客户端表单已填充或识别出封面 URL 并点击保存
- **THEN** 客户端将图片数组提交至后端并持久化

#### Scenario: 保存时图片数组持久化

- **WHEN** 客户端表单已填充或识别出封面 URL 并点击保存
- **THEN** 客户端将图片数组提交至后端并持久化

## ADDED Requirements

### Requirement: 收藏条目内容模型

收藏条目 SHALL 要求标题非空，描述和 URL 可空；URL 非空时保存规范化 URL、来源主机并参与重复判断，URL 为空时不参与重复判断。图片使用有序 `images` URL 数组，旧单图数据 SHALL 迁移为首项。

#### Scenario: 保存无 URL 收藏

- **WHEN** 用户提供标题、描述或图片但不提供 URL
- **THEN** 服务端允许保存，URL 相关字段为空且不执行重复 URL 判断

#### Scenario: 保存多图收藏

- **WHEN** 客户端提交图片 URL 数组
- **THEN** 服务端以 JSON 数组保存并在列表接口返回该数组

### Requirement: 目录内容按递归归属展示

用户进入某个收藏目录时，客户端 SHALL 展示直接归属于该目录及其所有后代目录的收藏视频；主页不再混排子目录卡片，目录切换仅由左侧目录导航完成。

#### Scenario: 打开父目录

- **WHEN** 用户从左侧目录导航进入包含子目录的父目录
- **THEN** 主页列表显示父目录及所有子目录下的视频，不显示目录卡片

### Requirement: 收藏主页批量编辑

收藏主页编辑模式 SHALL 提供全选和取消全选操作，并继续支持批量移动和批量删除。

#### Scenario: 全选当前列表

- **WHEN** 用户进入编辑模式并点击“全选”
- **THEN** 当前列表中的所有视频被选中，按钮变为“取消全选”

## ADDED Requirements

### Requirement: 图片异步持久化后刷新列表

客户端 SHALL 在收藏保存完成后等待正在进行的元数据识别，并将识别到的图片写入 `images` 数组；更新成功后 SHALL 刷新当前列表。

#### Scenario: 保存后封面识别完成

- **WHEN** 收藏已创建且后台封面识别随后成功
- **THEN** 服务端更新该收藏的 `images`，客户端刷新列表并显示新图片
