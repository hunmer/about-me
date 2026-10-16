// 聚合图片搜索脚本（关键词搜图 + 以图搜图）
//
// 两种模式（由输入自动切换）：
//   1. 填 imageUrl → 以图搜图：SerpAPI Google Lens 引擎
//        GET https://serpapi.com/search?engine=google_lens&url=...&api_key=...
//        返回 visual_matches（视觉相似图的来源站点/标题/缩略图），不支持翻页
//   2. 填 query → 关键词搜图，按 provider 选图源：
//        unsplash  GET https://api.unsplash.com/search/photos
//                  Header: Authorization: Client-ID {accessKey}
//                  条款：热链接官方 CDN + 署名摄影师；演示额度 50 次/小时
//        pixabay   GET https://pixabay.com/api/?key=...&q=...
//                  per_page 3-200、totalHits 上限 500；错误是纯文本 [ERROR ...]
//                  允许下载自托管（结果附 largeImageURL）
//        google    SerpAPI Google Images 引擎（与以图搜图共用 SerpAPI Key）
//                  GET https://serpapi.com/search?engine=google_images&google_domain=google.com&q=...
//                  真实全网图片结果；不支持翻页/方向/排序/类型；免费额度 250 次/月
//        bing      SerpAPI engine=bing_images，查询参数 q
//        yahoo     SerpAPI engine=yahoo_images，查询参数 p（注意不是 q）
//        yandex    SerpAPI engine=yandex_images，查询参数 text
//                  bing/yahoo/yandex 均返回 images_results（缓存缩略图+原图直链），
//                  不支持翻页/方向/排序/类型，共用 SerpAPI Key 与月度额度
//
// 各 API Key 存于脚本本地配置（configs/scripts_center/image_search_config.json），
// 按实际用到的图源校验对应 Key，不硬编码进脚本。
//
// 依赖的 JS Bridge 能力（Aboutme 1.0+）：
//   Aboutme.script_executor.getConfig  读取脚本配置
//   Aboutme.http.request               网络请求
//   Aboutme.plugins.ui.toast           轻提示
//   Aboutme.plugins.ui.showJsonScreen  json_dynamic_widget 全屏展示

const SCRIPT_ID = 'image_search';

// ── 参数归一 ─────────────────────────────────────────────
// 手动运行时 args 即运行表单输入；runScript 互调时为 {params: [...], calledFrom}
const input = (args && args.calledFrom === 'runScript')
    ? (Array.isArray(args.params) ? (args.params[0] || {}) : (args.params || {}))
    : (args || {});

const config = await Aboutme.script_executor.getConfig(SCRIPT_ID) || {};

const query = String(input.query || '').trim();
const imageUrl = String(input.imageUrl || '').trim();
const provider = String(input.provider || 'unsplash').trim(); // unsplash | pixabay | google | bing | yahoo | yandex
const mode = imageUrl ? 'lens' : 'keyword';                   // 由输入自动切换
const page = Math.max(1, Number(input.page || 1) || 1);
const imageType = String(input.imageType || 'photo').trim();  // 仅 pixabay
const orientation = String(input.orientation || 'any').trim();
const sort = String(input.sort || 'relevant').trim();         // relevant | popular | latest
// 默认展示；args.showUi 显式覆盖（供后台/工具调用关闭结果页）
const showUi = (typeof args.showUi === 'boolean') ? args.showUi : (config.showUi !== false);
// 显式代理（host:port 或 http://host:port）；留空时 Dart 端自动探测系统代理
const proxy = String(config.proxy || '').trim();

function toast(message, type) {
  try {
    Aboutme.plugins.ui.toast(message, { type: type || 'normal', gravity: 'top' });
  } catch (e) { /* toast 失败不影响主流程 */ }
}

// 发送 GET 请求，返回 {statusCode, headers, body}（body 自动尝试 JSON.parse）
// 网络层异常（超时/断网/DNS）以 {error} 返回而非抛异常
async function httpGet(url, headers) {
  const resp = await Aboutme.http.request({
    url, method: 'GET', headers, timeout: 30,
    ...(proxy ? { proxy } : {}),
  });
  if (resp.error) return { error: resp.error };
  let body = resp.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { /* 保持字符串 */ }
  }
  return { statusCode: resp.statusCode, headers: resp.headers, body };
}

