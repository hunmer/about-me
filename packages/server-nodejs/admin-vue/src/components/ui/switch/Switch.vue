<script setup lang="ts">
import { computed, type HTMLAttributes } from 'vue'
import { SwitchRoot, type SwitchRootEmits, type SwitchRootProps, SwitchThumb } from 'reka-ui'
// reka-ui v2 使用 modelValue 而非 value
import { cn } from '@/lib/utils'

const props = defineProps<{
  class?: HTMLAttributes['class']
} & SwitchRootProps>()

const emits = defineEmits<SwitchRootEmits>()

const delegatedProps = computed(() => {
  const { class: _, ...delegated } = props
  return delegated as SwitchRootProps
})
</script>

<template>
  <SwitchRoot
    v-bind="delegatedProps"
    :class="
      cn(
        'relative inline-flex h-7 w-12 shrink-0 cursor-pointer items-center rounded-full border border-outline-variant/50 transition-colors duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40 focus-visible:ring-offset-2 focus-visible:ring-offset-surface data-[state=checked]:bg-primary data-[state=unchecked]:bg-surface-container-highest',
        props.class
      )
    "
    @update:model-value="emits('update:modelValue', $event)"
  >
    <SwitchThumb
      class="pointer-events-none block h-5 w-5 translate-x-1 rounded-full bg-on-surface shadow-md transition-transform duration-300 data-[state=checked]:translate-x-6 data-[state=checked]:bg-on-primary"
    />
  </SwitchRoot>
</template>
