<script setup>
import { onMounted, ref } from "vue";
import { getFavoriteDetails } from "../api/favorite-details";
import FavoriteDetailCard from "../components/ItemCard.vue";

const items = ref([]);

onMounted(async () => {
  items.value = (await getFavoriteDetails()).favoriteDetails;
});
</script>

<template>
  <div class="page-content">
    <section class="welcome-block">
      <p class="eyebrow">WWJ / 内容工作台</p>
      <h1>别让收藏替你假装完成。</h1>
      <p class="lead">把随手收藏的内容，变成一件有下一步、会被重新问起的事。</p>
      <el-button type="primary" size="large" @click="$router.push('/favorites')">
        查看我的收藏
      </el-button>
    </section>

    <section class="section-block">
      <div class="section-heading">
        <div>
          <p class="eyebrow">Today</p>
          <h2>先从两件事开始</h2>
        </div>
        <el-link type="primary" @click="$router.push('/favorites')">全部收藏</el-link>
      </div>
      <div class="item-grid">
        <FavoriteDetailCard v-for="favoriteDetail in items.slice(0, 2)" :key="favoriteDetail.id" :favorite-detail="favoriteDetail" />
      </div>
    </section>
  </div>
</template>
