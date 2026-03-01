package tx;

import android.app.Activity;
import android.app.NativeActivity;
import android.os.Bundle;
import android.util.Log;

public class DroidActivity extends NativeActivity {
    final String TAG = "droid.M";

    private int exitCode = 128; // default to signal 128 for unknown exit code

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

    /// Returns tx.argv from Intent, or null if not present. Called from native.
    public String getArgvString() {
        android.content.Intent intent = getIntent();
        return intent != null ? intent.getStringExtra("tx.argv") : null;
    }
}
