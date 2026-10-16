// Unsplash 图片搜索脚本
// GET https://api.unsplash.com/search/photos?query=...&per_page=...
//   Header: Authorization: Client-ID {accessKey}
// 遵守 Unsplash 使用条款：
//   - 图片热链接官方 CDN（urls.regular），不自托管、不转存
//   - 展示时署名摄影师（Photo by {name} on Unsplash）
// Access Key 存于脚本本地配置（configs/scripts_center/unsplash_search_config.json），
// 通过运行表单旁的「配置」填写，不硬编码进脚本。
// 免费额度：演示 50 次/小时（响应头 X-Ratelimit-Remaining 可查余量）。
//
// 依赖的 JS Bridge 能力（Aboutme 1.0+）：
//   Aboutme.script_executor.getConfig  读取脚本配置
//   Aboutme.http.request               网络请求
//   Aboutme.plugins.ui.toast           轻提示
//   Aboutme.plugins.ui.showJsonScreen  json_dynamic_widget 全屏展示

const SCRIPT_ID = 'unsplash_search';

// ── 参数归一 ─────────────────────────────────────────────
// 手动运行时 args 即运行表单输入；runScript 互调时为 {params: [...], calledFrom}
const input = (args && args.calledFrom === 'runScript')
    ? (Array.isArray(args.params) ? (args.params[0] || {}) : (args.params || {}))
    : (args || {});

const config = await Aboutme.script_executor.getConfig(SCRIPT_ID) || {};

const query = String(input.query || '').trim();
const accessKey = String(config.accessKey || '').trim();
const perPage = Math.max(1, Math.min(30, Number(input.perPage || config.perPage || 10) || 10));
const page = Math.max(1, Number(input.page || 1) || 1);
const orientation = String(input.orientation || 'any').trim(); // any = 不限
const orderBy = String(input.orderBy || 'relevant').trim();    // relevant | latest
// 默认展示；args.showUi 显式覆盖（供后台/工具调用关闭结果页）
const showUi = (typeof args.showUi === 'boolean') ? args.showUi : (config.showUi !== false);
// 显式代理（host:port 或 http://host:port）；留空时 Dart 端自动探测系统代理
const proxy = String(config.proxy || '').trim();

function toast(message, type) {
  try {
    Aboutme.plugins.ui.toast(message, { type: type || 'normal', gravity: 'top' });
  } catch (e) { /* toast 失败不影响主流程 */ }
}

// ── 校验 ─────────────────────────────────────────────────
if (!query) {
  toast('请输入搜索关键词（query）', 'warning');
  return { success: false, error: '缺少搜索关键词 query' };
}
if (!accessKey) {
  toast('请先在脚本配置中填写 Unsplash Access Key', 'warning');
  return { success: false, error: '未配置 Access Key' };
}

// ── 请求搜索 ─────────────────────────────────────────────
let url = `https://api.unsplash.com/search/photos`
    + `?query=${encodeURIComponent(query)}`
    + `&per_page=${perPage}&page=${page}&order_by=${encodeURIComponent(orderBy)}`;
if (orientation && orientation !== 'any') {
  url += `&orientation=${encodeURIComponent(orientation)}`;
}

console.log(`[unsplash_search] 搜索: "${query}" per_page=${perPage} page=${page} orientation=${orientation} order_by=${orderBy}`);
toast(`正在搜索 "${query}" ...`);

let resp;
try {
  resp = await Aboutme.http.request({
    url,
    method: 'GET',
    headers: { 'Authorization': 'Client-ID ' + accessKey },
    timeout: 30,
    ...(proxy ? { proxy } : {}),
  });
} catch (e) {
  toast('搜索请求失败: ' + e.message, 'error');
  return { success: false, error: '请求失败: ' + e.message };
}

let body = resp.body;
// 网络层异常（超时/断网/DNS）以 {error} 返回而非抛异常
if (resp.error) {
  toast('搜索请求失败: ' + resp.error, 'error');
  return { success: false, error: '请求失败: ' + resp.error };
}
if (typeof body === 'string') {
  try { body = JSON.parse(body); } catch (e) { /* 保持字符串 */ }
}

if (resp.statusCode >= 400) {
  // Unsplash 错误格式：{ errors: ["..."] }；401=key 无效，403=额度用尽
  const apiError = (body && Array.isArray(body.errors) && body.errors[0])
      || (typeof body === 'string' ? body.slice(0, 200) : JSON.stringify(body).slice(0, 200));
  const hint = resp.statusCode === 401 ? '（Access Key 无效，请检查配置）'
      : resp.statusCode === 403 ? '（额度用尽：演示版 50 次/小时）' : '';
  toast(`搜索失败 HTTP ${resp.statusCode} ${hint}`, 'error');
  return { success: false, error: `HTTP ${resp.statusCode}: ${apiError} ${hint}` };
}

