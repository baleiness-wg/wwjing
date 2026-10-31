# Design

## Context

针对收藏夹对于多平台（小红书、哔哩哔哩、抖音）链接元数据（尤其是封面图片与标题）识别不稳定的问题，进行架构与实现层面的双端重构。详见 `proposal.md`。

## Goals / Non-Goals

**Goals:**

- **小红书（Node.js 端）**：彻底修复“两个 URL 拼接”与代理前缀残留问题，保证返回单段真实 CDN 高清直链。
- **哔哩哔哩（Node.js 端）**：集成类似 `mcp-server-bilibili` 的解析方案，直接调用专用解析通道获取视频真实彩色封面及标题，短链长链均可稳定穿透。
- **抖音（Flutter 端）**：基于 ClipVault 机制，在客户端完成 `v.douyin.com` 短链跳转追踪与 `aweme_id` 提取，调用抖音 Web 详情接口获取无水印原图封面 `video.origin_cover`，自动回填至表单。

**Non-Goals:**

- 本次变更不改变数据库存储结构，依然只保存图片 URL 直链，不引入本地文件存储服务。

## Decisions

### 1. 小红书 URL 清洗器重构
- **现状**：旧正则虽然排除了部分前缀，但若遇到 `https://ci.xiaohongshu.com/https://sns-...` 或带转义的 URL，简单匹配依然可能返回包含双重前缀的拼接串。
- **决定**：使用专用解码与清洗函数：
  1. 先进行 URI 解码；
  2. 使用正则提取以 `https?://sns-(?:webpic|img)[^"'?&]+` 开头并保留合法 query 的纯净直链；
  3. 如果未匹配到，检测最后一个 `http://` 或 `https://` 的位置，将之前的内容全部切除丢弃，确保绝不会产生两个协议前缀串联的异常 URL。

### 2. 哔哩哔哩服务端专用解析方案
- **参考**：`mcp-server-bilibili` 使用的接口 `https://api.bugpk.com/api/bilibili?url=...`。
- **决定**：
  在 Node 端 `bookmark-metadata.service.js` 中，当检测到目标链接为 `bilibili.com` 或 `b23.tv` 时，优先通过该解析通道获取，成功即提取 `data.cover`（转为 https）和 `data.title`。若该通道超时或异常，自动回退到官方 API `https://api.bilibili.com/x/web-interface/view?bvid=...`，形成双重保障。

### 3. 抖音客户端 ClipVault 方案
- **技术原理**：
  抖音官方网页受反爬 Acrawler 限制，服务端无动态执行环境易被封锁。
  在 Flutter 端：
  1. 通过轻量 HTTP 请求跟随 `v.douyin.com` 302 重定向拿到完整 URL（例如 `https://www.iesdouyin.com/share/video/7700035406317882660/...`）；
  2. 正则提取 `aweme_id`；
  3. 请求抖音官方接口 `https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids={id}` 或带标准移动端 User-Agent 的接口提取 `item_list[0].video.cover.url_list[0]` / `item_list[0].images[0].url_list[0]`；
  4. 移动端直接将解析出的原图直链与标题更新到输入框与封面组件。

## Risks / Trade-offs

- [抖音官方接口变动风险] → 接口提取失败时保持优雅降级，允许用户手动输入封面或保留域名占位，不阻断正常保存与 App 拉起。
- [第三方 Bilibili 解析服务高可用风险] → Node.js 端设置 3 秒超时并配置官方 view API 兜底，确保服务稳定。
