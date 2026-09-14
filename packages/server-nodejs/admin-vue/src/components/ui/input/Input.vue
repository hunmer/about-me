<script setup lang="ts">
import type { HTMLAttributes } from 'vue'
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
}>()

const model = defineModel<string | number>({ default: '' })
</script>

<template>
  <input
    v-model="model"
    :class="
      cn(
        'w-full rounded-lg bg-surface-container px-3.5 py-2.5 text-sm text-on-surface outline-none transition-all placeholder:text-on-surface-variant/40 focus:bg-surface-bright focus:ring-1 focus:ring-primary disabled:cursor-not-allowed disabled:opacity-50',
        props.class
      )
    "
  />
</template>
