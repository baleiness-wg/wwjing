# Design

复用现有 JWT 认证中间件、bcryptjs 哈希和用户模型。接口从 JWT 的 `req.auth.sub` 获取用户，先比较当前密码，再以 bcrypt 生成新哈希并更新 `updated_at`。客户端成功后清除令牌并回到登录页。
