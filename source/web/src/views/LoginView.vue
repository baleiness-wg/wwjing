<script setup>
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { login, register } from "../api/auth";

const router = useRouter();
const isRegister = ref(false);
const loading = ref(false);
const form = reactive({ username: "", password: "" });

async function submit() {
  loading.value = true;

  try {
    if (isRegister.value) await register(form);
    const result = await login(form);
    localStorage.setItem("wwjing_token", result.token);
    localStorage.setItem("wwjing_user", JSON.stringify(result.user));
    ElMessage.success(isRegister.value ? "注册并登录成功" : "登录成功");
    router.push("/");
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <main class="login-page">
    <el-card class="login-card" shadow="never">
      <p class="eyebrow">WWJ / 鲸境</p>
      <h1>{{ isRegister ? "创建账号" : "回来继续整理" }}</h1>
      <p class="lead">把常用工具集中到一个属于你的工作台。</p>
      <el-form label-position="top" @submit.prevent="submit">
        <el-form-item label="用户名">
          <el-input v-model="form.username" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" show-password autocomplete="current-password" @keyup.enter="submit" />
        </el-form-item>
        <el-button type="primary" :loading="loading" class="full-button" @click="submit">
          {{ isRegister ? "注册并登录" : "登录" }}
        </el-button>
      </el-form>
      <el-button text class="switch-button" @click="isRegister = !isRegister">
        {{ isRegister ? "已有账号，去登录" : "还没有账号，先注册" }}
      </el-button>
    </el-card>
  </main>
</template>
