<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { ElMessage, ElMessageBox } from "element-plus";
import {
  ArrowDown,
  ArrowUp,
  Delete,
  Dish,
  Edit,
  FolderAdd,
  CircleCheckFilled,
  CollectionTag,
  Folder,
  Link,
  MoreFilled,
  Plus,
  Refresh,
  Search,
  Opportunity
} from "@element-plus/icons-vue";
import {
  createBookmarkFolder,
  createBookmarkItem,
  detectBookmarkMetadata,
  deleteBookmarkFolder,
  deleteBookmarkItem,
  getBookmarkFolders,
  getBookmarkItems,
  getAllBookmarkItems,
  getBookmarkFolderShares,
  removeBookmarkFolderShare,
  shareBookmarkFolder,
  getRandomBookmark,
  updateBookmarkFolder,
  updateBookmarkItem,
  pinBookmarkItem
  ,uploadBookmarkImage
} from "../api/bookmarks";
import AiChatPanel from "../components/AiChatPanel.vue";

const route = useRoute();
const currentSpace = computed(() => route.meta.space || "star");
const currentTitle = computed(() => route.meta.title || (currentSpace.value === "cookie" ? "疯狂的厨房" : "鲸界"));


const pageSize = 12;
const folders = ref([]);
const items = ref([]);
const total = ref(0);
const page = ref(1);
const query = ref("");
const activeFolderId = ref(undefined);
const folderShareDialogVisible = ref(false);
const folderShareUsername = ref("");
const folderShareTarget = ref(null);
const folderShares = ref([]);
const loadingFolderShares = ref(false);
const loadingFolders = ref(false);
const loadingItems = ref(false);
let itemsRequestSequence = 0;
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
const aiChatVisible = ref(false);
const folderMenuVisible = ref(false);

const folderForm = reactive({ id: null, name: "", parentId: null, position: 0 });
const itemForm = reactive({ id: null, sourceUrl: "", title: "", description: "", coverUrl: "", folderIds: [] });
const imageInput = ref(null);
const itemImages = ref([]);
const pendingImages = ref([]);
const previewImagesVisible = ref(false);
const previewImageIndex = ref(0);
const bulkFolderIds = ref([]);
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
    await loadAiItems();
  }
);

const folderMap = computed(() => new Map(folders.value.map((folder) => [String(folder.id), folder])));
const pinnedFolderExpandedKeys = computed(() => {
  const expanded = new Set();
  folders.value.filter((folder) => folder.pinned).forEach((folder) => {
    let parentId = folder.parentId;
    while (parentId) {
      expanded.add(String(parentId));
      parentId = folderMap.value.get(String(parentId))?.parentId || null;
    }
  });
  return [...expanded];
});

function buildTree(parentId = null, ancestors = new Set()) {
  return folders.value
    .filter((folder) => String(folder.parentId ?? "") === String(parentId ?? ""))
    .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || a.position - b.position || a.name.localeCompare(b.name, "zh-CN") || Number(a.id) - Number(b.id))
    .filter((folder) => !ancestors.has(String(folder.id)))
    .map((folder) => ({
      ...folder,
      children: buildTree(folder.id, new Set([...ancestors, String(folder.id)]))
    }));
}

