<script setup lang="ts">
import { ref, computed } from 'vue'
import { useFilesStore } from '@/stores/files'
import { useUIStore } from '@/stores/ui'
import { useMessage } from '@/composables/useMessage'
import { useDialog } from '@/composables/useDialog'
import { syncApi } from '@/api'
import { Button } from '@/components/ui/button'

const filesStore = useFilesStore()
const uiStore = useUIStore()
const message = useMessage()
const dialog = useDialog()

// 危险区确认口令
const DANGER_PHRASE = 'DELETE-ALL-VAULT'
const dangerInput = ref('')
const dangerUnlocked = computed(() => dangerInput.value.trim() === DANGER_PHRASE)

async function handleExport(): Promise<void> {
  uiStore.setLoading(true, '导出 ZIP 文件...')
  try {
    const data = await syncApi.exportData()

    if (data.success && data.file_name) {
      const blob = await syncApi.downloadExportFile(data.file_name)
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = data.file_name
      a.click()
      URL.revokeObjectURL(url)

      message.success(
        `数据导出成功 (${data.metadata?.file_count} 个文件, ${data.metadata?.total_size_mb} MB)`
      )
      uiStore.addActivity('export', `导出了 ${data.metadata?.file_count} 个文件`)
    } else {
      throw new Error(data.error || '导出失败')
    }
  } catch (err) {
    message.error(err instanceof Error ? err.message : '导出失败')
  } finally {
    uiStore.setLoading(false)
  }
}

function handleClearData(): void {
  dialog.warning({
    title: '清空服务器数据',
    content: `警告：此操作将删除服务器上的所有 ${filesStore.stats.totalFiles} 个同步文件 (共 ${filesStore.formattedTotalSize})！此操作不可恢复！`,
    type: 'error',
    positiveText: '确认清空全部数据',
    negativeText: '取消',
    onPositiveClick: async () => {
      uiStore.setLoading(true, '清空服务器数据...')
      try {
        for (const file of filesStore.files) {
          await syncApi.deleteFile(file.path)
        }
        await filesStore.loadFiles()
        dangerInput.value = ''
        message.success('服务器数据已清空')
        uiStore.addActivity('delete', '清空了服务器数据')
      } catch (err) {
        message.error(err instanceof Error ? err.message : '清空失败')
      } finally {
        uiStore.setLoading(false)
      }
    }
  })
}
</script>

<template>
  <!-- 数据操作模块卡片 -->
  <div class="relative overflow-hidden rounded-2xl bg-surface/65 p-6 shadow-[0_4px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl sm:p-8">
    <!-- 危险辉光 -->
    <div class="pointer-events-none absolute -bottom-24 -right-24 h-52 w-52 rounded-full bg-error/10 blur-3xl" />

    <!-- 标题区 -->
    <div class="flex items-start justify-between gap-4 border-b border-outline-variant/30 pb-6">
      <div class="flex items-center gap-3.5">
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-error-container/40 text-error shadow-[0_0_20px_rgba(255,107,107,0.15)]">
          <span class="material-symbols-outlined text-xl">database</span>
        </div>
        <h2 class="text-lg font-bold tracking-tight text-on-surface">数据备份与敏感操作</h2>
      </div>
    </div>

    <!-- 破坏性警告横幅 -->
    <div class="mt-6 flex items-start gap-3 rounded-xl bg-error-container/25 p-4 text-xs leading-relaxed text-on-error-container">
      <span class="material-symbols-outlined mt-0.5 shrink-0 text-lg text-error">warning</span>
      <div>
        <span class="font-bold text-error">警告：</span>
        <span>涉及底层存储打包或不可逆物理抹除，请谨慎操作。</span>
      </div>
    </div>

    <!-- 全量数据归档导出 -->
    <div class="mt-6 space-y-4 rounded-xl bg-surface-container/60 p-5 backdrop-blur-md">
      <div class="flex items-center gap-2">
        <span class="material-symbols-outlined text-lg text-primary">archive</span>
        <span class="text-xs font-bold text-on-surface">全量数据归档导出</span>
      </div>
      <p class="text-xs leading-relaxed text-on-surface-variant">
        服务端将所有加密文档、元数据库打包为 ZIP 归档包供离线冷备。
      </p>

      <!-- 指标高亮框 -->
      <div class="grid grid-cols-2 gap-3 rounded-lg bg-surface-container-lowest/80 p-3 font-mono text-xs">
        <div class="flex flex-col">
          <span class="text-[10px] text-on-surface-variant">已索引对象</span>
          <span class="mt-0.5 text-sm font-bold text-on-surface">{{ filesStore.stats.totalFiles }} 个文件</span>
        </div>
        <div class="flex flex-col">
          <span class="text-[10px] text-on-surface-variant">预计大小</span>
          <span class="mt-0.5 text-sm font-bold text-primary">{{ filesStore.formattedTotalSize }}</span>
        </div>
      </div>

      <Button variant="glass" size="lg" class="w-full rounded-xl bg-primary-container hover:bg-primary-container/80" @click="handleExport">
        <span class="material-symbols-outlined text-base">folder_zip</span>
        <span>打包并导出全量数据 (ZIP)</span>
      </Button>
    </div>

    <!-- 清空服务器数据危险区 -->
    <div class="mt-6 space-y-4 rounded-xl bg-surface-container/60 p-5 backdrop-blur-md">
      <div class="flex items-center gap-2 text-error">
        <span class="material-symbols-outlined text-lg">bomb</span>
        <span class="text-xs font-bold">清空服务器数据危险区</span>
      </div>
      <p class="text-xs leading-relaxed text-on-surface-variant">
        永久物理删除云端所有同步文件与元数据，操作不可撤销。
      </p>

      <!-- 安全确认输入 -->
      <div class="space-y-2 pt-1">
        <label class="block font-mono text-[11px] text-on-surface-variant">
          输入确认文字 <span class="select-all font-bold text-error">{{ DANGER_PHRASE }}</span> 以解锁清空操作:
        </label>
        <input
          v-model="dangerInput"
          type="text"
          autocomplete="off"
          placeholder="输入确认口令..."
          class="w-full rounded-lg bg-surface-container-lowest/90 px-4 py-2.5 font-mono text-xs text-error transition-all placeholder:text-outline/50 focus:bg-surface-container-high focus:shadow-[0_0_15px_rgba(255,107,107,0.15)] focus:outline-none"
        />
      </div>

      <Button
        variant="secondary"
        size="lg"
        class="w-full rounded-xl"
        :class="dangerUnlocked ? 'bg-error text-on-error hover:bg-error/90' : 'cursor-not-allowed bg-surface-variant text-outline'"
        :disabled="!dangerUnlocked"
        @click="handleClearData"
      >
        <span class="material-symbols-outlined text-base">delete_sweep</span>
        <span>清空所有服务器数据 (不可恢复)</span>
      </Button>
    </div>
  </div>
</template>
