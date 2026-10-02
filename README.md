# 卜卜迷你工作台 · Android 打包工程

把单文件网页 `卜卜迷你工作台D.html` 打包成安卓 App（APK）。
基于 **Capacitor 7**：网页照常写 HTML/CSS/JS，外层套一个原生壳，需要系统能力时再调插件。

原文件 `卜卜迷你工作台D.html` **没有被改动**，改的是复制出来的 `www/index.html`。

远程仓库：https://github.com/Aprilfi/note.git

---

## 出 APK 只需要一条命令

```powershell
npm run build:debug
```

首次执行会自动下载 **便携工具链**（JDK 21 + Android SDK）到 `.toolchain\`，
以及 Gradle 和依赖。全程约 1GB 下载、10～20 分钟，`.toolchain` 占约 2.3GB；
之后每次改代码再跑就只要几十秒。

工具链装在工程目录里，**不写系统环境变量、不装 Android Studio**，删掉 `.toolchain\` 就等于没装过。
想顺手清掉下载缓存腾出 300MB：删 `.toolchain\downloads\` 即可，不影响已装好的工具链。

产物位置：

```
android\app\build\outputs\apk\debug\app-debug.apk
```

（已经跑通过一次，当前这个包是 4.68 MB，用的是 Android 默认 debug 签名。）

装机：手机连电脑后 `adb install -r <apk路径>`，或直接把 apk 拷进手机点开安装
（首次需要在系统设置里允许「安装未知来源应用」）。

### 不想在本机下载这 1GB？

推到 GitHub，用云端编译。仓库的 Actions 页面会自动跑，跑完在构建记录的
**Artifacts** 里下载 `bubu-workbench-debug`。代价是每次改代码要推一次仓库、等 3～5 分钟。

---

## 目录说明

```
apk-build/
├─ www/                      ← 真正的应用代码，平时只改这里
│  ├─ index.html               主页面（由原 HTML 转换而来，改动处有注释标注）
│  ├─ native-bridge.js         原生桥接：返回键 / 安全区 / 导出下载兜底
│  ├─ chart.umd.min.js         Chart.js 本地化，离线可用
│  ├─ manifest.json            PWA 清单（保留着，以后网页端也能装）
│  └─ icons/                   图标与启动图
├─ android/                  原生工程（Capacitor 生成，可提交进版本库）
├─ tools/
│  ├─ build-apk.ps1            一键装工具链 + 编译
│  ├─ make-icons.ps1           生成 www/icons 下的图标与启动图
│  └─ make-android-assets.ps1  把图标/启动图按密度写进 android 的 res 目录
├─ capacitor.config.json     应用 ID、名称、启动图、状态栏等
├─ package.json              依赖与快捷命令
└─ .github/workflows/        云端自动编译
```

---

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `npm run build:debug` | 装工具链（首次）+ 编译 debug APK |
| `npm run build:release` | 编译正式签名包（APK + AAB） |
| `npm run toolchain` | 只装工具链，不编译 |
| `npm run sync` | 把 `www/` 同步进 `android/`（改了网页后必须跑） |
| `npm run icons` | 重新生成 `www/icons/` 下的图标 |
| `npm run android-assets` | 重新生成安卓 res 里的图标和启动图 |
| `npm run gradle:debug` | 用系统自带的 JDK/SDK 编译（已装 Android Studio 时用） |
| `npm run open:android` | 用 Android Studio 打开原生工程 |

---

## 日常开发流程

改了 `www/` 里的任何文件之后，必须同步到安卓工程，否则手机上看到的还是旧版本。
`npm run build:debug` 已经内含同步，单独同步用 `npm run sync`。

### 需要改安卓原生部分时

比如加权限、改 Activity 行为、接原生 SDK：

```bash
npm run open:android     # 用 Android Studio 打开 android/
```

这种情况建议还是装一个 Android Studio，编辑 XML/Gradle 和看日志会舒服很多
（装了之后把 `npm run gradle:debug` 换回用系统的 JDK 即可，`.toolchain` 可以留着不用）。

---

## 换配色 / 换图标

两个脚本开头的 `$C_BG_TOP`、`$C_BG_BOT`、`$GLYPH` 是唯二需要改的地方：

```powershell
npm run icons            # 重新生成 www/icons
npm run android-assets   # 重新写入 android 的 res
npm run build:debug
```

`android-assets` 会自动处理：各密度的传统图标、圆形图标、自适应图标的前景+背景分层、
以及 11 个尺寸的启动图。改完不用手动碰 `res/` 目录。

---

## 签名

发布签名**已经配好了**，直接出正式包：

```powershell
npm run build:release
```

一次产出两个文件：

| 产物 | 用途 |
| --- | --- |
| `android\app\build\outputs\apk\release\app-release.apk` | 直接装手机、发给别人 |
| `android\app\build\outputs\bundle\release\app-release.aab` | 上传 Google Play 用 |

两个都用正式密钥签好了，不需要再手动 `Build → Generate Signed Bundle`。

### 签名材料在哪

| 文件 | 说明 |
| --- | --- |
| `android/app/bubu-release.jks` | 密钥库本体 |
| `android/keystore.properties` | 口令（明文，已被 `.gitignore` 排除） |

证书信息：

- 别名 `bubu`，RSA 2048，有效期 10000 天
- `CN=Bubu Workbench, OU=Personal, O=Bubu, L=Hong Kong, ST=Hong Kong, C=HK`
- SHA-256 指纹 `80:BB:09:BE:F4:56:69:05:67:87:C0:57:03:82:75:80:21:73:EA:79:18:E9:84:83:46:1C:2E:C2:EA:81:6A:D5`

**这两个文件 + 口令必须另外备份一份到别处（密码管理器 / 网盘 / U 盘）。**
`.jks` 丢了就再也无法更新同一个应用 —— 只能换新包名重新上架，老用户收不到更新。
`keystore.properties` 丢了，只要 `.jks` 还在，可以用 keytool 重设口令。

`android/app/build.gradle` 里读取这两个文件的那段是**文件不存在就自动跳过**的，
所以别人 clone 下来、或者只跑 debug 构建，都不会因为缺签名文件而报错。

要上 Google Play 还需要 `targetSdk` 跟上 Google 当年的要求（当前已是 35）。

---

## 几个必须知道的坑

**这套配置是按「国内网络」调过的，改动集中在三处，换网络环境前先看这里。**

这台机器上实测：`maven.google.com`、`repo1.maven.org` 完全连不上，
`dl.google.com` 能做 HEAD 请求但实际下载速度为 0（sdkmanager 因此不可用）。
针对它们做了如下处理：

| 位置 | 改了什么 | 为什么 |
| --- | --- | --- |
| `android/build.gradle` | 阿里云 Maven 镜像排在 `google()` / `mavenCentral()` 之前，共三处 | 官方源不可达，镜像能命中就不会去碰它们。仓库顺序反过来会卡在连接超时 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 分发地址换成腾讯云镜像 | `services.gradle.org` 太慢 |
| `tools/build-apk.ps1` | 不用 sdkmanager，改为直接从腾讯镜像下 SDK 的 zip | sdkmanager 的包源是 dl.google.com，下不动 |

关于 `buildToolsVersion`：`android/app/build.gradle` 里目前写着 `"34.0.0"`，
这是搭建时按腾讯镜像下的 build-tools 版本钉的。后来确认镜像上其实也有
35 / 36 / 37（只是文件名用的是下划线，`build-tools_r35_windows.zip`，
当时按连字符探测所以漏了）。所以这行不是必须的 —— 想升到 AGP 8.7 默认的
35.0.0，把 build-tools 35 下下来、删掉这行即可。

另外 `build.gradle` 里的镜像 URL 故意重复写了三次而不是抽成变量 ——
Gradle 的 `buildscript` 块会被提前单独求值，读不到脚本里的局部变量，
写变量名会直接报 `Could not get unknown property`。改的时候三处一起改。

**数据存在应用内部，卸载或清数据就没了。**
网页用的是 `localStorage`，在 App 里它落在应用私有目录。所以「设置」页的**导出备份**要定期用。
`native-bridge.js` 已经把导出接了原生兜底（走 Capacitor 文件系统 + 系统分享），
在 App 里点导出会真的存下文件，而不是像裸 WebView 那样点了没反应。

**底部导航条可能压住 TabBar。**
`capacitor.config.json` 里设了 `adjustMarginsForEdgeToEdge: "auto"`，
让 Capacitor 在 Android 15 上自动让出系统栏区域；`native-bridge.js` 另外会读原生安全区数值
写进 CSS 变量 `--bu-safe-b` 兜底。两层保险都失效的话，把 `"auto"` 改成 `"force"`。

**返回键行为。**
按返回键时：先关弹窗 → 再退回「计划」首页 → 都没有才退出应用。
逻辑在 `native-bridge.js` 的 `window.buHandleBack()`，想改直接改这个函数。

**Chart.js 必须保持本地。**
`index.html` 第 7 行已从 CDN 改成 `./chart.umd.min.js`。别改回网络地址，否则离线打开没有图表。

**网页端仍然可用。**
`www/` 就是一套完整的静态站点，直接双击 `index.html` 也能在浏览器里跑，
`native-bridge.js` 在浏览器里不会有任何副作用。

**PowerShell 脚本必须保持 UTF-8 带 BOM。**
`tools/` 下的 `.ps1` 里有中文，Windows PowerShell 5.1 默认按 GBK 读，
存成无 BOM 的 UTF-8 会直接报语法错误。用编辑器改完注意别把编码改掉。
## 版本管理

### 日常提交

```powershell
cd C:\Users\utgb3\Desktop\temp\apk-build
git add -A
git commit -m "改了什么"
git push
```

`node_modules`、`.toolchain`（2.3GB）、构建产物、签名文件都已被 `.gitignore` 排除，
整个仓库只有 **约 1.2 MB**，随便提交。

### 版本号只改一处

`package.json` 的 `version` 是**唯一来源**，`android/app/build.gradle` 会自动换算：

| package.json | versionName | versionCode |
| --- | --- | --- |
| `1.0.0` | `"1.0.0"` | `10000` |
| `1.2.3` | `"1.2.3"` | `10203` |

换算规则是 `major*10000 + minor*100 + patch`。**这个规则不要改** ——
`versionCode` 必须是单调递增的整数，Google Play 靠它判断新旧，
改了规则可能算出比上一版更小的值，新包就传不上去。
带后缀的版本（如 `1.2.3-beta1`）会先按 `-` 切掉后缀再算。

### 发一个版本

```powershell
# 1. 改 package.json 里的 version
# 2. 编译
npm run build:release
# 3. 提交并打标签
git add -A
git commit -m "发布 1.1.0"
git tag v1.1.0
git push
git push --tags
# 4. 到 GitHub 的 Releases 页面把 APK 传上去
```

产物文件名默认是 `app-release.apk`，**传到 Release 时记得改名带上版本号**
（如 `bubu-workbench-1.1.0.apk`），否则过两周就分不清哪个包是哪版了。

### 凭据与权限（重要）

凭据由 Git Credential Manager 管理，里面存的是一个 **Personal Access Token**。

**当前这个令牌没有 `workflow` 权限**，所以 `.github/workflows/` 下的文件推不上去。
这就是 `.github/workflows/android.yml`（云端编译配置）暂时没进版本库的原因 ——
文件还在本地磁盘上，没被删除。要启用云端编译，二选一：

1. 到 GitHub 新建一个勾选 `workflow` 权限的令牌，然后
   `git-credential-manager github logout`，再 push 一次重新登录；
2. 或者直接在 GitHub 网页上新建这个文件（网页端不受该限制）。

之后 `git add .github && git commit -m "加上云端编译" && git push` 即可。

### 数据格式版本（和 app 版本是两回事）

应用数据存在 `localStorage` 里，导出的备份文件里有个 `version: 2` ——
这是**数据格式**版本，和上面说的 app 版本、versionCode 完全无关。

改数据结构（加字段、改字段名、改嵌套）时，用户机器上那份老数据会读不出来。
代码里已经有先例：`migrateWishData()` 就是把老字段 `budget` 升级成 `price` 的。

规则：**每次改数据结构就把备份格式的 version 加 1，写一个对应的迁移函数，
启动时按版本号逐级升级。永远不要直接改老字段的含义。**
这是唯一一处改错了会丢数据的地方。

---

