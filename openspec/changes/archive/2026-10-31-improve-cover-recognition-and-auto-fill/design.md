# Design

## Context

目前移动端 `BookmarkForm` 仅在系统分享唤醒时设置了 `fetchMetadataOnOpen = true`。用户在应用内手动打开表单并点“粘贴”按钮时，不会自动请求元数据，必须手动按“识别封面”。另外，服务端 `bookmark-metadata.service.js` 直接读取 HTML 的 `og:image`，小红书页面返回了带 `https://ci.xiaohongshu.com/http...` 的双层嵌套格式导致 404；Bilibili 移动端部分视频则返回 `transparent.png` 透明图，导致前端显示空白。

## Goals / Non-Goals

**Goals:**

- 在服务端 `bookmark-metadata.service.js` 增加小红书封面 URL 剥离逻辑，提取内部纯净的 `https://sns-webpic-qc.xhscdn.com/...` 直链。
- 在服务端遇到 Bilibili `transparent.png` 或空图片时，调用 B 站公开 API `https://api.bilibili.com/x/web-interface/view?bvid=...` 获取真实彩色封面 `pic`。
- 在 Flutter 端 `BookmarkForm` 中：
  - 点击“粘贴”成功提取到链接时，自动触发 `_recognizeMetadata()`。
  - URL 输入框失去焦点且当前为有效新链接时，若标题或封面为空，自动触发 `_recognizeMetadata()`。
  - 在小红书短链重定向保存时，若获取到的 metadata 包含 `coverUrl` 且当前表单为空，自动一并赋值保存。

**Non-Goals:**

- 本阶段不下载图片二进制到本地文件系统（遵循方案一，继续存储 URL）。

## Decisions

### 1. 小红书图片清洗函数
解析出 `coverUrl` 后，若包含 `ci.xiaohongshu.com/http`，通过正则或字符串查找切出真正的 `http://sns-...` 并升级为 `https://sns-...`，实测该直链直接 HTTP 200，且不需要 Referer 头。

### 2. B 站透明假图检测与 API 兜底
在 `parseMetadata` 中检测如果 `coverUrl` 包含 `transparent.png`，并且 URL 包含 `BV` 或 `av` 号，发起轻量级请求获取视频信息以提取真实 `pic`。

### 3. Flutter 端防重复识别
通过记录上一次识别的 URL 避免频繁失焦重复请求；请求时显示加载动画，成功后无感更新预览卡片。
