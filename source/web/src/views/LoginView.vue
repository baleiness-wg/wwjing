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
    const returnPath = sessionStorage.getItem("office_login_return");
    sessionStorage.removeItem("office_login_return");
    router.push(returnPath || "/");
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
      <p class="eyebrow">WWJ / Whaleland</p>
      <h1> {{ isRegister ? "Register" : "Login" }} </h1>
      <el-form label-position="top" @submit.prevent="submit">
        <el-form-item label="用户名">
          <el-input v-model="form.username" autocomplete="username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" show-password autocomplete="current-password" @keyup.enter="submit" />
        </el-form-item>
        <el-button type="primary" :loading="loading" class="full-button" @click="submit">
          {{ isRegister ? "Register" : "Login" }}
        </el-button>
      </el-form>
      <el-button text class="switch-button" @click="isRegister = !isRegister">
         {{ isRegister ? "已有账号？去登录" : "还没有账号？去注册" }}
      </el-button>
    </el-card>
  </main>
</template>
