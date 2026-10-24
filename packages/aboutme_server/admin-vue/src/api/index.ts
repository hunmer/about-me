import type { ApiResponse, LoginRequest, LoginResponse, UserInfoResponse, DevicesListResponse, RegisterDeviceRequest, RegisterDeviceResponse, PushMessageRequest, PushMessageResponse } from './types'

// 优先级: localStorage > 环境变量 > 默认值
const ENV_SERVER = import.meta.env.VITE_API_BASE_URL || ''
const DEFAULT_SERVER = 'http://localhost:8874'

// API 客户端类
class ApiClient {
  private _baseUrl: string = ''
  private _token: string | null = null

  constructor() {
    // 优先使用 localStorage（用户手动配置），其次环境变量，最后默认值
    const storedUrl = localStorage.getItem('serverUrl')
    this._baseUrl = storedUrl || ENV_SERVER || DEFAULT_SERVER
    this._token = localStorage.getItem('token')
  }

  setBaseUrl(url: string): void {
    this._baseUrl = url
    localStorage.setItem('serverUrl', url)
  }

  getBaseUrl(): string {
    return this._baseUrl
  }

  setToken(token: string | null): void {
    this._token = token
    if (token) {
      localStorage.setItem('token', token)
    } else {
      localStorage.removeItem('token')
    }
  }

  getToken(): string | null {
    return this._token
  }

  async request<T>(
    endpoint: string,
    options: RequestInit = {},
    extraHeaders: Record<string, string> = {}
  ): Promise<T> {
    const url = `${this._baseUrl}${endpoint}`

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...extraHeaders
    }

    if (this._token) {
      headers['Authorization'] = `Bearer ${this._token}`
    }

    const response = await fetch(url, {
      ...options,
      headers
    })

    // 处理 401 认证错误
    if (response.status === 401) {
      this.setToken(null)
      localStorage.removeItem('username')
      throw new Error('登录已过期，请重新登录')
    }

    // 处理 403 错误 - 仅对特定端点清除登录状态
    if (response.status === 403) {
      const errorData = await response.json().catch(() => ({}))
      // 如果是密钥验证相关错误，不清除登录状态
      if (errorData.error?.includes('密钥') || endpoint.includes('encryption-key')) {
        throw new Error(errorData.error || '权限不足')
      }
      this.setToken(null)
      localStorage.removeItem('username')
      throw new Error('登录已过期，请重新登录')
    }

    // 已迁移业务域的原始文件写入被服务端以 426 拒绝，标记给 UI 展示升级引导
    if (response.status === 426) {
      const errorData = await response.json().catch(() => ({}))
      const error = new Error(errorData.error || UPGRADE_REQUIRED_MESSAGE)
      ;(error as Error & { status?: number; code?: string }).status = 426
      ;(error as Error & { status?: number; code?: string }).code =
        errorData.code || 'UPGRADE_REQUIRED'
      throw error
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(errorData.error || `HTTP Error: ${response.status}`)
    }

    return response.json()
  }

  async healthCheck(): Promise<boolean> {
    try {
      const response = await fetch(`${this._baseUrl}/health`)
      return response.ok
    } catch {
      return false
    }
  }

  async downloadFile(url: string): Promise<Blob> {
    const headers: Record<string, string> = {}
    if (this._token) {
      headers['Authorization'] = `Bearer ${this._token}`
    }

    const response = await fetch(url, { headers })

    if (!response.ok) {
      throw new Error('下载失败')
    }

    return response.blob()
  }
}

// 单例实例
export const apiClient = new ApiClient()

// 类型定义
interface ApiKeyInfo {
  id: string
  name: string
  key_prefix: string
  expires_at?: string
  last_used_at?: string
  is_expired: boolean
  created_at: string
}

interface CreatedApiKeyInfo {
  id: string
  name: string
  key: string
  key_prefix: string
  expires_at?: string
}

interface SyncFileInfo {
  path: string
  size: number
  updated_at: string
  is_folder?: boolean
  is_binary?: boolean
  md5?: string
}

