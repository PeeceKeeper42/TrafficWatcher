# =============================================================================
# tests/CMakeLists.txt — сборка и регистрация тестов
# =============================================================================

message(STATUS "Configuring tests...")

find_package(Qt5 REQUIRED COMPONENTS Test)

include_directories(${CMAKE_SOURCE_DIR}/src)

list(FILTER TrafficLight_Sources EXCLUDE REGEX "main\\.cpp$")

# ----------------------------------------------------------------------------
# Тест 1: Модульный тест для TrafficLightState
# ----------------------------------------------------------------------------
add_executable(test_trafficlightstate
        test_trafficlightstate.cpp
        ${TrafficLight_Sources}
        ${TrafficLight_Headers}
        ${TrafficLight_Resources}
)

apply_compiler_options(test_trafficlightstate)
apply_common_definitions(test_trafficlightstate)

target_link_libraries(test_trafficlightstate
        Qt5::Core
        Qt5::Test
)

# ----------------------------------------------------------------------------
# Тест 2: Интеграционный UI-тест (требует QGuiApplication и QML)
# ----------------------------------------------------------------------------
add_executable(test_ui
        test_ui.cpp
        ${TrafficLight_Sources}
        ${TrafficLight_Headers}
)

apply_compiler_options(test_ui)
apply_common_definitions(test_ui)

target_link_libraries(test_ui
        Qt5::Core
        Qt5::Gui
        Qt5::Quick
        Qt5::QuickControls2
        Qt5::Test
)

# ----------------------------------------------------------------------------
# Регистрация тестов в CTest с использованием генераторных выражений
# ----------------------------------------------------------------------------
add_test(NAME TrafficLightStateTest COMMAND $<TARGET_FILE:test_trafficlightstate>)
add_test(NAME UITest COMMAND $<TARGET_FILE:test_ui>)