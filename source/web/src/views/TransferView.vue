<script setup>
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import {
  downloadTransferFile,
  getTransferContent,
  saveTransferText,
  uploadTransferFile
} from "../api/transfer";

const maxFileSize = 100 * 1024 * 1024;
const activeInput = ref("file");
const fileInput = ref(null);
const text = ref("");
const content = ref(null);
const loading = ref(false);
const saving = ref(false);
const dragging = ref(false);

async function loadContent() {
  loading.value = true;
  try {
    const result = await getTransferContent();
    content.value = result.content;
    if (result.content?.type === "text") text.value = result.content.text;
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    loading.value = false;
  }
}

function selectFile() {
  fileInput.value?.click();
}

function validateFile(file) {
  if (!file) return false;
  if (file.size > maxFileSize) {
    ElMessage.error("文件不能超过 100 MB");
    return false;
  }
  return true;
}

async function handleFile(file) {
  if (!validateFile(file)) return;
  saving.value = true;
  try {
    await uploadTransferFile(file);
    ElMessage.success("文件已保存");
    await loadContent();
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

function onFileChange(event) {
  handleFile(event.target.files?.[0]);
  event.target.value = "";
}

function onDrop(event) {
  dragging.value = false;
  handleFile(event.dataTransfer.files?.[0]);
}

async function saveText() {
  if (!text.value.trim()) {
    ElMessage.warning("请输入文字内容");
    return;
  }
  saving.value = true;
  try {
    await saveTransferText(text.value);
    ElMessage.success("文字已保存");
    await loadContent();
  } catch (error) {
    ElMessage.error(error.message);
  } finally {
    saving.value = false;
  }
}

async function copyText() {
  try {
    await navigator.clipboard.writeText(content.value?.text || "");
    ElMessage.success("文字已复制");
  } catch {
    ElMessage.error("复制失败，请手动选择文字");
  }
}

async function downloadFile() {
  try {
    const response = await downloadTransferFile();
    const blob = await response.blob();
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = content.value.fileName || "download";
    link.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    ElMessage.error(error.message);
  }
}

onMounted(loadContent);
</script>

<template>
  <div class="page-content transfer-page">
    <div class="section-heading page-title">
      <div>
        <p class="eyebrow">工具</p>
        <h1>数据传输</h1>
        <p class="lead">在同一个账号的不同设备之间保存一条文件或文字。</p>
      </div>
    </div>

    <el-card class="transfer-card" shadow="never">
      <div class="transfer-tabs">
        <el-button :type="activeInput === 'file' ? 'primary' : 'default'" @click="activeInput = 'file'">文件</el-button>
        <el-button :type="activeInput === 'text' ? 'primary' : 'default'" @click="activeInput = 'text'">文字</el-button>
      </div>

      <div v-if="activeInput === 'file'" class="upload-zone" :class="{ dragging }" @dragover.prevent="dragging = true" @dragleave.prevent="dragging = false" @drop.prevent="onDrop" @click="selectFile">
        <input ref="fileInput" type="file" hidden @change="onFileChange">
        <strong>拖拽文件到这里</strong>
        <span>或点击选择文件，单个文件最大 100 MB</span>
      </div>
      <div v-else class="text-input-area">
        <el-input v-model="text" type="textarea" :rows="8" placeholder="输入需要在设备之间传递的文字" />
        <el-button type="primary" :loading="saving" @click="saveText">保存文字</el-button>
      </div>

      <el-divider />

      <div v-loading="loading" class="current-content">
        <template v-if="content?.type === 'file'">
          <p class="muted">当前文件</p>
          <div class="content-row">
            <div>
              <h2>{{ content.fileName }}</h2>
              <p class="muted">{{ content.fileSize }} 字节</p>
            </div>
            <el-button type="primary" @click="downloadFile">下载文件</el-button>
          </div>
        </template>
        <template v-else-if="content?.type === 'text'">
          <p class="muted">当前文字</p>
          <pre class="saved-text">{{ content.text }}</pre>
          <el-button @click="copyText">复制文字</el-button>
        </template>
        <el-empty v-else description="当前没有内容" />
      </div>
    </el-card>
  </div>
</template>
