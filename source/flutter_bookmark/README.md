# flutter_bookmark

统一的跨端私人收藏夹 Android 客户端。构建时必须通过 `APP_TYPE` 选择模式�?
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

第一版工程仅配置 Android。系统分享的 MethodChannel 只在 Android `MainActivity` 中注册；代码会在�?Android 平台跳过分享通道，避�?`MissingPluginException`，但正式功能验收应使�?Android 模拟器或真机�?
## 构建

```powershell
flutter analyze
flutter test
flutter build apk --debug --flavor kitchen --dart-define=APP_TYPE=kitchen
flutter build apk --debug --flavor star --dart-define=APP_TYPE=star
flutter build apk --release --flavor kitchen --dart-define=APP_TYPE=kitchen
flutter build apk --release --flavor star --dart-define=APP_TYPE=star
```

APK 输出位于 `build/app/outputs/flutter-apk/`。`APP_TYPE` 缺失、非法或�?flavor 不一致时构建会失败，不会静默回退到其他模式�?
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