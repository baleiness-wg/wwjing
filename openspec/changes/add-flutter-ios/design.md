# Design

使用 Flutter 官方 iOS 工程模板生成 `ios/` 目录，保留现有 Dart 层和 Android flavor。iOS 原生主应用通过 MethodChannel 接收 Share Extension 写入 App Group 的分享文本；主应用启动和进入前台时读取共享内容，再通过同一通道通知 Dart 层。Share Extension 使用 Swift 和 App Group UserDefaults，不直接访问业务 API。