// 认证 API
export const authApi = {
  login: (data: LoginRequest): Promise<LoginResponse> =>
    apiClient.request('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  getRegisterStatus: (): Promise<{ success: boolean; allow_register: boolean }> =>
    apiClient.request('/api/v1/auth/register-status'),

  register: (data: LoginRequest): Promise<LoginResponse> =>
    apiClient.request('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  // 获取密钥验证文件（加密的，由客户端本地解密验证）
  getKeyVerification: (): Promise<{
    success: boolean
    exists: boolean
    encrypted_data?: string
    md5?: string
    updated_at?: string
  }> => apiClient.request('/api/v1/auth/key-verification'),

  getApiKeys: (): Promise<{ success: boolean; api_keys?: ApiKeyInfo[] }> =>
    apiClient.request('/api/v1/auth/api-keys'),

  createApiKey: (data: {
    name: string
    expiry: 'never' | '7days' | '30days' | '90days' | '1year'
  }): Promise<{ success: boolean; api_key?: CreatedApiKeyInfo; error?: string }> =>
    apiClient.request('/api/v1/auth/api-keys', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  revokeApiKey: (keyId: string): Promise<ApiResponse> =>
    apiClient.request(`/api/v1/auth/api-keys/${keyId}`, {
      method: 'DELETE'
    }),

  getUserInfo: (): Promise<UserInfoResponse> =>
    apiClient.request('/api/v1/auth/user-info'),

  // API 访问控制
  getApiAccessStatus: (): Promise<{ success: boolean; enabled: boolean }> =>
    apiClient.request('/api/v1/auth/api-access'),

  setApiAccessStatus: (enabled: boolean): Promise<{ success: boolean; enabled: boolean; message: string }> =>
    apiClient.request('/api/v1/auth/api-access', {
      method: 'PUT',
      body: JSON.stringify({ enabled })
    }),

  // 验证加密密钥
  verifyEncryptionKey: (key: string): Promise<{ success: boolean; valid: boolean; error?: string }> =>
    apiClient.request('/api/v1/auth/verify-encryption-key', {
      method: 'POST',
      body: JSON.stringify({ key })
    })
}

// 设备管理 API
export const devicesApi = {
  getDevices: (): Promise<DevicesListResponse> =>
    apiClient.request('/api/v1/auth/devices'),

  registerDevice: (data: RegisterDeviceRequest): Promise<RegisterDeviceResponse> =>
    apiClient.request('/api/v1/auth/devices', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  deleteDevice: (deviceId: string): Promise<{ success: boolean; message: string; device_id: string }> =>
    apiClient.request(`/api/v1/auth/devices/${deviceId}`, {
      method: 'DELETE'
    }),

  pushMessage: (data: PushMessageRequest): Promise<PushMessageResponse> =>
    apiClient.request('/api/v1/auth/devices/push', {
      method: 'POST',
      body: JSON.stringify(data)
    })
}

// 按路径段编码，保留目录分隔符，与存储 SDK 的路径规则一致。
function encodeStoragePath(filePath: string): string {
  return filePath.replace(/\\/g, '/').split('/').map(encodeURIComponent).join('/')
}

// 同步 API
export const syncApi = {
  getFiles: (directory?: string): Promise<{ success: boolean; files: SyncFileInfo[] }> => {
    const params = directory ? `?prefix=${encodeURIComponent(directory)}` : ''
    // 服务端 /storage/files 返回 { path, size, updated_at } 数组，转换为前端结构
    return apiClient.request<{ files: { path: string; size: number; updated_at: string }[] }>(`/api/v1/storage/files${params}`).then(response => ({
      success: true,
      files: (response.files || []).map(f => ({
        path: f.path,
        size: f.size,
        updated_at: f.updated_at,
        is_folder: false
      }))
    }))
  },

  getStatus: (): Promise<{
    success: boolean
    user_id: string
    file_count: number
    total_size_bytes: number
    total_size_mb: string
    timestamp: string
  }> => apiClient.request('/api/v1/storage/files').then(response => ({
    success: true, user_id: '', file_count: (response as { files: unknown[] }).files.length,
    total_size_bytes: 0, total_size_mb: '0.00', timestamp: new Date().toISOString()
  })),

  deleteFile: (filePath: string): Promise<ApiResponse> =>
    apiClient.request(`/api/v1/storage/files/${encodeStoragePath(filePath)}`, {
      method: 'DELETE', headers: { 'X-Force-Overwrite': 'true' }
    }),

  // 下载原始文件，保留文件内容与格式
  downloadFile: async (filePath: string): Promise<Blob> => {
    const url = `${apiClient.getBaseUrl()}/api/v1/storage/files/${encodeStoragePath(filePath)}`
    const headers: Record<string, string> = {}
    const token = apiClient.getToken()
    if (token) {
      headers['Authorization'] = `Bearer ${token}`
    }

    const response = await fetch(url, { headers })

    if (response.status === 401 || response.status === 403) {
      apiClient.setToken(null)
      localStorage.removeItem('username')
      throw new Error('登录已过期，请重新登录')
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(errorData.error || `HTTP Error: ${response.status}`)
    }

    return response.blob()
  },

  exportData: (): Promise<{
    success: boolean
    file_name?: string
    metadata?: { file_count: number; total_size_mb: string }
    error?: string
  }> =>
    apiClient.request('/api/v1/storage/files', {
      method: 'POST'
    }),

  getDownloadUrl: (fileName: string): string =>
    `${apiClient.getBaseUrl()}/api/v1/storage/files/${encodeStoragePath(fileName)}`,

  downloadExportFile: (fileName: string): Promise<Blob> =>
    apiClient.downloadFile(syncApi.getDownloadUrl(fileName))
}


// ==== 已迁移业务域引导（P4）====
export const UPGRADE_REQUIRED_MESSAGE =
  '该路径属于已迁移的业务数据域，原始文件写入已禁用（HTTP 426）。请升级客户端 App，通过新版客户端（SDK 业务命令）管理这些数据；管理后台仅提供只读浏览。'

export function isUpgradeRequiredError(err: unknown): boolean {
  const e = err as { status?: number; code?: string }
  return e?.status === 426 || e?.code === 'UPGRADE_REQUIRED'
}

// 已迁移业务域清单（来自服务端 capabilities，失败时退回空表仅靠 426 兜底）
let migratedDomainsCache: string[] | null = null
export async function fetchMigratedDomains(): Promise<string[]> {
  if (migratedDomainsCache) return migratedDomainsCache
  try {
    const caps = await apiClient.request<{ migratedDomains?: string[] }>(
      '/api/v1/plugins/capabilities'
    )
    migratedDomainsCache = caps.migratedDomains || []
  } catch {
    migratedDomainsCache = []
  }
  return migratedDomainsCache
}

// 非域类的原始写保护前缀（configs 设置统一通道 / assets 资源系统等）
let protectedPrefixesCache: string[] | null = null
export async function fetchProtectedPrefixes(): Promise<string[]> {
  if (protectedPrefixesCache) return protectedPrefixesCache
  try {
    const caps = await apiClient.request<{ protectedPrefixes?: string[] }>(
      '/api/v1/plugins/capabilities'
    )
    protectedPrefixesCache = caps.protectedPrefixes || []
  } catch {
    protectedPrefixesCache = []
  }
  return protectedPrefixesCache
}

// 路径是否落在已迁移业务域前缀下（如 'diary/...' / 'agent_chat/...'）
export function isMigratedPath(path: string, domains: string[]): boolean {
  const first = path.replace(/^\/+/, '').split('/')[0]?.toLowerCase()
  return !!first && domains.includes(first)
}

// 路径是否落在保护前缀下（支持目录前缀与精确文件，如 'configs/...'、
// 'stickers/collections.json'；旧服务端未上报时 prefixes 为空表自动跳过）
export function isProtectedPath(path: string, prefixes: string[]): boolean {
  const normalized = path.replace(/^\/+/, '').toLowerCase()
  if (!normalized) return false
  return prefixes.some(
    (prefix) =>
      normalized === prefix.toLowerCase() ||
      normalized.startsWith(`${prefix.toLowerCase()}/`)
  )
}
