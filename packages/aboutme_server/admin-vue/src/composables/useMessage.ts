import { reactive } from 'vue'

export type MessageType = 'success' | 'error' | 'warning' | 'info'

export interface ToastItem {
  id: number
  type: MessageType
  message: string
  leaving: boolean
}

const toasts = reactive<ToastItem[]>([])
let uid = 0

function dismiss(id: number): void {
  const index = toasts.findIndex(t => t.id === id)
  if (index === -1) return
  toasts[index].leaving = true
  // 等待离场动画结束后移除
  setTimeout(() => {
    const i = toasts.findIndex(t => t.id === id)
    if (i > -1) toasts.splice(i, 1)
  }, 200)
}

function push(type: MessageType, message: string): void {
  const id = ++uid
  toasts.push({ id, type, message, leaving: false })
  setTimeout(() => dismiss(id), 3200)
}

export interface MessageApi {
  success: (message: string) => void
  error: (message: string) => void
  warning: (message: string) => void
  info: (message: string) => void
}

/**
 * 兼容 naive-ui useMessage 的轻量 toast API（Glacier 玻璃风格）
 */
export function useMessage(): MessageApi {
  return {
    success: m => push('success', m),
    error: m => push('error', m),
    warning: m => push('warning', m),
    info: m => push('info', m)
  }
}

export { toasts, dismiss }
