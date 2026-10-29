# Spec Delta

## Purpose

为同一账号下的不同 Flutter 客户端提供明确、可验证的数据空间隔离，使星标收藏和做饭收藏可以共享登录体系而不会互相出现在目录、搜索或随机结果中。

## ADDED Requirements

### Requirement: 收藏数据按应用空间隔离

系统 SHALL 为收藏夹、收藏条目和相关分类数据保存应用空间标识，至少支持 `star` 和 `cookie`；所有查询、创建、修改和删除操作 SHALL 同时校验当前用户与空间。

#### Scenario: 星标客户端只读取星标数据

- **WHEN** `flutter-star` 请求收藏夹或收藏条目
- **THEN** 系统只返回当前用户 `star` 空间的数据，不返回 `cookie` 空间数据

#### Scenario: 做饭客户端只读取做饭数据

- **WHEN** `flutter-cookie` 请求收藏夹或收藏条目
- **THEN** 系统只返回当前用户 `cookie` 空间的数据，不返回 `star` 空间数据

#### Scenario: 跨空间修改被拒绝

- **WHEN** 用户使用一个空间的客户端提交另一个空间的收藏夹或条目标识
- **THEN** 系统拒绝操作且不泄露目标空间数据

### Requirement: 客户端共用账号认证

系统 SHALL 允许 `flutter-star` 和 `flutter-cookie` 使用同一用户名密码登录和 Bearer JWT，但客户端 SHALL 使用各自固定空间请求数据。

#### Scenario: 同一账号登录两个客户端

- **WHEN** 用户使用同一账号分别登录两个客户端
- **THEN** 两个客户端都能完成认证，但各自只看到对应空间数据

### Requirement: 原收藏客户端重命名后保持行为

系统 SHALL 将原 Android 收藏客户端标识为 `flutter-star`，并保持原有链接分享、标题识别、收藏夹、打开链接和收藏管理行为。

#### Scenario: 升级后继续使用星标收藏

- **WHEN** 用户在 `flutter-star` 中打开原有星标收藏数据
- **THEN** 原有数据可继续读取和操作，且不被迁移到 `cookie` 空间
