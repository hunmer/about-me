<script setup lang="ts">
import { computed, inject, type Ref } from 'vue'
import { Checkbox } from '@/components/ui/checkbox'
import type { FileNode } from './types'

const props = defineProps<{
  node: FileNode
  depth: number
}>()

const ctx = inject<{
  expandedPaths: Ref<Set<string>>
  checkedFiles: Ref<Set<string>>
  nodeMap: Map<string, FileNode>
  toggleExpand: (node: FileNode) => void
  toggleFolderCheck: (node: FileNode) => void
  toggleFileCheck: (node: FileNode) => void
  onDownload: (node: FileNode) => void
  onDelete: (node: FileNode) => void
  onExportFolder: (node: FileNode) => void
  onToggleAll: () => void
  allChecked: Ref<boolean>
  someChecked: Ref<boolean>
  formatSize: (bytes?: number) => string
  formatTime: (iso?: string) => string
}>('fileTreeCtx')

const expanded = computed(() => ctx?.expandedPaths.value.has(props.node.path) ?? false)

// 文件夹勾选状态：基于已加载子文件推导（未全加载时视为部分语义）
const folderCheckState = computed<boolean | 'indeterminate'>(() => {
  if (!ctx || !props.node.isFolder) return false
  const files = collectFiles(props.node)
  if (files.length === 0) return ctx.checkedFiles.value.has(props.node.path + '/')
  const checked = files.filter(f => ctx.checkedFiles.value.has(f)).length
  if (checked === 0) return false
  if (checked === files.length) return true
  return 'indeterminate'
})

function collectFiles(node: FileNode): string[] {
  if (!node.isFolder) return [node.path]
  const result: string[] = []
  for (const child of node.children || []) {
    result.push(...collectFiles(child))
  }
  return result
}

// 文件类型图标与扩展名徽标
const iconMeta = computed(() => {
  const name = props.node.name.toLowerCase()
  if (/\.(png|jpe?g|gif|webp|bmp|svg|ico)$/.test(name))
    return { icon: 'image', color: 'text-secondary', ext: name.split('.').pop() || 'img' }
  if (/\.(db|sqlite|sqlite3)$/.test(name))
    return { icon: 'database', color: 'text-tertiary', ext: 'SQLite' }
  if (/\.enc$/.test(name))
    return { icon: 'lock', color: 'text-primary', ext: 'AES' }
  if (/\.(json|yaml|yml|toml|ini|conf)$/.test(name))
    return { icon: 'settings', color: 'text-on-surface-variant', ext: name.split('.').pop() || 'cfg' }
  if (/\.(zip|rar|7z|tar|gz)$/.test(name))
    return { icon: 'folder_zip', color: 'text-secondary', ext: name.split('.').pop() || 'zip' }
  return { icon: 'description', color: 'text-on-surface-variant', ext: name.includes('.') ? name.split('.').pop()! : 'file' }
})

const childCount = computed(() => props.node.children?.length ?? 0)

// 文件夹汇总大小（基于已加载子节点）
const folderSize = computed(() => {
  if (!props.node.isFolder) return undefined
  const total = sumSize(props.node)
  return total
})

function sumSize(node: FileNode): number {
  if (!node.isFolder) return node.size ?? 0
  let total = 0
  for (const child of node.children || []) total += sumSize(child)
  return total
}
</script>

