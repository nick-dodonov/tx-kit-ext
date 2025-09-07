-- Внешний модуль для управления зависимостями

print('Loading external tx_dep module...')

function tx_add_package_dep_external(name)
    print('Adding external package dependency: ' .. name)
    add_requires(name, {system = false})
end

function tx_add_target_dep_external(name)
    print('Adding external target dependency: ' .. name)
    add_packages(name)
end

function test(name)
    print('External tx_dep test function called!')
end
