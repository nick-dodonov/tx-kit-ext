import os
from pathlib import Path

# https://pypi.org/project/bazel-runfiles/#description
try:
    # for deps = ["@rules_python//python/runfiles"]
    from python.runfiles import Runfiles  # pyright: ignore[reportMissingImports]
except ImportError:
    # for deps = [requirement("bazel-runfiles")]
    from runfiles import Runfiles


class Finder:
    def __init__(self):
        self.runfiles = Runfiles.Create()

    def find_file(self, file: Path) -> tuple[Path | None, str]:
        if file.exists():
            return file, "CWD"

        env_keys = [
            "BUILD_WORKING_DIRECTORY",
            "BUILD_WORKSPACE_DIRECTORY",
        ]

        for env_key in env_keys:
            env_dir = os.environ.get(env_key)
            if env_dir:
                candidate = Path(env_dir) / file
                if candidate.exists():
                    return candidate, env_key

        # Try runfiles
        if self.runfiles:
            rlocation = self.runfiles.Rlocation(str(file))
            if rlocation:
                rlocation_path = Path(rlocation)
                if rlocation_path.exists():
                    return rlocation_path, "<RUNFILES>"

        return None, "<NOT FOUND>"
