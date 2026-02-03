import sys
import runner.wasm

if __name__ == "__main__":
    # TODO: pass TESTBRIDGE_TEST_ONLY environment variable to executor supporting bazel run/test --test_filter=
    #   https://bazel.build/reference/test-encyclopedia
    sys.exit(runner.wasm.main(sys.argv[1:]))
