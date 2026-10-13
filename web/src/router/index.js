import { createRouter, createWebHistory } from "vue-router";
import HomeView from "../views/HomeView.vue";
import FavoritesView from "../views/FavoritesView.vue";
import LoginView from "../views/LoginView.vue";
import FoldersView from "../views/FoldersView.vue";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", redirect: "/login" },
    { path: "/home", name: "home", component: HomeView, meta: { requiresAuth: true } },
    { path: "/favorites", name: "favorites", component: FavoritesView, meta: { requiresAuth: true } },
    { path: "/folders", name: "folders", component: FoldersView, meta: { requiresAuth: true } },
    { path: "/login", name: "login", component: LoginView }
  ]
});

router.beforeEach((to) => {
  const isAuthenticated = Boolean(localStorage.getItem("wwjing_token"));

  if (to.meta.requiresAuth && !isAuthenticated) return "/login";
  if (to.name === "login" && isAuthenticated) return "/home";
});

export default router;
