package io.github.yoisakiknd.pixora

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    private fun preferHighestRefreshRate() {
        val currentDisplay = windowManager.defaultDisplay
        val currentMode = currentDisplay.mode
        val preferredMode = currentDisplay.supportedModes
            .asSequence()
            .filter {
                it.physicalWidth == currentMode.physicalWidth &&
                    it.physicalHeight == currentMode.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: return
        val attributes = window.attributes
        attributes.preferredDisplayModeId = preferredMode.modeId
        attributes.preferredRefreshRate = preferredMode.refreshRate
        window.attributes = attributes
    }
}
