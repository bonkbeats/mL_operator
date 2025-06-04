cmake_minimum_required(VERSION 3.4.1)

# Set include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Add image_compare library
add_library(image_compare SHARED
    image_compare.cpp
    ImageCompare.cpp
    ImageCompare.h
    openn.hpp
)

# Link libraries
target_link_libraries(image_compare
    android
    log
)