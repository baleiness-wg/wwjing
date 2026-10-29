# wwjing_kitchen

跨端私人收藏夹 Android 客户端

## 本地运行

先在 `source/` 目录启动 Node API：

```powershell
npm run dev:server
```

服务默认监听 `http://0.0.0.0:3000`，API 前缀为 `/api`。数据库和 JWT 配置位于 `source/server-node/.env`；没有该文件时使用 `source/server-node/src/config/index.js` 中的开发默认值，可从 `.env.example` 复制后调整。

Android 模拟器默认连接：

```text
http://10.0.2.2:3000/api
```

连接 Android 真机时，需要使用电脑在局域网中的 IP，并重新运行：

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.2:3000/api
```

将 `192.168.1.2` 替换为电脑实际 IP，并确保防火墙允许手机访问 TCP 3000。

## 平台范围

第一版工程仅配置 Android。系统分享的 MethodChannel 只在 Android `MainActivity` 中注册；代码会在非 Android 平台跳过分享通道，避免 `MissingPluginException`，但正式功能验收应使用 Android 模拟器或真机。

## 构建

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Release APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

## VS Code 初始化

- 安装 Flutter 和 ADB QR 插件。
- 使用 `Ctrl+Shift+P` → `Flutter: Run Flutter Doctor` 检查环境。
- 使用 `Ctrl+Shift+P` → `Flutter: New Project` 创建新工程时，确保打开的是本目录。

## Android 无线调试

```powershell
adb disconnect
flutter clean
adb mdns services
adb connect 192.168.1.5:42209
adb devices -l
flutter run -d 192.168.1.5:42209
```

也可以使用 VS Code 的 ADB QR 插件完成无线配对。电脑开发者模式可通过 `Start-Process "ms-settings:developers"` 打开。
