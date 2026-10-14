<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useUIStore } from '@/stores/ui'
import { useDialog } from '@/composables/useDialog'
import { useMessage } from '@/composables/useMessage'
import { authApi } from '@/api'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'

const authStore = useAuthStore()
const uiStore = useUIStore()
const dialog = useDialog()
const message = useMessage()

// API 访问开关状态
const apiEnabled = ref(false)
const loadingApiStatus = ref(false)
const togglingApi = ref(false)

// 密钥输入
const keyInput = ref('')
const savingKey = ref(false)

// 本地是否有密钥
const hasLocalKey = computed(() => !!authStore.encryptionKey)

// 脱敏显示的密钥
const maskedKey = computed(() => {
  const key = authStore.encryptionKey
  if (!key) return ''
  return `${key.slice(0, 4)}${'•'.repeat(Math.max(0, key.length - 8))}${key.slice(-4)}`
})

// 字符计数
const charCount = computed(() => keyInput.value.length)

// 格式状态提示
const formatStatus = computed(() => {
  const key = keyInput.value.trim()
  if (!key) return { text: '等待输入', dot: 'bg-outline', cls: 'text-outline' }
  if (key.length !== 44) return { text: `长度 ${key.length} / 44`, dot: 'bg-tertiary', cls: 'text-tertiary' }
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(key)) return { text: '格式异常', dot: 'bg-error', cls: 'text-error' }
  return { text: '格式正确', dot: 'bg-primary', cls: 'text-primary' }
})

// 初始化加载 API 访问状态
onMounted(async () => {
  await loadApiAccessStatus()
})

async function loadApiAccessStatus(): Promise<void> {
  loadingApiStatus.value = true
  try {
    const response = await authApi.getApiAccessStatus()
    apiEnabled.value = response.enabled
  } catch (e) {
    console.error('获取 API 访问状态失败:', e)
  } finally {
    loadingApiStatus.value = false
  }
}

// 切换 API 访问状态
async function handleToggleApi(enabled: boolean): Promise<void> {
  togglingApi.value = true
  try {
    const response = await authApi.setApiAccessStatus(enabled)
    apiEnabled.value = response.enabled
    message.success(response.message)
    uiStore.addActivity('settings', enabled ? '开启了 API 访问' : '关闭了 API 访问')
  } catch (e) {
    // 恢复原状态
    apiEnabled.value = !enabled
    const errorMessage = e instanceof Error ? e.message : '设置失败'
    message.error(errorMessage)
  } finally {
    togglingApi.value = false
  }
}

// 验证密钥格式
function validateKeyFormat(key: string): boolean {
  if (!/^[A-Za-z0-9+/]+=*$/.test(key)) {
    message.error('加密密钥格式无效，应为 Base64 编码')
    return false
  }
  if (key.length < 40) {
    message.error('加密密钥长度不足，标准长度为 44 个字符')
    return false
  }
  return true
}

// AES-GCM 解密（与客户端加密服务兼容）
async function decryptVerificationData(encryptedData: string, key: string): Promise<string> {
  const parts = encryptedData.split('.')
  if (parts.length !== 2) {
    throw new Error('加密数据格式无效')
  }

  const [ivBase64, combinedBase64] = parts

  const iv = Uint8Array.from(atob(ivBase64), c => c.charCodeAt(0))
  const combined = Uint8Array.from(atob(combinedBase64), c => c.charCodeAt(0))
  const keyBytes = Uint8Array.from(atob(key), c => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey('raw', keyBytes, { name: 'AES-GCM' }, false, ['decrypt'])

  const decrypted = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, cryptoKey, combined)

  return new TextDecoder().decode(decrypted)
}

