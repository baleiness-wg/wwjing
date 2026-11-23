<script setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from "vue";
import { ElMessage } from "element-plus";
import { changePassword } from "../api/auth";

const columns = ref([]);
const topics = ref([]);
const rooms = ref([]);
const activeRoomId = ref(localStorage.getItem("office_active_room") || "");
const pendingRoomId = ref("");
const roomListCollapsed = ref(true);
const roomPassword = ref(localStorage.getItem(`office_room_password:${activeRoomId.value}`) || "");

const officeHeaderName = () => encodeURIComponent(currentDisplayName.value);
const roomDialogVisible = ref(false);
const roomDialogMode = ref("enter");
const roomName = ref("");
const activeTopicId = ref("");
const user = ref({ name: "用户" });
const guestName = ref(localStorage.getItem("office_guest_name") || `游客${Math.floor(100 + Math.random() * 900)}`);
const displayName = ref(localStorage.getItem("office_display_name") || "");
const currentDisplayName = computed(() => displayName.value || guestName.value);
const defaultDocumentTitle = document.title || "鲸界";
let titleFlashTimer;
let titleFlashIndex = 0;
let hasUnreadOfficeNotice = false;
const officeChannel = typeof BroadcastChannel !== "undefined" ? new BroadcastChannel("wwjing-office-events") : null;
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
const activeRoomName = computed(() => rooms.value.find((room) => room.id === activeRoomId.value)?.name || "未进入房间");
const title = computed(() => activeTopic.value?.cells[0]?.[0] || "Book1");
const rows = computed(() => (activeTopic.value?.cells.slice(2) || []).map((row, rowIndex) => row.map((value, columnIndex) => {
  const draftKey = `${activeTopicId.value}:${rowIndex + 2}:${columnIndex}`;
  return Object.prototype.hasOwnProperty.call(drafts, draftKey) ? drafts[draftKey] : value;
})));
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
  if (resizingColumn.value !== null) send({ type: "column:resize", index: resizingColumn.value, width: columnWidths.value[resizingColumn.value] });
  resizingColumn.value = null;
  window.removeEventListener("mousemove", resizeColumn);
  window.removeEventListener("mouseup", endResize);
}

