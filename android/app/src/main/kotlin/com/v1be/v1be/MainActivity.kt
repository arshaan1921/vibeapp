package com.v1be.v1be

import android.os.Bundle
import android.graphics.Color
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // ✅ Official Android Edge-to-Edge implementation for standard Activities.
        // This achieves the same result as enableEdgeToEdge() without requiring ComponentActivity.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Ensure system bars are transparent to allow full edge-to-edge display.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        super.onCreate(savedInstanceState)
    }
}
