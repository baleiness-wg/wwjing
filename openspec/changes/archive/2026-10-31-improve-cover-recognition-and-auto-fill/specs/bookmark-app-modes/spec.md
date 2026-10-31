# Spec Delta

## ADDED Requirements

### Requirement: 平台封面清洗与增强解析

服务端元数据解析 SHALL 对各大平台返回的封面 URL 进行规范化清洗，过滤无效或占位假图，并提取可直接访问的高清图片直链。

#### Scenario: 小红书双重协议嵌套封面清洗

- **WHEN** 解析到包含类似 `ci.xiaohongshu.com/http...` 嵌套的小红书图片链接
- **THEN** 服务端自动剥离多余代理前缀，将其规范化为 `https://sns-webpic-qc.xhscdn.com/...` 直链并返回

#### Scenario: 哔哩哔哩透明假图穿透

- **WHEN** 哔哩哔哩网页元数据返回 `transparent.png` 或空图片但链接包含有效 BV/av 标识
- **THEN** 服务端通过公开信息穿透提取视频的真实彩色封面图 URL 并返回

### Requirement: 表单智能自动识别元数据

移动端收藏表单 SHALL 在用户完成链接输入（包括点击“粘贴”或输入框失去焦点检测到有效 HTTP/HTTPS 链接）时，自动异步发起元数据识别并填充标题与封面预览，无需用户手动点击“识别封面”。

#### Scenario: 点击粘贴后自动识别

- **WHEN** 用户在收藏表单点击“粘贴”按钮填入有效链接
- **THEN** 客户端自动异步发起元数据抓取，并在成功后将封面填入封面预览与输入框

#### Scenario: 保存时完整持久化封面

- **WHEN** 客户端表单已填充或识别出封面 URL 并点击保存
- **THEN** 客户端将该 `coverUrl` 提交至后端接口持久化到数据库中
