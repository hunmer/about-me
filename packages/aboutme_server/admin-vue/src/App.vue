<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useUIStore } from '@/stores/ui'
import { useFilesStore } from '@/stores/files'
import { apiClient } from '@/api'

import AppHeader from '@/components/layout/AppHeader.vue'
import TabNavigation from '@/components/layout/TabNavigation.vue'
import AuthPanel from '@/components/login/AuthPanel.vue'
import OverviewTab from '@/components/overview/OverviewTab.vue'
import FilesTab from '@/components/files/FilesTab.vue'
import ApiKeysTab from '@/components/api-keys/ApiKeysTab.vue'
import PluginsTab from '@/components/plugins/PluginsTab.vue'
import DevicesTab from '@/components/devices/DevicesTab.vue'
import SettingsTab from '@/components/settings/SettingsTab.vue'
import LoadingOverlay from '@/components/common/LoadingOverlay.vue'
import Toaster from '@/components/common/Toaster.vue'
import AppDialog from '@/components/common/AppDialog.vue'

const authStore = useAuthStore()
const uiStore = useUIStore()
const filesStore = useFilesStore()

// 注册成功后回填的凭据
const prefillCredentials = ref<{ username: string; password: string } | null>(null)

onMounted(async () => {
  authStore.init()

  if (authStore.isLoggedIn) {
    try {
      await loadDashboardData()
    } catch (error) {
      console.log('Initial load failed:', error)
    }
  }

  // 定期检查服务器状态
  setInterval(checkServerHealth, 30000)
})

async function loadDashboardData(): Promise<void> {
  await Promise.all([
    checkServerHealth(),
    filesStore.loadFiles(),
    authStore.loadApiKeys()
  ])
}

async function checkServerHealth(): Promise<void> {
  const isOnline = await apiClient.healthCheck()
  uiStore.setServerStatus(isOnline ? 'online' : 'offline')
}

function handleRegistered(username: string, password: string): void {
  prefillCredentials.value = { username, password }
}
</script>

<template>
  <div class="relative flex min-h-screen flex-col bg-background">
    <!-- 全局环境光晕 -->
    <div class="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <div class="absolute -top-48 left-1/4 h-[350px] w-[600px] rounded-full bg-primary/10 blur-[140px]" />
      <div class="absolute top-1/3 -right-32 h-[350px] w-[500px] rounded-full bg-tertiary/5 blur-[120px]" />
    </div>

    <!-- 登录 / 注册 -->
    <AuthPanel
      v-if="!authStore.isLoggedIn"
      :prefill-username="prefillCredentials?.username"
      :prefill-password="prefillCredentials?.password"
      @registered="handleRegistered"
    />

    <!-- 控制台 -->
    <template v-else>
      <header
        class="fixed inset-x-0 top-0 z-50 h-28 bg-surface/75 shadow-[0_1px_12px_rgba(0,0,0,0.4)] backdrop-blur-2xl"
      >
        <div class="mx-auto flex h-16 items-center">
          <AppHeader />
        </div>
        <div class="mx-auto flex h-12 items-center">
          <TabNavigation />
        </div>
      </header>

      <main class="relative z-10 w-full min-h-screen flex-1 bg-background pt-28">
        <div class="tab-content mx-auto w-full max-w-7xl px-6 py-6">
          <OverviewTab v-show="uiStore.activeTab === 'overview'" />
          <FilesTab v-show="uiStore.activeTab === 'files'" />
          <ApiKeysTab v-show="uiStore.activeTab === 'apikeys'" />
          <PluginsTab v-show="uiStore.activeTab === 'plugins'" />
          <DevicesTab v-show="uiStore.activeTab === 'devices'" />
          <SettingsTab v-show="uiStore.activeTab === 'settings'" />
        </div>

        <footer class="relative z-10 mt-16 w-full bg-surface-container-lowest/70 py-6 backdrop-blur-lg">
          <div class="mx-auto max-w-7xl px-6 text-center font-mono text-xs text-on-surface-variant">
            <span>© {{ new Date().getFullYear() }} Aboutme Sync Server</span>
          </div>
        </footer>
      </main>
    </template>

    <!-- 全局浮层 -->
    <LoadingOverlay />
    <Toaster />
    <AppDialog />
  </div>
</template>
