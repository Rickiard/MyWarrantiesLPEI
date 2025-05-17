package com.example.mywarranties;

import android.graphics.Bitmap;
import android.app.Notification.BigPictureStyle;

public class NotificationStyleHelper {
    public static void setBigLargeIcon(BigPictureStyle style, Bitmap bitmap) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            style.bigLargeIcon(bitmap);
        } else {
            style.bigLargeIcon(bitmap);
        }
    }
} 