// 验证并保存密钥
async function handleSaveKey(): Promise<void> {
  const key = keyInput.value.trim()

  if (!validateKeyFormat(key)) {
    return
  }

  savingKey.value = true
  try {
    // 1. 获取服务端的验证文件
    const response = await authApi.getKeyVerification()

    if (!response.exists) {
      message.error('服务端没有密钥验证文件，请先在客户端完成首次同步')
      savingKey.value = false
      return
    }

    // 2. 本地解密验证
    if (!response.encrypted_data) {
      message.error('验证文件数据无效')
      savingKey.value = false
      return
    }

    try {
      const decryptedJson = await decryptVerificationData(response.encrypted_data, key)
      const verificationData = JSON.parse(decryptedJson)

      // 验证内容
      if (verificationData.content !== 'ABOUTME_KEY_VERIFICATION_v1') {
        message.error('密钥验证失败：内容不匹配')
        return
      }

      // 验证成功，保存密钥到本地
      authStore.setEncryptionKey(key)
      keyInput.value = ''
      message.success('密钥验证成功')
      uiStore.addActivity('settings', '验证了加密密钥')
    } catch {
      message.error('密钥验证失败：无法解密验证文件，密钥可能不正确')
    }
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : '验证失败'
    message.error(errorMessage)
  } finally {
    savingKey.value = false
  }
}

function handleDisableApi(): void {
  dialog.warning({
    title: '清除加密密钥',
    content: '确定要清除本地保存的加密密钥吗？清除后需要重新输入密钥才能解密文件。',
    type: 'error',
    positiveText: '清除',
    negativeText: '取消',
    onPositiveClick: () => {
      authStore.clearEncryptionKey()
      message.success('本地加密密钥已清除')
      uiStore.addActivity('settings', '清除了本地加密密钥')
    }
  })
}

async function copyToClipboard(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text)
    message.success('已复制到剪贴板')
  } catch {
    message.error('复制失败')
  }
}
</script>

