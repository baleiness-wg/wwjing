<script setup>
defineProps({
  favoriteDetail: {
    type: Object,
    required: true
  }
});
</script>

<template>
  <el-card class="item-card" shadow="never">
    <div class="item-card__body">
      <div>
        <h3>{{ favoriteDetail.title }}</h3>
        <p v-if="favoriteDetail.description">{{ favoriteDetail.description }}</p>
        <p v-if="favoriteDetail.nextAction">下一步：{{ favoriteDetail.nextAction }}</p>
        <a v-if="favoriteDetail.sourceUrl" :href="favoriteDetail.sourceUrl" target="_blank" rel="noreferrer">打开来源</a>
      </div>
      <el-tag effect="plain">{{ favoriteDetail.status === "inbox" ? "待处理" : favoriteDetail.status }}</el-tag>
    </div>
  </el-card>
</template>