// ── 解析结果 ─────────────────────────────────────────────
const results = (body && Array.isArray(body.results)) ? body.results : [];
const total = (body && body.total) || 0;

const images = [];
for (const r of results) {
  if (!r || !r.urls) continue;
  images.push({
    id: r.id,
    url: r.urls.regular || r.urls.full || '',   // 热链接 CDN 地址（w=1080）
    thumb: r.urls.thumb || '',
    photographer: (r.user && r.user.name) || '未知',
    profileUrl: (r.user && r.user.links && r.user.links.html) || '',
    description: r.description || r.alt_description || '',
    pageUrl: (r.links && r.links.html) || '',
    width: r.width,
    height: r.height,
  });
}

if (!images.length) {
  toast(`"${query}" 没有搜索到图片`, 'warning');
  return { success: false, error: '无搜索结果', data: { query, total, page, images: [] } };
}

const remaining = (resp.headers && (resp.headers['x-ratelimit-remaining'] || resp.headers['X-Ratelimit-Remaining'])) || '';
console.log(`[unsplash_search] 命中 ${images.length}/${total} 张${remaining !== '' ? `，本小时余量 ${remaining}` : ''}`);

// ── 构建 json_dynamic_widget 结果界面 ────────────────────
// 图片用 network_image 热链接官方 CDN（条款要求），每张下方署名摄影师
function creditText(img) {
  const size = img.width && img.height ? ` · ${img.width}x${img.height}` : '';
  return `Photo by ${img.photographer} on Unsplash${size}`;
}

const imageWidgets = [];
for (const img of images) {
  imageWidgets.push({
    type: 'padding',
    args: {
      padding: [8.0, 4.0],
      child: {
        type: 'column',
        args: {
          crossAxisAlignment: 'start',
          children: [
            {
              type: 'clip_rrect',
              args: {
                borderRadius: { type: 'circular', radius: 12.0 },
                child: { type: 'network_image', args: { src: img.url, fit: 'fitWidth' } },
              },
            },
            { type: 'sized_box', args: { height: 6.0 } },
            {
              type: 'text',
              args: { text: creditText(img), style: { fontSize: 11.0 } },
            },
            img.description
                ? { type: 'text', args: { text: img.description.slice(0, 60), style: { fontSize: 10.0 } } }
                : { type: 'sized_box', args: { height: 4.0 } },
          ],
        },
      },
    },
  });
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
              text: `"${query}" · 第 ${page} 页 · 共 ${total} 条结果`,
              style: { fontSize: 14.0, fontWeight: 'bold' },
            }
          },
          {
            type: 'text',
            args: {
              text: `展示 ${images.length} 张（热链接 Unsplash CDN，已署名摄影师）`,
              style: { fontSize: 11.0 },
            }
          },
          { type: 'sized_box', args: { height: 8.0 } },
        ].concat(imageWidgets)
      }
    }
  }
};

toast(`搜到 ${total} 条，展示 ${images.length} 张`, 'success');

const result = {
  success: true,
  message: `搜索 "${query}" 命中 ${images.length}/${total} 张`,
  data: {
    query,
    total,
    page,
    perPage,
    ...(remaining !== '' ? { rateLimitRemaining: Number(remaining) } : {}),
    // 供 runScript 互调消费：url=热链大图 thumb=缩略图
    images: images.map(function(i) { return { url: i.url, thumb: i.thumb, photographer: i.photographer, profileUrl: i.profileUrl, pageUrl: i.pageUrl, width: i.width, height: i.height }; }),
  }
};

if (showUi) {
  try {
    // 展示页关闭前该 await 不会结束，结果在关闭后返回
    const uiResp = await Aboutme.plugins.ui.showJsonScreen(uiJson, { title: 'Unsplash 搜索' });
    if (uiResp && uiResp.success === false) {
      // 后台触发（runScript 互调等）无 UI 上下文，降级为 toast 提示
      console.log(`[unsplash_search] 无法展示界面（${uiResp.reason || '未知'}），已降级为提示`);
      toast(`后台模式：命中 ${images.length} 张图片`, 'success');
    }
  } catch (e) {
    console.log(`[unsplash_search] 结果界面展示失败: ${e.message}`);
  }
}

return result;
