"""Build definitions for tx_binary rule (cc_binary wrapper w/ default build settings for multi-platform runs)."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("//runner:defs.bzl", "run_wrapper")
load(":tx_common.bzl", "tx_cc")

#TODO: try rewrite using Symbolic Macro https://bazel.build/versions/9.0.0/extending/macros
def tx_binary(name, **kwargs):
    """Creates a multi-platform binary target w/ default tx build options and runner.

    Args:
        name: The name of the target.
        **kwargs: Additional keyword arguments passed to cc_binary.
    """
    bin_name = name
    cc_binary(
        name = bin_name,
        copts = tx_cc.get_copts(kwargs.pop("copts", [])),
        cxxopts = tx_cc.get_cxxopts(kwargs.pop("cxxopts", [])),
        linkopts = tx_cc.get_linkopts(kwargs.pop("linkopts", [])),
        #TODO: research is it required: stamp = kwargs.pop("stamp", 1),
        **kwargs
    )

    run_wrapper(
        name = "{}.run".format(name),
        target_binary = ":{}".format(bin_name),
        platform = select({
            "@platforms//cpu:wasm32": "wasm",
            "//conditions:default": "auto",
        }),
        visibility = kwargs.get("visibility", ["//visibility:public"]),
    )

    # py_binary(
    #     name = run_name,
    #     srcs = [Label("//rules/build:runner.py")],
    #     main = "runner.py",
    #     # https://github.com/bazel-contrib/rules_python/tree/main/python/runfiles
    #     deps = ["@rules_python//python/runfiles"],
    #     # https://bazel.build/reference/be/make-variables
    #     data = [":{}".format(bin_name)],
    #     args = [
    #         "$(rlocationpath :{})".format(bin_name)
    #     ] + select({
    #         "@platforms//cpu:wasm32": ["--platform=wasm"],
    #         "//conditions:default": [],
    #     }),
    #     visibility = kwargs.get("visibility", ["//visibility:public"]),
    #     # target_compatible_with = select({
    #     #     "@platforms//cpu:wasm32": [],
    #     #     "//conditions:default": ["@platforms//:incompatible"],
    #     # }),
    # )
