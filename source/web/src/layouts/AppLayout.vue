<script setup>
import { computed, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  ArrowLeft,
  ArrowRight,
  CollectionTag,
  Close,
  Folder,
  FolderOpened,
  House,
  Star,
  SwitchButton,
  Tools,
  User
} from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import { changePassword } from "../api/auth";

const router = useRouter();
const route = useRoute();
const isMobile = () => window.matchMedia("(max-width: 640px)").matches;
const menuVisible = ref(!isMobile());
const toolsExpanded = ref(route.path.startsWith("/tools"));
const bookmarksExpanded = ref(route.path.startsWith("/tools/bookmarks"));
const user = JSON.parse(localStorage.getItem("wwjing_user") || "null");
const passwordDialogVisible = ref(false);
const passwordLoading = ref(false);
const passwordForm = reactive({ currentPassword: "", newPassword: "", confirmPassword: "" });

const navigationItems = [
  { path: "/", label: "首页", icon: House },
  {
    path: "/tools",
    label: "工具",
    icon: Folder,
    children: [
      { path: "/tools", label: "工具首页", icon: FolderOpened },
      { path: "/tools/transfer", label: "数据传输", icon: Tools },
      {
        path: "/tools/bookmarks",
        label: "收藏夹",
        icon: CollectionTag,
        children: [
          // { path: "/tools/bookmarks/kitchen", label: "疯狂的厨房", icon: KnifeFork },
          { path: "/tools/bookmarks/star", label: "鲸界", icon: Star }
        ]
      }
    ]
  }
];

const isHomeActive = computed(() => route.path === "/");
const isToolsActive = computed(() => route.path.startsWith("/tools"));

watch(
  () => route.path,
  (path) => {
    if (path.startsWith("/tools")) toolsExpanded.value = true;
    if (path.startsWith("/tools/bookmarks")) bookmarksExpanded.value = true;
  }
);

function go(path) {
  router.push(path);
  if (isMobile()) menuVisible.value = false;
}

function toggleMenu() {
  menuVisible.value = !menuVisible.value;
}

function toggleTools() {
  toolsExpanded.value = !toolsExpanded.value;
}

function toggleBookmarks() {
  bookmarksExpanded.value = !bookmarksExpanded.value;
}

function logout() {
  localStorage.removeItem("wwjing_token");
  localStorage.removeItem("wwjing_user");
  router.replace("/login");
}

function handleUserCommand(command) {
  if (command === "change-password") openPasswordDialog();
  if (command === "logout") logout();
}

function openPasswordDialog() {
  Object.assign(passwordForm, { currentPassword: "", newPassword: "", confirmPassword: "" });
  passwordDialogVisible.value = true;
}

async function submitPassword() {
  if (!passwordForm.currentPassword || !passwordForm.newPassword || !passwordForm.confirmPassword) {
    ElMessage.warning("请填写完整密码信息");
    return;
  }
  if (passwordForm.newPassword !== passwordForm.confirmPassword) {
    ElMessage.warning("两次输入的新密码不一致");
    return;
  }
  passwordLoading.value = true;
  try {
    await changePassword(passwordForm);
    ElMessage.success("密码修改成功，请重新登录");
    passwordDialogVisible.value = false;
    logout();
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    passwordLoading.value = false;
  }
}
</script>

