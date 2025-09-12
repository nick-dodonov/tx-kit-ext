package("tx-pkg-aux")
    --set_sourcedir(path.join(os.scriptdir(), "../tx-pkg-aux"))
    add_urls("https://github.com/nick-dodonov/tx-pkg-aux.git")

    on_install(function (package)
        import("package.tools.xmake").install(package)
    end)
