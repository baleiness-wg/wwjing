<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import {
  ArrowDown,
  ArrowUp,
  Delete,
  Edit,
  FolderAdd,
  Link,
  MoreFilled,
  Plus,
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
  updateBookmarkFolder,
  updateBookmarkItem
} from "../api/bookmarks";

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

const folderForm = reactive({ id: null, name: "", parentId: null, position: 0 });
const itemForm = reactive({ id: null, sourceUrl: "", title: "", description: "", coverUrl: "", folderId: null });
const bulkFolderId = ref(null);

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

function itemHost(item) {
  return item.sourceHost || sourceHost(item.sourceUrl);
}

function hasCover(item) {
  return Boolean(item.coverUrl) && !failedCoverUrls.value.has(item.coverUrl);
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
    const result = await getBookmarkFolders();
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
    const result = await getBookmarkItems(filters);
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
    if (folderDialogMode.value === "create") await createBookmarkFolder(data);
    else await updateBookmarkFolder(folderForm.id, data);
    folderDialogVisible.value = false;
    ElMessage.success(folderDialogMode.value === "create" ? "目录已创建" : "目录已更新");
    await loadFolders();
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

async function removeFolder(folder) {
  try {
    await ElMessageBox.confirm(`确定删除目录“${folder.name}”吗？非空目录不能删除。`, "删除目录", {
      type: "warning",
      confirmButtonText: "删除",
      cancelButtonText: "取消"
    });
    await deleteBookmarkFolder(folder.id);
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
      await updateBookmarkFolder(siblings[position].id, { position });
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
    if (itemDialogMode.value === "create") await createBookmarkItem({ ...data, allowDuplicate });
    else await updateBookmarkItem(itemForm.id, data);
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
    const results = await Promise.allSettled(targetItems.map((item) => deleteBookmarkItem(item.id)));
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
    selectedItems.value.map((item) => updateBookmarkItem(item.id, { folderId: bulkFolderId.value || null }))
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
        <p class="eyebrow">工具 / 收藏夹</p>
        <h1>收藏夹</h1>
        <p class="lead">把散落的链接收进清晰的目录，随时搜索和整理。</p>
      </div>
      <el-button type="primary" :icon="Plus" @click="openCreateItem">添加收藏</el-button>
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
          <button :class="{ active: activeFolderId === null }" @click="selectFolder(null)">
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
            <div class="folder-node" @click="selectFolder(data.id)">
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
          <article v-for="item in items" :key="item.id" class="bookmark-card">
            <el-checkbox
              class="bookmark-check"
              :model-value="selectedIds.includes(String(item.id))"
              :aria-label="`选择${item.title || itemHost(item)}`"
              @change="(checked) => toggleItem(item.id, checked)"
            />
            <a class="bookmark-cover" :href="item.sourceUrl" target="_blank" rel="noopener noreferrer" tabindex="-1" aria-hidden="true">
              <img v-if="hasCover(item)" :src="item.coverUrl" alt="" @error="markCoverFailed(item.coverUrl)" />
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
          <img v-if="!previewCoverFailed" :src="itemForm.coverUrl" alt="封面预览" @error="previewCoverFailed = true" />
          <div v-else class="bookmark-cover__fallback">
            <strong>{{ previewHost.slice(0, 1).toUpperCase() }}</strong>
            <small>{{ previewHost }}</small>
            <span>图片无法加载，将显示站点占位图</span>
          </div>
        </div>
        <el-form-item label="收藏目录">
          <el-select v-model="itemForm.folderId" class="full-width" clearable placeholder="未分类">
            <el-option label="未分类" :value="null" />
            <el-option v-for="folder in folderOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
          </el-select>
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
  </div>
</template>
