#!/usr/bin/env python3
"""
Simple test for update_integrity.py functionality.
"""

import os
import sys
import tempfile
import json
import pathlib
import shutil

# Add tools directory to path to import our module
sys.path.insert(0, os.path.dirname(__file__))

from update_integrity import PrivateRegistryClient, integrity, json_dump


def create_test_registry():
    """Create a temporary test registry structure."""
    temp_dir = tempfile.mkdtemp(prefix="test_registry_")
    registry_root = pathlib.Path(temp_dir)
    
    # Create bazel_registry.json
    registry_config = {
        "module_base_path": "modules"
    }
    json_dump(registry_root / "bazel_registry.json", registry_config)
    
    # Create test module structure
    module_dir = registry_root / "modules" / "testmod" / "1.0.0"
    module_dir.mkdir(parents=True)
    
    # Create test source.json
    source_json = {
        "url": "file:///dev/null",  # Special URL that returns empty content
        "integrity": "old-invalid-hash",
        "strip_prefix": "testmod-1.0.0"
    }
    json_dump(module_dir / "source.json", source_json)
    
    # Create overlay files
    overlay_dir = module_dir / "overlay"
    overlay_dir.mkdir()
    
    with open(overlay_dir / "BUILD.bazel", "w") as f:
        f.write("# Test BUILD file\n")
    
    with open(overlay_dir / "MODULE.bazel", "w") as f:
        f.write('module(name = "testmod", version = "1.0.0")\n')
    
    # Create patches
    patches_dir = module_dir / "patches"
    patches_dir.mkdir()
    
    with open(patches_dir / "test.patch", "w") as f:
        f.write("--- a/test.txt\n+++ b/test.txt\n@@ -1 +1 @@\n-old\n+new\n")
    
    return temp_dir


def test_update_integrity():
    """Test the update_integrity functionality."""
    print("Creating test registry...")
    test_registry = create_test_registry()
    
    try:
        print(f"Test registry created at: {test_registry}")
        
        # Initialize client
        client = PrivateRegistryClient(test_registry)
        
        # Test module listing
        modules = client.get_all_modules()
        assert "testmod" in modules, f"Expected 'testmod' in modules, got: {modules}"
        print("✓ Module listing works")
        
        # Test version listing
        versions = client.get_module_versions("testmod")
        assert "1.0.0" in versions, f"Expected '1.0.0' in versions, got: {versions}"
        print("✓ Version listing works")
        
        # Test module existence check
        assert client.module_exists("testmod"), "Module should exist"
        assert client.module_exists("testmod", "1.0.0"), "Module version should exist"
        assert not client.module_exists("nonexistent"), "Nonexistent module should not exist"
        print("✓ Module existence checks work")
        
        # Test source.json loading
        source = client.get_source("testmod", "1.0.0")
        assert source["url"] == "file:///dev/null", "URL should match"
        assert source["integrity"] == "old-invalid-hash", "Integrity should match initial value"
        print("✓ Source.json loading works")
        
        # Test update_integrity
        print("Running update_integrity...")
        client.update_integrity("testmod", "1.0.0")
        
        # Verify the update
        updated_source = client.get_source("testmod", "1.0.0")
        
        # Check that main integrity was updated (file:///dev/null returns empty content)
        expected_empty_hash = integrity(b"")  # Empty file hash
        assert updated_source["integrity"] == expected_empty_hash, \
            f"Expected {expected_empty_hash}, got {updated_source['integrity']}"
        print("✓ Main archive integrity updated correctly")
        
        # Check overlay hashes
        assert "overlay" in updated_source, "Overlay section should exist"
        assert "BUILD.bazel" in updated_source["overlay"], "BUILD.bazel should be in overlay"
        assert "MODULE.bazel" in updated_source["overlay"], "MODULE.bazel should be in overlay"
        print("✓ Overlay integrity computed correctly")
        
        # Check patches hashes
        assert "patches" in updated_source, "Patches section should exist"
        assert "test.patch" in updated_source["patches"], "test.patch should be in patches"
        print("✓ Patches integrity computed correctly")
        
        print("\n✅ All tests passed!")
        return True
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return False
        
    finally:
        # Cleanup
        print(f"Cleaning up test registry: {test_registry}")
        shutil.rmtree(test_registry)


if __name__ == "__main__":
    success = test_update_integrity()
    sys.exit(0 if success else 1)