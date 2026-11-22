import { createRouter, createWebHistory } from "vue-router";
import LoginView from "../views/LoginView.vue";
import TransferView from "../views/TransferView.vue";
import BookmarksView from "../views/BookmarksView.vue";
import ChatWorkbenchView from "../views/ChatWorkbenchView.vue";
import { getApplicationBase } from "./base";

const router = createRouter({
  history: createWebHistory(getApplicationBase()),
  routes: [
    { path: "/", redirect: "/transfer" },
    { path: "/transfer", name: "transfer", component: TransferView, meta: { requiresAuth: true } },
    { path: "/office", name: "office", component: ChatWorkbenchView },
    { path: "/tools", redirect: "/tools/bookmarks" },
    { path: "/tools/transfer", redirect: "/transfer" },
    {
      path: "/tools/bookmarks",
      name: "bookmarks-star",
      component: BookmarksView,
      meta: { requiresAuth: true, space: "star", title: "鲸界" }
    },
    { path: "/tools/bookmarks/star", redirect: "/tools/bookmarks" },
    {
      path: "/tools/bookmarks/kitchen",
      name: "bookmarks-kitchen",
      component: BookmarksView,
       meta: { requiresAuth: true, space: "kitchen", title: "疯狂的厨房" }
    },
    { path: "/login", name: "login", component: LoginView }
  ]
});

router.beforeEach((to) => {
  const isAuthenticated = Boolean(localStorage.getItem("wwjing_token"));

  if (to.meta.requiresAuth && !isAuthenticated) return "/login";
  if (to.name === "login" && isAuthenticated) return "/transfer";
});


export default router;