const folderTree = computed(() => buildTree());
const activeFolder = computed(() => activeFolderId.value ? folderMap.value.get(String(activeFolderId.value)) : null);
const activeTitle = computed(() => {
  if (activeFolderId.value === null) return "灵感";
  if (activeFolder.value) return activeFolder.value.name;
  return "全部收藏";
});
const folderViewKey = computed(() => `${currentSpace.value}:${activeFolderId.value === undefined ? "all" : activeFolderId.value === null ? "uncategorized" : activeFolderId.value}`);
const aiItems = ref([]);
const aiDirectoryContext = computed(() => ({
  space: currentSpace.value,
  directoryId: activeFolderId.value === undefined ? null : activeFolderId.value,
  directoryName: activeTitle.value,
  directoryPath: activeFolderId.value === undefined
    ? "全部收藏"
    : activeFolderId.value === null
      ? "灵感"
      : folderPath(activeFolderId.value),
  loadedItemCount: aiItems.value.length,
  items: aiItems.value.map((item) => ({
    title: item.title,
    description: item.description,
    sourceHost: itemHost(item),
    sourceUrl: item.sourceUrl,
    folderPath: folderPaths(item)
  }))
}));
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

  if (str.includes("xiaohongshu.com") || str.includes("xhscdn.com")) {
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
  const cleaned = cleanCoverUrl(item.images?.[0] || item.coverUrl);
  return Boolean(cleaned) && !failedCoverUrls.value.has(cleaned);
}

function coverSrc(item) {
  return cleanCoverUrl(item.images?.[0] || item.coverUrl);
}

function markCoverFailed(url) {
  failedCoverUrls.value = new Set([...failedCoverUrls.value, url]);
}

function folderPath(folderId) {
  if (folderId === null || folderId === undefined) return "灵感";
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

function folderPaths(item) {
  const ids = item.folderIds?.length ? item.folderIds : (item.folderId ? [item.folderId] : []);
  return ids.length ? ids.map((id) => folderPath(id)).join("、") : "灵感";
}

function flattenOptions(nodes = folderTree.value, depth = 0) {
  return nodes.flatMap((node) => [
    { id: node.id, name: node.name, label: `${"　".repeat(depth)}${node.name}`, depth },
    ...flattenOptions(node.children, depth + 1)
  ]);
}

const folderOptions = computed(() => flattenOptions());
const randomFolderOptions = computed(() => [
  { id: "all", name: "全部收藏", depth: 0, type: "all" },
  { id: "uncategorized", name: "灵感", depth: 0, type: "uncategorized" },
  ...folderOptions.value.map((folder) => ({ ...folder, type: "folder" }))
]);

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
    if (activeFolderId.value && !folderMap.value.has(String(activeFolderId.value))) {
      activeFolderId.value = undefined;
      page.value = 1;
      await loadItems();
    }
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loadingFolders.value = false;
  }
}

async function loadItems() {
  const requestSequence = ++itemsRequestSequence;
  const requestedSpace = currentSpace.value;
  const requestedFolderId = activeFolderId.value;
  const requestedPage = page.value;
  const requestedQuery = query.value.trim();
  const requestedFolderKey = requestedFolderId === undefined ? "all" : requestedFolderId === null ? "uncategorized" : String(requestedFolderId);
  loadingItems.value = true;
  selectedIds.value = [];
  items.value = [];
  try {
    const filters = { page: requestedPage, pageSize, query: requestedQuery || undefined };
    if (requestedFolderId === null) filters.uncategorized = true;
    else if (requestedFolderId !== undefined) {
      filters.folderId = requestedFolderId;
      filters.includeDescendants = true;
    }
    const result = await getBookmarkItems(filters, requestedSpace);
    const isCurrentRequest = requestSequence === itemsRequestSequence
      && requestedSpace === currentSpace.value
      && requestedFolderKey === (activeFolderId.value === undefined ? "all" : activeFolderId.value === null ? "uncategorized" : String(activeFolderId.value))
      && requestedPage === page.value
      && requestedQuery === query.value.trim();
    if (!isCurrentRequest) return;
    items.value = result.items || [];
    total.value = result.total || 0;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    if (requestSequence === itemsRequestSequence) loadingItems.value = false;
  }
}

function selectFolder(folderId) {
  activeFolderId.value = folderId;
  selectedRandomFolderId.value = folderId === null
    ? "uncategorized"
    : folderId === undefined
      ? "all"
      : String(folderId);
  page.value = 1;
  void loadItems();
  void loadAiItems();
  folderMenuVisible.value = false;
}

function searchItems() {
  page.value = 1;
  loadItems();
}

