#!/usr/bin/env python3
"""
Private registry integrity updater.

Аналог BCR update_integrity для приватного реестра.
Обновляет SHA хеши в source.json файлах.
"""

import os
import sys
import json
import hashlib
import base64
import pathlib
import urllib.request
import urllib.error


def download(url):
    """Download file from URL and return its content."""
    if url.startswith("file://"):
        # Handle file:// URLs for testing
        file_path = url[7:]  # Remove file:// prefix
        with open(file_path, "rb") as f:
            return f.read()
    
    try:
        with urllib.request.urlopen(url) as response:
            return response.read()
    except urllib.error.URLError as e:
        raise RuntimeError(f"Failed to download {url}: {e}")


def read_file(path):
    """Read file from local path."""
    with open(path, "rb") as f:
        return f.read()


def integrity(data, algorithm="sha256"):
    """Calculate integrity hash in SRI format."""
    assert algorithm in {
        "sha224",
        "sha256", 
        "sha384",
        "sha512",
    }, "Unsupported SRI algorithm"
    
    hash_obj = getattr(hashlib, algorithm)(data)
    encoded = base64.b64encode(hash_obj.digest()).decode()
    return f"{algorithm}-{encoded}"


def json_dump(file_path, data, sort_keys=False):
    """Write JSON data to file with consistent formatting."""
    with open(file_path, "w", newline="\n") as f:
        json.dump(data, f, indent=4, sort_keys=sort_keys)
        f.write("\n")


class PrivateRegistryClient:
    """Client for managing private Bazel registry."""
    
    def __init__(self, registry_root):
        self.root = pathlib.Path(registry_root).resolve()
        if not self.root.exists():
            raise RuntimeError(f"Registry root does not exist: {self.root}")
        
        # Verify it's a registry
        bazel_registry_json = self.root / "bazel_registry.json"
        if not bazel_registry_json.exists():
            raise RuntimeError(
                f"Not a valid registry: missing bazel_registry.json in {self.root}"
            )
    
    def get_modules_dir(self):
        """Get modules directory path."""
        config = self.get_registry_config()
        module_base_path = config.get("module_base_path", "modules")
        return self.root / module_base_path
    
    def get_registry_config(self):
        """Get bazel_registry.json content."""
        config_path = self.root / "bazel_registry.json"
        with open(config_path) as f:
            return json.load(f)
    
    def get_all_modules(self):
        """Get list of all available modules."""
        modules_dir = self.get_modules_dir()
        if not modules_dir.exists():
            return []
        return [d.name for d in modules_dir.iterdir() if d.is_dir()]
    
    def get_module_versions(self, module_name):
        """Get list of versions for a module."""
        module_dir = self.get_modules_dir() / module_name
        if not module_dir.exists():
            return []
        return [d.name for d in module_dir.iterdir() if d.is_dir()]
    
    def get_source_json_path(self, module_name, version):
        """Get path to source.json file."""
        return self.get_modules_dir() / module_name / version / "source.json"
    
    def get_source(self, module_name, version):
        """Load source.json content."""
        source_path = self.get_source_json_path(module_name, version)
        if not source_path.exists():
            raise RuntimeError(f"source.json not found: {source_path}")
        
        with open(source_path) as f:
            return json.load(f)
    
    def get_overlay_dir(self, module_name, version):
        """Get overlay directory path."""
        return self.get_modules_dir() / module_name / version / "overlay"
    
    def get_patches_dir(self, module_name, version):
        """Get patches directory path."""
        return self.get_modules_dir() / module_name / version / "patches"
    
    def module_exists(self, module_name, version=None):
        """Check if module (and optionally version) exists."""
        modules_dir = self.get_modules_dir()
        module_dir = modules_dir / module_name
        
        if not module_dir.exists():
            return False
        
        if version is None:
            return True
        
        version_dir = module_dir / version
        return version_dir.exists()
    
    def update_integrity(self, module_name, version):
        """Update SRI hashes in source.json file."""
        if not self.module_exists(module_name, version):
            raise RuntimeError(f"Module {module_name}@{version} not found")
        
        source = self.get_source(module_name, version)
        source_path = self.get_source_json_path(module_name, version)
        
        # Update main archive integrity
        if "url" in source:
            print(f"Downloading and calculating integrity for {source['url']}")
            archive_data = download(source["url"])
            source["integrity"] = integrity(archive_data)
            print(f"Updated main archive integrity: {source['integrity']}")
        
        # Update patches integrity
        patches_dir = self.get_patches_dir(module_name, version)
        if patches_dir.exists():
            current_patches = source.get("patches", {})
            available_patches = [p for p in patches_dir.iterdir() if p.is_file()]
            
            if available_patches:
                patches = {}
                for patch_file in available_patches:
                    patch_name = patch_file.name
                    patch_data = read_file(patch_file)
                    patch_integrity = integrity(patch_data)
                    patches[patch_name] = patch_integrity
                    
                    if patch_name in current_patches:
                        if current_patches[patch_name] != patch_integrity:
                            print(f"Updated patch {patch_name}: {patch_integrity}")
                    else:
                        print(f"Added new patch {patch_name}: {patch_integrity}")
                
                source["patches"] = patches
            else:
                # No patches exist, remove patches section
                source.pop("patches", None)
        else:
            # No patches directory, remove patches section
            source.pop("patches", None)
        
        # Update overlay integrity
        overlay_dir = self.get_overlay_dir(module_name, version)
        if overlay_dir.exists():
            overlay_files = []
            for path in overlay_dir.rglob("*"):
                if path.is_file() and path.name != "MODULE.bazel.lock":
                    overlay_files.append(path)
            
            if overlay_files:
                overlay = {}
                for overlay_file in overlay_files:
                    relative_path = str(overlay_file.relative_to(overlay_dir))
                    overlay_data = read_file(overlay_file)
                    overlay_integrity = integrity(overlay_data)
                    overlay[relative_path] = overlay_integrity
                    
                    current_overlay = source.get("overlay", {})
                    if relative_path in current_overlay:
                        if current_overlay[relative_path] != overlay_integrity:
                            print(f"Updated overlay {relative_path}: {overlay_integrity}")
                    else:
                        print(f"Added new overlay {relative_path}: {overlay_integrity}")
                
                source["overlay"] = overlay
            else:
                # No overlay files, remove overlay section
                source.pop("overlay", None)
        else:
            # No overlay directory, remove overlay section
            source.pop("overlay", None)
        
        # Write updated source.json
        json_dump(source_path, source, sort_keys=False)
        print(f"Updated {source_path}")


