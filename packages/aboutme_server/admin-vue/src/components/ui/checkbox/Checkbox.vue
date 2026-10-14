<script setup lang="ts">
import { computed, type HTMLAttributes } from 'vue'
import {
  CheckboxRoot,
  type CheckboxRootEmits,
  type CheckboxRootProps,
  CheckboxIndicator
} from 'reka-ui'
// reka-ui v2 使用 modelValue 而非 checked
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
} & CheckboxRootProps>()

const emits = defineEmits<CheckboxRootEmits>()

const delegatedProps = computed(() => {
  const { class: _, ...delegated } = props
  return delegated as CheckboxRootProps
})
</script>

<template>
  <CheckboxRoot
    v-bind="delegatedProps"
    :class="
      cn(
        'flex h-4 w-4 shrink-0 cursor-pointer items-center justify-center rounded border border-outline/70 bg-surface-container transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[state=indeterminate]:border-primary data-[state=indeterminate]:bg-primary focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-primary/60',
        props.class
      )
    "
    @update:model-value="emits('update:modelValue', $event)"
  >
    <CheckboxIndicator
      class="flex items-center justify-center text-on-primary"
    >
      <svg
        v-if="delegatedProps.modelValue === 'indeterminate'"
        class="h-3 w-3"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="3.5"
        stroke-linecap="round"
      >
        <path d="M5 12h14" />
      </svg>
      <svg
        v-else
        class="h-3 w-3"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="3.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M20 6 9 17l-5-5" />
      </svg>
    </CheckboxIndicator>
  </CheckboxRoot>
</template>
