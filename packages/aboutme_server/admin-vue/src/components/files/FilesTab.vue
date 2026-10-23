<script setup lang="ts">
import { ref, computed, onMounted, provide } from 'vue'
import JSZip from 'jszip'
import { useFilesStore } from '@/stores/files'
import { useUIStore } from '@/stores/ui'
import { useMessage } from '@/composables/useMessage'
import { useDialog } from '@/composables/useDialog'
import { syncApi } from '@/api'
import { formatSize, formatTime } from '@/utils/format'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import FileTreeNode from './FileTreeNode.vue'
import type { FileNode } from './types'

const filesStore = useFilesStore()
const uiStore = useUIStore()
const message = useMessage()
const dialog = useDialog()

// 树形数据
const treeData = ref<FileNode[]>([])
const expandedPaths = ref<Set<string>>(new Set())
const checkedFiles = ref<Set<string>>(new Set())
const searchQuery = ref('')
const refreshing = ref(false)

// 路径 → 节点索引
const nodeMap = new Map<string, FileNode>()

function indexNodes(nodes: FileNode[]): void {
  for (const node of nodes) {
    nodeMap.set(node.path, node)
    if (node.children) indexNodes(node.children)
  }
}

// 将 API 返回数据转换为节点
function convertFile(file: {
  path: string
  size?: number | null
  updated_at?: string
  is_folder?: boolean
  is_binary?: boolean
}): FileNode {
  const parts = file.path.split('/').filter(p => p)
  return {
    path: file.path,
    name: parts[parts.length - 1] || file.path,
    isFolder: file.is_folder ?? false,
    size: file.size ?? undefined,
    updatedAt: file.updated_at,
    isBinary: file.is_binary ?? false,
    children: file.is_folder ? [] : undefined,
    childrenLoaded: false
  }
}

// 从全量文件列表递归建树：API 只返回文件条目，目录节点由路径前缀推导
function buildTree(entries: { path: string; size?: number; updated_at?: string }[], prefix: string): FileNode[] {
  const folders = new Map<string, { node: FileNode; entries: typeof entries }>()
  const fileNodes: FileNode[] = []

  for (const entry of entries) {
    const rest = prefix ? entry.path.slice(prefix.length + 1) : entry.path
    if (!rest) continue
    const slash = rest.indexOf('/')
    if (slash === -1) {
      fileNodes.push({
        path: entry.path,
        name: rest,
        isFolder: false,
        size: entry.size,
        updatedAt: entry.updated_at,
        children: undefined,
        childrenLoaded: true
      })
    } else {
      const dirName = rest.slice(0, slash)
      const dirPath = prefix ? `${prefix}/${dirName}` : dirName
      let folder = folders.get(dirPath)
      if (!folder) {
        folder = {
          node: { path: dirPath, name: dirName, isFolder: true, children: [], childrenLoaded: true },
          entries: []
        }
        folders.set(dirPath, folder)
      }
      folder.entries.push(entry)
    }
  }

  const nodes: FileNode[] = []
  for (const { node, entries: subEntries } of folders.values()) {
    node.children = buildTree(subEntries, node.path)
    nodes.push(node)
  }
  nodes.push(...fileNodes)
  return nodes.sort((a, b) => {
    if (a.isFolder !== b.isFolder) return a.isFolder ? -1 : 1
    return a.name.localeCompare(b.name)
  })
}

// 加载根目录（由全量文件列表构建整棵树，目录展开无需再请求）
async function loadRootFiles(): Promise<void> {
  try {
    const response = await syncApi.getFiles()
    treeData.value = buildTree(response.files || [], '')
    indexNodes(treeData.value)
  } catch (err) {
    console.error('Failed to load root files:', err)
  }
}

// 加载目录子节点
async function loadChildren(node: FileNode): Promise<void> {
  if (node.childrenLoaded) return
  try {
    const response = await syncApi.getFiles(node.path)
    const files = response.files || []
    node.children = files.map(convertFile)
    node.childrenLoaded = true
    indexNodes(node.children)
  } catch (err) {
    console.error('Failed to load children:', err)
    node.children = []
    node.childrenLoaded = true
  }
}

// 展开 / 收起（搜索过滤产生节点副本，操作需回溯到原始节点）
function resolveOriginal(node: FileNode): FileNode {
  return nodeMap.get(node.path) ?? node
}