function fitColumnWidth(index, broadcast = true) {
  const values = [columns.value[index] || ""];
  topics.value.forEach((topic) => topic.cells?.forEach((row, rowIndex) => {
    const value = row?.[index] == null ? "" : String(row[index]);
    const author = topic.cellAuthors?.[`${rowIndex}:${index}`];
    const editedAt = topic.cellEditedAt?.[`${rowIndex}:${index}`];
    const time = editedAt ? formatEditedAt(editedAt) : "";
    values.push(`${author ? `${author} ` : ""}${time ? `${time} ` : ""}${value}`);
  }));
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  context.font = "12px Arial, Microsoft YaHei, sans-serif";
  const longest = Math.max(...values.map((value) => context.measureText(value).width), 42);
  const width = Math.min(800, Math.max(42, Math.ceil(longest + 88)));
  columnWidths.value[index] = width;
  if (broadcast) send({ type: "column:resize", index, width });
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

function syncCellLockBadges() {
  nextTick(() => {
    document.querySelectorAll(".workbench-sheet tbody tr").forEach((rowElement, rowIndex) => {
      rowElement.querySelectorAll("td:not(.row-number)").forEach((cellElement, columnIndex) => {
        const editor = cellLocks.value[`${activeTopicId.value}:${rowIndex + 2}:${columnIndex}`];
        if (editor && editor !== currentDisplayName.value) cellElement.dataset.editor = editor;
        else delete cellElement.dataset.editor;
        const key = `${activeTopicId.value}:${rowIndex + 2}:${columnIndex}`;
        if (unreadCells.value[key]) cellElement.dataset.unread = "true";
        else delete cellElement.dataset.unread;
      });
    });
  });
}

const lockedCellDetails = computed(() => Object.entries(cellLocks.value)
  .filter(([, name]) => name && name !== currentDisplayName.value)
  .map(([key, name]) => {
    const [, row, column] = key.split(":");
    return `${name} · ${String.fromCharCode(65 + Number(column))}${Number(row) + 1}`;
  }));
const connectionText = ref("连接中");
const editingCell = ref(null);
const editingOriginalValue = ref("");
const editingLockSent = ref(false);
const cellLocks = ref({});
const unreadCells = ref({});
const drafts = reactive({});
const pendingLocalValues = reactive({});
const pendingUpdates = reactive({});
const saveState = ref("已同步");
const passwordDialogVisible = ref(false);
const passwordLoading = ref(false);
const passwordForm = reactive({ currentPassword: "", newPassword: "", confirmPassword: "" });
watch(cellLocks, syncCellLockBadges, { deep: true });
watch(unreadCells, syncCellLockBadges, { deep: true });
watch(activeTopicId, syncCellLockBadges);
let snapshotTimer;
let snapshotSequence = 0;
let snapshotRequestId = 0;
let lastSnapshotRevision = null;
let reconnectTimer;
let reconnectDelay = 1000;

function send(message) {
  if (socket.value?.readyState === WebSocket.OPEN) socket.value.send(JSON.stringify(message));
}

function isOwnAuthor(author) {
  if (!author) return true;
  const savedUser = JSON.parse(localStorage.getItem("wwjing_user") || "null");
  return new Set([currentDisplayName.value, user.value.name, guestName.value, displayName.value, savedUser?.username])
    .has(author);
}

function notifyOffice(message, body) {
  if (isOwnAuthor(message.user)) return;
  officeChannel?.postMessage({ user: message.user, body, source: currentDisplayName.value, at: Date.now() });
  ElMessage.info(`${message.user}：${body}`);
  flashDocumentTitle(message.user, body);
  if (document.visibilityState !== "visible" && "Notification" in window && Notification.permission === "granted") {
    new Notification("Office 协作", { body: `${message.user}：${body}` });
  }
}

function flashDocumentTitle(author, body) {
  if (document.visibilityState === "visible") return;
  hasUnreadOfficeNotice = true;
  window.clearInterval(titleFlashTimer);
  titleFlashIndex = 0;
  const alertTitle = `● ${author}：${body}`;
  titleFlashTimer = window.setInterval(() => {
    document.title = titleFlashIndex++ % 2 === 0 ? alertTitle : defaultDocumentTitle;
  }, 700);
}

function clearOfficeTitleNotice() {
  if (document.visibilityState !== "visible" || !hasUnreadOfficeNotice) return;
  hasUnreadOfficeNotice = false;
  window.clearInterval(titleFlashTimer);
  document.title = defaultDocumentTitle;
}

function notifyFromOtherTab(event) {
  const { user: author, body, source } = event.data || {};
  if (isOwnAuthor(author) || isOwnAuthor(source)) return;
  if (document.visibilityState !== "visible" && "Notification" in window && Notification.permission === "granted") {
    new Notification("Office 协作", { body: `${author}：${body}` });
  } else {
    ElMessage.info(`${author}：${body}`);
  }
  flashDocumentTitle(author, body);
}

function notifySnapshotUpdate(snapshot) {
  if (lastSnapshotRevision === null) {
    lastSnapshotRevision = snapshot.revision;
    return;
  }
  if (snapshot.revision === lastSnapshotRevision) return;
  lastSnapshotRevision = snapshot.revision;
  const latest = snapshot.topics
    ?.flatMap((topic) => Object.entries(topic.cellEditedAt || {}).map(([key, editedAt]) => ({ topic, key, editedAt, user: topic.cellAuthors?.[key] })))
    .filter((entry) => !isOwnAuthor(entry.user))
    .sort((a, b) => Number(b.editedAt || 0) - Number(a.editedAt || 0))[0];
  if (latest) notifyOffice({ user: latest.user }, "已完成编辑");
}

function requestOfficeNotifications() {
  if ("Notification" in window && Notification.permission === "default") Notification.requestPermission();
}

function updateLockFallback(row, column, locked) {
  return fetch("/api/office/lock", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "",
      "X-Office-Guest": encodeURIComponent(guestName.value),
      "X-Office-Display-Name": officeHeaderName(),
      "X-Office-Room": activeRoomId.value,
      "X-Office-Password": roomPassword.value
    },
    body: JSON.stringify({ topicId: activeTopicId.value, row, column, locked })
  }).catch(() => {});
}

function cellKey(row, column) {
  return `${activeTopicId.value}:${row}:${column}`;
}

function markCellRead(key) {
  delete unreadCells.value[key];
}

function beginCellEdit(row, column) {
  const key = cellKey(row, column);
  if (cellLocks.value[key] && cellLocks.value[key] !== currentDisplayName.value) return false;
  editingCell.value = key;
  editingOriginalValue.value = activeTopic.value?.cells?.[row]?.[column] || "";
  drafts[key] = editingOriginalValue.value;
  editingLockSent.value = false;
  return true;
}

function endCellEdit(row, column, value) {
  updateCell(row - 2, column, value, true);
  const key = cellKey(row, column);
  delete cellLocks.value[key];
  editingCell.value = null;
  send({ type: "cell:unlock", topicId: activeTopicId.value, row, column });
  updateLockFallback(row, column, false);
}

