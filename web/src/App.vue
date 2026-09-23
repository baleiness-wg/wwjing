<script setup>
import { computed } from "vue";
import { useRoute } from "vue-router";
import AppLayout from "./layouts/AppLayout.vue";
import LoginView from "./views/LoginView.vue";

const route = useRoute();
const isLoginPage = computed(() => route.name === "login");
</script>

<template>
  <LoginView v-if="isLoginPage" />
  <AppLayout v-else />
</template>