async function toggleExpand(inputNode: FileNode): Promise<void> {
  const node = resolveOriginal(inputNode)
  if (!node.isFolder) return
  if (expandedPaths.value.has(node.path)) {
    expandedPaths.value.delete(node.path)
    expandedPaths.value = new Set(expandedPaths.value)
  } else {
    await loadChildren(node)
    expandedPaths.value.add(node.path)
    expandedPaths.value = new Set(expandedPaths.value)
  }
}

// 递归加载目录下所有节点（勾选文件夹时使用）
async function loadAllRecursively(node: FileNode): Promise<void> {
  await loadChildren(node)
  for (const child of node.children || []) {
    if (child.isFolder) await loadAllRecursively(child)
  }
}

function collectFilePaths(node: FileNode): string[] {
  if (!node.isFolder) return [node.path]
  const result: string[] = []
  for (const child of node.children || []) {
    result.push(...collectFilePaths(child))
  }
  return result
}

// 勾选文件
function toggleFileCheck(node: FileNode): void {
  const next = new Set(checkedFiles.value)
  if (next.has(node.path)) next.delete(node.path)
  else next.add(node.path)
  checkedFiles.value = next
}

// 勾选文件夹（递归加载全部子文件）
async function toggleFolderCheck(inputNode: FileNode): Promise<void> {
  const node = resolveOriginal(inputNode)
  await loadAllRecursively(node)
  const paths = collectFilePaths(node)
  const allChecked = paths.length > 0 && paths.every(p => checkedFiles.value.has(p))
  const next = new Set(checkedFiles.value)
  for (const p of paths) {
    if (allChecked) next.delete(p)
    else next.add(p)
  }
  checkedFiles.value = next
}

// 全选 / 取消全选（仅已加载节点）
async function toggleAll(): Promise<void> {
  const paths: string[] = []
  const walk = async (nodes: FileNode[]): Promise<void> => {
    for (const node of nodes) {
      if (node.isFolder) {
        await loadChildren(node)
        await walk(node.children || [])
      } else {
        paths.push(node.path)
      }
    }
  }
  await walk(treeData.value)

  if (checkedFiles.value.size >= paths.length && paths.every(p => checkedFiles.value.has(p))) {
    checkedFiles.value = new Set()
  } else {
    checkedFiles.value = new Set(paths)
  }
}

const someChecked = computed(() => checkedFiles.value.size > 0)
const allChecked = computed(() => {
  if (checkedFiles.value.size === 0) return false
  let total = 0
  const walk = (nodes: FileNode[]): void => {
    for (const node of nodes) {
      if (node.isFolder) walk(node.children || [])
      else total++
    }
  }
  walk(treeData.value)
  return total > 0 && checkedFiles.value.size >= total
})

const selectedFilePaths = computed(() => [...checkedFiles.value])
const selectedBytes = computed(() =>
  selectedFilePaths.value.reduce((sum, p) => sum + (nodeMap.get(p)?.size ?? 0), 0)
)

// 短格式占用大小（环形仪表内展示）
const shortTotalSize = computed(() => formatSize(filesStore.stats.totalSize))

// 已加载的目录数
const loadedFolderCount = computed(() => {
  let count = 0
  for (const node of nodeMap.values()) {
    if (node.isFolder) count++
  }
  return count
})

// 搜索过滤：名称匹配或后代匹配
function nodeMatches(node: FileNode, query: string): boolean {
  if (!query) return true
  if (node.name.toLowerCase().includes(query)) return true
  return (node.children || []).some(c => nodeMatches(c, query))
}

const visibleTree = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return treeData.value
  const filter = (nodes: FileNode[]): FileNode[] =>
    nodes
      .filter(n => nodeMatches(n, q))
      .map(n => ({ ...n, children: n.children ? filter(n.children) : undefined }))
  return filter(treeData.value)
})

// 刷新
async function handleRefresh(): Promise<void> {
  refreshing.value = true
  uiStore.setLoading(true, '刷新文件列表...')
  try {
    nodeMap.clear()
    expandedPaths.value = new Set()
    checkedFiles.value = new Set()
    await loadRootFiles()
    await filesStore.loadFiles()
    message.success('文件列表已刷新')
  } catch (err) {
    message.error(err instanceof Error ? err.message : '刷新失败')
  } finally {
    uiStore.setLoading(false)
    refreshing.value = false
  }
}