async function updateCellFallback(topicId, row, column, value) {
  const response = await fetch("/api/office/cell", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "",
      "X-Office-Guest": encodeURIComponent(guestName.value)
      ,"X-Office-Display-Name": officeHeaderName()
      ,"X-Office-Room": activeRoomId.value
      ,"X-Office-Password": roomPassword.value
    },
    body: JSON.stringify({ topicId, row, column, value })
  }).catch(() => null);
  return Boolean(response?.ok);
}

function selectTopic(topic) {
  if (!topic || !Array.isArray(topic.cells) || topic.cells.length < 3) return;
  activeTopicId.value = topic.id;
  columns.value = topic.cells[1] || [];
}

async function loadSnapshotForCurrentRoom() {
  if (!activeRoomId.value) return;
  const sequence = ++snapshotSequence;
  const roomId = activeRoomId.value;
  const response = await fetch("/api/office/snapshot", {
    cache: "no-store",
    headers: {
      Authorization: "",
      "X-Office-Room": roomId,
      "X-Office-Password": roomPassword.value
    }
  }).catch(() => null);
  if (!response?.ok || sequence !== snapshotSequence || roomId !== activeRoomId.value) return;
  const snapshot = await response.json();
  notifySnapshotUpdate(snapshot);
  snapshot.topics?.forEach((topic) => {
    topic.cells?.forEach((row, rowIndex) => row?.forEach((value, columnIndex) => {
      const localKey = `${topic.id}:${rowIndex}:${columnIndex}`;
      if (Object.prototype.hasOwnProperty.call(pendingLocalValues, localKey)) {
        if (String(value ?? "") === pendingLocalValues[localKey]) delete pendingLocalValues[localKey];
        else topic.cells[rowIndex][columnIndex] = pendingLocalValues[localKey];
      }
    }));
  });
  if (!snapshot.topics?.[0]?.cells?.length) {
    ElMessage.error("房间没有可用表格数据");
    return;
  }
  user.value = snapshot.user;
  topics.value = snapshot.topics;
  cellLocks.value = snapshot.locks || {};
  if (editingCell.value) cellLocks.value[editingCell.value] = currentDisplayName.value;
  columnWidths.value = snapshot.columnWidths || columnWidths.value;
  selectTopic(snapshot.topics[0]);
}

function connect() {
  if (!activeRoomId.value) return;
  if (socket.value?.readyState === WebSocket.OPEN || socket.value?.readyState === WebSocket.CONNECTING) return;
  const token = "";
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  socket.value = new WebSocket(`${protocol}//${window.location.host}/api/office/ws?token=${encodeURIComponent(token)}&guest=${encodeURIComponent(guestName.value)}&displayName=${encodeURIComponent(displayName.value)}&roomId=${encodeURIComponent(activeRoomId.value)}&password=${encodeURIComponent(roomPassword.value)}`);
  socket.value.onopen = () => { reconnectDelay = 1000; connectionText.value = "实时"; };
  socket.value.onerror = () => { connectionText.value = "已加载"; };
  socket.value.onclose = (event) => {
    if (pendingRoomId.value && event.code === 4003) {
      localStorage.removeItem(`office_room_password:${pendingRoomId.value}`);
      roomPassword.value = "";
      roomDialogVisible.value = true;
      ElMessage.error("房间密码错误，无法进入");
      pendingRoomId.value = "";
      return;
    }
    connectionText.value = "轮询";
    window.clearTimeout(reconnectTimer);
    reconnectTimer = window.setTimeout(connect, reconnectDelay);
    reconnectDelay = Math.min(reconnectDelay * 2, 10000);
  };
  socket.value.onmessage = ({ data }) => {
    const message = JSON.parse(data);
      if (message.type === "snapshot") {
        user.value = { ...message.user, name: currentDisplayName.value };
        topics.value = message.topics;
        cellLocks.value = message.locks || {};
        columnWidths.value = message.columnWidths || columnWidths.value;
        if (topics.value[0]) selectTopic(topics.value[0]);
      } else if (message.type === "column:resized") {
        columnWidths.value[message.index] = message.width;
      } else if (message.type === "cell:editing" || message.type === "cell:editing-end") {
        if (message.type === "cell:editing") cellLocks.value[message.key] = message.user;
        else delete cellLocks.value[message.key];
    } else if (message.type === "cell:lock-rejected") {
      if (editingCell.value === message.key) editingCell.value = null;
      ElMessage.warning(`${message.user || "其他用户"}正在编辑此单元格`);
    } else if (message.type === "cell:update:ack") {
      if (pendingUpdates[message.requestId]) delete pendingUpdates[message.requestId];
      saveState.value = "已同步";
    } else if (message.type === "cell:update:rejected") {
      if (pendingUpdates[message.requestId]) delete pendingUpdates[message.requestId];
      saveState.value = "保存失败";
      ElMessage.error(`${message.user || "其他用户"}已占用此单元格，内容未覆盖`);
      } else if (message.type === "topic:created") {
        topics.value.push(message.topic);
        selectTopic(message.topic);
      if (message.user !== currentDisplayName.value) notifyOffice({ user: message.user }, `新建了话题“${message.topic.name}”`);
    } else if (message.type === "cell:draft") {
      const topic = topics.value.find((item) => item.id === message.topicId);
      if (!topic || editingCell.value === `${message.topicId}:${message.row}:${message.column}`) return;
      topic.cells[message.row] ||= [];
      topic.cells[message.row][message.column] = message.value;
      } else if (message.type === "cell:draft") {
        const topic = topics.value.find((item) => item.id === message.topicId);
        if (!topic || editingCell.value === `${message.topicId}:${message.row}:${message.column}`) return;
        topic.cells[message.row] ||= [];
        topic.cells[message.row][message.column] = message.value;
        topic.cellAuthors ||= {};
        topic.cellAuthors[`${message.row}:${message.column}`] = message.user;
      } else if (message.type === "cell:updated") {
      notifyOffice(message, "已完成编辑");
      const topic = topics.value.find((item) => item.id === message.topicId);
      if (!topic) return;
      topic.cells[message.row] ||= [];
      topic.cells[message.row][message.column] = message.value;
      if (message.user !== currentDisplayName.value) unreadCells.value[`${message.topicId}:${message.row}:${message.column}`] = true;
      fitColumnWidth(message.column, false);
      topic.cellAuthors ||= {};
      if (String(message.value || "").trim()) topic.cellAuthors[`${message.row}:${message.column}`] = message.user;
      else delete topic.cellAuthors[`${message.row}:${message.column}`];
      topic.cellEditedAt ||= {};
      if (message.editedAt) topic.cellEditedAt[`${message.row}:${message.column}`] = message.editedAt;
      else delete topic.cellEditedAt[`${message.row}:${message.column}`];
      if (topic.id === activeTopicId.value && editingCell.value !== `${message.topicId}:${message.row}:${message.column}`) selectTopic(topic);
    }
  };
}

