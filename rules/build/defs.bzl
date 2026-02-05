"""
Public API for TX build rules.

This module re-exports all TX build rules for convenient importing.

Usage:
    load("@tx-kit-ext//rules/build:defs.bzl", "tx_binary", "tx_library", "tx_test")

Example:
    tx_library(
        name = "mylib",
        srcs = ["lib.cpp"],
        hdrs = ["lib.h"],
    )

    tx_binary(
        name = "myapp",
        srcs = ["main.cpp"],
        deps = [":mylib"],
    )

    tx_test(
        name = "mytest",
        srcs = ["test.cpp"],
        deps = [":mylib"],
    )
"""

load(":tx_binary.bzl", _tx_binary = "tx_binary")
load(":tx_library.bzl", _tx_library = "tx_library")
load(":tx_test.bzl", _tx_test = "tx_test")

# Re-export all TX build rules
tx_binary = _tx_binary
tx_library = _tx_library
tx_test = _tx_test
