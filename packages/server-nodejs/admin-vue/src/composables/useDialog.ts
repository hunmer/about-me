import { reactive } from 'vue'

export type DialogType = 'warning' | 'error' | 'info'

export interface DialogOptions {
  title: string
  content: string
  type?: DialogType
  positiveText?: string
  negativeText?: string
  onPositiveClick?: () => void | Promise<void>
}

interface DialogState extends DialogOptions {
  show: boolean
  positiveText: string
  negativeText: string
  type: DialogType
  confirming: boolean
}

const state = reactive<DialogState>({
  show: false,
  title: '',
  content: '',
  type: 'warning',
  positiveText: '确认',
  negativeText: '取消',
  confirming: false,
  onPositiveClick: undefined
})

function open(options: DialogOptions): void {
  Object.assign(state, {
    show: true,
    confirming: false,
    title: options.title,
    content: options.content,
    type: options.type ?? 'warning',
    positiveText: options.positiveText ?? '确认',
    negativeText: options.negativeText ?? '取消',
    onPositiveClick: options.onPositiveClick
  })
}

export interface DialogApi {
  warning: (options: DialogOptions) => void
  error: (options: DialogOptions) => void
  info: (options: DialogOptions) => void
}

/**
 * 兼容 naive-ui useDialog 的确认弹窗 API（Glacier 玻璃风格）
 */
export function useDialog(): DialogApi {
  return {
    warning: open,
    error: options => open({ ...options, type: 'error' }),
    info: options => open({ ...options, type: 'info' })
  }
}

async function confirm(): Promise<void> {
  if (state.confirming) return
  state.confirming = true
  try {
    await state.onPositiveClick?.()
  } finally {
    state.confirming = false
    state.show = false
  }
}

function cancel(): void {
  state.show = false
}

export { state as dialogState, confirm as confirmDialog, cancel as cancelDialog }
