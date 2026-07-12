set(SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/libasr/runtime/lfortran_intrinsics.c
)

if(WIN32)
  set(MATH_LIBRARIES "" CACHE STRING "math library")
else()
  set(MATH_LIBRARIES "m" CACHE STRING "math library")
endif()
mark_as_advanced( MATH_LIBRARIES )

add_library(lfortran_runtime SHARED ${SRC})
target_include_directories(lfortran_runtime BEFORE PUBLIC ${libasr_SOURCE_DIR}/..)
target_include_directories(lfortran_runtime BEFORE PUBLIC ${libasr_BINARY_DIR}/..)
target_link_libraries(lfortran_runtime PRIVATE ${MATH_LIBRARIES})
if (HAVE_INTERNAL_ALLOC_CHECK)
    target_compile_definitions(lfortran_runtime PRIVATE LFORTRAN_INTERNAL_ALLOC_CHECK)
endif()
set_target_properties(lfortran_runtime PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR})
set_target_properties(lfortran_runtime PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ..)

add_library(lfortran_runtime_static STATIC ${SRC})
target_include_directories(lfortran_runtime_static BEFORE PUBLIC ${libasr_SOURCE_DIR}/..)
target_include_directories(lfortran_runtime_static BEFORE PUBLIC ${libasr_BINARY_DIR}/..)
target_link_libraries(lfortran_runtime_static PRIVATE ${MATH_LIBRARIES})
if (HAVE_INTERNAL_ALLOC_CHECK)
    target_compile_definitions(lfortran_runtime_static PRIVATE LFORTRAN_INTERNAL_ALLOC_CHECK)
endif()
set_target_properties(lfortran_runtime_static PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ..)

if(WITH_TARGET_WASM)

    if ((NOT (DEFINED ENV{EMSDK_PATH})) AND (NOT (DEFINED ENV{WASI_SDK_PATH})))
        message(FATAL_ERROR "Atleast one of `EMSDK_PATH` or `WASI_SDK_PATH` must be available to target `WASM`")
    endif()

    if (DEFINED ENV{EMSDK_PATH})
        add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            COMMAND $ENV{EMSDK_PATH}/upstream/emscripten/emcc -I${libasr_SOURCE_DIR}/.. -DCOMPILE_TO_WASM
                -c --target=wasm32-unknown-emscripten ${SRC} -o ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            COMMENT "Cross compiling lfortran_intrinscs.c to ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o"
            DEPENDS ${SRC})
        add_custom_target(lfortran_runtime_wasm_emcc ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o)
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            DESTINATION ${CMAKE_INSTALL_LIBDIR})
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_emcc.o
            DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/..)
    endif()

    if (DEFINED ENV{WASI_SDK_PATH})
        add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            COMMAND $ENV{WASI_SDK_PATH}/bin/clang -I${libasr_SOURCE_DIR}/.. -DCOMPILE_TO_WASM
                -D_WASI_EMULATED_PROCESS_CLOCKS -c --target=wasm32-wasi ${SRC} -o ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            COMMENT "Cross compiling lfortran_intrinscs.c to ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o"
            DEPENDS ${SRC})
        add_custom_target(lfortran_runtime_wasm_wasi ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o)
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            DESTINATION ${CMAKE_INSTALL_LIBDIR})
        install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/lfortran_runtime_wasm_wasi.o
            DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/..)
    endif()
endif()

install(TARGETS lfortran_runtime_static
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(TARGETS lfortran_runtime
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install the header
install(
    FILES ../../../src/libasr/runtime/lfortran_intrinsics.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/lfortran/impure
)

install(
    FILES ../../../src/libasr/runtime/ISO_Fortran_binding.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/lfortran
)

# ---------------------------------------------------------------------------
# Pure Sollya math backend archive (compile-time --math-backend=pure)
# Built with system gfortran so the main C/CXX LFortran tree can produce it
# without a circular dependency on the lfortran Fortran frontend.
# Output next to liblfortran_runtime* so get_runtime_library_dir finds it.
# ---------------------------------------------------------------------------
find_program(LFORTRAN_PURE_MATH_FC gfortran)
if(LFORTRAN_PURE_MATH_FC)
    set(PURE_MATH_OBJDIR ${CMAKE_CURRENT_BINARY_DIR}/pure_math_objs)
    set(PURE_MATH_A ${CMAKE_CURRENT_BINARY_DIR}/../liblfortran_runtime_pure_math.a)
    set(PURE_TRIG_SRC ${CMAKE_CURRENT_SOURCE_DIR}/../pure/lfortran_intrinsic_trig.f90)
    set(PURE_ABI_SRC  ${CMAKE_CURRENT_SOURCE_DIR}/../pure/lfortran_pure_math_abi.f90)

    # Pure Fortran only. Host-tune pure.a (-march=native) for bulk SIMD.
    # No LTO IR so clang/g++ can link the archive without -flto.
    set(PURE_FC_FLAGS -ffree-line-length-none -O3 -fPIC
        -ftree-vectorize -funroll-loops -ffp-contract=fast -fno-math-errno
        -march=native)
    add_custom_command(
        OUTPUT ${PURE_MATH_A}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${PURE_MATH_OBJDIR}
        COMMAND ${LFORTRAN_PURE_MATH_FC} ${PURE_FC_FLAGS}
            -J${PURE_MATH_OBJDIR} -c ${PURE_TRIG_SRC}
            -o ${PURE_MATH_OBJDIR}/lfortran_intrinsic_trig.o
        COMMAND ${LFORTRAN_PURE_MATH_FC} ${PURE_FC_FLAGS}
            -J${PURE_MATH_OBJDIR} -I${PURE_MATH_OBJDIR} -c ${PURE_ABI_SRC}
            -o ${PURE_MATH_OBJDIR}/lfortran_pure_math_abi.o
        COMMAND ${CMAKE_AR} rcs ${PURE_MATH_A}
            ${PURE_MATH_OBJDIR}/lfortran_intrinsic_trig.o
            ${PURE_MATH_OBJDIR}/lfortran_pure_math_abi.o
        DEPENDS ${PURE_TRIG_SRC} ${PURE_ABI_SRC}
        COMMENT "Building liblfortran_runtime_pure_math.a (pure Fortran Sollya sin/cos)"
        VERBATIM
    )
    add_custom_target(lfortran_runtime_pure_math ALL DEPENDS ${PURE_MATH_A})
    install(FILES ${PURE_MATH_A}
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RENAME liblfortran_runtime_pure_math.a
    )
    install(FILES ${PURE_MATH_A}
        DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/..
        OPTIONAL
    )
    message(STATUS "Pure math backend: will build liblfortran_runtime_pure_math.a with ${LFORTRAN_PURE_MATH_FC}")
else()
    message(WARNING "gfortran not found: liblfortran_runtime_pure_math.a will not be built; --math-backend=pure cannot link")
endif()
