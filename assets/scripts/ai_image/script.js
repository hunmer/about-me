// AI 图片生成脚本（参考 workflow.ai-image 插件模板）
// 对接 OpenAI 兼容异步图像 API：
//   提交  POST {baseUrl}/v1/images/generations?async=true (JSON)
//   查询  GET  {baseUrl}/v1/images/tasks/{task_id}
// 提交返回 task_id 则轮询到终态（IN_PROGRESS / SUCCESS / FAILURE），
// 部分服务会直接同步返回 { created, data: [{url|b64_json}] }。
// 生成完成后用 json_dynamic_widget 渲染结果展示页。
// 生成的图片会持久化到 app_data/scripts/ai_image/（URL 图片先下载）；
// 后台触发（runScript 互调等）无法弹界面时自动降级为 toast 提示。
//
// 依赖的 JS Bridge 能力（Aboutme 1.0+）：
//   Aboutme.script_executor.getConfig  读取脚本配置
//   Aboutme.http.request               网络请求（QuickJS 无 fetch；responseType:'base64' 下载二进制）
//   Aboutme.system.sleep               轮询间隔等待（QuickJS 无可靠 setTimeout）
//   Aboutme.system.saveFile            base64 数据落盘（相对 app_data 目录）
//   Aboutme.plugins.ui.toast           轻提示
//   Aboutme.plugins.ui.showJsonScreen  json_dynamic_widget 全屏展示

const SCRIPT_ID = 'ai_image';

// ── 参数归一 ─────────────────────────────────────────────
// 手动运行时 args 即运行表单输入；runScript 互调时为 {params: [...], calledFrom}
const input = (args && args.calledFrom === 'runScript')
    ? (Array.isArray(args.params) ? (args.params[0] || {}) : (args.params || {}))
    : (args || {});

const config = await Aboutme.script_executor.getConfig(SCRIPT_ID) || {};

const prompt = String(input.prompt || '').trim();
const apiKey = String(config.apiKey || '').trim();
const baseUrl = String(config.baseUrl || 'https://ai.comfly.chat').replace(/\/+$/, '');
const model = String(input.model || config.model || 'gpt-image-1').trim();
const aspectRatio = String(input.aspectRatio || config.aspectRatio || '1:1').trim();
const n = Math.max(1, Math.min(4, Number(input.n || config.n || 1) || 1));
const showUi = config.showUi !== false; // 默认展示
// 显式代理（host:port 或 http://host:port）；留空时 Dart 端自动探测系统代理
const proxy = String(config.proxy || '').trim();

function toast(message, type) {
  try {
    Aboutme.plugins.ui.toast(message, { type: type || 'normal', gravity: 'top' });
  } catch (e) { /* toast 失败不影响主流程 */ }
}

async function sleep(ms) {
  return Aboutme.system.sleep(ms);
}

// 发送 HTTP 请求并返回 {statusCode, body}（body 自动尝试 JSON.parse）
async function httpJson(url, options) {
  const common = {
    url,
    method: options.method || 'GET',
    headers: options.headers,
    timeout: options.timeout || 60,
    ...(proxy ? { proxy } : {}),
  };
  const resp = await Aboutme.http.request(
    options.body != null ? { ...common, body: options.body } : common,
  );
  let body = resp.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { /* 保持字符串 */ }
  }
  return { statusCode: resp.statusCode, body };
}

// ── 校验 ─────────────────────────────────────────────────
if (!prompt) {
  toast('请输入图片描述（prompt）', 'warning');
  return { success: false, error: '缺少图片描述 prompt' };
}
if (!apiKey) {
  toast('请先在脚本配置中填写 API Key', 'warning');
  return { success: false, error: '未配置 API Key' };
}

const authHeaders = {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ' + apiKey,
};

// ── 参考图（图生图模式）─────────────────────────────────
// 输入 image 为本地路径或图片 URL 的混合列表：
//   URL → Aboutme.http.request 走代理下载为 base64
//   本地路径 → Aboutme.system.readFile 读取
const refPaths = Array.isArray(input.image)
    ? input.image.filter(function(p) { return p && String(p).trim(); })
    : (input.image ? [String(input.image)] : []);
