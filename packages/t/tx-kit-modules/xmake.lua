print('1111111111')

package("tx-kit-modules")
    set_description("TX Kit utility modules")
    
    on_install(function (package)
        -- Копируем модули в папку пакета
        print('2222222222')
        os.cp("modules/*.lua", package:installdir("modules"))
    end)
    
    on_load(function (package)
        -- Добавляем путь к модулям
        print('33333333333')
        package:addenv("XMAKE_MODULE_DIR", package:installdir("modules"))
    end)
