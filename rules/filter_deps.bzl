"""Helper rule to filter dependencies by provider type."""

load(
    "@rules_android//providers:providers.bzl",
    "AndroidCcLinkParamsInfo",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

##########################################
def _cc_deps_filter_impl(ctx):
    """Filters deps to return only those providing CcInfo, and merges them into a single CcInfo."""
    cc_infos = []
    files_list = []
    runfiles_list = []

    for dep in ctx.attr.deps:
        if CcInfo in dep:
            cc_infos.append(dep[CcInfo])

        if AndroidCcLinkParamsInfo in dep:
            cc_infos.append(dep[AndroidCcLinkParamsInfo].link_params)

        # Collect files and runfiles from all deps
        if DefaultInfo in dep:
            files_list.append(dep[DefaultInfo].files)
            if dep[DefaultInfo].default_runfiles:
                runfiles_list.append(dep[DefaultInfo].default_runfiles)

    if cc_infos:
        merged_cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)
    else:
        merged_cc_info = CcInfo()

    # Merge files and runfiles
    merged_files = depset(transitive = files_list)
    merged_runfiles = ctx.runfiles().merge_all(runfiles_list)

    return [
        DefaultInfo(
            files = merged_files,
            default_runfiles = merged_runfiles,
        ),
        merged_cc_info,
    ]

cc_deps_filter = rule(
    implementation = _cc_deps_filter_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            doc = "Mixed dependencies to filter cc_library and android_library deps from.",
        ),
    },
    provides = [CcInfo],
    doc = "Filters dependencies to return only those providing CcInfo, merging them into a single CcInfo provider.",
)


##########################################
def _droid_deps_filter_impl(ctx):
    return []


droid_deps_filter = rule(
    implementation = _droid_deps_filter_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
        ),
    },
    provides = [JavaInfo],
)
