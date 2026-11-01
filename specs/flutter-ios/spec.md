# flutter-ios 模块规格说明

- 版本：202611010020
- 最后更新：2026-11-01
- 模块名称：flutter-ios（Flutter iOS 客户端）

## 业务概述

flutter-ios 为现有 Flutter 收藏应用增加 iOS 工程支持。iOS 客户端与 Android 复用同一套 Dart 页面、认证、收藏接口和应用模式配置，并支持从系统分享菜单接收链接或分享文本。

## 核心业务流程

- 用户可使用 `kitchen` 或 `star` 应用模式构建 iOS 版本。
- iOS 客户端通过 HTTPS 或可配置的 API 地址访问现有 Node 服务。
- 用户从其他 iOS 应用分享链接或文本到收藏应用后，应用提取分享内容并进入快速收藏流程。
- iOS 应用从冷启动或运行中收到分享内容时，均将内容交给 Dart 层现有分享处理逻辑。
- iOS 客户端使用 Keychain 保存认证令牌，使用系统偏好保存非敏感设置。

## 页面布局约束

- iOS 与 Android 复用现有 Material 页面和交互，不新增独立的 iOS 页面分支。
- 分享扩展页面使用系统提供的分享扩展界面，提交后将文本传给主应用。
- iOS 工程必须声明应用显示名称、最低系统版本和网络访问配置；生产环境不得依赖明文 HTTP API。

## 接口说明

本模块不新增业务 HTTP 接口，继续使用现有认证和收藏接口。iOS 原生层与 Dart 层之间使用 `com.baleine.wwjing.bookmark/share` 通道传递分享文本。

```json
{
  "method": "shareReceived",
  "text": "示例标题 https://example.com/article"
}
```

## 版本记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-11-01 | 202611010020 | 新增 Flutter iOS 工程、系统分享接收和构建约束 |
