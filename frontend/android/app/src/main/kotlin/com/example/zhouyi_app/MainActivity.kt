package com.example.zhouyi_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "zhouyi/social_auth"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingProvider: String? = null
    private var latestAuthCode: String? = null
    private var latestProvider: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loginWithWechat" -> requestSocialAuth("wechat", result)
                    "loginWithQQ" -> requestSocialAuth("qq", result)
                    "loginWithDouyin" -> requestSocialAuth("douyin", result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthCallbackIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // Handle callback when app is resumed by deep link.
        handleAuthCallbackIntent(intent)
    }

    private fun requestSocialAuth(provider: String, result: MethodChannel.Result) {
        // Fast path: callback already arrived.
        if (latestAuthCode != null && latestProvider == provider) {
            result.success(latestAuthCode)
            latestAuthCode = null
            latestProvider = null
            return
        }

        if (pendingResult != null) {
            result.error("BUSY", "EN。", null)
            return
        }

        pendingProvider = provider
        pendingResult = result

        // Preferred: third-party SDK should be integrated here and return auth code.
        // MVP fallback: open backend OAuth authorization URL and receive app deep-link callback.
        val oauthBase = BuildConfig.SOCIAL_OAUTH_BASE_URL
        val appScheme = BuildConfig.SOCIAL_AUTH_SCHEME
        if (oauthBase.isBlank() || appScheme.isBlank()) {
            finishWithError(
                "SDK_NOT_CONFIGURED",
                "ENSDKENOAuthEN，EN SOCIAL_OAUTH_BASE_URL EN SOCIAL_AUTH_SCHEME。"
            )
            return
        }

        val callback = "$appScheme://social-auth/callback?provider=$provider"
        val authUri = Uri.parse(oauthBase).buildUpon()
            .appendPath(provider)
            .appendQueryParameter("redirect_uri", callback)
            .build()

        runCatching {
            startActivity(Intent(Intent.ACTION_VIEW, authUri))
        }.onFailure {
            finishWithError("LAUNCH_FAILED", "EN。")
        }
    }

    private fun handleAuthCallbackIntent(intent: Intent?) {
        val data = intent?.data ?: return
        val provider = data.getQueryParameter("provider")?.trim().orEmpty()
        val code = data.getQueryParameter("code")?.trim().orEmpty()
        if (provider.isEmpty() || code.isEmpty()) return

        latestProvider = provider
        latestAuthCode = code

        val expect = pendingProvider
        val result = pendingResult
        if (result != null && expect == provider) {
            result.success(code)
            pendingProvider = null
            pendingResult = null
            latestProvider = null
            latestAuthCode = null
        }
    }

    private fun finishWithError(code: String, message: String) {
        pendingResult?.error(code, message, null)
        pendingResult = null
        pendingProvider = null
    }
}
