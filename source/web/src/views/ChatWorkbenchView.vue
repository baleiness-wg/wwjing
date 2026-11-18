<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import { changePassword } from "../api/auth";

const columns = ref([]);
const topics = ref([]);
const activeTopicId = ref("");
const user = ref({ name: "用户" });
const selectedCell = ref("A1");
const socket = ref(null);
const columnWidths = ref([58, 58, 180, 380, 58, 58, 58, ...Array(19).fill(58)]);
const resizingColumn = ref(null);
const resizeStartX = ref(0);
const resizeStartWidth = ref(0);
const rowHeights = ref({});
const resizingRow = ref(null);
const resizeStartY = ref(0);
const resizeStartHeight = ref(28);
const activeTopic = computed(() => topics.value.find((topic) => topic.id === activeTopicId.value));
const title = computed(() => activeTopic.value?.cells[0]?.[0] || "Book1");
const rows = computed(() => activeTopic.value?.cells.slice(2) || []);
const sheetColumns = computed(() => [
  ...columns.value,
  ...Array.from({ length: 19 }, (_, index) => "列" + String.fromCharCode(72 + index))
]);

function beginResize(index, event) {
  event.preventDefault();
  resizingColumn.value = index;
  resizeStartX.value = event.clientX;
  resizeStartWidth.value = columnWidths.value[index] || 58;
  window.addEventListener("mousemove", resizeColumn);
  window.addEventListener("mouseup", endResize);
}

function resizeColumn(event) {
  if (resizingColumn.value === null) return;
  columnWidths.value[resizingColumn.value] = Math.max(42, resizeStartWidth.value + event.clientX - resizeStartX.value);
}

function endResize() {
  resizingColumn.value = null;
  window.removeEventListener("mousemove", resizeColumn);
  window.removeEventListener("mouseup", endResize);
}

function beginRowResize(rowIndex, event) {
  event.preventDefault();
  resizingRow.value = rowIndex;
  resizeStartY.value = event.clientY;
  resizeStartHeight.value = rowHeights.value[rowIndex] || 28;
  window.addEventListener("mousemove", resizeRow);
  window.addEventListener("mouseup", endRowResize);
}

function resizeRow(event) {
  if (resizingRow.value === null) return;
  rowHeights.value[resizingRow.value] = Math.max(22, resizeStartHeight.value + event.clientY - resizeStartY.value);
}

function endRowResize() {
  resizingRow.value = null;
  window.removeEventListener("mousemove", resizeRow);
  window.removeEventListener("mouseup", endRowResize);
}
const statusText = computed(() => `${rows.value.length} 行 · ${columns.value.length} 列 · 实时协作`);
const connectionText = ref("连接中");
const editingCell = ref(null);
const cellLocks = ref({});
const passwordDialogVisible = ref(false);
const passwordLoading = ref(false);
const passwordForm = reactive({ currentPassword: "", newPassword: "", confirmPassword: "" });
let snapshotTimer;

function send(message) {
  if (socket.value?.readyState === WebSocket.OPEN) socket.value.send(JSON.stringify(message));
}

function cellKey(row, column) {
  return `${activeTopicId.value}:${row}:${column}`;
}

function beginCellEdit(row, column) {
  const key = cellKey(row, column);
  if (cellLocks.value[key] && cellLocks.value[key] !== user.value.name) return false;
  editingCell.value = key;
  cellLocks.value[key] = user.value.name;
  send({ type: "cell:lock", topicId: activeTopicId.value, row, column });
  return true;
}

function endCellEdit(row, column, value) {
  updateCell(row - 2, column, value, true);
  const key = cellKey(row, column);
  delete cellLocks.value[key];
  editingCell.value = null;
  send({ type: "cell:unlock", topicId: activeTopicId.value, row, column });
}

async function updateCellFallback(topicId, row, column, value) {
  await fetch("/api/office/cell", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: localStorage.getItem("wwjing_token") || ""
    },
    body: JSON.stringify({ topicId, row, column, value })
  }).catch(() => {});
}

function selectTopic(topic) {
  activeTopicId.value = topic.id;
  columns.value = topic.cells[1] || [];
}

