<script setup lang="ts">
import { dismiss, toasts } from '@/composables/useMessage'

const iconMap: Record<string, string> = {
  success: 'check_circle',
  error: 'cancel',
  warning: 'warning',
  info: 'info'
}

const colorMap: Record<string, string> = {
  success: 'text-primary',
  error: 'text-error',
  warning: 'text-tertiary',
  info: 'text-secondary'
}
</script>

<template>
  <div
    class="pointer-events-none fixed bottom-8 right-8 z-[70] flex w-80 flex-col gap-2.5"
  >
    <TransitionGroup
      enter-active-class="transition-all duration-200"
      enter-from-class="translate-y-3 opacity-0"
      enter-to-class="translate-y-0 opacity-100"
      leave-active-class="transition-all duration-200"
      leave-from-class="opacity-100"
      leave-to-class="translate-y-3 opacity-0"
    >
      <div
        v-for="toast in toasts"
        :key="toast.id"
        class="pointer-events-auto flex items-center gap-3 rounded-xl bg-surface-variant/95 px-4 py-3 shadow-[0_10px_30px_rgba(0,0,0,0.5)] backdrop-blur-xl"
      >
        <span
          class="material-symbols-outlined text-lg"
          :class="colorMap[toast.type]"
        >
          {{ iconMap[toast.type] }}
        </span>
        <span class="flex-1 text-xs text-on-surface">{{ toast.message }}</span>
        <button
          class="text-on-surface-variant transition-colors hover:text-on-surface"
          @click="dismiss(toast.id)"
        >
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>
