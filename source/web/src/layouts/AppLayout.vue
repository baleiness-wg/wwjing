<script setup>
import { computed, onMounted, onBeforeUnmount, reactive, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  ArrowLeft,
  ArrowRight,
  Close,
  ChatDotRound,
  Folder,
  FolderOpened,
  Menu,
  Star,
  SwitchButton,
  Switch,
  User
} from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import { changePassword, getProfile, updateProfile } from "../api/auth";

const router = useRouter();
const route = useRoute();
const isMobile = () => window.matchMedia("(max-width: 640px)").matches;
const menuVisible = ref(!isMobile());
const toolsExpanded = ref(route.path.startsWith("/tools") || route.path === "/transfer");
const user = JSON.parse(localStorage.getItem("wwjing_user") || "null");
const passwordDialogVisible = ref(false);
const passwordLoading = ref(false);
const passwordForm = reactive({ currentPassword: "", newPassword: "", confirmPassword: "" });
const profileDialogVisible = ref(false);
const profileLoading = ref(false);
const profileDescription = ref("");
const bookmarkLocation = ref("");
const whalePosition = reactive({ right: 24, top: 140 });
const draggingWhale = ref(false);
let whaleStart = null;
let whaleMoved = false;

const navigationItems = [
  {
    path: "/tools",
    label: "Tools",
      icon: Folder,
      children: [
        { path: "/tools/bookmarks", label: "Bookmarks", icon: Star },
        { path: "/transfer", label: "Transfer", icon: Switch }
      ]
  }
];

const isToolsActive = computed(() => route.path === "/tools");
const isTransferActive = computed(() => route.path === "/transfer");

watch(
  () => route.path,
  (path) => {
    if (path.startsWith("/tools") || path === "/transfer") toolsExpanded.value = true;
  }
);

function go(path) {
  router.push(path);
  if (isMobile()) menuVisible.value = false;
}

function openOffice() {
  const officeUrl = new URL(`${import.meta.env.BASE_URL}office`, window.location.origin);
  window.open(officeUrl.href, "_blank", "noopener,noreferrer");
}

function toggleMenu() {
  menuVisible.value = !menuVisible.value;
}

function toggleTools() {
  toolsExpanded.value = !toolsExpanded.value;
}

function logout() {
  localStorage.removeItem("wwjing_token");
  localStorage.removeItem("wwjing_user");
  router.replace("/login");
}

function handleUserCommand(command) {
  if (command === "change-password") openPasswordDialog();
  if (command === "profile") openProfileDialog();
  if (command === "logout") logout();
}

async function openProfileDialog() {
  profileLoading.value = true;
  try {
    const result = await getProfile();
    profileDescription.value = result?.user?.profileDescription || "";
    profileDialogVisible.value = true;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    profileLoading.value = false;
  }
}

async function submitProfile() {
  profileLoading.value = true;
  try {
    await updateProfile({ description: profileDescription.value });
    ElMessage.success("个人信息已保存");
    profileDialogVisible.value = false;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    profileLoading.value = false;
  }
}

function updateBookmarkLocation(event) {
  bookmarkLocation.value = event.detail || "";
}

onMounted(() => window.addEventListener("wwjing:bookmark-location", updateBookmarkLocation));
onBeforeUnmount(() => window.removeEventListener("wwjing:bookmark-location", updateBookmarkLocation));

