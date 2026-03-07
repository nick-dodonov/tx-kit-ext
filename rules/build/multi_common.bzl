"""Common utilities shared between multi_app and multi_lib build rules."""

load("@bazel_skylib//rules:expand_template.bzl", "expand_template")

# Valid platforms supported by multi_* rules
VALID_PLATFORMS = ["host", "wasm", "droid"]

# Default Android manifest template for applications
DROID_MANIFEST_TEMPLATE = Label("//rules/build/droid:template.AndroidManifest.xml")


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


def _generate_manifest(base_name, droid_manifest, lib_name, use_default_template):
    """Generates AndroidManifest.xml from template or default.
    
    Creates either expand_template (if droid_manifest provided) or genrule (if using default)
    to generate the manifest file with __LIB_NAME__ and $LIB_NAME substitutions.
    
    Args:
        base_name: Base name for generated targets (e.g., "sdl3-1-droid").
        droid_manifest: User-provided manifest template label, or None.
        lib_name: Library/APK name to substitute into template (e.g., "sdl3-1-droid-apk").
        use_default_template: If True and droid_manifest is None, use default template.
                              If False and droid_manifest is None, return None.
    
    Returns:
        Label string (e.g., ":sdl3-1-droid_manifest") or None if no manifest needed.
    """
    if droid_manifest != None:
        # User provided custom manifest template - use expand_template
        manifest_gen = "{}_manifest".format(base_name)
        manifest_out = "{}_AndroidManifest.xml".format(base_name)
        expand_template(
            name = manifest_gen,
            template = droid_manifest,
            out = manifest_out,
            substitutions = {
                "__LIB_NAME__": lib_name,
                "$LIB_NAME": lib_name,
            },
        )
        return ":{}".format(manifest_gen)
    elif use_default_template:
        # No custom manifest, but default template requested (for apps)
        manifest_gen = "{}_manifest".format(base_name)
        manifest_out = "{}_AndroidManifest.xml".format(base_name.replace("-", "_"))
        native.genrule(
            name = manifest_gen,
            srcs = [DROID_MANIFEST_TEMPLATE],
            outs = [manifest_out],
            cmd = "sed 's/__LIB_NAME__/{}/' $(location {}) > $@".format(
                lib_name,
                DROID_MANIFEST_TEMPLATE,
            ),
        )
        return ":{}".format(manifest_gen)
    else:
        # No manifest needed (for libraries without explicit manifest)
        return None


# Public wrapper to satisfy Bazel macro naming convention  
def generate_manifest(base_name, droid_manifest, lib_name, use_default_template, name = None):  # @unused
    """Public wrapper for _generate_manifest.
    
    Args:
        base_name: Base name for generated targets.
        droid_manifest: User-provided manifest template label, or None.
        lib_name: Library/APK name to substitute into template.
        use_default_template: Whether to use default template if droid_manifest is None.
        name: Unused, required by Bazel macro convention.
        
    Returns:
        Label string or None.
    """
    return _generate_manifest(base_name, droid_manifest, lib_name, use_default_template)


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
