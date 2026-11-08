<script setup>
import { nextTick, ref, watch } from "vue";
import { ChatDotRound, Close, Cpu, Promotion, RefreshRight } from "@element-plus/icons-vue";
import { chatWithDirectory } from "../api/ai";

const props = defineProps({
  context: { type: Object, required: true },
  modelValue: { type: Boolean, default: false }
});

const emit = defineEmits(["update:modelValue"]);
const messages = ref([]);
const draft = ref("");
const sending = ref(false);
const failedMessage = ref("");
const messagesEl = ref(null);

function close() {
  emit("update:modelValue", false);
}

function resetConversation() {
  messages.value = [];
  draft.value = "";
  failedMessage.value = "";
  sending.value = false;
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesEl.value) messagesEl.value.scrollTop = messagesEl.value.scrollHeight;
  });
}

function contextKey(context) {
  return `${context.space}:${context.directoryId ?? "all"}:${context.directoryPath || ""}`;
}

async function sendMessage(message = draft.value) {
  const content = message.trim();
  if (!content || sending.value) return;
  failedMessage.value = "";
  draft.value = "";
  messages.value.push({ role: "user", content });
  sending.value = true;
  scrollToBottom();
  try {
    const history = messages.value.slice(0, -1).map(({ role, content: text }) => ({ role, content: text }));
    const result = await chatWithDirectory(props.context, content, history);
    messages.value.push({ role: "assistant", content: result.answer });
  } catch (error) {
    failedMessage.value = content;
    draft.value = content;
    messages.value.push({ role: "error", content: error.message || "AI 暂时无法回复，请重试。" });
  } finally {
    sending.value = false;
    scrollToBottom();
  }
}

function retry() {
  if (!failedMessage.value || sending.value) return;
  let failedIndex = -1;
  for (let index = messages.value.length - 1; index >= 0; index -= 1) {
    if (messages.value[index].role === "error") {
      failedIndex = index;
      break;
    }
  }
  if (failedIndex >= 0) messages.value.splice(failedIndex, 1);
  const content = failedMessage.value;
  const lastUserIndex = messages.value.findLastIndex
    ? messages.value.findLastIndex((message) => message.role === "user" && message.content === content)
    : messages.value.map((message) => message.role === "user" && message.content === content).lastIndexOf(true);
  if (lastUserIndex >= 0) messages.value.splice(lastUserIndex, 1);
  failedMessage.value = "";
  sendMessage(content);
}

watch(() => props.modelValue, (visible) => {
  if (!visible) resetConversation();
});

watch(() => contextKey(props.context), () => {
  if (props.modelValue) resetConversation();
});
</script>

<template>
  <div class="ai-chat-entry">
    <el-button
      v-if="!modelValue"
      class="ai-chat-fab"
      type="primary"
      circle
      :icon="ChatDotRound"
      aria-label="打开 AI Chat"
      title="和 AI 讨论当前目录"
      @click="emit('update:modelValue', true)"
    />

    <section v-if="modelValue" class="ai-chat-panel" aria-label="AI Chat 对话面板">
      <header class="ai-chat-header">
        <div>
          <strong><el-icon><Cpu /></el-icon> AI Chat</strong>
          <small>{{ context.directoryPath || context.directoryName || "全部收藏" }}</small>
        </div>
        <el-button text circle :icon="Close" aria-label="关闭 AI Chat" @click="close" />
      </header>

      <div ref="messagesEl" class="ai-chat-messages" aria-live="polite">
        <div v-if="!messages.length" class="ai-chat-empty">
          <el-icon><Cpu /></el-icon>
          <p>我可以根据当前已加载的 {{ context.loadedItemCount || 0 }} 条收藏和你讨论。</p>
          <small>不会自动读取网页全文。</small>
        </div>
        <div
          v-for="(message, index) in messages"
          :key="`${message.role}-${index}`"
          class="ai-chat-message"
          :class="`is-${message.role}`"
        >
          <span>{{ message.content }}</span>
        </div>
        <div v-if="sending" class="ai-chat-message is-assistant is-loading">AI 正在整理目录内容...</div>
      </div>

      <div v-if="failedMessage" class="ai-chat-retry">
        <span>这次请求没有完成。</span>
        <el-button text type="primary" :icon="RefreshRight" @click="retry">重试</el-button>
      </div>

      <form class="ai-chat-composer" @submit.prevent="sendMessage()">
        <el-input
          v-model="draft"
          type="textarea"
          :rows="2"
          maxlength="4000"
          show-word-limit
          resize="none"
          :disabled="sending"
          placeholder="例如：帮我找出当前目录里适合先阅读的内容"
          aria-label="输入给 AI 的问题"
        />
        <el-button type="primary" :icon="Promotion" :loading="sending" :disabled="!draft.trim()" native-type="submit">
          发送
        </el-button>
      </form>
    </section>
  </div>
</template>

<style scoped>
.ai-chat-entry { position: fixed; right: 28px; bottom: 28px; z-index: 20; }
.ai-chat-fab { width: 54px; height: 54px; box-shadow: 0 10px 24px rgba(21, 94, 86, .28); }
.ai-chat-panel { display: flex; width: min(390px, calc(100vw - 32px)); height: min(620px, calc(95vh - 40px)); flex-direction: column; overflow: hidden; border: 1px solid #dce8e2; border-radius: 18px; background: #fff; box-shadow: 0 18px 48px rgba(24, 52, 58, .2); }
.ai-chat-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 18px; border-bottom: 1px solid #edf2ef; background: #f7fbf8; }
.ai-chat-header strong, .ai-chat-header small { display: block; }
.ai-chat-header strong { color: #155e56; }
.ai-chat-header strong .el-icon { vertical-align: -2px; margin-right: 5px; }
.ai-chat-header small { max-width: 290px; overflow: hidden; margin-top: 5px; color: #7a8a86; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.ai-chat-messages { flex: 1; overflow-y: auto; padding: 16px; background: #fbfcfb; }
.ai-chat-empty { padding: 54px 18px; color: #6f817b; text-align: center; }
.ai-chat-empty .el-icon { color: #155e56; font-size: 30px; }
.ai-chat-empty p { margin: 12px 0 6px; line-height: 1.6; }
.ai-chat-empty small { color: #9aa8a3; }
.ai-chat-message { max-width: 86%; margin: 0 0 12px; padding: 10px 12px; border-radius: 13px; color: #2d403d; line-height: 1.55; white-space: pre-wrap; word-break: break-word; }
.ai-chat-message.is-user { margin-left: auto; background: #155e56; color: white; }
.ai-chat-message.is-assistant { margin-right: auto; background: #eaf3ef; }
.ai-chat-message.is-error { margin-right: auto; background: #fff0ed; color: #a94737; }
.ai-chat-message.is-loading { color: #74857f; font-size: 13px; }
.ai-chat-retry { display: flex; align-items: center; justify-content: space-between; padding: 8px 16px; border-top: 1px solid #f1e4e0; color: #a94737; font-size: 12px; }
.ai-chat-composer { display: flex; align-items: flex-end; gap: 8px; padding: 12px; border-top: 1px solid #edf2ef; background: #fff; }
.ai-chat-composer .el-input { flex: 1; }
@media (max-width: 640px) {
  .ai-chat-entry { right: 16px; bottom: 16px; }
  .ai-chat-panel { width: calc(100vw - 24px); height: min(680px, calc(95vh - 24px)); }
}
</style>