def main():
    """Main function with simple argument parsing."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Update the SRI hashes in source.json files for private registry modules"
    )
    parser.add_argument("module", help="Module name to update")
    parser.add_argument("--version", help="Module version (uses latest if not specified)")
    parser.add_argument("--registry", default=".", help="Path to registry root (default: current directory)")
    
    args = parser.parse_args()
    
    try:
        client = PrivateRegistryClient(args.registry)
        
        if not client.module_exists(args.module):
            available = client.get_all_modules()
            print(f"ERROR: Module '{args.module}' not found in registry.")
            if available:
                print(f"Available modules: {', '.join(available)}")
            else:
                print("No modules found in registry.")
            sys.exit(1)
        
        versions = client.get_module_versions(args.module)
        if not versions:
            print(f"ERROR: No versions found for module '{args.module}'")
            sys.exit(1)
        
        version = args.version
        if version is None:
            # Use latest version (lexicographically last)
            version = sorted(versions)[-1]
            print(f"Using latest version: {version}")
        
        if not client.module_exists(args.module, version):
            print(f"ERROR: Version '{version}' not found for module '{args.module}'.")
            print(f"Available versions: {', '.join(sorted(versions))}")
            sys.exit(1)
        
        print(f"Updating integrity for {args.module}@{version} in {args.registry}")
        client.update_integrity(args.module, version)
        print("Done!")
        
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # Support running from bazel (change to source directory)
    if os.getenv("BUILD_WORKSPACE_DIRECTORY"):
        os.chdir(os.getenv("BUILD_WORKSPACE_DIRECTORY"))
    
    main()