async function toggleItemPin(item) {
  if (activeFolderId.value === undefined || activeFolderId.value === null) {
    ElMessage.warning("请先进入具体收藏夹目录后再置顶");
    return;
  }
  await pinBookmarkItem(item.id, activeFolderId.value, !item.pinned, currentSpace.value);
  await loadItems();
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

function shareFolder(folder) {
  folderShareTarget.value = folder;
  folderShareUsername.value = "";
  folderShareDialogVisible.value = true;
  loadFolderShares(folder);
}

async function loadFolderShares(folder = folderShareTarget.value) {
  if (!folder) return;
  loadingFolderShares.value = true;
  try {
    const result = await getBookmarkFolderShares(folder.id, currentSpace.value);
    folderShares.value = result.shares || [];
  } catch (error) { ElMessage.error(error.message); }
  finally { loadingFolderShares.value = false; }
}

async function removeFolderShare(share) {
  if (!folderShareTarget.value) return;
  try {
    await removeBookmarkFolderShare(folderShareTarget.value.id, share.userId, currentSpace.value);
    await loadFolderShares();
    ElMessage.success(`已取消共享给 ${share.username}`);
  } catch (error) { ElMessage.error(error.message); }
}

async function toggleFolderPin(folder) {
  try {
    await updateBookmarkFolder(folder.id, { pinned: !folder.pinned }, currentSpace.value);
    await loadFolders();
    ElMessage.success(folder.pinned ? "已取消置顶" : "目录已置顶");
  } catch (error) {
    ElMessage.error(error.message);
  }
}

async function submitFolderShare() {
  if (!folderShareUsername.value.trim() || !folderShareTarget.value) return;
  try {
    await shareBookmarkFolder(folderShareTarget.value.id, folderShareUsername.value.trim(), currentSpace.value);
    folderShareDialogVisible.value = false;
    await loadFolderShares();
    ElMessage.success("目录已共享");
  } catch (error) { ElMessage.error(error.message); }
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
    if (createdFolder?.folder?.id && itemDialogVisible.value) itemForm.folderIds = [...itemForm.folderIds, createdFolder.folder.id];
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

function openCreateFolderForItem() {
  openCreateFolder(itemForm.folderIds[0] || null);
}

async function dropItemOnFolder(folderId) {
  if (!draggingItemId.value) return;
  const itemId = draggingItemId.value;
  draggingItemId.value = null;
  try {
    await updateBookmarkItem(itemId, { folderIds: folderId ? [folderId] : [] }, currentSpace.value);
    ElMessage.success(folderId ? "收藏已移动" : "收藏已移入灵感");
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
    folderIds: activeFolderId.value === undefined || activeFolderId.value === null ? [] : [activeFolderId.value]
  });
  previewCoverFailed.value = false;
  itemImages.value = [];
  pendingImages.value = [];
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
    folderIds: item.folderIds?.length ? [...item.folderIds] : (item.folderId ? [item.folderId] : [])
  });
  itemImages.value = [...(item.images || [])];
  pendingImages.value = [];
  previewCoverFailed.value = false;
  itemDialogVisible.value = true;
}

async function uploadItemImage(event) {
  const file = event.target.files?.[0];
  event.target.value = "";
  if (!file) return;
  if (!itemForm.id) {
    pendingImages.value = [...pendingImages.value, file];
    return;
  }
  try {
    const result = await uploadBookmarkImage(itemForm.id, file, currentSpace.value);
    itemImages.value = result.images || [...itemImages.value, result.image];
    itemForm.coverUrl = itemImages.value[0] || "";
    ElMessage.success("图片已上传");
  } catch (error) { ElMessage.error(error.message); }
}

