<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import {
  ArrowDown,
  ArrowUp,
  Delete,
  Dish,
  Edit,
  FolderAdd,
  Link,
  MoreFilled,
  Plus,
  Refresh,
  Search
} from "@element-plus/icons-vue";
import {
  createBookmarkFolder,
  createBookmarkItem,
  detectBookmarkMetadata,
  deleteBookmarkFolder,
  deleteBookmarkItem,
  getBookmarkFolders,
  getBookmarkItems,
  getRandomBookmark,
  updateBookmarkFolder,
  updateBookmarkItem
} from "../api/bookmarks";

const route = useRoute();
const currentSpace = computed(() => route.meta.space || "star");
const currentTitle = computed(() => route.meta.title || (currentSpace.value === "cookie" ? "疯狂的厨房" : "鲸界"));
const currentLead = computed(() => {
  return currentSpace.value === "cookie"
    ? "分类保存菜谱与做饭链接，并在不同设备间统一整理。"
    : "把散落的链接收进清晰的目录，随时搜索和整理。";
});

const pageSize = 12;
const folders = ref([]);
const items = ref([]);
const total = ref(0);
const page = ref(1);
const query = ref("");
const activeFolderId = ref(undefined);
const loadingFolders = ref(false);
const loadingItems = ref(false);
const selectedIds = ref([]);
const folderDialogVisible = ref(false);
const folderDialogMode = ref("create");
const itemDialogVisible = ref(false);
const itemDialogMode = ref("create");
const moveItemsVisible = ref(false);
const saving = ref(false);
const detectingMetadata = ref(false);
const previewCoverFailed = ref(false);
const failedCoverUrls = ref(new Set());
const randomDialogVisible = ref(false);
const loadingRandom = ref(false);
const randomItem = ref(null);

const folderForm = reactive({ id: null, name: "", parentId: null, position: 0 });
const itemForm = reactive({ id: null, sourceUrl: "", title: "", description: "", coverUrl: "", folderId: null });
const bulkFolderId = ref(null);
const draggingItemId = ref(null);

watch(
  () => currentSpace.value,
  async () => {
    activeFolderId.value = undefined;
    query.value = "";
    page.value = 1;
    selectedIds.value = [];
    await loadFolders();
    await loadItems();
  }
);

const folderMap = computed(() => new Map(folders.value.map((folder) => [String(folder.id), folder])));

function buildTree(parentId = null, ancestors = new Set()) {
  return folders.value
    .filter((folder) => String(folder.parentId ?? "") === String(parentId ?? ""))
    .sort((a, b) => a.position - b.position || a.name.localeCompare(b.name, "zh-CN") || Number(a.id) - Number(b.id))
    .filter((folder) => !ancestors.has(String(folder.id)))
    .map((folder) => ({
      ...folder,
      children: buildTree(folder.id, new Set([...ancestors, String(folder.id)]))
    }));
}

const folderTree = computed(() => buildTree());
const activeFolder = computed(() => activeFolderId.value ? folderMap.value.get(String(activeFolderId.value)) : null);
const activeTitle = computed(() => {
  if (activeFolderId.value === null) return "未分类";
  if (activeFolder.value) return activeFolder.value.name;
  return "全部收藏";
});
const selectedItems = computed(() => items.value.filter((item) => selectedIds.value.includes(String(item.id))));
const previewHost = computed(() => sourceHost(itemForm.sourceUrl));

function sourceHost(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "") || "网页收藏";
  } catch {
    return "网页收藏";
  }
}

function cleanCoverUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== "string") return null;
  let str = rawUrl.trim();
  try {
    for (let i = 0; i < 3; i++) {
      if (str.includes("%3A") || str.includes("%2F") || str.includes("%3a") || str.includes("%2f")) {
        str = decodeURIComponent(str);
      } else {
        break;
      }
    }
  } catch {}

  const xhsMatch = str.match(/https?:\/\/(sns-(?:webpic|img)[^"'?\s<]+(?:\?[^"'?\s<]*)?)/i);
  if (xhsMatch) {
    return `https://${xhsMatch[1]}`;
  }

  const lastHttps = str.lastIndexOf("https://");
  const lastHttp = str.lastIndexOf("http://");
  const lastProtocolIndex = Math.max(lastHttps, lastHttp);
  if (lastProtocolIndex > 0) {
    str = str.slice(lastProtocolIndex).replace(/^http:\/\//i, "https://");
  }
  return str;
}

function itemHost(item) {
  return item.sourceHost || sourceHost(item.sourceUrl);
}

function hasCover(item) {
  const cleaned = cleanCoverUrl(item.coverUrl);
  return Boolean(cleaned) && !failedCoverUrls.value.has(cleaned);
}

function coverSrc(item) {
  return cleanCoverUrl(item.coverUrl);
}

function markCoverFailed(url) {
  failedCoverUrls.value = new Set([...failedCoverUrls.value, url]);
}

function folderPath(folderId) {
  if (folderId === null || folderId === undefined) return "未分类";
  const names = [];
  const visited = new Set();
  let current = folderMap.value.get(String(folderId));
  while (current && !visited.has(String(current.id))) {
    names.unshift(current.name);
    visited.add(String(current.id));
    current = current.parentId ? folderMap.value.get(String(current.parentId)) : null;
  }
  return names.join(" / ") || "未知目录";
}

function flattenOptions(nodes = folderTree.value, depth = 0) {
  return nodes.flatMap((node) => [
    { id: node.id, label: `${"　".repeat(depth)}${node.name}` },
    ...flattenOptions(node.children, depth + 1)
  ]);
}

const folderOptions = computed(() => flattenOptions());

function descendantIds(folderId) {
  const result = new Set([String(folderId)]);
  let changed = true;
  while (changed) {
    changed = false;
    folders.value.forEach((folder) => {
      if (result.has(String(folder.parentId)) && !result.has(String(folder.id))) {
        result.add(String(folder.id));
        changed = true;
      }
    });
  }
  return result;
}

const folderMoveOptions = computed(() => {
  if (folderDialogMode.value !== "edit") return folderOptions.value;
  const excluded = descendantIds(folderForm.id);
  return folderOptions.value.filter((folder) => !excluded.has(String(folder.id)));
});

async function loadFolders() {
  loadingFolders.value = true;
  try {
    const result = await getBookmarkFolders(currentSpace.value);
    folders.value = result.folders || [];
    if (activeFolderId.value && !folderMap.value.has(String(activeFolderId.value))) activeFolderId.value = undefined;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loadingFolders.value = false;
  }
}

async function loadItems() {
  loadingItems.value = true;
  selectedIds.value = [];
  try {
    const filters = { page: page.value, pageSize, query: query.value.trim() || undefined };
    if (activeFolderId.value === null) filters.uncategorized = true;
    else if (activeFolderId.value !== undefined) filters.folderId = activeFolderId.value;
    const result = await getBookmarkItems(filters, currentSpace.value);
    items.value = result.items || [];
    total.value = result.total || 0;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loadingItems.value = false;
  }
}

function selectFolder(folderId) {
  activeFolderId.value = folderId;
  page.value = 1;
  loadItems();
}

function searchItems() {
  page.value = 1;
  loadItems();
}

function changePage(value) {
  page.value = value;
  loadItems();
}

function openCreateFolder(parentId = null) {
  folderDialogMode.value = "create";
  Object.assign(folderForm, { id: null, name: "", parentId, position: 0 });
  folderDialogVisible.value = true;
}

function openEditFolder(folder) {
  folderDialogMode.value = "edit";
  Object.assign(folderForm, {
    id: folder.id,
    name: folder.name,
    parentId: folder.parentId,
    position: folder.position
  });
  folderDialogVisible.value = true;
}

async function saveFolder() {
  if (!folderForm.name.trim()) return ElMessage.warning("请输入目录名称");
  saving.value = true;
  const data = {
    name: folderForm.name.trim(),
    parentId: folderForm.parentId || null,
    position: Number(folderForm.position) || 0
  };
  try {
    let createdFolder;
    if (folderDialogMode.value === "create") createdFolder = await createBookmarkFolder(data, currentSpace.value);
    else await updateBookmarkFolder(folderForm.id, data, currentSpace.value);
    folderDialogVisible.value = false;
    ElMessage.success(folderDialogMode.value === "create" ? "目录已创建" : "目录已更新");
    await loadFolders();
    if (createdFolder?.folder?.id && itemDialogVisible.value) itemForm.folderId = createdFolder.folder.id;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

function openCreateFolderForItem() {
  openCreateFolder(itemForm.folderId || null);
}

async function dropItemOnFolder(folderId) {
  if (!draggingItemId.value) return;
  const itemId = draggingItemId.value;
  draggingItemId.value = null;
  try {
    await updateBookmarkItem(itemId, { folderId }, currentSpace.value);
    ElMessage.success(folderId ? "收藏已移动" : "收藏已移入未分类");
    await Promise.all([loadFolders(), loadItems()]);
  } catch (error) {
    ElMessage.error(error.message);
  }
}

async function removeFolder(folder) {
  try {
    await ElMessageBox.confirm(`确定删除目录“${folder.name}”吗？非空目录不能删除。`, "删除目录", {
      type: "warning",
      confirmButtonText: "删除",
      cancelButtonText: "取消"
    });
    await deleteBookmarkFolder(folder.id, currentSpace.value);
    if (String(activeFolderId.value) === String(folder.id)) activeFolderId.value = undefined;
    ElMessage.success("目录已删除");
    await Promise.all([loadFolders(), loadItems()]);
  } catch (error) {
    if (error !== "cancel" && error !== "close") ElMessage.error(error.message || "目录非空，无法删除");
  }
}

async function moveFolderStep(folder, direction) {
  const siblings = folders.value
    .filter((entry) => String(entry.parentId ?? "") === String(folder.parentId ?? ""))
    .sort((a, b) => a.position - b.position || Number(a.id) - Number(b.id));
  const index = siblings.findIndex((entry) => String(entry.id) === String(folder.id));
  const targetIndex = index + direction;
  if (index < 0 || targetIndex < 0 || targetIndex >= siblings.length) return;
  [siblings[index], siblings[targetIndex]] = [siblings[targetIndex], siblings[index]];
  try {
    for (let position = 0; position < siblings.length; position += 1) {
      await updateBookmarkFolder(siblings[position].id, { position }, currentSpace.value);
    }
    await loadFolders();
  } catch (error) {
    ElMessage.error(error.message);
    await loadFolders();
  }
}

function openCreateItem() {
  itemDialogMode.value = "create";
  Object.assign(itemForm, {
    id: null,
    sourceUrl: "",
    title: "",
    description: "",
    coverUrl: "",
    folderId: activeFolderId.value === undefined ? null : activeFolderId.value
  });
  previewCoverFailed.value = false;
  itemDialogVisible.value = true;
}

function openEditItem(item) {
  itemDialogMode.value = "edit";
  Object.assign(itemForm, {
    id: item.id,
    sourceUrl: item.sourceUrl,
    title: item.title || "",
    description: item.description || "",
    coverUrl: item.coverUrl || "",
    folderId: item.folderId
  });
  previewCoverFailed.value = false;
  itemDialogVisible.value = true;
}

async function detectMetadata() {
  const sourceUrl = itemForm.sourceUrl.trim();
  if (!sourceUrl) return ElMessage.warning("请先输入链接");
  detectingMetadata.value = true;
  try {
    const result = await detectBookmarkMetadata(sourceUrl);
    const metadata = result.metadata || {};
    if (metadata.finalUrl) itemForm.sourceUrl = metadata.finalUrl;
    if (!itemForm.title.trim() && metadata.title) itemForm.title = metadata.title;
    if (!itemForm.description.trim() && metadata.description) itemForm.description = metadata.description;
    if (!itemForm.coverUrl.trim() && metadata.coverUrl) {
      itemForm.coverUrl = metadata.coverUrl;
      previewCoverFailed.value = false;
    }
    ElMessage.success("已获取网页信息");
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    detectingMetadata.value = false;
  }
}

async function submitItem(allowDuplicate = false) {
  const data = {
    sourceUrl: itemForm.sourceUrl.trim(),
    title: itemForm.title.trim() || null,
    description: itemForm.description.trim() || null,
    coverUrl: itemForm.coverUrl.trim() || null,
    folderId: itemForm.folderId || null
  };
  if (!data.sourceUrl) return ElMessage.warning("请输入链接");
  saving.value = true;
  try {
    if (itemDialogMode.value === "create") await createBookmarkItem({ ...data, allowDuplicate }, currentSpace.value);
    else await updateBookmarkItem(itemForm.id, data, currentSpace.value);
    itemDialogVisible.value = false;
    ElMessage.success(itemDialogMode.value === "create" ? "收藏已创建" : "收藏已更新");
    await loadItems();
  } catch (error) {
    if (error.code === "DUPLICATE_BOOKMARK" && !allowDuplicate) {
      const duplicateName = error.duplicate?.title || error.duplicate?.folderName || "已有收藏";
      try {
        await ElMessageBox.confirm(`检测到重复链接（${duplicateName}），仍要保存吗？`, "重复链接", {
          type: "warning",
          confirmButtonText: "仍然保存",
          cancelButtonText: "返回修改"
        });
        return submitItem(true);
      } catch (confirmError) {
        if (confirmError !== "cancel" && confirmError !== "close") ElMessage.error(confirmError.message);
      }
    } else {
      ElMessage.error(error.message);
    }
  } finally {
    saving.value = false;
  }
}

async function removeItems(targetItems = selectedItems.value) {
  if (!targetItems.length) return;
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${targetItems.length} 条收藏吗？`, "删除收藏", {
      type: "warning",
      confirmButtonText: "删除",
      cancelButtonText: "取消"
    });
    const results = await Promise.allSettled(targetItems.map((item) => deleteBookmarkItem(item.id, currentSpace.value)));
    const failed = results.filter((result) => result.status === "rejected");
    if (failed.length) ElMessage.error(`${failed.length} 条收藏删除失败`);
    else ElMessage.success("收藏已删除");
    await loadItems();
  } catch (error) {
    if (error !== "cancel" && error !== "close") ElMessage.error(error.message);
  }
}

function openMoveItems(targetItems = selectedItems.value) {
  selectedIds.value = targetItems.map((item) => String(item.id));
  bulkFolderId.value = null;
  moveItemsVisible.value = true;
}

async function moveItems() {
  saving.value = true;
  const results = await Promise.allSettled(
    selectedItems.value.map((item) => updateBookmarkItem(item.id, { folderId: bulkFolderId.value || null }, currentSpace.value))
  );
  const failed = results.filter((result) => result.status === "rejected");
  if (failed.length) ElMessage.error(`${failed.length} 条收藏移动失败`);
  else {
    ElMessage.success("收藏已移动");
    moveItemsVisible.value = false;
  }
  saving.value = false;
  await loadItems();
}

const randomFilterVisible = ref(false);
const selectedRandomFolderIds = ref([]);

function openRandomFilterDialog() {
  if (folders.value.length === 0) {
    return ElMessage.warning("当前没有菜谱目录，请先创建目录并添加收藏");
  }
  // 默认全选所有当前目录（或保留有效选择）
  if (!selectedRandomFolderIds.value.length) {
    selectedRandomFolderIds.value = folders.value.map((f) => String(f.id));
  } else {
    const validIds = new Set(folders.value.map((f) => String(f.id)));
    selectedRandomFolderIds.value = selectedRandomFolderIds.value.filter((id) => validIds.has(id));
    if (!selectedRandomFolderIds.value.length) {
      selectedRandomFolderIds.value = folders.value.map((f) => String(f.id));
    }
  }
  randomFilterVisible.value = true;
}

function toggleRandomFolderSelectAll() {
  if (selectedRandomFolderIds.value.length === folders.value.length) {
    selectedRandomFolderIds.value = [];
  } else {
    selectedRandomFolderIds.value = folders.value.map((f) => String(f.id));
  }
}

async function startRandomFromFilter() {
  if (selectedRandomFolderIds.value.length === 0) {
    return ElMessage.warning("请至少选择一个目录进行随机");
  }
  randomFilterVisible.value = false;
  randomDialogVisible.value = true;
  await fetchRandomDish();
}

async function fetchRandomDish() {
  if (selectedRandomFolderIds.value.length === 0) {
    randomItem.value = null;
    return ElMessage.warning("请至少选择一个目录进行随机");
  }
  loadingRandom.value = true;
  try {
    // 收集所选目录及其所有子目录 ID，随机选取一个目录传参给后端 folderId
    const candidateIds = [];
    selectedRandomFolderIds.value.forEach((id) => {
      descendantIds(id).forEach((subId) => candidateIds.push(subId));
    });

    const targetFolderId = candidateIds[Math.floor(Math.random() * candidateIds.length)];
    const res = await getRandomBookmark(currentSpace.value, targetFolderId);
    randomItem.value = res?.item || null;
    if (!randomItem.value) {
      ElMessage.info("所选目录中暂无可推荐的菜谱");
    }
  } catch (err) {
    ElMessage.error(err.message || "获取随机菜谱失败");
  } finally {
    loadingRandom.value = false;
  }
}

function openRandomUrl() {
  if (randomItem.value?.sourceUrl) {
    window.open(randomItem.value.sourceUrl, "_blank", "noopener,noreferrer");
  }
}

function changeRandomFilter() {
  randomDialogVisible.value = false;
  randomFilterVisible.value = true;
}

function toggleItem(id, checked) {
  const key = String(id);
  if (checked && !selectedIds.value.includes(key)) selectedIds.value.push(key);
  if (!checked) selectedIds.value = selectedIds.value.filter((entry) => entry !== key);
}

function formatDate(value) {
  return value ? new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium" }).format(new Date(value)) : "";
}

onMounted(async () => {
  await loadFolders();
  await loadItems();
});
</script>

<template>
  <div class="bookmarks-page">
    <header class="bookmarks-heading">
      <div>
        <p class="eyebrow">工具 / 收藏夹 / {{ currentTitle }}</p>
        <h1>{{ currentTitle }}</h1>
        <p class="lead">{{ currentLead }}</p>
      </div>
      <div style="display: flex; gap: 10px; align-items: center;">
        <el-button
          v-if="currentSpace === 'cookie'"
          type="success"
          plain
          :icon="Dish"
          @click="openRandomFilterDialog"
        >
          今天吃什么
        </el-button>
        <el-button type="primary" :icon="Plus" @click="openCreateItem">添加收藏</el-button>
      </div>
    </header>

    <div class="bookmarks-workspace">
      <aside v-loading="loadingFolders" class="folder-panel" aria-label="收藏目录">
        <div class="panel-title">
          <div>
            <span class="panel-kicker">目录</span>
            <strong>{{ folders.length }} 个收藏夹</strong>
          </div>
          <el-button text circle :icon="FolderAdd" title="新建顶层目录" aria-label="新建顶层目录" @click="openCreateFolder()" />
        </div>

        <nav class="folder-specials" aria-label="收藏范围">
          <button :class="{ active: activeFolderId === undefined }" @click="selectFolder(undefined)">
            <Link />
            <span>全部收藏</span>
          </button>
           <button
             :class="{ active: activeFolderId === null }"
             @dragover.prevent
             @drop.prevent="dropItemOnFolder(null)"
             @click="selectFolder(null)"
           >
            <span class="uncategorized-mark">—</span>
            <span>未分类</span>
          </button>
        </nav>

        <el-tree
          v-if="folderTree.length"
          class="folder-tree"
          :data="folderTree"
          node-key="id"
          default-expand-all
          :expand-on-click-node="false"
          :highlight-current="Boolean(activeFolderId)"
          :current-node-key="activeFolderId"
          aria-label="目录树"
        >
          <template #default="{ data }">
            <div
              class="folder-node"
              @click="selectFolder(data.id)"
              @dragover.prevent
              @drop.prevent="dropItemOnFolder(data.id)"
            >
              <span class="folder-node__name" :title="folderPath(data.id)">{{ data.name }}</span>
              <el-dropdown trigger="click" @command="(command) => command()" @click.stop>
                <el-button text circle :icon="MoreFilled" :aria-label="`${data.name}目录操作`" />
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item :icon="FolderAdd" :command="() => openCreateFolder(data.id)">新增子目录</el-dropdown-item>
                    <el-dropdown-item :icon="Edit" :command="() => openEditFolder(data)">重命名或移动</el-dropdown-item>
                    <el-dropdown-item :icon="ArrowUp" :command="() => moveFolderStep(data, -1)">上移</el-dropdown-item>
                    <el-dropdown-item :icon="ArrowDown" :command="() => moveFolderStep(data, 1)">下移</el-dropdown-item>
                    <el-dropdown-item divided :icon="Delete" :command="() => removeFolder(data)">删除</el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </template>
        </el-tree>
        <el-empty v-else :image-size="56" description="还没有目录" />
      </aside>

      <main class="bookmark-list-panel">
        <div class="list-toolbar">
          <div>
            <p class="list-path">{{ activeFolder ? folderPath(activeFolder.id) : activeTitle }}</p>
            <h2>{{ activeTitle }}</h2>
          </div>
          <el-input
            v-model="query"
            class="bookmark-search"
            clearable
            :prefix-icon="Search"
            placeholder="搜索标题、描述或链接"
            aria-label="搜索收藏"
            @keyup.enter="searchItems"
            @clear="searchItems"
          >
            <template #append><el-button aria-label="执行搜索" @click="searchItems">搜索</el-button></template>
          </el-input>
        </div>

        <div v-if="selectedIds.length" class="bulk-bar" role="status">
          <strong>已选择 {{ selectedIds.length }} 项</strong>
          <div>
            <el-button size="small" @click="openMoveItems()">移动</el-button>
            <el-button size="small" type="danger" plain @click="removeItems()">删除</el-button>
          </div>
        </div>

        <div v-loading="loadingItems" class="bookmark-results" aria-live="polite">
            <article
              v-for="item in items"
              :key="item.id"
              class="bookmark-card"
              draggable="true"
              @dragstart="draggingItemId = String(item.id)"
              @dragend="draggingItemId = null"
            >
            <el-checkbox
              class="bookmark-check"
              :model-value="selectedIds.includes(String(item.id))"
              :aria-label="`选择${item.title || itemHost(item)}`"
              @change="(checked) => toggleItem(item.id, checked)"
            />
            <a class="bookmark-cover" :href="item.sourceUrl" target="_blank" rel="noopener noreferrer" tabindex="-1" aria-hidden="true">
              <img v-if="hasCover(item)" :src="coverSrc(item)" referrerpolicy="no-referrer" alt="" @error="markCoverFailed(coverSrc(item))" />
              <span v-else class="bookmark-cover__fallback">
                <strong>{{ itemHost(item).slice(0, 1).toUpperCase() }}</strong>
                <small>{{ itemHost(item) }}</small>
              </span>
            </a>
            <div class="bookmark-body">
              <div class="bookmark-meta">
                <span class="host-chip">{{ itemHost(item) }}</span>
                <span>{{ folderPath(item.folderId) }}</span>
                <time :datetime="item.updatedAt">{{ formatDate(item.updatedAt) }}</time>
              </div>
              <a :href="item.sourceUrl" target="_blank" rel="noopener noreferrer">{{ item.title || item.sourceUrl }}</a>
              <p v-if="item.description">{{ item.description }}</p>
              <small>{{ item.sourceUrl }}</small>
            </div>
            <div class="bookmark-actions">
              <el-button text circle :icon="Edit" title="编辑收藏" aria-label="编辑收藏" @click="openEditItem(item)" />
              <el-dropdown trigger="click" @command="(command) => command()">
                <el-button text circle :icon="MoreFilled" aria-label="更多收藏操作" />
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item :command="() => openMoveItems([item])">移动</el-dropdown-item>
                    <el-dropdown-item divided :icon="Delete" :command="() => removeItems([item])">删除</el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </div>
          </article>
          <el-empty v-if="!loadingItems && !items.length" description="这里还没有收藏">
            <el-button type="primary" :icon="Plus" @click="openCreateItem">添加第一条收藏</el-button>
          </el-empty>
        </div>

        <el-pagination
          v-if="total > pageSize"
          class="bookmark-pagination"
          background
          layout="prev, pager, next"
          :current-page="page"
          :page-size="pageSize"
          :total="total"
          aria-label="收藏分页"
          @current-change="changePage"
        />
      </main>
    </div>

    <el-dialog v-model="folderDialogVisible" :title="folderDialogMode === 'create' ? '新建目录' : '编辑目录'" width="min(460px, 92vw)">
      <el-form label-position="top" @submit.prevent="saveFolder">
        <el-form-item label="目录名称" required>
          <el-input v-model="folderForm.name" maxlength="120" show-word-limit autofocus />
        </el-form-item>
        <el-form-item label="上级目录">
          <el-select v-model="folderForm.parentId" class="full-width" clearable placeholder="顶层目录">
            <el-option label="顶层目录" :value="null" />
            <el-option v-for="folder in folderMoveOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序位置">
          <el-input-number v-model="folderForm.position" :min="0" :precision="0" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="folderDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveFolder">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="itemDialogVisible" :title="itemDialogMode === 'create' ? '添加收藏' : '编辑收藏'" width="min(620px, 94vw)" :close-on-click-modal="false">
      <el-form label-position="top" @submit.prevent="submitItem()">
        <el-form-item label="链接" required>
          <el-input v-model="itemForm.sourceUrl" type="url" placeholder="https://example.com">
            <template #append>
              <el-button :loading="detectingMetadata" @click="detectMetadata">检测网页信息</el-button>
            </template>
          </el-input>
        </el-form-item>
        <el-form-item label="标题">
          <el-input v-model="itemForm.title" placeholder="可留空" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="itemForm.description" type="textarea" :rows="4" placeholder="记录为什么收藏这个链接" />
        </el-form-item>
        <el-form-item label="封面图片 URL">
          <el-input
            v-model="itemForm.coverUrl"
            type="url"
            clearable
            placeholder="https://example.com/cover.jpg"
            @input="previewCoverFailed = false"
          />
        </el-form-item>
        <div v-if="itemForm.coverUrl" class="bookmark-cover-preview">
          <img v-if="!previewCoverFailed" :src="cleanCoverUrl(itemForm.coverUrl)" referrerpolicy="no-referrer" alt="封面预览" @error="previewCoverFailed = true" />
          <div v-else class="bookmark-cover__fallback">
            <strong>{{ previewHost.slice(0, 1).toUpperCase() }}</strong>
            <small>{{ previewHost }}</small>
            <span>图片无法加载，将显示站点占位图</span>
          </div>
        </div>
        <el-form-item label="收藏目录">
          <div class="folder-select-row">
            <el-select v-model="itemForm.folderId" class="full-width" clearable placeholder="未分类">
              <el-option label="未分类" :value="null" />
              <el-option v-for="folder in folderOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
            </el-select>
            <el-button :icon="FolderAdd" title="新建目录并选择" aria-label="新建目录并选择" @click="openCreateFolderForItem" />
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="itemDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitItem()">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="moveItemsVisible" title="移动收藏" width="min(440px, 92vw)">
      <p class="muted">将 {{ selectedIds.length }} 条收藏移动到：</p>
      <el-select v-model="bulkFolderId" class="full-width" clearable placeholder="未分类">
        <el-option label="未分类" :value="null" />
        <el-option v-for="folder in folderOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
      </el-select>
      <template #footer>
        <el-button @click="moveItemsVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="moveItems">移动</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="randomFilterVisible" title="选择随机目录范围" width="min(460px, 92vw)">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
        <span class="muted">勾选要参与抽取的菜谱目录</span>
        <el-button
          v-if="folders.length"
          size="small"
          text
          type="primary"
          @click="toggleRandomFolderSelectAll"
        >
          {{ selectedRandomFolderIds.length === folders.length ? "全不选" : "全选" }}
        </el-button>
      </div>
      <el-checkbox-group v-if="folderOptions.length" v-model="selectedRandomFolderIds" class="random-filter-list">
        <div
          v-for="folder in folderOptions"
          :key="folder.id"
          class="random-filter-item"
        >
          <el-checkbox :value="String(folder.id)" :label="String(folder.id)">
            <span>{{ folder.label }}</span>
          </el-checkbox>
        </div>
      </el-checkbox-group>
      <el-empty v-else :image-size="48" description="暂无可选择的菜谱目录" />
      <template #footer>
        <el-button @click="randomFilterVisible = false">取消</el-button>
        <el-button type="primary" :icon="Dish" @click="startRandomFromFilter">开始随机</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="randomDialogVisible" title="今天吃什么" width="min(500px, 94vw)" destroy-on-close>
      <div v-if="randomItem" class="random-dish-card">
        <div class="random-dish-cover">
          <img v-if="hasCover(randomItem)" :src="randomItem.coverUrl" alt="" />
          <div v-else class="random-dish-fallback">
            <strong>🍲</strong>
            <small>{{ itemHost(randomItem) }}</small>
          </div>
        </div>
        <div class="random-dish-content">
          <h3>{{ randomItem.title || "推荐菜谱" }}</h3>
          <p v-if="randomItem.description" class="random-dish-desc">{{ randomItem.description }}</p>
          <div class="random-dish-meta">
            <span class="host-chip">{{ itemHost(randomItem) }}</span>
            <span v-if="randomItem.folderId" class="folder-chip">📁 {{ folderPath(randomItem.folderId) }}</span>
          </div>
        </div>
      </div>
      <div v-else class="empty-random">
        <el-empty description="暂无可推荐的菜谱收藏，快去添加吧！" />
      </div>
      <template #footer>
        <div class="random-dialog-footer">
          <el-button @click="changeRandomFilter">调整范围</el-button>
          <el-button v-if="randomItem" :icon="Refresh" :loading="loadingRandom" @click="fetchRandomDish">换一个</el-button>
          <el-button v-if="randomItem" type="primary" :icon="Link" @click="openRandomUrl">打开菜谱</el-button>
          <el-button @click="randomDialogVisible = false">关闭</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>
