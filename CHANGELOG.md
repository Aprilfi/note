# 更新日志

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

发版流程：

1. 在下面把「未发布」里的条目归到新版本号下，写上日期
2. 改 `package.json` 的 `version`
3. `npm run build:release`
4. `git add -A && git commit -m "发布 x.y.z" && git tag vx.y.z`
5. `git push && git push --tags`，再去 GitHub 的 Releases 页把 APK 传上去

版本号规则见 README 的「版本管理」一节：
`versionCode = major*10000 + minor*100 + patch`，只增不减。

---

## [未发布]

### 新增

- 设置页增加「关于」卡片，显示当前版本号与内部版本号
- `www/version.js` 由编译脚本依据 `package.json` 自动生成，
  应用内用 `@capacitor/app` 的 `getInfo()` 读取真实安装的版本，
  浏览器预览时退回读这个文件
- `npm run install:release` / `install:debug`：自动找 `adb` 并把包装到设备上
  （本机没把 platform-tools 加进 PATH）
- README 重写为流程导向的《开发与发布手册》
- 配置 SSH 密钥（`~/.ssh/id_ed25519`，ed25519 无口令），远程地址改为
  `git@github.com:Aprilfi/note.git`。HTTPS 走令牌容易被墙且受权限限制，
  SSH 走 22 端口更稳
- 启用 GitHub Actions 云端编译（`.github/workflows/android.yml` 终于能推上去了，
  SSH 不受令牌的 `workflow` 权限限制）

### 数据导入支持选文件

- 设置页的导入区改成两步：**① 选备份文件 → ② 确认模式并恢复**。
  原来只能把备份内容粘贴进文本框，现在可以直接选「导出全部备份」得到的那份 txt
- 选文件后会自动读取并校验，然后列出识别到的内容（考公/健康各多少条、
  心愿/未来清单/购入复盘多少条、有没有自定义壁纸、这份备份是什么时候导出的），
  一眼就能看出有没有选错文件
- 备份文件名带上日期时间：`卜卜迷你工作台备份-20261002-1435.txt`。
  原来每次导出都叫同一个名字，攒几份就分不清该恢复哪个
- 备份内容里新增 `exportedAt` 字段记录导出时间（老备份没有这个字段，
  导入时会提示「可能是旧版本导出的」，不影响导入）
- 导入完成的提示现在会列出各模块的条数和本次实际增加的数量

### 导出备份改用系统「另存为」对话框

- 之前导出是「写进 App 自己的 Documents 目录 + 弹系统分享面板」，用户看不到
  文件存哪了，而且分享面板里有没有「保存到本机」取决于设备装了哪些 App
  （裸模拟器上就没有）
- 改成安卓标准的 SAF 另存为（`ACTION_CREATE_DOCUMENT`）：能自己挑文件夹、
  改文件名，界面是系统自带的（`com.google.android.documentsui`），什么设备上都有
- 实现放在 `MainActivity.java`：通过 `addJavascriptInterface` 暴露
  `window.AndroidBu.saveBackup(文件名, 文本)`，用 `ActivityResultContracts.CreateDocument`
  拿回用户选定的 Uri 再写入
- 保存完成后回调用 `window.__buSaveResult(ok)` 通知网页，界面弹出明确提示
  （「已保存：xxx.txt，在你刚才选的那个文件夹里」），取消则不打扰
- `.documentsui` 是系统组件，不再依赖 `@capacitor/filesystem` 的私有目录 +
  `@capacitor/share`，那套降级为拿不到原生桥时的兜底

### 心愿模块重整（需求改版第 1 步）

- 「➕ 新增心愿」不再是独立子标签，改成**弹窗**，和「编辑心愿」共用同一个表单
  （传 id 就是编辑，不传就是新增），字段只维护一份
- 去掉「价格」和「欲望程度」两个字段，连带去掉列表里的价格区间标签、
  合计价格、以及排序里的两个按价格选项
- 新增「规格」字段（选填的一行文本），在列表里以标签显示，方便同类之间对比
- 心愿不再记价格，所以「标记下单」时实际花掉的钱改为必填
- **旧数据里的 `price` / `desire` 字段保留在 localStorage 里没有删除**，
  只是界面不再读写它们 —— 删除不可逆，留着零成本，万一以后想恢复还有

