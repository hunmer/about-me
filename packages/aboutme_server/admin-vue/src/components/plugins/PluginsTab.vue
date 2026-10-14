<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { usePluginsStore } from '@/stores/plugins'
import { useMessage } from '@/composables/useMessage'
import { useDialog } from '@/composables/useDialog'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import type { InstalledPlugin, StorePlugin } from '@/api/types'

type PluginSubTab = 'installed' | 'store'

const pluginsStore = usePluginsStore()
const message = useMessage()
const dialog = useDialog()

const fileInput = ref<File | null>(null)
const fileInputRef = ref<HTMLInputElement | null>(null)
const activeSubTab = ref<PluginSubTab>('installed')
const showConfigModal = ref(false)
const storeConfigURL = ref('')
const syncInterval = ref(0)
const searchQuery = ref('')

// 初始化数据
onMounted(async () => {
  await Promise.all([pluginsStore.fetchInstalledPlugins(), pluginsStore.fetchStoreConfig()])
})

// 已安装插件搜索过滤
const filteredInstalled = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return pluginsStore.installedPlugins
  return pluginsStore.installedPlugins.filter(
    p =>
      p.title.toLowerCase().includes(q) ||
      p.description.toLowerCase().includes(q)
  )
})

// 商店插件搜索过滤
const filteredStore = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return pluginsStore.storePlugins
  return pluginsStore.storePlugins.filter(
    p =>
      p.title.toLowerCase().includes(q) ||
      p.description.toLowerCase().includes(q)
  )
})

// 刷新商店
async function handleRefreshStore(): Promise<void> {
  await pluginsStore.fetchStorePlugins()
}

// 打开配置弹窗
function handleOpenConfig(): void {
  storeConfigURL.value = pluginsStore.storeConfig.storeURL || ''
  syncInterval.value = pluginsStore.storeConfig.syncInterval || 0
  showConfigModal.value = true
}

// 保存配置
async function handleSaveConfig(): Promise<void> {
  if (!storeConfigURL.value) {
    message.warning('请输入商店 URL')
    return
  }
  const success = await pluginsStore.updateStoreConfig({
    storeURL: storeConfigURL.value,
    syncInterval: syncInterval.value
  })
  if (success) {
    message.success('配置已保存')
    showConfigModal.value = false
  } else {
    message.error('保存配置失败')
  }
}

// 文件上传处理
function handleFileSelect(event: Event): void {
  const file = (event.target as HTMLInputElement).files?.[0] as File
  if (!file) {
    message.warning('请选择 ZIP 文件')
    return
  }
  fileInput.value = file
}

// 触发文件选择框
function triggerFileSelect(): void {
  fileInputRef.value?.click()
}

// 上传插件
async function handleUpload(): Promise<void> {
  if (!fileInput.value) return
  const success = await pluginsStore.uploadPlugin(fileInput.value)
  if (success) {
    message.success('插件上传成功')
    fileInput.value = null
    if (fileInputRef.value) {
      fileInputRef.value.value = ''
    }
  } else {
    message.error(pluginsStore.error || '上传失败')
  }
}

// 从商店安装
async function handleInstallFromStore(plugin: StorePlugin): Promise<void> {
  const success = await pluginsStore.installFromStore(plugin.downloadURL)
  if (success) {
    message.success(`${plugin.title} 安装成功`)
  } else {
    message.error(pluginsStore.error || '安装失败')
  }
}

// 启用插件
async function handleEnable(plugin: InstalledPlugin): Promise<void> {
  const success = await pluginsStore.enablePlugin(plugin.uuid)
  if (success) {
    message.success(`${plugin.title} 已启用`)
  }
}

// 禁用插件
async function handleDisable(plugin: InstalledPlugin): Promise<void> {
  const success = await pluginsStore.disablePlugin(plugin.uuid)
  if (success) {
    message.success(`${plugin.title} 已禁用`)
  }
}

// 卸载插件
function handleUninstall(plugin: InstalledPlugin): void {
  dialog.warning({
    title: '确认卸载',
    content: `确定要卸载 "${plugin.title}" 吗？此操作不可恢复。`,
    type: 'error',
    positiveText: '确认卸载',
    negativeText: '取消',
    onPositiveClick: async () => {
      const success = await pluginsStore.uninstallPlugin(plugin.uuid)
      if (success) {
        message.success(`${plugin.title} 已卸载`)
      }
    }
  })
}