function connect() {
  const token = localStorage.getItem("wwjing_token") || "";
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  socket.value = new WebSocket(`${protocol}//${window.location.host}/api/office/ws?token=${encodeURIComponent(token)}`);
  socket.value.onopen = () => { connectionText.value = "实时"; };
  socket.value.onerror = () => { connectionText.value = "已加载"; };
  socket.value.onclose = () => { connectionText.value = "离线"; };
  socket.value.onmessage = ({ data }) => {
    const message = JSON.parse(data);
      if (message.type === "snapshot") {
        user.value = message.user;
        topics.value = message.topics;
        cellLocks.value = message.locks || {};
        if (topics.value[0]) selectTopic(topics.value[0]);
      } else if (message.type === "cell:lock" || message.type === "cell:unlock") {
        if (message.type === "cell:lock") cellLocks.value[message.key] = message.user;
        else delete cellLocks.value[message.key];
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

function updateCell(rowIndex, cellIndex, value, sync = true) {
  editingCell.value = `${activeTopicId.value}:${rowIndex + 2}:${cellIndex}`;
  if (activeTopic.value) {
    activeTopic.value.cells[rowIndex + 2][cellIndex] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors[`${rowIndex + 2}:${cellIndex}`] = user.value.name;
  }
  if (sync) return;
}

function flushEditingCell() {
  if (!editingCell.value || !activeTopic.value) return;
  const [, row, column] = editingCell.value.split(":").map(Number);
  const value = activeTopic.value.cells[row]?.[column] || "";
  send({ type: "cell:update", topicId: activeTopicId.value, row, column, value });
  updateCellFallback(activeTopicId.value, row, column, value);
  delete cellLocks.value[editingCell.value];
  send({ type: "cell:unlock", topicId: activeTopicId.value, row, column });
  editingCell.value = null;
}

function handleFocusOut() {
  if (document.activeElement?.tagName !== "INPUT") flushEditingCell();
}

function updateTitle(value) {
  if (activeTopic.value) {
    activeTopic.value.cells[0][0] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors["0:0"] = user.value.name;
  }
  send({ type: "cell:update", topicId: activeTopicId.value, row: 0, column: 0, value });
  updateCellFallback(activeTopicId.value, 0, 0, value);
}

function updateHeader(cellIndex, value) {
  if (activeTopic.value) {
    activeTopic.value.cells[1][cellIndex] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors[`1:${cellIndex}`] = user.value.name;
  }
  columns.value[cellIndex] = value;
  send({ type: "cell:update", topicId: activeTopicId.value, row: 1, column: cellIndex, value });
  updateCellFallback(activeTopicId.value, 1, cellIndex, value);
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

function logout() {
  socket.value?.close();
  window.clearInterval(snapshotTimer);
  localStorage.removeItem("wwjing_token");
  localStorage.removeItem("wwjing_user");
  sessionStorage.setItem("office_login_return", "/office");
  window.location.href = `${import.meta.env.BASE_URL}login`;
}

function openPasswordDialog() {
  Object.assign(passwordForm, { currentPassword: "", newPassword: "", confirmPassword: "" });
  passwordDialogVisible.value = true;
}

async function submitPassword() {
  if (!passwordForm.currentPassword || !passwordForm.newPassword || !passwordForm.confirmPassword) return ElMessage.warning("请填写完整密码信息");
  if (passwordForm.newPassword !== passwordForm.confirmPassword) return ElMessage.warning("两次输入的新密码不一致");
  passwordLoading.value = true;
  try {
    await changePassword(passwordForm);
    ElMessage.success("密码修改成功，请重新登录");
    passwordDialogVisible.value = false;
    logout();
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    passwordLoading.value = false;
  }
}

onMounted(connect);
onMounted(() => document.addEventListener("focusout", handleFocusOut, true));
onMounted(async () => {
  try {
    const response = await fetch("/api/office/snapshot", { headers: { Authorization: localStorage.getItem("wwjing_token") || "" } });
    if (!response.ok) return;
    const snapshot = await response.json();
    user.value = snapshot.user;
    topics.value = snapshot.topics;
    cellLocks.value = snapshot.locks || {};
    if (topics.value[0] && !activeTopicId.value) selectTopic(topics.value[0]);
    snapshotTimer = window.setInterval(async () => {
      const poll = await fetch("/api/office/snapshot", { headers: { Authorization: localStorage.getItem("wwjing_token") || "" } }).catch(() => null);
      if (!poll?.ok) return;
      if (editingCell.value || document.activeElement?.tagName === "INPUT") return;
      const latest = await poll.json();
      topics.value = latest.topics;
      user.value = latest.user;
      cellLocks.value = latest.locks || {};
      const current = topics.value.find((topic) => topic.id === activeTopicId.value) || topics.value[0];
      if (current) selectTopic(current);
    }, 2000);
  } catch {
    connectionText.value = "离线";
  }
});
onUnmounted(() => {
  socket.value?.close();
  window.clearInterval(snapshotTimer);
  endResize();
  endRowResize();
  document.removeEventListener("focusout", handleFocusOut, true);
});
</script>

<template>
  <div class="office-page">
    <header class="office-titlebar"><span class="office-app-icon">X</span><strong>{{ title }}</strong><span class="office-online"><span class="presence-dot"></span>{{ connectionText }}</span><el-dropdown class="office-user-menu" @command="(command) => command === 'password' ? openPasswordDialog() : logout()"><button type="button" class="office-user">{{ user.name }}⌄</button><template #dropdown><el-dropdown-menu><el-dropdown-item command="password">修改密码</el-dropdown-item><el-dropdown-item command="logout">退出登录</el-dropdown-item></el-dropdown-menu></template></el-dropdown></header>
    <nav class="office-ribbon"><button>文件</button><button class="is-active">开始</button><button>插入</button><button>布局</button><button>审阅</button><span class="ribbon-separator"></span><span class="ribbon-tool">剪切</span><span class="ribbon-tool">复制</span><span class="ribbon-tool">粘贴</span><span class="ribbon-separator"></span><span class="ribbon-tool">自动换行</span><span class="ribbon-tool">筛选</span></nav>
    <section class="workbench-shell">
      <div class="sheet-panel">
        <div class="sheet-toolbar"><div class="sheet-tab"><span class="sheet-tab-icon">▦</span> 工作表</div><div class="sheet-actions"><button type="button" @click="addRow">＋ 行</button><span class="sheet-save-state">已同步</span></div></div>
        <div class="formula-bar"><span class="name-box">{{ selectedCell }}</span><span class="formula-symbol">fx</span><input value="点击单元格编辑内容" readonly aria-label="公式栏提示"></div>
        <div class="sheet-scroll"><table class="workbench-sheet"><colgroup><col class="col-row-number"><col v-for="(_, index) in sheetColumns" :key="index" :style="{ width: `${columnWidths[index]}px` }"></colgroup><thead><tr class="column-letters" :style="{ height: `${rowHeights.letters || 26}px` }"><th class="row-number"></th><th v-for="(_, index) in sheetColumns" :key="index">{{ String.fromCharCode(65 + index) }}<span class="column-resize-handle" @mousedown="beginResize(index, $event)"></span><span class="row-resize-handle" @mousedown="beginRowResize(0, $event)"></span></th></tr><tr class="sheet-title-row" :style="{ height: `${rowHeights.title || 30}px` }"><th class="row-number">1</th><th :colspan="sheetColumns.length" class="sheet-title-cell"><span v-if="fixedCellAuthor(0, 0)" class="cell-author">{{ fixedCellAuthor(0, 0) }}：</span><input :value="title" aria-label="表格标题" @input="updateTitle($event.target.value)"><span class="row-resize-handle" @mousedown="beginRowResize(1, $event)"></span></th></tr><tr class="sheet-header" :style="{ height: `${rowHeights.header || 28}px` }"><th class="row-number">2</th><th v-for="(_, index) in sheetColumns" :key="index"><span v-if="index < 7 && fixedCellAuthor(1, index)" class="cell-author">{{ fixedCellAuthor(1, index) }}：</span><input v-if="index < 7" :value="columns[index]" :aria-label="`第 ${index + 1} 列标题`" @input="updateHeader(index, $event.target.value)"></th></tr></thead><tbody><tr v-for="(row, rowIndex) in rows" :key="rowIndex" :style="{ height: `${rowHeights[rowIndex + 2] || 28}px` }"><td class="row-number">{{ rowIndex + 3 }}</td><td v-for="(_, cellIndex) in sheetColumns" :key="cellIndex" :class="{ 'is-selected': selectedCell === `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}` }" @click="selectedCell = `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}`"><span v-if="cellAuthor(rowIndex, cellIndex)" class="cell-author">{{ cellAuthor(rowIndex, cellIndex) }}：</span><input :value="row[cellIndex] || ''" :aria-label="`${sheetColumns[cellIndex]} 第 ${rowIndex + 3} 行`" @input="updateCell(rowIndex, cellIndex, $event.target.value)"><span class="row-resize-handle" @mousedown="beginRowResize(rowIndex + 2, $event)"></span></td></tr></tbody></table></div>
        <footer class="sheet-status"><span>{{ statusText }}</span><span>◉ {{ user.name }}</span></footer>
        <div class="office-sheet-tabs"><button v-for="topic in topics" :key="topic.id" type="button" :class="{ 'is-active': topic.id === activeTopicId }" @click="selectTopic(topic)">▦ {{ topic.name }}</button><button type="button" class="add-sheet" title="新建话题" @click="addTopic">＋</button></div>
      </div>
    </section>
    <el-dialog v-model="passwordDialogVisible" title="修改密码" width="min(92vw, 420px)"><el-form label-position="top" @submit.prevent="submitPassword"><el-form-item label="当前密码"><el-input v-model="passwordForm.currentPassword" type="password" show-password /></el-form-item><el-form-item label="新密码"><el-input v-model="passwordForm.newPassword" type="password" show-password /></el-form-item><el-form-item label="确认新密码"><el-input v-model="passwordForm.confirmPassword" type="password" show-password @keyup.enter="submitPassword" /></el-form-item></el-form><template #footer><el-button @click="passwordDialogVisible = false">取消</el-button><el-button type="primary" :loading="passwordLoading" @click="submitPassword">确认修改</el-button></template></el-dialog>
  </div>
</template>
