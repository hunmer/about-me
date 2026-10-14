<script setup lang="ts">
import { computed, type HTMLAttributes } from 'vue'
import { DialogDescription, type DialogDescriptionProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
} & DialogDescriptionProps>()

const delegatedProps = computed(() => {
  const { class: _, ...delegated } = props
  return delegated as DialogDescriptionProps
})
</script>

<template>
  <DialogDescription
    v-bind="delegatedProps"
    :class="cn('text-xs text-on-surface-variant', props.class)"
  >
    <slot />
  </DialogDescription>
</template>
