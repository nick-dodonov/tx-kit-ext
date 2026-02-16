"""Bazel aspect for inspecting target information.

Usage:
    bazel build //path/to:target --aspects=@tx-kit-ext//aspects:inspect.bzl%inspect_aspect
"""

def _log(message):
    _YELLOW = "\033[1;33m"
    _RESET = "\033[0m"
    print("\n" + _YELLOW + message + _RESET)  # buildifier: disable=print

def _inspect_aspect_impl(target, ctx):
    _log("""target: {}
    label: {}
""".format(target, target.label).strip())
    _log("ctx: " + str(ctx))

    output_groups = {}
    if OutputGroupInfo in target:
        og = target[OutputGroupInfo]
        output_groups = dir(og)
    _log("Output groups: {}".format(output_groups if output_groups else "None"))

    return []

inspect_aspect = aspect(
    implementation = _inspect_aspect_impl,
)
