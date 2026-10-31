# Tasks

## 1. 服务端小红书清洗与 B 站专用解析

- [x] 1.1 重构 `source/server-node/src/services/bookmark-metadata.service.js` 中的小红书 URL 清洗逻辑，彻底剥离所有前置代理和转义前缀，编写单测验证纯净单 URL 直链输出。
- [x] 1.2 在 `bookmark-metadata.service.js` 集成 Bilibili 专用解析通道（基于 `mcp-server-bilibili` 核心服务接口），支持短链及长链解析并包含官方 API 双重兜底；编写单测验证 B 站解析。
- [x] 1.3 运行后端单元测试 `npm test` 验证服务端所有功能与用例全部通过。

## 2. 移动端抖音 ClipVault 解析机制

- [x] 2.1 在 Flutter 端实现抖音客户端解析器（跟踪 `v.douyin.com` 短链重定向、提取 `aweme_id` 并请求无水印封面接口提取原图直链与标题）。
- [x] 2.2 在 `source/flutter_bookmark/lib/widgets/bookmark_form.dart` 中对接抖音解析逻辑：检测到抖音链接时优先触发客户端解析并回填封面与标题。
- [x] 2.3 编写 Flutter 单元与组件测试验证抖音解析与表单联动。

## 3. 全量验证与更新

- [x] 3.1 运行 Flutter 全量测试与代码分析，确保测试全部通过。
- [x] 3.2 更新构建元数据及规格记录。

## Workflow follow-up

- 完成实施后评审并归档变更。
