<script setup lang="ts">
import ApiControl from './ApiControl.vue'
import DataOperations from './DataOperations.vue'
</script>

<template>
  <div class="flex w-full flex-col">
    <!-- 头部上下文 -->
    <div class="mb-10">
      <h1 class="text-3xl font-bold tracking-tight text-on-surface">系统核心设置</h1>
    </div>

    <!-- 双模块布局 -->
    <div class="grid grid-cols-1 items-start gap-8 lg:grid-cols-12">
      <section class="flex flex-col gap-6 lg:col-span-7">
        <ApiControl />
      </section>
      <section class="flex flex-col gap-6 lg:col-span-5">
        <DataOperations />
      </section>
    </div>
  </div>
</template>
