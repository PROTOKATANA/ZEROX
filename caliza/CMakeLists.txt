cmake_minimum_required(VERSION 3.21 FATAL_ERROR)

set(CMAKE_C_COMPILER "clang")

set(CMAKE_CXX_COMPILER "clang++")

set(CMAKE_CUDA_HOST_COMPILER "clang++")

set(APODO "caliza")

project(${APODO} LANGUAGES CXX)

set(DISPOSITIVO "CUDA")

if(UNIX)

set(ROCM /opt/rocm)

set(CUDA /usr/local/cuda)

elseif(WIN32)

# ...

endif()

if(DISPOSITIVO STREQUAL "CUDA")

	add_definitions(-D__HIP_PLATFORM_NVIDIA__)

	set(CMAKE_CUDA_COMPILER ${CUDA}/bin/nvcc)

	set(CMAKE_CUDA_ARCHITECTURES "60")

	add_definitions(-DTHRUST_IGNORE_CUB_VERSION_CHECK)

elseif (DISPOSITIVO STREQUAL "HIP")

	add_definitions(-D__HIP_PLATFORM_HIP__)

endif()

set(CMAKE_CXX_STANDARD 20)

set(CMAKE_CXX_EXTENSIONS ON)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

enable_language(${DISPOSITIVO})

set(CMAKE_${DISPOSITIVO}_STANDARD 20)

set(CMAKE_${DISPOSITIVO}_EXTENSIONS OFF)

set(CMAKE_${DISPOSITIVO}_STANDARD_REQUIRED ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_subdirectory(${CMAKE_SOURCE_DIR}/caxor/proto)

file(GLOB_RECURSE TITANIO LIST_DIRECTORIES true ${CMAKE_SOURCE_DIR}/src/*)

set_source_files_properties(

	${CMAKE_SOURCE_DIR}/src/excavadora.cc

	PROPERTIES LANGUAGE ${DISPOSITIVO}

)

add_library(

	${APODO} STATIC

	${CMAKE_SOURCE_DIR}/src/mineria.cc

	${CMAKE_SOURCE_DIR}/src/excavadora.cc

)

target_include_directories(

	${APODO} PRIVATE

	${ROCM}/include

	${CUDA}/include

	${TITANIO}

)

target_link_libraries(${APODO} PRIVATE capnp kj)
