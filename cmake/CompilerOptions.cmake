# =============================================================================
# CompilerOptions.cmake — применение флагов компилятора к таргету
# =============================================================================

function(apply_compiler_options TARGET_NAME)
    # ----- GCC / Clang -----
    target_compile_options(${TARGET_NAME} PRIVATE
        $<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:
            -Wall -Wextra -Wpedantic
            -Wshadow
            -Wnon-virtual-dtor
            -Wold-style-cast
            -Wcast-align
            -Wunused
            -Wsign-conversion
            -Wnull-dereference
            -Wdouble-promotion
            -Wmissing-include-dirs
            -Wno-unused-parameter
            -fstack-protector-strong
            -fPIE
        >
    
	# ----- MSVC -----
        $<$<CXX_COMPILER_ID:MSVC>:
            /W4
            /WX
            /MP
        >
    )

endfunction()