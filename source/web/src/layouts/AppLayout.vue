<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Close, Menu, User, SwitchButton, Tools, House } from "@element-plus/icons-vue";

const router = useRouter();
const route = useRoute();
const menuVisible = ref(!window.matchMedia("(max-width: 640px)").matches);
const user = JSON.parse(localStorage.getItem("wwjing_user") || "null");
const sideItems = [{ path: "/", label: "首页", icon: House, when: (path) => path === "/" }, { path: "/tools/transfer", label: "数据传输", icon: Tools, when: (path) => path.startsWith("/tools") }];

function go(path) {
  router.push(path);
  if (window.matchMedia("(max-width: 640px)").matches) menuVisible.value = false;
}

function toggleMenu() {
  menuVisible.value = !menuVisible.value;
}

function logout() {
  localStorage.removeItem("wwjing_token");
  localStorage.removeItem("wwjing_user");
  router.replace("/login");
}
</script>

<template>
  <el-container class="app-shell" :class="{ 'menu-open': menuVisible }">
    <div v-if="menuVisible" class="menu-backdrop" @click="menuVisible = false"></div>
     <el-aside :width="menuVisible ? '220px' : '0px'" class="app-aside">
       <el-button class="mobile-close" text circle :icon="Close" aria-label="关闭菜单" @click="menuVisible = false" />
       <el-menu
        :default-active="route.path"
        class="side-menu"
      >
         <el-menu-item v-for="item in sideItems.filter((entry) => entry.when(route.path))" :key="item.path" :index="item.path" @click="go(item.path)">
           <el-icon><component :is="item.icon" /></el-icon>
           <span>{{ item.label }}</span>
         </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
         <el-header class="app-header">
           <div class="header-brand">
             <span class="brand-mark">鲸</span>
             <strong>鲸境</strong>
           </div>
           <el-button text class="menu-toggle" :icon="menuVisible ? Close : Menu" @click="toggleMenu">
            {{ menuVisible ? "收起菜单" : "展开菜单" }}
          </el-button>
         <nav class="top-nav">
           <el-button text :class="{ active: route.path === '/' }" @click="go('/')">首页</el-button>
           <el-button text :class="{ active: route.path.startsWith('/tools') }" @click="go('/tools')">工具</el-button>
         </nav>
         <div class="header-actions">
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
