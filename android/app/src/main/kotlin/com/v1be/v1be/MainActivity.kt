package com.v1be.v1be

import android.os.Bundle
import android.graphics.Color
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // ✅ Enable modern edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Ensure transparent bars on older Android versions
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        super.onCreate(savedInstanceState)
    }
}
