#!/usr/bin/env node
/**
 * 从 models.dev 拉取最新模型数据，重新生成 lib/plugins/openai/models/llm_models.dart
 * 的内置模型列表（llmModelGroup部分），并保留 models.dev 无对应的本地自定义组。
 *
 * 用法:
 *   node scripts/update_llm_models.mjs                # 在线拉取并写入
 *   node scripts/update_llm_models.mjs --dry-run      # 只打印结果不写文件
 *   node scripts/update_llm_models.mjs --input a.json # 用本地 api.json（离线调试）
 *
 * 规则（须与 ModelController.fetchRemoteModelGroups 保持一致）:
 *   - provider id 经 providerGroupAlias 映射为本地组 id（zhipuai→zhipu 等）
 *   - 跳过 status=deprecated 与非对话类模型（type 不为 chat/undefined）
 *   - supportsVision: modalities.input 含 image，旧字段 fallback attachment
 *   - 按 release_date 降序（fallback last_updated）取每组前 cap 个
 *   - 远端无数据的本地组（如 qwen/xfyun/perplexity/other）整组保留原文
 *
 * 写入后建议执行: dart format lib/plugins/openai/models/llm_models.dart
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const targetFile = resolve(rootDir, 'lib/plugins/openai/models/llm_models.dart');
const REMOTE_URL = 'https://models.dev/api.json';
// llm_models.dart 中内置列表区的起始锚点注释（锚点之前为类定义区，脚本不动）
const LIST_ANCHOR = '// 预定义的大模型列表';

// 与 ModelController._providerGroupAlias 保持一致
const providerGroupAlias = {
  zhipuai: 'zhipu',
  moonshotai: 'moonshot',
  'moonshotai-cn': 'moonshot',
  'alibaba': 'alibaba-qwen',
  'alibaba-cn': 'alibaba-qwen',
};

// 各远端组收录上限（按 release_date 最新优先）；本地有但此处未列的组不会被更新
const capsByGroup = {
  deepseek: 8,
  meta: 8,
  mistral: 12,
  openai: 16,
  anthropic: 14,
  google: 14,
  zhipu: 14,
  moonshot: 10,
  cohere: 10,
  'alibaba-qwen': 16,
  xai: 8,
  minimax: 8,
};

// ---------- CLI ----------
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const inputIdx = args.indexOf('--input');
const inputFile = inputIdx !== -1 ? args[inputIdx + 1] : null;

// ---------- 远端数据 ----------
async function fetchApiJson() {
  if (inputFile) {
    return JSON.parse(readFileSync(resolve(rootDir, inputFile), 'utf8'));
  }
  const res = await fetch(REMOTE_URL);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// 解析单个 provider 的模型列表（过滤 + 提取能力字段 + 按发布日期排序）
function parseProvider(provider) {
  const models = [];
  for (const [id, m] of Object.entries(provider.models ?? {})) {
    if (m.status === 'deprecated') continue;
    if (m.type && m.type !== 'chat') continue;
    const input = m.modalities?.input;
    models.push({
      id,
      name: m.name ?? id,
      supportsVision: Array.isArray(input)
        ? input.includes('image')
        : (m.attachment ?? null),
      supportsReasoning: m.reasoning ?? null,
      contextLimit: m.limit?.context ?? null,
      maxOutput: m.limit?.output ?? null,
      date: m.release_date ?? m.last_updated ?? '',
    });
  }
  models.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
  return models;
}

// ---------- 现有 dart 文件解析 ----------
function parseExistingGroups(src) {
  const anchor = src.indexOf(LIST_ANCHOR);
  if (anchor === -1) throw new Error(`未找到锚点注释: ${LIST_ANCHOR}`);
  const head = src.slice(0, anchor);
  const listStart = src.indexOf('final llmModelGroups = [', anchor);
  const listEnd = src.lastIndexOf('];');
  const body = src.slice(listStart, listEnd);

  const groups = []; // {id, name, block}，保持文件顺序
  for (const block of body.split(/(?=^  LLMModelGroup\()/m)) {
    const id = block.match(/^ {4}id: '([^']+)'/m)?.[1];
    if (!id) continue;
    const name = block.match(/^ {4}name: '([^']+)'/m)?.[1] ?? id;
    groups.push({ id, name, block: block.trimEnd() });
  }
  if (!groups.length) throw new Error('未能从现有文件解析出 LLMModelGroup');
  return { head, groups };
}

// ---------- dart 代码生成 ----------
const q = (s) => `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
const boolLit = (v) => (v ? 'true' : 'false');

function genGroupBlock(group, models) {
  const lines = [
    '  LLMModelGroup(',
    `    id: ${q(group.id)},`,
    `    name: ${q(group.name)},`,
    '    models: [',
  ];
  for (const m of models) {
    lines.push(
      '      LLMModel(',
      `        id: ${q(m.id)},`,
      `        name: ${q(m.name)},`,
      `        group: ${q(group.id)},`,
    );
    if (m.supportsVision != null)
      lines.push(`        supportsVision: ${boolLit(m.supportsVision)},`);
    if (m.supportsReasoning != null)
      lines.push(`        supportsReasoning: ${boolLit(m.supportsReasoning)},`);
    if (m.contextLimit != null) lines.push(`        contextLimit: ${m.contextLimit},`);
    if (m.maxOutput != null) lines.push(`        maxOutput: ${m.maxOutput},`);
    lines.push('      ),');
  }
  lines.push('    ],', '  ),');
  return lines.join('\n');
}

// ---------- 主流程 ----------
async function main() {
  console.log(`拉取 ${inputFile ? inputFile : REMOTE_URL} ...`);
  const api = await fetchApiJson();

  // 远端组按本地组 id 聚合（多个 provider 可能映射到同一组，如 alibaba/-cn）
  const remoteByGroup = {};
  for (const [pid, provider] of Object.entries(api)) {
    const gid = providerGroupAlias[pid] ?? pid;
    const models = parseProvider(provider);
    if (!models.length) continue;
    (remoteByGroup[gid] ??= []).push(...models);
  }

  const { head, groups } = parseExistingGroups(readFileSync(targetFile, 'utf8'));

  const blocks = [];
  const stats = { updated: [], kept: [] };
  for (const group of groups) {
    const remoteModels = remoteByGroup[group.id];
    const cap = capsByGroup[group.id];
    if (remoteModels && cap) {
      remoteModels.sort((a, b) => (b.date || '').localeCompare(a.date || ''));
      const picked = remoteModels.slice(0, cap);
      blocks.push(genGroupBlock(group, picked));
      stats.updated.push(`${group.id}(${picked.length})`);
    } else {
      blocks.push(group.block);
      stats.kept.push(group.id);
    }
  }

  const result =
    head +
    `${LIST_ANCHOR}（数据来源: https://models.dev，按 release_date 取各组最新模型）\n` +
    '// 本地自定义组（models.dev 无对应数据）自动保留原文\n' +
    'final llmModelGroups = [\n' +
    blocks.join('\n') +
    '\n];\n';

  if (dryRun) {
    console.log('[dry-run] 更新组:', stats.updated.join(', ') || '无');
    console.log('[dry-run] 保留组:', stats.kept.join(', ') || '无');
    console.log('[dry-run] 未写入文件');
    return;
  }

  writeFileSync(targetFile, result);
  console.log(`已写入 ${targetFile}`);
  console.log('更新组:', stats.updated.join(', ') || '无');
  console.log('保留组:', stats.kept.join(', ') || '无');
  console.log('提示: 执行 dart format lib/plugins/openai/models/llm_models.dart 后提交');
}

main().catch((e) => {
  console.error('失败:', e.message);
  process.exit(1);
});
