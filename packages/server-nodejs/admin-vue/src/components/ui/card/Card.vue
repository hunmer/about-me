<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
}>()
</script>

<template>
  <div
    :class="
      cn(
        'relative rounded-xl bg-surface-container/60 shadow-lg backdrop-blur-xl',
        props.class
      )
    "
  >
    <slot />
  </div>
</template>
