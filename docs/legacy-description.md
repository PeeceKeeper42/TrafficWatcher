# Аудит старого проекта (Qt 5.15.2 / C++17)

Репозиторий был очищен коммитом `9b911bf` («Delete whole project, new iteration…»).
Полное дерево предыдущей итерации доступно из истории — это наш «эталон для повторения и развития»:

```bash
git ls-tree -r --name-only 44ffd1b              # список файлов
git show 44ffd1b:src/TrafficLight.h             # любой файл
git show 44ffd1b:cmake/CompilerOptions.cmake
git log --oneline --all
```

История: `d35f99f init` → `e0bf34a Основная функционал` → `44ffd1b Доработка тесты (не работают)` →
`9b911bf удаление` → `dbf478d .gitignore`.

## Что было

```
CMakeLists.txt                       Qt5, option(BUILD_TESTS), generate_deployment_scripts()
cmake/QtSetup.cmake                  find_package(Qt5), CMAKE_PREFIX_PATH хардкодом, target_link_qt()
cmake/CompilerOptions.cmake          флаги предупреждений GCC/Clang/MSVC через генераторные выражения
cmake/Defines.cmake                  CMAKE_CXX_STANDARD 17, дефайны по CONFIG и PLATFORM_ID
cmake/Functions.cmake + Deploy.{bat,sh}.in
src/TrafficLight.{h,cpp}             контроллер: список состояний, currentIndex, QTimer, blinkPhase
src/StateModel.{h,cpp}               QAbstractListModel + QList<TrafficLightState*> (владелец)
src/TrafficLightState.{h,cpp}        TrafficLightMode (enum Mode{Off,On,Blink}+duration) ×3 канала
src/main.cpp                         QGuiApplication + 4× qmlRegisterType + load("qrc:/qml/main.qml")
resources/resources.qrc
resources/qml/main.qml               ApplicationWindow, RowLayout, TrafficLight { id: trafficLight }
resources/qml/TrafficLightUi/        qmldir + singleton Theme.qml + LightBulb/StateEditor/Styled* (11 файлов)
tests/test_trafficlightstate.cpp     QTest-юнит
tests/test_ui.cpp                    QTest + QGuiApplication + QML (интеграция)
```

Хорошего, что стоит сохранить как инстинкт:

- `cmake/*.cmake` разнесены по ответственностям, а не один файл на 400 строк;
- генераторные выражения для флагов (`$<$<CXX_COMPILER_ID:...>>`) и дефайнов (`$<$<PLATFORM_ID:Windows>>`) — уже «взрослый» CMake;
- Doxygen на каждом классе/методе, `Q_ENUM`, `Q_PROPERTY` c NOTIFY, `Q_INVOKABLE` для методов из QML;
- разделены юнит-тест ядра и UI-тест;
- контроллер (`TrafficLight`) отделён от модели (`StatesModel`) и от представления (`TrafficLightUi`).

## Что устарело / болит → вектор переписывания

| # | Находка в старом коде | Проблема в Qt6 / C++20 / CMake4 | Модуль курса |
|---|---|---|---|
| 1 | `find_package(Qt5)`, `Qt5::Core`, `CMAKE_PREFIX_PATH` = `D:/Qt/5.15.2/msvc2019_64` прямо в модуле | Qt6 → versionless `Qt::Core`; путь к Qt обязан приходить из пресета/окружения, а не из `if(NOT ...) set(...)` | 1.2, 2.1 |
| 2 | `set(CMAKE_AUTOMOC/AUTORCC/AUTOUIC ON)` вручную | `qt_standard_project_setup()` + `qt_policy()` стандартизируют это | 2.1 |
| 3 | 4× `qmlRegisterType` в `main.cpp`, ручной `qmldir`, QML через `.qrc` | `QML_ELEMENT` + `qt_add_qml_module()`: регистрация генерится на билде, работает в статических сборках, включается `qmlcachegen` и qmllint-автодополнение | 2.2, 2.3 |
| 4 | `cmake_minimum_required(VERSION 3.16)` | На установленном CMake 4.3 `find_package(Qt5)` падает (`Compatibility with CMake < 3.5 has been removed` в файлах Qt5Config) — старой веткой на этой машине уже не собрать | 1.1 |
| 5 | `include_directories(${CMAKE_SOURCE_DIR}/src)` в `tests/CMakeLists.txt` | Global includes = «action at a distance»; нужно `add_library(core STATIC)` + `target_link_libraries(test PRIVATE TrafficWatcher::Core)` | 1.1, 1.3 |
| 6 | `set(TrafficLight_Headers ...)`, проброс в родителя через `PARENT_SCOPE`, `list(FILTER ... EXCLUDE REGEX "main\.cpp$")` в тестах | Родитель не должен знать список файлов ребёнка; переиспользование источников тестами — через отдельный таргет, а не фильтр по regex | 1.3 |
| 7 | `/W4 /WX` всегда, `-Wall -Wextra ...` на всех | `-Werror` имеет смысл только в CI-пресете: падать на предупреждениях нового компилятора у тиммейта — убить продуктивность | 1.2, 10.2 |
| 8 | `-fstack-protector-strong -fPIE` для всего блока GNU-флагов | Не все флаги валидны для AppleClang; нужна проверка `check_cxx_compiler_flag` и `$<COMPILE_LANGUAGE>` | 1.1, 7.1 |
| 9 | `#include <windows.h>` + `SetConsoleOutputCP(CP_UTF8)` в `main.cpp` | Платформенный код без прослойки — то, что по требованию выносится в `src/platform/` | 7.1 |
| 10 | `Q_PROPERTY(int mode READ getMode WRITE setMode)` для `enum Mode` | Тип свойства должен быть `Mode`: тогда в QML это `Light.Mode.Off`, а не магическое `2`, и qmllint/IDE это проверяют | 4.2, 5.1 |
| 11 | Тесты «не работают» (коммит так и называется); `add_test` без `WORKING_DIRECTORY`/`ENVIRONMENT` | Без CTest-свойств, `QT_QPA_PLATFORM=offscreen` и поиска QML-импорта тесты обречены; нужен также `--output-junit` и coverage-лот | 8.1–8.3 |
| 12 | Деплой через `Deploy.bat.in` / `Deploy.sh.in`, `@...@`-подстановка на configure | Qt6: `qt_generate_deploy_qml_app_script()` — install-time скрипт, один на 3 платформы, вместо двух шаблонов | 9.1 |
| 13 | Имя: папка `TrafficWatcher`, `project(TrafficLight)`, старый `.iml` = `TraficLighter` | Одно имя на всё. В Qt6 имя проекта и URI QML-модуля — это API, переименование потом дорого | 1.1, 2.2 |
| 14 | `git log` по кириллическим коммитам даёт `╨Ю╤Б╨╜╨╛╨▓╨╜...` | Кодировка консоли/`i18n.*`; выстрелит в CI-логах и CDash-заметках | 10.1 |
| 15 | В `.gitignore` есть строка `*.cmake` | Игнорирует **будущие** модули в `cmake/` (пока папки нет — не видно). Игнорить надо конкретные генерируемые файлы | 1.1 |

## Что стоит перенести как есть

- Разделение «контроллер / модель / UI-компоненты» — оно уже правильное, просто переезжает на Qt6-механику.
- Идея QML-подмодуля с темой (`TrafficLightUi` + singleton `Theme`) → станет `qt_add_qml_module(URI TrafficWatcher.UI)` с темой на C++.
- Идея «два слоя тестов» (ядро и UI) → станет `tests/unit` + `tests/qml` с CTest-фикстурами.
