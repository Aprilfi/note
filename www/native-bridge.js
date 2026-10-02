/* ============================================================
   卜卜迷你工作台 —— 原生外壳桥接层
   ------------------------------------------------------------
   这个文件只在「打包成 App」时被 index.html 引入，作用是把浏览器里
   正常、但塞进安卓 WebView 后会失效的功能补回来：

     1. 底部安全区   —— WebView 里 env(safe-area-inset-*) 恒为 0，
                        TabBar 会被系统手势条压住
     2. 返回键       —— 不拦截的话按一下就直接退出应用
     3. 导出下载     —— a.download + Blob 在 WebView 里不触发下载，
                        备份文件会「点了没反应」
     4. 错误回传     —— 出问题时把报错丢给原生日志，方便排查

   设计原则：全部功能都是「有原生就增强，没有就完全退回浏览器行为」，
   所以在普通浏览器里打开这个页面，本文件不会有任何副作用。

   原生侧需要实现的接口（任选其一，没有也不影响其它功能）：

     Android JavascriptInterface  →  window.AndroidBu
       int    safeAreaBottom()                 返回底部安全区像素（int）
       void   log(String msg)                  日志
       void   saveBackup(String name, String text)  保存导出的备份

     或者由原生壳直接注入：
       window.__BU_INSETS__ = { bottom: 16 };
       window.__BU_SAVE__   = function(name, text) { ... };

   如果用的是 Capacitor，则自动走 @capacitor/app + filesystem + share。
============================================================ */
(function () {
  'use strict';

  var doc = document;
  var BACKUP_NAME = '卜卜迷你工作台备份.txt';
  var CAP = (window.Capacitor && window.Capacitor.Plugins) || null;
  var AB = window.AndroidBu || null;          // 自写壳的桥

  /* ---------- 调用原生桥的小工具 ---------- */
  function nativeCall(name, a, b) {
    var fn = (AB && typeof AB[name] === 'function') ? AB[name] : null;
    if (fn) { try { return fn.call(AB, a, b); } catch (e) { /* 忽略 */ } }
    return null;
  }
  function log(msg) {
    nativeCall('log', String(msg));
    if (window.console && console.log) console.log('[bu]', msg);
  }

  /* ============================================================
     1. 安全区
     CSS 侧已把 --bu-safe-b 接进 body / TabBar 的 padding，
     这里负责在原生环境下写入真实数值。
  ============================================================ */
  function applyInsets() {
    var bottom = NaN;

    // 优先读壳直接注入的全局量
    if (window.__BU_INSETS__ && typeof window.__BU_INSETS__.bottom === 'number') {
      bottom = window.__BU_INSETS__.bottom;
    }
    // 其次问原生桥
    if (!isFinite(bottom)) {
      var r = nativeCall('safeAreaBottom');
      if (r !== null && r !== undefined && isFinite(Number(r))) bottom = Number(r);
    }
    if (isFinite(bottom) && bottom >= 0) {
      doc.documentElement.style.setProperty('--bu-safe-b', bottom + 'px');
      log('safe-area bottom = ' + bottom + 'px');
    }
  }

  /* ============================================================
     2. 返回键
     原生侧在 onBackPressed 时调用 window.buHandleBack()：
       返回 true  → 已被网页处理（关了弹窗 / 回到了首页）
       返回 false → 网页管不了，原生照常退出应用
  ============================================================ */
  function closeTopModal() {
    var modals = doc.querySelectorAll('.modal-overlay');
    for (var i = modals.length - 1; i >= 0; i--) {
      var m = modals[i];
      if (m.style && m.style.display && m.style.display !== 'none') {
        m.style.display = 'none';
        return true;
      }
    }
    return false;
  }
  function goHomePage() {
    var active = doc.querySelector('.page.active');
    if (active && active.id !== 'plan' && typeof window.switchPage === 'function') {
      window.switchPage('plan');
      return true;
    }
    return false;
  }
  window.buHandleBack = function () {
    if (closeTopModal()) return true;
    if (goHomePage()) return true;
    return false;
  };

  // Capacitor 环境下返回键由插件派发，这里接上同一套逻辑
  if (CAP && CAP.App && typeof CAP.App.addListener === 'function') {
    CAP.App.addListener('backButton', function () {
      if (window.buHandleBack()) return;
      if (typeof CAP.App.exitApp === 'function') CAP.App.exitApp();
    });
  }

  /* ============================================================
     3. 导出下载兜底
     exportAll() 走的是 Blob + a.download，WebView 里不会真的落盘。
     这里钩住 URL.createObjectURL，把要下载的文本顺手交给原生保存。
     原来的浏览器行为保持不动（浏览器里照常弹出下载）。
  ============================================================ */
  function routeBackup(text) {
    // (a) Capacitor：写进 App 私有目录再调系统分享
    if (CAP && CAP.Filesystem && typeof CAP.Filesystem.writeFile === 'function') {
      CAP.Filesystem.writeFile({
        path: BACKUP_NAME,
        data: text,
        directory: 'DOCUMENTS',
        encoding: 'utf8'
      }).then(function (res) {
        log('backup written: ' + (res && res.uri));
        if (CAP.Share && typeof CAP.Share.share === 'function') {
          return CAP.Share.share({ title: BACKUP_NAME, url: res.uri });
        }
      }).catch(function (e) { log('backup failed: ' + e); });
      return true;
    }
    // (b) 自写壳注入的保存函数
    if (typeof window.__BU_SAVE__ === 'function') {
      try { window.__BU_SAVE__(BACKUP_NAME, text); return true; } catch (e) { log('__BU_SAVE__ failed: ' + e); }
    }
    // (c) Android JavascriptInterface
    if (AB && typeof AB.saveBackup === 'function') {
      nativeCall('saveBackup', BACKUP_NAME, text);
      return true;
    }
    return false;
  }

  if (window.URL && typeof URL.createObjectURL === 'function') {
    var origCreate = URL.createObjectURL;
    URL.createObjectURL = function (blob) {
      var url = origCreate.call(URL, blob);
      try {
        if (blob && /text\/plain/.test(blob.type || '') && typeof blob.text === 'function') {
          blob.text().then(function (text) {
            if (routeBackup(text)) log('backup routed to native, ' + text.length + ' bytes');
          }).catch(function () {});
        }
      } catch (e) { /* 忽略 */ }
      return url;
    };
  }

  /* ============================================================
     4. 错误回传 + 双击缩放屏蔽
  ============================================================ */
  window.addEventListener('error', function (e) {
    log('JS ERROR: ' + (e && e.message) + ' @' + (e && e.lineno));
  });
  window.addEventListener('unhandledrejection', function (e) {
    log('PROMISE REJECT: ' + (e && e.reason && (e.reason.message || e.reason)));
  });

  // viewport 已禁用手势缩放，这里再挡掉双击放大（部分 WebView 不认 viewport）
  var lastTouch = 0;
  doc.addEventListener('touchend', function (e) {
    var now = Date.now();
    if (now - lastTouch <= 300) { e.preventDefault(); lastTouch = 0; }
    else { lastTouch = now; }
  }, { passive: false });

  /* ---------- 启动 ---------- */
  if (doc.readyState === 'loading') {
    doc.addEventListener('DOMContentLoaded', applyInsets);
  } else {
    applyInsets();
  }
  window.addEventListener('resize', applyInsets);

  log('native-bridge ready | capacitor=' + !!CAP + ' | androidBu=' + !!AB);
})();
