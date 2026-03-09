"""Helper rule to filter dependencies by provider type."""

# load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(
    "@rules_android//providers:providers.bzl",
    "AndroidCcLinkParamsInfo",
    "StarlarkAndroidResourcesInfo",
)
load(
    "@rules_android//rules:android_split_transition.bzl", 
    "android_split_transition",
    #"android_transition",
)

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

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

def _droid_top_manifest_impl(ctx):
    """Take the most appropriate android manifest from dependencies."""
    manifest = None
    for dep in ctx.attr.deps:
        # print("AVAILABLE PROVIDERS", dep)
        if StarlarkAndroidResourcesInfo in dep:
            info = dep[StarlarkAndroidResourcesInfo]
            manifests = info.transitive_manifests
            if manifests:
                manifest = manifests.to_list()[0]
                break

    #fail("XXXXXXXXXXXXXXXXXXXXXXXXXXX", manifest)
    if not manifest:
        fail("No Android manifest found in deps")

    return [
        DefaultInfo(files = depset([manifest])),
    ]

droid_top_manifest = rule(
    implementation = _droid_top_manifest_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            cfg = android_split_transition,
        ),
    },
)