// 卡片配色（按索引轮换）
const cardPalette = [
  { box: 'bg-primary/10 text-primary', tag: 'text-primary' },
  { box: 'bg-secondary-container/50 text-secondary', tag: 'text-secondary' },
  { box: 'bg-tertiary-container/40 text-tertiary', tag: 'text-tertiary' },
  { box: 'bg-primary-container/40 text-primary', tag: 'text-primary' }
]

function palette(index: number) {
  return cardPalette[index % cardPalette.length]
}
</script>

<template>
  <section class="w-full py-8">
    <!-- 头部控制区 -->
    <div class="mb-8 flex flex-col justify-between gap-6 lg:flex-row lg:items-center">
      <div>
        <h1 class="text-2xl font-bold tracking-tight text-on-surface lg:text-3xl">插件与生态模块</h1>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <div class="relative min-w-[220px]">
          <span class="material-symbols-outlined pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-lg text-on-surface-variant">search</span>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="检索已安装或商店插件..."
            class="w-full rounded-lg bg-surface-container/70 py-2 pl-9 pr-4 text-xs text-on-surface transition-all placeholder:text-on-surface-variant/60 focus:bg-surface-container-high focus:outline-none"
          />
        </div>

        <input
          ref="fileInputRef"
          type="file"
          accept=".zip"
          class="hidden"
          @change="handleFileSelect"
        />
        <Button variant="secondary" size="sm" @click="triggerFileSelect">
          <span class="material-symbols-outlined text-base text-primary">upload_file</span>
          <span>上传插件 (ZIP)</span>
        </Button>
        <Button
          v-if="fileInput"
          variant="glass"
          size="sm"
          :disabled="pluginsStore.loading"
          @click="handleUpload"
        >
          <span class="max-w-[160px] truncate">{{ fileInput.name }}</span>
          <span class="material-symbols-outlined text-base">cloud_upload</span>
        </Button>
        <Button variant="glass" size="sm" @click="handleOpenConfig">
          <span class="material-symbols-outlined text-base">hub</span>
          <span>配置商店源</span>
        </Button>
      </div>
    </div>

    <!-- 子导航 Tabs -->
    <div class="mb-6 flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
      <div class="flex w-fit items-center gap-1.5 rounded-xl bg-surface-container-lowest/80 p-1 backdrop-blur-xl">
        <button
          type="button"
          class="flex items-center gap-2 rounded-lg px-4 py-1.5 text-xs font-medium transition-all"
          :class="
            activeSubTab === 'installed'
              ? 'bg-primary-container font-semibold text-on-primary-container shadow-md'
              : 'text-on-surface-variant hover:bg-surface-variant/40 hover:text-on-surface'
          "
          @click="activeSubTab = 'installed'"
        >
          <span class="material-symbols-outlined text-sm">widgets</span>
          <span>已安装</span>
          <span class="rounded-full px-1.5 py-0.5 text-[10px]" :class="activeSubTab === 'installed' ? 'bg-primary/20 text-primary' : 'bg-surface-container-highest text-on-surface-variant'">
            {{ pluginsStore.installedPlugins.length }}
          </span>
        </button>
        <button
          type="button"
          class="flex items-center gap-2 rounded-lg px-4 py-1.5 text-xs font-medium transition-all"
          :class="
            activeSubTab === 'store'
              ? 'bg-primary-container font-semibold text-on-primary-container shadow-md'
              : 'text-on-surface-variant hover:bg-surface-variant/40 hover:text-on-surface'
          "
          @click="activeSubTab = 'store'"
        >
          <span class="material-symbols-outlined text-sm">shopping_bag</span>
          <span>插件商店</span>
          <span class="rounded-full px-1.5 py-0.5 text-[10px]" :class="activeSubTab === 'store' ? 'bg-primary/20 text-primary' : 'bg-surface-container-highest text-on-surface-variant'">
            {{ pluginsStore.storePlugins.length }}
          </span>
        </button>
      </div>
    </div>

    <!-- 已安装视图 -->
    <div v-show="activeSubTab === 'installed'" class="flex flex-col gap-6">
      <div v-if="pluginsStore.loading" class="flex items-center justify-center gap-3 py-20 text-on-surface-variant">
        <span class="h-5 w-5 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
        <span class="font-mono text-xs">加载插件清单中...</span>
      </div>

      <div v-else-if="filteredInstalled.length === 0" class="flex flex-col items-center gap-4 rounded-xl bg-surface-container/40 py-16 text-on-surface-variant backdrop-blur-xl">
        <span class="material-symbols-outlined text-5xl opacity-30">widgets</span>
        <span class="font-mono text-xs">暂无已安装的插件</span>
        <Button variant="glass" size="sm" @click="handleOpenConfig">
          <span class="material-symbols-outlined text-base">settings</span>
          <span>配置商店</span>
        </Button>
      </div>

      <div v-else class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="(plugin, index) in filteredInstalled"
          :key="plugin.uuid"
          class="group flex flex-col justify-between rounded-xl bg-surface-container/60 p-5 shadow-lg backdrop-blur-xl transition-all duration-300 hover:bg-surface-container/85"
          :class="plugin.status === 'disabled' ? 'opacity-80' : ''"
        >
          <div>
            <div class="mb-4 flex items-start justify-between gap-3">
              <div class="flex items-center gap-3">
                <div class="flex h-11 w-11 items-center justify-center rounded-xl shadow-inner" :class="palette(index).box">
                  <span class="material-symbols-outlined text-2xl">extension</span>
                </div>
                <div>
                  <h3 class="text-sm font-bold leading-snug text-on-surface transition-colors group-hover:text-primary">
                    {{ plugin.title }}
                  </h3>
                  <span class="font-mono text-[11px] text-on-surface-variant">{{ plugin.author }}</span>
                </div>
              </div>
              <div class="flex flex-col items-end gap-1">
                <span
                  v-if="plugin.status === 'enabled'"
                  class="flex items-center gap-1 rounded bg-primary/20 px-2 py-0.5 font-mono text-[10px] font-medium text-primary"
                >
                  <span class="h-1.5 w-1.5 animate-pulse rounded-full bg-primary" />
                  已启用
                </span>
                <span
                  v-else-if="plugin.status === 'disabled'"
                  class="flex items-center gap-1 rounded bg-surface-variant px-2 py-0.5 font-mono text-[10px] font-medium text-on-surface-variant"
                >
                  <span class="h-1.5 w-1.5 rounded-full bg-outline" />
                  已禁用
                </span>
                <span v-else class="rounded bg-tertiary-container/40 px-2 py-0.5 font-mono text-[10px] font-medium text-tertiary">
                  已安装
                </span>
                <span class="font-mono text-[10px] text-on-surface-variant/80">v{{ plugin.version }}</span>
              </div>
            </div>

            <p class="mb-4 line-clamp-2 text-xs leading-relaxed text-on-surface-variant">
              {{ plugin.description }}
            </p>

            <div class="mb-4 flex items-center justify-between rounded-lg bg-surface-container-lowest/50 px-3 py-2 font-mono text-[11px] text-on-surface-variant/80">
              <div class="flex items-center gap-1.5">
                <span class="material-symbols-outlined text-sm" :class="palette(index).tag">security</span>
                <span>UUID: {{ plugin.uuid.slice(0, 8) }}...</span>
              </div>
              <a
                v-if="plugin.website"
                class="inline-flex items-center gap-1 text-primary hover:underline"
                :href="plugin.website"
                target="_blank"
              >
                <span>官方主页</span>
                <span class="material-symbols-outlined text-xs">north_east</span>
              </a>
            </div>
          </div>

          <div class="flex items-center justify-between gap-2 pt-3">
            <div class="flex items-center gap-2">
              <Button
                v-if="plugin.status === 'enabled'"
                variant="secondary"
                size="xs"
                @click="handleDisable(plugin)"
              >
                <span class="material-symbols-outlined text-sm">pause</span>
                <span>禁用</span>
              </Button>
              <Button
                v-else
                size="xs"
                class="bg-primary-container text-on-primary-container shadow-none hover:bg-primary/30"
                @click="handleEnable(plugin)"
              >
                <span class="material-symbols-outlined text-sm">play_arrow</span>
                <span>启用</span>
              </Button>
            </div>
            <button
              type="button"
              class="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-medium text-error transition-colors hover:bg-error-container/40"
              @click="handleUninstall(plugin)"
            >
              <span class="material-symbols-outlined text-sm">delete_forever</span>
              <span>卸载</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 商店视图 -->
    <div v-show="activeSubTab === 'store'" class="flex flex-col gap-6">
      <div v-if="pluginsStore.loading" class="flex items-center justify-center gap-3 py-20 text-on-surface-variant">
        <span class="h-5 w-5 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
        <span class="font-mono text-xs">加载商店列表中...</span>
      </div>

      <div v-else-if="!pluginsStore.storeConfig.storeURL" class="flex flex-col items-center gap-4 rounded-xl bg-surface-container/40 py-16 text-on-surface-variant backdrop-blur-xl">
        <span class="material-symbols-outlined text-5xl opacity-30">shopping_bag</span>
        <span class="font-mono text-xs">请先配置商店 URL</span>
        <Button variant="glass" size="sm" @click="handleOpenConfig">
          <span class="material-symbols-outlined text-base">settings</span>
          <span>配置商店</span>
        </Button>
      </div>

      <template v-else>
        <div class="flex items-center justify-between">
          <span class="font-mono text-xs text-on-surface-variant">
            商店插件 ({{ filteredStore.length }})
          </span>
          <Button variant="ghost" size="xs" :disabled="pluginsStore.loading" @click="handleRefreshStore">
            <span class="material-symbols-outlined text-base" :class="{ 'animate-spin': pluginsStore.loading }">refresh</span>
            <span>刷新商店</span>
          </Button>
        </div>

        <div v-if="filteredStore.length === 0" class="flex flex-col items-center gap-3 rounded-xl bg-surface-container/40 py-16 text-on-surface-variant backdrop-blur-xl">
          <span class="material-symbols-outlined text-5xl opacity-30">shopping_bag</span>
          <span class="font-mono text-xs">商店列表为空 · 点击刷新获取</span>
        </div>

        <div v-else class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
          <div
            v-for="(plugin, index) in filteredStore"
            :key="plugin.uuid"
            class="flex flex-col justify-between rounded-xl bg-surface-container/60 p-5 shadow-lg backdrop-blur-xl transition-all hover:bg-surface-container/85"
          >
            <div>
              <div class="mb-3 flex items-start justify-between gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-xl" :class="palette(index).box">
                  <span class="material-symbols-outlined">extension</span>
                </div>
                <span class="rounded bg-surface-variant px-2 py-0.5 font-mono text-[10px] text-on-surface-variant">
                  v{{ plugin.version }}
                </span>
              </div>
              <h3 class="mb-1 text-sm font-bold text-on-surface">{{ plugin.title }}</h3>
              <p class="mb-3 font-mono text-[11px] text-on-surface-variant">by {{ plugin.author }}</p>
              <p class="mb-4 line-clamp-2 text-xs text-on-surface-variant">{{ plugin.description }}</p>
            </div>

            <Button
              v-if="pluginsStore.isInstalled(plugin.uuid)"
              variant="secondary"
              size="sm"
              class="w-full"
              disabled
            >
              <span class="material-symbols-outlined text-base">check_circle</span>
              <span>已安装</span>
            </Button>
            <Button
              v-else
              size="sm"
              class="w-full"
              :disabled="pluginsStore.loading"
              @click="handleInstallFromStore(plugin)"
            >
              <span class="material-symbols-outlined text-base">download</span>
              <span>{{ pluginsStore.loading ? '安装中...' : '安装此插件' }}</span>
            </Button>
          </div>
        </div>
      </template>
    </div>

    <!-- 商店配置弹窗 -->
    <Dialog v-model:open="showConfigModal">
      <DialogContent class="max-w-md">
        <DialogHeader class="flex-row items-center gap-3 space-y-0">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary">
            <span class="material-symbols-outlined text-xl">hub</span>
          </div>
          <div>
            <DialogTitle>商店配置</DialogTitle>
            <DialogDescription class="mt-0.5">
              服务器将定期从该地址拉取插件列表
            </DialogDescription>
          </div>
        </DialogHeader>

        <div class="space-y-4">
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-on-surface-variant">商店 JSON URL</label>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">link</span>
              <input
                v-model="storeConfigURL"
                type="url"
                placeholder="https://example.com/plugins.json"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>

          <div class="flex items-start gap-2.5 rounded-xl bg-surface-container-lowest/50 p-3 text-xs leading-relaxed text-on-surface-variant">
            <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-primary">info</span>
            <p>输入插件商店的 JSON 文件 URL，服务器将定期从此 URL 获取可用插件列表。</p>
          </div>
        </div>

        <DialogFooter class="gap-2.5">
          <Button variant="ghost" size="sm" @click="showConfigModal = false">取消</Button>
          <Button size="sm" @click="handleSaveConfig">
            <span class="material-symbols-outlined text-base">save</span>
            <span>保存配置</span>
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </section>
</template>
