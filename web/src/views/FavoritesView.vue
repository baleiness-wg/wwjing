<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { useRoute } from "vue-router";
import { ElMessage } from "element-plus";
import { createFavoriteDetail, getFavoriteDetails } from "../api/favorite-details";
import { getFolders } from "../api/folders";
import FavoriteDetailCard from "../components/ItemCard.vue";

const items = ref([]);
const router = useRouter();
const route = useRoute();
const saving = ref(false);
const folders = ref([]);
const form = reactive({ title: "", description: "", nextAction: "", sourceUrl: "", category: "other", folderId: null });

const categories = [
  ["shopping", "购物"], ["article", "文章"], ["video", "视频"],
  ["code", "代码"], ["link", "链接"], ["text", "普通文本"], ["other", "其他"]
];

async function loadItems() {
  items.value = (await getFavoriteDetails(route.query.folderId)).favoriteDetails;
}

async function loadFolders() {
  folders.value = (await getFolders()).folders;
}

async function pasteClipboard() {
  try {
    form.sourceUrl = await navigator.clipboard.readText();
    if (form.sourceUrl.trim()) ElMessage.success("已读取剪切板");
  } catch {
    ElMessage.error("浏览器禁止读取剪切板，请手动粘贴");
  }
}

async function saveItem() {
  if (!form.title.trim() && !form.sourceUrl.trim()) return;
  saving.value = true;

  try {
    const result = await createFavoriteDetail(form);
    items.value.unshift(result.favoriteDetail);
    form.title = "";
    form.description = "";
    form.nextAction = "";
    form.sourceUrl = "";
    form.category = "other";
    form.folderId = null;
    ElMessage.success("已收进收藏夹");
  } catch (error) {
    if (error.message.includes("Bearer") || error.message.includes("登录")) {
      await router.push("/login");
    }
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

onMounted(async () => {
  await Promise.all([loadItems(), loadFolders()]);
});
</script>

<template>
  <div class="page-content">
    <div class="section-heading page-title">
      <div>
        <p class="eyebrow">Library</p>
        <h1>收藏夹</h1>
        <p class="lead">收藏只是入口，下一步才让它真正属于你。</p>
      </div>
    </div>

    <el-card class="capture-card" shadow="never">
      <el-form label-position="top" @submit.prevent="saveItem">
        <el-form-item label="你想先收进来的内容">
          <el-input v-model="form.sourceUrl" placeholder="粘贴视频或文章链接，后台自动提取标题和简介" @keyup.enter="saveItem">
            <template #append><el-button @click="pasteClipboard">读取剪切板</el-button></template>
          </el-input>
        </el-form-item>
        <el-form-item label="标题（可选）">
          <el-input v-model="form.title" placeholder="不填写则自动使用链接标题" />
        </el-form-item>
        <el-form-item label="简介（可选）">
          <el-input v-model="form.description" type="textarea" placeholder="不填写则自动使用链接简介" />
        </el-form-item>
        <el-form-item label="下一步动作">
          <el-input v-model="form.nextAction" placeholder="例如：周末看完并写三条笔记" />
        </el-form-item>
        <div class="form-row">
          <el-form-item label="内容分类">
            <el-select v-model="form.category" class="full-width">
              <el-option v-for="category in categories" :key="category[0]" :label="category[1]" :value="category[0]" />
            </el-select>
          </el-form-item>
          <el-form-item label="保存到收藏夹">
            <el-select v-model="form.folderId" clearable placeholder="不指定收藏夹" class="full-width">
              <el-option v-for="folder in folders" :key="folder.id" :label="folder.name" :value="folder.id" />
            </el-select>
          </el-form-item>
        </div>
        <el-button type="primary" :loading="saving" @click="saveItem">加入收藏夹</el-button>
      </el-form>
    </el-card>

    <section class="section-block">
      <div class="section-heading">
        <h2>{{ route.query.folderId ? "收藏夹内容" : "所有收藏" }}</h2>
        <span class="muted">{{ items.length }} 条</span>
      </div>
      <div class="item-grid">
        <FavoriteDetailCard v-for="favoriteDetail in items" :key="favoriteDetail.id" :favorite-detail="favoriteDetail" />
      </div>
    </section>
  </div>
</template>
