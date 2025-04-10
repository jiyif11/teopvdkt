cmake_minimum_required(VERSION 3.16)
project(cpuinfer_ext VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)

# --- General Optimization Flags ---
# Keep O3 and fast-math, OpenMP is good for parallelism
set(BASE_CXX_FLAGS "-O3 -ffast-math -fopenmp")
# Consider adding LTO later if beneficial
# set(BASE_CXX_FLAGS "${BASE_CXX_FLAGS} -flto")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${BASE_CXX_FLAGS}")
# Add LTO flags also for linking if enabled
# set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -flto")
# set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -flto")
# set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -flto")

add_compile_definitions(_GLIBCXX_USE_CXX11_ABI=${_GLIBCXX_USE_CXX11_ABI})
set(CMAKE_BUILD_TYPE "Release")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- Platform/Architecture Specific Options ---
option(TARGET_ARCH_NATIVE "Use native CPU optimizations (-march=native or /arch:AVX2 etc.)" ON)
option(ARM_ENABLE_SVE2 "Enable ARM SVE2 optimizations (+sve2)" ON "Requires ARMv9-A and compatible compiler/code")
option(ARM_ENABLE_BF16 "Enable ARM BF16 optimizations (+bf16)" OFF "Requires ARMv9.2-A or specific cores")
option(ARM_ENABLE_I8MM "Enable ARM I8MM optimizations (+i8mm)" OFF "Requires ARMv8.2-A/ARMv9.0-A or specific cores")
# Add more options for specific CPU targets if needed
# option(ARM_CPU_TARGET "Specify ARM CPU target (e.g., neoverse-n2, cortex-x2). Overrides native/arch." "")

# (Keep your x86 options like LLAMA_AVX* if cross-platform is needed)
# ... (LLAMA_AVX options etc.) ...


# --- Detect Architecture and Set Flags ---
set(ARCH_FLAGS "")
set(ARCH_IS_ARM OFF)
set(ARCH_IS_X86 OFF)

if (CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$")
    message(STATUS "ARM64/AArch64 detected")
    set(ARCH_IS_ARM ON)
    if (MSVC)
        # MSVC ARM64 handling (Keep as is or adapt if needed)
        # ... (Your existing MSVC ARM code) ...
    else()
        # GCC / Clang on ARM64

        # Base architecture string
        set(ARM_MARCH_STR "armv8-a") # Default conservative baseline

        # --- Determine ARM Architecture Level ---
        # Simple check based on CMAKE_SYSTEM_PROCESSOR (might need refinement)
        # A more robust method might involve compiler checks or toolchain info
        if (CMAKE_SYSTEM_PROCESSOR MATCHES "armv9|aarch64v9") # Heuristic, improve if possible
             set(ARM_MARCH_STR "armv9-a")
             message(STATUS "Detected ARMv9-a architecture level (heuristic).")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "armv8|aarch64") # Check for v8 after v9
             # Could add checks for v8.1, v8.2 etc. if needed
             set(ARM_MARCH_STR "armv8-a") # Or perhaps armv8.2-a as a common baseline?
             message(STATUS "Detected ARMv8-a architecture level (heuristic).")
        else()
             message(WARNING "Could not reliably determine ARMv8/v9 level from CMAKE_SYSTEM_PROCESSOR (${CMAKE_SYSTEM_PROCESSOR}). Defaulting to ${ARM_MARCH_STR}.")
        endif()

        # --- Add Architecture Features (Based on options) ---
        set(ARM_FEATURES "")
        # Check if we are aiming for armv9-a or higher before enabling v9 features
        if(ARM_MARCH_STR VERSION_GREATER_EQUAL "armv9-a" OR ARM_MARCH_STR STREQUAL "armv9-a")
            if(ARM_ENABLE_SVE2)
                list(APPEND ARM_FEATURES "+sve2")
                message(STATUS "Enabling ARM SVE2 (+sve2)")
            endif()
        endif()
        # I8MM might be available from v8.2-a
        if(ARM_MARCH_STR VERSION_GREATER_EQUAL "armv8.2-a" OR ARM_MARCH_STR MATCHES "armv9")
             if(ARM_ENABLE_I8MM)
                  list(APPEND ARM_FEATURES "+i8mm")
                  message(STATUS "Enabling ARM I8MM (+i8mm)")
             endif()
        endif()
        # BF16 usually needs v9.2-a or specific v9.0 cores
        if(ARM_MARCH_STR VERSION_GREATER_EQUAL "armv9.2-a") # Check specific version if needed
             if(ARM_ENABLE_BF16)
                  list(APPEND ARM_FEATURES "+bf16")
                  message(STATUS "Enabling ARM BF16 (+bf16)")
             endif()
        endif()
        # Add dot product check if needed (often enabled by default with recent arches)
         # list(APPEND ARM_FEATURES "+dotprod")

        # --- Construct the final -march / -mcpu flag ---
        if (TARGET_ARCH_NATIVE)
            list(APPEND ARCH_FLAGS "-mcpu=native")
            message(STATUS "Using native CPU optimization (-mcpu=native)")
            # Note: -mcpu=native implicitly enables features supported by the host CPU.
            # You might not need to add +sve2 etc. explicitly when using native,
            # but keeping the options allows disabling them if needed.
            # Consider adding features *conditionally* if NOT using native,
            # or always add them and let the compiler sort it out if native includes them.
            # Let's add them here for clarity, compiler usually ignores duplicates/implications.
            string(JOIN "" ARM_FEATURES_STR ${ARM_FEATURES})
            if (ARM_FEATURES_STR)
                list(APPEND ARCH_FLAGS "-march=native${ARM_FEATURES_STR}") # Try adding features to native
            endif()
        else()
            # If not native, use the detected/specified architecture and features
            string(JOIN "" ARM_FEATURES_STR ${ARM_FEATURES})
            list(APPEND ARCH_FLAGS "-march=${ARM_MARCH_STR}${ARM_FEATURES_STR}")
             # Optional: add specific -mtune if desired and not using -mcpu=native
             # list(APPEND ARCH_FLAGS "-mtune=...")
        endif()

        # Add FP16 format if supported and needed (check remains useful)
        include(CheckCXXCompilerFlag)
        check_cxx_compiler_flag("-mfp16-format=ieee" COMPILER_SUPPORTS_FP16_FORMAT_IEEE)
        if (COMPILER_SUPPORTS_FP16_FORMAT_IEEE)
            list(APPEND ARCH_FLAGS -mfp16-format=ieee)
        endif()

        # REMOVED: -mfpu=neon-fp-armv9 (let -march/-mcpu handle it)
        # REMOVED: -mno-unaligned-access (usually not needed/detrimental)
        # REMOVED: Specific armv6/v7 logic (assuming target is v8/v9)
        # If you need older ARM support, re-add those sections carefully.

    endif()

elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|i686|AMD64)$" OR CMAKE_GENERATOR_PLATFORM_LWR MATCHES "^(x86_64|amd64|x64)$")
    message(STATUS "x86_64 detected")
    set(ARCH_IS_X86 ON)
    # ... (Your existing x86/MSVC flag logic - likely ok) ...
    if (MSVC)
        # ...
    else()
        if (TARGET_ARCH_NATIVE) # Unified native flag
            list(APPEND ARCH_FLAGS "-march=native")
            # Add common useful flags usually enabled by native, but explicitly if needed
            list(APPEND ARCH_FLAGS -mfma -mavx -mavx2)
        else()
            # Apply specific flags based on LLAMA_* options if native is OFF
            if (LLAMA_F16C) list(APPEND ARCH_FLAGS -mf16c) endif()
            # ... (rest of your LLAMA_AVX* checks) ...
        endif()
    endif()


# ... (Rest of PowerPC and Unknown Architecture handling) ...

else()
    message(WARNING "Could not detect known CPU architecture. No specific optimizations applied.")
endif()


# Add the architecture-specific flags to the compiler options
string(JOIN " " ARCH_FLAGS_STR "${ARCH_FLAGS}")
if (ARCH_FLAGS_STR)
    message(STATUS "Applying architecture flags: ${ARCH_FLAGS_STR}")
    # Use generator expressions for language-specific flags
    add_compile_options("$<$<COMPILE_LANGUAGE:C>:${ARCH_FLAGS_STR}>")
    add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:${ARCH_FLAGS_STR}>")
endif()

# --- Dependencies and Linking ---
# ... (pybind11, llama.cpp subdirectories) ...

# Ensure llama.cpp also gets the optimized flags
# If llama.cpp has its own target, make sure it inherits or receives these flags.
# Since it's added as a subdirectory, it *should* inherit CMAKE_CXX_FLAGS unless it overrides them.
# You might need to check llama.cpp's CMakeLists.txt.

# ... (Include directories, CUDA/ROCM/MUSA handling - keep as is) ...

# ... (Source file definitions) ...

# ... (Formatting target) ...

# Add llamafile target (static library)
# Ensure llamafile *also* gets compiled with appropriate flags if it contains perf-critical code.
# It will inherit global flags, which is likely what you want.
# add_library(llamafile STATIC ${SOURCE_DIR4}) # Already exists

# --- Main Python Module Target ---
message(STATUS "Final CMAKE_CXX_FLAGS for ${PROJECT_NAME}: ${CMAKE_CXX_FLAGS}")
pybind11_add_module(${PROJECT_NAME} MODULE ${ALL_SOURCES})

# Link dependencies
# Use target_link_libraries correctly
target_link_libraries(${PROJECT_NAME} PRIVATE llama) # Link against the llama target built from the subdirectory

# Link llamafile if needed by the main module (Adjust if needed)
target_link_libraries(${PROJECT_NAME} PRIVATE llamafile)


# --- GPU and NUMA Linking ---
# ... (Your existing CUDA/ROCM/MUSA linking logic) ...
# ... (Your existing NUMA linking logic) ...

