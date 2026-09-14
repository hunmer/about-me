<script setup lang="ts">
import { computed, type HTMLAttributes } from 'vue'
import {
  DialogPortal,
  DialogOverlay,
  DialogContent,
  DialogClose,
  type DialogContentEmits,
  type DialogContentProps
} from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
  hideClose?: boolean
} & DialogContentProps>()

const emits = defineEmits<DialogContentEmits>()

const delegatedProps = computed(() => {
  const { class: _, hideClose: __, ...delegated } = props
  return delegated as DialogContentProps
})
</script>

<template>
  <DialogPortal>
    <DialogOverlay
      class="fixed inset-0 z-50 bg-background/80 backdrop-blur-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"
    />
    <DialogContent
      v-bind="delegatedProps"
      :class="
        cn(
          'fixed left-1/2 top-1/2 z-50 grid w-full max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 rounded-2xl bg-surface-container/95 p-6 shadow-[0_0_50px_rgba(0,0,0,0.6)] backdrop-blur-2xl duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95',
          props.class
        )
      "
    >
      <slot />
      <DialogClose
        v-if="!hideClose"
        class="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-lg text-on-surface-variant transition-colors hover:bg-surface-variant hover:text-on-surface focus:outline-none"
      >
        <span class="material-symbols-outlined text-lg">close</span>
        <span class="sr-only">关闭</span>
      </DialogClose>
    </DialogContent>
  </DialogPortal>
</template>
