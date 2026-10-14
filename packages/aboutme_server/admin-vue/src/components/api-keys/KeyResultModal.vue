<script setup lang="ts">
import { ref, computed } from 'vue'
import { apiClient } from '@/api'
import { useMessage } from '@/composables/useMessage'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogTitle
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'

interface Props {
  show: boolean
  apiKey: { name: string; key: string } | null
}

const props = defineProps<Props>()

const emit = defineEmits<{
  'update:show': [value: boolean]
  close: []
}>()

const message = useMessage()

const masked = ref(true)
const copiedKey = ref(false)
const copiedConfig = ref(false)

const mcpConfig = computed(() => {
  if (!props.apiKey) return ''
  return JSON.stringify(
    {
      mcpServers: {
        'aboutme-sync': {
          command: 'npx',
          args: ['-y', '@aboutme/mcp-server'],
          env: {
            ABOUTME_SERVER_URL: apiClient.getBaseUrl(),
            ABOUTME_API_KEY: props.apiKey.key
          }
        }
      }
    },
    null,
    2
  )
})

async function copyToClipboard(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text)
  } catch {
    // 降级方案
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    document.body.removeChild(textarea)
  }
}

async function handleCopyKey(): Promise<void> {
  if (!props.apiKey) return
  await copyToClipboard(props.apiKey.key)
  copiedKey.value = true
  message.success('已复制密钥到剪贴板')
  setTimeout(() => (copiedKey.value = false), 2000)
}

async function handleCopyConfig(): Promise<void> {
  await copyToClipboard(mcpConfig.value)
  copiedConfig.value = true
  message.success('已复制配置到剪贴板')
  setTimeout(() => (copiedConfig.value = false), 2000)
}

function handleClose(): void {
  emit('close')
  emit('update:show', false)
}
</script>

<template>
  <Dialog
    :open="show"
    @update:open="(v: boolean) => emit('update:show', v)"
  >
    <DialogContent class="max-w-2xl overflow-hidden p-0" hide-close>
      <!-- 顶部渐变强调线 -->
      <div class="h-1 w-full bg-gradient-to-r from-primary via-tertiary to-primary" />

      <div class="space-y-6 p-6">
        <!-- 头部 -->
        <div class="flex items-start justify-between gap-4">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20 text-primary shadow-[0_0_20px_rgba(125,211,252,0.3)]">
              <span class="material-symbols-outlined text-2xl">verified</span>
            </div>
            <div>
              <DialogTitle class="text-base font-bold tracking-tight text-on-surface">
                API Key 创建成功
              </DialogTitle>
              <DialogDescription class="mt-0.5">
                请即刻备份，关闭后将不再显示完整内容。
              </DialogDescription>
            </div>
          </div>
          <button
            class="flex h-8 w-8 items-center justify-center rounded-lg text-on-surface-variant transition-colors hover:bg-surface-variant hover:text-on-surface"
            @click="handleClose"
          >
            <span class="material-symbols-outlined text-lg">close</span>
          </button>
        </div>

        <div v-if="apiKey" class="space-y-6">
          <!-- 密钥展示框 -->
          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs">
              <span class="font-mono uppercase tracking-wider text-on-surface-variant">API 密钥 ({{ apiKey.name }})</span>
              <span class="flex items-center gap-1 text-[11px] font-medium text-error">
                <span class="material-symbols-outlined text-[13px]">warning</span>
                仅显一次
              </span>
            </div>
            <div class="group relative flex items-center rounded-xl bg-surface-container-lowest/90 px-4 py-3 shadow-inner">
              <span class="material-symbols-outlined mr-3 text-[20px] text-primary">key</span>
              <span
                class="w-full select-all overflow-hidden text-ellipsis whitespace-nowrap font-mono text-xs font-medium text-primary"
              >
                {{ masked ? '•'.repeat(Math.min(apiKey.key.length, 40)) : apiKey.key }}
              </span>
              <div class="ml-2 flex items-center gap-1.5">
                <button
                  type="button"
                  class="rounded-lg p-1.5 text-on-surface-variant transition-colors hover:bg-surface-variant hover:text-on-surface"
                  title="切换显示状态"
                  @click="masked = !masked"
                >
                  <span class="material-symbols-outlined text-base">
                    {{ masked ? 'visibility' : 'visibility_off' }}
                  </span>
                </button>
                <Button size="xs" @click="handleCopyKey">
                  <span class="material-symbols-outlined text-[15px]">
                    {{ copiedKey ? 'check' : 'content_copy' }}
                  </span>
                  <span>{{ copiedKey ? '已复制!' : '复制密钥' }}</span>
                </Button>
              </div>
            </div>
          </div>

          <!-- MCP 配置示例 -->
          <div class="space-y-2">
            <div class="flex items-center justify-between text-xs">
              <div class="flex items-center gap-2">
                <span class="font-mono text-on-surface-variant">MCP Server 配置示例</span>
                <span class="rounded bg-surface-variant px-1.5 py-0.5 font-mono text-[10px] text-on-surface-variant">
                  mcp_config.json
                </span>
              </div>
              <button
                type="button"
                class="flex items-center gap-1 text-xs font-medium text-primary transition-colors hover:text-primary-fixed"
                @click="handleCopyConfig"
              >
                <span class="material-symbols-outlined text-[14px]">file_copy</span>
                <span>{{ copiedConfig ? '已复制到剪贴板' : '复制配置' }}</span>
              </button>
            </div>
            <div class="relative overflow-hidden rounded-xl bg-surface-container-lowest/90 shadow-inner">
              <div class="flex items-center bg-surface-container-high/40 px-4 py-2">
                <span class="flex items-center gap-2">
                  <span class="inline-block h-2.5 w-2.5 rounded-full bg-error/70" />
                  <span class="inline-block h-2.5 w-2.5 rounded-full bg-primary/70" />
                  <span class="inline-block h-2.5 w-2.5 rounded-full bg-tertiary/70" />
                </span>
              </div>
              <pre class="overflow-x-auto p-4 font-mono text-xs leading-relaxed text-on-surface-variant"><code>{{ mcpConfig }}</code></pre>
            </div>
          </div>

          <!-- 使用说明 -->
          <div class="flex items-start gap-2.5 rounded-xl bg-surface-container-low/70 p-3.5 text-xs leading-relaxed text-on-surface-variant">
            <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-primary">query_stats</span>
            <p>
              API Key 用于代替用户名密码进行认证。调用需要解密的接口时，需通过
              <span class="font-mono text-primary/90">X-Encryption-Key</span> 请求头传递加密密钥。
            </p>
          </div>
        </div>

        <DialogFooter class="justify-end pt-2">
          <Button variant="secondary" size="sm" class="bg-surface-container-highest hover:bg-surface-variant" @click="handleClose">
            我已保存，完成
          </Button>
        </DialogFooter>
      </div>
    </DialogContent>
  </Dialog>
</template>
