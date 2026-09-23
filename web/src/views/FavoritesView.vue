<script setup>
import { onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { ElMessage } from "element-plus";
import { createItem, getItems } from "../api/items";
import ItemCard from "../components/ItemCard.vue";

const items = ref([]);
const router = useRouter();
const saving = ref(false);
const form = reactive({ title: "", nextAction: "", sourceUrl: "" });

async function loadItems() {
  items.value = (await getItems()).items;
}

async function saveItem() {
  if (!form.title.trim()) return;
  saving.value = true;

  try {
    const result = await createItem(form);
    items.value.unshift(result.item);
    form.title = "";
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
          <el-input v-model="form.title" placeholder="例如：一个值得实践的产品方法" @keyup.enter="saveItem" />
        </el-form-item>
        <div class="form-row">
          <el-form-item label="下一步动作">
            <el-input v-model="form.nextAction" placeholder="例如：周末看完并写三条笔记" />
          </el-form-item>
          <el-form-item label="来源链接（可选）">
            <el-input v-model="form.sourceUrl" placeholder="https://..." />
          </el-form-item>
        </div>
        <el-button type="primary" :loading="saving" @click="saveItem">加入收藏夹</el-button>
      </el-form>
    </el-card>

    <section class="section-block">
      <div class="section-heading">
        <h2>所有收藏</h2>
        <span class="muted">{{ items.length }} 条</span>
      </div>
      <div class="item-grid">
        <ItemCard v-for="item in items" :key="item.id" :item="item" />
      </div>
    </section>
  </div>
</template>