function currentIdentity() {
  const savedUser = JSON.parse(localStorage.getItem("wwjing_user") || "null");
  return savedUser?.username || guestName.value;
}

function addRow() {
  if (!activeTopic.value) return;
  const row = [activeTopic.value.cells.length - 1, "", "新事项", "", "", "", ""];
  activeTopic.value.cells.push(row);
  send({ type: "cell:update", topicId: activeTopicId.value, row: activeTopic.value.cells.length - 1, column: 2, value: row[2] });
}

function updateCell(rowIndex, cellIndex, value, sync = true) {
  const key = `${activeTopicId.value}:${rowIndex + 2}:${cellIndex}`;
  if (editingCell.value !== key) beginCellEdit(rowIndex + 2, cellIndex);
  if (!editingLockSent.value) {
    if (cellLocks.value[key] && cellLocks.value[key] !== currentDisplayName.value) return;
    editingLockSent.value = true;
    cellLocks.value[key] = currentDisplayName.value;
    send({ type: "cell:lock", topicId: activeTopicId.value, row: rowIndex + 2, column: cellIndex });
  }
  drafts[key] = value;
  send({ type: "cell:draft", topicId: activeTopicId.value, row: rowIndex + 2, column: cellIndex, value });
}

async function flushEditingCell() {
  if (!editingCell.value || !activeTopic.value) return;
  const [, row, column] = editingCell.value.split(":").map(Number);
  const value = drafts[editingCell.value] ?? (activeTopic.value.cells[row]?.[column] || "");
  pendingLocalValues[`${activeTopicId.value}:${row}:${column}`] = value;
  if (!editingLockSent.value && value === editingOriginalValue.value) {
    delete drafts[editingCell.value];
    editingCell.value = null;
    return;
  }
  activeTopic.value.cells[row][column] = value;
  activeTopic.value.cellAuthors ||= {};
  activeTopic.value.cellEditedAt ||= {};
  const authorKey = `${row}:${column}`;
  if (String(value).trim()) {
    activeTopic.value.cellAuthors[authorKey] = currentDisplayName.value;
    activeTopic.value.cellEditedAt[authorKey] = Date.now();
  } else {
    delete activeTopic.value.cellAuthors[authorKey];
    delete activeTopic.value.cellEditedAt[authorKey];
  }
  const requestId = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  pendingUpdates[requestId] = { key: editingCell.value, topicId: activeTopicId.value, row, column, value };
  saveState.value = "保存中";
  send({ type: "cell:update", requestId, topicId: activeTopicId.value, row, column, value });
  const saved = await updateCellFallback(activeTopicId.value, row, column, value);
  if (!saved) {
    saveState.value = "保存失败";
    return;
  }
  delete cellLocks.value[editingCell.value];
  delete drafts[editingCell.value];
  send({ type: "cell:unlock", topicId: activeTopicId.value, row, column });
  updateLockFallback(row, column, false);
  fitColumnWidth(column);
  editingCell.value = null;
  editingLockSent.value = false;
  saveState.value = "已同步";
}

