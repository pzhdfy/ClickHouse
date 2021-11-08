option(ENABLE_THRIFT "Enable Thrift" ON)
option(USE_INTERNAL_THRIFT_LIBRARY "Set to FALSE to use system thrift library instead of bundled" ${NOT_UNBUNDLED})

if(ENABLE_THRIFT)
    if (NOT EXISTS "${ClickHouse_SOURCE_DIR}/contrib/thrift")
        message (WARNING "submodule contrib is missing. to fix try run: \n git submodule update --init --recursive")
        set (MISSING_THRIFT 1)
    endif()

    if (USE_INTERNAL_THRIFT_LIBRARY AND NOT MISSING_THRIFT)
        if (MAKE_STATIC_LIBRARIES)
            set(THRIFT_LIBRARY thrift_static)
        else()
            set(THRIFT_LIBRARY thrift)
        endif()
        set (THRIFT_INCLUDE_DIR "${ClickHouse_SOURCE_DIR}/contrib/thrift/lib/cpp/src")
        set (THRIFT_COMPILER "thrift-compiler")
    else()
        find_library(THRIFT_LIBRARY thrift)
    endif ()
endif()

message (STATUS "Using_THRIFT=${ENABLE_THRIFT}: ${THRIFT_INCLUDE_DIR} : ${THRIFT_LIBRARY}")
