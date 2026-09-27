package com.mrkoko.signalpro;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.Intent;
import android.graphics.Path;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.util.Log;

public class MarketAccessibilityService extends AccessibilityService {

    private static final String TAG = "MRKOKOAccessibility";
    private static MarketAccessibilityService instance;
    private boolean isScrolling = false;
    private Handler handler = new Handler(Looper.getMainLooper());
    private int screenWidth  = 1080;
    private int screenHeight = 2400;
    private int scrollStep   = 0;
    private static final int MAX_SCROLL_STEPS = 20; // scroll 20 times to cover full chart history
    private Runnable scrollRunnable;

    public static MarketAccessibilityService getInstance() { return instance; }

    @Override
    public void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
        screenWidth  = getResources().getDisplayMetrics().widthPixels;
        screenHeight = getResources().getDisplayMetrics().heightPixels;
        Log.d(TAG, "Accessibility service connected. Screen: " + screenWidth + "x" + screenHeight);

        // notify Flutter
        Intent intent = new Intent("com.mrkoko.ACCESSIBILITY_CONNECTED");
        sendBroadcast(intent);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // capture window state changes (market opened)
        if (event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            String pkg = event.getPackageName() != null ? event.getPackageName().toString() : "";
            Log.d(TAG, "Window changed: " + pkg);
            Intent intent = new Intent("com.mrkoko.WINDOW_CHANGED");
            intent.putExtra("package", pkg);
            sendBroadcast(intent);
        }
    }

    @Override
    public void onInterrupt() {
        isScrolling = false;
        Log.d(TAG, "Service interrupted");
    }

    // Called from Flutter to start auto-scrolling through chart history
    public void startChartScan() {
        if (isScrolling) return;
        isScrolling = true;
        scrollStep  = 0;
        Log.d(TAG, "Starting chart scan scroll");

        scrollRunnable = new Runnable() {
            @Override
            public void run() {
                if (!isScrolling || scrollStep >= MAX_SCROLL_STEPS) {
                    isScrolling = false;
                    // notify Flutter scan scroll complete
                    Intent done = new Intent("com.mrkoko.SCROLL_DONE");
                    done.putExtra("steps", scrollStep);
                    sendBroadcast(done);
                    return;
                }
                performChartSwipe();
                scrollStep++;
                // wait 800ms between swipes for capture
                handler.postDelayed(this, 800);
            }
        };
        handler.post(scrollRunnable);
    }

    public void stopChartScan() {
        isScrolling = false;
        if (scrollRunnable != null) handler.removeCallbacks(scrollRunnable);
    }

    // Swipe right → reveals older candles (chart scrolls left showing history)
    private void performChartSwipe() {
        int y      = screenHeight / 2;
        int startX = (int)(screenWidth * 0.25f);
        int endX   = (int)(screenWidth * 0.85f);

        Path path = new Path();
        path.moveTo(startX, y);
        path.lineTo(endX, y);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(new GestureDescription.StrokeDescription(path, 0, 350));

        dispatchGesture(builder.build(), new GestureResultCallback() {
            @Override
            public void onCompleted(GestureDescription gestureDescription) {
                Log.d(TAG, "Swipe " + scrollStep + " completed");
                Intent intent = new Intent("com.mrkoko.SWIPE_DONE");
                intent.putExtra("step", scrollStep);
                sendBroadcast(intent);
            }
            @Override
            public void onCancelled(GestureDescription gestureDescription) {
                Log.d(TAG, "Swipe cancelled");
            }
        }, null);
    }

    @Override
    public void onDestroy() {
        instance = null;
        isScrolling = false;
        super.onDestroy();
    }
}