// 提取错误详情（兼容 JSON 与纯文本错误体），截断到 200 字符
function errorDetail(body) {
  const raw = (body && typeof body === 'object')
      ? ((Array.isArray(body.errors) && body.errors[0]) || body.error || JSON.stringify(body))
      : String(body || '');
  return String(raw).slice(0, 200);
}

// ── 校验 ─────────────────────────────────────────────────
if (!imageUrl && !query) {
  toast('请填写搜索关键词，或图片 URL 进行以图搜图', 'warning');
  return { success: false, error: '缺少 query / imageUrl' };
}

const keys = {
  unsplash: String(config.unsplashAccessKey || '').trim(),
  pixabay: String(config.pixabayKey || '').trim(),
  serpapi: String(config.serpApiKey || '').trim(),
};
// SerpAPI 关键词搜图引擎表（查询参数名各不相同：google/bing=q, yahoo=p, yandex=text）
const SERP_ENGINES = {
  google: { engine: 'google_images', qParam: 'q' },
  bing: { engine: 'bing_images', qParam: 'q' },
  yahoo: { engine: 'yahoo_images', qParam: 'p' },
  yandex: { engine: 'yandex_images', qParam: 'text' },
};
const isSerpProvider = !!SERP_ENGINES[provider];

if (mode === 'lens' && !keys.serpapi) {
  toast('以图搜图需要先在脚本配置中填写 SerpAPI Key', 'warning');
  return { success: false, error: '未配置 SerpAPI Key' };
}
if (mode === 'keyword' && isSerpProvider && !keys.serpapi) {
  toast(`${provider} 图源与以图搜图共用 SerpAPI Key，请先在脚本配置中填写`, 'warning');
  return { success: false, error: '未配置 SerpAPI Key（' + provider + ' 图源）' };
}
if (mode === 'keyword' && (provider === 'unsplash' || provider === 'pixabay') && !keys[provider]) {
  toast(`使用 ${provider} 图源需要先在脚本配置中填写对应 Key`, 'warning');
  return { success: false, error: '未配置 ' + provider + ' 的 Key' };
}

// ── 搜索：Google Lens 以图搜图 ───────────────────────────
async function searchLens() {
  const limit = Math.max(1, Math.min(100, Number(input.perPage || config.perPage || 20) || 20));
  const url = `https://serpapi.com/search`
      + `?engine=google_lens`
      + `&url=${encodeURIComponent(imageUrl)}`
      + `&api_key=${encodeURIComponent(keys.serpapi)}`;

  console.log(`[image_search] 以图搜图: ${imageUrl} limit=${limit}`);
  toast('正在以图搜图（Google Lens）...');

  const resp = await httpGet(url);
  if (resp.error) {
    return { success: false, error: '请求失败: ' + resp.error };
  }
  if (resp.statusCode >= 400) {
    // SerpAPI 错误体：{ error: "..." }（401=key 无效，429=免费额度用尽）
    const detail = errorDetail(resp.body);
    const hint = resp.statusCode === 401 ? '（SerpAPI Key 无效）'
        : resp.statusCode === 429 ? '（免费额度 250 次/月已用尽）' : '';
    return { success: false, error: `HTTP ${resp.statusCode}: ${detail} ${hint}` };
  }

  const hits = (resp.body && Array.isArray(resp.body.visual_matches)) ? resp.body.visual_matches : [];
  const images = [];
  for (const v of hits.slice(0, limit)) {
    if (!v || !v.link) continue;
    images.push({
      url: v.thumbnail || v.link,        // 缩略图（Google CDN），详情页链接见 pageUrl
      thumb: v.thumbnail || '',
      user: v.source || '',              // 来源站点名
      profileUrl: '',
      pageUrl: v.link,                   // 匹配结果的落地页
      description: v.title || '',
      width: v.thumbnail_width,
      height: v.thumbnail_height,
      source: 'google_lens',
    });
  }
  if (!images.length) {
    return { success: false, error: '无视觉匹配结果（图片不可访问或无相似图）' };
  }
  return { success: true, images, total: hits.length, page: 1, perPage: images.length };
}

