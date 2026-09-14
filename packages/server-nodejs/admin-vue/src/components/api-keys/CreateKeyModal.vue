<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useMessage } from '@/composables/useMessage'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'

interface Props {
  show: boolean
}

defineProps<Props>()

const emit = defineEmits<{
  'update:show': [value: boolean]
  success: []
}>()

const authStore = useAuthStore()
const message = useMessage()

const form = reactive({
  name: '',
  expiry: 'never' as 'never' | '7days' | '30days' | '90days' | '1year'
})

const loading = ref(false)

const expiryOptions = [
  { label: '永不过期', value: 'never' },
  { label: '7 天', value: '7days' },
  { label: '30 天', value: '30days' },
  { label: '90 天', value: '90days' },
  { label: '1 年', value: '1year' }
] as const

async function handleCreate(): Promise<void> {
  if (!form.name.trim()) {
    message.error('请输入 API Key 名称')
    return
  }

  loading.value = true
  try {
    await authStore.createApiKey({
      name: form.name.trim(),
      expiry: form.expiry
    })

    // 重置表单
    form.name = ''
    form.expiry = 'never'

    emit('success')
  } catch (err) {
    message.error(err instanceof Error ? err.message : '创建失败')
  } finally {
    loading.value = false
  }
}

function handleClose(): void {
  emit('update:show', false)
}
</script>

<template>
  <Dialog
    :open="show"
    @update:open="(v: boolean) => emit('update:show', v)"
  >
    <DialogContent class="max-w-md" hide-close>
      <DialogHeader class="flex-row items-center gap-3 space-y-0">
        <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary shadow-[0_0_15px_rgba(125,211,252,0.2)]">
          <span class="material-symbols-outlined text-xl">vpn_key</span>
        </div>
        <div>
          <DialogTitle>创建 API Key</DialogTitle>
          <DialogDescription class="mt-0.5">
            为 MCP Server 等外部应用签发访问密钥
          </DialogDescription>
        </div>
      </DialogHeader>

      <div class="space-y-5">
        <div class="flex flex-col gap-1.5">
          <label class="flex items-center justify-between text-xs font-medium text-on-surface-variant">
            <span>密钥名称 <span class="text-error">*</span></span>
          </label>
          <div class="relative flex items-center">
            <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">badge</span>
            <input
              v-model="form.name"
              type="text"
              placeholder="例如: Claude Desktop MCP"
              class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              @keyup.enter="handleCreate"
            />
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-xs font-medium text-on-surface-variant">过期时间</label>
          <div class="grid grid-cols-5 gap-1.5 rounded-xl bg-surface-container p-1 shadow-inner">
            <button
              v-for="option in expiryOptions"
              :key="option.value"
              type="button"
              class="rounded-lg px-1 py-1.5 text-[11px] font-medium transition-all"
              :class="
                form.expiry === option.value
                  ? 'bg-primary-container text-on-primary-container shadow-sm'
                  : 'text-on-surface-variant hover:text-on-surface'
              "
              @click="form.expiry = option.value"
            >
              {{ option.label }}
            </button>
          </div>
        </div>

        <div class="flex items-start gap-2.5 rounded-xl bg-surface-container-lowest/50 p-3 text-xs leading-relaxed text-on-surface-variant">
          <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-primary">info</span>
          <p>密钥创建后仅完整展示一次，请立即备份。调用解密接口时需通过 <span class="font-mono text-primary/90">X-Encryption-Key</span> 请求头传递加密密钥。</p>
        </div>
      </div>

      <DialogFooter class="gap-2.5">
        <Button variant="ghost" size="sm" @click="handleClose">取消</Button>
        <Button size="sm" :disabled="loading" @click="handleCreate">
          <span v-if="loading" class="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent" />
          <span v-else class="material-symbols-outlined text-base">add_circle</span>
          <span>{{ loading ? '签发中...' : '签发密钥' }}</span>
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