function displayCellValue(row, column) {
  const key = cellKey(row, column);
  return Object.prototype.hasOwnProperty.call(drafts, key) ? drafts[key] : activeTopic.value?.cells?.[row]?.[column] || "";
}

function handleFocusOut(event) {
  if (event.target?.tagName === "INPUT") {
    flushEditingCell();
    const key = event.target.dataset.officeUnreadKey;
    if (key) {
      delete unreadCells.value[key];
      delete event.target.dataset.officeUnreadKey;
      syncCellLockBadges();
    }
  }
}

function clearUnreadCell(row, column) {
  delete unreadCells.value[cellKey(row, column)];
}

function handleFocusIn(event) {
  const input = event.target;
  if (input.tagName !== "INPUT" || !activeTopic.value) return;
  const row = input.closest("tbody tr");
  const cell = input.closest("td");
  if (!row || !cell) return;
  const rowIndex = [...row.parentElement.children].indexOf(row);
  const column = cell.cellIndex - 1;
  const key = cellKey(rowIndex + 2, column);
  if (editingCell.value && editingCell.value !== key) {
    delete unreadCells.value[editingCell.value];
  }
  delete unreadCells.value[key];
  syncCellLockBadges();
  input.dataset.officeUnreadKey = key;
  if (cellLocks.value[key] && cellLocks.value[key] !== currentDisplayName.value) {
    input.blur();
    ElMessage.warning(`${cellLocks.value[key]}正在编辑此单元格`);
    return;
  }
  selectedCell.value = `${String.fromCharCode(65 + column)}${rowIndex + 3}`;
  beginCellEdit(rowIndex + 2, column);
}

function updateTitle(value) {
  if (activeTopic.value) {
    activeTopic.value.cells[0][0] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors["0:0"] = currentDisplayName.value;
    activeTopic.value.cellEditedAt ||= {};
    activeTopic.value.cellEditedAt["0:0"] = Date.now();
  }
  send({ type: "cell:update", topicId: activeTopicId.value, row: 0, column: 0, value });
  updateCellFallback(activeTopicId.value, 0, 0, value);
}

function updateHeader(cellIndex, value) {
  if (activeTopic.value) {
    activeTopic.value.cells[1][cellIndex] = value;
    activeTopic.value.cellAuthors ||= {};
    activeTopic.value.cellAuthors[`1:${cellIndex}`] = currentDisplayName.value;
    activeTopic.value.cellEditedAt ||= {};
    activeTopic.value.cellEditedAt[`1:${cellIndex}`] = Date.now();
  }
  columns.value[cellIndex] = value;
  send({ type: "cell:update", topicId: activeTopicId.value, row: 1, column: cellIndex, value });
  updateCellFallback(activeTopicId.value, 1, cellIndex, value);
}

function cellAuthor(rowIndex, cellIndex) {
  const key = `${rowIndex + 2}:${cellIndex}`;
  const author = activeTopic.value?.cellAuthors?.[key];
  return author ? `${author} ${formatEditedAt(activeTopic.value?.cellEditedAt?.[key])}` : "";
}

function cellEditedAt(rowIndex, cellIndex) {
  return activeTopic.value?.cellEditedAt?.[`${rowIndex + 2}:${cellIndex}`] || null;
}

function formatEditedAt(value) {
  return value ? new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit" }).format(new Date(value)) : "";
}

function displayAuthor(rowIndex, cellIndex) {
  const author = cellAuthor(rowIndex, cellIndex);
  const editedAt = activeTopic.value?.cellEditedAt?.[`${rowIndex + 2}:${cellIndex}`];
  return author ? `${author} ${formatEditedAt(editedAt)}` : "";
}

function fixedCellAuthor(rowIndex, cellIndex) {
  const key = `${rowIndex}:${cellIndex}`;
  const author = activeTopic.value?.cellAuthors?.[key];
  return author ? `${author} ${formatEditedAt(activeTopic.value?.cellEditedAt?.[key])}` : "";
}

function cellEditor(row, column) {
  const editor = cellLocks.value[cellKey(row, column)];
  return editor && editor !== currentDisplayName.value ? editor : "";
}

function cellIsLocked(row, column) {
  return Boolean(cellEditor(row, column));
}

function isCellLockedByOther(row, column) {
  return Boolean(cellEditor(row, column));
}

function addTopic() {
  const name = window.prompt("新建话题", "未命名话题");
  if (name?.trim()) send({ type: "topic:create", name: name.trim() });
}