const isEdit = refPaths.length > 0;

let refFiles = []; // [{base64, filename}]
if (refPaths.length) {
  for (const p of refPaths) {
    try {
      let base64 = '';
      let filename = '';
      if (/^https?:\/\//i.test(p)) {
        const resp = await Aboutme.http.request({
          url: p, method: 'GET', responseType: 'base64', timeout: 60,
          ...(proxy ? { proxy } : {}),
        });
        if (!resp.bodyBase64) {
          toast(`参考图下载失败: ${p}`, 'warning');
          return { success: false, error: '参考图下载失败: ' + p };
        }
        base64 = resp.bodyBase64;
        filename = p.replace(/^.*[\\/]/, '').split('?')[0] || 'image.png';
        console.log(`[ai_image] 参考图已下载: ${filename} (${Math.round(base64.length * 3 / 4 / 1024)}KB)`);
      } else {
        const r = await Aboutme.system.readFile({ path: p });
        if (!r || !r.base64) {
          toast(`参考图读取失败: ${p}`, 'warning');
          return { success: false, error: '参考图读取失败: ' + p };
        }
        base64 = r.base64;
        filename = String(p).replace(/^.*[\\/]/, '') || 'image.png';
        console.log(`[ai_image] 参考图已读取: ${filename} (${Math.round(r.size / 1024)}KB)`);
      }
      refFiles.push({ base64, filename });
    } catch (e) {
      toast('参考图获取失败: ' + e.message, 'error');
      return { success: false, error: '参考图获取失败: ' + e.message };
    }
  }
}

console.log(`[ai_image] 提交生成 ${isEdit ? '图生图(编辑)' : '文生图'} model=${model} ratio=${aspectRatio} n=${n}${isEdit ? ` 参考图=${refFiles.length}` : ''}`);
console.log(`[ai_image] ${isEdit ? '编辑指令' : '提示词'}: ${prompt}`);
toast(isEdit ? `图生图任务已提交（${refFiles.length} 张参考图）...` : '已提交生成任务，等待云端处理...');

// ── 提交生成 ─────────────────────────────────────────────
let submit;
try {
  if (isEdit) {
    // 图生图：POST /v1/images/edits?async=true（multipart，多图用 image[] 字段名）
    const multipart = [];
    const fileField = refFiles.length > 1 ? 'image[]' : 'image';
    for (const f of refFiles) {
      multipart.push({ name: fileField, filename: f.filename, base64: f.base64 });
    }
    multipart.push({ name: 'prompt', value: prompt });
    multipart.push({ name: 'model', value: model });
    if (aspectRatio) multipart.push({ name: 'aspect_ratio', value: aspectRatio });
    if (n) multipart.push({ name: 'n', value: String(n) });

    submit = await Aboutme.http.request({
      url: `${baseUrl}/v1/images/edits?async=true`,
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + apiKey },
      multipart,
      timeout: 120,
      ...(proxy ? { proxy } : {}),
    });
    let body = submit.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (e) { /* 保持字符串 */ }
    }
    submit = { statusCode: submit.statusCode, body };
  } else {
    // 文生图：POST /v1/images/generations?async=true（JSON）
    submit = await httpJson(`${baseUrl}/v1/images/generations?async=true`, {
      method: 'POST',
      headers: authHeaders,
      body: { prompt, model, aspect_ratio: aspectRatio, n },
      timeout: 120,
    });
  }
} catch (e) {
  toast('生成请求失败: ' + e.message, 'error');
  return { success: false, error: '提交失败: ' + e.message };
}

if (submit.statusCode >= 400) {
  const detail = typeof submit.body === 'string'
      ? submit.body.slice(0, 200)
      : JSON.stringify(submit.body).slice(0, 200);
  toast(`提交失败 HTTP ${submit.statusCode}`, 'error');
  return { success: false, error: `HTTP ${submit.statusCode}: ${detail}` };
}