// 单文件下载
async function downloadFile(filePath: string): Promise<void> {
  uiStore.setLoading(true, '下载文件...')
  try {
    const fileName = filePath.split('/').pop() || 'file'

    const blob = await syncApi.downloadFile(filePath)
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = fileName
    a.click()
    URL.revokeObjectURL(url)

    message.success('下载成功')
    uiStore.addActivity('download', `下载了文件 ${filePath}`)
  } catch (err) {
    message.error(err instanceof Error ? err.message : '下载失败')
  } finally {
    uiStore.setLoading(false)
  }
}

function handleDownload(node: FileNode): void {
  void downloadFile(node.path)
}

// 删除确认
function handleDelete(node: FileNode): void {
  dialog.warning({
    title: '确认删除文件',
    content: `确定要永久删除 ${node.path} 吗？此操作不可恢复。`,
    type: 'error',
    positiveText: '确认永久删除',
    negativeText: '取消',
    onPositiveClick: async () => {
      uiStore.setLoading(true, '删除文件...')
      try {
        await filesStore.deleteFile(node.path)
        await handleRefresh()
        message.success('文件已删除')
        uiStore.addActivity('delete', `删除了文件 ${node.path}`)
      } catch (err) {
        message.error(err instanceof Error ? err.message : '删除失败')
      } finally {
        uiStore.setLoading(false)
      }
    }
  })
}

// 批量下载（ZIP 打包）
async function batchDownload(paths: string[]): Promise<void> {
  if (paths.length === 0) {
    message.warning('请先选择要下载的文件')
    return
  }
  if (paths.length === 1) {
    await downloadFile(paths[0])
    return
  }

  uiStore.setLoading(true, `正在下载 ${paths.length} 个文件并打包...`)

  const zip = new JSZip()
  let successCount = 0
  let failCount = 0

  for (const filePath of paths) {
    try {
      const blob = await syncApi.downloadFile(filePath)
      zip.file(filePath, blob)
      successCount++
    } catch {
      failCount++
    }
  }

  if (successCount === 0) {
    uiStore.setLoading(false)
    message.error('所有文件下载失败')
    return
  }

  try {
    const zipBlob = await zip.generateAsync({ type: 'blob' })
    const url = URL.createObjectURL(zipBlob)
    const a = document.createElement('a')
    a.href = url
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
    a.download = `files_${timestamp}.zip`
    a.click()
    URL.revokeObjectURL(url)

    if (failCount === 0) {
      message.success(`成功下载 ${successCount} 个文件（已打包）`)
    } else {
      message.warning(`下载完成：${successCount} 个成功，${failCount} 个失败（已打包）`)
    }
    uiStore.addActivity('download', `批量下载了 ${successCount} 个文件`)
  } catch {
    message.error('打包失败')
  } finally {
    uiStore.setLoading(false)
    checkedFiles.value = new Set()
  }
}

// 文件夹快速导出
async function handleExportFolder(inputNode: FileNode): Promise<void> {
  const node = resolveOriginal(inputNode)
  uiStore.setLoading(true, '递归加载目录...')
  await loadAllRecursively(node)
  const paths = collectFilePaths(node)
  if (paths.length === 0) {
    uiStore.setLoading(false)
    message.warning('该目录下没有文件')
    return
  }
  await batchDownload(paths)
}

// 批量删除
function handleBatchDelete(): void {
  const count = selectedFilePaths.value.length
  dialog.warning({
    title: '批量删除确认',
    content: `警告：您正在批量清除选定的 ${count} 个文件 (共 ${formatSize(selectedBytes.value)})，所有操作不可恢复。`,
    type: 'error',
    positiveText: `全部永久删除 (${count})`,
    negativeText: '取消',
    onPositiveClick: async () => {
      uiStore.setLoading(true, `正在删除 ${count} 个文件...`)
      let successCount = 0
      let failCount = 0

      for (const filePath of selectedFilePaths.value) {
        try {
          await filesStore.deleteFile(filePath)
          successCount++
        } catch {
          failCount++
        }
      }

      uiStore.setLoading(false)

      if (successCount > 0 && failCount === 0) {
        message.success(`成功删除 ${successCount} 个文件`)
      } else if (successCount > 0 && failCount > 0) {
        message.warning(`删除完成：${successCount} 个成功，${failCount} 个失败`)
      } else {
        message.error('所有文件删除失败')
      }

      checkedFiles.value = new Set()
      await handleRefresh()
    }
  })
}

