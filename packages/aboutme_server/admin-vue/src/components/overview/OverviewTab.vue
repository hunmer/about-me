<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useUIStore } from '@/stores/ui'
import { useFilesStore } from '@/stores/files'
import { useAuthStore } from '@/stores/auth'
import { authApi } from '@/api'
import type { UserInfo } from '@/api/types'
import StatsGrid from './StatsGrid.vue'
import ActivityList from './ActivityList.vue'

const uiStore = useUIStore()
const filesStore = useFilesStore()
const authStore = useAuthStore()

const userInfo = ref<UserInfo | null>(null)

// 加载用户信息
async function loadUserInfo(): Promise<void> {
  try {
    const response = await authApi.getUserInfo()
    if (response.success && response.user_info) {
      userInfo.value = response.user_info
    }
  } catch (err) {
    console.error('Failed to load user info:', err)
  }
}

function handleApiClick(): void {
  uiStore.setTab('settings')
}

function goTab(tab: 'apikeys' | 'files' | 'settings'): void {
  uiStore.setTab(tab)
}

async function handleQuickSync(): Promise<void> {
  await filesStore.loadFiles()
}

onMounted(() => {
  loadUserInfo()
})
</script>

<template>
  <div class="flex w-full flex-col">
    <!-- 装饰光晕 -->
    <div class="relative w-full pb-12 pt-6">
      <div class="pointer-events-none absolute -top-12 left-1/3 -z-10 h-40 w-96 rounded-full bg-primary/10 blur-[90px]" />
      <div class="pointer-events-none absolute right-12 top-48 -z-10 h-36 w-80 rounded-full bg-tertiary/10 blur-[100px]" />

      <!-- 段落标题 / 上下文栏 -->
      <div class="mb-8 flex flex-col justify-between gap-4 md:flex-row md:items-end">
        <div>
          <h2 class="text-2xl font-bold tracking-tight text-on-surface">系统总览看板</h2>
        </div>

        <!-- 节点信息卡 -->
        <div class="flex items-center gap-4 rounded-xl bg-surface-container/60 px-4 py-2 shadow-lg backdrop-blur-xl">
          <div class="flex flex-col">
            <span class="font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">当前同步节点</span>
            <span class="font-mono text-sm font-bold text-primary">{{ authStore.serverUrl.replace(/^https?:\/\//, '') }}</span>
          </div>
          <div class="h-7 w-px bg-outline-variant/60" />
          <div class="flex items-center gap-2">
            <span class="material-symbols-outlined text-lg" :class="uiStore.serverStatus === 'online' ? 'text-primary' : 'text-error'">
              {{ uiStore.serverStatus === 'online' ? 'cloud_done' : 'cloud_off' }}
            </span>
          </div>
        </div>
      </div>

      <!-- 4 张统计卡片 -->
      <StatsGrid
        :total-files="filesStore.stats.totalFiles"
        :total-size="filesStore.formattedTotalSize"
        :server-status="uiStore.serverStatus"
        :api-enabled="authStore.hasEncryptionKey"
        :user-info="userInfo"
        @click-api="handleApiClick"
      />

      <!-- 双栏主区域 -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <!-- 左栏：最近活动审计流 (8 cols) -->
        <div class="flex flex-col gap-4 lg:col-span-8">
          <div class="relative overflow-hidden rounded-xl bg-surface-container/60 p-6 shadow-xl backdrop-blur-xl">
            <div class="mb-6 flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-surface-variant text-primary">
                  <span class="material-symbols-outlined text-[20px]">receipt_long</span>
                </div>
                <h3 class="text-base font-semibold tracking-tight text-on-surface">最近活动</h3>
              </div>
            </div>

            <ActivityList :activities="uiStore.recentActivities" />
          </div>
        </div>

        <!-- 右栏：快捷操作 (4 cols) -->
        <div class="flex flex-col gap-6 lg:col-span-4">
          <!-- 快捷控制 -->
          <div class="rounded-xl bg-surface-container/60 p-5 shadow-xl backdrop-blur-xl">
            <div class="mb-4 flex items-center gap-2.5">
              <span class="material-symbols-outlined text-[20px] text-primary">bolt</span>
              <h3 class="text-sm font-semibold uppercase tracking-wider text-on-surface">快捷控制</h3>
            </div>
            <div class="space-y-3">
              <!-- 生成新 API 密钥 -->
              <button
                type="button"
                class="group flex w-full items-center justify-between rounded-lg bg-surface-container-high/70 p-3 text-left transition-all duration-200 hover:bg-surface-container-highest/80"
                @click="goTab('apikeys')"
              >
                <div class="flex items-center gap-3">
                  <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-on-primary">
                    <span class="material-symbols-outlined text-base">vpn_key</span>
                  </div>
                  <span class="block text-xs font-semibold text-on-surface">生成新 API 密钥</span>
                </div>
                <span class="material-symbols-outlined text-sm text-on-surface-variant transition-transform group-hover:translate-x-1 group-hover:text-primary">
                  arrow_forward
                </span>
              </button>

              <!-- 立即刷新数据 -->
              <button
                type="button"
                class="group flex w-full items-center justify-between rounded-lg bg-surface-container-high/70 p-3 text-left transition-all duration-200 hover:bg-surface-container-highest/80"
                @click="handleQuickSync"
              >
                <div class="flex items-center gap-3">
                  <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary-container text-on-primary-container transition-transform group-hover:scale-105">
                    <span class="material-symbols-outlined text-base">sync</span>
                  </div>
                  <span class="block text-xs font-semibold text-on-surface">刷新同步数据</span>
                </div>
                <span class="material-symbols-outlined text-sm text-on-surface-variant transition-transform group-hover:translate-x-1 group-hover:text-primary">
                  arrow_forward
                </span>
              </button>

              <!-- 导出与设置 -->
              <button
                type="button"
                class="group flex w-full items-center justify-between rounded-lg bg-surface-container-high/70 p-3 text-left transition-all duration-200 hover:bg-surface-container-highest/80"
                @click="goTab('settings')"
              >
                <div class="flex items-center gap-3">
                  <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-surface-variant text-on-surface-variant transition-colors group-hover:text-primary">
                    <span class="material-symbols-outlined text-base">settings</span>
                  </div>
                  <span class="block text-xs font-semibold text-on-surface">安全与数据操作</span>
                </div>
                <span class="material-symbols-outlined text-sm text-on-surface-variant transition-colors group-hover:text-on-surface">
                  chevron_right
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
