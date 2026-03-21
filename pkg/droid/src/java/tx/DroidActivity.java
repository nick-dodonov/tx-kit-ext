package tx;

import android.app.Activity;
import android.app.NativeActivity;
import android.os.Bundle;
import android.util.Log;

public class DroidActivity extends NativeActivity {
    final String TAG = "glue.A";

    private int exitCode = 128; // default to signal 128 for unknown exit code

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.v(TAG, "onCreate");
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onDestroy() {
        Log.v(TAG, "onDestroy");
        super.onDestroy();

        //TODO: configurable: required for current droid.py runner implementation to detect finish now
        System.exit(exitCode);
    }

    @Override
    protected void onStart() {
        Log.v(TAG, "onStart");
        super.onStart();
    }

    @Override
    protected void onStop() {
        Log.v(TAG, "onStop");
        super.onStop();
    }

    /// Called from native glue to pass main() result before finish.
    public void finishProcess(int exitCode) {
        Log.v(TAG, String.format("finishProcess: %d", exitCode));
        this.exitCode = exitCode;
        this.finish();
    }

    /// Returns tx.argv from Intent, or null if not present. Called from native.
    public String getArgvString() {
        android.content.Intent intent = getIntent();
        return intent != null ? intent.getStringExtra("tx.argv") : null;
    }
}
