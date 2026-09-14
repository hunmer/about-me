<script setup lang="ts">
import { ref, reactive, watch, onMounted, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useUIStore } from '@/stores/ui'
import { useFilesStore } from '@/stores/files'
import { useMessage } from '@/composables/useMessage'
import { authApi, apiClient } from '@/api'
import { Button } from '@/components/ui/button'

const props = defineProps<{
  prefillUsername?: string
  prefillPassword?: string
}>()

const emit = defineEmits<{
  (e: 'registered', username: string, password: string): void
}>()

const authStore = useAuthStore()
const uiStore = useUIStore()
const filesStore = useFilesStore()
const message = useMessage()

type AuthMode = 'login' | 'register'
const mode = ref<AuthMode>('login')

const loginForm = reactive({
  username: '',
  password: '',
  serverUrl: localStorage.getItem('serverUrl') || 'http://localhost:8874'
})

const regForm = reactive({
  username: '',
  password: '',
  confirmPassword: '',
  serverUrl: localStorage.getItem('serverUrl') || 'http://localhost:8874'
})

const error = ref('')
const loginLoading = ref(false)
const regLoading = ref(false)
const allowRegister = ref(true)
const showLoginPassword = ref(false)
const showRegPassword = ref(false)

// 注册成功回填提示
const registeredNotice = ref(false)

// 注册表单校验提示状态
const usernameHint = computed(() => {
  const len = regForm.username.length
  if (len === 0) return { text: '至少 3 个字符', cls: 'text-on-surface-variant' }
  if (len < 3) return { text: '字符数不足 (需 ≥ 3)', cls: 'text-error font-medium' }
  return { text: '用户名可用 ✓', cls: 'text-emerald-400 font-medium' }
})

const passwordHint = computed(() => {
  const len = regForm.password.length
  if (len === 0) return { text: '至少 6 个字符', cls: 'text-on-surface-variant' }
  if (len < 6) return { text: '长度过短 (需 ≥ 6)', cls: 'text-error' }
  return { text: '安全强度良好', cls: 'text-emerald-400' }
})

const matchStatus = computed(() => {
  if (!regForm.confirmPassword) return { text: '待核对', cls: 'text-on-surface-variant', icon: '' }
  if (regForm.password === regForm.confirmPassword)
    return { text: '密码一致', cls: 'text-emerald-400', icon: 'check_circle' }
  return { text: '密码不匹配', cls: 'text-error', icon: 'cancel' }
})

// 监听预填充凭据
watch(
  () => [props.prefillUsername, props.prefillPassword],
  ([username, password]) => {
    if (username) loginForm.username = username
    if (password) loginForm.password = password
  },
  { immediate: true }
)

onMounted(async () => {
  // 检查服务器是否允许注册
  try {
    apiClient.setBaseUrl(regForm.serverUrl)
    const response = await authApi.getRegisterStatus()
    allowRegister.value = response.allow_register
  } catch (e) {
    console.warn('无法获取注册状态:', e)
  }
})

function switchMode(target: AuthMode): void {
  mode.value = target
  error.value = ''
}

function fillDefaults(): void {
  loginForm.username = 'admin'
  loginForm.password = 'admin123'
}

async function handleLogin(): Promise<void> {
  if (!loginForm.username || !loginForm.password) {
    error.value = '请输入用户名和密码'
    return
  }

  loginLoading.value = true
  error.value = ''

  try {
    await authStore.login(loginForm.username, loginForm.password, loginForm.serverUrl)

    // 加载数据
    await Promise.all([
      checkServerHealth(),
      filesStore.loadFiles(),
      authStore.loadApiKeys()
    ])

    message.success('登录成功')
  } catch (err) {
    error.value = err instanceof Error ? err.message : '登录失败，请检查用户名和密码'
  } finally {
    loginLoading.value = false
  }
}

async function checkServerHealth(): Promise<void> {
  try {
    const response = await fetch(`${loginForm.serverUrl}/health`)
    uiStore.setServerStatus(response.ok ? 'online' : 'offline')
  } catch {
    uiStore.setServerStatus('offline')
  }
}

