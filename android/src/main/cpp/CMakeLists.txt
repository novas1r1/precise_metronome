cmake_minimum_required(VERSION 3.22.1)
project(precise_metronome CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Oboe is pulled in via prefab from the com.google.oboe:oboe dependency.
find_package(oboe REQUIRED CONFIG)

add_library(precise_metronome SHARED
    metronome_engine.cpp
    click_synth.cpp
    jni_bridge.cpp
)

target_link_libraries(precise_metronome
    PRIVATE
    oboe::oboe
    log
    android
)

target_compile_options(precise_metronome PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
)
