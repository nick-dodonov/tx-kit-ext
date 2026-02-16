import os
from pathlib import Path

# https://pypi.org/project/bazel-runfiles/#description
try:
    # for deps = ["@rules_python//python/runfiles"]
    from python.runfiles import Runfiles  # pyright: ignore[reportMissingImports]
except ImportError:
    # for deps = [requirement("bazel-runfiles")]
    from runfiles import Runfiles

from . import log


class Finder:
    def __init__(self):
        self.runfiles = Runfiles.Create()

    def find_file(self, file: Path) -> tuple[Path | None, str]:
        if file.exists():
            return file, "CWD"

        build_working_dir = os.environ.get("BUILD_WORKING_DIRECTORY")
        if build_working_dir:
            candidate = Path(build_working_dir) / file
            if candidate.exists():
                return candidate, "BUILD_WORKING_DIRECTORY"

        # Try runfiles
        if self.runfiles:
            rlocation = self.runfiles.Rlocation(str(file))
            if rlocation:
                rlocation_path = Path(rlocation)
                if rlocation_path.exists():
                    return rlocation_path, "<RUNFILES>"

        return None, "<NOT FOUND>"

    def find_file_logged(self, file: Path) -> Path | None:
        found_file, found_in = self.find_file(file)
        if found_file:
            log.trace(f"  Found: {found_file} # {found_in}")
        return found_file