// 提取 task_id（comfly 顶层 task_id / closeai 风格 data.task_id / data 为字符串）
function pickTaskId(r) {
  if (!r || typeof r !== 'object') return '';
  if (typeof r.task_id === 'string' && r.task_id) return r.task_id;
  if (typeof r.data === 'string') return r.data;
  if (r.data && typeof r.data === 'object' && typeof r.data.task_id === 'string') return r.data.task_id;
  return '';
}

const taskId = pickTaskId(submit.body);
let payload = submit.body; // 同步返回时直接就是结果

// ── 轮询任务 ─────────────────────────────────────────────
if (taskId) {
  console.log(`[ai_image] 任务已提交 task_id=${taskId}，开始轮询...`);
  const deadline = Date.now() + 4 * 60 * 1000; // 脚本执行上限 5 分钟，留余量

  while (Date.now() < deadline) {
    await sleep(5000);
    let taskResp;
    try {
      taskResp = await httpJson(`${baseUrl}/v1/images/tasks/${encodeURIComponent(taskId)}`, {
        method: 'GET',
        headers: authHeaders,
        timeout: 30,
      });
    } catch (e) {
      console.log(`[ai_image] 查询任务失败，将重试: ${e.message}`);
      continue;
    }

    const data = (taskResp.body && taskResp.body.data) || {};
    const status = String(data.status || '').toUpperCase();
    console.log(`[ai_image] 任务状态: ${status || '未知'} ${data.progress || ''}`);

    if (status === 'SUCCESS') { payload = data; break; }
    if (status === 'FAILURE' || status === 'FAILED') {
      const reason = data.fail_reason || (taskResp.body && taskResp.body.message) || '未知错误';
      toast('图片任务失败: ' + reason, 'error');
      return { success: false, error: '任务失败: ' + reason, taskId };
    }
  }

  if (!Array.isArray((payload && payload.data))) {
    toast('轮询超时，任务未完成', 'error');
    return { success: false, error: '轮询超时', taskId };
  }
}

// ── 提取图片 ─────────────────────────────────────────────
// 异步结果包在 data 中；同步兼容格式 { created, data: [...] }
const resultRoot = (payload && Array.isArray(payload.data)) ? payload : (payload && payload.data) || {};
const items = Array.isArray(resultRoot.data) ? resultRoot.data : [];

const images = [];   // [{kind:'url', value}, {kind:'base64', value}]
for (const item of items) {
  if (!item || typeof item !== 'object') continue;
  if (item.url) {
    images.push({ kind: 'url', value: item.url });
  } else if (item.b64_json) {
    images.push({ kind: 'base64', value: item.b64_json });
  }
}

if (!images.length) {
  const detail = JSON.stringify(payload).slice(0, 200);
  toast('未解析到生成图片', 'error');
  return { success: false, error: '未获取到图片: ' + detail, taskId };
}