// ── 搜索：Unsplash ───────────────────────────────────────
async function searchUnsplash(perPage) {
  // 方向：landscape/portrait/squarish 有效，horizontal/vertical 映射到近义值
  const oriMap = { landscape: 'landscape', portrait: 'portrait', squarish: 'squarish', horizontal: 'landscape', vertical: 'portrait' };
  const ori = oriMap[orientation] || '';
  // 排序：unsplash 仅 relevant/latest，popular 无对应值按相关度处理
  const orderBy = (sort === 'latest') ? 'latest' : 'relevant';

  let url = `https://api.unsplash.com/search/photos`
      + `?query=${encodeURIComponent(query)}`
      + `&per_page=${perPage}&page=${page}&order_by=${orderBy}`;
  if (ori) url += `&orientation=${ori}`;

  console.log(`[image_search] unsplash 搜索: "${query}" per_page=${perPage} page=${page} orientation=${ori} order_by=${orderBy}`);
  toast(`正在搜索 "${query}"（Unsplash）...`);

  const resp = await httpGet(url, { 'Authorization': 'Client-ID ' + keys.unsplash });
  if (resp.error) {
    return { success: false, error: '请求失败: ' + resp.error };
  }
  if (resp.statusCode >= 400) {
    const detail = errorDetail(resp.body);
    const hint = resp.statusCode === 401 ? '（Access Key 无效）'
        : resp.statusCode === 403 ? '（演示额度 50 次/小时用尽）' : '';
    return { success: false, error: `HTTP ${resp.statusCode}: ${detail} ${hint}` };
  }

  const results = (resp.body && Array.isArray(resp.body.results)) ? resp.body.results : [];
  const images = [];
  for (const r of results) {
    if (!r || !r.urls) continue;
    images.push({
      url: r.urls.regular || r.urls.full || '',  // 热链接 CDN（w=1080，条款要求热链+署名）
      thumb: r.urls.thumb || '',
      user: (r.user && r.user.name) || '未知',
      profileUrl: (r.user && r.user.links && r.user.links.html) || '',
      pageUrl: (r.links && r.links.html) || '',
      description: r.description || r.alt_description || '',
      width: r.width,
      height: r.height,
      source: 'unsplash',
    });
  }
  const remaining = resp.headers
      && (resp.headers['x-ratelimit-remaining'] || resp.headers['X-Ratelimit-Remaining']);
  return { success: true, images, total: (resp.body && resp.body.total) || 0, page, perPage, rateLimitRemaining: remaining != null ? Number(remaining) : null };
}

// ── 搜索：Pixabay ────────────────────────────────────────
async function searchPixabay(perPage) {
  // 方向：horizontal/vertical 有效，landscape/portrait/squarish 映射/忽略
  const oriMap = { horizontal: 'horizontal', vertical: 'vertical', landscape: 'horizontal', portrait: 'vertical' };
  const ori = oriMap[orientation] || '';
  // 排序：pixabay 仅 popular/latest，relevant 按热门处理
  const order = (sort === 'latest') ? 'latest' : 'popular';

  const url = `https://pixabay.com/api/`
      + `?key=${encodeURIComponent(keys.pixabay)}`
      + `&q=${encodeURIComponent(query)}`
      + `&per_page=${perPage}&page=${page}`
      + `&image_type=${encodeURIComponent(imageType)}`
      + `&order=${order}`
      + (ori ? `&orientation=${ori}` : '');

  console.log(`[image_search] pixabay 搜索: "${query}" per_page=${perPage} page=${page} image_type=${imageType} orientation=${ori} order=${order}`);
  toast(`正在搜索 "${query}"（Pixabay）...`);

  const resp = await httpGet(url);
  if (resp.error) {
    return { success: false, error: '请求失败: ' + resp.error };
  }
  // Pixabay 错误是纯文本 [ERROR 400] "..."（JSON.parse 失败保持字符串）
  if (resp.statusCode >= 400 || typeof resp.body === 'string') {
    const detail = errorDetail(resp.body);
    const hint = /blocked|invalid/i.test(detail) ? '（API Key 无效或被封禁）' : '';
    return { success: false, error: `HTTP ${resp.statusCode}: ${detail} ${hint}` };
  }

  const hits = (resp.body && Array.isArray(resp.body.hits)) ? resp.body.hits : [];
  const totalHits = (resp.body && resp.body.totalHits) || 0;
  const images = [];
  for (const h of hits) {
    if (!h || !h.webformatURL) continue;
    images.push({
      url: h.webformatURL,              // 640px 展示图
      thumb: h.previewURL || '',
      user: h.user || '未知',
      profileUrl: '',
      pageUrl: h.pageURL || '',
      description: h.tags || '',
      width: h.imageWidth,
      height: h.imageHeight,
      large: h.largeImageURL || '',     // 1280px 下载/自托管用
      source: 'pixabay',
    });
  }
  if (!images.length) {
    const overLimit = (page - 1) * perPage >= 500;
    return { success: false, error: overLimit ? '翻页超过 totalHits 上限 500' : '无搜索结果' };
  }
  return { success: true, images, total: totalHits, page, perPage };
}

