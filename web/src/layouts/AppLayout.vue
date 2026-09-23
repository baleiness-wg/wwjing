<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Collection, House, Plus, User, SwitchButton } from "@element-plus/icons-vue";

const router = useRouter();
const route = useRoute();
const menuVisible = ref(true);
const user = JSON.parse(localStorage.getItem("wwjing_user") || "null");

function go(path) {
  router.push(path);
}

function logout() {
  localStorage.removeItem("wwjing_token");
  localStorage.removeItem("wwjing_user");
  router.replace("/login");
}
</script>

<template>
  <el-container class="app-shell">
    <el-aside :width="menuVisible ? '220px' : '0px'" class="app-aside">
      <div v-if="menuVisible" class="brand">
        <span class="brand-mark">鲸</span>
        <div>
          <strong>鲸境</strong>
          <small>把收藏变成行动</small>
        </div>
      </div>

      <el-menu
        v-if="menuVisible"
        :default-active="route.path"
        router
        class="side-menu"
      >
        <el-menu-item index="/home">
          <el-icon><House /></el-icon>
          <span>首页</span>
        </el-menu-item>
        <el-menu-item index="/favorites">
          <el-icon><Collection /></el-icon>
          <span>收藏夹</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="app-header">
        <el-button text @click="menuVisible = !menuVisible">菜单</el-button>
        <div class="header-actions">
          <el-button type="primary" :icon="Plus" @click="go('/favorites')">收进来</el-button>
          <el-dropdown @command="logout">
            <el-button text class="user-button">
              <el-icon><User /></el-icon>
              {{ user?.username || "用户" }}
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="logout" :icon="SwitchButton">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main class="app-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>
