# Proposal

## Why

用户在收藏外部链接（如小红书、哔哩哔哩、抖音等）时，由于服务端提取规则未适配各大平台嵌套前缀、部分页面防盗链以及假占位图，导致抓取到的封面为透明假图（B站 `transparent.png`）或带双重协议嵌套前缀的错误地址（小红书），进而在客户端无法加载真实封面图片，退化为显示域名文字占位；此外，移动端在用户粘贴链接后未自动触发元数据识别，体验断层。

## What Changes

- 服务端元数据解析器增加小红书封面 URL 清洗规则：自动移除嵌套的 `https://ci.xiaohongshu.com/http...` 前缀，提取真正的 CDN 直链。
- 服务端增加 B 站封面增强穿透：当 `og:image` 匹配到 `transparent.png` 或空图时，从链接提取 BV/av 标识并请求公开接口获取真实高清视频封面。
- 服务端抖音解析优化：针对 `iesdouyin.com` 页面提取 `_ROUTER_DATA` 内嵌封面或静态属性。
- 移动端收藏表单体验优化：在用户点击“粘贴”按钮或链接输入框失去焦点填入有效链接时，自动触发异步元数据与封面识别，无需用户手动寻找“识别封面”按钮。
- 确保保存时表单中的封面 URL 正常提交并写入数据库 `bookmark_items.cover_url`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `bookmark-app-modes`: 增强链接元数据封面解析可靠性（支持小红书、B站等平台的真实封面清洗与兜底），并在客户端表单实现链接填入后自动异步识别与预览。

## Impact

- 服务端 `source/server-node/src/services/bookmark-metadata.service.js` 增加小红书地址清洗和 B 站封面兜底。
- 移动端 `source/flutter_bookmark/lib/widgets/bookmark_form.dart` 在粘贴和失焦后自动触发识别。
- 更新相关单元与端到端测试，确保覆盖小红书 URL 清洗和 B 站封面兜底。