// ── 搜索：SerpAPI 引擎（google/bing/yahoo/yandex 图片）────
// 各引擎响应统一为 images_results[]（thumbnail 缓存缩略图 / original 原图直链）
async function searchSerpImages(perPage) {
  const eng = SERP_ENGINES[provider];
  let url = `https://serpapi.com/search`
      + `?engine=${eng.engine}`
      + `&${eng.qParam}=${encodeURIComponent(query)}`
      + `&api_key=${encodeURIComponent(keys.serpapi)}`;
  // 仅 google 引擎支持语言/地区参数（默认 en/us；中文场景可配 zh-CN / cn）
  let logExtra = '';
  if (provider === 'google') {
    const hl = String(config.googleHl || 'en').trim();
    const gl = String(config.googleGl || 'us').trim();
    url += `&google_domain=google.com&hl=${encodeURIComponent(hl)}&gl=${encodeURIComponent(gl)}`;
    logExtra = ` hl=${hl} gl=${gl}`;
  }

  console.log(`[image_search] ${provider} 搜索: "${query}"${logExtra} limit=${perPage}`);
  toast(`正在搜索 "${query}"（${provider}）...`);

  const resp = await httpGet(url);
  if (resp.error) {
    return { success: false, error: '请求失败: ' + resp.error };
  }
  if (resp.statusCode >= 400) {
    // SerpAPI 错误体：{ error: "..." }（401=key 无效，429=免费额度用尽）
    const detail = errorDetail(resp.body);
    const hint = resp.statusCode === 401 ? '（SerpAPI Key 无效）'
        : resp.statusCode === 429 ? '（免费额度 250 次/月已用尽）' : '';
    return { success: false, error: `HTTP ${resp.statusCode}: ${detail} ${hint}` };
  }

  const hits = (resp.body && Array.isArray(resp.body.images_results)) ? resp.body.images_results : [];
  const images = [];
  for (const r of hits.slice(0, perPage)) {
    if (!r || !r.thumbnail) continue;
    images.push({
      url: r.original || r.thumbnail,       // 原图直链（可能失效/较大），展示用 thumb
      thumb: r.thumbnail,                   // 引擎缓存缩略图，加载稳定
      user: r.source || '',                 // 来源站点名
      profileUrl: '',
      pageUrl: r.link || '',                // 结果落地页
      description: r.title || '',
      width: r.original_width,
      height: r.original_height,
      source: provider,
    });
  }
  if (!images.length) {
    return { success: false, error: '无搜索结果' };
  }
  return { success: true, images, total: hits.length, page: 1, perPage: images.length };
}

// ── 执行搜索 ─────────────────────────────────────────────
let search;
if (mode === 'lens') {
  search = await searchLens();
} else if (isSerpProvider) {
  // 搜索引擎不支持翻页/方向/排序/类型，仅截断数量（上限 100 条/页）
  const limit = Math.max(1, Math.min(100, Number(input.perPage || config.perPage || 10) || 10));
  search = await searchSerpImages(limit);
} else {
  // per_page 各源范围不同：unsplash 1-30 / pixabay 3-200
  const raw = Number(input.perPage || config.perPage || 10) || 10;
  const perPage = (provider === 'unsplash')
      ? Math.max(1, Math.min(30, raw))
      : Math.max(3, Math.min(200, raw));
  search = (provider === 'unsplash') ? await searchUnsplash(perPage) : await searchPixabay(perPage);
}

if (!search.success) {
  toast('搜索失败: ' + search.error, 'error');
  return { success: false, error: search.error, data: { mode, provider, query, imageUrl, images: [] } };
}

const images = search.images;
console.log(`[image_search] 命中 ${images.length}/${search.total} 来源=${mode === 'lens' ? 'google_lens' : provider}`);

// ── 构建 json_dynamic_widget 结果界面 ────────────────────
// 署名文案按来源区分（Unsplash 条款要求署名摄影师）
function creditText(img) {
  if (img.source === 'unsplash') return `Photo by ${img.user} on Unsplash`;
  if (img.source === 'pixabay') return `by ${img.user}`;
  return img.user ? `来源: ${img.user}` : '';
}

