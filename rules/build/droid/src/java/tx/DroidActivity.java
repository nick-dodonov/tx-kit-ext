package tx;

import android.app.Activity;
import android.app.NativeActivity;
import android.os.Bundle;
import android.util.Log;

public class DroidActivity extends NativeActivity {
    final String TAG = "droid.M";

    private int exitCode = 0;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "onCreate");
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onDestroy() {
        Log.d(TAG, "onDestroy");
        super.onDestroy();
        System.exit(exitCode);
    }

    /// Called from native glue to pass main() result before finish.
    public void setExitCode(int code) {
        exitCode = code;
    }
}
