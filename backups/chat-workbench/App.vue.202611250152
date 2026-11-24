<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import AppLayout from "./layouts/AppLayout.vue";
import LoginView from "./views/LoginView.vue";
import ChatWorkbenchView from "./views/ChatWorkbenchView.vue";

const route = useRoute();
const isLoginPage = computed(() => route.name === "login");
const isOfficePage = computed(() => route.name === "office");
</script>

<template>
  <LoginView v-if="isLoginPage" />
  <ChatWorkbenchView v-else-if="isOfficePage" />
  <AppLayout v-else />
</template>
