# =============================================================================
# QtSetup.cmake — поиск и настройка Qt
# =============================================================================

if(NOT CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "D:/Qt/5.15.2/msvc2019_64" CACHE PATH "Path to Qt installation")
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Да, как бы глобально для всего проекта ищем, модуль у нас один, так что вполне сносно
find_package(Qt5 REQUIRED COMPONENTS
    Core
    Quick
    QuickControls2
)

set(USER_RECOMMENDED_VERSION 5.15.2)

if(NOT Qt5_VERSION VERSION_GREATER_EQUAL ${USER_RECOMMENDED_VERSION})
    message(WARNING "Рекомендуется Qt ${USER_RECOMMENDED_VERSION} или новее. Текущая версия: ${Qt5_VERSION}")
endif()

function(target_link_qt TARGET_NAME)
    target_link_libraries(${TARGET_NAME}
            Qt5::Core
            Qt5::Quick
            Qt5::QuickControls2
    )
endfunction()