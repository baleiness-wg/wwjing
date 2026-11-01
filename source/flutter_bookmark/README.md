# flutter_bookmark

统一的跨端私人收藏夹 Flutter 客户端，支持 Android 和 iOS。构建时必须通过 `APP_TYPE` 选择模式。
| 模式 | Flutter flavor | 收藏空间 | 应用名称 | 随机推荐 |
| --- | --- | --- | --- | --- |
| kitchen | `kitchen` | `cookie` | 疯狂的厨�?| 支持 |
| star | `star` | `star` | 鲸界 | 不支�?|

## 本地运行

先在 `source/` 目录启动 Node API�?
```powershell
npm run dev:server
```

服务默认监听 `http://0.0.0.0:3000`，API 前缀�?`/api`。数据库�?JWT 配置位于 `source/server-node/.env`；没有该文件时使�?`source/server-node/src/config/index.js` 中的开发默认值，可从 `.env.example` 复制后调整�?
Android 模拟器默认连接：

```text
http://10.0.2.2:3000/api
```

连接 Android 真机时，需要使用电脑在局域网中的 IP，并重新运行�?
```powershell
flutter run --flavor kitchen -d <device-id> --dart-define=APP_TYPE=kitchen --dart-define=API_BASE_URL=http://192.168.1.2:3000/api
flutter run --flavor star -d <device-id> --dart-define=APP_TYPE=star --dart-define=API_BASE_URL=http://192.168.1.2:3000/api
```

�?`192.168.1.2` 替换为电脑实�?IP，并确保防火墙允许手机访�?TCP 3000�?
## 平台范围

工程已配置 Android 和 iOS。Android 使用 `MainActivity` 接收系统分享；iOS 主应用已准备 MethodChannel 和 App Group 接收分享扩展写入的分享文本。Share Extension target 及 Apple Developer App Group 签名需要在 macOS/Xcode 中完成最终配置。
## 构建

```powershell
flutter analyze
flutter test
flutter build apk --debug --flavor kitchen --dart-define=APP_TYPE=kitchen
flutter build apk --debug --flavor star --dart-define=APP_TYPE=star
flutter build apk --release --flavor kitchen --dart-define=APP_TYPE=kitchen
flutter build apk --release --flavor star --dart-define=APP_TYPE=star
flutter build ios --debug --dart-define=APP_TYPE=kitchen
flutter build ios --debug --dart-define=APP_TYPE=star
```

APK 输出位于 `build/app/outputs/flutter-apk/`。iOS 构建必须在 macOS + Xcode 环境执行；真机发布还需要 Apple Developer 签名和 App Group capability。`APP_TYPE` 缺失或非法时构建会失败，不会静默回退到其他模式。
统一工程使用新的 Android 应用标识，不能覆盖旧�?`flutter_kitchen` �?`flutter_star` 安装。首次迁移需要安装对�?flavor 并重新登录；服务�?`cookie` �?`star` 空间数据不迁移、不丢失�?
## VS Code 初始�?
- 安装 Flutter �?ADB QR 插件�?- 使用 `Ctrl+Shift+P` �?`Flutter: Run Flutter Doctor` 检查环境�?- 使用 `Ctrl+Shift+P` �?`Flutter: New Project` 创建新工程时，确保打开的是本目录�?
## Android 无线调试

```powershell
adb disconnect
adb mdns services
adb connect 192.168.1.5:42209
adb devices -l
flutter run --flavor kitchen -d 192.168.1.5:42209 --dart-define=APP_TYPE=kitchen
flutter run --flavor star -d 192.168.1.5:42209 --dart-define=APP_TYPE=star
```

也可以使�?VS Code �?ADB QR 插件完成无线配对。电脑开发者模式可通过 `Start-Process "ms-settings:developers"` 打开�?
