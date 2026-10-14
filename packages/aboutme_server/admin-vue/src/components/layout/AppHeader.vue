<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { useUIStore } from '@/stores/ui'
import { useDialog } from '@/composables/useDialog'
import { useMessage } from '@/composables/useMessage'

const authStore = useAuthStore()
const uiStore = useUIStore()
const dialog = useDialog()
const message = useMessage()

function handleLogout(): void {
  dialog.warning({
    title: '确认退出',
    content: '确定要退出登录吗？',
    positiveText: '退出',
    negativeText: '取消',
    onPositiveClick: () => {
      authStore.logout()
      message.success('已退出登录')
    }
  })
}
</script>

<template>
  <div class="mx-auto w-full max-w-7xl px-6 h-16 flex items-center justify-between">
    <div class="flex items-center gap-6">
      <div class="flex items-center gap-3">
        <div
          class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 shadow-[0_0_20px_rgba(125,211,252,0.15)]"
        >
          <span class="material-symbols-outlined text-primary text-2xl">
            cloud_sync
          </span>
        </div>
        <div>
          <span class="text-base font-bold tracking-tight text-on-surface">
            Aboutme Sync Server
          </span>
        </div>
      </div>

      <div class="hidden h-5 w-px bg-outline-variant/60 sm:block" />

      <!-- 服务器状态胶囊 -->
      <div
        class="flex items-center gap-2 rounded-full bg-surface-container-high/80 px-3 py-1 shadow-[0_0_15px_rgba(125,211,252,0.06)]"
      >
        <span class="relative flex h-2 w-2">
          <span
            class="absolute inline-flex h-full w-full animate-ping rounded-full opacity-75"
            :class="uiStore.serverStatus === 'online' ? 'bg-primary' : 'bg-error'"
          />
          <span
            class="relative inline-flex h-2 w-2 rounded-full"
            :class="uiStore.serverStatus === 'online' ? 'bg-primary' : 'bg-error'"
          />
        </span>
        <span class="text-xs font-medium text-on-surface">
          {{ uiStore.serverStatus === 'online' ? '在线' : '离线' }}
        </span>
      </div>
    </div>

    <div class="flex items-center gap-4">
      <div
        class="flex items-center gap-3 rounded-full bg-surface-container/60 px-3 py-1.5"
      >
        <div class="flex h-8 w-8 items-center justify-center rounded-full bg-primary">
          <span class="material-symbols-outlined text-[18px] text-on-primary">
            person
          </span>
        </div>
        <div class="pr-1.5 text-left">
          <span class="block text-xs font-semibold leading-tight text-on-surface">
            {{ authStore.username || 'admin' }}
          </span>
        </div>
      </div>

      <button
        type="button"
        class="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium text-on-surface-variant transition-colors hover:bg-error-container/40 hover:text-error"
        @click="handleLogout"
      >
        <span class="material-symbols-outlined text-base">logout</span>
        <span>退出</span>
      </button>
    </div>
  </div>
</template>