function clearSelection(): void {
  checkedFiles.value = new Set()
}

// 注入上下文给递归树节点
provide('fileTreeCtx', {
  expandedPaths,
  checkedFiles,
  nodeMap,
  toggleExpand,
  toggleFolderCheck,
  toggleFileCheck,
  onDownload: handleDownload,
  onDelete: handleDelete,
  onExportFolder: handleExportFolder,
  onToggleAll: toggleAll,
  allChecked,
  someChecked,
  formatSize,
  formatTime
})

onMounted(() => {
  loadRootFiles()
})
</script>

<template>
  <div class="flex w-full flex-col gap-6">
    <!-- 顶部统计 & 存储概览 -->
    <div class="grid grid-cols-1 items-stretch gap-5 lg:grid-cols-12">
      <!-- 文件元数据头卡 -->
      <div class="relative overflow-hidden rounded-xl bg-surface/80 p-6 shadow-md backdrop-blur-xl lg:col-span-8">
        <div class="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-primary/10 blur-3xl" />
        <div class="z-10 flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold tracking-tight text-on-surface">云端文件仓库</h1>
          </div>
          <div class="flex items-center gap-3">
            <Button
              variant="secondary"
              size="sm"
              :disabled="refreshing"
              @click="handleRefresh"
            >
              <span class="material-symbols-outlined text-base" :class="{ 'animate-spin': refreshing }">refresh</span>
              <span>刷新文件列表</span>
            </Button>
            <Button variant="glass" size="sm" @click="toggleAll()">
              <span class="material-symbols-outlined text-base">select_all</span>
              <span>{{ allChecked ? '取消全选' : '全选文件' }}</span>
            </Button>
          </div>
        </div>

        <!-- 遥测条 -->
        <div class="z-10 mt-6 grid grid-cols-2 gap-3 rounded-lg bg-surface-container-low/70 p-3">
          <div class="flex flex-col">
            <span class="font-mono text-[10px] uppercase text-on-surface-variant">总同步对象</span>
            <span class="mt-0.5 font-mono text-base font-bold text-on-surface">{{ filesStore.stats.totalFiles }} 个项</span>
          </div>
          <div class="flex flex-col">
            <span class="font-mono text-[10px] uppercase text-on-surface-variant">占用空间</span>
            <span class="mt-0.5 font-mono text-base text-on-surface">{{ filesStore.formattedTotalSize }}</span>
          </div>
        </div>
      </div>

      <!-- 存储容量 widget -->
      <div class="relative flex flex-col justify-between overflow-hidden rounded-xl bg-surface/80 p-6 shadow-md backdrop-blur-xl lg:col-span-4">
        <div class="flex items-center gap-2">
          <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <span class="material-symbols-outlined text-lg">pie_chart</span>
          </div>
          <span class="text-xs font-semibold leading-tight text-on-surface">同步存储占用</span>
        </div>

        <div class="my-4 flex items-center gap-5">
          <!-- 环形仪表 -->
          <div class="relative h-20 w-20 shrink-0">
            <svg class="h-full w-full -rotate-90" viewBox="0 0 36 36">
              <path
                class="text-surface-variant"
                d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                fill="none"
                stroke="currentColor"
                stroke-width="3.5"
              />
              <path
                class="text-primary"
                d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                fill="none"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-width="3.5"
              />
            </svg>
            <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
              <span class="font-mono text-xs font-bold text-on-surface">{{ shortTotalSize }}</span>
            </div>
          </div>
          <div class="flex flex-1 flex-col gap-2 font-mono text-xs">
            <div class="flex justify-between">
              <span class="text-on-surface-variant">文件</span>
              <span class="text-on-surface">{{ filesStore.stats.totalFiles }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-on-surface-variant">目录</span>
              <span class="text-on-surface">{{ loadedFolderCount }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 搜索 & 过滤工具栏 -->
    <div class="flex flex-col items-stretch justify-between gap-3 rounded-xl bg-surface/80 p-3 shadow-sm backdrop-blur-xl md:flex-row md:items-center">
      <div class="flex flex-1 items-center gap-3">
        <div class="relative max-w-md flex-1">
          <span class="material-symbols-outlined pointer-events-none absolute left-3 top-2.5 text-lg text-on-surface-variant">search</span>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索文件名或路径..."
            class="w-full rounded-lg bg-surface-container-low py-2 pl-9 pr-8 text-xs text-on-surface transition-all placeholder:text-on-surface-variant/60 focus:bg-surface-container focus:outline-none"
          />
        </div>
      </div>
      <div class="flex items-center gap-2 rounded-lg bg-primary-container/30 px-3 py-1.5 text-on-primary-container">
        <span class="material-symbols-outlined text-sm text-primary">account_tree</span>
        <span class="text-[11px] font-medium">选中目录自动递归包含其子项</span>
        <div class="ml-1 h-1.5 w-1.5 rounded-full bg-primary" />
      </div>
    </div>

    <!-- 主文件树面板 -->
    <div class="flex flex-col overflow-hidden rounded-xl bg-surface/80 shadow-md backdrop-blur-2xl">
      <!-- 表头 -->
      <div class="grid grid-cols-12 items-center gap-3 bg-surface-container-low px-6 py-3.5 font-mono text-xs font-medium uppercase tracking-wider text-on-surface-variant">
        <div class="flex col-span-6 items-center gap-3 md:col-span-5">
          <Checkbox
            :model-value="allChecked ? true : someChecked ? 'indeterminate' : false"
            @update:model-value="toggleAll()"
          />
          <span>名称 / 路径</span>
        </div>
        <div class="col-span-3 text-right md:col-span-2">大小</div>
        <div class="col-span-3 text-right md:col-span-3">最近同步时间</div>
        <div class="hidden justify-end pr-2 md:flex md:col-span-2">操作选项</div>
      </div>

      <!-- 树内容 -->
      <div class="flex flex-col">
        <div v-if="visibleTree.length === 0" class="flex flex-col items-center gap-3 py-14 text-on-surface-variant">
          <span class="material-symbols-outlined text-5xl opacity-30">folder_off</span>
          <span class="font-mono text-xs">暂无同步文件 · 等待客户端推送</span>
        </div>
        <FileTreeNode
          v-for="node in visibleTree"
          :key="node.path"
          :node="node"
          :depth="0"
        />
      </div>
    </div>

    <!-- 浮动批量操作栏 -->
    <Transition
      enter-active-class="transition-all duration-300"
      enter-from-class="translate-y-16 opacity-0"
      enter-to-class="translate-y-0 opacity-100"
      leave-active-class="transition-all duration-300"
      leave-from-class="translate-y-0 opacity-100"
      leave-to-class="translate-y-16 opacity-0"
    >
      <aside
        v-if="checkedFiles.size > 0"
        aria-label="批量操作栏"
        class="fixed bottom-8 left-1/2 z-40 flex w-auto max-w-2xl -translate-x-1/2 items-center gap-4 rounded-2xl bg-surface-container-high/90 px-5 py-3 shadow-[0_8px_32px_rgba(0,0,0,0.5)] backdrop-blur-2xl"
      >
        <div class="flex items-center gap-2.5 pr-2">
          <div class="h-2.5 w-2.5 animate-pulse rounded-full bg-primary" />
          <span class="font-mono text-xs font-bold text-on-surface">
            已选 {{ checkedFiles.size }} 项 ({{ formatSize(selectedBytes) }})
          </span>
        </div>
        <div class="h-6 w-px bg-outline-variant" />
        <div class="flex items-center gap-2">
          <Button size="sm" @click="batchDownload(selectedFilePaths)">
            <span class="material-symbols-outlined text-sm">folder_zip</span>
            <span>打包下载 (ZIP)</span>
          </Button>
          <Button variant="destructive" size="sm" @click="handleBatchDelete">
            <span class="material-symbols-outlined text-sm">delete_sweep</span>
            <span>删除 ({{ checkedFiles.size }})</span>
          </Button>
        </div>
        <button
          type="button"
          class="ml-1 rounded-lg p-1 text-on-surface-variant transition-colors hover:bg-surface-variant hover:text-on-surface"
          title="清空选择"
          @click="clearSelection"
        >
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      </aside>
    </Transition>
  </div>
</template>