<template>
  <!-- 模块卡片 -->
  <div class="relative overflow-hidden rounded-2xl bg-surface/65 p-6 shadow-[0_4px_30px_rgba(0,0,0,0.35)] backdrop-blur-2xl sm:p-8">
    <div class="pointer-events-none absolute -right-24 -top-24 h-48 w-48 rounded-full bg-primary/10 blur-3xl" />

    <!-- 标题区 -->
    <div class="flex items-start justify-between gap-4 border-b border-outline-variant/30 pb-6">
      <div class="flex items-center gap-3.5">
        <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-container/40 text-primary shadow-[0_0_20px_rgba(125,211,252,0.12)]">
          <span class="material-symbols-outlined text-xl">token</span>
        </div>
        <h2 class="text-lg font-bold tracking-tight text-on-surface">API 访问控制与密钥管理</h2>
      </div>
    </div>

    <!-- 全局 API 开关 -->
    <div class="flex flex-col justify-between gap-4 border-b border-outline-variant/20 py-6 sm:flex-row sm:items-center">
      <div class="space-y-1 pr-4">
        <span class="text-sm font-semibold text-on-surface">全局 API 访问权限</span>
        <p class="text-xs leading-relaxed text-on-surface-variant">
          允许外部客户端及自动化脚本通过 Bearer Token 访问。
        </p>
      </div>
      <Switch
        :model-value="apiEnabled"
        :disabled="loadingApiStatus || togglingApi"
        @update:model-value="handleToggleApi"
      />
    </div>

    <!-- 密钥安全子模块 -->
    <div class="mt-6 flex flex-col gap-6">
      <!-- 当前密钥状态 -->
      <div class="rounded-xl bg-surface-container/60 p-5 shadow-inner backdrop-blur-md">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-2">
            <span class="material-symbols-outlined text-base text-primary">verified_user</span>
            <span class="text-xs font-semibold text-on-surface">加密主密钥 (Master Secret Key)</span>
          </div>
          <div
            class="flex items-center gap-1.5 rounded-full px-2.5 py-0.5 font-mono text-xs"
            :class="hasLocalKey ? 'bg-primary-container/30 text-primary' : 'bg-error-container/40 text-error'"
          >
            <span class="h-1.5 w-1.5 rounded-full" :class="hasLocalKey ? 'bg-primary' : 'bg-error'" />
            <span>{{ hasLocalKey ? '已设置 [安全受保护]' : '未设置' }}</span>
          </div>
        </div>

        <!-- 密钥可视化块 -->
        <div
          v-if="hasLocalKey"
          class="flex flex-col items-stretch justify-between gap-3 rounded-lg bg-surface-container-lowest/80 p-3.5 font-mono sm:flex-row sm:items-center"
        >
          <div class="flex items-center gap-3 overflow-hidden">
            <span class="material-symbols-outlined text-base text-on-surface-variant">key</span>
            <span class="select-all truncate text-xs font-semibold tracking-wider text-on-surface">{{ maskedKey }}</span>
          </div>
          <Button
            variant="secondary"
            size="xs"
            class="shrink-0 bg-surface-variant hover:bg-surface-variant/80"
            @click="copyToClipboard(authStore.encryptionKey)"
          >
            <span class="material-symbols-outlined text-sm">content_copy</span>
            <span>复制密钥</span>
          </Button>
        </div>

        <div
          v-else
          class="flex items-start gap-2.5 rounded-lg bg-error-container/25 p-3 text-xs leading-relaxed text-on-error-container"
        >
          <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-error">warning</span>
          <p>需要提供加密密钥才能解密文件（从 Aboutme 客户端获取）。</p>
        </div>
      </div>

      <!-- 密钥更新表单 -->
      <div class="space-y-4">
        <div>
          <div class="mb-2 flex items-center justify-between">
            <label class="flex items-center gap-1.5 text-xs font-semibold text-on-surface">
              <span>设置 / 轮换主密钥</span>
              <span class="font-normal text-on-surface-variant">(Base64 编码)</span>
            </label>
            <div class="flex items-center gap-2">
              <span class="flex items-center gap-1 font-mono text-[11px]" :class="formatStatus.cls">
                <span class="h-1.5 w-1.5 rounded-full" :class="formatStatus.dot" />
                <span>{{ formatStatus.text }}</span>
              </span>
              <span class="rounded bg-surface-container px-2 py-0.5 font-mono text-[11px] text-on-surface-variant">
                {{ charCount }} / 44
              </span>
            </div>
          </div>
          <div class="relative">
            <input
              v-model="keyInput"
              type="text"
              maxlength="44"
              autocomplete="off"
              spellcheck="false"
              placeholder="粘贴完整的 44 位 Base64 加密密钥..."
              class="w-full rounded-xl bg-surface-container-low/90 px-4 py-3 font-mono text-xs text-on-surface transition-all placeholder:text-outline/70 focus:bg-surface-container-high focus:shadow-[0_0_20px_rgba(125,211,252,0.15)] focus:outline-none"
              @keyup.enter="handleSaveKey"
            />
            <div class="pointer-events-none absolute right-3 top-3 text-outline-variant">
              <span class="material-symbols-outlined text-base">password</span>
            </div>
          </div>
        </div>

        <!-- 验证说明 -->
        <div class="flex items-start gap-2.5 rounded-xl bg-surface-container-lowest/50 p-3 text-xs leading-relaxed text-on-surface-variant">
          <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-primary">query_stats</span>
          <p>
            解密 <span class="font-mono text-primary/90">.vault_verify.enc</span> 校验密钥有效性，通过后保存至本地。
          </p>
        </div>

        <!-- 操作按钮 -->
        <div class="flex flex-wrap items-center justify-between gap-3 pt-2">
          <Button size="lg" class="rounded-xl" :disabled="savingKey || !keyInput.trim()" @click="handleSaveKey">
            <span v-if="savingKey" class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
            <span v-else class="material-symbols-outlined text-base">check_circle</span>
            <span>{{ savingKey ? '验证中...' : '验证并更新密钥' }}</span>
          </Button>
          <Button
            v-if="hasLocalKey"
            variant="destructive"
            size="lg"
            class="rounded-xl bg-error-container/30 hover:bg-error-container/60"
            @click="handleDisableApi"
          >
            <span class="material-symbols-outlined text-base">delete_forever</span>
            <span>清除本地密钥</span>
          </Button>
        </div>
      </div>

      <!-- 提示横幅 -->
      <div class="mt-2 flex items-start gap-3 rounded-xl bg-gradient-to-r from-tertiary-container/30 to-surface-container/40 p-4 text-xs text-on-surface">
        <span class="select-none text-base">💡</span>
        <div class="leading-relaxed">
          <span class="font-semibold text-tertiary-fixed">同步建议：</span>
          <span class="text-on-surface-variant">可在客户端「设置 &gt; 开发者选项」中导出端到端主密钥。</span>
        </div>
      </div>
    </div>
  </div>
</template>
