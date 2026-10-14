<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDevicesStore } from '@/stores/devices'
import { useMessage } from '@/composables/useMessage'
import { useDialog } from '@/composables/useDialog'
import { formatTime } from '@/utils/format'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import type { Device } from '@/api/types'

const devicesStore = useDevicesStore()
const message = useMessage()
const dialog = useDialog()

// 推送消息模态框
const showPushModal = ref(false)
const selectedDevice = ref<Device | null>(null)
const pushTitle = ref('')
const pushBody = ref('')
const pushLoading = ref(false)

onMounted(() => {
  devicesStore.loadDevices()
})

// 平台图标与展示元数据
function deviceMeta(platform?: string) {
  if (!platform) return { icon: 'smartphone', label: '终端设备', emoji: '📱 手机' }
  const p = platform.toLowerCase()
  if (p.includes('windows') || p.includes('linux') || p.includes('desktop'))
    return { icon: 'desktop_windows', label: platform, emoji: '🖥️ 桌面台式机' }
  if (p.includes('ipad') || p.includes('tablet'))
    return { icon: 'tablet_mac', label: platform, emoji: '📟 平板' }
  if (p.includes('mac') || p.includes('macos'))
    return { icon: 'laptop_mac', label: platform, emoji: '💻 笔记本' }
  return { icon: 'smartphone', label: platform, emoji: '📱 手机' }
}

// 遥测统计
const fcmActiveCount = computed(
  () => devicesStore.devices.filter(d => d.fcm_token).length
)
const platformCount = computed(
  () => new Set(devicesStore.devices.map(d => d.platform?.toLowerCase() || 'unknown')).size
)
const latestSync = computed(() => {
  const times = devicesStore.devices
    .map(d => d.last_sync_at)
    .filter(Boolean)
    .sort()
  return times.length ? formatTime(times[times.length - 1]) : '-'
})

// 打开推送模态框
function openPushModal(device?: Device) {
  selectedDevice.value = device || null
  pushTitle.value = ''
  pushBody.value = ''
  showPushModal.value = true
}

// 发送推送消息
async function sendPushMessage() {
  if (!pushTitle.value.trim() || !pushBody.value.trim()) {
    message.warning('请填写标题和内容')
    return
  }

  pushLoading.value = true
  try {
    const result = await devicesStore.pushMessage(
      selectedDevice.value?.device_id,
      pushTitle.value,
      pushBody.value
    )

    if (result.success) {
      message.success(`推送成功，已发送到 ${result.sentCount || 1} 个设备`)
      showPushModal.value = false
    } else {
      message.error(result.error || '推送失败')
    }
  } finally {
    pushLoading.value = false
  }
}

// 删除设备
function handleDelete(device: Device) {
  dialog.warning({
    title: '解除设备授权',
    content: `确定要删除设备 "${device.device_name}" 吗？删除后该设备需要重新登录。`,
    type: 'error',
    positiveText: '删除',
    negativeText: '取消',
    onPositiveClick: async () => {
      const success = await devicesStore.deleteDevice(device.device_id)
      if (success) {
        message.success('设备已删除')
      } else {
        message.error(devicesStore.error || '删除失败')
      }
    }
  })
}

async function copyDeviceId(deviceId: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(deviceId)
    message.success('已复制 Device ID')
  } catch {
    message.error('复制失败')
  }
}
</script>

