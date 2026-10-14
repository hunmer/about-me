<script setup lang="ts">
import { computed, type HTMLAttributes } from 'vue'
import { DialogTitle, type DialogTitleProps } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
} & DialogTitleProps>()

const delegatedProps = computed(() => {
  const { class: _, ...delegated } = props
  return delegated as DialogTitleProps
})
</script>

<template>
  <DialogTitle
    v-bind="delegatedProps"
    :class="cn('text-base font-bold tracking-tight text-on-surface', props.class)"
  >
    <slot />
  </DialogTitle>
</template>
