package("tx-pkg-misc")
    --set_sourcedir(path.join(os.scriptdir(), "../tx-pkg-misc"))
    add_urls("https://github.com/nick-dodonov/tx-pkg-misc.git")

    on_install(function (package)
        import("package.tools.xmake").install(package)
    end)
