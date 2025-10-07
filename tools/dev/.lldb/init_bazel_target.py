import os
import datetime
# https://lldb.llvm.org/python_api/lldb.SBDebugger.html
# to support code completion setup used lldb package, e.g., for CLion w/ .venv python interpreter:
# ln -s "/Users/nik/Applications/CLion 2025.3 EAP.app/Contents/bin/lldb/mac/x64/LLDB.framework/Resources/Python/lldb" .venv/lib/python3.13/site-packages/lldb
import lldb

print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] === Load {__file__}")
print(f"LLDB package: {lldb.__path__}")

#TODO: add relative paths too
#setting append target.source-map . /Users/nik/p/t/tx/tx-pkg-misc
#setting append target.source-map external /Users/nik/p/t/tx/tx-pkg-misc/bazel-tx-pkg-misc/external
#TODO: adopt to current target's module name
#TODO: adopt to real externals (local --override_module) instead of symlinked ones
_external_src = '/Users/nik/p/t/tx/tx-pkg-misc/external'
_external_dst = '/Users/nik/p/t/tx/tx-pkg-misc/bazel-tx-pkg-misc/external'
lldb.debugger.HandleCommand(f'settings append target.source-map {_external_src} {_external_dst}')
