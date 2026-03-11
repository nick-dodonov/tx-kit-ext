"""Common utilities shared between multi_app and multi_lib build rules."""
load(":filter_deps.bzl", "cc_deps_filter")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

# Valid platforms supported by multi_* rules
VALID_PLATFORMS = ["host", "wasm", "droid"]

_COMMON_ATTRS = dict(
    platforms = attr.string_list(
        default = VALID_PLATFORMS,
        configurable = False,
        doc = "List of platforms to build for. Valid values: 'host', 'wasm', 'droid'. Default: all platforms.",
    ),
    deps = attr.label_list(
        providers = [
            [CcInfo],
            [JavaInfo],
        ],
        doc = "Dependencies: cc_library (CcInfo) or android_library/java_library (JavaInfo). All deps are passed to both cc_library and android_binary.",
    ),
)

_DROID_COMMON_ATTRS = dict(
    droid_manifest = attr.label(
        allow_single_file = [".xml"],
        doc = ("The name of the Android manifest file, normally " +
                "AndroidManifest.xml. Must be defined if resource_files or assets are defined."),
    ),
    droid_srcs = attr.label_list(
        allow_files = [".java", ".srcjar"],
        default = [],
        doc = "Java/Kotlin source files for Android platform. Automatically creates android_library wrapping cc_library.",
    ),
    droid_custom_package = attr.string(
        doc = ("Java package for which java sources will be generated. " +
                "By default the package is inferred from the directory where the BUILD file " +
                "containing the rule is. You can specify a different package but this is " +
                "highly discouraged since it can introduce classpath conflicts with other " +
                "libraries that will only be detected at runtime."),
    ),
    droid_assets = attr.label_list(
        allow_files = True,
        cfg = "target",
        doc = "Asset files for Android platform. Passed to android_library.",
    ),
    droid_assets_dir = attr.string(
        doc = "Directory for Android assets. Passed to android_library.",
    ),
)

def _get_common_attrs():
    """ Returns the common attributes for multi_app and multi_lib rules. """
    return _COMMON_ATTRS | _DROID_COMMON_ATTRS

def validate_platforms(enabled_platforms):
    """Validates the platforms list.

    Args:
        enabled_platforms: List of platform strings to validate.

    Fails if any platform is invalid or list is empty.
    """
    for platform in enabled_platforms:
        if platform not in VALID_PLATFORMS:
            fail("Invalid platform '{}'. Must be one of: {}".format(platform, VALID_PLATFORMS))
    if len(enabled_platforms) == 0:
        fail("platforms list cannot be empty. Must specify at least one platform: {}".format(VALID_PLATFORMS))

def build_platform_select_dict(name, enabled_platforms):
    """Builds a select() dictionary for platform-based alias.

    Creates a mapping from platform constraints to target names based on enabled platforms.

    Args:
        name: Base target name (e.g., "sdl3-lib").
        enabled_platforms: List of enabled platforms (subset of VALID_PLATFORMS).

    Returns:
        Dictionary suitable for select() with platform constraints as keys and target labels as values.
        Includes "//conditions:default" key with fallback target.
    """
    select_dict = {}
    default_target = None

    # Host has highest priority for default
    if "host" in enabled_platforms:
        default_target = ":{}-host".format(name)

    # WASM platform constraint
    if "wasm" in enabled_platforms:
        select_dict["@platforms//cpu:wasm32"] = ":{}-wasm".format(name)
        if default_target == None:
            default_target = ":{}-wasm".format(name)

    # Android platform constraint
    if "droid" in enabled_platforms:
        select_dict["@platforms//os:android"] = ":{}-droid".format(name)
        if default_target == None:
            default_target = ":{}-droid".format(name)

    select_dict["//conditions:default"] = default_target
    return select_dict

def _get_cc_deps(name, all_deps):
    """Filters deps to only those providing CcInfo for cc_library/cc_binary targets (android deps may include android_library targets)."""
    if all_deps:
        cc_deps_filter_name = "{}.cc_deps".format(name)
        cc_deps_filter(
            name = cc_deps_filter_name,
            deps = all_deps,
        )
        return [":{}".format(cc_deps_filter_name)]
    return []

multi_common = struct(
    get_common_attrs = _get_common_attrs,
    get_cc_deps = _get_cc_deps,
)
