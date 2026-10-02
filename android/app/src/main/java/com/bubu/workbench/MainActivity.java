package com.bubu.workbench;

import android.net.Uri;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;

import com.getcapacitor.BridgeActivity;

import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/**
 * 应用主 Activity。
 *
 * 除了 Capacitor 默认的行为，这里额外给网页挂了一个原生能力：
 *
 *     window.AndroidBu.saveBackup(name, text)
 *
 * 它会弹安卓标准的「另存为」对话框（SAF 的 ACTION_CREATE_DOCUMENT），
 * 让用户自己挑文件夹、改文件名，然后把备份文本写进去。
 *
 * 为什么不直接用 @capacitor/filesystem：那个插件只支持 App 私有目录
 * （DOCUMENTS / DATA / LIBRARY / CACHE），写进去用户在外面翻不到；
 * 原先的补救办法是再调一次系统分享把文件发出去，但分享面板里有没有
 * 「保存到本机」取决于设备装了哪些 App —— 裸模拟器上就没有这一项。
 * SAF 是安卓系统自带的（com.android.documentsui），什么设备上都有。
 */
public class MainActivity extends BridgeActivity {

    /** 用户还在挑选保存位置时，先把待写入的内容暫存在这里 */
    private String pendingBackupText = null;

    /** 系统「另存为」对话框。必须在本 Activity 启动前注册，所以放在 onCreate 里。 */
    private ActivityResultLauncher<String> saveDocumentLauncher;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // CreateDocument 的泛型参数就是「建议的文件名」，返回的是用户选定的 Uri
        saveDocumentLauncher = registerForActivityResult(
                new ActivityResultContracts.CreateDocument("text/plain"),
                uri -> {
                    String text = pendingBackupText;
                    pendingBackupText = null;
                    if (uri != null && text != null) {
                        notifyWeb(writeTextToUri(uri, text));
                    }
                    // uri 为 null 表示用户点了取消，不打扰他
                });

        // 把原生对象挂到 WebView 上，网页里即可用 window.AndroidBu
        if (getBridge() != null && getBridge().getWebView() != null) {
            getBridge().getWebView().addJavascriptInterface(new BuBridge(), "AndroidBu");
        }
    }

    /** 暴露给网页的对象。方法必须加 @JavascriptInterface 才会被调用。 */
    private class BuBridge {

        @JavascriptInterface
        public void saveBackup(String fileName, String text) {
            // 这个回调跑在 WebView 的线程上，弹对话框必须切回主线程
            runOnUiThread(() -> {
                pendingBackupText = text;
                try {
                    // 传进去的是预填的文件名，用户可以改
                    saveDocumentLauncher.launch(fileName);
                } catch (Exception e) {
                    // 极端情况（设备连文件选择器都没有），放弃并如实回报
                    pendingBackupText = null;
                    notifyWeb(false);
                }
            });
        }
    }

    /** 把文本写进用户选定的 URI。返回是否成功。 */
    private boolean writeTextToUri(Uri uri, String text) {
        // "wt" = write + truncate，保证覆盖旧内容而不是接在后面
        try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
            if (out == null) return false;
            out.write(text.getBytes(StandardCharsets.UTF_8));
            out.flush();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /** 把结果回报给网页，让界面能给用户一个明确的提示。 */
    private void notifyWeb(boolean ok) {
        try {
            WebView wv = (getBridge() != null) ? getBridge().getWebView() : null;
            if (wv == null) return;
            String js = "window.__buSaveResult && window.__buSaveResult(" + (ok ? "true" : "false") + ")";
            wv.post(() -> wv.evaluateJavascript(js, null));
        } catch (Exception ignored) {
            // 回报失败不影响主流程
        }
    }
}
