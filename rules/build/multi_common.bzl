"""Common utilities shared between multi_app and multi_lib build rules."""

# Valid platforms supported by multi_* rules
VALID_PLATFORMS = ["host", "wasm", "droid"]


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
