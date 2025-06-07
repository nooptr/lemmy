cmake_minimum_required(VERSION 3.20)
project(whisperer)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Find required frameworks
find_library(APPLICATION_SERVICES_FRAMEWORK ApplicationServices)
find_library(AVFOUNDATION_FRAMEWORK AVFoundation)
find_library(APPKIT_FRAMEWORK AppKit)
find_library(COREFOUNDATION_FRAMEWORK CoreFoundation)

if(NOT APPLICATION_SERVICES_FRAMEWORK)
    message(FATAL_ERROR "ApplicationServices framework not found")
endif()

if(NOT AVFOUNDATION_FRAMEWORK)
    message(FATAL_ERROR "AVFoundation framework not found")
endif()

if(NOT APPKIT_FRAMEWORK)
    message(FATAL_ERROR "AppKit framework not found")
endif()

if(NOT COREFOUNDATION_FRAMEWORK)
    message(FATAL_ERROR "CoreFoundation framework not found")
endif()

# Source files
set(SOURCES
    src/main.c
    src/keylogger.c
)

# Create the executable
add_executable(whisperer ${SOURCES})

# Link frameworks
target_link_libraries(whisperer
    ${APPLICATION_SERVICES_FRAMEWORK}
    ${AVFOUNDATION_FRAMEWORK}
    ${APPKIT_FRAMEWORK}
    ${COREFOUNDATION_FRAMEWORK}
)

# Set output directory
set_target_properties(whisperer PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)

# Compiler flags for macOS
target_compile_options(whisperer PRIVATE
    -Wall
    -Wextra
    -Werror
    -Wno-error=unused-parameter
    -Wno-error=unused-function
)