package com.rankscope.app

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHighRefreshRate()
    }

    override fun onPostResume() {
        super.onPostResume()
        setHighRefreshRate()
    }

    private fun setHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val currentDisplay = display ?: return
            val modes = currentDisplay.supportedModes
            var maxMode: Display.Mode? = null
            var maxRate = 0f
            for (mode in modes) {
                if (mode.refreshRate > maxRate) {
                    maxRate = mode.refreshRate
                    maxMode = mode
                }
            }
            if (maxMode != null && maxRate >= 90f) {
                val params = window.attributes
                params.preferredDisplayModeId = maxMode.modeId
                window.attributes = params
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            @Suppress("DEPRECATION")
            val currentDisplay = windowManager.defaultDisplay ?: return
            val modes = currentDisplay.supportedModes
            var maxMode: Display.Mode? = null
            var maxRate = 0f
            for (mode in modes) {
                if (mode.refreshRate > maxRate) {
                    maxRate = mode.refreshRate
                    maxMode = mode
                }
            }
            if (maxMode != null && maxRate >= 90f) {
                val params = window.attributes
                params.preferredDisplayModeId = maxMode.modeId
                window.attributes = params
            }
        }
    }
}
