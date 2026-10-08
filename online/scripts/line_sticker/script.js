// ── LINE 贴图下载 ─────────────────────────────────────────
// 参考：https://github.com/suchipi/line-sticker-downloader
// 原工具用 Puppeteer 点击商店页面抓图；脚本环境改为直接调用 LINE 公开 API：
//   1. 从链接解析产品 ID
//   2. GET stickerpacklistmobile.json 拿贴图列表
//   3. 逐张下载贴图 PNG（静态包取 android 图；动态包优先 iPhone APNG 源，
//      导入时宿主会自动把 APNG 转成 GIF 以支持动画播放）
//   4. importStickerCollection 导入为本地贴图合集（聊天表情面板可用）
//
// 使用的桥接 API：
//   Aboutme.script_executor.getConfig          读取脚本配置（proxy）
//   Aboutme.http.request                       网络请求（QuickJS 无 fetch）
//   Aboutme.system.saveFile                    URL 直写存储（相对 app_data）
//   Aboutme.plugins.ui.toast                   轻提示
//   Aboutme.plugins.chat.importStickerCollection  导入贴图合集

const SCRIPT_ID = 'line_sticker';

const config = (await Aboutme.script_executor.getConfig(SCRIPT_ID)) || {};
const proxy = (config.proxy && String(config.proxy).trim()) || undefined;

const inputUrl = String((args && (args.url || args._value)) || '').trim();
const customName = String((args && args.name) || '').trim();

function fail(message) {
  Aboutme.plugins.ui.toast(message, { type: 'error', gravity: 'top' });
  return { success: false, message: message };
}

// ── 1. 解析产品 ID ─────────────────────────────────────
if (!inputUrl) return fail('请输入 LINE 贴图链接');
if (inputUrl.indexOf('emojishop') !== -1) {
  return fail('暂不支持表情商店（emojishop）链接，请使用贴图（stickershop）链接');
}
const idMatch = inputUrl.match(/(?:product|detail)\/(\d+)/);
if (!idMatch) return fail('无法从链接中识别贴图 ID：' + inputUrl);
const productId = idMatch[1];

const httpHeaders = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
  Referer: 'https://store.line.me/',
};

async function httpGetJson(url, timeout) {
  const resp = await Aboutme.http.request({
    url,
    method: 'GET',
    headers: httpHeaders,
    timeout,
    ...(proxy ? { proxy } : {}),
  });
  if (resp && resp.error) {
    throw new Error(String(resp.error));
  }
  let body = resp.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch (e) {
      /* 保持字符串 */
    }
  }
  return { statusCode: resp.statusCode, body };
}

// ── 2. 获取贴图列表 ────────────────────────────────────
log('获取贴图列表: ' + productId);
let listResp;
try {
  listResp = await httpGetJson(
    'https://stickershop.line-scdn.net/stickershop/v1/product/' +
      productId +
      '/android/stickerpacklistmobile.json',
    30,
  );
} catch (e) {
  return fail(
    '获取贴图列表失败: ' +
      (e.message || e) +
      '。请在脚本配置中填写可用代理（如 http://127.0.0.1:7890），或填 direct 强制直连',
  );
}
if (listResp.statusCode !== 200) {
  return fail(
    '获取贴图列表失败: HTTP ' + listResp.statusCode + '（LINE 域名需要代理）',
  );
}
const list = listResp.body || {};
// 注意：LINE 官方接口的字段名就是 stickets（拼写如此）
const stickers = (list.stickets || list.stickers || []).filter(function (s) {
  return s && s.id != null;
});
if (!stickers.length) return fail('贴图列表为空，请确认链接是否有效');

// ── 3. 确定合集名称 ────────────────────────────────────
function pickTitle(t) {
  if (!t) return '';
  if (typeof t === 'string') return t;
  if (typeof t === 'object') {
    const keys = Object.keys(t);
    return (
      t['zh-Hans'] || t['zh-Hant'] || t['en'] || t['ja-JP'] || (keys.length ? t[keys[0]] : '')
    );
  }
  return '';
}
let title = customName || pickTitle(list.title);
if (!title) {
  // 回退：抓商店页面 og:title
  try {
    const page = await Aboutme.http.request({
      url: 'https://store.line.me/stickershop/product/' + productId + '/zh-Hans',
      headers: httpHeaders,
      timeout: 20,
      ...(proxy ? { proxy } : {}),
    });
    if (page.statusCode === 200 && typeof page.body === 'string') {
      const m =
        page.body.match(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/) ||
        page.body.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/);
      if (m) title = m[1];
    }
  } catch (e) {
    /* 名称回退 */
  }
}
if (!title) title = 'LINE贴图 ' + productId;

// ── 4. 逐张下载贴图 ────────────────────────────────────
Aboutme.plugins.ui.toast('开始下载「' + title + '」共 ' + stickers.length + ' 张', {
  type: 'normal',
});
const downloaded = [];
for (let i = 0; i < stickers.length; i++) {
  const sid = stickers[i].id;
  const savePath = 'stickers/downloads/' + productId + '_' + sid + '.png';
  const staticUrl =
    'https://sdl-stickershop.line.naver.jp/products/0/0/' +
    productId + '/' + sid + '/android/sticker.png';
  const apngUrl =
    'https://sdl-stickershop.line.naver.jp/products/0/0/' +
    productId + '/' + sid + '/iphone/sticker@2x.png';
  // 动态贴图优先 iPhone APNG 源（导入时自动转 GIF 播放动画），静态包优先 android 图
  const resourceType = String(stickers[i].stickerResourceType || '');
  const isAnimated =
    /ANIMATION|POPUP/.test(resourceType) || list.hasAnimation === true;
  const urls = isAnimated ? [apngUrl, staticUrl] : [staticUrl, apngUrl];
  let saved = false;
  for (const u of urls) {
    try {
      const r = await Aboutme.system.saveFile({
        path: savePath,
        url: u,
        timeout: 60,
        ...(proxy ? { proxy } : {}),
      });
      if (r && r.success) {
        saved = true;
        break;
      }
    } catch (e) {
      /* 尝试下一个 URL */
    }
  }
  if (saved) {
    downloaded.push(savePath);
  } else {
    log('贴图 ' + sid + ' 下载失败，跳过', 'warn');
  }
  if ((i + 1) % 5 === 0) {
    Aboutme.plugins.ui.toast('下载中 ' + (i + 1) + '/' + stickers.length, {
      type: 'normal',
    });
    log('下载进度 ' + (i + 1) + '/' + stickers.length);
  }
}

if (!downloaded.length) return fail('所有贴图下载失败，请检查网络或代理配置');

// ── 5. 导入为贴图合集 ──────────────────────────────────
let imported = null;
try {
  imported = await Aboutme.plugins.chat.importStickerCollection({
    name: title,
    paths: downloaded,
  });
} catch (e) {
  return fail('导入贴图合集失败: ' + (e.message || e));
}
if (!imported || imported.error || imported.success !== true) {
  return fail('导入贴图合集失败: ' + ((imported && imported.error) || '未知错误'));
}

Aboutme.plugins.ui.toast('已导入「' + title + '」' + downloaded.length + ' 张贴图', {
  type: 'success',
});
log('导入完成: ' + title + ' (' + downloaded.length + '/' + stickers.length + ')');

return {
  success: true,
  message:
    '已下载并导入贴图合集「' + title + '」（' +
    downloaded.length + '/' + stickers.length +
    ' 张），可在聊天表情面板中使用',
  data: {
    collectionId: imported.id,
    count: downloaded.length,
    localPaths: downloaded.map(function (p) {
      return './' + p;
    }),
  },
};
