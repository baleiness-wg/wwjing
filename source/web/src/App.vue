<script setup>
import { computed, defineAsyncComponent } from "vue";
import { useRoute } from "vue-router";
import ChatWorkbenchView from "./views/ChatWorkbenchView.vue";

const AppLayout = defineAsyncComponent(() => import("./layouts/AppLayout.vue"));
const LoginView = defineAsyncComponent(() => import("./views/LoginView.vue"));

const route = useRoute();
const isLoginPage = computed(() => route.name === "login");
const isOfficePage = computed(() => route.name === "office");
</script>

<template>
  <LoginView v-if="isLoginPage" />
  <ChatWorkbenchView v-else-if="isOfficePage" />
  <AppLayout v-else />
</template>
