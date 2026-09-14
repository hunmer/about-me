<script setup lang="ts">
import { ref, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useUIStore } from '@/stores/ui'
import { useMessage } from '@/composables/useMessage'
import { useDialog } from '@/composables/useDialog'
import { formatTime } from '@/utils/format'
import { Button } from '@/components/ui/button'
import CreateKeyModal from './CreateKeyModal.vue'
import KeyResultModal from './KeyResultModal.vue'

const authStore = useAuthStore()
const uiStore = useUIStore()
const message = useMessage()
const dialog = useDialog()

const showCreateModal = ref(false)
const showResultModal = ref(false)
const searchQuery = ref('')
const filterMode = ref<'all' | 'active'>('all')

const filteredKeys = computed(() => {
  let keys = authStore.apiKeys
  if (filterMode.value === 'active') keys = keys.filter(k => !k.is_expired)
  const q = searchQuery.value.trim().toLowerCase()
  if (q) {
    keys = keys.filter(
      k =>
        k.name.toLowerCase().includes(q) ||
        k.key_prefix.toLowerCase().includes(q)
    )
  }
  return keys
})

const activeCount = computed(() => authStore.apiKeys.filter(k => !k.is_expired).length)

function handleCreateSuccess(): void {
  showCreateModal.value = false
  showResultModal.value = true
  uiStore.addActivity('api_key', '创建了 API Key')
}

function handleRevoke(keyId: string, keyName: string): void {
  dialog.warning({
    title: '撤销 API Key',
    content: `确定要撤销密钥 "${keyName}" 吗？关联的服务将立即失去访问权限。`,
    type: 'error',
    positiveText: '确认撤销',
    negativeText: '取消',
    onPositiveClick: async () => {
      uiStore.setLoading(true, '撤销 API Key...')
      try {
        await authStore.revokeApiKey(keyId)
        message.success('API Key 已撤销')
        uiStore.addActivity('api_key', '撤销了一个 API Key')
      } catch (err) {
        message.error(err instanceof Error ? err.message : '撤销失败')
      } finally {
        uiStore.setLoading(false)
      }
    }
  })
}

async function copyPrefix(prefix: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(prefix)
    message.success('已复制前缀到剪贴板')
  } catch {
    message.error('复制失败')
  }
}

function handleCloseResult(): void {
  showResultModal.value = false
  authStore.clearCreatedKey()
}
</script>

