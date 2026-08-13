# =============================================================================
# Defines.cmake
# =============================================================================

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

function(apply_common_definitions TARGET_NAME)
    target_compile_definitions(${TARGET_NAME} PRIVATE
        # ----- Debug -----
        $<$<CONFIG:Debug>:
            QT_DEBUG
            DEBUG
            _DEBUG
            PROJECT_VERSION="${PROJECT_VERSION}"
        >
        # ----- Release -----
        $<$<CONFIG:Release>:
            QT_NO_DEBUG_OUTPUT
            NDEBUG
        >
        # ----- Платформозависимые -----
        $<$<PLATFORM_ID:Windows>:WIN32_LEAN_AND_MEAN;NOMINMAX>
        $<$<PLATFORM_ID:Linux>:LINUX>
        $<$<PLATFORM_ID:Darwin>:MACOS>
    )
endfunction()

