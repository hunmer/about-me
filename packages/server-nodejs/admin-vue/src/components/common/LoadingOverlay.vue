<script setup lang="ts">
import { useUIStore } from '@/stores/ui'

const uiStore = useUIStore()
</script>

<template>
  <Transition
    enter-active-class="transition-opacity duration-200"
    enter-from-class="opacity-0"
    leave-active-class="transition-opacity duration-200"
    leave-to-class="opacity-0"
  >
    <div
      v-if="uiStore.loading"
      class="fixed inset-0 z-[80] flex items-center justify-center bg-background/70 backdrop-blur-sm"
    >
      <div
        class="flex flex-col items-center gap-4 rounded-2xl bg-surface-container/90 px-10 py-8 shadow-2xl backdrop-blur-2xl"
      >
        <div class="relative flex h-10 w-10 items-center justify-center">
          <span
            class="absolute inset-0 rounded-full bg-primary/20 blur-md"
          />
          <span
            class="h-8 w-8 animate-spin rounded-full border-2 border-primary/30 border-t-primary"
          />
        </div>
        <span class="text-xs font-mono text-on-surface-variant">
          {{ uiStore.loadingMessage || '处理中...' }}
        </span>
      </div>
    </div>
  </Transition>
</template>
