#include <iostream>
#include "cc_lib.h"

int main(int argc, char** argv)
{
    std::cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" << std::endl;
    std::cout << get_greeting("World") << std::endl;
    std::cout << "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ :: " << argc - 1 << std::endl;
    return argc - 1;
}
