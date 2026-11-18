<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";

const columns = ref([]);
const topics = ref([]);
const activeTopicId = ref("");
const user = ref({ name: "用户" });
const selectedCell = ref("A1");
const socket = ref(null);
const activeTopic = computed(() => topics.value.find((topic) => topic.id === activeTopicId.value));
const title = computed(() => activeTopic.value?.cells[0]?.[0] || "Book1");
const rows = computed(() => activeTopic.value?.cells.slice(2) || []);
const sheetColumns = computed(() => [
  ...columns.value,
  ...Array.from({ length: 19 }, (_, index) => "列" + String.fromCharCode(72 + index))
]);
const statusText = computed(() => `${rows.value.length} 行 · ${columns.value.length} 列 · 实时协作`);

function send(message) {
  if (socket.value?.readyState === WebSocket.OPEN) socket.value.send(JSON.stringify(message));
}

function selectTopic(topic) {
  activeTopicId.value = topic.id;
  columns.value = topic.cells[1] || [];
}

function connect() {
  const token = localStorage.getItem("wwjing_token") || "";
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  socket.value = new WebSocket(`${protocol}//${window.location.host}/api/office/ws?token=${encodeURIComponent(token)}`);
  socket.value.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    if (message.type === "snapshot") {
      user.value = message.user;
      topics.value = message.topics;
      if (topics.value[0]) selectTopic(topics.value[0]);
    } else if (message.type === "topic:created") {
      topics.value.push(message.topic);
      selectTopic(message.topic);
    } else if (message.type === "cell:updated") {
      const topic = topics.value.find((item) => item.id === message.topicId);
      if (!topic) return;
      topic.cells[message.row] ||= [];
      topic.cells[message.row][message.column] = message.value;
      topic.cellAuthors ||= {};
      topic.cellAuthors[`${message.row}:${message.column}`] = message.user;
      if (topic.id === activeTopicId.value) selectTopic(topic);
    }
  };
}

function addRow() {
  if (!activeTopic.value) return;
  const row = [activeTopic.value.cells.length - 1, "", "新事项", "", "", "", ""];
  activeTopic.value.cells.push(row);
  send({ type: "cell:update", topicId: activeTopicId.value, row: activeTopic.value.cells.length - 1, column: 2, value: row[2] });
}

function updateCell(rowIndex, cellIndex, value) {
  if (activeTopic.value) {
    activeTopic.value.cells[rowIndex + 2][cellIndex] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors[`${rowIndex + 2}:${cellIndex}`] = user.value.name;
  }
  send({ type: "cell:update", topicId: activeTopicId.value, row: rowIndex + 2, column: cellIndex, value });
}

function updateTitle(value) {
  if (activeTopic.value) {
    activeTopic.value.cells[0][0] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors["0:0"] = user.value.name;
  }
  send({ type: "cell:update", topicId: activeTopicId.value, row: 0, column: 0, value });
}

function updateHeader(cellIndex, value) {
  if (activeTopic.value) {
    activeTopic.value.cells[1][cellIndex] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors[`1:${cellIndex}`] = user.value.name;
  }
  columns.value[cellIndex] = value;
  send({ type: "cell:update", topicId: activeTopicId.value, row: 1, column: cellIndex, value });
}

function cellAuthor(rowIndex, cellIndex) {
  return activeTopic.value?.cellAuthors?.[`${rowIndex + 2}:${cellIndex}`] || "";
}

function fixedCellAuthor(rowIndex, cellIndex) {
  return activeTopic.value?.cellAuthors?.[`${rowIndex}:${cellIndex}`] || "";
}

function addTopic() {
  const name = window.prompt("新建话题", "未命名话题");
  if (name?.trim()) send({ type: "topic:create", name: name.trim() });
}

onMounted(connect);
onUnmounted(() => socket.value?.close());
</script>

<template>
  <div class="office-page">
    <header class="office-titlebar"><span class="office-app-icon">X</span><strong>{{ title }}</strong><span class="office-save">{{ user.name }}</span><span class="office-online"><span class="presence-dot"></span>已连接</span></header>
    <nav class="office-ribbon"><button>文件</button><button class="is-active">开始</button><button>插入</button><button>布局</button><button>审阅</button><span class="ribbon-separator"></span><span class="ribbon-tool">剪切</span><span class="ribbon-tool">复制</span><span class="ribbon-tool">粘贴</span><span class="ribbon-separator"></span><span class="ribbon-tool">自动换行</span><span class="ribbon-tool">筛选</span></nav>
    <section class="workbench-shell">
      <div class="sheet-panel">
        <div class="sheet-toolbar"><div class="sheet-tab"><span class="sheet-tab-icon">▦</span> 工作表</div><div class="sheet-actions"><button type="button" @click="addRow">＋ 行</button><span class="sheet-save-state">已同步</span></div></div>
        <div class="formula-bar"><span class="name-box">{{ selectedCell }}</span><span class="formula-symbol">fx</span><input value="点击单元格编辑内容" readonly aria-label="公式栏提示"></div>
        <div class="sheet-scroll"><table class="workbench-sheet"><colgroup><col class="col-row-number"><col v-for="(_, index) in sheetColumns" :key="index" :class="index < 7 ? `col-${['no', 'system', 'step', 'detail', 'rd', 'time', 'result'][index]}` : 'col-blank'"></colgroup><thead><tr class="column-letters"><th class="row-number"></th><th v-for="(_, index) in sheetColumns" :key="index">{{ String.fromCharCode(65 + index) }}</th></tr><tr class="sheet-title-row"><th class="row-number">1</th><th :colspan="sheetColumns.length" class="sheet-title-cell"><span v-if="fixedCellAuthor(0, 0)" class="cell-author">{{ fixedCellAuthor(0, 0) }}：</span><input :value="title" aria-label="表格标题" @input="updateTitle($event.target.value)"></th></tr><tr class="sheet-header"><th class="row-number">2</th><th v-for="(_, index) in sheetColumns" :key="index"><span v-if="index < 7 && fixedCellAuthor(1, index)" class="cell-author">{{ fixedCellAuthor(1, index) }}：</span><input v-if="index < 7" :value="columns[index]" :aria-label="`第 ${index + 1} 列标题`" @input="updateHeader(index, $event.target.value)"></th></tr></thead><tbody><tr v-for="(row, rowIndex) in rows" :key="rowIndex"><td class="row-number">{{ rowIndex + 3 }}</td><td v-for="(_, cellIndex) in sheetColumns" :key="cellIndex" :class="{ 'is-selected': selectedCell === `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}` }" @click="selectedCell = `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}`"><span v-if="cellAuthor(rowIndex, cellIndex)" class="cell-author">{{ cellAuthor(rowIndex, cellIndex) }}：</span><input :value="row[cellIndex] || ''" :aria-label="`${sheetColumns[cellIndex]} 第 ${rowIndex + 3} 行`" @input="updateCell(rowIndex, cellIndex, $event.target.value)"></td></tr></tbody></table></div>
        <footer class="sheet-status"><span>{{ statusText }}</span><span>◉ {{ user.name }}</span></footer>
        <div class="office-sheet-tabs"><button v-for="topic in topics" :key="topic.id" type="button" :class="{ 'is-active': topic.id === activeTopicId }" @click="selectTopic(topic)">▦ {{ topic.name }}</button><button type="button" class="add-sheet" title="新建话题" @click="addTopic">＋</button></div>
      </div>
    </section>
  </div>
</template>
