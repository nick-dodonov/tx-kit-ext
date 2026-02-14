"""Defines a Bazel transition for switching to the execution (host) platform."""

def _host_transition_impl(settings, attr):
    # Switch to execution platform (host)
    # Use execution platform instead of target platform
    _ignore = (settings, attr)  # @unused
    return {
        "//command_line_option:platforms": "@local_config_platform//:host",
    }

host_transition = transition(
    implementation = _host_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)
