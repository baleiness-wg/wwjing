# Proposal

## Why

在多平台外部收藏（小红书、哔哩哔哩、抖音）的日常使用中，原先依赖静态网页 HTML 的封面抓取策略严重受阻：
1. 小红书返回的图片包含双重代理前缀或嵌套 URL，清洗不彻底导致生成损坏的双重 URL；
2. 哔哩哔哩短链及防盗链/412 机制导致静态网页无法稳定获取视频彩色封面；
3. 抖音 Web 页面受动态 Acrawler 验证码和字节码防护（`_$jsvmprt`），导致纯服务端拉取 HTML 完全失效。

为了彻底解决这三大平台的封面和元数据识别问题，需要结合最适宜的架构策略：
- 服务端重构小红书直链提取算法，剥离任何反代与嵌套前缀；
- 服务端针对哔哩哔哩集成类似 `mcp-server-bilibili` 的解析能力，直接调用高可用 API 获取高清视频封面与标题；
- 移动端（Flutter）引入 ClipVault 机制，在用户粘贴或分享抖音链接时直接在客户端跟踪短链并调用移动端/Web 接口获取无水印原图封面，并自动填充提交。

## What Changes

- **服务端小红书清洗**：彻底重构 `bookmark-metadata.service.js` 中的 URL 清洗算法，递归解码并丢弃所有代理前缀，仅返回纯净的 `https://sns-webpic...` / `https://sns-img...` 直链。
- **服务端 Bilibili 解析**：集成 Bilibili 专用解析服务（基于 `mcp-server-bilibili` 核心接口），支持 `b23.tv` 短链重定向与高清封面直接提取。
- **移动端抖音 ClipVault 解析机制**：在 Flutter 客户端增加针对抖音短链的客户端解析通道，由客户端跟随 `v.douyin.com` 重定向、提取 `aweme_id`、请求详情接口并回填高清封面与标题。
- **端到端体验联动**：移动端在识别外部链接时优先判断平台并分流，小红书与 B 站通过服务端解析，抖音优先执行客户端高清抓取，确保保存时封面入库。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `bookmark-app-modes`: 增强三大平台封面识别与清洗能力，规范化小红书直链输出，增加 B 站专用解析能力，并在移动端表单实现抖音短链客户端解析与封面自动填充。

## Impact

- `source/server-node/src/services/bookmark-metadata.service.js`：清洗逻辑重构及 B 站解析升级。
- `source/flutter_bookmark/lib/widgets/bookmark_form.dart` 及配套服务：集成抖音客户端解析器与表单联动。
- 后端及移动端测试用例更新与验证。