<template>
  <el-container class="app-shell" :class="{ 'menu-open': menuVisible }">
    <div v-if="menuVisible && isMobile()" class="menu-backdrop" @click="menuVisible = false"></div>

    <el-aside :width="menuVisible ? '220px' : '64px'" class="app-aside">
      <div class="aside-brand" :class="{ 'is-collapsed': !menuVisible }">
        <span class="brand-mark">鲸</span>
        <div v-if="menuVisible" class="aside-brand-copy">
          <strong>鲸界</strong>
          <small>工作空间</small>
        </div>
        <el-button
          v-if="isMobile()"
          class="mobile-close"
          text
          circle
          :icon="Close"
          aria-label="关闭菜单"
          @click="menuVisible = false"
        />
      </div>

      <nav class="side-menu" aria-label="主导航">
        <template v-for="item in navigationItems" :key="item.path">
          <button
            v-if="!item.children"
            class="side-menu-item"
            :class="{ 'is-active': route.path === item.path }"
            :title="item.label"
            @click="go(item.path)"
          >
            <el-icon><component :is="item.icon" /></el-icon>
            <span v-if="menuVisible">{{ item.label }}</span>
          </button>

          <button
            v-else
            class="side-menu-item side-menu-group"
            :class="{ 'is-active': isToolsActive }"
            :title="item.label"
            :aria-expanded="toolsExpanded"
            aria-controls="tools-submenu"
            @click="toggleTools"
          >
            <el-icon><component :is="toolsExpanded ? FolderOpened : item.icon" /></el-icon>
            <span v-if="menuVisible">{{ item.label }}</span>
            <el-icon v-if="menuVisible" class="group-chevron"><ArrowLeft v-if="toolsExpanded" /><ArrowRight v-else /></el-icon>
          </button>

          <div v-if="item.children && menuVisible && toolsExpanded" id="tools-submenu" class="side-submenu">
            <template v-for="child in item.children" :key="child.path">
              <button
                v-if="!child.children"
                class="side-menu-item side-submenu-item"
                :class="{ 'is-active': route.path === child.path }"
                @click="go(child.path)"
              >
                <el-icon><component :is="child.icon" /></el-icon>
                <span>{{ child.label }}</span>
              </button>

              <template v-else>
                <button
                  class="side-menu-item side-submenu-item side-menu-group"
                  :class="{ 'is-active': route.path.startsWith(child.path) }"
                  :title="child.label"
                  :aria-expanded="bookmarksExpanded"
                  @click="toggleBookmarks"
                >
                  <el-icon><component :is="bookmarksExpanded ? FolderOpened : Folder" /></el-icon>
                  <span>{{ child.label }}</span>
                  <el-icon class="group-chevron"><ArrowLeft v-if="bookmarksExpanded" /><ArrowRight v-else /></el-icon>
                </button>

                <div v-if="bookmarksExpanded" class="side-sub-submenu">
                  <button
                    v-for="subChild in child.children"
                    :key="subChild.path"
                    class="side-menu-item side-sub-submenu-item"
                    :class="{ 'is-active': route.path === subChild.path }"
                    @click="go(subChild.path)"
                  >
                    <el-icon><component :is="subChild.icon" /></el-icon>
                    <span>{{ subChild.label }}</span>
                  </button>
                </div>
              </template>
            </template>
          </div>
        </template>
      </nav>
    </el-aside>

    <el-container>
      <el-header class="app-header">
        <div class="header-brand">
          <el-button
            text
            circle
            class="menu-toggle"
            :icon="menuVisible ? ArrowLeft : ArrowRight"
            :aria-label="menuVisible ? '收起菜单' : '展开菜单'"
            :title="menuVisible ? '收起菜单' : '展开菜单'"
            @click="toggleMenu"
          />
        </div>
        <div class="header-actions">
          <el-dropdown @command="handleUserCommand">
            <el-button text class="user-button">
              <el-icon><User /></el-icon>
              {{ user?.username || "用户" }}
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="change-password" :icon="User">修改密码</el-dropdown-item>
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
     <el-dialog v-model="passwordDialogVisible" title="修改密码" width="min(92vw, 420px)">
    <el-form label-position="top" @submit.prevent="submitPassword">
      <el-form-item label="当前密码"><el-input v-model="passwordForm.currentPassword" type="password" show-password /></el-form-item>
      <el-form-item label="新密码"><el-input v-model="passwordForm.newPassword" type="password" show-password /></el-form-item>
      <el-form-item label="确认新密码"><el-input v-model="passwordForm.confirmPassword" type="password" show-password @keyup.enter="submitPassword" /></el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="passwordDialogVisible = false">取消</el-button>
      <el-button type="primary" :loading="passwordLoading" @click="submitPassword">确认修改</el-button>
    </template>
  </el-dialog>
  </el-container>
 
</template>
