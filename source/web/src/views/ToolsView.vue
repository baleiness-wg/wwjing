<script setup>
const regularTools = [
  {
    name: "数据传输",
    description: "在同一个账号的不同设备之间传递文件和文字。",
    path: "/tools/transfer",
    icon: "T"
  }
];

const bookmarkTools = [
  {
    name: "疯狂的厨房",
    description: "分类保存菜谱与做饭链接，支持今天吃什么随机抽取菜谱。",
    path: "/tools/bookmarks/kitchen",
    icon: "厨"
  },
  {
    name: "鲸界",
    description: "通用图文与全网网页链接收藏，跨端多层级目录集中整理。",
    path: "/tools/bookmarks/star",
    icon: "鲸"
  }
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

    <div class="section-block">
      <div class="tool-grid">
        <el-card
          v-for="tool in regularTools"
          :key="tool.name"
          class="tool-card"
          shadow="never"
          @click="$router.push(tool.path)"
        >
          <div class="tool-card__icon">{{ tool.icon }}</div>
          <div>
            <h3>{{ tool.name }}</h3>
            <p>{{ tool.description }}</p>
          </div>
        </el-card>
      </div>
    </div>

    <div class="section-block" style="margin-top: 32px;">
      <div class="section-heading" style="margin-bottom: 14px;">
        <div>
          <h2>收藏夹</h2>
          <p class="muted" style="margin-top: 4px;">多空间链接收藏与整理目录。</p>
        </div>
      </div>
      <div class="tool-grid">
        <el-card
          v-for="tool in bookmarkTools"
          :key="tool.name"
          class="tool-card"
          shadow="never"
          @click="$router.push(tool.path)"
        >
          <div class="tool-card__icon">{{ tool.icon }}</div>
          <div>
            <h3>{{ tool.name }}</h3>
            <p>{{ tool.description }}</p>
          </div>
        </el-card>
      </div>
    </div>
  </div>
</template>
