import { createRouter, createWebHistory } from "vue-router";
import LoginView from "../views/LoginView.vue";
import ToolsView from "../views/ToolsView.vue";
import HomeView from "../views/HomeView.vue";
import TransferView from "../views/TransferView.vue";
import BookmarksView from "../views/BookmarksView.vue";

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: "/", name: "home", component: HomeView, meta: { requiresAuth: true } },
    { path: "/tools", name: "tools", component: ToolsView, meta: { requiresAuth: true } },
    { path: "/tools/transfer", name: "transfer", component: TransferView, meta: { requiresAuth: true } },
    { path: "/tools/bookmarks", name: "bookmarks", component: BookmarksView, meta: { requiresAuth: true } },
    { path: "/login", name: "login", component: LoginView }
  ]
});

router.beforeEach((to) => {
  const isAuthenticated = Boolean(localStorage.getItem("wwjing_token"));

  if (to.meta.requiresAuth && !isAuthenticated) return "/login";
  if (to.name === "login" && isAuthenticated) return "/";
});

export default router;