<template>
  <!-- 文件夹行 -->
  <div
    v-if="node.isFolder"
    class="grid cursor-pointer grid-cols-12 items-center gap-3 bg-surface px-6 py-3 transition-colors hover:bg-surface-container-low/60"
    @click="ctx?.toggleExpand(node)"
  >
    <div class="col-span-6 flex min-w-0 items-center gap-3 md:col-span-5" :style="{ paddingLeft: `${depth * 16}px` }">
      <Checkbox
        :model-value="folderCheckState"
        @update:model-value="ctx?.toggleFolderCheck(node)"
        @click.stop
      />
      <button
        type="button"
        class="flex h-5 w-5 items-center justify-center text-on-surface-variant transition-transform duration-150 hover:text-primary"
        :class="expanded ? 'rotate-90' : ''"
        @click.stop="ctx?.toggleExpand(node)"
      >
        <span class="material-symbols-outlined text-base">arrow_right</span>
      </button>
      <div class="flex h-6 w-6 shrink-0 items-center justify-center rounded bg-primary/10 text-primary">
        <span class="material-symbols-outlined text-base">
          {{ expanded ? 'folder_open' : 'folder' }}
        </span>
      </div>
      <span class="truncate text-sm font-semibold text-on-surface">{{ node.name }}/</span>
      <span class="shrink-0 rounded-full bg-surface-container-high px-2 py-0.5 font-mono text-[10px] text-on-surface-variant">
        {{ childCount }} 个项目
      </span>
    </div>
    <div class="col-span-3 text-right font-mono text-xs text-on-surface md:col-span-2">
      {{ ctx?.formatSize(folderSize) }}
    </div>
    <div class="col-span-3 text-right font-mono text-xs text-on-surface-variant md:col-span-3">
      {{ ctx?.formatTime(node.updatedAt) }}
    </div>
    <div class="hidden justify-end md:flex md:col-span-2">
      <button
        type="button"
        class="rounded bg-surface-container px-2.5 py-1 text-[11px] font-medium text-on-surface-variant transition-colors hover:bg-primary/20 hover:text-primary"
        @click.stop="ctx?.onExportFolder(node)"
      >
        快速导出
      </button>
    </div>
  </div>

  <!-- 文件行 -->
  <div
    v-else
    class="group grid grid-cols-12 items-center gap-3 px-6 py-2.5 transition-colors hover:bg-surface-container/50"
    :style="{ paddingLeft: `${depth * 4}px` }"
  >
    <div class="col-span-6 flex min-w-0 items-center gap-3 md:col-span-5" :style="{ marginLeft: `${depth * 14}px` }">
      <Checkbox
        :model-value="ctx?.checkedFiles.value.has(node.path) ?? false"
        @update:model-value="ctx?.toggleFileCheck(node)"
      />
      <div class="flex h-6 w-6 shrink-0 items-center justify-center rounded bg-surface-container" :class="iconMeta.color">
        <span class="material-symbols-outlined text-base">{{ iconMeta.icon }}</span>
      </div>
      <div class="flex min-w-0 items-center gap-2">
        <span class="truncate font-mono text-xs text-on-surface">{{ node.name }}</span>
        <span class="shrink-0 rounded bg-secondary-container/60 px-1 font-mono text-[9px] uppercase text-on-secondary-container">
          {{ iconMeta.ext }}
        </span>
      </div>
    </div>
    <div class="col-span-3 text-right font-mono text-xs text-on-surface-variant md:col-span-2">
      {{ ctx?.formatSize(node.size) }}
    </div>
    <div class="col-span-3 text-right font-mono text-xs text-on-surface-variant md:col-span-3">
      {{ ctx?.formatTime(node.updatedAt) }}
    </div>
    <div class="hidden items-center justify-end gap-1.5 md:flex md:col-span-2">
      <button
        type="button"
        class="flex items-center gap-1 rounded bg-surface-container-high px-2.5 py-1 text-[11px] font-medium text-primary transition-colors hover:bg-primary/20"
        @click="ctx?.onDownload(node)"
      >
        <span class="material-symbols-outlined text-xs">key</span>
        <span>下载解密</span>
      </button>
      <button
        type="button"
        class="rounded bg-surface-container-high p-1 text-on-surface-variant transition-colors hover:bg-error-container hover:text-error"
        @click="ctx?.onDelete(node)"
      >
        <span class="material-symbols-outlined text-sm">delete</span>
      </button>
    </div>
  </div>

  <!-- 子节点 -->
  <div
    v-if="node.isFolder && expanded"
    class="flex flex-col bg-surface-container-lowest/40"
  >
    <div v-if="!node.childrenLoaded && childCount === 0" class="px-6 py-2.5" :style="{ paddingLeft: `${(depth + 1) * 14 + 24}px` }">
      <span class="font-mono text-[11px] text-on-surface-variant">加载中...</span>
    </div>
    <FileTreeNode
      v-for="child in node.children"
      :key="child.path"
      :node="child"
      :depth="depth + 1"
    />
  </div>
</template>
