# Tasks

## 1. 服务端封面清洗与兜底

- [x] 1.1 在 `source/server-node/src/services/bookmark-metadata.service.js` 实现小红书封面 URL 清洗，剥离 `ci.xiaohongshu.com/http` 嵌套代理前缀；增加测试验证清洗前后的 URL 格式。
- [x] 1.2 在服务端实现 B 站 `transparent.png` 透明图检测与公开接口穿透，自动获取真实视频封面；编写测试验证假图被替换为真图。
- [x] 1.3 运行 `source/server-node` 测试确保全部通过。

## 2. 移动端表单自动识别与封面保存

- [x] 2.1 在 `source/flutter_bookmark/lib/widgets/bookmark_form.dart` 中，点击“粘贴”或输入框失去焦点时自动调用 `_recognizeMetadata()` 异步抓取封面与标题；通过 Widget 测试验证粘贴后自动触发识别。
- [x] 2.2 确保短链保存和小红书解析时，自动带入解析出的 `coverUrl` 提交保存。

## 3. 验证与版本收尾

- [x] 3.1 运行 Flutter 代码分析和全量测试，确保全部通过。
- [x] 3.2 更新 `build.json`、`main.dart` 中的 BUILD_TIME 以及模块规格说明。

## Workflow follow-up

- 实施与评审完毕后归档变更。
