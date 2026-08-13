# =============================================================================
# src/CMakeLists.txt — файлы и сборка исполняемого модуля
# =============================================================================

set(TrafficLight_Headers
    ${CMAKE_CURRENT_SOURCE_DIR}/TrafficLight.h
)

set(TrafficLight_Sources
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/TrafficLight.cpp
)

set(TrafficLight_Forms 

)

set(TrafficLight_Resources
    ${CMAKE_SOURCE_DIR}/resources/resources.qrc
)

# Создаём исполняемый файл
add_executable(trafficlight
    ${TrafficLight_Headers}
    ${TrafficLight_Sources}
    ${TrafficLight_Forms}
    ${TrafficLight_Resources}
)

# Пути для поиска заголовков
target_include_directories(trafficlight PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    #
)

apply_compiler_options(trafficlight)

apply_common_definitions(trafficlight)

target_link_qt(trafficlight)

set(TrafficLight_Sources ${TrafficLight_Sources} PARENT_SCOPE)
set(TrafficLight_Headers ${TrafficLight_Headers} PARENT_SCOPE)
set(TrafficLight_Resources ${TrafficLight_Resources} PARENT_SCOPE)
set(TrafficLight_Forms ${TrafficLight_Forms} PARENT_SCOPE)