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
       <div class="item-card__tags">
         <el-tag v-if="favoriteDetail.category" effect="plain">{{ favoriteDetail.category }}</el-tag>
         <el-tag type="info" effect="plain">{{ favoriteDetail.status === "inbox" ? "待处理" : favoriteDetail.status }}</el-tag>
       </div>
    </div>
  </el-card>
</template>
