# 卜卜迷你工作台 · 开发与发布手册

把单文件网页 `卜卜迷你工作台D.html` 用 **Capacitor 7** 打包成安卓应用。
网页照常写 HTML / CSS / JS，外层套一个原生壳，需要系统能力时再调插件。

| 项目 | 值 |
| --- | --- |
| 远程仓库 | https://github.com/Aprilfi/note.git |
| 包名 | `com.bubu.workbench` |
| 当前版本 | 1.0.0（versionCode 10000） |
| 支持系统 | Android 6.0 及以上（minSdk 23） |
| 编译目标 | compileSdk 35 / targetSdk 35 |
| 产物大小 | APK 4.3 MB / AAB 4.1 MB |

原文件 `卜卜迷你工作台D.html` **保留在旁边没有改动**，改的是复制出来的 `www/index.html`。

**每天改功能只要记三步：**

```powershell
cd C:\Users\utgb3\Desktop\temp\apk-build
# 1. 改 www\ 里的文件
npm run build:release          # 2. 编译，约 40 秒
npm run install:release        # 3. 装到设备，约 2 秒
```

---

## 目录

1. [环境准备（一次性）](#1-环境准备一次性)
2. [每天改功能](#2-每天改功能)
3. [五种改动分别怎么做](#3-五种改动分别怎么做)
4. [发版完整流程](#4-发版完整流程)
5. [版本号规则](#5-版本号规则)
6. [常用命令速查](#6-常用命令速查)
7. [目录说明](#7-目录说明)
8. [签名与发布材料](#8-签名与发布材料)
9. [国内网络适配](#9-国内网络适配)
10. [已知的坑](#10-已知的坑)
11. [故障排查](#11-故障排查)

---

## 1. 环境准备（一次性）

### 方案 A：便携工具链（本项目自带，推荐）

```powershell
cd C:\Users\utgb3\Desktop\temp\apk-build
npm install          # 装 Capacitor 等 npm 依赖
npm run toolchain    # 下载 JDK 21 + Android SDK 到 .toolchain\，约 1GB、10-20 分钟
npm run build:release
```

工具链装在工程目录里，**不写系统环境变量、不装 Android Studio**，删掉 `.toolchain\`
就等于没装过。装完之后 `.toolchain\downloads\` 里那堆压缩包（约 320 MB）可以删掉，
不影响已装好的工具链。

### 方案 B：用已有的 Android Studio

本机已经装了 Android Studio 2026.1.4（`D:\05Software\04tools\Android\Studio`）
和 SDK（`D:\05Software\04tools\Android\SDK`）。

`npm run build:release` 默认用的是便携工具链；想改用系统那份 JDK/SDK，
用 `npm run gradle:debug`，或者在 Android Studio 里直接打开原生工程
（`npm run open:android`）点绿色三角运行。

---

## 2. 每天改功能

> **不想敲命令的话**：双击工程根目录的 `一键编译并安装.bat`，
> 它会依次跑完下面第 2、3 步（编译 → 装到设备），跑完停在窗口让你看结果。
> 桌面上也放了一份副本，直接双击更方便。

### 主循环

| 步骤 | 命令 | 实测耗时 |
| --- | --- | --- |
| 1. 改代码 | 编辑 `www\index.html` 或 `www\native-bridge.js` | — |
| 2. 编译 | `npm run build:release` | **约 40 秒** |
| 3. 装到设备 | `npm run install:release` | **约 2 秒** |

一次改动的完整往返大约 **45 秒**。第一次编译会慢一些（要下 Gradle 和依赖）。

> 为什么装包要额外包一层：本机没把 `adb` 加进 PATH，直接敲 `adb` 会提示找不到命令。
> `npm run install:release` 会自动去几个已知位置找 `adb` 并装上对应的包。
> 如果你希望以后能直接用 `adb`，把它加进用户 PATH 即可：
>
> ```powershell
> [Environment]::SetEnvironmentVariable('PATH',
>   [Environment]::GetEnvironmentVariable('PATH','User') +
>   ';D:\05Software\04tools\Android\SDK\platform-tools', 'User')
> ```

### 几秒钟的快速预览

`www\index.html` 就是一套完整的静态网页，**直接双击用浏览器打开**即可，
改完刷新就能看，不用等编译。

但有两件事要注意：

- 浏览器里的数据和 App 里的**是两份，互不相通**，别在浏览器里录真实数据
- 返回键、导出下载、底部安全区这些**原生行为在浏览器里不生效**，
  必须装到设备上才能验

### 编译产物在哪

```
android\app\build\outputs\
├─ apk\release\app-release.apk      ← 装手机 / 发给别人（已签名）
├─ bundle\release\app-release.aab   ← 上传 Google Play 用
└─ apk\debug\app-debug.apk          ← 调试用
```

### 只想要 debug 包

```powershell
npm run build:debug    # 约 25 秒
```

⚠️ **debug 包和 release 包签名不同，不能互相覆盖安装。**
设备上装的是 release 版时再装 debug 版会报：

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match
```

要换过去必须先卸载再装，而**这会清掉应用内的数据**。
装包脚本失败时会把那条卸载命令原样打给你，复制执行即可。
所以日常测试建议固定用一个 —— 推荐 release，因为最终发的就是它，
而且覆盖安装会保留数据。

### 装到真机

```powershell
# 手机连上电脑并在「开发者选项」里打开 USB 调试
npm run install:release
```

或者直接把 APK 拷进手机点开安装（首次需要在系统设置里允许「安装未知来源应用」）。

### 装到模拟器

双击桌面上的 **`Android模拟器\启动模拟器.bat`**。

**要用它启动**，别从 Android Studio 的 Device Manager 点 ▶。原因是这台机器是
2880x1800 物理屏 + 200% 缩放，逻辑分辨率只有 1440x900，模拟器「自动」模式算出来的
窗口比屏幕高 112px，上下会被切掉。那个 bat 会在启动前写入 `window.scale = 0.31`。

---

## 3. 五种改动分别怎么做

### 3.1 改界面 / 逻辑（绝大多数情况）

改 `www\index.html`。里面就是普通的 HTML + CSS + 一个 `<script>` 块，
写法和原来那个单文件网页完全一样。

改完 → 编译 → 装机，见上一节。

### 3.2 改原生行为（返回键 / 安全区 / 导出下载 / 版本号）

改 `www\native-bridge.js`。这个文件只在 App 里生效，浏览器里没有任何副作用。

| 想改什么 | 改哪个函数 |
| --- | --- |
| 返回键行为 | `window.buHandleBack()` |
| 底部安全区 | `applyInsets()` |
| 导出备份的落盘方式 | `routeBackup()`（走原生 SAF 还是降级到系统分享） |
| 「另存为」对话框本身 | `android\...\MainActivity.java` 的 `BuBridge.saveBackup()` |
| 设置页的版本号显示 | `renderVersion()` |

### 3.3 加原生能力（通知 / 相机 / 文件 / 分享等）

```powershell
cd C:\Users\utgb3\Desktop\temp\apk-build
npm install @capacitor/xxx     # 1. 装插件
#                                2. 改 JS 调用插件 API
npm run build:release          # 3. 编译（内部已含 cap sync，会自动注册插件）
```

部分插件还要在 `android\app\src\main\AndroidManifest.xml` 里加权限声明。

已经装了的插件：

| 插件 | 用途 |
| --- | --- |
| `@capacitor/app` | 应用信息、返回键 |
| `@capacitor/filesystem` | 文件读写（导出备份用） |
| `@capacitor/share` | 系统分享 |
| `@capacitor/splash-screen` | 启动图 |
| `@capacitor/status-bar` | 状态栏配色 |

### 3.4 换图标 / 换配色

图标源图是 **`assets\icon-source.jpg`**。换图就替换这个文件，然后：

```powershell
npm run icons            # 生成 www\icons（PWA 清单用）
npm run android-assets   # 写进 android 的 res（各密度启动图标 + 启动图）
npm run build:release
```

⚠️ 源图的背景色写在 `tools\icon-lib.ps1` 顶部的 `$Script:IconBgTop` /
`$Script:IconBgBottom`。**换了图不改这两行，贴图边缘会露出一圈颜色不同的方块边界。**
取值方法：看源图最上面一行和最下面一行的颜色。

另外注意 `www/icons` 只生成 `manifest.json` 真正引用的 144 / 192 / 512 三个尺寸 ——
多生成的文件会跟着 `www\` 一起打进 APK 白占体积（之前多出的三个文件占了 2.6 MB）。

### 3.5 改数据结构（唯一会丢数据的地方）

应用数据存在 `localStorage` 里。导出备份里有个 `version: 2` —— 那是**数据格式版本**，
和 app 版本、versionCode 完全是两回事。

**规则：每次改数据结构就把这个 version 加 1，写一个对应的迁移函数，
启动时按版本号逐级升级。永远不要直接改老字段的含义。**

代码里已经有先例 —— `migrateWishData()` 就是把老字段 `budget` 升级成 `price` 的：

```js
function migrateWishData(){
  const ws=getWishes(); let wc=false;
  ws.forEach(w=>{
    if(w.price===undefined){w.price=Number(w.budget)||0;wc=true;}
    if(!w.createdAt){w.createdAt=new Date().toISOString();wc=true;}
  });
  if(wc) saveWishes(ws);
}
```

---

## 4. 发版完整流程

```powershell
cd C:\Users\utgb3\Desktop\temp\apk-build
```

| # | 做什么 | 具体操作 |
| --- | --- | --- |
| 1 | 归拢改动记录 | 把 `CHANGELOG.md` 里「未发布」的条目移到新版本号下，写上日期 |
| 2 | 改版本号 | 改 `package.json` 的 `version`（**唯一来源**，别处都不用动） |
| 3 | 编译 | `npm run build:release` |
| 4 | 提交 | `git add -A` ，然后 `git commit -m "发布 1.1.0"` |
| 5 | 打标签 | `git tag v1.1.0` |
| 6 | 推送 | `git push` ，然后 `git push --tags` |
| 7 | 上传产物 | 到 GitHub 的 Releases 页面新建 release，把 APK 传上去 |

第 7 步有一个容易忽略的点：**上传前把 APK 改名带上版本号**，
比如 `bubu-workbench-1.1.0.apk`。默认叫 `app-release.apk`，
存两个星期就分不清哪个包是哪版了。这一步在 GitHub 网页上拖拽上传即可，不用命令行。

### 只给自己或朋友装

跳过第 1、5、7 步也行：2 → 3 → 4 → 6，然后把 APK 拷给对方。

### 加新功能时的小提交

平时改功能不必每次发版，正常提交就行：

```powershell
git add -A
git commit -m "改了什么的简短说明"
git push
```

攒够一批再走上面的发版流程。

---

## 5. 版本号规则

`package.json` 的 `version` 是**唯一来源**，`android\app\build.gradle`
在编译时自动换算成安卓需要的两个值：

| package.json | versionName（给用户看） | versionCode（系统判断新旧） |
| --- | --- | --- |
| `1.0.0` | `"1.0.0"` | `10000` |
| `1.2.3` | `"1.2.3"` | `10203` |

换算规则是 `major*10000 + minor*100 + patch`。

**这个规则不要改。** `versionCode` 必须是单调递增的整数，Google Play 靠它判断新旧，
改了规则可能算出比上一版更小的值，新包就传不上去。
带后缀的版本（如 `1.2.3-beta1`）会先按 `-` 切掉后缀再算。

编译时终端会打印一行给你核对：

```
[version] 1.2.3 (versionCode 10203)
```

App 里的「设置 → 关于」也会显示当前版本，装到手机上可以直接看到装的是哪一版。
这个数字来自 `@capacitor/app` 的 `getInfo()`，是真正装在机器上那个包的版本。

---

## 6. 常用命令速查

全部在 `C:\Users\utgb3\Desktop\temp\apk-build` 目录下执行。

| 命令 | 作用 |
| --- | --- |
| `npm run build:release` | 编译正式包（APK + AAB，已签名），约 40 秒 |
| `npm run build:debug` | 编译 debug 包，约 25 秒 |
| `npm run install:release` | 把 release 包装到连接的设备上 |
| `npm run install:debug` | 把 debug 包装到连接的设备上 |
| `npm run toolchain` | 只装便携工具链，不编译 |
| `npm run sync` | 只把 `www\` 同步进 `android\`（改了网页必须做，上面两条已内含） |
| `npm run icons` | 重新生成 `www\icons` |
| `npm run android-assets` | 重新生成安卓 res 里的图标和启动图 |
| `npm run open:android` | 用 Android Studio 打开原生工程 |
| `npm run gradle:debug` | 用系统自带的 JDK / SDK 编译 |
| `npm run clean` | 清掉安卓编译产物 |

---

## 7. 目录说明

```
apk-build/
├─ www/                      ← 真正的应用代码，平时只改这里
│  ├─ index.html               主页面（由原 HTML 转换而来，改动处有注释标注）
│  ├─ native-bridge.js         原生桥接：返回键 / 安全区 / 导出下载兜底 / 版本号
│  ├─ chart.umd.min.js         Chart.js 本地化，离线可用
│  ├─ version.js               版本号，编译时依据 package.json 自动生成
│  ├─ manifest.json            PWA 清单（保留着，以后网页端也能装）
│  └─ icons/                   PWA 图标（只放 144/192/512，别的会白占 APK 体积）
├─ assets/
│  └─ icon-source.jpg          图标源图（换图标就替换这个文件）
├─ android/                    原生工程（Capacitor 生成，可提交进版本库）
│  ├─ app/build.gradle           应用配置：签名、版本号换算
│  ├─ app/src/main/java/com/bubu/workbench/MainActivity.java
│  │                             原生桥：导出备份时弹系统「另存为」对话框
│  ├─ app/src/main/AndroidManifest.xml   权限、Activity 声明
│  ├─ app/src/main/res/          图标、启动图、字符串
│  ├─ app/bubu-release.jks       ← 签名密钥库，**不在版本库里**
│  └─ keystore.properties        ← 签名口令，**不在版本库里**
├─ tools/
│  ├─ build-apk.ps1            一键装工具链 + 编译（核心脚本）
│  ├─ icon-lib.ps1             图标绘制共用逻辑
│  ├─ make-icons.ps1           生成 www/icons
│  └─ make-android-assets.ps1  写入 android 的 res
├─ capacitor.config.json     应用 ID、名称、启动图、状态栏等
├─ package.json              依赖、快捷命令、**版本号唯一来源**
├─ CHANGELOG.md              更新日志，发版时记一条
├─ .github/workflows/        云端自动编译（见第 8 节说明，暂未纳入版本库）
└─ .toolchain/               便携工具链（约 2.5GB，不进版本库，删掉即净）
```

---

## 8. 签名与发布材料

发布签名**已经配好了**，`npm run build:release` 出来的包直接就是签好的，
不需要再手动走 Android Studio 的 `Build → Generate Signed Bundle`。

| 文件 | 说明 |
| --- | --- |
| `android\app\bubu-release.jks` | 密钥库本体 |
| `android\keystore.properties` | 口令（明文，已被 `.gitignore` 排除） |

证书信息：

- 别名 `bubu`，RSA 2048，有效期 10000 天
- `CN=Bubu Workbench, OU=Personal, O=Bubu, L=Hong Kong, ST=Hong Kong, C=HK`
- SHA-256 指纹 `80:BB:09:BE:F4:56:69:05:67:87:C0:57:03:82:75:80:21:73:EA:79:18:E9:84:83:46:1C:2E:C2:EA:81:6A:D5`

**这两个文件 + 口令必须另外备份一份到别处**（密码管理器 / 网盘 / U 盘）。
`.jks` 丢了就再也无法更新同一个应用 —— 只能换包名重新上架，老用户收不到更新。
`keystore.properties` 丢了不要紧，只要 `.jks` 还在，用 keytool 能重设口令。

`android\app\build.gradle` 里读取这两个文件的那段是**文件不存在就自动跳过**的，
所以别人 clone 下来、或者只跑 debug 构建，都不会因为缺签名文件而报错。

### 云端编译（GitHub Actions）

`.github/workflows/android.yml` **已经启用**：往 `main` 推代码就会在 GitHub 上
自动编译并产出 APK，跑完在构建记录的 **Artifacts** 里下载 `bubu-workbench-debug`。
也可以在仓库的 Actions 页面手动点 **Run workflow** 触发。

好处是本机什么都不用装；代价是每次要推一次仓库、等 3-5 分钟。
本机能 40 秒出包，所以日常还是本地编，云端这条留作备份和「换台电脑也能出包」的兜底。

> **SSH 与令牌的区别**：这个文件一开始推不上去，报的是
> `refusing to allow an OAuth App to create or update workflow ... without 'workflow' scope`。
> 原因是 HTTPS 走的是 Personal Access Token，而那个令牌没有 `workflow` 权限，
> GitHub 不允许它创建 `.github/workflows/` 下的文件。
> **改用 SSH 之后就不受这个限制了** —— SSH 按账号鉴权，不经过令牌的权限体系。

---

## 9. 国内网络适配

这台机器上实测：

| 源 | 结果 |
| --- | --- |
| `maven.google.com` | 连不上（AndroidX / AGP 依赖的来源） |
| `repo1.maven.org` | 连不上（junit、gson 等通用依赖的来源） |
| `dl.google.com` | 能握手，实际下载速度为 0 |
| `services.gradle.org` | 跳转后仍拉不动 |
| `maven.aliyun.com` | **正常** |
| `mirrors.cloud.tencent.com` | **正常**，Gradle 分发 5 MB/s，SDK 清单完整 |

针对它们做了三处替换：

| 位置 | 改了什么 | 为什么 |
| --- | --- | --- |
| `android/build.gradle` | 阿里云 Maven 镜像排在 `google()` / `mavenCentral()` 之前，共三处 | 官方源不可达，镜像能命中就不会去碰它们。顺序反了会卡在连接超时 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 分发地址换成腾讯云镜像 | `services.gradle.org` 太慢 |
| `tools/build-apk.ps1` | 不用 sdkmanager，改为直接从腾讯镜像下 SDK 的 zip | sdkmanager 的包源是 dl.google.com，下不动 |

关于 `buildToolsVersion`：`android/app/build.gradle` 里**没有**写这一项，
是为了让 AGP 用它自带的默认值（当前 35.0.0）。钉死某个版本会让 CI
或换一台机器时因为缺少该特定版本而失败。`tools/build-apk.ps1` 里装的
也是 build-tools 35.0.0，两边保持一致。

另外 `build.gradle` 里的镜像 URL 故意重复写了三次而不是抽成变量 ——
Gradle 的 `buildscript` 块会被提前单独求值，读不到脚本里的局部变量，
写变量名会直接报 `Could not get unknown property`。**改的时候三处一起改。**

Android Studio 那边的镜像配置（SDK 更新源、SDK 基础地址覆盖等）
记在 `C:\Users\utgb3\Desktop\temp\android-studio-mirror\README.md`。

---

## 10. 已知的坑

**数据存在应用内部，卸载或清数据就没了。**
网页用的是 `localStorage`，在 App 里它落在应用私有目录。所以「设置」页的
**导出备份**要定期用。`native-bridge.js` 已经把导出接了原生兜底
（走 Capacitor 文件系统 + 系统分享），在 App 里点导出会真的存下文件，
而不是像裸 WebView 那样点了没反应。

**底部导航条可能压住 TabBar。**
`capacitor.config.json` 里设了 `adjustMarginsForEdgeToEdge: "auto"`，
让 Capacitor 在 Android 15 上自动让出系统栏区域；`native-bridge.js` 另外会
读原生安全区数值写进 CSS 变量 `--bu-safe-b` 兜底。两层保险都失效的话，
把 `"auto"` 改成 `"force"`。

**返回键行为。**
按返回键时：先关弹窗 → 再退回「计划」首页 → 都没有才退出应用。
逻辑在 `native-bridge.js` 的 `window.buHandleBack()`。

**Chart.js 必须保持本地。**
`index.html` 里是从 `./chart.umd.min.js` 加载的，别改回网络地址，
否则离线打开会没有图表。

**网页端仍然可用。**
`www/` 就是一套完整的静态站点，直接双击 `index.html` 也能在浏览器里跑，
`native-bridge.js` 在浏览器里不会有任何副作用。

**PowerShell 脚本必须保持 UTF-8 带 BOM。**
`tools/` 下的 `.ps1` 里有中文，Windows PowerShell 5.1 默认按 GBK 读，
存成无 BOM 的 UTF-8 会直接报语法错误。用编辑器改完注意别把编码改掉。

**`.bat` 文件里不要写中文，也不要用 `chcp`。**
cmd.exe 读批处理用的是控制台代码页，这台机器上 UTF-8 和 GBK 不一致。
更麻烦的是在 `.bat` 里用 `chcp 65001` 换代码页：cmd 的读取偏移会错位，
把后面的行切碎。症状很像玄学 —— 报 `'tle' is not recognized`，
其实是 `title` 那一行被砍成了两截。
所以本项目的 `.bat` 一律只当**纯 ASCII 入口**（`一键编译并安装.bat`、
`启动模拟器.bat` 都是这样），中文提示全部放在对应的 `.ps1` 里。

**别再去改原来的 `卜卜迷你工作台D.html`。**
现在有两份拷贝，`www\index.html` 才是打进 APK 的那份，而且里面多了
本地 Chart.js、`native-bridge.js`、`version.js` 的引入。
继续改原文件的话，得手工把这些同步过去，很容易漏。把它当存档就好。

---

## 11. 故障排查

| 现象 | 原因 / 处理 |
| --- | --- |
| `Task 's' is ambiguous` | `build-apk.ps1` 里任务数组被 PowerShell 拆成了字符串。已修，别再删掉 `[string[]]` 强转 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 设备上是另一个签名的包（debug ↔ release）。按 `install-apk.ps1` 提示的卸载命令先卸掉，注意会清数据 |
| 编译卡在下载 Gradle | 检查 `android\gradle\wrapper\gradle-wrapper.properties` 里的地址是不是腾讯镜像 |
| 解压 SDK 组件报 `being used by another process` | 杀毒软件在扫描刚解压的 exe。脚本已有重试；还不行就关掉实时防护重试一次 |
| `Could not find xxx` 依赖找不到 | 阿里云镜像缺这个包。把 `~\.gradle\init.d\aliyun-mirrors.gradle` 改名成 `.bak` 临时停用，或往镜像列表里加别的源 |
| 模拟器窗口上下被切掉 | 用桌面 `Android模拟器\启动模拟器.bat` 启动，别从 Device Manager 点 ▶ |
| 改完网页但手机上没变化 | 忘了同步。`npm run build:release` 已内含 `cap sync`，直接跑它就行 |
| 设置页版本号显示不出来 | 检查 `www\version.js` 是否存在、`index.html` 里有没有引入它 |
| 推 `main` 报 GitHub 连不上 | `github.com` 的解析 IP 偶发被墙。用 SSH 远程（走 22 端口）比 HTTPS 稳；实在不行过一阵再推 |
| 推 `.github/workflows/` 被拒，提示缺 `workflow` 权限 | HTTPS + 令牌的限制。把远程换成 SSH 即可绕过，见第 8 节 |