async function handleRegister(): Promise<void> {
  if (!regForm.username || !regForm.password) {
    error.value = '请填写用户名和密码'
    return
  }
  if (regForm.username.length < 3) {
    error.value = '用户名至少需要 3 个字符'
    return
  }
  if (regForm.password.length < 6) {
    error.value = '密码至少需要 6 个字符'
    return
  }
  if (regForm.password !== regForm.confirmPassword) {
    error.value = '两次输入的密码不一致'
    return
  }

  regLoading.value = true
  error.value = ''

  try {
    apiClient.setBaseUrl(regForm.serverUrl)

    const response = await authApi.register({
      username: regForm.username,
      password: regForm.password,
      device_id: 'admin_panel',
      device_name: 'Admin Panel'
    })

    if (!response.success) {
      error.value = response.error || '注册失败'
      return
    }

    // 回填登录表单并切换
    loginForm.username = regForm.username
    loginForm.password = regForm.password
    loginForm.serverUrl = regForm.serverUrl
    registeredNotice.value = true
    switchMode('login')
    emit('registered', regForm.username, regForm.password)
  } catch (err) {
    error.value = err instanceof Error ? err.message : '注册失败'
  } finally {
    regLoading.value = false
  }
}
</script>

<template>
  <main class="relative z-10 flex min-h-screen w-full items-center justify-center p-4 sm:p-6 md:p-10">
    <!-- 登录页专属环境光晕 -->
    <div class="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <div class="absolute -top-32 -left-32 h-96 w-96 rounded-full bg-primary/10 blur-[128px]" />
      <div class="absolute -bottom-32 -right-32 h-96 w-96 rounded-full bg-tertiary/10 blur-[128px]" />
    </div>

    <div class="relative flex w-full max-w-[500px] flex-col items-center">
      <!-- 卡片背面的辉光 -->
      <div class="pointer-events-none absolute -top-10 left-1/2 h-32 w-3/4 -translate-x-1/2 rounded-full bg-primary/20 blur-[70px]" />
      <div class="pointer-events-none absolute -bottom-10 left-1/2 h-28 w-2/3 -translate-x-1/2 rounded-full bg-tertiary/15 blur-[60px]" />

      <!-- 主玻璃卡片 -->
      <div class="relative w-full rounded-2xl bg-surface/80 p-6 shadow-[0_8px_40px_rgba(0,0,0,0.55)] backdrop-blur-2xl transition-all duration-300 sm:p-9">
        <!-- 顶部品牌 -->
        <div class="mb-7 flex flex-col items-center text-center">
          <div class="group mb-3.5 flex h-14 w-14 items-center justify-center rounded-xl bg-surface-container-high text-primary shadow-inner shadow-primary/20 transition-transform duration-300 hover:scale-105">
            <span
              class="material-symbols-outlined text-3xl transition-transform duration-500 group-hover:rotate-180"
              style="font-variation-settings: 'FILL' 1"
            >
              all_inclusive
            </span>
          </div>
          <div class="flex items-center gap-2">
            <h2 class="text-xl font-bold tracking-tight text-on-surface">
              Aboutme Sync Server
            </h2>
          </div>
        </div>

        <!-- 模式切换 Tabs -->
        <div class="mb-6 grid grid-cols-2 rounded-xl bg-surface-container p-1 shadow-inner">
          <button
            type="button"
            class="flex items-center justify-center gap-2 rounded-lg py-2 text-sm font-medium transition-all duration-200"
            :class="
              mode === 'login'
                ? 'bg-surface-bright text-primary shadow-sm'
                : 'text-on-surface-variant hover:text-on-surface'
            "
            @click="switchMode('login')"
          >
            <span class="material-symbols-outlined text-base">lock_open</span>
            <span>系统登录</span>
          </button>
          <button
            type="button"
            class="flex items-center justify-center gap-2 rounded-lg py-2 text-sm font-medium transition-all duration-200"
            :class="
              mode === 'register'
                ? 'bg-surface-bright text-tertiary shadow-sm'
                : 'text-on-surface-variant hover:text-on-surface'
            "
            @click="switchMode('register')"
          >
            <span class="material-symbols-outlined text-base">person_add</span>
            <span>注册账户</span>
            <span
              class="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-400"
              title="开放注册"
            />
          </button>
        </div>

        <!-- 注册成功提示 -->
        <div
          v-if="registeredNotice"
          class="mb-5 flex items-start gap-2.5 rounded-lg bg-surface-container-high/90 p-3 text-xs text-on-surface transition-all duration-300"
        >
          <span class="material-symbols-outlined mt-0.5 shrink-0 text-base text-primary" style="font-variation-settings: 'FILL' 1">
            check_circle
          </span>
          <div class="flex-1">
            <p class="font-semibold text-primary">注册成功！</p>
            <p class="mt-0.5 text-on-surface-variant">凭据已自动回填，请点击登录进入面板。</p>
          </div>
          <button
            class="shrink-0 text-on-surface-variant transition-colors hover:text-on-surface"
            @click="registeredNotice = false"
          >
            <span class="material-symbols-outlined text-sm">close</span>
          </button>
        </div>

        <!-- 注册开放状态横幅（仅注册模式） -->
        <div
          v-if="mode === 'register'"
          class="mb-5 flex items-center justify-between rounded-lg bg-surface-container-low px-3.5 py-2.5"
        >
          <div class="flex items-center gap-2">
            <span class="relative flex h-2 w-2">
              <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span class="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            <span class="font-mono text-xs text-on-surface">NODE: {{ regForm.serverUrl.replace(/^https?:\/\//, '') }}</span>
          </div>
          <span
            class="inline-flex items-center gap-1 rounded bg-emerald-950/60 px-2 py-0.5 text-[11px] font-medium"
            :class="allowRegister ? 'text-emerald-300' : 'text-error'"
          >
            <span class="material-symbols-outlined text-xs">how_to_reg</span>
            {{ allowRegister ? '开放注册 (Open)' : '注册已关闭' }}
          </span>
        </div>

        <!-- 默认凭据横幅（仅登录模式） -->
        <div
          v-if="mode === 'login'"
          class="mb-5 flex items-center justify-between rounded-lg bg-surface-container-low px-3 py-2.5 text-xs"
        >
          <div class="flex items-center gap-2 text-on-surface-variant">
            <span class="material-symbols-outlined text-base text-primary">info</span>
            <span>
              默认凭据:
              <strong class="select-all font-mono text-primary">admin</strong> /
              <strong class="select-all font-mono text-primary">admin123</strong>
            </span>
          </div>
          <button
            type="button"
            class="rounded bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary transition-colors hover:underline"
            @click="fillDefaults"
          >
            一键填入
          </button>
        </div>

        <!-- 错误提示 -->
        <div
          v-if="error"
          class="mb-5 flex items-center gap-2.5 rounded-lg bg-error-container/40 px-3 py-2.5 text-xs text-on-error-container"
        >
          <span class="material-symbols-outlined text-base text-error">cancel</span>
          <span>{{ error }}</span>
        </div>

        <!-- 登录表单 -->
        <form v-if="mode === 'login'" class="flex flex-col gap-4" @submit.prevent="handleLogin">
          <div class="flex flex-col gap-1.5">
            <label class="flex items-center justify-between text-xs font-medium text-on-surface-variant">
              <span>同步节点服务器 (Server Node)</span>
            </label>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">dns</span>
              <input
                v-model="loginForm.serverUrl"
                type="url"
                required
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-on-surface-variant">管理员账号 (Username)</label>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">account_circle</span>
              <input
                v-model="loginForm.username"
                type="text"
                required
                placeholder="请输入用户名"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-medium text-on-surface-variant">访问密码 (Password)</label>
            </div>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">key</span>
              <input
                v-model="loginForm.password"
                :type="showLoginPassword ? 'text' : 'password'"
                required
                placeholder="••••••••"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-10 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
              <button
                type="button"
                class="absolute right-3 flex items-center justify-center text-on-surface-variant transition-colors hover:text-on-surface"
                @click="showLoginPassword = !showLoginPassword"
              >
                <span class="material-symbols-outlined text-lg">
                  {{ showLoginPassword ? 'visibility_off' : 'visibility' }}
                </span>
              </button>
            </div>
          </div>

          <Button
            type="submit"
            size="lg"
            class="mt-2 w-full"
            :disabled="loginLoading"
          >
            <span
              v-if="loginLoading"
              class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
            />
            <span v-else class="material-symbols-outlined text-lg">verified_user</span>
            <span>{{ loginLoading ? '正在握手认证...' : '登 录 管 理 面 板' }}</span>
          </Button>
        </form>

        <!-- 注册表单 -->
        <form
          v-else
          class="flex flex-col gap-4"
          :class="{ 'pointer-events-none opacity-50': !allowRegister }"
          @submit.prevent="handleRegister"
        >
          <div class="flex flex-col gap-1.5">
            <label class="flex items-center justify-between text-xs font-medium text-on-surface-variant">
              <span>注册目标节点</span>
            </label>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">hub</span>
              <input
                v-model="regForm.serverUrl"
                type="url"
                required
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-medium text-on-surface-variant">新用户名</label>
              <span class="text-[11px]" :class="usernameHint.cls">{{ usernameHint.text }}</span>
            </div>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">badge</span>
              <input
                v-model="regForm.username"
                type="text"
                minlength="3"
                required
                placeholder="设置用户名 (如: dev_master)"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-4 text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-medium text-on-surface-variant">账户主密码</label>
              <span class="text-[11px]" :class="passwordHint.cls">{{ passwordHint.text }}</span>
            </div>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">lock</span>
              <input
                v-model="regForm.password"
                :type="showRegPassword ? 'text' : 'password'"
                minlength="6"
                required
                placeholder="建议包含大小写字母与数字"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-10 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
              <button
                type="button"
                class="absolute right-3 flex items-center justify-center text-on-surface-variant transition-colors hover:text-on-surface"
                @click="showRegPassword = !showRegPassword"
              >
                <span class="material-symbols-outlined text-lg">
                  {{ showRegPassword ? 'visibility_off' : 'visibility' }}
                </span>
              </button>
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-medium text-on-surface-variant">确认主密码</label>
              <span class="font-mono text-[11px]" :class="matchStatus.cls">{{ matchStatus.text }}</span>
            </div>
            <div class="relative flex items-center">
              <span class="material-symbols-outlined pointer-events-none absolute left-3 text-lg text-on-surface-variant">shield</span>
              <input
                v-model="regForm.confirmPassword"
                type="password"
                minlength="6"
                required
                placeholder="再次输入密码"
                class="w-full rounded-lg bg-surface-container py-2.5 pl-10 pr-10 font-mono text-sm text-on-surface transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:outline-none focus:ring-1 focus:ring-primary"
              />
              <span
                v-if="matchStatus.icon"
                class="material-symbols-outlined absolute right-3 text-lg"
                :class="matchStatus.cls"
              >
                {{ matchStatus.icon }}
              </span>
            </div>
          </div>

          <Button
            type="submit"
            variant="tertiary"
            size="lg"
            class="mt-2 w-full"
            :disabled="regLoading || !allowRegister"
          >
            <span
              v-if="regLoading"
              class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
            />
            <span v-else class="material-symbols-outlined text-lg">person_add_alt</span>
            <span>{{ regLoading ? '生成密钥对与初始化...' : '完 成 注 册 并 初 始 化' }}</span>
          </Button>

          <p v-if="!allowRegister" class="text-center text-xs text-error">
            注册功能已关闭，请联系管理员
          </p>
        </form>

        <!-- 底部留白 -->
      </div>
    </div>
  </main>
</template>
