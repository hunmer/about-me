<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useUIStore } from '@/stores/ui'
import { useMessage } from '@/composables/useMessage'
import { authApi } from '@/api'
import { Switch } from '@/components/ui/switch'

const uiStore = useUIStore()
const message = useMessage()

// API 访问开关状态
const apiEnabled = ref(false)
const loadingApiStatus = ref(false)
const togglingApi = ref(false)

// 初始化加载 API 访问状态
onMounted(async () => {
  await loadApiAccessStatus()
})

async function loadApiAccessStatus(): Promise<void> {
  loadingApiStatus.value = true
  try {
    const response = await authApi.getApiAccessStatus()
    apiEnabled.value = response.enabled
  } catch (e) {
    console.error('获取 API 访问状态失败:', e)
  } finally {
    loadingApiStatus.value = false
  }
}

// 切换 API 访问状态
async function handleToggleApi(enabled: boolean): Promise<void> {
  togglingApi.value = true
  try {
    const response = await authApi.setApiAccessStatus(enabled)
    apiEnabled.value = response.enabled
    message.success(response.message)
    uiStore.addActivity('settings', enabled ? '开启了 API 访问' : '关闭了 API 访问')
  } catch (e) {
    // 恢复原状态
    apiEnabled.value = !enabled
    const errorMessage = e instanceof Error ? e.message : '设置失败'
    message.error(errorMessage)
  } finally {
    togglingApi.value = false
  }
}

</script>

<template>
  <!-- 模块卡片 -->
  <div class="relative overflow-hidden rounded-2xl bg-surface/65 p-6 shadow-[0_4px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl sm:p-8">
    <div class="pointer-events-none absolute -right-24 -top-24 h-48 w-48 rounded-full bg-primary/10 blur-3xl" />

    <!-- 标题区 -->
    <div class="flex items-start justify-between gap-4 border-b border-outline-variant/30 pb-6">
      <div class="flex items-center gap-3.5">
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-container/40 text-primary shadow-[0_0_20px_rgba(125,211,252,0.12)]">
          <span class="material-symbols-outlined text-xl">token</span>
        </div>
        <h2 class="text-lg font-bold tracking-tight text-on-surface">API 访问控制</h2>
      </div>
    </div>

    <!-- 全局 API 开关 -->
    <div class="flex flex-col justify-between gap-4 pt-6 sm:flex-row sm:items-center">
      <div class="space-y-1 pr-4">
        <span class="text-sm font-semibold text-on-surface">全局 API 访问权限</span>
        <p class="text-xs leading-relaxed text-on-surface-variant">
          允许外部客户端及自动化脚本通过 Bearer Token 访问。
        </p>
      </div>
      <Switch
        :model-value="apiEnabled"
        :disabled="loadingApiStatus || togglingApi"
        @update:model-value="handleToggleApi"
      />
    </div>
  </div>
</template>
