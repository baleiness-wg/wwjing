# Tasks

## 1. 数据库迁移

- [ ] 1.1 新增 `007_use_md5_ids_and_kitchen_space.sql`，预检 `(user_id, space, normalized_url)` 重复条目并以异常终止；在本地数据库副本执行 `npm run db:migrate`，确认迁移成功且重复数据场景回滚。
- [ ] 1.2 在迁移中完成用户与收藏条目 MD5 主键转换、所有关联列类型与外键重建；执行前后对比各表记录数并查询 `bookmark_item_tags` 悬空关联为 0。
- [ ] 1.3 在迁移中把目录、条目、标签的 `cookie` 空间更新为 `kitchen` 并替换空间 CHECK 约束；查询三表 `space` 仅剩 `star` / `kitchen`。

## 2. 服务端 MD5 标识

- [ ] 2.1 注册流程使用 `crypto` 生成 `MD5(username)` 作为 `users.id`；更新服务端测试，验证注册响应和登录 JWT `sub` 为 32 位小写十六进制。
- [ ] 2.2 收藏条目创建使用 `MD5(userId:space:normalizedUrl)` 生成 `bookmark_items.id`；更新单元测试，验证同用户同空间重复链接命中既有重复提示，不同用户或空间得到不同 ID。
- [ ] 2.3 收藏条目详情/更新/删除改为校验 32 位十六进制标识；更新 API 测试，验证 `1234` 返回 `INVALID_INPUT`，合法 ID 正常读写。
- [ ] 2.4 检查标签、随机推荐、传输内容和日志中的 ID 字符串传递，修正仍假定数字 ID 的测试或代码；运行 `npm test` 确认全部通过。

## 3. 服务端空间值改为 kitchen

- [ ] 3.1 更新收藏目录、条目、标签、随机推荐服务的 `parseSpace` 与硬编码空间值为 `star` / `kitchen`；更新服务端测试断言，运行 `npm test` 确认无 `cookie` 残留。
- [ ] 3.2 更新 `source/server-node/README.http` 中随机推荐与收藏接口示例为 `space=kitchen`，并添加 MD5 标识示例；逐条核对示例参数与当前路由一致。

## 4. Flutter 客户端

- [ ] 4.1 将 `AppConfig.kitchen.space` 改为 `kitchen`，更新 `app_config_test.dart` 和所有请求测试夹具；运行 `flutter test` 确认通过。
- [ ] 4.2 检查收藏条目模型对字符串 ID 的解析与表单/列表传递，修正仍按数字处理的代码；运行 `flutter analyze` 确认无问题。
- [ ] 4.3 更新 `source/flutter_bookmark/build.json` 的 `built` 与 `llmodel`；确认文件可被页脚读取。

## 5. Web 客户端

- [ ] 5.1 更新路由 meta、API 默认空间、`BookmarksView` 空间判断为 `kitchen`；更新 Web 测试断言，运行 `npm test` 确认通过。
- [ ] 5.2 更新 `source/web/build.json` 的 `built` 与 `llmodel`；确认文件可被页脚读取。

## 6. 项目规格与集成验证

- [ ] 6.1 更新 `specs/bookmark-app-modes/spec.md` 与 `specs/bookmark-management/spec.md` 的空间值、MD5 标识说明和接口示例，追加版本记录；核对文档中不再出现 `cookie`。
- [ ] 6.2 更新 `source/server-node/build.json` 的 `built` 与 `llmodel`；确认文件可被服务端读取。
- [ ] 6.3 依次运行服务端 `npm test`、Flutter `flutter test`、Web `npm test`，确认全部通过且日志中无 `cookie` 或数字收藏 ID 断言。

## Workflow follow-up

- 完成实现后同步 delta specs 到主规格并运行 `openspec validate --specs`。
- 归档 `use-md5-ids-and-kitchen-space`。
