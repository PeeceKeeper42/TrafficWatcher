# Урок 01 — CMake как граф таргетов: пресеты, тесты и упаковка по эталону

## Блок 1. Карточка

| Поле | Значение |
|---|---|
| Модуль / урок | **Модуль 1**, строки плана `1.1`–`1.5` ([`docs/course.md`](../course.md), «Модуль 1 — Современный CMake как граф таргетов», строка 105). Обозначение `1.M` = строка плана; физически это цикл `M` этого файла |
| Веха | **M1** (паритет) |
| Артефакт на выходе | одна команда на шаг: `cmake --preset win-ninja-debug` → `cmake --build --preset win-ninja-debug` → `ctest --preset win-ninja-debug`; на выходе запускаемый `tw_app.exe`, один зелёный тест с лейблом `smoke`, граф в `build/graph/deps.dot`, заготовка `install(EXPORT)` в `core/` |
| На входе (prerequisites) | **ожидаемое**, урок [00](00-territory-and-toolchain.md) не закрыт (замер 24.11.2026: Qt 6 отсутствует, `ninja` и компилятор вне `PATH`): ADR-0001 с компилятором, генератором, Qt-китом и версией CMake; `cmake-build-debug/` без чужого кэша (уже так — замер); [`CMakeLists.txt`](../../CMakeLists.txt) из четырёх значащих строк, таргетов ноль |
| Порождаемые ADR | **0001** (подтверждается сборкой), **0002** (имя / namespace / include-путь / URI), **0003** (политика предупреждений), **0004** (layout), **0020** (ветвление и тег модуля) |
| Эталон урока | fmt, spdlog, nlohmann/json, googletest, Catch2, assimp, qt-creator, vcpkg-tool — свод правил в преамбуле блока 5, разбор в блоке 8 |
| Вопросы и следующий урок | [`docs/answers/01-cmake-target-graph.md`](../answers/01-cmake-target-graph.md); дальше — [урок 02 «Qt 6 в CMake»](02-qt6-in-cmake.md) (модуль 2, веха M1) |

## Блок 2. Цели и доказательства

После урока ты умеешь:

| Цель | Где отрабатывается | Чем доказывается |
|---|---|---|
| **Строить граф таргетов так, как его строят библиотеки-эталоны**: тип + namespaced `ALIAS` + usage requirements в `PUBLIC`/`INTERFACE` | цикл 1, разбор (1)–(10) | `cmake -S . -B build/graph --graphviz=…`: ребро `tw_app → tw::core` есть, обратного нет; D1 |
| **Выбрать keyword по направлению требования** и назвать симптом ошибки по строке диагностики, а не по статье | цикл 1, дырявый пример, тонкость 1–2 | вопрос A2 в `answers/` |
| **Держать одну точку входа для IDE, терминала и CI**: многослойные `hidden`-пресеты, `${presetName}`, `$env{}`, одинаковые имена у configure/build/test | цикл 2, разбор (1)–(8) | `cmake --list-presets` и `cmake --list-presets=test` печатают один и тот же набор имён; D2 |
| **Отличать то, что CMake действительно реализует, от того, что есть только в JSON-схеме сообщества** | цикл 2, «Ловушка» про `matrixPresets` | `(cmake --help-manual cmake-presets \| Select-String matrix).Count` → **0** (замер 25.11.2026) |
| **Разложить репозиторий на `core/ app/ cmake/ tests/`** так, чтобы публичные заголовки были видны через `include/<ns>/`, а `install()`-скелет был написан рядом с определением таргета | цикл 3 | дерево в D4; `git grep -n "file(GLOB"` → пусто |
| **Видеть в `.gitignore` спецификацию поставки**, а не «файл мусора»: тот же список читает CPack при сборке source-пакета | цикл 4 | `git check-ignore -v cmake/TwWarnings.cmake` → код 1, вывод пуст (замер 24.11.2026); D6 |
| **Подключить CTest способом, который уважает чужой граф**: `include(CTest)` → `BUILD_TESTING` → свой `TW_BUILD_TESTS` | цикл 5 | `ctest --preset …` печатает `Total Tests: 1`, а `-L nosuchlabel` даёт `No tests were found!!!` и код **0** (замер) — и ты объясняешь, почему это красный шаг, а не зелёный; D8 |
| **Разделить коммиты по причине** и закрыть модуль тегом | цикл 4 | `git log --oneline -8`, `git describe --tags --abbrev=0`; D7 |

**Как читать урок.** Блоки 1–2 и 7 — первый проход: зачем и чем доказывается. Второй проход — циклы
практикума по порядку: каждый следующий надстраивается над сборкой предыдущего, переставлять их нельзя.
Внутри цикла порядок фиксирован: **механика → почему именно так → что будет, если нарушить → тонкость →
мини-практика**; в конце цикла — строка «Эталон» с конкретными `файл:строка` изученных репозиториев.
Ссылки на upstream ведут на ветки `master`/`devel` по состоянию на 25.11.2026: номера строк там смещаются,
проверяй diff-ом, а не цитатой. Термины без перевода — глоссарий блока 8; конструкции — сводка блока 8.

### Мини-практика на 3 минуты

```powershell
cmake -S . -B build/probe -G Ninja
cmake --list-presets
```

Замер 24.11.2026 на текущем репозитории и текущей машине (блокеры B1–B2 урока 00 ещё не закрыты):

```text
CMake Error: CMake was unable to find a build program corresponding to "Ninja".  CMAKE_MAKE_PROGRAM is not set.
CMake Error: CMAKE_CXX_COMPILER not set, after EnableLanguage
-- Configuring incomplete, errors occurred!
```

```text
CMake Error: Could not read presets from C:/Projects/TrafficWatcher:
File not found: C:/Projects/TrafficWatcher/CMakePresets.json
```