async function clearCurrentSheet() {
  if (!activeTopic.value) return;
  if (!window.confirm("确定清空当前工作表吗？此操作会清除表格内容和编辑标记。")) return;
  const rows = activeTopic.value.cells.length;
  const columnsCount = Math.max(...activeTopic.value.cells.map((row) => row.length), 0);
  for (let row = 0; row < rows; row += 1) {
    for (let column = 0; column < columnsCount; column += 1) {
      if (activeTopic.value.cells[row]?.[column]) {
        send({ type: "cell:update", topicId: activeTopicId.value, row, column, value: "" });
      }
    }
  }
  activeTopic.value.cells = activeTopic.value.cells.map((row) => row.map(() => ""));
  activeTopic.value.cellAuthors = {};
  activeTopic.value.cellEditedAt = {};
}

async function loadRooms() {
  const response = await fetch("/api/office/rooms", { headers: { Authorization: "", "X-Office-Guest": encodeURIComponent(guestName.value) } });
  if (response.ok) {
    rooms.value = (await response.json()).rooms || [];
    const savedRoomId = localStorage.getItem("office_active_room");
    const savedRoom = rooms.value.find((room) => room.id === savedRoomId);
    if (savedRoom) {
      enterRoom(savedRoom);
    } else if (savedRoomId) {
      localStorage.removeItem("office_active_room");
      activeRoomId.value = "";
    }
  }
}

async function changeRoomPassword(room) {
  const password = window.prompt("输入新房间密码", "")?.trim();
  if (!password) return;
  if (password.length < 4) return ElMessage.warning("房间密码至少 4 位");
  const response = await fetch(`/api/office/rooms/${encodeURIComponent(room.id)}/password`, { method: "PATCH", headers: { "Content-Type": "application/json", Authorization: "", "X-Office-Guest": encodeURIComponent(guestName.value) }, body: JSON.stringify({ password }) });
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    return ElMessage.error(payload.message || payload.error?.message || `修改密码失败（${response.status}）`);
  }
  localStorage.setItem(`office_room_password:${room.id}`, password);
  ElMessage.success("房间密码已修改");
}

async function deleteRoom(room) {
  if (!window.confirm(`确定删除房间“${room.name}”吗？`)) return;
  const response = await fetch(`/api/office/rooms/${encodeURIComponent(room.id)}`, { method: "DELETE", headers: { Authorization: "", "X-Office-Guest": encodeURIComponent(guestName.value) } });
  if (!response.ok) return ElMessage.error("删除房间失败");
  rooms.value = rooms.value.filter((item) => item.id !== room.id);
  if (activeRoomId.value === room.id) enterRoom(rooms.value[0] || { id: "main" });
  ElMessage.success("房间已删除");
}

function enterRoom(room) {
  pendingRoomId.value = room.id;
  lastSnapshotRevision = null;
  localStorage.setItem("office_active_room", room.id);
  if (room.id !== "main") roomPassword.value = localStorage.getItem(`office_room_password:${room.id}`) || "";
  if (!room.id) return;
  if (roomPassword.value) {
    roomDialogVisible.value = false;
    activeRoomId.value = room.id;
    snapshotSequence += 1;
    topics.value = [];
    activeTopicId.value = "";
    columns.value = [];
    socket.value?.close();
    window.setTimeout(() => { connect(); loadSnapshotForCurrentRoom(); }, 100);
    return;
  }
  // 没有缓存密码时，保持当前房间待输入状态；刷新不会回到房间列表。
  roomDialogMode.value = "enter";
  roomDialogVisible.value = true;
}

async function createRoom() {
  if (!roomName.value.trim() || roomPassword.value.length < 4) return ElMessage.warning("请输入房间名称和至少 4 位密码");
  const response = await fetch("/api/office/rooms", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "", "X-Office-Guest": encodeURIComponent(guestName.value) }, body: JSON.stringify({ name: roomName.value.trim(), password: roomPassword.value }) });
  if (!response.ok) return ElMessage.error("创建房间失败");
  const { room } = await response.json();
  rooms.value.push(room);
  roomDialogVisible.value = false;
  pendingRoomId.value = room.id;
  activeRoomId.value = room.id;
  localStorage.setItem("office_active_room", room.id);
  localStorage.setItem(`office_room_password:${room.id}`, roomPassword.value);
  snapshotSequence += 1;
  topics.value = [];
  activeTopicId.value = "";
  columns.value = [];
  socket.value?.close();
  window.setTimeout(() => { connect(); loadSnapshotForCurrentRoom(); }, 100);
}