<template>
  <div class="flex w-full flex-col space-y-6">
    <!-- 安全通告横幅 -->
    <div class="relative overflow-hidden rounded-xl bg-surface-container/60 p-4 shadow-lg backdrop-blur-xl sm:p-5">
      <div class="pointer-events-none absolute inset-0 bg-gradient-to-r from-primary/10 via-tertiary/5 to-transparent" />
        <div class="z-10 flex items-start gap-3.5">
          <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/15 text-primary shadow-[0_0_15px_rgba(125,211,252,0.2)]">
            <span class="material-symbols-outlined text-[20px]">shield_lock</span>
          </div>
          <div>
            <span class="font-mono text-xs font-semibold uppercase tracking-wider text-primary">安全通告</span>
            <p class="mt-0.5 text-xs leading-relaxed text-on-surface-variant">
              API Key 用于授权 MCP Server 等外部应用安全访问同步数据。密钥创建后仅完整展示一次，请妥善保存。
            </p>
          </div>
        </div>
    </div>

    <!-- 操作头 -->
    <div class="flex flex-col items-stretch justify-between gap-4 sm:flex-row sm:items-center">
      <div class="flex max-w-md flex-1 items-center gap-3">
        <div class="relative w-full">
          <span class="material-symbols-outlined absolute left-3.5 top-1/2 -translate-y-1/2 text-[18px] text-on-surface-variant">search</span>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索密钥名称或前缀..."
            class="w-full rounded-xl bg-surface-container/60 py-2 pl-10 pr-4 text-xs text-on-surface shadow-inner backdrop-blur-md transition-all placeholder:text-on-surface-variant/60 focus:bg-surface-container-high focus:outline-none"
          />
        </div>
        <div class="flex shrink-0 items-center rounded-xl bg-surface-container/60 p-1 text-xs text-on-surface-variant backdrop-blur-md">
          <button
            type="button"
            class="rounded-lg px-2.5 py-1 text-[11px] transition-colors"
            :class="filterMode === 'all' ? 'bg-surface-variant/70 font-medium text-on-surface' : 'hover:text-on-surface'"
            @click="filterMode = 'all'"
          >
            全部 ({{ authStore.apiKeys.length }})
          </button>
          <button
            type="button"
            class="rounded-lg px-2.5 py-1 text-[11px] transition-colors"
            :class="filterMode === 'active' ? 'bg-surface-variant/70 font-medium text-on-surface' : 'hover:text-on-surface'"
            @click="filterMode = 'active'"
          >
            有效 ({{ activeCount }})
          </button>
        </div>
      </div>

      <div class="flex items-center justify-end gap-3">
        <Button size="sm" @click="showCreateModal = true">
          <span class="material-symbols-outlined text-base">add_circle</span>
          <span>创建 API Key</span>
        </Button>
      </div>
    </div>

    <!-- 密钥表格卡片 -->
    <div class="relative overflow-hidden rounded-xl bg-surface-container/60 shadow-xl backdrop-blur-xl">
      <div class="overflow-x-auto">
        <table class="w-full border-collapse text-left text-xs">
          <thead>
            <tr class="bg-surface-container-high/40 font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
              <th class="px-5 py-3.5 font-semibold">密钥名称</th>
              <th class="px-4 py-3.5 font-semibold">密钥前缀</th>
              <th class="px-4 py-3.5 font-semibold">过期时间</th>
              <th class="px-4 py-3.5 font-semibold">最后调用时间</th>
              <th class="px-4 py-3.5 font-semibold">状态</th>
              <th class="px-5 py-3.5 text-right font-semibold">操作</th>
            </tr>
          </thead>
          <tbody class="text-on-surface">
            <tr v-if="filteredKeys.length === 0">
              <td colspan="6" class="px-5 py-14">
                <div class="flex flex-col items-center gap-3 text-on-surface-variant">
                  <span class="material-symbols-outlined text-5xl opacity-30">key</span>
                  <span class="font-mono text-xs">暂无 API Key · 点击右上角创建</span>
                </div>
              </td>
            </tr>

            <tr
              v-for="key in filteredKeys"
              :key="key.id"
              class="transition-colors hover:bg-surface-container-high/30"
              :class="key.is_expired ? 'opacity-60' : ''"
            >
              <td class="px-5 py-4">
                <div class="flex items-center gap-3">
                  <div
                    class="flex h-8 w-8 items-center justify-center rounded-lg"
                    :class="key.is_expired ? 'bg-surface-variant text-outline' : 'bg-primary-container/30 text-primary'"
                  >
                    <span class="material-symbols-outlined text-[18px]">terminal</span>
                  </div>
                  <div>
                    <span class="block font-semibold text-on-surface" :class="key.is_expired ? 'line-through' : ''">
                      {{ key.name }}
                    </span>
                    <span class="font-mono text-[10px] text-on-surface-variant">ID: {{ key.id }}</span>
                  </div>
                </div>
              </td>
              <td class="px-4 py-4 font-mono text-[11px]">
                <span
                  class="rounded px-2 py-0.5"
                  :class="key.is_expired ? 'bg-surface-container-lowest/40 text-outline' : 'bg-surface-container-lowest/80 text-primary'"
                >
                  {{ key.key_prefix }}***
                </span>
              </td>
              <td class="px-4 py-4 font-mono text-[11px] text-on-surface-variant">
                <template v-if="key.is_expired">
                  <span class="text-error">已于 {{ formatTime(key.expires_at) }} 过期</span>
                </template>
                <template v-else-if="key.expires_at">
                  {{ formatTime(key.expires_at) }}
                </template>
                <template v-else>
                  <span class="text-secondary/70">永不过期</span>
                </template>
              </td>
              <td class="px-4 py-4 font-mono text-[11px] text-on-surface-variant">
                <div v-if="key.last_used_at" class="flex items-center gap-1.5 text-on-surface">
                  <span class="h-1.5 w-1.5 animate-pulse rounded-full bg-primary" />
                  {{ formatTime(key.last_used_at) }}
                </div>
                <span v-else class="text-outline">从未调用</span>
              </td>
              <td class="px-4 py-4">
                <span
                  v-if="key.is_expired"
                  class="inline-flex items-center gap-1 rounded-full bg-surface-variant px-2 py-0.5 text-[11px] font-medium text-outline"
                >
                  <span class="material-symbols-outlined text-[12px]">schedule</span>
                  已过期
                </span>
                <span
                  v-else
                  class="inline-flex items-center gap-1 rounded-full bg-primary-container/40 px-2 py-0.5 text-[11px] font-medium text-primary"
                >
                  <span class="material-symbols-outlined text-[12px]">check_circle</span>
                  正常
                </span>
              </td>
              <td class="px-5 py-4 text-right">
                <div class="inline-flex items-center gap-1.5">
                  <button
                    type="button"
                    class="flex items-center gap-1 rounded-lg bg-surface-container-high/80 px-2 py-1 text-[11px] font-medium text-on-surface-variant transition-colors hover:bg-surface-variant hover:text-on-surface"
                    title="复制前缀"
                    @click="copyPrefix(key.key_prefix)"
                  >
                    <span class="material-symbols-outlined text-[14px]">content_copy</span>
                    <span>复制前缀</span>
                  </button>
                  <button
                    type="button"
                    class="flex items-center gap-1 rounded-lg bg-error-container/30 px-2 py-1 text-[11px] font-medium text-error transition-colors hover:bg-error-container"
                    title="撤销 Key"
                    @click="handleRevoke(key.id, key.name)"
                  >
                    <span class="material-symbols-outlined text-[14px]">block</span>
                    <span>撤销</span>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 表尾统计 -->
      <div class="flex items-center gap-4 bg-surface-container-low/80 p-4 font-mono text-xs text-on-surface-variant">
        <span>活跃密钥: <strong class="font-semibold text-primary">{{ activeCount }} 个</strong></span>
        <span>密钥总数: <strong class="font-semibold text-on-surface">{{ authStore.apiKeys.length }} 个</strong></span>
      </div>
    </div>

    <CreateKeyModal v-model:show="showCreateModal" @success="handleCreateSuccess" />
    <KeyResultModal
      v-model:show="showResultModal"
      :api-key="authStore.createdKey"
      @close="handleCloseResult"
    />
  </div>
</template>
