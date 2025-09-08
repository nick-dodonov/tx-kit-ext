package("tx-kit-includes")
    -- https://xmake.io/api/description/builtin-policies.html#package-install-always
    set_policy("package.install_always", true)
    --set_policy("build.always_update_configfiles", true)

    on_load(function (package)
        print('TODO: tx-kit-includes: on_load')
    end)

    on_install(function (package)
        print('TODO: tx-kit-includes: on_install')
    end)
