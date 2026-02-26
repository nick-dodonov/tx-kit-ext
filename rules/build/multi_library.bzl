"""Build rule for creating multi-platform cc_library for host, wasm, and android.

Creates platform-specific cc_library targets with suffixes (-host, -wasm, -droid)
so build outputs are separated. An alias selects the appropriate variant based on
the current --platforms configuration.
"""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load(":tx_common.bzl", "tx_cc")


def _multi_library_impl(name, visibility, **kwargs):
    # multi_library manages target_compatible_with itself
    if kwargs.pop("target_compatible_with", None) != None:
        fail("multi_library does not support target_compatible_with attribute")

    kwargs["copts"] = tx_cc.get_copts(kwargs.pop("copts", []))
    kwargs["cxxopts"] = tx_cc.get_cxxopts(kwargs.pop("cxxopts", []))

    # Host: exclude wasm and android
    host_kwargs = dict(kwargs)
    host_kwargs["target_compatible_with"] = select({
        "@platforms//cpu:wasm32": ["@platforms//:incompatible"],
        "@platforms//os:android": ["@platforms//:incompatible"],
        "//conditions:default": [],
    })
    cc_library(
        name = "{}-host".format(name),
        visibility = visibility,
        **host_kwargs,
    )

    # WASM
    wasm_kwargs = dict(kwargs)
    wasm_kwargs["target_compatible_with"] = ["@platforms//cpu:wasm32"]
    cc_library(
        name = "{}-wasm".format(name),
        visibility = visibility,
        **wasm_kwargs,
    )

    # Droid (Android NDK)
    droid_kwargs = dict(kwargs)
    droid_kwargs["target_compatible_with"] = ["@platforms//os:android"]
    cc_library(
        name = "{}-droid".format(name),
        visibility = visibility,
        **droid_kwargs,
    )

    # Alias selects variant based on current --platforms
    native.alias(
        name = name,
        actual = select({
            "@platforms//cpu:wasm32": ":{}-wasm".format(name),
            "@platforms//os:android": ":{}-droid".format(name),
            "//conditions:default": ":{}-host".format(name),
        }),
        visibility = visibility,
    )


# https://bazel.build/extending/macros
multi_library = macro(
    inherit_attrs = native.cc_library,
    implementation = _multi_library_impl,
    attrs = {},
)
