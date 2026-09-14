<script setup lang="ts">
import type { Activity } from '@/stores/ui'
import { formatTime } from '@/utils/format'

interface Props {
  activities: Activity[]
}

defineProps<Props>()

const metaMap: Record<string, { icon: string; label: string; box: string; tag: string }> = {
  download: { icon: 'download_for_offline', label: '下载备份', box: 'bg-primary/10 text-primary', tag: 'bg-primary-container/60 text-on-primary-container' },
  upload: { icon: 'cloud_upload', label: '同步上传', box: 'bg-primary/10 text-primary', tag: 'bg-primary-container/60 text-on-primary-container' },
  delete: { icon: 'auto_delete', label: '存储清理', box: 'bg-secondary-container text-secondary', tag: 'bg-surface-variant text-on-surface-variant' },
  api_key: { icon: 'key', label: '安全令牌', box: 'bg-tertiary-container text-tertiary', tag: 'bg-tertiary-container text-on-tertiary-container' },
  settings: { icon: 'settings', label: '系统设置', box: 'bg-surface-variant text-on-surface', tag: 'bg-surface-container-highest text-on-surface-variant' },
  export: { icon: 'archive', label: '数据导出', box: 'bg-primary/10 text-primary', tag: 'bg-primary-container/60 text-on-primary-container' },
  login: { icon: 'lock_open', label: '安全鉴权', box: 'bg-primary/10 text-primary', tag: 'bg-primary-container/60 text-on-primary-container' },
  sync: { icon: 'sync', label: '同步事件', box: 'bg-secondary-container text-secondary', tag: 'bg-surface-variant text-on-surface-variant' }
}

function meta(type: string) {
  return metaMap[type] || { icon: 'extension', label: '操作事件', box: 'bg-surface-variant text-on-surface-variant', tag: 'bg-surface-container-highest text-on-surface-variant' }
}
</script>

<template>
  <div v-if="activities.length === 0" class="flex flex-col items-center gap-3 py-10 text-on-surface-variant">
    <span class="material-symbols-outlined text-4xl opacity-40">receipt_long</span>
    <span class="text-xs font-mono">暂无活动记录 · 等待操作事件流入</span>
  </div>

  <div v-else class="relative space-y-3">
    <div
      v-for="activity in activities"
      :key="activity.id"
      class="group flex items-start gap-4 rounded-lg bg-surface-container-low/70 p-3.5 transition-all duration-200 hover:bg-surface-container-high/60"
    >
      <div
        class="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
        :class="meta(activity.type).box"
      >
        <span class="material-symbols-outlined text-[20px]">{{ meta(activity.type).icon }}</span>
      </div>
      <div class="min-w-0 flex-1">
        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center gap-2 truncate">
            <span
              class="rounded px-1.5 py-0.5 font-mono text-[10px] font-medium"
              :class="meta(activity.type).tag"
            >
              {{ meta(activity.type).label }}
            </span>
            <span class="truncate text-xs font-semibold text-on-surface">{{ activity.message }}</span>
          </div>
          <span class="whitespace-nowrap font-mono text-[10px] text-on-surface-variant">
            {{ formatTime(activity.time) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