<template>
  <div class="flex w-full flex-col pb-12">
    <!-- Hero 诊断面板 -->
    <div class="relative mb-8 w-full overflow-hidden rounded-2xl bg-surface-container/60 p-7 shadow-xl backdrop-blur-xl">
      <div class="pointer-events-none absolute -bottom-16 -right-16 h-80 w-80 rounded-full bg-primary/10 blur-3xl" />
      <div class="pointer-events-none absolute -left-12 -top-12 h-64 w-64 rounded-full bg-tertiary/10 blur-3xl" />

      <div class="relative z-10 flex flex-col justify-between gap-6 lg:flex-row lg:items-center">
        <div class="flex flex-col gap-2">
          <div class="flex items-baseline gap-3">
            <h1 class="text-2xl font-bold tracking-tight text-on-surface lg:text-3xl">终端设备管理</h1>
            <span class="rounded-full bg-primary-container/40 px-3 py-1 text-sm font-medium text-primary">
              当前已授权 {{ devicesStore.devices.length }} 台终端设备
            </span>
          </div>
          <p class="max-w-2xl text-xs leading-relaxed text-on-surface-variant">
            删除设备后该设备需要重新登录授权。
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <Button variant="glass" size="lg" class="rounded-xl" @click="openPushModal()">
            <span class="material-symbols-outlined text-lg text-primary">cell_tower</span>
            <span>向所有设备广播推送</span>
          </Button>
          <Button variant="secondary" size="lg" class="rounded-xl" :disabled="devicesStore.loading" @click="devicesStore.loadDevices()">
            <span class="material-symbols-outlined text-lg text-on-surface-variant" :class="{ 'animate-spin': devicesStore.loading }">refresh</span>
            <span>刷新设备列表</span>
          </Button>
        </div>
      </div>

      <!-- 遥测条 -->
      <div class="relative z-10 mt-6 grid grid-cols-2 gap-4 rounded-xl bg-surface-container-lowest/40 p-4 sm:grid-cols-4">
        <div class="flex items-center gap-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-surface-container-high text-primary">
            <span class="material-symbols-outlined text-lg">devices</span>
          </div>
          <div>
            <div class="font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">已授权终端</div>
            <div class="text-sm font-semibold text-on-surface">{{ devicesStore.devices.length }} 台设备</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-surface-container-high text-tertiary">
            <span class="material-symbols-outlined text-lg">notifications_active</span>
          </div>
          <div>
            <div class="font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">FCM 推送通道</div>
            <div class="text-sm font-semibold text-on-surface">{{ fcmActiveCount }} 台已激活</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-surface-container-high text-primary">
            <span class="material-symbols-outlined text-lg">shield_lock</span>
          </div>
          <div>
            <div class="font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">平台分布</div>
            <div class="text-sm font-semibold text-on-surface">{{ platformCount }} 类平台</div>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-surface-container-high text-secondary">
            <span class="material-symbols-outlined text-lg">sync</span>
          </div>
          <div>
            <div class="font-mono text-[10px] uppercase tracking-wider text-on-surface-variant">最近同步</div>
            <div class="text-sm font-semibold text-on-surface">{{ latestSync }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- 设备卡片网格 -->
    <div v-if="devicesStore.loading && devicesStore.devices.length === 0" class="flex items-center justify-center gap-3 py-20 text-on-surface-variant">
      <span class="h-5 w-5 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
      <span class="font-mono text-xs">加载设备清单中...</span>
    </div>

    <div v-else-if="devicesStore.devices.length === 0" class="flex flex-col items-center gap-3 rounded-xl bg-surface-container/40 py-16 text-on-surface-variant backdrop-blur-xl">
      <span class="material-symbols-outlined text-5xl opacity-30">devices</span>
      <span class="font-mono text-xs">暂无已注册设备 · 等待终端接入</span>
    </div>

    <div v-else class="mb-10 grid grid-cols-1 gap-5 lg:grid-cols-2">
      <div
        v-for="device in devicesStore.devices"
        :key="device.device_id"
        class="group relative flex flex-col justify-between overflow-hidden rounded-2xl bg-surface-container/60 p-6 shadow-lg backdrop-blur-xl transition-all duration-300 hover:shadow-2xl"
      >
        <div class="pointer-events-none absolute right-0 top-0 h-32 w-32 rounded-bl-full bg-primary/5" />

        <div>
          <div class="mb-5 flex items-start justify-between gap-4">
            <div class="flex items-center gap-3.5">
              <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary shadow-inner">
                <span class="material-symbols-outlined text-2xl">{{ deviceMeta(device.platform).icon }}</span>
              </div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="text-base font-semibold tracking-tight text-on-surface">{{ device.device_name }}</h3>
                  <span
                    v-if="device.fcm_token"
                    class="inline-flex items-center rounded-full bg-primary/15 px-2 py-0.5 font-mono text-[10px] font-medium text-primary"
                  >
                    推送已激活
                  </span>
                </div>
                <div class="mt-1 flex items-center gap-2">
                  <span class="text-xs font-medium text-on-surface-variant">{{ deviceMeta(device.platform).label }}</span>
                  <span class="text-[11px] text-outline">•</span>
                  <span class="text-xs text-on-surface-variant">{{ deviceMeta(device.platform).emoji }}</span>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-1.5">
              <button
                type="button"
                class="flex items-center gap-1 rounded-lg bg-surface-container-high px-3 py-1.5 text-xs font-medium text-on-surface-variant transition-colors hover:bg-primary-container hover:text-on-primary-container"
                title="发送远程通知"
                @click="openPushModal(device)"
              >
                <span class="material-symbols-outlined text-base">send</span>
                <span>推送</span>
              </button>
              <button
                type="button"
                class="rounded-lg bg-surface-container-high p-1.5 text-on-surface-variant transition-colors hover:bg-error-container hover:text-error"
                title="解除授权并删除设备"
                @click="handleDelete(device)"
              >
                <span class="material-symbols-outlined text-base">delete</span>
              </button>
            </div>
          </div>

          <!-- 规格信息行 -->
          <div class="grid grid-cols-1 gap-3 rounded-xl bg-surface-container-lowest/50 p-3.5 font-mono text-xs sm:grid-cols-2">
            <div class="flex flex-col gap-1">
              <span class="text-[10px] uppercase tracking-wider text-on-surface-variant">Device ID</span>
              <button
                type="button"
                class="group/btn flex items-center justify-between rounded bg-surface-variant/40 px-2 py-1 text-left text-on-surface transition-colors hover:bg-surface-variant"
                @click="copyDeviceId(device.device_id)"
              >
                <span class="truncate">{{ device.device_id }}</span>
                <span class="material-symbols-outlined ml-1 text-sm text-on-surface-variant group-hover/btn:text-primary">content_copy</span>
              </button>
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-[10px] uppercase tracking-wider text-on-surface-variant">FCM Push Token</span>
              <div class="flex items-center justify-between rounded bg-surface-variant/40 px-2 py-1 text-on-surface-variant">
                <span class="truncate">{{ device.fcm_token ? `${device.fcm_token.slice(0, 18)}...` : '未注册' }}</span>
                <span
                  v-if="device.fcm_token"
                  class="rounded bg-primary/20 px-1.5 py-0.5 font-sans text-[10px] font-medium text-primary"
                >
                  已激活
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between pt-3 font-mono text-xs text-on-surface-variant">
          <div class="flex items-center gap-1.5">
            <span class="material-symbols-outlined text-sm text-secondary">history</span>
            <span>注册于 {{ formatTime(device.created_at) }}</span>
          </div>
          <div v-if="device.last_sync_at" class="flex items-center gap-1 text-primary">
            <span class="h-1.5 w-1.5 animate-ping rounded-full bg-primary" />
            <span>最后同步: {{ formatTime(device.last_sync_at) }}</span>
          </div>
          <div v-else class="text-outline">尚未同步</div>
        </div>
      </div>
    </div>

    <!-- 推送消息模态框 -->
    <Dialog v-model:open="showPushModal">
      <DialogContent class="max-w-md">
        <DialogHeader class="flex-row items-center gap-3 space-y-0">
          <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary">
            <span class="material-symbols-outlined text-xl">cell_tower</span>
          </div>
          <div>
            <DialogTitle>
              {{ selectedDevice ? `推送到 ${selectedDevice.device_name}` : '推送到所有设备' }}
            </DialogTitle>
            <DialogDescription class="mt-0.5">
              {{ selectedDevice ? `目标: ${selectedDevice.device_id}` : `将广播至 ${devicesStore.devices.length} 台已授权设备` }}
            </DialogDescription>
          </div>
        </DialogHeader>

        <div class="space-y-4">
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-on-surface-variant">推送标题</label>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">send</span>
              <input
                v-model="pushTitle"
                type="text"
                placeholder="推送标题"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-on-surface-variant">推送内容</label>
            <textarea
              v-model="pushBody"
              rows="3"
              placeholder="推送内容"
              class="w-full resize-none rounded-lg bg-surface-container px-3.5 py-2.5 text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>
        </div>

        <DialogFooter class="gap-2.5">
          <Button variant="ghost" size="sm" @click="showPushModal = false">取消</Button>
          <Button size="sm" :disabled="pushLoading" @click="sendPushMessage">
            <span v-if="pushLoading" class="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" />
            <span v-else class="material-symbols-outlined text-base">send</span>
            <span>{{ pushLoading ? '发送中...' : '发送推送' }}</span>
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
