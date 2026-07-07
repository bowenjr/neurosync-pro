cmake_minimum_required(VERSION 3.16)

execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE NSP_GIT_COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT NSP_GIT_COMMIT)
    set(NSP_GIT_COMMIT "unknown")
endif()
add_compile_definitions(NSP_GIT_COMMIT="${NSP_GIT_COMMIT}")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(nsp_diagnostic)
