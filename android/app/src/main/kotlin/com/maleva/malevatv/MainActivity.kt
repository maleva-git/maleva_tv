package com.maleva.malevatv

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep TV screen on while app is running
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        useHighestResolution()
    }

    /**
     * Many TVs run their UI at 1080p and upscale it to the 4K / 8K panel, which makes text soft.
     * Ask for the panel's largest display mode (same refresh rate where possible) so the board
     * is drawn at full resolution. TVs that do not offer a larger mode keep the current one.
     */
    private fun useHighestResolution() {
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay)
            ?: return
        val current = display.mode
        val best = display.supportedModes.maxWithOrNull(
            compareBy<android.view.Display.Mode> { it.physicalWidth.toLong() * it.physicalHeight }
                .thenBy { -abs(it.refreshRate - current.refreshRate) }
        ) ?: return
        if (best.modeId != current.modeId) {
            window.attributes = window.attributes.apply { preferredDisplayModeId = best.modeId }
        }
    }
}