function openImagePreview(index = 0) {
  previewImageIndex.value = index;
  previewImagesVisible.value = true;
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
      itemImages.value = [
        metadata.coverUrl,
        ...itemImages.value.filter((image) => image !== metadata.coverUrl)
      ];
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
    images: [...itemImages.value],
    folderIds: [...itemForm.folderIds]
  };
  saving.value = true;
  try {
    if (itemDialogMode.value === "create") {
      const created = await createBookmarkItem({ ...data, allowDuplicate }, currentSpace.value);
      const itemId = created?.item?.id || created?.id;
      if (itemId) {
        for (const file of pendingImages.value) {
          const result = await uploadBookmarkImage(itemId, file, currentSpace.value);
          itemImages.value = result.images || itemImages.value;
        }
      }
    }
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
  bulkFolderIds.value = [];
  moveItemsVisible.value = true;
}

async function moveItems() {
  saving.value = true;
  const results = await Promise.allSettled(
    selectedItems.value.map((item) => updateBookmarkItem(item.id, { folderIds: [...bulkFolderIds.value] }, currentSpace.value))
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
const selectedRandomFolderId = ref("all");
const randomFolderTreeElement = ref(null);

function openRandomFilterDialog() {
  const currentId = activeFolderId.value;
  selectedRandomFolderId.value = currentId === null
    ? "uncategorized"
    : currentId === undefined || !folderMap.value.has(String(currentId))
      ? "all"
      : String(currentId);
  randomFilterVisible.value = true;
  nextTick(() => {
    randomFolderTreeElement.value?.querySelector(".random-folder-node.is-active")?.scrollIntoView({
      block: "center",
      behavior: "smooth"
    });
  });
}

function selectRandomFolder(data) {
  selectedRandomFolderId.value = String(data.id);
}

async function startRandomFromFilter() {
  randomFilterVisible.value = false;
  randomDialogVisible.value = true;
  await fetchRandomDish();
}

async function fetchRandomDish() {
  loadingRandom.value = true;
  try {
    const folderIds = selectedRandomFolderId.value === "all" || selectedRandomFolderId.value === "uncategorized"
      ? []
      : [...descendantIds(selectedRandomFolderId.value)];
    const res = await getRandomBookmark(currentSpace.value, "", folderIds, selectedRandomFolderId.value === "uncategorized");
    randomItem.value = res?.item || null;
    if (!randomItem.value) {
      ElMessage.info("所选目录中暂无可推荐的内容");
    }
  } catch (err) {
    ElMessage.error(err.message || "获取随机内容失败");
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

function openGlobalAiChat() { aiChatVisible.value = !aiChatVisible.value; }

onMounted(async () => {
  window.addEventListener("wwjing:open-ai-chat", openGlobalAiChat);
  window.setTimeout(() => window.dispatchEvent(new CustomEvent("wwjing:bookmark-location", { detail: activeTitle.value })), 0);
  await loadFolders();
  await loadItems();
  await loadAiItems();
});

async function loadAiItems() {
  const filters = {};
  if (activeFolderId.value !== undefined) {
    if (activeFolderId.value === null) filters.uncategorized = true;
    else {
      filters.folderId = activeFolderId.value;
      filters.includeDescendants = true;
    }
  }
  const result = await getAllBookmarkItems(filters, currentSpace.value);
  aiItems.value = result.items || [];
}

onBeforeUnmount(() => window.removeEventListener("wwjing:open-ai-chat", openGlobalAiChat));

watch(activeTitle, (title) => window.dispatchEvent(new CustomEvent("wwjing:bookmark-location", { detail: title })));
</script>

<template>
  <div class="bookmarks-page">
    <div v-if="folderMenuVisible" class="bookmark-folder-backdrop" @click="folderMenuVisible = false"></div>
    <div class="bookmarks-workspace">
      <aside v-loading="loadingFolders" class="folder-panel" :class="{ 'is-mobile-visible': folderMenuVisible }" aria-label="收藏目录">
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
             <Opportunity class="uncategorized-icon" />
             <span>灵感</span>
          </button>
        </nav>

        <el-tree
          v-if="folderTree.length"
          class="folder-tree"
          :data="folderTree"
          node-key="id"
           :default-expanded-keys="pinnedFolderExpandedKeys"
          :key="`folders-${folders.length}-${pinnedFolderExpandedKeys.join(',')}`"
          :expand-on-click-node="false"
          :highlight-current="false"
          aria-label="目录树"
        >
          <template #default="{ data }">
            <div
               class="folder-node"
               :class="{ 'is-pinned': data.pinned, 'is-active': String(activeFolderId) === String(data.id) }"
              @click="selectFolder(data.id)"
              @dragover.prevent
              @drop.prevent="dropItemOnFolder(data.id)"
            >
               <span class="folder-node__name" :title="folderPath(data.id)">{{ data.pinned ? "📌 " : "" }}{{ data.name }}</span>
               <el-dropdown trigger="click" placement="bottom-end" :popper-offset="8" @command="(command) => command()" @click.stop>
                <el-button text circle :icon="MoreFilled" :aria-label="`${data.name}目录操作`" />
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item :icon="FolderAdd" :command="() => openCreateFolder(data.id)">新增子目录</el-dropdown-item>
                    <el-dropdown-item :icon="Edit" :command="() => openEditFolder(data)">重命名或移动</el-dropdown-item>
                    <el-dropdown-item :command="() => shareFolder(data)">共享目录</el-dropdown-item>
                    <el-dropdown-item :command="() => toggleFolderPin(data)">{{ data.pinned ? "取消置顶" : "置顶目录" }}</el-dropdown-item>
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
           <div class="list-toolbar-title">
             <el-button class="mobile-folder-toggle" text circle :icon="Folder" title="打开收藏目录" aria-label="打开收藏目录" @click="folderMenuVisible = true" />
             <h2>{{ activeTitle }}</h2>
             <div class="list-toolbar-actions">
               <el-button type="success" plain :icon="Dish" @click="openRandomFilterDialog">Today</el-button>
               <el-button type="primary" :icon="Plus" @click="openCreateItem">添加收藏</el-button>
             </div>
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
            <template #append><el-button :icon="Search" aria-label="执行搜索" @click="searchItems" /></template>
          </el-input>
        </div>

        <div v-if="selectedIds.length" class="bulk-bar" role="status">
          <strong>已选择 {{ selectedIds.length }} 项</strong>
          <div>
            <el-button size="small" @click="openMoveItems()">移动</el-button>
            <el-button size="small" type="danger" plain @click="removeItems()">删除</el-button>
          </div>
        </div>

         <div :key="folderViewKey" v-loading="loadingItems" class="bookmark-results" aria-live="polite">
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
            <a class="bookmark-cover" :href="item.sourceUrl || undefined" target="_blank" rel="noopener noreferrer" tabindex="-1" :aria-hidden="item.sourceUrl ? 'true' : undefined">
              <img v-if="hasCover(item)" :src="coverSrc(item)" referrerpolicy="no-referrer" alt="" @error="markCoverFailed(coverSrc(item))" />
              <span v-else class="bookmark-cover__fallback">
                <strong>{{ itemHost(item).slice(0, 1).toUpperCase() }}</strong>
                <small>{{ itemHost(item) }}</small>
              </span>
            </a>
            <div class="bookmark-body">
              <div class="bookmark-meta">
                <span class="host-chip">{{ itemHost(item) }}</span>
                <span>{{ folderPaths(item) }}</span>
                <time :datetime="item.updatedAt">{{ formatDate(item.updatedAt) }}</time>
              </div>
              <a :href="item.sourceUrl" target="_blank" rel="noopener noreferrer">{{ item.title || "未命名收藏" }}</a>
              <p v-if="item.description">{{ item.description }}</p>
              <small v-if="item.sourceUrl">{{ item.sourceUrl }}</small>
            </div>
            <div class="bookmark-actions">
              <el-button text circle :icon="Edit" title="编辑收藏" aria-label="编辑收藏" @click="openEditItem(item)" />
               <el-dropdown trigger="click" placement="bottom-end" :popper-offset="4" popper-class="bookmark-actions-popper" @command="(command) => command()">
                <el-button text circle :icon="MoreFilled" aria-label="更多收藏操作" />
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item :command="() => openMoveItems([item])">移动</el-dropdown-item>
                    <el-dropdown-item :command="() => toggleItemPin(item)">{{ item.pinned ? "取消置顶" : "置顶" }}</el-dropdown-item>
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

    <el-dialog v-model="folderShareDialogVisible" title="共享目录" width="min(420px, 92vw)">
      <div v-loading="loadingFolderShares" class="folder-share-list">
        <p class="muted">已共享给</p>
        <el-empty v-if="!loadingFolderShares && !folderShares.length" :image-size="40" description="暂未共享" />
        <div v-for="share in folderShares" :key="share.userId" class="folder-share-row">
          <span>{{ share.username }}</span>
          <el-button text type="danger" @click="removeFolderShare(share)">移除</el-button>
        </div>
      </div>
      <el-form label-position="top" @submit.prevent="submitFolderShare">
        <el-form-item label="用户名">
          <el-input v-model="folderShareUsername" placeholder="输入对方用户名" autofocus />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="folderShareDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitFolderShare">共享</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="itemDialogVisible" :title="itemDialogMode === 'create' ? '添加收藏' : '编辑收藏'" width="min(620px, 94vw)" :close-on-click-modal="false">
      <el-form label-position="top" @submit.prevent="submitItem()">
        <el-form-item label="标题">
          <el-input v-model="itemForm.title" placeholder="请输入标题" />
        </el-form-item>
        <el-form-item label="链接（可选）">
          <el-input v-model="itemForm.sourceUrl" type="url" placeholder="输入链接（可留空）" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="itemForm.description" type="textarea" :rows="10" placeholder="记录为什么收藏这个链接" />
        </el-form-item>
      <el-form-item label="图片">
          <input ref="imageInput" type="file" accept="image/jpeg,image/png,image/webp,image/gif" hidden @change="uploadItemImage" />
          <div v-if="itemImages.length || pendingImages.length || itemForm.coverUrl" class="item-image-strip">
            <button
              v-for="(image, index) in [...itemImages, ...pendingImages.map((file) => URL.createObjectURL(file))]"
              :key="`${image}-${index}`"
              type="button"
              class="item-image-thumb item-image-thumb-button"
              @click="openImagePreview(index)"
            >
              <img :src="image" alt="收藏图片" />
              <span v-if="index === 0" class="item-image-cover-badge">封面</span>
            </button>
            <button v-if="!itemImages.length && itemForm.coverUrl" type="button" class="item-image-thumb item-image-thumb-button" @click="openImagePreview(0)">
              <img :src="itemForm.coverUrl" alt="收藏封面" />
            </button>
          </div>
          <div class="image-upload-actions">
            <el-button @click="imageInput?.click()">追加图片</el-button>
            <span class="muted image-upload-hint">{{ itemImages.length + pendingImages.length }} 张图片</span>
          </div>
        </el-form-item>
        <el-form-item label="收藏目录">
          <div class="folder-select-row">
            <el-select v-model="itemForm.folderIds" class="full-width" multiple collapse-tags collapse-tags-tooltip placeholder="灵感">
              <el-option v-for="folder in folderOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
            </el-select>
            <el-button :icon="FolderAdd" title="新建目录并选择" aria-label="新建目录并选择" @click="openCreateFolderForItem" />
          </div>
          <div v-if="!itemImages.length && itemForm.coverUrl" class="item-image-strip">
            <div class="item-image-thumb"><img :src="itemForm.coverUrl" alt="收藏封面" /></div>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="itemDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitItem()">保存</el-button>
      </template>
    </el-dialog>
    <el-dialog v-model="previewImagesVisible" title="图片预览" width="min(760px, 94vw)">
      <el-carousel v-if="itemImages.length || pendingImages.length" :initial-index="previewImageIndex" height="min(60vh, 520px)" arrow="always" indicator-position="outside">
        <el-carousel-item v-for="(image, index) in [...itemImages, ...pendingImages.map((file) => URL.createObjectURL(file))]" :key="`${image}-${index}`">
          <img class="item-image-preview" :src="image" alt="收藏图片" />
        </el-carousel-item>
      </el-carousel>
    </el-dialog>

    <el-dialog v-model="moveItemsVisible" title="移动收藏" width="min(440px, 92vw)">
        <p class="muted">将 {{ selectedIds.length }} 条收藏关联到：</p>
            <el-select v-model="bulkFolderIds" class="full-width" multiple collapse-tags collapse-tags-tooltip placeholder="灵感">
        <el-option v-for="folder in folderOptions" :key="folder.id" :label="folder.label" :value="folder.id" />
      </el-select>
      <template #footer>
        <el-button @click="moveItemsVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="moveItems">移动</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="randomFilterVisible" title="选择随机目录范围" width="min(460px, 92vw)">
      <span class="muted">选择一个平级范围进行抽取</span>
      <div ref="randomFolderTreeElement" class="random-folder-tree">
        <button
          v-for="folder in randomFolderOptions"
          :key="folder.id"
          type="button"
          class="random-folder-node"
          :class="{ 'is-active': selectedRandomFolderId === String(folder.id), 'is-special': folder.type !== 'folder' }"
          :style="{ paddingLeft: `${8 + folder.depth * 20}px` }"
          @click="selectRandomFolder(folder)"
        >
          <el-icon class="random-folder-icon"><component :is="folder.type === 'all' ? CollectionTag : folder.type === 'uncategorized' ? Link : Folder" /></el-icon><span>{{ folder.name }}</span>
          <el-icon v-if="selectedRandomFolderId === String(folder.id)" class="random-folder-selected"><CircleCheckFilled /></el-icon>
        </button>
      </div>
      <template #footer>
        <el-button @click="randomFilterVisible = false">取消</el-button>
        <el-button type="primary" :icon="Dish" @click="startRandomFromFilter">开始随机</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="randomDialogVisible" class="random-dialog" title="Today" width="min(500px, 94vw)" destroy-on-close>
      <div v-if="randomItem" class="random-dish-card">
        <div class="random-dish-cover">
           <img v-if="hasCover(randomItem)" :src="coverSrc(randomItem)" alt="" />
          <div v-else class="random-dish-fallback">
            <strong>🍲</strong>
            <small>{{ itemHost(randomItem) }}</small>
          </div>
        </div>
        <div class="random-dish-content">
          <h3>{{ randomItem.title || "推荐内容" }}</h3>
          <p v-if="randomItem.description" class="random-dish-desc">{{ randomItem.description }}</p>
          <div class="random-dish-meta">
            <span class="host-chip">{{ itemHost(randomItem) }}</span>
            <span v-if="randomItem.folderIds?.length || randomItem.folderId" class="folder-chip">📁 {{ folderPaths(randomItem) }}</span>
          </div>
        </div>
      </div>
      <div v-else class="empty-random">
        <el-empty description="暂无可推荐的收藏，快去添加吧！" />
      </div>
      <template #footer>
        <div class="random-dialog-footer">
          <el-button @click="changeRandomFilter">调整范围</el-button>
          <el-button v-if="randomItem" :icon="Refresh" :loading="loadingRandom" @click="fetchRandomDish">换一个</el-button>
          <el-button v-if="randomItem" type="primary" :icon="Link" @click="openRandomUrl">打开链接</el-button>
          <el-button @click="randomDialogVisible = false">关闭</el-button>
        </div>
      </template>
    </el-dialog>

    <AiChatPanel v-model="aiChatVisible" :context="aiDirectoryContext" />
  </div>
</template>
