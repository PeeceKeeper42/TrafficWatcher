# =============================================================================
# 1. Минимальные требования и базовые настройки проекта
# =============================================================================
cmake_minimum_required(VERSION 3.16)
project(TrafficLight LANGUAGES CXX)

# =============================================================================
# 2. Подключение вспомогательных модулей из папки cmake/
# =============================================================================
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(QtSetup)          
include(CompilerOptions)
include(Defines)
include(Functions)

generate_deployment_scripts(trafficlight "${CMAKE_SOURCE_DIR}/resources/qml")

# =============================================================================
# 3. Добавление директории с исходниками
# =============================================================================
add_subdirectory(src)

# =============================================================================
# 4. Тесты
# =============================================================================
option(BUILD_TESTS "Включить тесты" OFF)

if(BUILD_TESTS)
    message(STATUS "Сборка тестов включена, но тестовые файлы не добавлены.")
    # add_subdirectory(tests)
endif()

# =============================================================================
# 5. Вывод информации о проекте
# =============================================================================
message(STATUS "--------------------------------------------------")
message(STATUS "Проект: ${PROJECT_NAME}")
message(STATUS "Стандарт C++: ${CMAKE_CXX_STANDARD}")
message(STATUS "Qt версия: ${Qt5_VERSION}")
message(STATUS "Конфигурация: ${CMAKE_BUILD_TYPE}")
message(STATUS "--------------------------------------------------")

print_file_list("Исходники"   TrafficLight_Sources)
print_file_list("Заголовки"   TrafficLight_Headers)
print_file_list("Ресурсы"     TrafficLight_Resources)
print_file_list("Формы"       TrafficLight_Forms)

message(STATUS "--------------------------------------------------")