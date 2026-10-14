<script setup lang="ts">
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { cancelDialog, confirmDialog, dialogState } from '@/composables/useDialog'

const iconMap: Record<string, string> = {
  warning: 'warning',
  error: 'delete_forever',
  info: 'info'
}

const colorMap: Record<string, string> = {
  warning: 'bg-tertiary-container/40 text-tertiary',
  error: 'bg-error-container/40 text-error',
  info: 'bg-primary/15 text-primary'
}
</script>

<template>
  <Dialog
    :open="dialogState.show"
    @update:open="(v: boolean) => !v && cancelDialog()"
  >
    <DialogContent hide-close class="max-w-md">
      <DialogHeader class="flex-row items-center gap-3 space-y-0">
        <div
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl"
          :class="colorMap[dialogState.type]"
        >
          <span class="material-symbols-outlined text-xl">
            {{ iconMap[dialogState.type] }}
          </span>
        </div>
        <div>
          <DialogTitle>{{ dialogState.title }}</DialogTitle>
          <DialogDescription class="mt-0.5">
            {{ dialogState.content }}
          </DialogDescription>
        </div>
      </DialogHeader>
      <DialogFooter class="mt-2 gap-2.5">
        <Button variant="ghost" size="sm" @click="cancelDialog()">
          {{ dialogState.negativeText }}
        </Button>
        <Button
          size="sm"
          :variant="dialogState.type === 'error' ? 'destructive' : 'default'"
          :disabled="dialogState.confirming"
          @click="confirmDialog()"
        >
          <span
            v-if="dialogState.confirming"
            class="h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-t-transparent"
          />
          {{ dialogState.positiveText }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
