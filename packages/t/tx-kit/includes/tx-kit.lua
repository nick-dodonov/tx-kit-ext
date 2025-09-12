-- Allows using local pkg repos for develop instead of packages from remote repos.
local _key = "TX_LOCAL"
option(_key, {default = os.getenv(_key)})
local _local = has_config(_key)

local function _log(msg)
    if os.getenv("TX_DEBUG") then
        print('TX_DEBUG: ' .. msg)
    end
end

local _xmake_add_requires = add_requires
function add_requires(names, opt)
    if _local and type(names) == "string" and names:match("^tx-") then
        local _path = os.scriptdir() .. "/../" .. names -- TODO: TX_LOCAL as prefix if exists
        if os.exists(_path) and os.isdir(_path) then
            _log('includes: ' .. _path)
            includes(_path)
            return
        end
    end

    _log('add_requires: ' .. names)
    _xmake_add_requires(names, opt)
end

local _xmake_add_packages = add_packages
function add_packages(name)
    if _local and type(name) == "string" and name:match("^tx-") then
        _log('add_deps: ' .. name)
        add_deps(name)
        return
    end

    _log('add_packages: ' .. name)
    _xmake_add_packages(name)
end
