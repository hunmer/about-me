<script setup lang="ts">
import { useUIStore, type TabId } from '@/stores/ui'

const uiStore = useUIStore()

const tabs: { id: TabId; label: string }[] = [
  { id: 'overview', label: '概览' },
  { id: 'files', label: '文件管理' },
  { id: 'apikeys', label: 'API Keys' },
  { id: 'plugins', label: '插件商店' },
  { id: 'devices', label: '设备管理' },
  { id: 'settings', label: '设置' }
]
</script>

<template>
  <div class="mx-auto w-full max-w-7xl px-6 h-12 flex items-center justify-start">
    <nav
      class="flex items-center gap-1.5 rounded-xl bg-surface-container-lowest/60 p-1 backdrop-blur-md"
    >
      <button
        v-for="tab in tabs"
        :key="tab.id"
        type="button"
        class="rounded-lg px-4 py-1.5 text-xs font-medium transition-colors"
        :class="
          uiStore.activeTab === tab.id
            ? 'bg-primary-container font-semibold text-on-primary-container shadow-[0_0_16px_rgba(125,211,252,0.2)]'
            : 'text-on-surface-variant hover:bg-surface-variant/40 hover:text-on-surface'
        "
        @click="uiStore.setTab(tab.id)"
      >
        {{ tab.label }}
      </button>
    </nav>
  </div>
</template>
