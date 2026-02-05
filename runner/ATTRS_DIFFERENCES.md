# Attribute Declarations: Rules vs Symbolic Macros

## Summary Table: Rules vs Symbolic Macros

| Aspect                      | Rules                     | Symbolic Macros            |
|-----------------------------|---------------------------|----------------------------|
| Declaration                 | `rule(attrs={...})`       | `macro(attrs={...})`       |
| Implicit attributes         | name, visibility + more   | name, visibility           |
| Access in implementation    | `ctx.attr.attr_name`      | Direct function parameter  |
| Implementation signature    | `def _impl(ctx)`          | `def _impl(name, vis, ..)` |
| Attribute inheritance       | ❌ Not supported          | ✅ `inherit_attrs=...`     |
| Parameter `mandatory`       | ✅ Available              | ✅ Available               |
| Parameter `default`         | ✅ Available              | ✅ Available               |
| Parameter `doc`             | ✅ Available              | ✅ Available               |
| Parameter `configurable`    | ✅ Available              | ✅ Available               |
| Parameter `executable`      | ✅ Available              | ❌ Not supported           |
| Parameter `cfg`             | ✅ Available ("exec", ..) | ❌ Not supported           |
| Parameter `providers`       | ✅ Available              | ❌ Not supported           |
| Configurable behavior       | Stored as-is              | Auto-wrapped in select()   |
| Private attributes (_name)  | ✅ Supported              | ✅ Supported               |
| Output attributes           | ✅ `attr.output()`        | ❌ Not supported           |

## Ways to Share Attributes

### ✅ Pattern 1: Shared Dictionary Constant

```python
_SHARED_ATTRS = {
    "dep": attr.label(...),
    "platform": attr.string(...),
}

my_rule = rule(attrs = _SHARED_ATTRS, ...)
my_macro = macro(attrs = _SHARED_ATTRS, ...)
```

### ✅ Pattern 2: Merge with Additional Attributes

```python
my_macro = macro(
    attrs = _SHARED_ATTRS | {
        "extra": attr.bool(...),
    },
    ...
)
```

### ✅ Pattern 3: Factory Function

```python
def make_attrs(**options):
    base = {"dep": attr.label(...)}
    if options.get("add_test"):
        base["is_test"] = attr.bool(...)
    return base

my_rule = rule(attrs = make_attrs(add_test=False), ...)
my_macro = macro(attrs = make_attrs(add_test=True), ...)
```

### ✅ Pattern 4: inherit_attrs (macros only)

```python
my_macro = macro(
    inherit_attrs = my_rule,  # or another macro
    attrs = {
        "is_test": attr.bool(...),      # additional
        "platform": attr.string(...),   # override
    },
    ...
)
```

### ❌ Does NOT Work: Inheritance for Rules

```python
my_rule = rule(
    inherit_attrs = ...,  # ❌ This parameter doesn't exist!
    ...
)
```

## Recommendations

1. **For simple cases**: Use shared dictionary `_SHARED_ATTRS` (see defs.bzl)

2. **For complex cases**: Create factory function `make_*_attrs()`

3. **For macro wrapping rule**: Use `inherit_attrs`

4. **Remember parameter differences**:
   - `cfg`, `executable`, `providers` - rules only
   - `inherit_attrs` - macros only

5. **Account for configurable attrs behavior in macros**:
   - Values are automatically wrapped in `select()`
   - `None` is not wrapped

6. **For inherited attrs in macros**:
   - Implementation must have `**kwargs`
   - Non-mandatory attrs always get `default=None`

## Usage in defs.bzl

The current implementation uses Pattern 1 (shared dictionary):

```python
_SHARED_ATTRS = {
    "target_binary": attr.label(...),
    "target_args": attr.string_list(...),
    "platform": attr.string(...),
}

run_wrapper_script = rule(attrs = _SHARED_ATTRS, ...)
run_wrapper = macro(attrs = _SHARED_ATTRS | {"is_test": ...}, ...)
```

This pattern eliminates duplication while keeping the code simple and maintainable.

## References

- [Bazel Rules Documentation](https://bazel.build/extending/rules)
- [Bazel Symbolic Macros Documentation](https://bazel.build/extending/macros)
