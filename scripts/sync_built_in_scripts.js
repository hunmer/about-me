#!/usr/bin/env node
/**
 * 内置脚本同步命令：online/scripts/{id} → assets/scripts/{id}
 *
 * 用法:
 *   node scripts/sync_built_in_scripts.js            # 同步下面列表中的全部内置脚本
 *   node scripts/sync_built_in_scripts.js ai_image   # 只同步指定 id
 *
 * 行为:
 *   1. 比较 online 与 assets 的实质内容（metadata 剔除 version/builtIn 后比较 + script.js 全文）
 *   2. 有差异时自动升 patch 版本（如 1.3.2 → 1.3.3），保证应用启动时内置脚本升级机制能推送
 *   3. 整体同步 metadata.json（加 builtIn: true）与 script.js 到 assets —— 杜绝部分同步
 *   4. 重算 online/scripts/{id}/files.json 校验值
 *   5. 输出一致性校验结果
 *
 * 注意: 新增内置脚本时，需同步维护 lib/plugins/scripts_center/services/script_loader.dart
 *       的 builtInScriptIds 常量，以及 pubspec.yaml 的 assets 声明。
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// 与 script_loader.dart 的 builtInScriptIds 保持一致
const DEFAULT_BUILT_IN_IDS = ['ai_image', 'line_sticker'];

const ROOT = path.resolve(__dirname, '..');
const ids = process.argv.slice(2).length ? process.argv.slice(2) : DEFAULT_BUILT_IN_IDS;

const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const writeJson = (p, obj) => fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
const md5 = (buf) => crypto.createHash('md5').update(buf).digest('hex');

/** 剔除 version/builtIn 后的实质内容（键排序保证比较稳定） */
function canonicalMeta(meta) {
  const clone = { ...meta };
  delete clone.version;
  delete clone.builtIn;
  return JSON.stringify(clone, (k, v) => (v instanceof Object && !(v instanceof Array)
    ? Object.keys(v).sort().reduce((acc, key) => { acc[key] = v[key]; return acc; }, {})
    : v));
}

let changed = 0;
let unchanged = 0;

for (const id of ids) {
  const onlineDir = path.join(ROOT, 'online/scripts', id);
  const assetsDir = path.join(ROOT, 'assets/scripts', id);

  if (!fs.existsSync(path.join(onlineDir, 'metadata.json'))) {
    console.error(`❌ [${id}] online/scripts/${id}/metadata.json 不存在`);
    process.exitCode = 1;
    continue;
  }

  const onlineMeta = readJson(path.join(onlineDir, 'metadata.json'));
  const onlineCode = fs.readFileSync(path.join(onlineDir, 'script.js'));

  // 与 assets 比较实质内容
  let hasDiff = true;
  if (fs.existsSync(path.join(assetsDir, 'metadata.json'))) {
    const assetsMeta = readJson(path.join(assetsDir, 'metadata.json'));
    const assetsCode = fs.readFileSync(path.join(assetsDir, 'script.js'));
    hasDiff = canonicalMeta(onlineMeta) !== canonicalMeta(assetsMeta)
      || !onlineCode.equals(assetsCode);
  }

  if (!hasDiff) {
    unchanged++;
    console.log(`✓ [${id}] 内容一致，无需同步 (v${onlineMeta.version})`);
  } else {
    // 升 patch 版本，保证应用端升级机制能推送
    const parts = String(onlineMeta.version || '1.0.0').split('.').map((n) => parseInt(n) || 0);
    while (parts.length < 3) parts.push(0);
    parts[2] += 1;
    const newVersion = parts.join('.');
    const oldVersion = onlineMeta.version || '(无)';

    onlineMeta.version = newVersion;
    writeJson(path.join(onlineDir, 'metadata.json'), onlineMeta);

    fs.mkdirSync(assetsDir, { recursive: true });
    const assetsMeta = { ...onlineMeta, builtIn: true };
    writeJson(path.join(assetsDir, 'metadata.json'), assetsMeta);
    fs.copyFileSync(path.join(onlineDir, 'script.js'), path.join(assetsDir, 'script.js'));

    changed++;
    console.log(`✅ [${id}] 已同步并升级版本 ${oldVersion} -> v${newVersion} (metadata + script.js + builtIn)`);
  }

  // 重算 online 的 files.json 校验值
  const entries = ['metadata.json', 'script.js'].map((f) => {
    const buf = fs.readFileSync(path.join(onlineDir, f));
    return { path: f, md5: md5(buf), size: buf.length };
  });
  writeJson(path.join(onlineDir, 'files.json'), entries);

  // 一致性校验
  const a = readJson(path.join(assetsDir, 'metadata.json'));
  const o = readJson(path.join(onlineDir, 'metadata.json'));
  const consistent = a.version === o.version && JSON.stringify(a.inputs) === JSON.stringify(o.inputs)
    && a.builtIn === true
    && fs.readFileSync(path.join(assetsDir, 'script.js')).equals(
      fs.readFileSync(path.join(onlineDir, 'script.js')));
  console.log(`   [${id}] 校验: version=${o.version} inputs=${(o.inputs || []).map((i) => i.key + ':' + i.type).join(',')} 一致=${consistent ? '✓' : '✗'}`);
  if (!consistent) process.exitCode = 1;
}

console.log(`\n完成: ${changed} 个同步升级, ${unchanged} 个已是最新${process.exitCode ? '，存在校验失败！' : ''}`);
