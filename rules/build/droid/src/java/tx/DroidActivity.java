package tx;

import android.app.Activity;
import android.app.NativeActivity;
import android.os.Bundle;
import android.util.Log;

public class DroidActivity extends NativeActivity {
    final String TAG = "droid.M";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "onCreate");
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onDestroy() {
        Log.d(TAG, "onDestroy");
        super.onDestroy();
        System.exit(0);
    }

    public static void finishOnUiThread(Activity activity) {
        activity.runOnUiThread(activity::finish);
    }
}
