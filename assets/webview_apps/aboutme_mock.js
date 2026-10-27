/**
 * Aboutme JavaScript Bridge Mock
 * 用于开发测试的独立模拟环境
 *
 * 基于 lib/plugins/webview/screens/webview_browser_screen.dart /
 * lib/plugins/webview/widgets/embedded_webview.dart 中的
 * _createAboutmeUserScript 注入脚本，以及
 * lib/plugins/webview/services/js_bridge_injector.dart（handler 实现）、
 * lib/core/js_bridge/js_bridge_manager.dart（system API 实现）同步。
 *
 * 注意：仅模拟 WebView 环境（Aboutme.plugins/system/ui/storage）。
 * QuickJS 脚本环境的额外命名空间（Aboutme.http/events/toolCall/tools）
 * 不在 WebView 注入范围内，故不提供。
 */

(function() {
  'use strict';

  // 1. 注入基础命名空间
  if (typeof window.Aboutme !== 'undefined') {
    console.warn('[Aboutme Mock] Aboutme already exists, skipping initialization');
    return;
  }

  window.Aboutme = {
    version: '1.0.0',
    plugins: {},
    system: {},
    storage: {},
    _ready: false,
    _readyCallbacks: []
  };

  /**
   * Aboutme ready 回调机制
   * @param {Function} callback - 回调函数
   */
  window.Aboutme.ready = function(callback) {
    if (window.Aboutme._ready) {
      try {
        callback();
      } catch(e) {
        console.error('[Aboutme Mock] Ready callback error:', e);
      }
    } else {
      window.Aboutme._readyCallbacks.push(callback);
    }
  };

  // 2. 注入插件代理
  // 真实环境结果直接返回（不包装 success/data 字段），错误为 {error: '...'} 对象
  window.Aboutme.plugins = new Proxy({}, {
    get: function(target, pluginId) {
      if (pluginId === 'ui' || typeof pluginId === 'symbol') {
        return target[pluginId];
      }

      if (!target[pluginId]) {
        target[pluginId] = new Proxy({}, {
          get: function(_, methodName) {
            if (typeof methodName === 'symbol') return undefined;

            return function(params) {
              console.log(`[Aboutme Mock] Plugin call: ${pluginId}.${methodName}`, params);

              // 模拟插件调用：直接返回模拟数据（真实环境返回插件自身的结果结构）
              return Promise.resolve({
                pluginId: pluginId,
                method: methodName,
                params: params || {},
                timestamp: Date.now()
              });
            };
          }
        });
      }
      return target[pluginId];
    }
  });

  // 3. 注入系统 API（与 js_bridge_manager._registerSystemAPIs 对齐）
  var WEEKDAY_NAMES = ['一', '二', '三', '四', '五', '六', '日'];

  function pad(n, len) {
    return String(n).padStart(len || 2, '0');
  }

  function weekdayName(d) {
    return WEEKDAY_NAMES[d.getDay() === 0 ? 6 : d.getDay() - 1];
  }

  function timeObject(d) {
    return {
      timestamp: d.getTime(),
      datetime: d.toISOString(),
      year: d.getFullYear(),
      month: d.getMonth() + 1,
      day: d.getDate(),
      hour: d.getHours(),
      minute: d.getMinutes(),
      second: d.getSeconds(),
      millisecond: d.getMilliseconds(),
      weekday: d.getDay() === 0 ? 7 : d.getDay(),
      weekdayName: weekdayName(d)
    };
  }

  // formatDate 的占位符替换规则与 Dart _formatDateTime 一致（小写 yyyy、E 为星期）
  function applyFormat(d, format) {
    return format
      .split('yyyy').join(pad(d.getFullYear(), 4))
      .split('MM').join(pad(d.getMonth() + 1))
      .split('dd').join(pad(d.getDate()))
      .split('HH').join(pad(d.getHours()))
      .split('hh').join(pad(d.getHours() % 12))
      .split('mm').join(pad(d.getMinutes()))
      .split('ss').join(pad(d.getSeconds()))
      .split('E').join(weekdayName(d));
  }

  // getCustomDate 的 relativePosition 处理（周一起始，与 dart_date 一致）
  var relativePositions = {
    startOfDay: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); },
    endOfDay: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999); },
    startOfHour: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours()); },
    endOfHour: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), 59, 59, 999); },
    startOfMinute: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes()); },
    endOfMinute: function(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), 59, 999); },
    startOfMonth: function(d) { return new Date(d.getFullYear(), d.getMonth(), 1); },
    endOfMonth: function(d) { return new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59, 999); },
    startOfWeek: function(d) {
      var s = new Date(d.getFullYear(), d.getMonth(), d.getDate());
      s.setDate(s.getDate() - ((s.getDay() + 6) % 7));
      return s;
    },
    endOfWeek: function(d) {
      var e = relativePositions.startOfWeek(d);
      e.setDate(e.getDate() + 6);
      return relativePositions.endOfDay(e);
    },
    startOfYear: function(d) { return new Date(d.getFullYear(), 0, 1); },
    endOfYear: function(d) { return new Date(d.getFullYear(), 11, 31, 23, 59, 59, 999); }
  };

  function timeago(d) {
    var diffSec = Math.round((Date.now() - d.getTime()) / 1000);
    if (diffSec < 10) return 'just now';
    if (diffSec < 60) return diffSec + ' seconds ago';
    if (diffSec < 3600) return Math.round(diffSec / 60) + ' minutes ago';
    if (diffSec < 86400) return Math.round(diffSec / 3600) + ' hours ago';
    if (diffSec < 2592000) return Math.round(diffSec / 86400) + ' days ago';
    return d.toISOString().split('T')[0];
  }

  window.Aboutme.system.getCurrentTime = function() {
    console.log('[Aboutme Mock] System call: getCurrentTime');
    return Promise.resolve(timeObject(new Date()));
  };

  window.Aboutme.system.getDeviceInfo = function() {
    console.log('[Aboutme Mock] System call: getDeviceInfo');
    return Promise.resolve({
      platform: 'web',
      platformVersion: navigator.userAgent,
      deviceModel: navigator.platform,
      isPhysicalDevice: true
    });
  };

  window.Aboutme.system.getAppInfo = function() {
    console.log('[Aboutme Mock] System call: getAppInfo');
    return Promise.resolve({
      appName: 'Aboutme',
      version: '1.0.0',
      buildNumber: '1',
      packageName: 'github.hunmer.aboutme'
    });
  };

  // formatDate(dateInput, format?)：dateInput 为日期字符串或毫秒时间戳，format 默认 'yyyy-MM-dd HH:mm:ss'
  window.Aboutme.system.formatDate = function(dateInput, format) {
    console.log('[Aboutme Mock] System call: formatDate', dateInput, format);

    var date = dateInput instanceof Date ? dateInput : new Date(dateInput);
    if (typeof dateInput !== 'number' && typeof dateInput !== 'string' || isNaN(date.getTime())) {
      // 真实环境返回 {error} 对象（不 reject）
      return Promise.resolve({ error: 'Exception: Invalid date input type' });
    }
    return Promise.resolve(applyFormat(date, format || 'yyyy-MM-dd HH:mm:ss'));
  };

  window.Aboutme.system.getTimestamp = function() {
    console.log('[Aboutme Mock] System call: getTimestamp');
    return Promise.resolve(Date.now());
  };

  // getCustomDate(options)：options = { baseDate?, timezone?, add?, subtract?, relativePosition?, format? }
  // add/subtract = { days, hours, minutes, seconds, milliseconds }
  // format: 'object'(默认) | 'timestamp' | 'iso' | 'text' | 自定义格式字符串
  window.Aboutme.system.getCustomDate = function(options) {
    console.log('[Aboutme Mock] System call: getCustomDate', options);

    try {
      var opts = options || {};
      var d = new Date();

      if (opts.baseDate != null) {
        d = new Date(opts.baseDate);
      }

      ['add', 'subtract'].forEach(function(key) {
        var delta = opts[key];
        if (delta) {
          var ms = ((delta.days || 0) * 86400 + (delta.hours || 0) * 3600 +
                    (delta.minutes || 0) * 60 + (delta.seconds || 0)) * 1000 +
                   (delta.milliseconds || 0);
          d = new Date(d.getTime() + (key === 'add' ? ms : -ms));
        }
      });

      var position = opts.relativePosition;
      if (position && relativePositions[position]) {
        d = relativePositions[position](d);
      }

      var format = opts.format || 'object';
      if (format === 'timestamp') {
        return Promise.resolve(d.getTime());
      }
      if (format === 'iso') {
        return Promise.resolve(d.toISOString());
      }
      if (format === 'text') {
        return Promise.resolve(timeago(d));
      }
      if (format === 'object') {
        return Promise.resolve(timeObject(d));
      }
      return Promise.resolve(applyFormat(d, format));
    } catch (e) {
      return Promise.resolve({ error: e.toString() });
    }
  };

  // 4. 注入 UI API（与 js_bridge_injector 的 handler 对齐：
  //    alert 返回 boolean，dialog 返回 boolean|null，toast 走 SnackBar）
  var uiApi = {
    toast: function(message, options) {
      console.log('[Aboutme Mock] UI Toast:', message, options);

      var durationMs = typeof options?.duration === 'number' ? options.duration
        : options?.duration === 'long' ? 4000 : 2000;
      var gravity = options?.gravity || 'bottom';

      // 模拟 toast 显示（真实环境为固定时长 SnackBar，不处理 options）
      var toast = document.createElement('div');
      toast.style.cssText = `
        position: fixed;
        left: 50%;
        transform: translateX(-50%);
        ${gravity === 'top' ? 'top: 20px;' : gravity === 'center' ? 'top: 50%;' : 'bottom: 40px;'}
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 12px 24px;
        border-radius: 8px;
        font-size: 14px;
        z-index: 999999;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        max-width: 80%;
        text-align: center;
      `;
      toast.textContent = message;

      document.body.appendChild(toast);

      setTimeout(() => {
        toast.style.transition = 'opacity 0.3s';
        toast.style.opacity = '0';
        setTimeout(() => {
          if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
          }
        }, 300);
      }, durationMs);

      return Promise.resolve();
    },
    alert: function(message, options) {
      console.log('[Aboutme Mock] UI Alert:', message, options);

      // 模拟真实环境：单个确认按钮，返回 boolean
      var dialog = document.createElement('div');
      dialog.style.cssText = `
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 999999;
      `;

      var content = document.createElement('div');
      content.style.cssText = `
        background: white;
        padding: 24px;
        border-radius: 12px;
        max-width: 400px;
        width: 90%;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      `;

      content.innerHTML = `
        <h3 style="margin: 0 0 12px 0; font-size: 18px; font-weight: 600;">
          ${options?.title || '提示'}
        </h3>
        <p style="margin: 0 0 20px 0; font-size: 14px; color: #666; line-height: 1.5;">
          ${message || ''}
        </p>
        <div style="display: flex; justify-content: flex-end;">
          <button id="ok-btn" style="
            padding: 8px 16px;
            background: #007AFF;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
          ">${options?.confirmText || '确定'}</button>
        </div>
      `;

      dialog.appendChild(content);
      document.body.appendChild(dialog);

      return new Promise((resolve) => {
        content.querySelector('#ok-btn').onclick = () => {
          document.body.removeChild(dialog);
          resolve(true);
        };
        // 点击背景关闭（真实环境 DSDialog dismiss 返回 false）
        dialog.onclick = (e) => {
          if (e.target === dialog) {
            document.body.removeChild(dialog);
            resolve(false);
          }
        };
      });
    },
    dialog: function(options) {
      console.log('[Aboutme Mock] UI Dialog:', options);

      // 模拟真实环境：title/content + 确认/取消，返回 boolean|null
      var showCancel = options?.showCancel !== false;
      var dialog = document.createElement('div');
      dialog.style.cssText = `
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 999999;
      `;

      var content = document.createElement('div');
      content.style.cssText = `
        background: white;
        padding: 24px;
        border-radius: 12px;
        max-width: 400px;
        width: 90%;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      `;

      content.innerHTML = `
        <h3 style="margin: 0 0 12px 0; font-size: 18px; font-weight: 600;">
          ${options?.title || ''}
        </h3>
        <p style="margin: 0 0 20px 0; font-size: 14px; color: #666; line-height: 1.5;">
          ${options?.content || ''}
        </p>
        <div style="display: flex; gap: 12px; justify-content: flex-end;">
          ${showCancel ? `
            <button id="cancel-btn" style="
              padding: 8px 16px;
              border: 1px solid #ddd;
              background: white;
              border-radius: 6px;
              cursor: pointer;
              font-size: 14px;
            ">${options?.cancelText || '取消'}</button>
          ` : ''}
          <button id="ok-btn" style="
            padding: 8px 16px;
            background: #007AFF;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
          ">${options?.confirmText || '确定'}</button>
        </div>
      `;

      dialog.appendChild(content);
      document.body.appendChild(dialog);

      return new Promise((resolve) => {
        content.querySelector('#ok-btn').onclick = () => {
          document.body.removeChild(dialog);
          resolve(true);
        };

        var cancelBtn = content.querySelector('#cancel-btn');
        if (cancelBtn) {
          cancelBtn.onclick = () => {
            document.body.removeChild(dialog);
            resolve(false);
          };
        }

        // 点击背景关闭（真实环境返回 null）
        dialog.onclick = (e) => {
          if (e.target === dialog) {
            document.body.removeChild(dialog);
            resolve(null);
          }
        };
      });
    }
  };

  window.Aboutme.plugins.ui = uiApi;
  window.Aboutme.ui = uiApi;

  // 5. 注入 Storage API（真实环境仅 read/write/delete，走统一数据 SDK 的
  //    webview 域 KV 命令；read 返回 null 表示不存在，错误时 reject）
  var STORAGE_PREFIX = 'AboutmeMock_';
  var storageApi = {
    read: function(key) {
      console.log(`[Aboutme Mock] Storage read: ${key}`);

      try {
        const prefixedKey = STORAGE_PREFIX + key;
        const value = localStorage.getItem(prefixedKey);

        if (value === null) {
          return Promise.resolve(null);
        }

        // 尝试解析 JSON
        try {
          const parsed = JSON.parse(value);
          return Promise.resolve(parsed);
        } catch (e) {
          return Promise.resolve(value);
        }
      } catch (e) {
        console.error('[Aboutme Mock] Storage read error:', e);
        return Promise.reject(new Error(e.toString()));
      }
    },
    write: function(key, value) {
      console.log(`[Aboutme Mock] Storage write: ${key}`, value);

      try {
        const prefixedKey = STORAGE_PREFIX + key;
        const jsonValue = JSON.stringify(value);
        localStorage.setItem(prefixedKey, jsonValue);
        return Promise.resolve(true);
      } catch (e) {
        console.error('[Aboutme Mock] Storage write error:', e);
        return Promise.reject(new Error(e.toString()));
      }
    },
    delete: function(key) {
      console.log(`[Aboutme Mock] Storage delete: ${key}`);

      try {
        const prefixedKey = STORAGE_PREFIX + key;
        localStorage.removeItem(prefixedKey);
        return Promise.resolve(true);
      } catch (e) {
        console.error('[Aboutme Mock] Storage delete error:', e);
        return Promise.reject(new Error(e.toString()));
      }
    }
  };

  window.Aboutme.storage = storageApi;

  // 6. 添加辅助方法（仅 Mock 环境提供，真实环境无 Aboutme.utils）
  window.Aboutme.utils = {
    // 日志记录
    log: function(...args) {
      console.log('[Aboutme]', ...args);
    },
    // 错误记录
    error: function(...args) {
      console.error('[Aboutme Error]', ...args);
    },
    // 警告记录
    warn: function(...args) {
      console.warn('[Aboutme Warning]', ...args);
    },
    // 获取存储状态（Mock 调试用）
    getStorageState: function() {
      try {
        var keys = Object.keys(localStorage);
        var state = {};
        keys.forEach(function(key) {
          if (key.startsWith(STORAGE_PREFIX)) {
            var value = localStorage.getItem(key);
            try {
              state[key.substring(STORAGE_PREFIX.length)] = JSON.parse(value);
            } catch (e) {
              state[key.substring(STORAGE_PREFIX.length)] = value;
            }
          }
        });
        return state;
      } catch (e) {
        console.error('[Aboutme Mock] getStorageState error:', e);
        return {};
      }
    },
    // 重置存储（Mock 调试用）
    resetStorage: function() {
      var keys = Object.keys(localStorage);
      keys.forEach(function(key) {
        if (key.startsWith(STORAGE_PREFIX)) {
          localStorage.removeItem(key);
        }
      });
      console.log('[Aboutme Mock] Storage reset');
      return Promise.resolve(true);
    }
  };

  // 标记准备完成并触发回调
  window.Aboutme._ready = true;
  if (window.Aboutme._readyCallbacks) {
    window.Aboutme._readyCallbacks.forEach(function(cb) {
      try {
        cb();
      } catch(e) {
        console.error('[Aboutme Mock] Ready callback error:', e);
      }
    });
    window.Aboutme._readyCallbacks = [];
  }

  // 打印初始化完成信息
  console.log('%c[Aboutme] JS Bridge Mock loaded successfully', 'color: #4CAF50; font-weight: bold; font-size: 12px;');
  console.log('%cVersion: ' + window.Aboutme.version, 'color: #666;');
  console.log('%cAvailable APIs:', 'color: #666;');
  console.log('  - Aboutme.plugins.<pluginName>.<method>(params)  // 结果直接返回，错误为 {error} 对象');
  console.log('  - Aboutme.system.getCurrentTime/getDeviceInfo/getAppInfo/formatDate/getTimestamp/getCustomDate()');
  console.log('  - Aboutme.ui.toast(message, options) / alert(message, options) -> boolean / dialog(options) -> boolean|null');
  console.log('  - Aboutme.storage.read(key) -> value|null / write(key, value) -> true / delete(key) -> true');
  console.log('  - Aboutme.utils（仅 Mock 环境的调试工具）');

  // 导出到全局，便于调试
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = window.Aboutme;
  }
})();
