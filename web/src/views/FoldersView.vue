<script setup>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { ArrowRight } from "@element-plus/icons-vue";
import { createFolder, getFolders } from "../api/folders";

const router = useRouter();
const folders = ref([]);
const name = ref("");
const loading = ref(true);
const saving = ref(false);

async function loadFolders() {
  loading.value = true;
  try {
    folders.value = (await getFolders()).folders;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loading.value = false;
  }
}

async function saveFolder() {
  if (!name.value.trim()) return;
  saving.value = true;
  try {
    const result = await createFolder({ name: name.value.trim() });
    folders.value.push(result.folder);
    name.value = "";
    ElMessage.success("收藏夹已创建");
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

function openFolder(folder) {
  router.push({ name: "favorites", query: { folderId: folder.id } });
}

onMounted(loadFolders);
</script>

<template>
  <div class="page-content">
    <div class="section-heading page-title">
      <div>
        <p class="eyebrow">Folders</p>
        <h1>我的收藏夹</h1>
        <p class="lead">按主题整理收藏，让下一步更容易找到。</p>
      </div>
    </div>

    <el-card class="capture-card" shadow="never">
      <el-form @submit.prevent="saveFolder">
        <el-form-item label="新收藏夹名称">
          <el-input v-model="name" placeholder="例如：待读文章、旅行计划" @keyup.enter="saveFolder">
            <template #append>
              <el-button :loading="saving" @click="saveFolder">新建</el-button>
            </template>
          </el-input>
        </el-form-item>
      </el-form>
    </el-card>

    <div v-if="loading" class="empty-state"><el-skeleton :rows="4" animated /></div>
    <div v-else-if="!folders.length" class="empty-state">暂时没有收藏夹，先创建一个吧。</div>
    <div v-else class="folder-grid">
      <el-card v-for="folder in folders" :key="folder.id" class="folder-card" shadow="never" @click="openFolder(folder)">
        <div class="folder-card__icon">▦</div>
        <div>
          <h3>{{ folder.name }}</h3>
          <p>{{ folder.itemCount || 0 }} 条收藏</p>
        </div>
        <el-icon><ArrowRight /></el-icon>
      </el-card>
    </div>
  </div>
</template>
