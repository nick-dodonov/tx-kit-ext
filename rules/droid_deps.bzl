load(
    "@rules_android//rules:android_split_transition.bzl",
    "android_split_transition",
)
load("//rules:log.bzl", "log")

_log = log.info(0)

##########################################
DroidDefaultAppManifestInfo = provider(
    "Provides the default Android manifest file from dependencies for multi_app.",
    fields = {
        "default_app_manifest": "Default Android manifest file from dependencies for multi_app.",
    }
)

def _droid_default_app_manifest_impl(ctx):
    _log("=== droid_default_app_manifest {}".format(ctx.label))
    return [
        DroidDefaultAppManifestInfo(
            default_app_manifest=ctx.file.default_app_manifest,
        ),
    ]

droid_default_app_manifest = rule(
    implementation = _droid_default_app_manifest_impl,
    attrs = {
        "default_app_manifest": attr.label(
            allow_single_file = [".xml"],
            doc = ("Default Android manifest file for the case multi_app doesn't define one."),
        ),
    },
)

##########################################
def _droid_default_app_manifest_aspect_impl(target, ctx):
    _log("=== droid_default_app_manifest_aspect {}".format(target))

    found_default_app_manifest = None

    # First pass: check direct "data" attribute (highest priority)
    if hasattr(ctx.rule.attr, "data"):
        target_data = ctx.rule.attr.data
        for d in target_data:
            if DroidDefaultAppManifestInfo in d:
                found_default_app_manifest = d[DroidDefaultAppManifestInfo]
                _log("  FOUND (in data)", found_default_app_manifest)
                break
    
    # Second pass: if not found in data, check transitive deps (lower priority)
    if not found_default_app_manifest and hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if DroidDefaultAppManifestInfo in dep:
                found_default_app_manifest = dep[DroidDefaultAppManifestInfo]
                _log("  FOUND (in deps)", found_default_app_manifest)
                break

    if found_default_app_manifest:
        return [found_default_app_manifest]

    return []

_droid_default_app_manifest_aspect = aspect(
    implementation = _droid_default_app_manifest_aspect_impl,
    attr_aspects = ["deps"],  # traverse by "deps" attribute
    # required_providers = [CcInfo, JavaInfo],  # only apply to some targets (to filter out another deps that are not relevant)
)

##########################################
def _droid_select_default_app_manifest_impl(ctx):
    """Take the top default app manifest from deps -> data."""
    _log("=== droid_select_default_app_manifest  {}".format(ctx.label))

    found_default_app_manifest = None
    for dep in ctx.attr.search_deps:
        _log("  look in", dep)
        if DroidDefaultAppManifestInfo in dep:
            found_default_app_manifest = dep[DroidDefaultAppManifestInfo].default_app_manifest
            _log("    FOUND RESULT:", found_default_app_manifest)
            break

    if not found_default_app_manifest:
        fail("No found Android default app manifest in deps->data for {}".format(ctx.label))

    return [
        DefaultInfo(files = depset([found_default_app_manifest])),
    ]

droid_select_default_app_manifest = rule(
    implementation = _droid_select_default_app_manifest_impl,
    attrs = {
        "search_deps": attr.label_list(
            mandatory = True,
            cfg = android_split_transition,  # TODO: maybe simple android_transition instead?
            aspects = [_droid_default_app_manifest_aspect],
        ),
    },
)
