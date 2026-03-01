#include <iostream>
#include <unistd.h>

#include "cc_lib.h"

static void simulate_force_exit()
{
    std::cout << "simulate_force_exit(): _exit(17)" << std::endl;
    _exit(17);
}

static void simulate_crash()
{
    std::cout << "simulate_crash(): SIGSEGV" << std::endl;
    int* p = nullptr;
    *p = 1;
    (void)p;
}
int main(int argc, char** argv)
{
    std::cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << std::endl;
    std::cout << get_greeting("World") << std::endl;
    std::cout << "argc=" << argc << std::endl;
    for (int i = 0; i < argc; ++i) {
        std::cout << "argv[" << i << "]=" << argv[i] << std::endl;
    }

    if (argc > 1) {
        std::string arg = argv[1];
        if (arg == "exit") {
            simulate_force_exit();
        } else if (arg == "crash") {
            simulate_crash();
        }
    }

    std::cout << "exit code: " << argc - 1 << std::endl;
    std::cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << std::endl;
    return argc - 1;
}
