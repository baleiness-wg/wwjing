<script setup>
const tools = [
  {
    name: "数据传输",
    description: "在同一个账号的不同设备之间传递文件和文字。",
    path: "/tools/transfer",
  },
];
</script>

<template>
  <div class="page-content">
    <div class="section-heading page-title">
      <div>
        <p class="eyebrow">工具</p>
        <h1>工具</h1>
        <p class="lead">选择一个工具开始使用。</p>
      </div>
    </div>

    <div class="tool-grid">
      <el-card v-for="tool in tools" :key="tool.name" class="tool-card" shadow="never" @click="$router.push(tool.path)">
        <div class="tool-card__icon">T</div>
        <div>
          <h3>{{ tool.name }}</h3>
          <p>{{ tool.description }}</p>
        </div>
      </el-card>
    </div>
  </div>
</template>
