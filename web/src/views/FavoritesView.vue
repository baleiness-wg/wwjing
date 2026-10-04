<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { createFavoriteDetail, getFavoriteDetails } from "../api/favorite-details";
import FavoriteDetailCard from "../components/ItemCard.vue";

const items = ref([]);
const router = useRouter();
const saving = ref(false);
const form = reactive({ title: "", description: "", nextAction: "", sourceUrl: "" });

async function loadItems() {
  items.value = (await getFavoriteDetails()).favoriteDetails;
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

onMounted(loadItems);
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
          <el-input v-model="form.sourceUrl" placeholder="粘贴视频或文章链接，后台自动提取标题和简介" @keyup.enter="saveItem" />
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
        <el-button type="primary" :loading="saving" @click="saveItem">加入收藏夹</el-button>
      </el-form>
    </el-card>

    <section class="section-block">
      <div class="section-heading">
        <h2>所有收藏</h2>
        <span class="muted">{{ items.length }} 条</span>
      </div>
      <div class="item-grid">
        <FavoriteDetailCard v-for="favoriteDetail in items" :key="favoriteDetail.id" :favorite-detail="favoriteDetail" />
      </div>
    </section>
  </div>
</template>
