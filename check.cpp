#include "ImageCompare.h"

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cout << "Usage: " << argv[0] << " image1 image2 " << std::endl;
        return 1;
    }

    ImageComparator comparator;
    comparator.run(argv[1], argv[2]);

    return 0;
}