<script setup>
defineProps({
  item: {
    type: Object,
    required: true
  }
});
</script>

<template>
  <el-card class="item-card" shadow="never">
    <div class="item-card__body">
      <div>
        <h3>{{ item.title }}</h3>
        <p v-if="item.nextAction">下一步：{{ item.nextAction }}</p>
      </div>
      <el-tag effect="plain">{{ item.status === "inbox" ? "待处理" : item.status }}</el-tag>
    </div>
  </el-card>
</template>