function confirmEnterRoom() {
  roomDialogVisible.value = false;
  activeRoomId.value = pendingRoomId.value;
  localStorage.setItem(`office_room_password:${activeRoomId.value}`, roomPassword.value);
  snapshotRequestId += 1;
  snapshotSequence += 1;
  topics.value = [];
  activeTopicId.value = "";
  columns.value = [];
  socket.value?.close();
  window.setTimeout(() => { connect(); loadSnapshotForCurrentRoom(); }, 100);
}

function logout() {
  socket.value?.close();
  window.clearInterval(snapshotTimer);
  connectionText.value = "已退出房间";
}

function renameGuest() {
  const next = window.prompt("修改昵称", currentDisplayName.value)?.trim();
  if (!next) return;
  displayName.value = next.slice(0, 40);
  localStorage.setItem("office_display_name", displayName.value);
  send({ type: "user:rename", name: displayName.value });
  user.value = { ...user.value, name: displayName.value };
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

onMounted(() => { loadRooms(); });
onMounted(() => officeChannel?.addEventListener("message", notifyFromOtherTab));
onMounted(() => document.addEventListener("visibilitychange", clearOfficeTitleNotice));
onMounted(requestOfficeNotifications);
onMounted(() => {
  snapshotTimer = window.setInterval(loadSnapshotForCurrentRoom, 1500);
});
onMounted(() => {
  document.addEventListener("focusout", handleFocusOut, true);
  document.addEventListener("focusin", handleFocusIn, true);
});
onUnmounted(() => {
  window.clearInterval(titleFlashTimer);
  document.title = defaultDocumentTitle;
  officeChannel?.removeEventListener("message", notifyFromOtherTab);
  officeChannel?.close();
  document.removeEventListener("visibilitychange", clearOfficeTitleNotice);
  socket.value?.close();
  window.clearTimeout(reconnectTimer);
  window.clearInterval(snapshotTimer);
  window.clearTimeout(reconnectTimer);
  endResize();
  endRowResize();
  document.removeEventListener("focusout", handleFocusOut, true);
  document.removeEventListener("focusin", handleFocusIn, true);
});
</script>

<template>
  <div class="office-page">
    <header class="office-titlebar"><span class="office-app-icon">X</span><strong>{{ activeRoomName }}</strong><span class="office-save">{{ title }}</span><span class="office-online"><span class="presence-dot"></span>{{ connectionText }}</span><button type="button" class="office-user" @click="renameGuest">{{ currentDisplayName }}⌄</button></header>
    <nav class="office-ribbon"><button>文件</button><button class="is-active">开始</button><button>插入</button><button>布局</button><button>审阅</button><span class="ribbon-separator"></span><span class="ribbon-tool">剪切</span><span class="ribbon-tool">复制</span><span class="ribbon-tool">粘贴</span><span class="ribbon-separator"></span><span class="ribbon-tool">自动换行</span><span class="ribbon-tool">筛选</span></nav>
    <section class="workbench-shell">
      <aside v-if="!roomListCollapsed" class="office-room-list"><div class="office-room-head"><strong>聊天房间</strong><span><button type="button" title="新建房间" @click="roomDialogMode = 'create'; roomName = ''; roomPassword = ''; roomDialogVisible = true">＋</button><button type="button" class="room-collapse-button" title="收起房间列表" aria-label="收起房间列表" @click="roomListCollapsed = true">‹</button></span></div><div v-for="room in rooms" :key="room.id" class="office-room-row"><button type="button" class="office-room-item" :class="{ 'is-active': room.id === activeRoomId }" @click="room.id === activeRoomId ? null : enterRoom(room)">{{ room.name }}<small>{{ room.protected ? '🔒' : '' }} {{ room.online || 0 }}</small></button><el-dropdown v-if="room.id !== 'main'" trigger="click"><button type="button" class="office-room-more">⋯</button><template #dropdown><el-dropdown-menu><el-dropdown-item @click="changeRoomPassword(room)">修改密码</el-dropdown-item><el-dropdown-item divided @click="deleteRoom(room)">删除房间</el-dropdown-item></el-dropdown-menu></template></el-dropdown></div></aside>
      <button v-else type="button" class="office-room-expand" title="展开房间列表" @click="roomListCollapsed = false">＋</button>
      <div v-if="!activeRoomId" class="office-empty-room"><h2>请创建房间</h2><p>创建一个聊天房间后开始协作编辑。</p><button type="button" @click="roomDialogMode = 'create'; roomName = ''; roomPassword = ''; roomDialogVisible = true">＋ 创建房间</button></div><div v-else class="sheet-panel">
         <div class="sheet-toolbar"><div class="sheet-tab"><span class="sheet-tab-icon">▦</span> 工作表</div><div class="sheet-actions"><button type="button" @click="addRow">＋ 行</button><button type="button" class="sheet-clear-button" @click="clearCurrentSheet">清屏</button><span class="sheet-save-state">{{ saveState }}</span></div></div>
        <div class="formula-bar"><span class="name-box">{{ selectedCell }}</span><span class="formula-symbol">fx</span><input value="点击单元格编辑内容" readonly aria-label="公式栏提示"></div>
        <div class="sheet-scroll"><table class="workbench-sheet"><colgroup><col class="col-row-number"><col v-for="(_, index) in sheetColumns" :key="index" :style="{ width: `${columnWidths[index]}px` }"></colgroup><thead><tr class="column-letters" :style="{ height: `${rowHeights.letters || 26}px` }"><th class="row-number"></th><th v-for="(_, index) in sheetColumns" :key="index">{{ String.fromCharCode(65 + index) }}<span class="column-resize-handle" @mousedown="beginResize(index, $event)"></span><span class="row-resize-handle" @mousedown="beginRowResize(0, $event)"></span></th></tr><tr class="sheet-title-row" :style="{ height: `${rowHeights.title || 30}px` }"><th class="row-number">1</th><th :colspan="sheetColumns.length" class="sheet-title-cell"><span v-if="fixedCellAuthor(0, 0)" class="cell-author">{{ fixedCellAuthor(0, 0) }}：</span><input :value="title" aria-label="表格标题" @input="updateTitle($event.target.value)"><span class="row-resize-handle" @mousedown="beginRowResize(1, $event)"></span></th></tr><tr class="sheet-header" :style="{ height: `${rowHeights.header || 28}px` }"><th class="row-number">2</th><th v-for="(_, index) in sheetColumns" :key="index"><span v-if="index < 7 && fixedCellAuthor(1, index)" class="cell-author">{{ fixedCellAuthor(1, index) }}：</span><input v-if="index < 7" :value="columns[index]" :aria-label="`第 ${index + 1} 列标题`" @input="updateHeader(index, $event.target.value)"></th></tr></thead><tbody><tr v-for="(row, rowIndex) in rows" :key="rowIndex" :style="{ height: `${rowHeights[rowIndex + 2] || 28}px` }"><td class="row-number">{{ rowIndex + 3 }}</td><td v-for="(_, cellIndex) in sheetColumns" :key="cellIndex" :class="{ 'is-selected': selectedCell === `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}` }" @click="selectedCell = `${String.fromCharCode(65 + cellIndex)}${rowIndex + 3}`"><span v-if="cellAuthor(rowIndex, cellIndex)" class="cell-author">{{ cellAuthor(rowIndex, cellIndex) }}：</span><input :value="row[cellIndex] || ''" :aria-label="`${sheetColumns[cellIndex]} 第 ${rowIndex + 3} 行`" @input="updateCell(rowIndex, cellIndex, $event.target.value)"><span class="row-resize-handle" @mousedown="beginRowResize(rowIndex + 2, $event)"></span></td></tr></tbody></table></div>
        <footer class="sheet-status"><span>{{ statusText }}</span><span>◉ {{ user.name }}</span></footer>
        <div class="office-sheet-tabs"><button v-for="topic in topics" :key="topic.id" type="button" :class="{ 'is-active': topic.id === activeTopicId }" @click="selectTopic(topic)">▦ {{ topic.name }}</button><button type="button" class="add-sheet" title="新建话题" @click="addTopic">＋</button></div>
      </div>
    </section>
    <el-dialog v-model="roomDialogVisible" :title="roomDialogMode === 'create' ? '新建聊天房间' : '进入聊天房间'" width="min(92vw, 380px)"><el-form label-position="top"><el-form-item v-if="roomDialogMode === 'create'" label="房间名称"><el-input v-model="roomName" /></el-form-item><el-form-item label="房间密码"><el-input v-model="roomPassword" type="password" show-password /></el-form-item></el-form><template #footer><el-button @click="roomDialogVisible = false">取消</el-button><el-button type="primary" @click="roomDialogMode === 'create' ? createRoom() : confirmEnterRoom()">{{ roomDialogMode === 'create' ? '创建' : '进入' }}</el-button></template></el-dialog>
    <el-dialog v-model="passwordDialogVisible" title="修改密码" width="min(92vw, 420px)"><el-form label-position="top" @submit.prevent="submitPassword"><el-form-item label="当前密码"><el-input v-model="passwordForm.currentPassword" type="password" show-password /></el-form-item><el-form-item label="新密码"><el-input v-model="passwordForm.newPassword" type="password" show-password /></el-form-item><el-form-item label="确认新密码"><el-input v-model="passwordForm.confirmPassword" type="password" show-password @keyup.enter="submitPassword" /></el-form-item></el-form><template #footer><el-button @click="passwordDialogVisible = false">取消</el-button><el-button type="primary" :loading="passwordLoading" @click="submitPassword">确认修改</el-button></template></el-dialog>
  </div>
</template>
