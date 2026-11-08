# Tasks

## 1. 数据库与 Node 收藏契约

- [ ] 1.1 固化 `images` JSONB 数组和 URL 可空迁移，验证 `npm run db:migrate` 在带历史 `cover_url` 数据的数据库上成功执行且不丢失首图。
- [ ] 1.2 更新 Node 收藏模型和服务，验证标题必填、空 URL 可保存、非空 URL 重复判断以及 `images` 数组 JSONB 读写测试通过。
- [ ] 1.3 保留并文档化图片上传预留接口，验证接口返回明确的未实现状态且不修改收藏数据。

## 2. 元数据与平台行为

- [ ] 2.1 恢复并完善抖音、哔哩哔哩、小红书专用元数据解析，验证小红书真实 CDN 封面优先于平台 Logo 的解析测试通过。
- [ ] 2.2 验证 LinkLauncher 的平台 HTTPS、Deep Link、App 首页、外部链接回退顺序，确保 Flutter 平台跳转测试通过。
- [ ] 2.3 实现保存后异步图片持久化和列表刷新，验证识别完成后 `images` 更新且当前列表显示新图片。

## 3. Flutter 表单与收藏主页

- [ ] 3.1 更新 Flutter 模型、API 和表单，验证标题必填、描述/URL 可选、图片预览与 `images` 数组提交。
- [ ] 3.2 恢复分享、剪贴板、粘贴后的自动识别和编辑中切换确认，验证分享与剪贴板专项 Widget 测试通过。
- [ ] 3.3 让主页只显示视频卡片，目录切换请求递归后代目录，验证主页不显示目录卡片且父目录列表包含后代视频。
- [ ] 3.4 完成主页紧凑卡片、搜索栏、全选批量编辑和平台跳转 UI 调整，验证 Flutter 全量测试通过。

## 4. Flutter 目录交互

- [ ] 4.1 实现左侧目录树和目录选择器折叠/展开，验证父目录折叠后子目录不可见且再次展开恢复。
- [ ] 4.2 实现目录操作菜单选中高亮和不遮挡触发按钮的定位，验证移动、删除、重命名入口仍可用。
- [ ] 4.3 验证目录新增、移动、批量移动和当前目录默认选中行为，相关目录选择器测试通过。

## 5. Web 管理端

- [ ] 5.1 同步 Web 收藏模型、列表和编辑表单，验证标题必填、URL 可选、图片数组首图显示及多空间入口不回归。
- [ ] 5.2 调整 Web 收藏卡片宽度和图片/内容/操作四列布局，验证桌面和移动端收藏行占满可用宽度且 Web 测试通过。

## 6. 集成与部署验证

- [ ] 6.1 更新 Flutter、Node、Web 文档和构建版本信息，验证接口文档与实际请求字段一致。
- [ ] 6.2 执行 `flutter analyze`、`flutter test`、Node `npm test` 和 Web `npm test`，确认所有测试通过。
- [ ] 6.3 在生产 Docker 网络和持久化数据库上执行迁移、健康检查、登录、收藏列表和新增无 URL 条目验证。

## Workflow follow-up

- Archive the change after implementation and review are complete.
- Verify the archived main specs preserve the consolidated requirements.