// 以图搜图：缩略图小图 + 标题横排；关键词搜图：大图竖排
function lensItemWidget(img) {
  return {
    type: 'padding',
    args: {
      padding: [8.0, 6.0],
      child: {
        type: 'row',
        args: {
          crossAxisAlignment: 'start',
          children: [
            {
              type: 'clip_rrect',
              args: {
                borderRadius: { type: 'circular', radius: 8.0 },
                child: { type: 'network_image', args: { src: img.thumb || img.url, width: 72.0, height: 72.0, fit: 'cover' } },
              },
            },
            { type: 'sized_box', args: { width: 12.0 } },
            {
              type: 'expanded',
              args: {
                child: {
                  type: 'column',
                  args: {
                    crossAxisAlignment: 'start',
                    children: [
                      { type: 'text', args: { text: (img.description || '').slice(0, 80) || '(无标题)', style: { fontSize: 13.0 } } },
                      { type: 'sized_box', args: { height: 4.0 } },
                      { type: 'text', args: { text: creditText(img), style: { fontSize: 11.0 } } },
                      { type: 'text', args: { text: img.pageUrl.slice(0, 70), style: { fontSize: 10.0 } } },
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    },
  };
}

function photoItemWidget(img) {
  return {
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
            { type: 'text', args: { text: creditText(img), style: { fontSize: 11.0 } } },
            img.description
                ? { type: 'text', args: { text: img.description.slice(0, 60), style: { fontSize: 10.0 } } }
                : { type: 'sized_box', args: { height: 4.0 } },
          ],
        },
      },
    },
  };
}

const headerTitle = (mode === 'lens')
    ? `以图搜图 · ${images.length} 条视觉匹配`
    : `"${query}" · ${provider} · 第 ${search.page} 页 · 共 ${search.total} 条`;
const providerSub = (provider === 'unsplash')
    ? '热链 Unsplash CDN，已署名摄影师'
    : (provider === 'pixabay')
        ? 'webformatURL 640px，large 可下载自托管'
        : `${provider} 全网结果，展示缓存缩略图（url 为原图直链）`;
const headerSub = (mode === 'lens')
    ? imageUrl
    : `展示 ${images.length} 张（${providerSub}）`;

const uiJson = {
  type: 'scaffold',
  args: {
    body: {
      type: 'list_view',
      args: {
        padding: [16.0, 16.0],
        children: [
          { type: 'text', args: { text: headerTitle, style: { fontSize: 14.0, fontWeight: 'bold' } } },
          { type: 'text', args: { text: headerSub, style: { fontSize: 11.0 } } },
          { type: 'sized_box', args: { height: 8.0 } },
        ].concat(images.map((mode === 'lens' || isSerpProvider) ? lensItemWidget : photoItemWidget))
      }
    }
  }
};

toast(`搜到 ${search.total} 条，展示 ${images.length} 条`, 'success');

const result = {
  success: true,
  message: (mode === 'lens')
      ? `以图搜图命中 ${images.length} 条视觉匹配`
      : `搜索 "${query}" 命中 ${images.length}/${search.total} 张（${provider}）`,
  data: {
    mode,
    provider: mode === 'lens' ? 'google_lens' : provider,
    query,
    imageUrl: mode === 'lens' ? imageUrl : '',
    total: search.total,
    page: search.page,
    ...(search.rateLimitRemaining != null ? { rateLimitRemaining: search.rateLimitRemaining } : {}),
    // 供 runScript 互调消费：url=展示图 large=原图(pixabay) pageUrl=落地页
    images: images.map(function(i) {
      return { url: i.url, thumb: i.thumb, large: i.large || '', user: i.user, profileUrl: i.profileUrl, pageUrl: i.pageUrl, width: i.width, height: i.height, source: i.source };
    }),
  }
};

if (showUi) {
  try {
    // 展示页关闭前该 await 不会结束，结果在关闭后返回
    const uiResp = await Aboutme.plugins.ui.showJsonScreen(uiJson, { title: mode === 'lens' ? '以图搜图结果' : '图片搜索' });
    if (uiResp && uiResp.success === false) {
      // 后台触发（runScript 互调等）无 UI 上下文，降级为 toast 提示
      console.log(`[image_search] 无法展示界面（${uiResp.reason || '未知'}），已降级为提示`);
      toast(`后台模式：命中 ${images.length} 条结果`, 'success');
    }
  } catch (e) {
    console.log(`[image_search] 结果界面展示失败: ${e.message}`);
  }
}

return result;