function beginWhaleDrag(event) {
  event.currentTarget?.setPointerCapture?.(event.pointerId);
  draggingWhale.value = true;
  whaleMoved = false;
  whaleStart = { x: event.clientX, y: event.clientY, right: whalePosition.right, top: whalePosition.top };
  window.addEventListener("pointermove", moveWhale);
  window.addEventListener("pointerup", endWhaleDrag, { once: true });
  window.addEventListener("pointercancel", endWhaleDrag, { once: true });
}
function moveWhale(event) {
  if (!whaleStart) return;
  if (Math.abs(event.clientX - whaleStart.x) + Math.abs(event.clientY - whaleStart.y) > 4) whaleMoved = true;
  whalePosition.right = Math.max(8, whaleStart.right + whaleStart.x - event.clientX);
  whalePosition.top = Math.max(8, whaleStart.top + event.clientY - whaleStart.y);
}
function endWhaleDrag() {
  draggingWhale.value = false;
  whaleStart = null;
  window.removeEventListener("pointermove", moveWhale);
  window.removeEventListener("pointercancel", endWhaleDrag);
  localStorage.setItem("wwjing_whale_position", JSON.stringify(whalePosition));
}
function openWhale(event) {
  if (whaleMoved) {
    event.preventDefault();
    return;
  }
  window.dispatchEvent(new CustomEvent("wwjing:open-ai-chat"));
}
try {
  const saved = JSON.parse(localStorage.getItem("wwjing_whale_position") || "null");
  if (saved) {
    Object.assign(whalePosition, saved);
    if (typeof saved.top !== "number" && typeof saved.bottom === "number") {
      whalePosition.top = Math.max(8, window.innerHeight - saved.bottom - 72);
    }
  }
} catch { /* ignore invalid saved position */ }

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
      <div class="aside-brand" :class="{ 'is-collapsed': !menuVisible }" role="link" tabindex="0" title="鲸界" @click="go('/transfer')" @keydown.enter="go('/transfer')">
         <img class="brand-mark-image" src="/whale.svg" alt="鲸界" />
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
        <div v-for="item in navigationItems" :key="item.path" class="side-menu-entry">
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
            <button
              v-for="child in item.children"
              :key="child.path"
              class="side-menu-item side-submenu-item"
              :class="{ 'is-active': child.path === '/transfer' ? isTransferActive : route.path === child.path }"
              @click="go(child.path)"
            >
              <el-icon><component :is="child.icon" /></el-icon>
              <span>{{ child.label }}</span>
            </button>
          </div>
        </div>
      </nav>
    </el-aside>

    <el-container>
      <el-header class="app-header">
        <div class="header-brand">
          <el-button text circle class="menu-toggle" :icon="Menu" :aria-label="menuVisible ? '收起菜单' : '展开菜单'" :title="menuVisible ? '收起菜单' : '展开菜单'" @click="toggleMenu" />
          <el-breadcrumb v-if="route.path === '/transfer' || route.path.startsWith('/tools')" class="header-breadcrumb" separator="/">
            <el-breadcrumb-item>Tools</el-breadcrumb-item>
            <el-breadcrumb-item v-if="route.path.startsWith('/tools/bookmarks')">Bookmarks</el-breadcrumb-item>
            <el-breadcrumb-item v-else-if="route.path === '/transfer'">Transfer</el-breadcrumb-item>
            <el-breadcrumb-item v-if="bookmarkLocation" class="is-current">{{ bookmarkLocation }}</el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        <div class="header-actions">
          <el-button text circle :icon="ChatDotRound" title="Office 协作" aria-label="Office 协作" @click="openOffice" />
          <el-dropdown @command="handleUserCommand">
            <el-button text class="user-button">
              <el-icon><User /></el-icon>
              {{ user?.username || "用户" }}
            </el-button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile" :icon="User">个人信息</el-dropdown-item>
                <el-dropdown-item command="change-password" :icon="User">修改密码</el-dropdown-item>
                <el-dropdown-item command="logout" :icon="SwitchButton">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
       <el-main class="app-main" :class="{ 'bookmark-main': route.path.startsWith('/tools/bookmarks') }">
        <router-view />
      </el-main>
    </el-container>
      <button class="global-whale-button" :class="{ 'is-dragging': draggingWhale }" :style="{ right: `${whalePosition.right}px`, top: `${whalePosition.top}px` }" title="和 AI 讨论收藏" @pointerdown="beginWhaleDrag" @click="openWhale">
        <img src="/whale.svg" alt="" />
      </button>
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
  <el-dialog v-model="profileDialogVisible" title="个人信息" width="min(92vw, 680px)">
    <el-input
      v-model="profileDescription"
      type="textarea"
      :rows="12"
      maxlength="4000"
      show-word-limit
      placeholder="告诉 AI 你的兴趣、习惯、目标和偏好"
    />
    <template #footer>
      <el-button @click="profileDialogVisible = false">取消</el-button>
      <el-button type="primary" :loading="profileLoading" @click="submitProfile">保存</el-button>
    </template>
  </el-dialog>
  </el-container>
 
</template>

<style scoped>
.global-whale-button { position: fixed; z-index: 20; width: 108px; height: 108px; border: 0; border-radius: 50%; background: transparent; color: #006b5f; cursor: grab; user-select: none; touch-action: none; filter: drop-shadow(0 3px 8px rgb(0 107 95 / 24%)); }
.global-whale-button img { width: 96px; height: 96px; display: block; margin: auto; object-fit: contain; pointer-events: none; }
.global-whale-button.is-dragging { cursor: grabbing; }
</style>