Первый вывод чинится ADR-0001 (это про тулчейн, не про граф), второй — уроком: `CMakePresets.json` появится
в цикле 2. Смысл практики — зафиксировать состояние входа: `build/probe` конфигурируется, но цели
`tw_app` не имеет, потому что таргетов в репозитории ещё нет. Каталог `build/probe` после опыта удали:
[`.gitignore:4`](../../.gitignore#L4) скрывает `build/`, но не чистит его.

## Блок 3. Проблема урока

Репозиторий уже «проект на CMake»: в [`CMakeLists.txt:3`](../../CMakeLists.txt#L3) —
`cmake_minimum_required(VERSION 4.3.2)`, в [`:4`](../../CMakeLists.txt#L4) —
`project(TrafficWatcher LANGUAGES CXX)`. Ни таргета, ни пресета, ни теста. Из этого состояния растут пять
дефектов, и все пять в изученных проектах закрыты механически, а не договорённостью:

| Дефект здесь | Чем закрыт в эталоне | Какой цикл |
|---|---|---|
| `4.3.2` — это версия моей машины, а не минимум проекта; `cmake` из бандла CLion (4.2.2) этот файл не читает | fmt пишет `VERSION 3.8...3.28`, spdlog — `3.10...3.21`, nlohmann/json — `3.5...4.0` (замер 25.11.2026) | 1 |
| У требований нет носителя: include-путь можно положить в `include_directories` «наверху», и тогда consumer-тест 11.3 ничего не докажет | у всех восьми проектов путь живёт в `target_include_directories` с парой `$<BUILD_INTERFACE>` / `$<INSTALL_INTERFACE>` | 1, 3 |
| Таргет доступен потребителю как голое `tw_core`: опечатка в имени превращается в «link с флагом `tw_core`», а чужой таргет с тем же именем — в тихий конфликт | `add_library(fmt::fmt ALIAS fmt)`, `spdlog::spdlog`, `nlohmann_json::nlohmann_json`, `GTest::gtest` — имя с namespace создаётся рядом с определением | 1 |
| Сборка зависит от того, что я набрал руками: урок 00 нашёл в `cmake-build-debug/` кэш от WSL (`CMAKE_GENERATOR:INTERNAL=Unix Makefiles`, `CMAKE_HOME_DIRECTORY=/mnt/c/…`) | пресеты layered: `base` → `debug`/`windows` → именованный, `binaryDir: "out/build/${presetName}"` (vcpkg-tool) | 2 |
| Тесты и установка включаются всегда: `enable_testing()` «где-то», `install()` «когда-нибудь в 11» | `include(CTest)` + гейт `BUILD_TESTING AND … AND NOT_SUBPROJECT` (Catch2), `option(... ${FMT_MASTER_PROJECT})` (fmt), `PROJECT_IS_TOP_LEVEL` (spdlog) | 4, 5 |

Пятого дефекта здесь ещё нет, но он дороже остальных: **`.gitignore` никто не читает как спецификацию
поставки**. fmt генерирует `CPACK_SOURCE_IGNORE_FILES` из собственного `.gitignore`
([`CMakeLists.txt:653–672`](https://github.com/fmtlib/fmt/blob/master/CMakeLists.txt)), а Catch2 прямо пишет,
что установка в sub-project ломает destinations
([`CMakeLists.txt`, комментарий к `#1373`](https://github.com/catchorg/Catch2/blob/devel/CMakeLists.txt)).
Урок 00 нашёл у нас правило `*.cmake`, которое прятало будущий `cmake/TwWarnings.cmake`, — снято владельцем
24.11.2026. В этом уроке тот же файл становится аргументом: то, что скрыто от git, скрыто и от пакета.

К концу урока: `cmake --preset win-ninja-debug` — единственная команда конфигурации; `tw_app → tw::core`
виден в `deps.dot`; `ctest --preset` даёт один зелёный тест; в `core/CMakeLists.txt` рядом с `add_library`
лежит `install(TARGETS … EXPORT …)`-скелет, а в `CMakePresets.json` — три вида пресетов с одинаковыми именами.

## Блок 4. Приложение: вход → выход

| | Состояние |
|---|---|
| **Вход** (ожидаемый, см. блок 1) | после урока 00: тулчейн назван в ADR-0001, Qt 6.10.x установлен, чужого кэша нет; собирается [`CMakeLists.txt`](../../CMakeLists.txt) из четырёх строк, таргетов ноль, пресетов ноль |
| **На выходе** | `core/` (таргет `tw_core` + `ALIAS tw::core` + строительный `Mode.hpp`), `app/` (`tw_app.exe`), `cmake/TwWarnings.cmake` (функция `tw_add_warning_flags`), `tests/` (`tw_tests`, один тест с лейблом `smoke`), `CMakePresets.json` с `configurePresets`/`buildPresets`/`testPresets`, `build/graph/deps.dot`; в `core/` — заготовка `install(TARGETS … EXPORT)` и `include(GNUInstallDirs)`; `cpack --list-presets` находит `package`-пресет |
| **Следующий урок открывается** | с двумя таргетами, собранными из пресета, и с `BUILD_TESTING`, который модуль 8 использует как рубильник; `ui/`-каталог в layout только зарезервирован — `qt_add_qml_module` из модуля 2 придёт в него |

**Строительный код (срок жизни указан).** `core/include/trafficwatcher/core/Mode.hpp` — `enum class Mode`
с одной non-inline функцией: нужен, чтобы у `tw_core` было требование к компиляции, а у теста — что
проверять. Замена — **урок 6.1** (реальная стейт-машина светофора, [`course.md`](../course.md), блок II),
удаление `Mode` — пункт его задания. `app/src/main.cpp` — не заглушка, а будущая точка входа: остаётся до
конца курса. Заготовка `install(EXPORT)` — строительная в том же смысле: проверяется consumer-тестом 11.3,
а до него она обязана лишь не ломать конфигурацию, но не обязана работать.

### Таблица усложнения: конструкции урока 00 меняются здесь

| Конструкция | Появилась | Как усложняется здесь |
|---|---|---|
| `CMakeCache.txt` как источник правды о каталоге сборки | [урок 00, блок 8](00-territory-and-toolchain.md) | появляется `binaryDir` пресета **и** `${presetName}` в нём: каталог выбирается не руками и не IDE, а именем пресета; чужой кэш становится невозможным, а не «найденным и удалённым». Проверка: `Test-Path build/win-ninja-debug/CMakeCache.txt` |
| Выбор генератора (`Ninja` vs `Visual Studio`) | урок 00, блок 4 | генератор — свойство пресета, и из него растут три поведения: у Ninja нужен `CMAKE_BUILD_TYPE`, у VS — `--config`; `CMAKE_EXPORT_COMPILE_COMMANDS` на VS игнорируется («implemented only by Makefile Generators and Ninja Generators» — `cmake --help-variable`), а значит clang-tidy из 10.2 живёт только в Ninja-пресетах |
| Разные версии `cmake` (`PATH` vs бандл IDE) | урок 00, тонкость 2 | `cmake_minimum_required(VERSION <min>[...<policy_max>])`: `...` из 4.3.2-документации превращает расхождение версий в число — минимум обязан быть не выше 4.2.2, а `policy_max` задаёт поколение политик (`CMP0079`, `CMP0077`), от которого зависит, пройдёт или нет `target_link_libraries` чужого каталога |
| Правило `*.cmake` в `.gitignore` | урок 00, находка + D5 | `.gitignore` становится входом для сборки: из него fmt делает `CPACK_SOURCE_IGNORE_FILES`, а мы — проверку D6 и причину, по которой `cmake/TwWarnings.cmake` обязан быть в индексе |
| `where.exe` / `Test-Path` («нет на диске» vs «нет в `PATH`») | урок 00, тонкость 1 | компилятор приходит через `toolchainFile` или `CMAKE_CXX_COMPILER` в `cacheVariables` пресета; вопрос «виден ли он в `PATH`» заменяется вопросом «какой пресет выбран», и проверяется это копией репозитория без `PATH`-изменений (шаг 8) |
| `cmake --list-presets` и коды возврата | урок 00, цикл 3 | та же команда вызывается с `[=<type>]`: `configure`, `build`, `test`, `package`, `workflow` (`cmake --help`); инвариант урока — одинаковые имена в трёх первых списках, а не просто «список непустой» |

## Блок 5. Практикум

Пять циклов = пять строк плана модуля 1. Порядок не произволен: в цикле 1 появляется граф, в 2 — точка
входа в него, в 3 — каталоги, в 4 — правила индекса и упаковки, в 5 — тест. Правка в цикле 1 видна в
цикле 5 сразу: например, `INTERFACE`-таргет без `ALIAS` сломает и `ctest`, и `install(EXPORT)`.

### Свод эталонных правил

Восемь правил, снятых с изученных `CMakeLists.txt` 25.11.2026 (полные ссылки — блок 8). Каждое — с колонкой
«чем проверить», потому что правило без проверки — мода, а не инженерия.

| # | Правило эталона | Где в уроке | Чем проверить |
|---|---|---|---|
| 1 | `cmake_minimum_required(VERSION <min>...<policy_max>)` — диапазон; минимум ниже самой сладой точки входа | цикл 1 (1) | `cmake --help-command cmake_minimum_required` |
| 2 | У каждого публичного таргета — `ALIAS` с namespace, созданный рядом с определением | цикл 1 (6) | `cmake --help-command add_library` (форма `ALIAS <target>`) |
| 3 | Include-путь парой: `$<BUILD_INTERFACE:…>` **и** `$<INSTALL_INTERFACE:…>` | цикл 1 (8), цикл 3 | `cmake --help-manual cmake-generator-expressions` |
| 4 | Всё, чего не должно быть у потребителя, гейтится top-level-флагом: `PROJECT_IS_TOP_LEVEL` (3.21+) или `X_MASTER_PROJECT` | цикл 1 (4), цикл 5 | `cmake --help-variable PROJECT_IS_TOP_LEVEL` |
| 5 | Тесты подключаются через `include(CTest)`, то есть через общий `BUILD_TESTING`, а не своей кнопкой | цикл 5 | `cmake --help-module CTest` |
| 6 | Пресеты многослойные (`hidden`-базы), `binaryDir`/`installDir` через `${presetName}`, машинное — через `$env{}`; configure/build/test/package носят **одинаковые имена** | цикл 2 | `cmake --list-presets=test`, `cpack --list-presets` |
| 7 | Каталог `cmake/` с функциями проекта лежит в `CMAKE_MODULE_PATH`, а не копируется в каждый `CMakeLists.txt` | цикл 3 | `cmake --help-variable CMAKE_MODULE_PATH` |
| 8 | `install()`/`CPack` описаны рядом с таргетом и gated тем же top-level-флагом; source-пакет строится из `.gitignore` | цикл 4 | `cmake --help-module CPackComponent`, `cpack --help` |

### Цикл 1 — Таргет, alias и направление требований (план 1.1; ≤25 минут)

**1. Механика: разбор (1)–(10).** Минимальный граф в форме, которую используют библиотеки-эталоны.

```cmake
# ── (1) CMakeLists.txt, корень
cmake_minimum_required(VERSION 3.28...4.3)     # min...policy_max, см. таблицу усложнения блока 4
project(TrafficWatcher VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)                         # (2) CMAKE_INSTALL_{BINDIR,LIBDIR,INCLUDEDIR,DOCDIR}
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")   # (3)

option(TW_BUILD_TESTS "Build tw_tests" ${PROJECT_IS_TOP_LEVEL})   # (4) 3.21+
option(TW_INSTALL   "Generate install rules" ${PROJECT_IS_TOP_LEVEL})

add_subdirectory(core)
add_subdirectory(app)
if(TW_BUILD_TESTS)
  add_subdirectory(tests)                       # (5)
endif()
```

```cmake
# ── (6) core/CMakeLists.txt
add_library(tw_core STATIC src/Mode.cpp)
add_library(tw::core ALIAS tw_core)             # (7) имя с namespace — рядом с определением
target_compile_features(tw_core PUBLIC cxx_std_20)          # (8)
target_include_directories(tw_core PUBLIC                    # (9)
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
set_target_properties(tw_core PROPERTIES FOLDER core)        # (10)

# ── app/CMakeLists.txt
add_executable(tw_app src/main.cpp)
target_link_libraries(tw_app PRIVATE tw::core)               # потребитель линкует namespaced-имя
```

Что делает каждый пункт и почему именно так:

1. **`VERSION 3.28...4.3`** — две числа с литералом `...`: минимум и граница политик. Форма — `cmake --help-command
   cmake_minimum_required` (note про версии «older than 3.12»: старые CMake видят только минимум). Обе наши
   точки входа (4.3.2 из `PATH`, 4.2.2 из бандла CLion) ≥ 3.12 — диапазон работает у обеих.
2. **`include(GNUInstallDirs)`** — иначе `install()` пишет `lib/` на одной машине и `lib64/` на другой, и
   пакет 11.x разваливается на RPM-ориентированных дистрибутивах.
3. **`CMAKE_MODULE_PATH`** — один раз на корень; отсюда в цикле 4 вызывается `tw_add_warning_flags`.
4. **`PROJECT_IS_TOP_LEVEL`** (3.21+, `cmake --help-variable`) — **значение по умолчанию** опции: в
   sub-project рубильник выключен, в своём проекте — включён. Эталон оборачивает её в
   `FMT_MASTER_PROJECT`/`SPDLOG_MASTER_PROJECT` с `NOT DEFINED`-fallback; при нашем минимуме 3.28
   fallback не нужен — ровно здесь диапазон лучше их `3.8`/`3.10`.
5. **`add_subdirectory(tests)` под флагом** — чтобы чужой граф, `add_subdirectory`-ящий нас, не собирал наши
   тесты: так же поступают Catch2 (`NOT_SUBPROJECT`) и fmt.
6. **`add_library(tw_core STATIC …)`** — тип указан явно: иначе решает `BUILD_SHARED_LIBS`, то есть чужой кэш
   меняет наш артефакт (у googletest это публичная опция — она же причина трёх `DESTINATION` в цикле 4).
7. **`ALIAS`** — `add_library(<name> ALIAS <target>)`; потребители пишут только `tw::core` (ADR-0002). fmt
   генерирует их макро, nlohmann пишет рядом; в `install(EXPORT)` тот же namespace — свойство `NAMESPACE`.
8. **`cxx_std_20` в `PUBLIC`** — это *feature*, а не флаг: CMake сам подставит `/std:c++20` или
   `-std=gnu++20`; `PUBLIC`, потому что стандарт — часть чужого требования к компиляции.
9. **Пара `BUILD_INTERFACE`/`INSTALL_INTERFACE`** — первое работает при сборке из исходников, второе попадает
   в `twTargets.cmake` после `install(EXPORT)` (11.3); без него consumer-тест падает не у нас, а у пользователя.
10. **`FOLDER`** — группирует таргеты в VS/CLion; `USE_FOLDERS` — глобальное свойство (`cmake --help-properties`).

**Дырявый пример (часть 2 цикла).** Тот же `core/CMakeLists.txt`, из которого вынуты три строки. Сначала
предскажи фазу (конфигурация / компиляция / линковка / `ctest`), потом проверяй:

| Вырезано | Предсказание | Чем проверить |
|---|---|---|
| `add_library(tw::core ALIAS tw_core)` | падает **конфигурация** `app/`: CMake печатает `… links to …` и список причин «typo in the target name / a find_package call is missing for an IMPORTED target / an ALIAS target is missing» (три строки найдены в `cmake.exe` 4.3.2, замер 25.11.2026) | `cmake -S . -B build/d1 -G Ninja` |
| `PUBLIC` → `PRIVATE` в `target_include_directories` | конфигурация зелёная, падает **компиляция** `tw_app`: заголовок не уехал в его interface | `cmake --build build/d1` |
| `target_compile_features(...)` целиком | падает **компиляция**, но на конструкции C++20, а не на путях; стандарт при этом не «наш», а дефолт компилятора | `Select-String build/d1/build.ninja -Pattern "std"` |

**2. Почему сделано именно так.** Таргет — носитель требований: `PUBLIC`/`INTERFACE` превращают зависимость
в строку в чужой команде компиляции. Диапазон вместо одной версии — потому что `cmake_minimum_required`
задаёт **поколение политик** (`cmake_policy(VERSION <min>[...<policy_max>])`, формулировка из `--help-command`),
которое решает, включена `CMP0079` или нет. У эталона минимум всегда сильно ниже версии автора: fmt `3.8`,
nlohmann `3.5`, googletest `3.13`, Catch2 `3.16`, assimp `3.22`, spdlog `3.10` — «моя версия = минимум» не пишет ни один.

**3. Что будет, если нарушить.**

| Нарушение | Конкретный симптом | Где чинить |
|---|---|---|
| `target_compile_features(tw_core PRIVATE cxx_std_20)` | `tw_core` собирается, `tw_app` падает на разборе `Mode.hpp` (`concept`, `<=>`, `consteval`): у него стандарт по умолчанию компилятора, а он у MSVC и GCC разный | шаг 2, `PUBLIC` (тонкость 1) |
| Только `$<BUILD_INTERFACE:…>`, без `INSTALL_INTERFACE` | конфигурация и сборка зелёные; `install(EXPORT)` из 11.3 отдаёт путь к **build**-дереву, и на чистой машине consumer-тест находит несуществующий каталог | шаг 2, вторая строка |
| Потребитель ссылается на `tw_core`, а не на `tw::core` | опечатка не видна: CMake трактует неизвестное имя как флаг линковщика, а конфликт имён с чужим таргетом становится тихим | шаг 2–3, `ALIAS` + `tw::` |

**Тонкость 1.** `PRIVATE`/`PUBLIC`/`INTERFACE` — не про «секретность», а про **направление распространения**:
`PRIVATE` — только при сборке самого таргета, `INTERFACE` — только у потребителя, `PUBLIC` — на обеих сторонах.
Отсюда проверяемое следствие: у `INTERFACE`-библиотеки `PRIVATE`-требования бессмысленны —
`add_library(tw_iface INTERFACE)` плюс `target_include_directories(tw_iface PRIVATE …)` даёт диагностику,
которую перечитывают целиком. Для курса `ui` (модуль 2) получит заголовки через `PUBLIC`, поэтому
`PRIVATE` здесь значит «модуль 2 не соберётся», а не «безопаснее».

**Тонкость 2.** У относительного include-пути три судьбы, все в `cmake --help-command target_include_directories`:
обычная строка конвертируется в абсолютную относительно `CMAKE_CURRENT_SOURCE_DIR`; путь, который
**начинается** с генераторного выражения, «will be used unmodified» — `$<BUILD_INTERFACE:include>`
абсолютным не станет; относительный путь внутри `$<INSTALL_INTERFACE:…>` читается от префикса установки.
Симптом второго случая — не ошибка у `tw_core`, а `fatal error: trafficwatcher/core/Mode.hpp: No such
file or directory` при сборке `tw_app` (GCC; MSVC — `C1083`); проверяется `INCLUDES` в `build/graph/build.ninja`.

**4. Мини-практика и чекпойнт (5 минут).**

```powershell
cmake -S . -B build/graph -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake -S . -B build/graph --graphviz=build/graph/deps.dot
Select-String -Path build/graph/deps.dot -Pattern "tw_core"
```

→ рёбра `tw_app -> tw_core` и `tw_tests -> tw_core`, обратных нет; `--graphviz=<file>` — та же конфигурация
(`cmake --help`, настройки — `CMakeGraphVizOptions.cmake`); в схеме ≥10 тот же граф — полем `graphviz` в пресете.

**Эталон цикла:** [fmt `:251,255–256`](https://github.com/fmtlib/fmt/blob/master/CMakeLists.txt) — `ALIAS` + пара interface;
[spdlog `:203,216,222`](https://github.com/gabime/spdlog/blob/v1.x/CMakeLists.txt) — `INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}`,
`DEBUG_POSTFIX`; [nlohmann/json `:150–151`](https://github.com/nlohmann/json/blob/develop/CMakeLists.txt) — `INTERFACE` + `ALIAS`; fmt `:1` — `VERSION 3.8...3.28`.

### Цикл 2 — Пресет как единственная точка входа (план 1.2; ≤25 минут)

**1. Механика: разбор (1)–(8).** `CMakePresets.json` в форме vcpkg-tool и qt-creator: слои, `${presetName}`,
`$env{}`, три вида пресетов с одинаковыми именами.

```jsonc
{
  "version": 3,                                       // (1) не максимум машины, а минимум нужного
  "configurePresets": [
    { "name": "base", "hidden": true,                 // (2) слой: общее
      "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/${presetName}", // (3) одна конфигурация — один каталог
      "installDir": "${sourceDir}/build/install/${presetName}",
      "cacheVariables": { "CMAKE_EXPORT_COMPILE_COMMANDS": true, "TW_BUILD_TESTS": true } },
    { "name": "win", "hidden": true, "inherits": [ "base" ],   // (4) слой: платформа
      "condition": { "type": "equals", "lhs": "${hostSystemName}", "rhs": "Windows" } },
    { "name": "debug", "hidden": true, "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" } },
    { "name": "win-ninja-debug", "inherits": [ "win", "debug" ],   // (5) выбор порядка наследования
      "displayName": "Windows · Ninja · Debug",
      "description": "Основной пресет курса. Компилятор берётся из окружения Visual Studio; без него конфигурация падает на CMAKE_CXX_COMPILER not set (замер 24.11.2026)." },
    { "name": "win-vs", "inherits": [ "win" ], "generator": "Visual Studio 17 2022",
      "architecture": { "value": "x64", "strategy": "set" },       // (6) multi-config: BUILD_TYPE не нужен
      "toolchainFile": "$env{TW_QT_TOOLCHAIN}" },                  // (7) машинное — наружу из файла
    { "name": "win-ninja-release", "inherits": [ "win" ],
      "cacheVariables": { "CMAKE_BUILD_TYPE": "Release" } }        // (8)
  ],
  "buildPresets": [
    { "name": "win-ninja-debug", "configurePreset": "win-ninja-debug" } ],
  "testPresets": [
    { "name": "win-ninja-debug", "configurePreset": "win-ninja-debug",
      "output": { "outputOnFailure": true } } ]
}
```

1. **`version: 3`** — ровно та схема, в которую входят все поля этого примера: `condition`, `installDir`,
   `toolchainFile`, опциональные `binaryDir`/`generator` и макрос `${hostSystemName}` (лестница схем — в
   `cmake --help-manual cmake-presets`: `2` → CMake 3.20, `3` → 3.21, `6` → 3.25, `11` → 4.3). Машина
   принимает до **11** (`Unrecognized "version" 99: must be >=1 and <=11`, замер 24.11.2026), но и
   qt-creator, и vcpkg-tool пишут `3`: чем ниже зафиксированная схема, тем более старый CMake прочитает
   файл (CI-образ, чужая IDE). Обратная сторона: `packagePresets`/`workflowPresets` и `outputJUnitFile` —
   **≥6**, `include` — **≥4**, `$penv{}` в `include` — **≥7**, `$comment` и `graphviz` — **≥10**. Значит
   номер схемы — часть ADR-0001, и поднимается он один раз: до 6 тогда, когда появляются package-пресеты.
2. **`hidden: true`** — базовые слои не выбираются напрямую («If a preset is hidden, it cannot be used in the …»
   в руководстве) и не засоряют `cmake --list-presets`: список остаётся списком реальных конфигураций.
3. **`${presetName}` в `binaryDir`** — каталог выводится из имени, поэтому два пресета физически не могут
   сесть в один кэш. Это и есть ответ на дефект урока 00: `cmake-build-debug/` создавался IDE, потому что
   каталог выбирал человек.
4. **`condition`** — объект с `type` ∈ `const|equals|notEquals|anyOf|allOf|not` и `${hostSystemName}`;
   пресет с ложным условием не предлагается, а не падает.
5. **Порядок в `inherits`** — правило из руководства: при конфликте побеждает **ранний** пресет в массиве.
   `["win", "debug"]` и `["debug", "win"]` дают разные результаты, если оба задают одно поле; путают это
   регулярно, поэтому `debug` у нас не трогает `generator`.
6. **`architecture`/`toolset`** — работают только с генераторами, которые их поддерживают (VS); с Ninja это
   игнорируемое поле, и проверка «пресет применим» здесь — лог конфигурации, а не чтение документации.
7. **`$env{}`** — не пишет абсолютный путь машины в отслеживаемый файл. Эталон делает так:
   `toolchainFile": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"` (vcpkg-tool),
   `$env{QT_HARMONYOS_ROOT}/…/qt.toolchain.cmake` (qt-creator). Машинное живёт в `CMakeUserPresets.json`
   ([`.gitignore:32`](../../.gitignore#L32)), который неявно включает `CMakePresets.json` в любой версии.
8. **`testPresets`/`buildPresets` с тем же именем**, что и configure-пресет: инвариант vcpkg-tool
   (`buildPresets`/`testPresets` перечисляют ровно те же `windows-ci`, `linux-debug`, `macos-ci`). Нарушение
   инварианта видно только в CI: `ctest --preset win-ninja-debug` падает с «not found», когда тестовый
   пресет назвали иначе.

**2. Почему именно так.** Пресет переносит точку входа из истории shell-а в отслеживаемый файл: IDE, терминал
и CI получают одно имя. `cacheVariables` пишутся в кэш **до** `project()`, поэтому компилятор и генератор
перестают быть наследием окружения (WSL-кэш из урока 00 — это ровно отсутствие пресета). `description` —
не комментарий, а документация окружения: у qt-creator в нём описано, что молча сломается без переменной
(`…the build silently falls back to the host compiler`).

**3. Что будет, если нарушить.**

| Нарушение | Симптом (замерено на этой машине) | Где чинить |
|---|---|---|
| Два пресета с одним `binaryDir`, разные генераторы | `Does not match the generator used previously: NMake Makefiles`, код 1; при одинаковом генераторе кэш **молча переиспользуется**, и `ctest` запускает бинарник предыдущей конфигурации | `${presetName}` в `binaryDir` (шаг 3) |
| `version` выше поддерживаемого | `Unrecognized "version" 99: must be >=1 and <=11`, код 1 | фиксировать схему в ADR-0001 |
| Неизвестное поле (`"nonexistentField": true`) | `Could not read presets from <каталог>`, код 1 — файл не читается целиком | `cmake --list-presets` после каждой правки |
| `CMakeUserPresets.json` в git | абсолютные пути одной машины в чужом CI; IDE на второй машине конфигурирует несуществующий кит | [`.gitignore:32`](../../.gitignore#L32) + `git check-ignore -v` (цикл 4) |
| `CMAKE_BUILD_TYPE` в `win-vs` вместо `--config`/`buildPresets.binaryDir` | multi-config генератор игнорирует `CMAKE_BUILD_TYPE`: собирается `Debug`, тестируется `Release` | `buildPresets` + `-C`, см. тонкость 4 |

**Тонкость 3.** `CMAKE_EXPORT_COMPILE_COMMANDS` из `base` — не «галочка для tidy»: руководство говорит —
«implemented only by Makefile Generators and Ninja Generators. It is ignored on other generators». В `win-vs`
поле молча не делает ничего, и clang-tidy из 10.2 на VS-пресете теряет все translation units без ошибки.
Проверяется: `Test-Path build/win-vs/compile_commands.json` → `False`, у Ninja → `True`. Следствие: CI
из 12.3 обязан запускать статический анализ только на Ninja-пресете.

**Тонкость 4.** Пресет — это не только конфигурация: у `cmake --list-presets` есть `[=<type>]`, и типы —
`configure`, `build`, `test`, `package`, `workflow` (`cmake --help`). Разные списки означают разный вопрос:
`configure` «что собрано», `test` «чем запускается», `package` «чем упаковывается». Эталон отвечает на все
три одним именем; наш курс отвечает на них же в 8.3 (`ctest --preset`), 11.x (`cpack --preset`) и 12.3
(`cmake --workflow --preset …`). Проверка: `cmake --list-presets=test` и `cpack --list-presets` (обе
подсхемы существуют, `cpack --help` → `--preset`, `--list-presets`).

**Ловушка.** Строка плана `1.2` когда-то обещала «Matrix-presets (`OS × compiler × config`)»; скорректирована
25.11.2026. Матрицы пресетов есть в JSON-схеме сообщества, но **не в реализации CMake**: `(cmake --help-manual
cmake-presets | Select-String matrix).Count` → **0** (замер 25.11.2026, CMake 4.3.2), а неизвестное поле
обрушивает чтение файла целиком (строка таблицы выше). Вывод, который надо проверить у себя: матрицу рисует
не CMake, а вызывающая сторона — CI-матрица GitHub (`--preset ${{ matrix.preset }}`) плюс hidden-слои, как
в vcpkg-tool; либо пресеты генерируются скриптом.

**5. Мини-практика и чекпойнт (2 минуты).**

```powershell
cmake --list-presets; $LASTEXITCODE
cmake --list-presets=test; $LASTEXITCODE
cmake --preset nope
```

→ первый список печатает `win-ninja-debug`, `win-vs`, `win-ninja-release` и **не** печатает `base`/`win`
(hidden); второй пуст или падает, пока `testPresets` не добавлены; третья команда — «preset not found», и её
код возврата отличается от «файла нет» (сравни с уроком 00, цикл 3).

**Эталон цикла:** [vcpkg-tool `CMakePresets.json`](https://github.com/microsoft/vcpkg-tool/blob/main/CMakePresets.json)
(version 3, `out/build/${presetName}`, `$env{VCPKG_ROOT}`, имена в build/test),
[qt-creator `CMakePresets.json`](https://github.com/qt-creator/qt-creator/blob/master/CMakePresets.json) (`hidden`-база, `description` как документация, `toolchainFile` через `$env{}`).

### Цикл 3 — Layout, `cmake/` и запрет `file(GLOB)` (план 1.3; ≤20 минут)

**1. Механика: разбор (1)–(6).** Дерево — по ADR-0004, функции проекта — как у эталона в `cmake/`.

```text
TrafficWatcher/
  CMakeLists.txt              # (1) только структура и гейты, ноль флагов
  CMakePresets.json           # (2)
  cmake/
    TwWarnings.cmake          # (3) функция tw_add_warning_flags(<target>...)
    TwPackaging.cmake         # (4) include(TwPackaging) -> install()/CPack, цикл 4
  core/
    include/trafficwatcher/core/Mode.hpp   # (5) публичный заголовок под namespace
    src/Mode.cpp
    CMakeLists.txt            # (6) здесь же — install(TARGETS ... EXPORT twTargets)
  app/src/main.cpp
  tests/                      # цикл 5
  ui/                         # резерв под модуль 2 (ADR-0004)
  packaging/                  # резерв под модуль 11
```

1. **Корень — структура, не флаги.** Все компиляторные решения живут в `cmake/` и вызываются по таргету:
   Catch2 держит хелперы в `extras/` и добавляет их в `CMAKE_MODULE_PATH` **и в PARENT_SCOPE**, assimp — в `cmake-modules/`.
2. **Пресеты рядом с корнем**, иначе IDE находит кэш раньше, чем проект — точку входа.
3. **`cmake/TwWarnings.cmake`** — ровно тот файл, который прятало правило `*.cmake` в уроке 00; он обязан
   быть в индексе, иначе на чистой машине конфигурация падает на `include()` («could not find requested
   file»), а локально всё зелёное.
4. **`cmake/TwPackaging.cmake`** — туда переезжает `install()`/`CPack` (цикл 4). Эталон: spdlog делает
   `include(cmake/spdlogCPack.cmake)` одной строкой, а не держит 60 строк CPACK-переменных в корне.
5. **`include/<ns>/`** — публичный API отличается от внутреннего путём, а не комментарием; `INSTALL_INTERFACE`
   из цикла 1 указывает именно на него.
6. **`install()` рядом с `add_library()`**, а не в отдельном «файле установки»:

```cmake
if(TW_INSTALL)                                          # гейт из цикла 1 (4)
  install(TARGETS tw_core EXPORT twTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}         # DLL на Windows
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
  install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
endif()
```

Три `DESTINATION` — разделение артефактов: Windows-DLL уходит в `RUNTIME`, импортная либа — в `ARCHIVE`;
напиши только `LIBRARY` — в пакет DLL не попадёт (spdlog, `:399–404`). Формы — `cmake --help-command install`.

**2. Почему сделано именно так.** Явный список источников против `file(GLOB)`: GLOB читает файловую систему
в момент конфигурации, поэтому новый `.cpp` не перетягивает graph — сборка «не заметит» файл до следующего
`cmake -S`. В корневых `CMakeLists.txt` пяти изученных проектов `file(GLOB` не встречается ни разу (замер
25.11.2026). Причина не в стиле: у GLOB нет момента обновления, а у `add_library` — есть.

**3. Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| `file(GLOB SRC "core/src/*.cpp")` | добавил `Tick.cpp` — сборка зелёная, функции нет; `ninja: no work to do`, хотя файл на диске | явный список (шаг 4) |
| `include_directories(core/include)` в корне | ребра в `deps.dot` нет; consumer-тест 11.3 не находит заголовки, потому что требование не уехало в `twTargets.cmake` | `target_include_directories` (цикл 1 (9)) |
| `cmake/TwWarnings.cmake` не в индексе | локально работает, в CI `include() could not find requested file` | D6, `git check-ignore -v` (цикл 4) |
| `install()` без `TW_INSTALL`-гейта | проект, который `add_subdirectory`-ит нас, устанавливает наши файлы в **свой** префикс (у Catch2 на это заведен issue `#1373`, и гейт стоит в коде) | шаг 4 + цикл 1 (4) |

**Ловушка.** Вызов `target_link_libraries(tw_app … tw::core)` из другого каталога исторически требовал, чтобы
таргет был создан там же, где его правят; сняла это политика `CMP0079` (`cmake --help-policy CMP0079`). Её
поколение включает `cmake_minimum_required`: ниже `policy_max` 3.13 та же строчка даёт `Attempt to add link
library "tw_core" to target "tw_app" which is not built in this directory.` (фрагмент в `cmake.exe` 4.3.2,
замер 24.11.2026). Проверка: поменяй `...4.3` на `...3.10` в корневом `CMakeLists.txt` — ошибка вернётся:
`policy_max` не декорация, а режим работы с чужими каталогами.

**Тонкость 5.** `add_subdirectory(tests)` даёт кэш в `<bindir>/tests` — до тех пор, пока ты не передашь
второй аргумент. Тривиально, пока один `binaryDir`; в 12.3, где один репозиторий конфигурируется матрицей,
путь `add_subdirectory(tests ${CMAKE_BINARY_DIR}/tests-${presetName})` — единственный способ не перемешать
тестовые каталоги двух конфигураций. Проверяется списком: `Get-ChildItem build -Directory`.

**6. Мини-практика и чекпойнт (3 минуты).**

```powershell
git ls-files core cmake app tests | Select-Object -First 12
cmake -S . -B build/graph --graphviz=build/graph/deps.dot
Get-Content build/graph/deps.dot | Select-String '"tw_core"'
```

→ ни один путь не помечен как отсутствующий (`git ls-files` молчит ровно на тех каталогах, которых ещё нет
в индексе — это и есть момент проверить D6), а в графе `tw_core` имеет степень ≥ 2 (`tw_app`, `tw_tests`).

**Эталон цикла:** [Catch2 `CMakeLists.txt`](https://github.com/catchorg/Catch2/blob/devel/CMakeLists.txt)
(`CMAKE_MODULE_PATH` + `PARENT_SCOPE`, `USE_FOLDERS ON`, `set(CMAKE_FOLDER "tests")`), [assimp `:316`](https://github.com/assimp/assimp/blob/master/CMakeLists.txt)
(`cmake-modules/`), [spdlog `:459`](https://github.com/gabime/spdlog/blob/v1.x/CMakeLists.txt) (`include(cmake/spdlogCPack.cmake)`).

### Цикл 4 — Индекс и `.gitignore` как спецификация поставки (план 1.4; ≤25 минут)

**1. Механика: разбор (1)–(12).** Упаковка живёт в `cmake/TwPackaging.cmake` — ровно так spdlog выносит
её из корня (`include(cmake/spdlogCPack.cmake)`, `:459`). Источник списка исключений — `.gitignore`, как у
fmt (`CMakeLists.txt:653–672`).

```cmake
# ── (1) cmake/TwPackaging.cmake
if(NOT PROJECT_IS_TOP_LEVEL)
  return()                                          # (2)
endif()

file(STRINGS "${PROJECT_SOURCE_DIR}/.gitignore" tw_ignore)   # (3)
list(FILTER tw_ignore EXCLUDE REGEX "^[[:space:]]*$")        # (4)
foreach(line IN LISTS tw_ignore)                             # (5)
  string(REPLACE "." "[.]" rx "${line}")
  string(REPLACE "*" ".*" rx "${rx}")
  list(APPEND tw_source_ignore "${rx}$" "${rx}/")
endforeach()
list(APPEND tw_source_ignore "/\\.git($|/)" "/build($|/)")   # (6)

set(CPACK_PACKAGE_NAME "TrafficWatcher")                     # (7)
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_CONTACT "https://github.com/PeeceKeeper42/TrafficWatcher")
set(CPACK_GENERATOR "ZIP")                                   # (8)
set(CPACK_SOURCE_GENERATOR "ZIP")                            # (9)
set(CPACK_SOURCE_IGNORE_FILES "${tw_source_ignore}")
include(InstallRequiredSystemLibraries)                      # (10)
include(CPack)                                               # (11)
```

```cmake
# ── (12) корневой CMakeLists.txt, после add_subdirectory(...)
if(TW_INSTALL)
  include(TwPackaging)          # ищется через CMAKE_MODULE_PATH из цикла 1 (3)
endif()
```

2. `return()` первой строкой — та же защита, что у Catch2, где весь install/CPack-блок обёрнут в
   `if(NOT_SUBPROJECT)`: `CPACK_*` — переменные обычного scope, в чужом графе они перекрыли бы его поставку.
3–6. `file(STRINGS <filename> <out-var>)` читает `.gitignore` списком строк, `list(FILTER … EXCLUDE REGEX)`
   убирает пустые, цикл превращает gitignore-маску в regex (`.` → `[.]`, `*` → `.*`) в двух формах: `${rx}$` —
   файл, `${rx}/` — каталог. Пункт (6) обязателен: fmt комментирует — «the .gitignore-derived `build/` pattern
   does not actually prune the directory or its contents».
7. `CPACK_PACKAGE_VERSION` из `project(VERSION 0.1.0)`: модуль CPack сам заполняет
   `CPACK_PACKAGE_VERSION_{MAJOR,MINOR,PATCH}` из версии проекта (`cmake --help-module CPack`) — второй
   источник номера в репозитории не появляется нигде (проверка D6).
8–9. `CPACK_SOURCE_*` описывают **source**-пакет, `CPACK_GENERATOR` — бинарный: дорожки разные, путают их в
   11.x. Здесь важно, что `ZIP` указан один раз и для той, и для другой.
10. `InstallRequiredSystemLibraries` заполняет `CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS` рантаймами MSVC («only
    with MSVC from Visual Studio 2015 or higher» — `cmake --help-module`); без него `tw_app.exe` на машине
    без Visual Studio не стартует — в вине это не наш баг, а поставка.
11–12. `include(CPack)` создаёт в каталоге сборки `CPackConfig.cmake` и `CPackSourceConfig.cmake`, которые
    читает следующий `cpack`; корень остаётся структурой (цикл 3, пункт 1) — в нём одна `include(TwPackaging)`.

**2. Почему именно так.** CPack: бинарные установщики «contain all files that have been installed via
`install()` command», source-пакет — «all source files… except those in `CPACK_SOURCE_IGNORE_FILES`».
Единственный отслеживаемый файл, описывающий оба списка, — `.gitignore`: что скрыто от git, скрыто и от
пакета. Поэтому правило `*.cmake` из урока 00 было не «конфигурацией мусора», а дырой: оно прятало
`cmake/TwWarnings.cmake` от индекса и выбрасывало бы его из source-пакета.

**3. Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| `install(TARGETS …)` без `RUNTIME DESTINATION` | в бинарном пакете нет DLL: CPack берёт только то, что установил `install()`, а не всё, что собралось | цикл 3, три `DESTINATION` |
| правило в `.gitignore` добавлено «на скорость» | файл исчезает из `git ls-files`, на чистой машине — `include() could not find requested file`, в пакете его тоже нет | D6, `git check-ignore -v` |
| `.gitignore` скопирован в `CPACK_SOURCE_IGNORE_FILES` без (6) | в релизный архив уезжает `build/CMakeCache.txt` чужой машины — ровно тот WSL-кэш из урока 00 | строка (6) |
| `include(CPack)` вызывается из `tests/CMakeLists.txt` | два вызова → два набора `CPackConfig.cmake`, `cpack` выбирает непредсказуемый | (11)–(12): один вызов на проект |

**Тонкость 6.** `CPACK_GENERATOR` имеет два смысла: в `CMakeLists.txt` — *list of generators*, в
`CPACK_PROJECT_CONFIG_FILE` — *single generator* (`cmake --help-module CPack`). `cpack` без `-G` проходит
по списку и делает **по пакету на каждый элемент**. Для логики «для ZIP одно, для NSIS другое» и существует
`CPACK_PROJECT_CONFIG_FILE`. Проверяется: `cpack -G "ZIP;TGZ"` даёт два файла (`;` зависит от оболочки).
Следствие: CI из модуля 12 обязан фиксировать `-G`, иначе число артефактов равно длине строки в `CMakeLists.txt`.

**Ловушка.** `include(CPack)` «may also add two new build targets, `package` and `package_source`» — и сразу
оговорка «depending on the CMake generator» (`--help-module CPack`). `cmake --build <dir> --target package`
на одном генераторе зелёный, на другом падает с «unknown target». Надёжная форма — явный вызов `cpack`:
`cpack --config build/win-ninja-debug/CPackConfig.cmake -G ZIP` (`cpack --help` → `-G`, `--config`, `--preset`).
Проверь обе формы: `cmake --build build/win-vs --target package` и `cmake --build build/win-ninja-debug --target package`.

**4. Мини-практика и чекпойнт (4 минуты).**

```powershell
Test-Path build/win-ninja-debug/CPackConfig.cmake
git check-ignore -v cmake/TwWarnings.cmake; $LASTEXITCODE
git ls-files .gitignore CMakePresets.json
```

→ первая `False` до `include(CPack)` и `True` после; вторая — пустой вывод и код **1** (замер 24.11.2026:
правило `*.cmake` снято); третья печатает оба пути. Если `CMakePresets.json` в этой паре помечен игнорируемым —
ты добавил его в `.gitignore`, и это откат цикла 2 (пресет обязан быть в индексе).

**Git: коммит по причине и тег модуля.** ADR-0020 (ветвление и тег) порождается этим циклом: именно здесь
появляется то, что стоит коммитить раздельно — граф, точка входа, layout, поставка. Проверки:

```powershell
git log --oneline -8
git describe --tags --abbrev=0    # код 128: fatal: No names found, cannot describe anything. (замер 24.11.2026)
git tag -a m01-done -m "развязало: …; сломалось: …; беру дальше: …"
```

Тег ставится **после** закрытых DoD: три строки в теле — ритуал ([`methodology.md`](../methodology.md) §2.11);
`git describe` до первого тега обязан вернуть 128 — это доказательство, что тег ещё не ставился.

**Эталон цикла:** [fmt `:653–672`](https://github.com/fmtlib/fmt/blob/master/CMakeLists.txt) (source-пакет из
`.gitignore`), [assimp `:319,880`](https://github.com/assimp/assimp/blob/master/CMakeLists.txt) (`CPACK_COMPONENTS_ALL`;
`CPACK_PACKAGE_CONTACT`), [spdlog `:459`](https://github.com/gabime/spdlog/blob/v1.x/CMakeLists.txt),
[Catch2](https://github.com/catchorg/Catch2/blob/devel/CMakeLists.txt) (`include(CPack)` внутри `if(NOT_SUBPROJECT)`).
Компоненты (`cpack_add_component`, `--help-module CPackComponent`) — модуль 11.

### Цикл 5 — CTest: рубильник, лейбл и честный код возврата (план 1.5; ≤25 минут)

**1. Механика: разбор (1)–(9).** Форма гейта — как у nlohmann/json (`:236–241`), проверка «не перекричать
родителя» — как у Catch2.

```cmake
# ── (1) корневой CMakeLists.txt, вместо «add_subdirectory(tests) всегда»
if(TW_BUILD_TESTS AND (NOT DEFINED BUILD_TESTING OR BUILD_TESTING))   # (2)
  include(CTest)                                                     # (3)
  add_subdirectory(tests)                                            # (4)
endif()
```

```cmake
# ── (5) tests/CMakeLists.txt
add_executable(tw_tests src/Mode_test.cpp)
target_link_libraries(tw_tests PRIVATE tw::core)        # (6) ALIAS из цикла 1 (7)
tw_add_warning_flags(tw_tests)                          # (7) функция из cmake/, цикл 3 (3)
add_test(NAME core/mode/smoke COMMAND tw_tests --case smoke)     # (8)
set_tests_properties(core/mode/smoke PROPERTIES LABELS "smoke" TIMEOUT 30)   # (9)
```

2. Порядок условия не косметика: `BUILD_TESTING` существует **только после** `include(CTest)`, поэтому сначала
   проверяется `NOT DEFINED` (nlohmann: «disabled by a parent project via BUILD_TESTING»). `TW_BUILD_TESTS` —
   второй рубильник: им управляет пресет (цикл 2), а родитель графа — общим `BUILD_TESTING`.
3. `include(CTest)` вместо голого `enable_testing()`: модуль `CTest` вызывает его сам («unless `BUILD_TESTING`
   is set to `OFF`»). Две границы в `--help-command enable_testing`: «should be invoked in the top-level source
   directory» и «must be called in file scope, not in a `function()` call nor inside a `block()`».
6. `tw::core` в `PRIVATE`: тесту не нужны наши include-пути «наружу», и `PRIVATE` здесь — проверка, что
   требование уехало от `tw_core`, а не дублируется (цикл 1, тонкость 1).
7. `tw_add_warning_flags(tw_tests)` вызывается из `tests/CMakeLists.txt` по таргету там же; функция в `cmake/`
   работает благодаря `CMP0079` (ловушка цикла 3), то есть `policy_max` из цикла 1 (1).
8. Форма `add_test(NAME …)`: только в `NAME`-форме имя таргета подставляется путём к бинарнику и работают
   генераторные выражения — «target names are not supported in the command-line» (`cmake --help-command add_test`).
9. `set_tests_properties(<tests>… [DIRECTORY <dir>] PROPERTIES <prop> <value>…)`; `DIRECTORY` — с 3.28
   (`--help-command set_tests_properties`). `LABELS` — то, по чему CI фильтрует (`ctest -L smoke`).

**Дырявый пример (часть 2 цикла).** В фрагменте (1)–(9) вырезано по одной строке; предскажи вывод **до**
проверки — иначе это не извлечение знания, а угадывание:

| Вырезано | Предсказание | Чем проверить |
|---|---|---|
| `include(CTest)` (тесты добавляются, `enable_testing()` никто не звал) | конфигурация зелёная, `ctest` → `No tests were found!!!` и код **0** (замер 24.11.2026) | `ctest --test-dir build/win-ninja-debug; $LASTEXITCODE` |
| `LABELS "smoke"` | запуск без фильтра проходит, `-L smoke` не находит ничего: шаг CI с фильтром становится зелёным без тестов | `ctest -L smoke -N` |
| всё условие (2), `add_subdirectory(tests)` без гейта | при `-DBUILD_TESTING=OFF` от родителя тесты всё равно собираются — наш граф не уважает чужой | `cmake --preset win-ninja-debug -DBUILD_TESTING=OFF` → `Get-ChildItem build/win-ninja-debug/tests` |

**2. Почему именно так.** Карта видов теста модуля 1 совпадает с рубильником модуля 8: вид появляется
вместе со слоем приложения, который он проверяет, поэтому пустая строка «здесь» — не дыра, а граница.

| Вид | Что проверяет | Здесь | Полноценно |
|---|---|---|---|
| unit | функцию домена на фиктивных часах | `core/mode/smoke` на строительном `Mode` | 8.1–8.3 |
| contract | что публичный API `tw::core` виден без `add_subdirectory` | заготовка `install(EXPORT)` из цикла 3 | 11.3 (consumer-тест) |
| integration | сценарий светофора целиком | — | 6.x |
| golden / snapshot | вывод QML | — | 5.x |
| static | clang-tidy, UBSan | `CMAKE_EXPORT_COMPILE_COMMANDS` в `base` (цикл 2, тонкость 3) | 10.2 |

**3. Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| шаг CI смотрит только на код возврата | упавший тест виден, а **отсутствие** тестов — нет: у `ctest` код 0 значит и «всё прошло», и «тестов не нашли» (замер) | `-N` перед запуском, `--output-on-failure` |
| `set_tests_properties` в корне, `add_test` в `tests/` | «не найдено» или молчаливое отсутствие свойства: свойства задаются в каталоге создания теста (исключение — `DIRECTORY`, 3.28) | цикл 5 (9) |
| нет `TIMEOUT` | висячий тест держит пайплайн до внешнего лимита, диагноз теряется | `TIMEOUT 30` или `ctest --timeout` |
| один `add_test` на весь `tw_tests` | нет лейблов по отдельным кейсам, `--repeat until-fail:N` перезапускает всё подряд | `*_discover_tests` — модуль 8 |
| `include(CTest)` переезжает в `function()` в `cmake/` | нарушение границы из документации (`enable_testing` «must be called in file scope, not in a `function()` call nor inside a `block()`»): тесты не появляются либо конфигурация падает — текст диагностики читай целиком, это твой замер | цикл 5 (3): `include(CTest)` в file scope корня |

**Ловушка.** Пустой фильтр — зелёный. Замер 24.11.2026: `ctest -L nosuchlabel` печатает
`No tests were found!!!` и возвращает **0**. Три дешёвые защиты: `ctest -N` (число тестов в логе),
`filter.include.label` + `output.shortProgress` в `testPresets` (тогда имя фильтра живёт в репозитории, а
не в пайплайне), и JUnit-отчёт. Последнее — с оговоркой: поле `outputJUnitFile` появилось только в версии
формата **6** (`cmake --help-manual cmake-presets`: «The outputJUnitFile field was added to the `output`
object»; `6` → CMake 3.25), поэтому в нашей `version: 3` файл пишется флагом CLI —
`ctest --output-junit build/Testing/junit.xml`, а не пресетом. Проверка: `Test-Path build/Testing/junit.xml` → `True`.

**4. Мини-практика и чекпойнт (3 минуты).**

```powershell
ctest --preset win-ninja-debug; $LASTEXITCODE
ctest -N
ctest -L smoke -N; $LASTEXITCODE
```

→ первая: один `Passed`, код 0; вторая и третья печатают список без запуска (`-N` = `--show-only`). Полный
вывод первой команды — твой замер: перенеси его в инвентарь урока, на 25.11.2026 запускать ещё нечего. Если
`ctest --preset` отвечает `Could not read presets` — `testPresets` названы иначе, чем configure-пресет
(цикл 2, пункт 8).

**Эталон цикла:** [nlohmann/json `:54,236–241`](https://github.com/nlohmann/json/blob/develop/CMakeLists.txt)
(`JSON_BuildTests` + `BUILD_TESTING`), [Catch2](https://github.com/catchorg/Catch2/blob/devel/CMakeLists.txt)
(`include(CTest)` под `CATCH_DEVELOPMENT_BUILD`; гейт с `NOT_SUBPROJECT` + `find_package(Python3 REQUIRED …)`),
[googletest `:13–16`](https://github.com/google/googletest/blob/main/CMakeLists.txt) (`gtest_force_shared_crt` как `mark_as_advanced`).

## Блок 6. Задание: граф, точка входа, один зелёный тест

Один проект: четырёхстрочный [`CMakeLists.txt`](../../CMakeLists.txt) превращается в граф из трёх таргетов с пресетом,
установочным скелетом и тестом. Из 10 пунктов DoD семеро правят артефакты (`core/`, `app/`, `tests/`, `cmake/`), трое — индекс/ADR/ответы.

### Definition of Done

- [ ] **D1 (граф).** `cmake --preset win-ninja-debug` конфигурирует без правки окружения руками; в
  `build/graph/deps.dot` есть рёбра `tw_app → tw_core` и `tw_tests → tw_core`, обратных нет.
- [ ] **D2 (сборка).** `cmake --build --preset win-ninja-debug` создаёт `tw_app.exe`, запуск возвращает 0.
- [ ] **D3 (тест).** `ctest --preset win-ninja-debug` → один `Passed`, `Total Tests: 1`, код 0; полный вывод —
  в инвентарь урока как твой замер (на 25.11.2026 запускать было нечего).
- [ ] **D4 (layout).** Дерево = ADR-0004: `core/include/trafficwatcher/core/`, `core/src/`, `app/src/`,
  `cmake/`, `tests/`, `ui/`, `packaging/`; `git grep -n "file(GLOB"` → пусто.
- [ ] **D5 (предупреждения).** `cmake/TwWarnings.cmake` в индексе (`git check-ignore -v` → код 1), функция
  вызвана для `tw_core`, `tw_app` и `tw_tests`.
- [ ] **D6 (пакет).** `CPACK_PACKAGE_VERSION` = `${PROJECT_VERSION}`, второго источника номера нет;
  source-архив содержит `cmake/TwWarnings.cmake` и не содержит `build/`.
- [ ] **D7 (установка).** В `core/CMakeLists.txt` под `if(TW_INSTALL)` лежит
  `install(TARGETS tw_core EXPORT twTargets …)` с тремя `DESTINATION`; конфигурация с `-DTW_INSTALL=OFF`
  проходит так же зеленой — гейт работает.
- [ ] **D8 (пресеты).** `cmake --list-presets`, `=build`, `=test` печатают один и тот же набор имён,
  `base`/`win`/`debug` в списках не видны.
- [ ] **D9 (git).** ≥3 коммита с разными причинами + annotated tag `m01-done`;
  `git describe --tags --abbrev=0` печатает тег.
- [ ] **D10 (документация).** Черновики ADR-0002/0003/0004/0020 заведены владельцем; `answers/01` заполнен.

### Прямые шаги

Порядок: сначала файлы, где ошибаться негде, кроме синтаксиса, потом граф, потом пресеты, потом тест и упаковка.

**Шаг 1 — заголовок домена: `core/include/trafficwatcher/core/Mode.hpp` (D4).** В файле должно быть:
`enum class Mode` с ≥3 значениями; объявление одной non-inline функции, чья сигнатура использует `Mode`;
один вариант include-guard на весь проект (вопрос ADR-0003); ни одного Qt-заголовка — `core/` живёт до
модуля 2.
Проверка: `Select-String core/include/trafficwatcher/core/Mode.hpp -Pattern "enum class"` → одна строка.

**Шаг 2 — реализация: `core/src/Mode.cpp` (D1).** В файле должно быть: определение функции из шага 1 (не
`inline`, иначе таргету нечего компилировать); `switch` по всем значениям `Mode` — иначе проверка шага 7
пустая; только стандартная библиотека.
Проверка: `(Get-Content core/src/Mode.cpp | Select-String "Mode::").Count` -gt 0.

**Шаг 3 — точка входа: `app/src/main.cpp` (D2).** В файле должно быть: `#include <trafficwatcher/core/Mode.hpp>`
**углом через `include/`**, а не относительный путь внутрь `core/`; вызов функции шага 1; код возврата из
результата. Проверка: `Select-String app/src/main.cpp -Pattern "trafficwatcher/core"` → строка есть.

**Шаг 4 — объявление таргета: `core/CMakeLists.txt` (D1, D7).** В файле должно быть:
`add_library(tw_core STATIC src/Mode.cpp)` со **явным** списком; `add_library(tw::core ALIAS tw_core)`
следующей строкой; `target_compile_features(tw_core PUBLIC cxx_std_20)`; `target_include_directories` парой
`$<BUILD_INTERFACE:…>` / `$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>`; `install(TARGETS … EXPORT
twTargets …)` внутри `if(TW_INSTALL)` с `RUNTIME`/`LIBRARY`/`ARCHIVE`.
Проверка: `cmake --help-command install` → форма `install(TARGETS <target>… [EXPORT <export-name>] …)`;
`cmake -S . -B build/graph -G Ninja -DCMAKE_BUILD_TYPE=Debug; cmake --build build/graph --target tw_core` → успех.

**Шаг 5 — родитель: `CMakeLists.txt` (D1, D8).** В файле должно быть:
`cmake_minimum_required(VERSION 3.28...4.3)`; `project(TrafficWatcher VERSION 0.1.0 LANGUAGES CXX)`;
`include(GNUInstallDirs)`; `list(APPEND CMAKE_MODULE_PATH …)`; два `option(… ${PROJECT_IS_TOP_LEVEL})`;
`add_subdirectory(core)`, `add_subdirectory(app)`, тесты — под условием цикла 5; **ни одного** флага
компилятора и ни одного `include_directories()`.
Проверка: `Select-String CMakeLists.txt -Pattern "include_directories|target_compile_options"` → пусто;
`cmake -S . -B build/graph --graphviz=build/graph/deps.dot` → рёбра D1.

**Шаг 6 — точка входа: `CMakePresets.json` (D8, D2).** В файле должно быть: `version: 3`; hidden-слои
`base`/`win`/`debug`; `win-ninja-debug`, `win-vs`, `win-ninja-release`; `binaryDir` и `installDir` через
`${presetName}`; `cacheVariables` с `CMAKE_BUILD_TYPE`, `TW_BUILD_TESTS`,
`CMAKE_EXPORT_COMPILE_COMMANDS`; `buildPresets` и `testPresets` с **теми же именами**; ни одного абсолютного
пути машины (только `$env{}`).
Проверка: `cmake --list-presets; cmake --list-presets=build; cmake --list-presets=test` → один набор имён.

**Шаг 7 — функции проекта: `cmake/TwWarnings.cmake` (D5).** В файле должно быть:
`function(tw_add_warning_flags)` c `ARGUMENTS`/`ARGV`; внутри — `target_compile_options(<target> PRIVATE …)`
и ветка по `MSVC`; никаких глобальных `add_compile_options()`; вызов функции из `core/`, `app/`, `tests/`.
Проверка: `git check-ignore -v cmake/TwWarnings.cmake; $LASTEXITCODE` → пустой вывод, код **1**.

**Шаг 8 — тест: `tests/CMakeLists.txt` и `tests/src/Mode_test.cpp` (D3).** В `Mode_test.cpp` должно быть:
проверка предсказания функции шага 1; `return 1` при несоответствии и `return 0` при успехе; фреймворк не
нужен (появится в модуле 8). В `tests/CMakeLists.txt`: `add_executable(tw_tests …)`,
`target_link_libraries(tw_tests PRIVATE tw::core)`, `add_test(NAME core/mode/smoke COMMAND tw_tests …)`,
`set_tests_properties(… PROPERTIES LABELS "smoke" TIMEOUT 30)`.
Проверка: `ctest --preset win-ninja-debug; $LASTEXITCODE` → `0` и один `Passed`; `ctest -L smoke -N` → список
не пуст; `ctest -L nosuchlabel` → **тоже** код 0, и в отчёте урока ты пишешь, почему этот шаг красный.

**Шаг 9 — упаковка: `cmake/TwPackaging.cmake` (D6).** В файле должно быть:
`if(NOT PROJECT_IS_TOP_LEVEL) return() endif()` первой строкой; чтение `.gitignore` и transform (5) с
обязательной допиской `"/build($|/)"` (6); `CPACK_PACKAGE_*`, `CPACK_GENERATOR`, `CPACK_SOURCE_GENERATOR`,
`CPACK_SOURCE_IGNORE_FILES`; `include(InstallRequiredSystemLibraries)`; `include(CPack)`; в корне — одна
`include(TwPackaging)` под `if(TW_INSTALL)`.
Проверка: `cpack --config build/win-ninja-debug/CPackSourceConfig.cmake` → архив; в списке его содержимого
есть `cmake/TwWarnings.cmake`, нет ни одного пути под `build/`.

**Шаг 10 — индекс, коммиты, тег (D9, D10).** Разделить правки на ≥3 коммита по причине — граф; точка входа;
тест и поставка; в `answers/01-*.md` заполнить все слоты; завести черновики ADR (файлы создаёт владелец).
Проверка: `git log --oneline -8`; `git tag -a m01-done -m "…"`, затем
`git describe --tags --abbrev=0` → имя тега (до тега — код 128, цикл 4).

### Чего не делаем

* Qt, `qt_add_qml_module`, `FetchContent`, `find_package(Qt6)` — модули 2 и 9; `ui/` только зарезервирован (ADR-0004).
* consumer-тест установленного пакета — 11.3; заготовка `install(EXPORT)` обязана лишь не ломать конфигурацию.
* компоненты CPack, NSIS/WIX, `package`/`workflow`-пресеты (схема ≥6), CI-файлы, матрицы — модули 11–12;
  `matrixPresets` не существует в CMake 4.3.2 (ловушка цикла 2).
* `catch_discover_tests`/`gtest_discover_tests`, `outputJUnitFile` (схема ≥6) — модули 8 и 12.

## Блок 7. Приёмка

### Рубрика DoD

| Пункт | Зачтено | С оговоркой | Не зачтено |
|---|---|---|---|
| D1 | `deps.dot` содержит оба ребра, обратных нет | ребро есть только `tw_app → tw_core` | граф не построена, `--graphviz` не запускался |
| D2 | `tw_app.exe` собран из пресета и возвращает 0 | собран прямой `cmake --build build/graph`, пресет не использовался | собирается только из IDE |
| D3 | один `Passed`, код 0, вывод в инвентаре | тест запускается `ctest -R`, а не `--preset` | `No tests were found!!!` принято за успех |
| D4 | дерево = ADR-0004, `file(GLOB` нет | `ui/` и `packaging/` не созданы (резерв — это допустимо) | заголовки вне `include/trafficwatcher/` |
| D5 | функция вызвана для трёх таргетов | вызвана для двух | предупреждения заданы глобально в корне |
| D6 | source-архив без `build/`, с `cmake/` | `build/` исключён, `cmake/` в архиве нет | версия CPack задана вторым источником |
| D7 | `install()` под гейтом, три `DESTINATION` | гейта нет, но `install()` не ломает чужой граф | `install()` отсутствует |
| D8 | три списка пресетов с одним набором имён | имена `build`/`test` отличаются суффиксом | пресетов нет, конфигурируется флагами |
| D9 | ≥3 коммита по причине + `m01-done` | 2 коммита, тег есть | один коммит «всё сразу» |
| D10 | ADR-черновики заведены, `answers/01` заполнен | ADR отложены на закрытие модуля | ответы не заполнены |

### Self-check

**1.** Чем `INTERFACE` в `target_include_directories` отличается от `PRIVATE` для `STATIC`-таргета `tw_core`?
<details><summary>Ответ</summary>`PRIVATE` — только при сборке `tw_core`, `INTERFACE` — только потребителю.
Для `STATIC` include-требование имеет смысл только как `INTERFACE`/`PUBLIC`: `tw_app` без этого пути не соберётся.</details>

**2.** Почему `ctest -L nosuchlabel` возвращает 0, и что из этого следует для шага CI?
<details><summary>Ответ</summary>«Тестов не найдено» — пустой отбор, не ошибка (замер 24.11.2026); код возврата
не доказывает наличие тестов — нужен `ctest -N` или `--output-junit` с проверкой числа кейсов.</details>

**3.** Что произойдёт с `cpack` без `-G`, если в `CMakeLists.txt` написать `set(CPACK_GENERATOR ZIP;TGZ;WIX)`?
<details><summary>Ответ</summary>Три пакета за один прогон: в `CMakeLists.txt` это **список**, и `cpack`
итерируется по нему («In a `CMakeLists.txt` file, `CPACK_GENERATOR` is a list of generators»,
`cmake --help-module CPack`). Отсюда правило: в репозитории — один генератор, остальное выбирается флагом.</details>

### Exit ticket

Две строки: (а) самое непонятное в уроке; (б) что именно ты проверишь в первом уроке модуля 2 — без (б) следующий
урок пишется вслепую.

**Что назвать в отчёте о закрытии** ([`methodology.md`](../methodology.md) §4): конструкцию из урока 00, которая
здесь изменила поведение — например, `CMakeCache.txt` перестал быть точкой выбора каталога и стал следствием `binaryDir`.

## Блок 8. Справка и «дальше»

### Сводка урока: конструкции

| Конструкция | Полная форма (категория) | Ключевые аргументы | Где применима | Где неприменима | Best practice + следствие | Тонкость | Чем проверить |
|---|---|---|---|---|---|---|---|
| `cmake_minimum_required` | команда: `cmake_minimum_required(VERSION <min>[...<policy_max>] [FATAL_ERROR])` | `...` — литерал; до 3.12 лишнее игнорируется | первой строкой корня | как выбор компилятора — это `toolchainFile`/ADR-0001 | диапазон, а не версия машины; иначе `policy_max` не на что проверить | поколение политик (`CMP0079`) включается здесь | `cmake --help-command cmake_minimum_required` |
| `add_library(… ALIAS …)` | команда: `add_library(<name> ALIAS <target>)`, 3.11/3.18 для imported | `<name>` с `::`, `<target>` — не alias | рядом с каждым публичным таргетом | alias **нельзя** править (`set_target_properties`) и нельзя `install()`/`export()` | alias рядом с определением, иначе `tw::core` исчезает из чужого графа без сообщения | импортируемый таргет глобален только с 3.11 | `cmake --help-command add_library` |
| `target_compile_features` | команда: `target_compile_features(<target> {INTERFACE\|PUBLIC\|PRIVATE} <feature>… …)` | `cxx_std_20` и другие *features* | `tw_core`, `tw_app`, `tw_tests` | вместо `CMAKE_CXX_STANDARD` «наверху»: свойство каталога не доедет до consumer | `PUBLIC cxx_std_20`; иначе `tw_app` собирается с дефолтом компилятора | это требование, а не флаг: генератор подбирает `/std:c++20` сам | `cmake --help-command target_compile_features`, список — `cmake --help-property COMPILE_FEATURES` |
| `target_include_directories` | команда: `target_include_directories(<target> [SYSTEM] [AFTER\|BEFORE] {INTERFACE\|PUBLIC\|PRIVATE} <dir>… …)` | пара `BUILD_INTERFACE`/`INSTALL_INTERFACE` | у каждого таргета со своими заголовками | `include_directories()` в каталоге: требование не попадает в `twTargets.cmake` | абсолют в `BUILD_INTERFACE`, относительный в `INSTALL_INTERFACE`; иначе 11.3 ставит пакет без заголовков | путь, начинающийся с генераторного выражения, не конвертируется в абсолютный | `cmake --help-command target_include_directories` |
| `PROJECT_IS_TOP_LEVEL` | переменная, `.. versionadded:: 3.21` | `if(PROJECT_IS_TOP_LEVEL)`, значение по умолчанию `option()` | гейты тестов, установки, упаковки | внутри `add_subdirectory`-детей одного проекта: там она `OFF` у всех, кто не корень | `option(X … ${PROJECT_IS_TOP_LEVEL})`; иначе чужой `FetchContent` собирает твои тесты | эталон оборачивает её в `FMT_MASTER_PROJECT` + `NOT DEFINED` fallback | `cmake --help-variable PROJECT_IS_TOP_LEVEL` |
| `install(TARGETS …)` | команда: `install(TARGETS <target>… [EXPORT <export-name>] [RUNTIME\|LIBRARY\|ARCHIVE DESTINATION <dir>] …)` | `EXPORT`, три `DESTINATION`, `OPTIONAL`, `EXCLUDE_FROM_ALL` | рядом с `add_library`, под top-level гейтом | `install(TARGETS tw::core)` — alias установить нельзя | три `DESTINATION` из `GNUInstallDirs`; иначе DLL не попадает в пакет | `install()` без `EXPORT` — это не устанавливаемый CMake-пакет | `cmake --help-command install` |
| `include(CTest)` → `BUILD_TESTING` | модуль; `BUILD_TESTING` — опция-переменная | `-DBUILD_TESTING=OFF` от родителя | один раз в корне, в file scope | внутри `function()`/`block()` — «must be called in file scope» (граница из `enable_testing`) | `include(CTest)` вместо голого `enable_testing()`; иначе у модуля 8 нет рубильника | `CTest` вызывает `enable_testing()` сам, пока `BUILD_TESTING` не `OFF` | `cmake --help-module CTest`, `cmake --help-command enable_testing` |
| `add_test` | команда: `add_test(NAME <name> COMMAND <command> [<arg>…] [CONFIGURATIONS <config>…] [WORKING_DIRECTORY <dir>] [COMMAND_EXPAND_LISTS])` | `NAME`-форма | `tests/CMakeLists.txt` | старая форма `add_test(<name> <cmd> …)`: ни имён таргетов, ни генераторных выражений | `NAME` + `COMMAND tw_tests`; иначе `$<TARGET_FILE:…>` уедет в отбор literal | тест создаётся там же, где и `enable_testing()`-область | `cmake --help-command add_test` |
| `set_tests_properties` | команда: `set_tests_properties(<tests>… [DIRECTORY <dir>] PROPERTIES <prop> <value>…)` | `LABELS`, `TIMEOUT`, `WILL_FAIL`, `PASS_REGULAR_EXPRESSION` | сразу после `add_test` | из другого каталога без `DIRECTORY` (это 3.28+) | `LABELS "smoke"` + `TIMEOUT`: иначе `-L` и `--repeat` бесполезны | свойства задаются в каталоге создания теста | `ctest --help-property-list` |
| `CPACK_SOURCE_IGNORE_FILES` | key CPack (переменная, список regex) | формируется из `.gitignore` | `cmake/TwPackaging.cmake` под top-level гейтом | как замена `install()`-правил: бинарный пакет берёт только их | паттерн на `build/` обязан отсекать содержимое, а не только имя | source- и binary-дорожки у CPack разные | `cmake --help-module CPack` |
| ключи пресетов (`version`, `inherits`, `condition`, `binaryDir`, `$env{}`) | key `CMakePresets.json`; `condition`/`installDir`/`toolchainFile` — схема 3 | порядок `inherits`: ранний побеждает | `CMakePresets.json`, машинное — в `CMakeUserPresets.json` | `matrixPresets` — нет в реализации (замер: 0 упоминаний в руководстве) | одинаковые имена в configure/build/test; иначе `ctest --preset` падает в CI | `packagePresets`/`workflowPresets`/`outputJUnitFile` — схема ≥6 | `cmake --help-manual cmake-presets`, `cmake --list-presets[=<type>]` |

### Глоссарий урока

| Термин | Дальше идёт без перевода |
|---|---|
| usage requirements | требования таргета, которые едут потребителю через `PUBLIC`/`INTERFACE` |
| namespaced alias | имя `ns::target`, под которым таргет виден снаружи |
| `BUILD_INTERFACE` / `INSTALL_INTERFACE` | две формы одного требования: сборка из исходников и установленный пакет |
| поколение политик | набор `CMP…`, который включает `cmake_minimum_required` |
| top-level / sub-project | `PROJECT_IS_TOP_LEVEL`; всё, что включено через `add_subdirectory`/`FetchContent` |
| schema версии пресетов | номер `version` в `CMakePresets.json`, привязанный к CMake (`2`→3.20 … `11`→4.3) |

### Диагностика: симптом → настоящая причина → где чинить

| Симптом | Настоящая причина | Где чинить |
|---|---|---|
| `CMake was unable to find a build program corresponding to "Ninja"` | тулчейн не выбран, а не «нет ninja» | ADR-0001; урок 00, блокеры B1–B2 |
| `CMAKE_CXX_COMPILER not set, after EnableLanguage` | компилятор виден в одной оболочке и не виден в другой | `toolchainFile`/`cacheVariables` пресета, цикл 2 |
| `Could not read presets from <каталог>: File not found` | файла `CMakePresets.json` нет (или он в игноре) | цикл 2, шаг 6 |
| `Unrecognized "version" 99: must be >=1 and <=11` (замер) | схема выше поддерживаемой | зафиксировать схему в ADR-0001 |
| `Does not match the generator used previously: …` (замер) | два входа в один `binaryDir` | `${presetName}` в `binaryDir` |
| `Target "…" links to … but the target was not found` (фрагменты из `cmake.exe`, замер) | нет `ALIAS`, или опечатка в `ns::name` | цикл 1 (7) |
| `No tests were found!!!` + код 0 (замер) | `enable_testing()` не вызван в этой области, либо фильтр пуст | цикл 5, ловушка |
| cpack делает два пакета вместо одного | `CPACK_GENERATOR` — список | тонкость 6, фиксировать `-G` |

### Подмеченные ошибки в текущем состоянии репозитория

* [`CMakeLists.txt:3`](../../CMakeLists.txt#L3) — `VERSION 4.3.2` пинит версию машины; cmake из бандла
  CLion (4.2.2, урок 00) такой файл не читает, и сборка из IDE падает на первой строке.
* [`CMakeLists.txt:4`](../../CMakeLists.txt#L4) — `project()` без `VERSION`: `PROJECT_VERSION` пуст, а CPack
  при недостающих компонентах подставляет `0.1.1` (текст — в `cmake --help-module CPack`). Шаг 5 закрывает это.
* [`CMakeLists.txt:1–2`](../../CMakeLists.txt#L1) — комментарии «version 4.5.0 latest btw»; на этой машине
  `cmake --version` → 4.3.2 (замер 25.11.2026). Версия — факт окружения и живёт в ADR-0001, а не в комментарии.
* `git status --porcelain` (замер 25.11.2026): `D ` у `docs/answers/01-cmake-target-model*.md`, `08`, `15` —
  удаления **в индексе**, и ` D` у четырёх старых `docs/lessons/*.md` — удаления **только в рабочем дереве**.
  При `git checkout -- .` первые вернутся, вторые нет; судьба старых уроков — решение владельца.
* [`.gitignore:4`](../../.gitignore#L4) `build/` и [`:28`](../../.gitignore#L28) `Testing/` — правила, из
  которых в цикле 4 делается спецификация поставки; `Testing/` проверь после первого `ctest`:
  `Get-ChildItem build/win-ninja-debug/Testing -Recurse`.
* `cmake-build-debug/` на диске есть, в git его нет ([`:3`](../../.gitignore#L3)) — урок 00 нашёл там чужой
  WSL-кэш; пресет с `${presetName}` делает такой кэш невозможным.

### Инвентарь окружения (замер 24–25.11.2026)

* `cmake --version` → 4.3.2 (`C:\Program Files\CMake\bin\cmake.exe`); бандл CLion — 4.2.2.
* Пресеты: максимум схемы **11**; неизвестное поле обрушивает чтение файла; `ctest` без тестов → код **0**,
  с падением → **8**; `git describe --tags` → **128**; `git check-ignore -v cmake/TwWarnings.cmake` → **1**.
* `cpack --help` → `-G`, `-C`, `-D`, `--config`, `--preset`, `--list-presets`, `-P`, `-R`, `-B`, `--vendor`.
* `ctest --help` → `--preset`, `--test-dir`, `-N/--show-only[=format]`, `-L/-R/-E`, `-I` (stride),
  `--output-on-failure`, `--output-junit`, `--rerun-failed`, `--repeat`, `--timeout`, `--build-and-test`.
* `cmake --help-manual cmake-presets`: упоминаний `matrix` — **0**; `outputJUnitFile` — схема **6**.
* `cmake --help-variable CMAKE_EXPORT_COMPILE_COMMANDS`: «ignored on other generators» (не Makefile/Ninja).
* Файлы upstream изучались 25.11.2026 в ветках `master`/`devel`/`v1.x`; номера строк смещаются.

### Что читать

1. **Разбор чужого кода (обязательный пункт).** [fmt `CMakeLists.txt`](https://github.com/fmtlib/fmt/blob/master/CMakeLists.txt) —
   строки 251–256 (`ALIAS` + interface), 533–560 (`CMakePackageConfigHelpers`), 653–672 (source-пакет из `.gitignore`).
   Вопрос: почему рядом с `install(EXPORT …)` лежит `export(EXPORT …)` в build-дереве, и что он чинит для `FetchContent`?
2. [Catch2 `CMakeLists.txt`](https://github.com/catchorg/Catch2/blob/devel/CMakeLists.txt) — `NOT_SUBPROJECT`,
   десять `cmake_dependent_option(… "CATCH_DEVELOPMENT_BUILD" OFF)`, `set(CMAKE_MODULE_PATH … PARENT_SCOPE)`.
   Вопрос: почему `PARENT_SCOPE` — только когда `NOT NOT_SUBPROJECT`?
3. [vcpkg-tool `CMakePresets.json`](https://github.com/microsoft/vcpkg-tool/blob/main/CMakePresets.json) —
   слои, имена в build/test; [qt-creator `CMakePresets.json`](https://github.com/qt-creator/qt-creator/blob/master/CMakePresets.json) — `description` как документация того, что молча сломается без env-переменной.
4. Руководства на своей машине: `cmake --help-manual cmake-presets`, `cmake --help-module CPack`,
   `cmake --help-module CTest`, `ctest --help-property-list`.
5. Уроки курса: [00](00-territory-and-toolchain.md) (тулчейн и коды возврата), 8.1 (карта тестов),
   11.3 (consumer-тест установленного пакета).

### Итог урока

* **ADR:** 0001 подтверждается сборкой из пресета; порождает — **0002** (имя/namespace/include-путь/URI),
  **0003** (политика предупреждений и include-guard), **0004** (layout), **0020** (ветвление и тег модуля).
  Черновики создаёт владелец; ассистент проверяет форму по [`template.md`](../adr/template.md).
* **Файлы:** `CMakeLists.txt`, `CMakePresets.json`, `core/{CMakeLists.txt,src/Mode.cpp,include/trafficwatcher/core/Mode.hpp}`,
  `app/{CMakeLists.txt,src/main.cpp}`, `tests/{CMakeLists.txt,src/Mode_test.cpp}`,
  `cmake/{TwWarnings.cmake,TwPackaging.cmake}`, `build/graph/deps.dot`, тег `m01-done`.
* **Состояние, с которым открывается следующий урок:** два таргета собираются одной командой пресета, один
  тест под лейблом `smoke` проходит, `BUILD_TESTING` — общий рубильник модуля 8, `ui/` зарезервирован под
  `qt_add_qml_module`, `install(EXPORT)`-скелет ждёт consumer-теста 11.3.
* **Следующий урок:** [02 «Qt 6 в CMake»](02-qt6-in-cmake.md) — Qt 6 как зависимость графа (модуль 2, веха M1).
* **Выброшено из урока намеренно:** `matrixPresets` (нет в CMake 4.3.2), «урок про CMake вообще» — все
  проверки привязаны к `tw_core`/`tw_app`/`tw_tests`.
