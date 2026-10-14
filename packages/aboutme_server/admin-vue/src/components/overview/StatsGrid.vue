<script setup lang="ts">
import type { ServerStatus } from '@/stores/ui'
import type { UserInfo } from '@/api/types'

interface Props {
  totalFiles: number
  totalSize: string
  serverStatus: ServerStatus
  apiEnabled: boolean
  userInfo?: UserInfo | null
}

const props = defineProps<Props>()

const emit = defineEmits<{
  clickApi: []
}>()

// 格式化日期
function formatDate(dateStr: string): string {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  })
}

// 格式化文件大小
function formatSize(bytes: number): string {
  if (!bytes) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  let unitIndex = 0
  let size = bytes
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024
    unitIndex++
  }
  return `${size.toFixed(1)} ${units[unitIndex]}`
}

// 存储占配额 2GB 的百分比
function storagePercent(): number {
  const total = props.userInfo?.sync_total_size ?? 0
  return Math.min(100, +((total / (2 * 1024 * 1024 * 1024)) * 100).toFixed(1))
}
</script>

<template>
  <div class="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
    <!-- Card 1: 当前用户 -->
    <div
      class="group relative rounded-xl bg-surface-container/60 p-5 shadow-lg backdrop-blur-xl transition-all duration-300 hover:bg-surface-container-high/80 hover:shadow-[0_0_30px_rgba(125,211,252,0.12)]"
    >
      <div class="pointer-events-none absolute right-0 top-0 h-24 w-24 rounded-full bg-primary/5 opacity-0 blur-2xl transition-opacity group-hover:opacity-100" />
      <div class="absolute right-5 top-5 flex h-8 w-8 items-center justify-center rounded-lg bg-surface-variant/80 text-primary transition-transform group-hover:scale-110">
        <span class="material-symbols-outlined text-[19px]">verified_user</span>
      </div>
      <div class="space-y-1">
        <div class="flex items-baseline gap-2">
          <h3 class="text-xl font-bold tracking-tight text-on-surface">{{ userInfo?.username || '-' }}</h3>
          <span class="rounded-full bg-primary-container px-2 py-0.5 text-[10px] font-medium text-on-primary-container">管理员</span>
        </div>
        <div class="mt-2 flex items-center justify-between pt-2 font-mono text-[11px] text-on-surface-variant">
          <span>注册日期</span>
          <span class="text-on-surface">{{ formatDate(userInfo?.created_at || '') }}</span>
        </div>
        <div class="flex items-center justify-between font-mono text-[11px] text-on-surface-variant">
          <span>加密密钥</span>
          <span class="flex items-center gap-1 text-primary">
            <span class="inline-block h-1.5 w-1.5 rounded-full" :class="apiEnabled ? 'bg-primary' : 'bg-outline'" />
            {{ apiEnabled ? '已启用' : '未设置' }}
          </span>
        </div>
      </div>
    </div>

    <!-- Card 2: 同步文件数 -->
    <div
      class="group relative rounded-xl bg-surface-container/60 p-5 shadow-lg backdrop-blur-xl transition-all duration-300 hover:bg-surface-container-high/80 hover:shadow-[0_0_30px_rgba(125,211,252,0.12)]"
    >
      <div class="pointer-events-none absolute right-0 top-0 h-24 w-24 rounded-full bg-primary/5 opacity-0 blur-2xl transition-opacity group-hover:opacity-100" />
      <div class="absolute right-5 top-5 flex h-8 w-8 items-center justify-center rounded-lg bg-surface-variant/80 text-primary transition-transform group-hover:scale-110">
        <span class="material-symbols-outlined text-[19px]">folder_copy</span>
      </div>
      <div class="space-y-1">
        <div class="flex items-baseline gap-2">
          <h3 class="text-2xl font-bold tracking-tight text-on-surface">{{ userInfo?.sync_file_count ?? totalFiles }}</h3>
          <span class="text-xs text-on-surface-variant">个文件</span>
        </div>
        <div class="mt-2 flex items-center justify-between pt-2 font-mono text-[11px] text-on-surface-variant">
          <span>分类目录</span>
          <span class="font-semibold text-on-surface">{{ userInfo?.sync_folder_count ?? 0 }} 个目录</span>
        </div>
        <div class="flex items-center justify-between font-mono text-[11px] text-on-surface-variant">
          <span>本地清单</span>
          <span class="font-semibold text-on-surface">{{ totalFiles }} 项已索引</span>
        </div>
      </div>
    </div>

    <!-- Card 3: 总存储大小 -->
    <div
      class="group relative rounded-xl bg-surface-container/60 p-5 shadow-lg backdrop-blur-xl transition-all duration-300 hover:bg-surface-container-high/80 hover:shadow-[0_0_30px_rgba(125,211,252,0.12)]"
    >
      <div class="pointer-events-none absolute right-0 top-0 h-24 w-24 rounded-full bg-tertiary/10 opacity-0 blur-2xl transition-opacity group-hover:opacity-100" />
      <div class="absolute right-5 top-5 flex h-8 w-8 items-center justify-center rounded-lg bg-surface-variant/80 text-tertiary transition-transform group-hover:scale-110">
        <span class="material-symbols-outlined text-[19px]">database</span>
      </div>
      <div class="space-y-1">
        <div class="flex items-baseline justify-between">
          <h3 class="text-2xl font-bold tracking-tight text-on-surface">
            {{ userInfo?.sync_total_size_mb ?? totalSize }}
            <span v-if="userInfo" class="text-sm font-normal text-on-surface-variant">MB</span>
          </h3>
          <span v-if="userInfo" class="font-mono text-[11px] text-tertiary">{{ storagePercent() }}%</span>
        </div>
        <!-- 进度条 -->
        <div class="my-2 h-1.5 w-full overflow-hidden rounded-full bg-surface-container-highest">
          <div
            class="h-1.5 rounded-full bg-gradient-to-r from-primary to-tertiary transition-all duration-500"
            :style="{ width: `${Math.max(storagePercent(), userInfo ? 2 : 0)}%` }"
          />
        </div>
        <div class="flex items-center justify-between font-mono text-[11px] text-on-surface-variant">
          <span>格式化大小</span>
          <span class="text-on-surface">{{ formatSize(userInfo?.sync_total_size ?? 0) }}</span>
        </div>
      </div>
    </div>

    <!-- Card 4: 服务器状态（可点击跳转） -->
    <button
      type="button"
      class="group relative block cursor-pointer rounded-xl bg-surface-container/60 p-5 text-left shadow-lg backdrop-blur-xl transition-all duration-300 hover:scale-[1.02] hover:bg-surface-container-high hover:shadow-[0_0_30px_rgba(125,211,252,0.2)]"
      @click="emit('clickApi')"
    >
      <div class="pointer-events-none absolute right-0 top-0 h-24 w-24 rounded-full bg-primary/15 blur-2xl" />
      <div class="absolute right-5 top-5 flex items-center gap-1 font-mono text-[10px] text-primary opacity-80 transition-opacity group-hover:opacity-100">
        <span>详情</span>
        <span class="material-symbols-outlined text-xs transition-transform group-hover:translate-x-0.5">arrow_forward</span>
      </div>
      <div class="space-y-1">
        <div class="flex items-center gap-2">
          <span class="relative flex h-2.5 w-2.5">
            <span
              class="absolute inline-flex h-full w-full animate-ping rounded-full opacity-75"
              :class="serverStatus === 'online' ? 'bg-primary' : 'bg-error'"
            />
            <span
              class="relative inline-flex h-2.5 w-2.5 rounded-full"
              :class="serverStatus === 'online' ? 'bg-primary' : 'bg-error'"
            />
          </span>
          <h3 class="text-xl font-bold tracking-tight text-on-surface">
            {{ serverStatus === 'online' ? '在线 (Online)' : '离线 (Offline)' }}
          </h3>
        </div>
        <div class="mt-2 flex items-center justify-between pt-2 font-mono text-[11px] text-on-surface-variant">
          <span>心跳检测</span>
          <span class="font-semibold text-primary">30s 轮询</span>
        </div>
        <div class="flex items-center justify-between font-mono text-[11px] text-on-surface-variant">
          <span>API 服务</span>
          <span class="text-on-surface">{{ apiEnabled ? '已启用 / 密钥就绪' : '密钥未设置' }}</span>
        </div>
      </div>
    </button>
  </div>
</template>