// ── 持久化保存 ───────────────────────────────────────────
// 保存到 app_data/scripts/ai_image/ 下；URL 图片先下载（responseType: base64）。
// 单张失败不影响主流程。
function timestamp() {
  const d = new Date();
  const p = function(n) { return (n < 10 ? '0' : '') + n; };
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

async function saveImages(imageList) {
  const stamp = timestamp();
  // 与 imageList 等长对齐（失败位为 null），便于界面按索引取对应图片
  // base64 保留用于界面展示（network_image 不走代理，被墙图床显示不出来）
  const saved = new Array(imageList.length).fill(null);
  for (let i = 0; i < imageList.length; i++) {
    const img = imageList[i];
    try {
      let base64 = img.value;
      if (img.kind === 'url') {
        const resp = await Aboutme.http.request({
          url: img.value, method: 'GET', responseType: 'base64', timeout: 60,
          ...(proxy ? { proxy } : {}),
        });
        if (!resp.bodyBase64) continue;
        base64 = resp.bodyBase64;
      }
      const file = `scripts/ai_image/ai_image_${stamp}_${i + 1}.png`;
      const result = await Aboutme.system.saveFile({ path: file, base64 });
      if (result && result.success) {
        saved[i] = { path: result.absolutePath || result.path, base64 };
        console.log(`[ai_image] 已保存: ${result.absolutePath || result.path}`);
      }
    } catch (e) {
      console.log(`[ai_image] 保存第 ${i + 1} 张失败: ${e.message}`);
    }
  }
  return saved;
}

console.log(`[ai_image] 开始保存 ${images.length} 张图片到本地...`);
const savedImages = await saveImages(images); // 与 images 等长，失败位为 null
const savedList = savedImages.filter(Boolean);
const localPaths = savedList.map(function(s) { return s.path; });
const savedCount = savedList.length;
console.log(`[ai_image] 保存完成 ${savedCount}/${images.length}`);

// ── 构建 json_dynamic_widget 结果界面 ────────────────────
// 已保存的图片用 memory_image（base64 在手，不依赖网络；
// network_image 不走系统代理，被墙图床会加载失败），
// 未保存成功的回退 network_image（URL 直连）
function imageWidget(base64, url) {
  const child = base64
    ? { type: 'memory_image', args: { image: base64, fit: 'fitWidth' } }
    : { type: 'network_image', args: { src: url, fit: 'fitWidth' } };
  return {
    type: 'padding',
    args: {
      padding: [8.0, 8.0],
      child: {
        type: 'clip_rrect',
        args: {
          borderRadius: { type: 'circular', radius: 12.0 },
          child: child,
        },
      },
    },
  };
}

const imageWidgets = [];
for (let i = 0; i < images.length; i++) {
  const s = savedImages[i];
  imageWidgets.push(imageWidget(s ? s.base64 : null, images[i].value));
}

const uiJson = {
  type: 'scaffold',
  args: {
    body: {
      type: 'list_view',
      args: {
        padding: [16.0, 16.0],
        children: [
          {
            type: 'text',
            args: {
              text: `${isEdit ? '图生图' : '文生图'}成功 · ${images.length} 张 · ${model}${aspectRatio ? ' · ' + aspectRatio : ''}${isEdit ? ` · ${refFiles.length}参考` : ''}`,
              style: { fontSize: 14.0, fontWeight: 'bold' },
            }
          },
          { type: 'sized_box', args: { height: 8.0 } },
          {
            type: 'text',
            args: {
              text: prompt,
              style: { fontSize: 13.0 },
            }
          },
          {
            type: 'text',
            args: {
              text: savedCount
                ? `已保存 ${savedCount}/${images.length} 张到 app_data/scripts/ai_image/`
                : '图片未保存到本地',
              style: { fontSize: 11.0 },
            }
          },
          { type: 'sized_box', args: { height: 8.0 } },
        ].concat(imageWidgets)
      }
    }
  }
};

toast(savedCount
    ? `生成 ${images.length} 张，已保存 ${savedCount} 张到本地`
    : `生成成功，共 ${images.length} 张图片`, 'success');

const result = {
  success: true,
  message: `生成 ${images.length} 张图片，保存 ${savedCount} 张`,
  data: {
    images: images.map(function(i) { return i.value; }),
    imageUrls: images.filter(function(i) { return i.kind === 'url'; }).map(function(i) { return i.value; }),
    localPaths: localPaths,
    taskId: taskId,
    model: model,
    created: resultRoot.created,
  }
};

if (showUi) {
  try {
    // 展示页关闭前该 await 不会结束，结果在关闭后返回
    const uiResp = await Aboutme.plugins.ui.showJsonScreen(uiJson, { title: 'AI 图片生成' });
    if (uiResp && uiResp.success === false) {
      // 后台触发（runScript 互调等）无 UI 上下文，降级为 toast 提示
      console.log(`[ai_image] 无法展示界面（${uiResp.reason || '未知'}），已降级为提示`);
      toast(localPaths.length
          ? `后台模式：已保存 ${localPaths.length} 张图片`
          : `后台模式：已生成 ${images.length} 张图片`, 'success');
    }
  } catch (e) {
    console.log(`[ai_image] 结果界面展示失败: ${e.message}`);
  }
}

return result;