### 计划模块重整（需求改版第 2 步）

- **删掉「考公」整个板块** —— 含考公任务、碎片留言、精华留言。
  计划页现在只剩「健康」和「社会化」，默认展开的也从考公换成健康
- **社会化新增一套评论**（🪶 碎片留言 + ⭐ 精华留言）。按确认采用方案 B：
  原有的「💫 瞬间&灵感（带标签）」和「⭐ 精华收藏」**原样保留**，评论是另外一套
- 设置页的计划统计同步调整：去掉「考公留言 / 考公精华留言」两张卡，
  换成「社会化留言 / 社会化精华留言」
- 数据导入、导出摘要、清空确认的文案和字段列表同步去掉考公
- **旧数据里的 `gongkao` / `gongkaoTop` 保留在 localStorage 里没有删除**，
  只是界面不再渲染；设置页的「清空计划数据」会把它们一并清掉

### 一键编译并安装

- 新增 `一键编译并安装.bat`（桌面也有副本）：双击就依次跑完
  `npm run build:release` + `npm run install:release`，失败时给出中文提示并停住不闪退
- 逻辑放在 `tools/build-and-install.ps1` 里，`.bat` 保持纯 ASCII 只做入口 ——
  cmd.exe 读批处理用的是控制台代码页（这台机器上 UTF-8 / GBK 不一致），
  中文写在 `.bat` 里会导致整行解析错乱

### 变更

- 应用图标与启动图换成仓鼠图。源图放在 `assets/icon-source.jpg`，
  换图后重跑 `npm run icons` 和 `npm run android-assets` 即可。
  图标底色是贴着源图背景的垂直渐变（`#2D7EE3` → `#388FEE`），
  换图时若背景色不同，需要同步改 `tools/icon-lib.ps1` 顶部的两个颜色，
  否则贴图边缘会露出色差方块
- 去掉 `android/app/build.gradle` 里钉死的 `buildToolsVersion "34.0.0"`，
  改用 AGP 自带默认值（当前 35.0.0）。钉死版本会让 CI 或换机器时
  因为缺少该特定版本而失败
- `www/icons` 只保留 `manifest.json` / `index.html` 真正引用的
  144 / 192 / 512 三个尺寸。之前额外生成的 `icon-1024`、`icon-foreground`、
  `icon-background`、`splash-2732`、`splash-512` 没有任何地方引用，
  却跟着 `www/` 一起打进 APK 白占 2.6MB。去掉后 APK 从 6.94MB 降到 4.31MB

### 修复

- `npm run build:debug` 一直失败的问题。PowerShell 会把「只有一个元素的数组」
  拆成字符串，导致 `@gradleArgs` 展开时把 `assembleDebug` 按字符逐个传给 Gradle，
  报 `Task 's' is ambiguous`。release 分支有两个任务所以没暴露
- 图标贴图边缘出现一圈亮边。源因是 GDI+ 的 bicubic 重采样在矩形边界产生过冲，
  已改为 `HighQualityBilinear`
- `tools/build-apk.ps1` 解压 SDK 组件时偶发失败。杀毒软件会在刚解压出 exe
  的瞬间扫描并短暂锁住文件，导致 `ExtractToDirectory` 报
  "being used by another process"。已加重试

---

## [1.0.0] - 2026-10-01

首个可发布版本。

### 新增

- 把单文件网页 `卜卜迷你工作台D.html` 用 Capacitor 7 打包成安卓应用
- 考公 / 健康 / 社会化计划、心愿清单、未来清单、购入复盘、消费统计图表
- 原生适配：安卓返回键（先关弹窗、再回首页、最后才退出）、
  底部导航栏安全区、导出备份走系统分享落盘
- 正式签名（`bubu-release.jks`，有效期 10000 天）
- 图标与启动图生成脚本、一键编译脚本
- 国内网络适配：Maven 依赖走阿里云镜像，Gradle 分发与 Android SDK 走腾讯镜像
