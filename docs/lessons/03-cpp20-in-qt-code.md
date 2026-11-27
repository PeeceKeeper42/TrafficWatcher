# Урок 03 — C++20 в Qt-коде: флаг, feature-макрос и решение ADR-0005

## Блок 1. Карточка

| Поле | Значение |
|---|---|
| Модуль / урок | **Модуль 3**, строки плана `3.1`–`3.4` ([`docs/course.md`:137–148](../course.md#L137)). Обозначение `3.M` = строка плана; физически это цикл `M` этого файла. Цикл 1 делит строку `3.1` пополам: флаг и макросы — здесь, compile-time данные — в цикле 2 |
| Веха | **M1** (паритет): [`readme.md`:20](../readme.md#L20) — «повторить функционал на Qt 6.10.2 / **C++20** / QML», и [`readme.md`:166](../readme.md#L166) — «Не поддерживаем Qt5 и C++17» |
| Артефакт на выходе | `Select-String build/win-ninja-debug/compile_commands.json -Pattern "-std=\|/std:"` → одна строка `-std=c++20` (не `gnu++20`, не `17`) для всех TU `tw_core` + `tw_app`; дальше `ctest --preset win-ninja-debug -L unit` зелёный, а в `docs/adr/` — черновик **ADR-0005** |
| На входе (prerequisites) | **ожидаемое**: уроки [01](01-cmake-target-graph.md) и [02](02-qt6-in-cmake.md) не закрыты (замер 26.11.2026: `git tag` пуст, `git ls-files` даёт только `docs/`, `AGENTS.md`, `CMakeLists.txt`, `.gitignore`). Нужно: `tw_core` (+ `ALIAS tw::core`) со `target_compile_features(tw_core PUBLIC cxx_std_20)` и строительным `core/include/trafficwatcher/core/Mode.hpp`, `tw_app`, пресет `win-ninja-debug`, один зелёный `smoke`-тест; для циклов 3–5 — `tw_ui` с `LightBulb` из урока 02 и найденный `Qt6::Core` |
| Порождаемые ADR | **0005** — «Какие фичи C++20 считаем разрешёнными в общем коде (и что нельзя)» ([`adr/readme.md`:21](../adr/readme.md#L21), очередь, веха M1). Подтверждает 0001 (кит и компилятор) и 0003 (флаги предупреждений) |
| Эталон урока | установленный Qt 6.10.2 (`qcompilerdetection.h`, `<QtTypeTraits>`, `qspan.h`, `qmetaobject.h` — номера строк замерены здесь), страница «C++20 Overview» Qt 6.10, `.clang-tidy` Qt Creator — свод правил в преамбуле блока 5, ссылки в блоке 8 |
| Вопросы и следующий урок | [`docs/answers/03-cpp20-in-qt-code.md`](../answers/03-cpp20-in-qt-code.md); дальше — модуль 4 «QML «как надо»» ([`course.md`:150](../course.md#L150)) |

## Блок 2. Цели и доказательства

После урока ты умеешь:

| Цель | Где отрабатывается | Чем доказывается |
|---|---|---|
| **Найти по `compile_commands.json`, в каком режиме реально собрана каждая TU, и объяснить, чем `cxx_std_20` отличается от «все фичи C++20 есть»** | цикл 1, разбор (1)–(8) | команда артефакта из карточки → `-std=c++20`; `Select-String build/win-ninja-debug/compile_commands.json -Pattern "gnu\+\+"` → пусто |
| **Выбрать гейт по признаку «компилятор врёт или нет»**: `__cplusplus` vs `__cpp_*` vs `_GLIBCXX_RELEASE` vs версия компилятора — и назвать, чем проверять каждый | цикл 1 (3)–(5), цикл 2 (7) | `g++ -dM -E` на своём компиляторе со списком макросов; вопрос A2 |
| **Предсказать, упадёт ли конструкция на C++20 или на C++23, по тексту диагностики и по макросу** | цикл 2 (3)–(5), цикл 5 (2)–(4) | тексты ошибок из цикла 2/5 на своей машине; вопрос A3 |
| **Ограничить шаблон концептом так, чтобы отказ компилятора читался как спецификация, а не как стек нот** | цикл 3, разбор (1)–(7) | цепочка `no matching function for call to …` → `constraints not satisfied` → `the expression 'is_enum_v<E> …' evaluated to 'false'` (замер 26.11.2026); вопрос A4 |
| **Отличить view от владельца данных в Qt-коде**: `std::span`/`QSpan`, `QStringView`/`QUtf8StringView`, и назвать цену каждой границы | цикл 4, цикл 5 (5)–(7) | висящий `std::span` собирается с `-Wall -Wextra -Wpedantic` **без диагностики** (замер); отличия `QSpan` названы по строкам заголовка; вопрос A5 |
| **Собрать аргументы для ADR-0005: таблица «фича \| стандарт \| гейт \| цена \| чем проверено»** | все циклы, задание D8 | таблица в черновике ADR-0005; вопрос A6 и B1 |

**Как читать урок.** Первый проход — блоки 1–2 и 7. Дальше циклы строго по порядку: что даёт флаг
(1) → compile-time данные (2) → границы шаблонов (3) → view над таблицей фаз (4) → ошибки, строки и
логи (5). Внутри цикла: **механика → почему именно так → что будет, если нарушить → тонкость →
мини-практика и чекпойнт**, в конце — «Эталон цикла».

Все числа и тексты ошибок — замер 26.11.2026 на этой машине: GCC 13.1.0 из бандла CLion
(`C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin\g++.exe`) и CMake 4.3.2; GCC 8.1.0 из
`C:\Qt\Tools\mingw810_64`; заголовки Qt 6.10.2 — `C:\Qt6.10.2-msvc2022\qt6.10.2-x64-msvc2022\Qt\6.10.2\msvc2022_64\include`
(`qmake -v` → «Using Qt version 6.10.2»). Две границы честности: **MSVC не установлен** (`vswhere.exe`
отсутствует), поэтому всё про `/std:`, `/Zc:__cplusplus` и `_MSVC_LANG` дано цитатой из документации Qt и
помечено «проверь»; и Qt здесь — **MSVC-сборка**, поэтому её заголовки годятся только для `-fsyntax-only`
(замер: `#include <QtCore/QString>` → код 0), а не для линковки: все Qt-пропуски урока — проверки
компиляции, а не запуск бинарника.

### Мини-практика на 5 минут

Две команды из каталога репозитория — «что за инструмент вообще»:

```powershell
cmake --version | Select-Object -First 1
& "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin\g++.exe" --version | Select-Object -First 1
```

→ `cmake version 4.3.2` и `g++.exe (GCC) 13.1.0` (замер; у GCC из `C:\Qt\Tools\mingw810_64` первая строка
другого формата — `g++.exe (x86_64-posix-seh-rev0, Built by MinGW-W64 project) 8.1.0`, и это аргумент
сверять компилятор по выводу, а не по имени папки).

Третья проверка — «умеет ли этот компилятор C++20» — на ней спотыкаются все пробы урока. Рабочая форма
(замер 26.11.2026):

```powershell
Push-Location "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin"
@('int main(){}') -join "`n" | & ".\g++.exe" -fsyntax-only -std=c++20 -x c++ -
"exit=$LASTEXITCODE"        # → 0
Pop-Location
```

Та же команда из `build/` с абсолютным путём к `g++.exe` вернёт **код 1 без единой строки диагностики**;
`-B"<путь к bin>"` не лечит (замер: тоже код 1). Причина не в флагах, а в поиске DLL: `g++` порождает
`cc1plus.exe` из `libexec\gcc\...`, а `libstdc++-6.dll` и `libgcc_s_seh-1.dll` лежат в `bin`, и для
дочернего процесса их не видно — текущий каталог в списке поиска есть, поэтому `Push-Location` в `bin` и
работает. Для **полной** сборки проб (нужен ассемблер и линковка) добавь `-B.`: без него замер даёт
`g++.exe: fatal error: cannot execute 'as': CreateProcess: No such file or directory`. Правильное место для
такого `PATH` — `environment` в пресете (урок 12.1), а не `$env:PATH` в профиле: постоянная правка
окружения ломает воспроизводимость сборки на второй машине. Форма `@('строка1','строка2') -join "`n"`
обязательна: here-string с многострочным телом ломает разбор кавычек, а `cmd /c` в этом курсе не
используется.

## Блок 3. Проблема урока

В репозитории нет ни одной строки кода, которая требовала бы C++20, и ровно поэтому урок начинается не
с «как написать `concept`», а с проверки, что обещание курса выполняется. Пять симптомов:

1. **Стандарт объявлен, но не доказан.** Урок 01 поставил `target_compile_features(tw_core PUBLIC
   cxx_std_20)` ([`lessons/01`:163](01-cmake-target-graph.md#L163)) и объяснил: «это *feature*, а не
   флаг». Флаг при этом мог быть любой: `CXX_EXTENSIONS` — «`ON` by default»
   (`cmake --help-property CXX_EXTENSIONS`, замер), значит GCC по умолчанию получит `-std=gnu++20`.
2. **C++17 живёт в планах как норма.** Старый проект ставил `CMAKE_CXX_STANDARD 17`
   ([`legacy-description.md`:22](../legacy-description.md#L22)); [`readme.md`:166](../readme.md#L166)
   запрещает C++17 как поддерживаемую цель. Между ними — молчание: ни один файл репозитория не говорит,
   что будет, если компилятор не потянет 20.
3. **Расширения компилятора делают «тихую» сборку.** Замер: designated initializers в правильном порядке
   собираются под `-std=c++17` и `-std=gnu++17` с `-Wall -Wextra` **с нулевым числом диагностик** (код 0), и
   `__cpp_designated_initializers` при этом **не определён**; `-Wpedantic` показывает `warning: C++ designated
   initializers only available with '-std=c++20' or '-std=gnu++20' [-Wc++20-extensions]`. Хуже того:
   `[[no_unique_address]]` меняет раскладку **в C++17-режиме без предупреждения вообще** (`A=12` против
   `B=8`; даже `-Wpedantic` молчит).
4. **План модуля обещает то, чего в C++20 нет.** Строка [`3.3`](../course.md#L143) требует
   `std::to_underlying` и `QString::formatted`: первый под C++20 отвергается компилятором
   (`note: 'std::to_underlying' is only available from C++23 onwards`, замер), второго **нет в Qt 6.10.2** —
   в списке членов `QString` его нет (замер `Select-String` по `qstring.h`: есть `asprintf`/`vasprintf`
   (`:367–368`) и вариадический `arg(Args &&...)` (`:354–365`), `formatted` — нет). `std::expected` из
   строки статуса курса — тоже C++23: под `-std=c++20` — `error: 'expected' is not a member of 'std'` (замер).
5. **Домен всё ещё считает режимы целыми.** В старом проекте — `enum Mode{Off,On,Blink}` и
   `Q_PROPERTY(int mode READ getMode WRITE setMode)`
   ([`legacy-description.md`:26, :56](../legacy-description.md#L26)): режим приходит из QML числом, и
   никакая проверка не отделяет `2` от `7`.

К концу урока будет так: в `compile_commands.json` лежит проверяемый флаг, которым ты управляешь явно; в
`Mode.hpp` — типизированный `enum class … : std::uint8_t` с `consteval`-валидатором и compile-time таблицей,
отказ компилятора на нарушении читается как спецификация; view-типы (`std::span`/`QSpan`, `QStringView`)
стоят только там, где владелец данных виден в той же строке; а `ADR-0005` заполнен таблицей
«фича → стандарт → гейт → цена», потому что без неё следующий модуль начнёт писать C++23-код наугад.

## Блок 4. Приложение: вход → выход

| | Состояние |
|---|---|
| **Вход** (ожидаемое — уроки 01–02 не закрыты, блок 1) | собираются `tw_core` (строительный `core/include/trafficwatcher/core/Mode.hpp`, `src/Mode.cpp`) и `tw_app` из пресета `win-ninja-debug`; `target_compile_features(tw_core PUBLIC cxx_std_20)` стоит, но флаг в команде компиляции никем не сверен; один `smoke`-тест под `LABELS smoke` проходит; `ui/` — `tw_ui` с `LightBulb` (`Q_ENUM`/свойство типа `Mode` пока `int`) и `Main.qml` |
| **На выходе** | `core/include/trafficwatcher/core/Mode.hpp` + `PhaseTable.hpp` + `Concepts.hpp` (все три — **строительные**, живут до урока 6.1, где их заменяет `TrafficLightState`/`TickEngine` из [`course.md`:179](../course.md#L179)); `core/CMakeLists.txt` с `CXX_EXTENSIONS OFF` и `CXX_STANDARD_REQUIRED ON`; `tests/` — unit-тесты на каждую новую абстракцию под лейблом `unit` + negative control; в `ui/` — `LightBulb` с `qToUnderlying`/`QMetaEnum::valueToKey` вместо `static_cast<int>`; черновик ADR-0005 |
| **Следующий урок открывается** | с ядром, чей режим сборки доказан одной командой, и с типизированным `Mode`: модуль 4 ([`course.md`:150–157](../course.md#L150)) перекладывает `Main.qml` и просит `required property` — а типизированное свойство (`Mode`, а не `int`) из находки `10` опирается ровно на те enum-ы и концепты, которые появились здесь; модуль 6.1 заменяет строительные заголовки доменом, и его план удаления уже в этом уроке (шаги 1–3 называют их строительными) |

**Строительный код (срок жизни указан).** `Mode.hpp` из урока 01 остаётся строительным: в этом уроке он
**развивается**, а не заменяется. `PhaseTable.hpp` и `Concepts.hpp` — тоже строительные: их удаление или
замена стоят пунктом задания **урока 6.1** ([`course.md`:179](../course.md#L179), «стейт-машина вместо
`if (isRunning)`») — там же, где `Mode.hpp` превращается в `TrafficLightState`. Имена будущего домена
(`TrafficLightState`, `TickEngine`, `IClock`) в тексте встречаются только с этой пометкой.

### Таблица усложнения: конструкции прошлых уроков меняются здесь

| Конструкция | Появилась | Как усложняется здесь |
|---|---|---|
| `target_compile_features(tw_core PUBLIC cxx_std_20)` | урок 01, цикл 1 (8) | требование **не гарантирует фичу**: руководство `cmake-compile-features(7)` — «at minimum aware of that standard, but could be greater … does not guarantee the existence of any particular feature. Diagnosis … delayed until compile time»; дальше управляем `CXX_EXTENSIONS` и `CXX_STANDARD_REQUIRED` и смотрим флаг (цикл 1) |
| `PUBLIC` / `INTERFACE` — направление требования | урок 01, тонкость 1 цикла 1 | тот же механизм везёт **стандарт**: `PUBLIC` кладёт feature в `INTERFACE_COMPILE_FEATURES`, и `tw_app` собирается в том же режиме — проверяется не графом, а строкой компиляции `app/src/main.cpp` (цикл 1, тонкость 1) |
| `CMAKE_EXPORT_COMPILE_COMMANDS` | урок 01, тонкость 3 цикла 2 | тот же файл из «входа для clang-tidy/qmllint» становится **главным свидетелем** урока: одна `Select-String` закрывает D1; на VS-пресете её нет → проверка живёт на Ninja (цикл 1, чекпойнт) |
| `Mode.hpp` (`enum class Mode`) | урок 01, блок 4 (строительный) | появляется явный underlying type, `consteval`-валидатор и designated-init таблица; следствие: значение «2 из QML» перестаёт быть легальным числом (цикл 2, цикл 3) |
| `Q_ENUM` + свойство `Mode` | урок 02, цикл 3; находка `10` ([`legacy-description.md`:56](../legacy-description.md#L56)) | enum перестаёт быть числом в двух местах сразу: концепт на границе шаблона (цикл 3) и `QMetaEnum::valueToKey`/`qToUnderlying` в рефлексии (цикл 5, тонкость 2) |
| `LABELS smoke` / `negative` | уроки 01–02, цикл 5 / цикл 4 | добавляется лейбл `unit` для тестов доменных абстракций (приёмка модуля — «unit-тесты на каждую новую абстракцию», [`course.md`:147](../course.md#L147)); `WILL_FAIL` получает второй смысл — тест на то, что **не должно компилироваться** (цикл 3, тонкость 1) |

## Блок 5. Практикум

Пять циклов по пять частей (`AGENTS.md` §2.1): показ → дырявый пример → самостоятельная проверка →
ловушка/тонкость → чекпойнт. Строить всё — на трёх строительных заголовках (`Mode.hpp`, `PhaseTable.hpp`,
`Concepts.hpp`) и на `LightBulb` из урока 02; срок их жизни — до урока 6.1 (блок 4).

### Свод эталонных правил урока

Шесть правил, каждое — с источником, который можно открыть прямо сейчас. Дальше они именуются «правило 1»…«правило 6».

| № | Правило | Где подтверждено | Что из него следует в коде |
|---|---|---|---|
| **1** | Qt 6 **официально требует C++17**, а не 20: «Qt 6 officially requires C++17, however we are constantly working on supporting new C++ language features» | [cpp20-overview (Qt 6.10.3)](https://doc.qt.io/qt-6.10/cpp20-overview.html); `qcompilerdetection.h:1317–1323` — `#if defined(__cplusplus) && (__cplusplus < 201703L)` → `#error "Qt requires a C++17 compiler…"` (замер по установленному 6.10.2) | наш `cxx_std_20` — **наше** требование, а не требование Qt; обосновывается оно в ADR-0005, а не «потому что Qt же 17» |
| **2** | В **публичном API и ABI** Qt не может использовать C++20-типы: «Qt 6 only requires C++17, meaning it cannot have C++20 types in the API and ABI» — отсюда `QSpan` вместо `std::span` | там же, раздел «QSpan - a Qt version of std::span» | для `tw_core`, который в 11.3 экспортируется `find_package`, тот же тип рассуждения: API публичной библиотеки живёт по самому слабому потребителю |
| **3** | Гейт «фича есть» собирается из **трёх** слоёв, потому что один врёт: `__cplusplus` **+** `_GLIBCXX_RELEASE` **+** версия компилятора | `qcompilerdetection.h:1473–1476`: «libstdc++ shipped with gcc < 11 does not have a fix for defect LWG 3346» → `#if __cplusplus >= 202002L && (!defined(_GLIBCXX_RELEASE) \|\| _GLIBCXX_RELEASE >= 11)`; `:1478–1483`: «P0846 doesn't have a feature macro :/ … claims C++20 support but lacks P0846» (`Q_CC_MSVC >= 1939`) | в ADR-0005 у каждой разрешённой фичи — слой гейта; писать `#if __cplusplus >= 202002L` там, где есть `__cpp_*`, — осознанный выбор, а не привычка |
| **4** | Макросы **языка** предопределены, макросы **библиотеки** появляются только после включения заголовка | замер: пустой TU на `-std=c++23` не даёт ни `_GLIBCXX_RELEASE`, ни `__cpp_lib_expected`; после `#include <version>` → `#define _GLIBCXX_RELEASE 13`, `#define __cpp_lib_expected 202211L` | гейт библиотеки без `#include <version>` выше него молча выключает ветку; проверка — всегда `-dM -E`, а не «компилируется же» |
| **5** | Ограничение шаблона — это документация: **I.9 «If an interface is a template, document its parameters using concepts»** | [CppCoreGuidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines) (заголовок правила проверен 26.11.2026 в тексте страницы) | концепт на границе `tw_core` описывает контракт лучше комментария; но он **не** сокращает диагностику (цикл 3, цифры) |
| **6** | Qt берёт C++20-фичи **по одной и с фасадом**: `Q_CONSTINIT`, `Q_NODISCARD_CTOR`, `Q_NODISCARD_X` | cpp20-overview, раздел «Additional important features»; `qcompilerdetection.h:981/985/988` — `[[nodiscard]]`, `[[nodiscard(message)]]` и резервные определения `:1083–1089` (`Q_REQUIRED_RESULT` — пустое), `:1409–1418` — пять определений `Q_CONSTINIT` | там, где фича может отсутствовать, в курсовом коде — макрос или `static_assert`, а не надежда на компилятор |

### Цикл 1 — флаг: от `cxx_std_20` до `-std=c++20` в `compile_commands.json` (план 3.1; ≤25 минут)

**1. Показ («я делаю»), разбор (1)–(8).** Фрагмент `core/CMakeLists.txt` — иллюстрация, пишешь ты:

```cmake
add_library(tw_core STATIC src/Mode.cpp src/PhaseTable.cpp)          # (1)
target_compile_features(tw_core PUBLIC cxx_std_20)                   # (2)
set_target_properties(tw_core PROPERTIES
    CXX_STANDARD 20                                                  # (3)
    CXX_STANDARD_REQUIRED ON                                         # (4)
    CXX_EXTENSIONS OFF)                                              # (5)
target_include_directories(tw_core PUBLIC include)                   # (6)
```

```powershell
cmake --build --preset win-ninja-debug                              # (7)
Select-String build/win-ninja-debug/compile_commands.json -Pattern "-std=" |
  ForEach-Object { ($_.Line -split '"')[1] -replace '.*(-std=\S+).*','$1' } |
  Select-Object -Unique                                             # (8)
```

1. **Два TU.** Без `.cpp` команде `target_compile_features` нечего менять в команде компиляции, а (8) вернёт пустоту вместо ответа.
2. **`cxx_std_20`** — сигнатура из `cmake --help-command target_compile_features` (замер, CMake 4.3.2): `target_compile_features(<target> {INTERFACE|PUBLIC|PRIVATE} <feature>... …)`. Там же два предложения, из которых весь цикл: «If the feature is not listed in the `CMAKE_CXX_COMPILE_FEATURES` … an error will be reported **by CMake**» (фаза конфигурации) и «If the use of the feature requires an additional compiler flag, such as `-std=gnu++11`, the flag will be added automatically» — обрати внимание на **форму** примера: CMake сам пишет `gnu++`. Keyword обязателен: `PUBLIC` кладёт feature и в `COMPILE_FEATURES`, и в `INTERFACE_COMPILE_FEATURES`.
3. **`CXX_STANDARD 20`** — дублирование сознательное: `cmake-compile-features(7)`, «Requiring Language Standards» — мета-фича требует режим «**at minimum aware of that standard, but could be greater** … does not guarantee the existence of any particular feature. Diagnosis of use of unsupported features will be delayed until compile time». То есть `cxx_std_20` = «не ниже 20», верхняя граница открыта: на GCC 15 тот же проект соберётся в 23-режиме. `CXX_STANDARD` фиксирует **точный** уровень.
4. **`CXX_STANDARD_REQUIRED ON`** — без него требование опционально (`cmake --help-property CXX_STANDARD_REQUIRED`, замер): «If this property is `OFF` or unset, the value of the `CXX_STANDARD` target property is treated as optional and may **"decay" to a previous standard** if the requested is not available». Следствие: сборка на старом тулчейне не падает, а **молча** собирается в C++17 — и `concept` из цикла 3 превращается в `error: 'concept' does not name a type` глубоко в заголовках (буквальный текст GCC 8.1, замер в ловушке).
5. **`CXX_EXTENSIONS OFF`** — страница свойства (замер): «this results in adding a flag such as `-std=gnu++11` instead of `-std=c++11` … This property is **`ON` by default**», поэтому без этой строки (8) напечатает `-std=gnu++20`. Свойство инициализируется значением `CMAKE_CXX_EXTENSIONS` «and otherwise by the value of `CMAKE_CXX_EXTENSIONS_DEFAULT` (see `CMP0128`)» — но `cmake --help-variable CMAKE_CXX_EXTENSIONS_DEFAULT` отвечает `Argument "CMAKE_CXX_EXTENSIONS_DEFAULT" to --help-variable is not a defined variable` (замер): текст свойства ссылается на переменную, которой нет в справке, — проверять надо поведение сборки, а не имя.
6. **`PUBLIC include`** — урок 01; здесь нужен, чтобы `PhaseTable.hpp` доехал до `tw_app` и `tw_ui`, и их TU попали в ту же проверку (8).
7. **Сборка пресетом `win-ninja-debug`** — на генераторе «Ninja» + `CMAKE_EXPORT_COMPILE_COMMANDS=ON` (урок 01, тонкость 3 цикла 2) `compile_commands.json` лежит рядом с `build.ninja`. На `Ninja Multi-Config` и на VS-генераторе его нет — тогда свидетель только `build.ninja`/`vcxproj`, и шаг D1 это различие учитывает.
8. **Извлечение флага из JSON** — `-split '"'` берёт поле `"command"`, `Select-Object -Unique` оставляет **одну** строку: это доказательство, что режим у всех TU один. Две строки = где-то `cxx_std_20` не доехал (обычно `PRIVATE` вместо `PUBLIC`).

**2. Делаем вместе: дырявый пример 1.** Тот же фрагмент с четырьмя пропусками — вставь и предскажи вывод проверки до запуска.

```cmake
add_library(tw_core STATIC src/Mode.cpp src/PhaseTable.cpp)
target_compile_features(tw_core ______ cxx_std_20)      # пропуск A — keyword
set_target_properties(tw_core PROPERTIES
    CXX_STANDARD ______                                  # пропуск B — число
    CXX_STANDARD_REQUIRED ______                         # пропуск C — ON/OFF
    CXX_EXTENSIONS ______)                               # пропуск D — ON/OFF
```

- **A.** `PRIVATE`. Предсказание: `tw_core` соберётся, `tw_app` — в режиме компилятора по умолчанию. Проверка: `Select-String build/win-ninja-debug/compile_commands.json -Pattern "Mode.cpp|main.cpp"` и посмотреть `-std=` в каждой строке → **две** разные (одна — отсутствие флага), при `PUBLIC` — одна. Тот же `INTERFACE_COMPILE_FEATURES`-механизм урока 01, только везёт он теперь стандарт.
- **B.** `17` при сохранённом `cxx_std_20`. Предсказание: конфигурация **не** падает. Проверь `cmake --build --preset win-ninja-debug` и флаг в JSON: пропуск нужен, чтобы увидеть, что два механизма расходятся, а не согласуются сами собой, — ответ фиксирует вывод, а не моё обещание.
- **C.** `OFF`. Предсказание: на тулчейне без C++20 сборка деградирует молча (правило decay). Проверка — на втором компиляторе машины: `Push-Location "C:\Qt\Tools\mingw810_64\bin"` и конфигурация в отдельный build-каталог `build/probe-gcc8` (временная папка внутри репозитория).
- **D.** `ON`. Проверка: `Select-String build/win-ninja-debug/compile_commands.json -Pattern "gnu\+\+"` → **пусто** при `OFF`, непусто при `ON`.

**3. Ты делаешь (4 минуты).** Сними таблицу предопределённых макросов на своём компиляторе (нужен только препроцессор):

```powershell
Push-Location "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin"
foreach ($st in 'c++17','c++20') {
  "" | & ".\g++.exe" -dM -E "-std=$st" -x c++ - |
    Select-String '__cplusplus |__cpp_concepts|__cpp_designated_initializers|__cpp_char8_t|__cpp_impl_three_way_comparison'
}
Pop-Location
```

→ `c++17`: ровно одна строка `#define __cplusplus 201703L`. `c++20`: `__cplusplus 202002L`,
`__cpp_concepts 202002L`, `__cpp_designated_initializers 201707L`, `__cpp_char8_t 202207L`,
`__cpp_impl_three_way_comparison 201907L` (замер). Ни одного `__cpp_*` в c++17-блоке — вот почему гейтят
макросом, а не `__cplusplus` (правила 3–4).

**4. Ловушка и тонкости.**

**Ловушка.** Синтаксис C++20 принимается в режиме C++17 молча. Замер:
`@('struct P{int a;int b;};','int main(){P p{.a=1,.b=2};return p.a+p.b;}')` на `-std=c++17 -Wall -Wextra` →
**код 0, ноль диагностик**; с `-Wpedantic` → два `warning: C++ designated initializers only available with
'-std=c++20' or '-std=gnu++20' [-Wc++20-extensions]` и всё тот же код 0. На GCC 8.1 (`-std=c++2a -Wall
-Wextra -Wpedantic`) та же таблица собирается с кодом 0, **но** `concept` уже нет: `error: 'concept' does not
name a type; did you mean 'constexpr'?` + `note: 'concept' only available with -fconcepts`, и `__cplusplus`
при этом `201709L`. Вывод для ADR-0005: **флаг и `__cplusplus` не описывают тулчейн**; описывают —
предопределённые `__cpp_*` (язык) и `__cpp_lib_*` после включения (библиотека).

**Тонкость 1.** `PUBLIC` везёт стандарт через `INTERFACE_COMPILE_FEATURES`, и это видно только в строке
компиляции потребителя. Проверка: после (8) найди запись `app/src/main.cpp` — флаг обязан быть тем же
`-std=c++20`. Следствие нарушения: домен в 20, `main.cpp` — в режиме по умолчанию; `LightBulb.h` из урока 02,
включивший `Concepts.hpp`, падает на строке `concept` с текстом «does not name a type», и выглядит это как
ошибка заголовка, а не графа.

**Тонкость 2.** `gnu++20` и `c++20` различаются измеримо: `-std=c++20` определяет `__STRICT_ANSI__ 1`,
`-std=gnu++20` — нет (замер `g++ -dM -E`). Следствие: заголовки CRT/MinGW/glibc, которые ветвят по
`__STRICT_ANSI__`, дают **другой набор объявлений** — меняются не только расширения (`typeof`, `__int128`), но
и видимость стандартных имён. Требование воспроизводимости курса («одна строка компиляции на всех ОС и CI») —
оно и про `CXX_EXTENSIONS OFF`.

**5. Чекпойнт.** `cmake --build --preset win-ninja-debug` → сборка без ошибок;
`Select-String build/win-ninja-debug/compile_commands.json -Pattern "gnu\+\+"` → **пусто**. Если печатает
`-std=gnu++20`, пропуск D ещё не закрыт.

**Эталон цикла:** `qcompilerdetection.h:1317–1323` и `:1325–1336` — тот же класс решения в чистом виде:
`#error "Qt requires a C++17 compiler, and a suitable value for __cplusplus. On MSVC, you must pass the
/Zc:__cplusplus option to the compiler."`, и сразу `static_assert(!std::is_convertible_v<std::nullptr_t, bool>,
"On MSVC you must pass the /permissive- option to the compiler.")` — **доказательство режима компилятором, а не
флагом**: `/permissive-` проверяется поведенчески, потому что его отсутствие не меняет ни `__cplusplus`, ни
версию компилятора.

### Цикл 2 — compile-time данные: типизированный `Mode` и таблица фаз (план 3.1; ≤25 минут)

**1. Показ, разбор (1)–(8).** `Mode.hpp` из урока 01 остаётся строительным, но перестаёт быть «объявлением enum»:

```cpp
// ── core/include/trafficwatcher/core/Mode.hpp
#include <cstdint>                                                     // (1)
enum class Mode : std::uint8_t { Off = 0, On = 1, Blink = 2 };         // (2)

// ── core/include/trafficwatcher/core/PhaseTable.hpp
#include <array>
#include <cstddef>
#include <trafficwatcher/core/Mode.hpp>
struct Phase { Mode red; Mode green; std::uint16_t ticks; };           // (3)

inline constexpr std::array<Phase, 3> kPhases{                         // (4)
    Phase{.red = Mode::On,    .green = Mode::Off,  .ticks = 40},
    Phase{.red = Mode::Blink, .green = Mode::Blink, .ticks = 20},
    Phase{.red = Mode::Off,   .green = Mode::On,   .ticks = 60},
};

constexpr std::uint32_t totalTicks() {                                 // (5)
    std::uint32_t sum = 0;
    for (const Phase &p : kPhases) { sum += p.ticks; }
    return sum;
}
static_assert(totalTicks() == 120,                                     // (6)
              "sum of Phase::ticks must match the golden table of M1");

consteval std::size_t firstInvalidPhase() {                            // (7)
    for (std::size_t i = 0; i < kPhases.size(); ++i) {
        if (kPhases[i].ticks == 0) { return i; }
    }
    return kPhases.size();
}
static_assert(firstInvalidPhase() == kPhases.size(),                   // (8)
              "a zero-length phase makes TickEngine spin");
```

1. **`<cstdint>`** — без него `std::uint8_t`/`std::uint16_t` не объявлены; в Qt-коде тот же слой даёт `<QtGlobal>` (`quint8`/`qsizetype`), но `core` Qt не знает (урок 01: `tw_core` без Qt в доменных заголовках).
2. **Явный underlying type** — `: std::uint8_t`: размер известен, `Q_ENUM`/`QMetaEnum` с ним работают (цикл 5, тонкость 2 — там, где `valueToKey(int)` против `valueToKey(quint64)`), а «три значения в байт» позволяют сериализовать пресет по байту (модуль 13.2). Следствие: `enum class` и до этого не давал неявного conversion, но теперь в API `LightBulb` каждый `static_cast<int>` выглядит шумно — цикл 5 чинит его `qToUnderlying`.
3. **`struct Phase`** — агрегат без конструктора: именно поэтому работает (4) в форме designated initializers; свой конструктор отнял бы эту форму.
4. **`inline constexpr std::array<Phase, 3>`** — `inline`, чтобы одна таблица на TU не превратилась в `multiple definition` при линковке `tw_core` + `tw_app`; `std::array`, а не `std::vector`: compile-time динамическая память разрешена только при полном освобождении (тонкость 1 — с текстом ошибки).
5. **`constexpr` функция-сумма** — обычный `for`, `constexpr` с C++14; важно, что **инвариант** таблицы живёт рядом с таблицей, а не в тесте.
6. **`static_assert` с сообщением** — текст в кавычках обязан объяснять, что сломается в приложении: это читает следующий человек в CI-логе.
7. **`consteval` валидатор** — функция, исполнимая **только** на компиляции: вызов из `main()` — ошибка, и это хорошо. Внутри `return i`, а не `throw`: `throw` даёт сообщение на месте `static_assert`, но требует исключений в тулчейне (ADR-0003 о флагах; на MSVC `/EHsc` — отдельный вопрос).
8. **Второй `static_assert`** — «нет нулевой фазы». Тот же приём, которым Qt проверяет `/permissive-` (`qcompilerdetection.h:1335`): поведенческая проверка режима сборки, а не проверка флага.

**2. Делаем вместе: дырявый пример 2.** Те же объявления с четырьмя пропусками; форма пробы — из мини-практики (`Push-Location` в `bin`, `@(...) -join "\`n"` на входе):

```cpp
enum class Mode ______ { Off = 0, On = 1, Blink = 2 };              // пропуск A
struct Phase { Mode red; Mode green; std::uint16_t ticks; };
______ constexpr std::array<Phase, 3> kPhases{                      // пропуск B
    Phase{.red = Mode::On, .green = Mode::Off, .ticks = 40},
    Phase{.ticks = 20, .red = Mode::Blink, .green = Mode::Blink},   // пропуск C
    Phase{.red = Mode::Off, .green = Mode::On, .ticks = 60},
};
constexpr std::uint32_t totalTicks() { std::uint32_t s = 0; for (const Phase &p : kPhases) s += p.ticks; return s; }
static_assert(totalTicks() == ______ );                             // пропуск D
```

- **A.** Пропущен `: std::uint8_t`. Проверка: проба `@('#include <cstdint>','enum class M{Off};','static_assert(sizeof(M)==4);')` → **проходит** (без underlying type размер — `int`), то есть сериализация «по байту» молча врёт; с `: std::uint8_t` тот же assert падает: `error: static assertion failed` (замер).
- **B.** Без `inline` — сборка `tw_app`, включающего заголовок в двух TU, падает на `multiple definition of 'kPhases'` (link). Проверка: `cmake --build --preset win-ninja-debug 2>&1 | Select-String "multiple definition"` → непусто.
- **C.** Designator'ы **не в порядке объявления** (`.ticks` раньше `.red`). Замер на `-std=c++20`: `error: designator order for field 'P::a' does not match declaration order in 'P'`, код 1 — и то же в режиме C++17. Это единственная из «мягких» конструкций цикла, которая падает сама; остальные — нет.
- **D.** `== 120`. Проверка: посчитай сам и сравни с выводом; при заведомо неверном числе сообщение обязано читаться как задание (`"sum of Phase::ticks …"` из (6)), а не как голое `static assertion failed`.

**3. Ты делаешь (3 минуты).** Замени `ticks = 20` на `ticks = 0` в **своей** `PhaseTable.hpp`:
`cmake --build --preset win-ninja-debug 2>&1 | Select-String "firstInvalidPhase|static assertion|zero-length"` →
сборка падает на (8) с текстом `"a zero-length phase makes TickEngine spin"`. Это negative control: если assert
не сработал, `consteval` у тебя превратился в `constexpr` — проверь (7).

**4. Ловушка и тонкости.**

**Ловушка.** Таблица соберётся и в C++17: вариант (4) с designated initializers на `-std=c++17 -Wall -Wextra` →
код 0 («Ловушка» цикла 1), а `__cpp_designated_initializers` при этом не определён. Значит защита от «это
собрали не в том режиме» — не флаг и не warning, а `#ifndef __cpp_concepts`-гейт или `static_assert` на `sizeof`
(пропуск A); в курсовом коде такой гейт стоит в `Concepts.hpp` (цикл 3).

**Тонкость 1.** Динамическая память в constant expression — только с полным освобождением. Замер:
`constexpr std::vector<int> f(){ std::vector<int> v{1,2,3}; return (int)v.size(); }` в `static_assert` —
**код 0** (деструктор освобождает память внутри константного выражения), а утечка
`constexpr int g(){ auto p = new int(5); return *p; }` — `error: '(g() == 5)' is not a constant expression
because allocated storage has not been deallocated`, код 1. Следствие: compile-time таблица — это `std::array`
+ `constexpr` (`inline`), а не «кэш на `std::vector` в `init()`», и проверяет это один `static_assert`, а не ревью.

**Тонкость 2.** `[[no_unique_address]]` меняет раскладку **молча и в C++17**. Замер: `struct E{}; struct A{E e;int x;int y;};
struct B{[[no_unique_address]] E e;int x;int y;};` → **`A=12 B=8`** при `-std=c++17 -Wall -Wextra -Wpedantic`, код 0,
и `__has_cpp_attribute(no_unique_address) == 201803L` в обоих режимах. То есть атрибут работает там, где по
стандарту его быть не должно, `__has_cpp_attribute` это не отличает, диагностики нет даже с `-Wpedantic`. Для
проекта с ABI-экспортом (`tw_core` в 11.3) значит: им пользуются, только если весь граф собран одним тулчейном,
и это строка ADR-0005. Подсказка из production: `Select-String -Path "<Qt>\include\QtCore\*.h" -Pattern
"\[\[no_unique_address\]\]"` → **0 совпадений** (замер по Qt 6.10.2), хотя пустых членов-обёрток в Qt хватает.

**5. Чекпойнт.** `cmake --build --preset win-ninja-debug` → зелёная **с обоими** `static_assert` и без строки
`zero-length` в логе; `Select-String core/include/trafficwatcher/core/PhaseTable.hpp -Pattern "static_assert"` → две строки.

**Эталон цикла:** `qttypetraits.h:27–32` (замер по установленным заголовкам) — комментарий
`// like std::to_underlying` и `constexpr std::underlying_type_t<Enum> qToUnderlying(Enum e) noexcept`: Qt пишет
**свою** функцию, потому что системная — C++23 (правило 3); там же `qExchange` «like std::exchange» под
`#ifndef QT_NO_QEXCHANGE` — фасад вместо прямой зависимости от версии библиотеки.

### Цикл 3 — concepts: граница, которую читает компилятор (план 3.2; ≤25 минут)

**1. Показ, разбор (1)–(7).** `core/include/trafficwatcher/core/Concepts.hpp` — строительный, живёт до 6.1:

```cpp
#include <type_traits>                                                     // (1)

#ifndef __cpp_concepts                                                     // (7)
#error "tw_core requires a C++20 compiler"
#endif

namespace trafficwatcher::core {

template <typename E>                                                      // (2)
concept ScopedEnum = std::is_enum_v<E> && !std::is_convertible_v<E, int>;

template <typename E>                                                      // (3)
    requires ScopedEnum<E>
constexpr auto toIndex(E e) noexcept { return static_cast<std::underlying_type_t<E>>(e); }   // (4)

template <typename T>                                                      // (5)
constexpr bool acceptsAsMode(T v) noexcept
{
    if constexpr (ScopedEnum<T>) { return toIndex(v) < 3; }                 // (6)
    else { return false; }
}

} // namespace trafficwatcher::core
```

1. **Только `<type_traits>`** — `tw_core` не знает Qt (урок 01); `std::derived_from` из `<concepts>` появится в (5)-варианте для `QObject`, когда хелпер переедет в `tw_ui` (тонкость 2).
2. **`concept`, а не `static_assert` внутри** — правило 5 (Core Guidelines **I.9**: «If an interface is a template, document its parameters using concepts»). Две части условия читаются как спецификация: «это enum» и «он не превращается в `int`» — вторая отсекает старый `enum Mode` из [`legacy-description.md`:26](../legacy-description.md#L26), который как раз в `int` и превращался.
3. **`requires`-предложение отдельной строкой**, а не ограничение в имени параметра (`template<ScopedEnum E>`): обе формы легальны, но (3) остаётся читаемой, когда ограничений два и больше — и ровно её использует Qt: `qttypetraits.h:270` — `requires std::three_way_comparable_with<T, U>` отдельной строкой, над ней компактная `template<std::three_way_comparable T>` (`:267`) (замер).
4. **`std::underlying_type_t<E>`** — тип известен из цикла 2 (`: std::uint8_t`), поэтому `toIndex` даёт `unsigned char`, и ширина поля в пресете (13.2) совпадает с типом.
5. **Одна функция с `if constexpr` вместо трёх перегрузок** — план 3.2 прямо просит сравнить формы. Различие в диагностике и в числе кандидатов («Ловушка»): `if constexpr` выбирает ветку **после** подстановки и не даёт «no matching function», перегрузки с `requires` дают список причин отказа.
6. **`toIndex(v) < 3`** — магическое число оставлено сознательно: в задании его убирает `kPhases.size()` (цикл 2), и это единственная правка, превращающая пример в домен.
7. **Гейт «а если компилятор без концептов» — (7)**, над (2): `#ifndef __cpp_concepts` + `#error "tw_core requires a C++20 compiler"`: та же форма, что `qcompilerdetection.h:1317–1322` (правило 1). `#error`, а не тихая подмена: `Concepts.hpp` включается из `LightBulb.h`, и молчаливая деградация означала бы, что QML-свойство снова принимает любой `int`.

**2. Делаем вместе: дырявый пример 3.** Тот же файл с тремя пропусками:

```cpp
template <typename E>
concept ScopedEnum = ______(E) && !std::is_convertible_v<E, int>;    // пропуск A
template <typename E>
______ ScopedEnum(E)                                                // пропуск B
constexpr auto toIndex(E e) noexcept { return static_cast<std::underlying_type_t<E>>(e); }
template <typename T>
constexpr bool acceptsAsMode(T v) noexcept {
    ______ (ScopedEnum<T>) { return toIndex(v) < 3; }                // пропуск C
    else { return false; }
}
```

- **A.** `std::is_enum_v`. Проверка: проба `static_assert(ScopedEnum<int> == false);` через `g++ -fsyntax-only -std=c++20 -I core/include` → код 0; если вместо `is_enum_v` написать `is_integral_v`, тот же assert падает.
- **B.** `requires`. Проверка предсказания: `@('template<typename E> requires EnumC<E> int f(E);','int main(){ return f(3.5); }')` → в диагностике обязана быть строка `constraints not satisfied` (замер в «Ловушке»); без `requires` её нет.
- **C.** `if constexpr`. Проверка: `g++ -std=c++17` на том же файле → отказ с текстом про `constexpr` (`error: 'if constexpr' …`/`expected primary-expression`, формулировка зависит от режима); главное — `if constexpr` **не компилируется в C++17**, в отличие от обычной `constexpr`-ветки, и это аргумент для гейта (7).

**3. Ты делаешь (4 минуты).** Сравни две формы отказа на своей машине:

```powershell
Push-Location "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin"
$conc = @('#include <type_traits>','template<typename E> concept EnumC=std::is_enum_v<E>;','template<typename T> concept IntC=std::is_integral_v<T>;','template<EnumC E> int f(E){return 1;}','template<IntC T> int f(T){return 2;}','int main(){ return f(3.5); }') -join "`n"
$o = ($conc | & ".\g++.exe" -fsyntax-only -std=c++20 -x c++ - 2>&1 | ForEach-Object {"$_"}) -join "`n"
"CONCEPT lines=" + $o.Split("`n").Count
$snf = @('#include <type_traits>','template<typename E> std::enable_if_t<std::is_enum_v<E>,int> f(E){return 1;}','template<typename T> std::enable_if_t<std::is_integral_v<T>,int> f(T){return 2;}','int main(){ return f(3.5); }') -join "`n"
$p = ($snf | & ".\g++.exe" -fsyntax-only -std=c++20 -x c++ - 2>&1 | ForEach-Object {"$_"}) -join "`n"
"SFINAE lines=" + $p.Split("`n").Count
Pop-Location
```

→ замеры ассистента (GCC 13.1.0): **CONCEPT lines=16**, **SFINAE lines=13**. Формат вывода одинаковый, число
строк у концептов **больше**; разница — в содержании.

**4. Ловушка и тонкости.**

**Ловушка.** Концепт не сокращает диагностику — он делает её **адресной** (16 строк против 13, замер выше). Цепочка ниже — та же проба `f(3.5)`, но под границей (2)–(4) этого цикла (`toIndex` с `requires ScopedEnum<E>`), а не под двумя однострочными концептами.
Последние строки у концептов (замер, дословно): `error: no matching function for call to 'toIndex(double)'` →
`note: candidate: 'template<class E>  requires  ScopedEnum<E> constexpr auto toIndex(E)'` →
`note: constraints not satisfied` → `note: the expression 'is_enum_v<E> [with E = double]' evaluated to 'false'`.
У SFINAE последние строки — `error: no type named 'type' in 'struct std::enable_if<false, int>'`: сказано, что
сломалось, но не сказано, **какое требование**. Поэтому концепт берут не за краткость, а за то, что отказ
указывает на строку определения концепта, — и пишут его **для каждой границы**, где иначе появился бы
`static_assert` в теле.

**Тонкость 1.** Граница с `requires` превращает «не должно компилироваться» в **проверяемый тест**. Форма из
production-практики CMake — `try_compile`: `try_compile(<compileResultVar> PROJECT <projectName> SOURCE_DIR
<srcdir> [BINARY_DIR <bindir>] [TARGET <targetName>] …)`, и по руководству `cmake --help-command try_compile`
(замер): «Build success returns `TRUE` and build failure returns `FALSE` in `<compileResultVar>`» — то есть
`if(<compileResultVar>) message(FATAL_ERROR …)` инвертирует смысл, и тест «не компилируется» становится
конфигурационным. Альтернатива — `add_test` + `set_tests_properties(<t> PROPERTIES WILL_FAIL TRUE)` (урок 01,
цикл 5) на цели `cmake --build --target <negative-target>`. Следствие выбора без `try_compile`: `WILL_FAIL`
принимает **любой** ненулевой код — падение из-за отсутствующего компилятора зачитается как «концепт работает».
Проверка: `cmake --help-command try_compile` и `ctest --help | Select-String "WILL_FAIL"`.

**Тонкость 2.** Ограничение на `QObject` живёт **в другом слое**, чем `ScopedEnum`: `std::derived_from<T, QObject>`
требует `<concepts>` и видимости `QObject`. Замер на установленных заголовках 6.10.2: проба
`template<typename T> concept IsQ = std::derived_from<T, QObject>; static_assert(IsQ<QObject>);` на
`-std=c++17` → `error: 'concept' does not name a type` + `note: 'concept' only available with '-std=c++20' or
'-fconcepts'` (код 1), на `-std=c++20` → код 0. Следствие: такой концепт появляется в `ui/`, а не в `core/` —
иначе `tw_core` теряет независимость от Qt, которую ты построил в уроке 01 и принимаешь в 6.1. Та же
сдержанность у Qt: `qttypetraits.h:266` — `#if defined(__cpp_lib_three_way_comparison) && defined(__cpp_lib_concepts)`,
а вне этой ветки те же traits **неограниченны**, и в `q20iterator.h:47` стоит дословный комментарий
`// unconstrained (constraint requires concepts)`; при этом `Select-String -Path "<Qt>\include\QtCore\*.h" -Pattern
"^\s*concept "` → **0 совпадений** (замер): Qt 6.10 не объяляет **своих** концептов в публичных заголовках, хотя
библиотечные использует. Значит позиция ADR-0005 «свои концепты в домене — да, в публичных заголовках
библиотеки — с оглядкой на 11.3» опирается не на вкус, а на то, как решает сам Qt.

**5. Чекпойнт.** `cmake --build --preset win-ninja-debug 2>&1 | Select-String "constraints not satisfied"` →
**пусто** (сборка зелёная); `Select-String core/include/trafficwatcher/core/Concepts.hpp -Pattern "concept |requires|if constexpr"`
→ три совпадения: по одной форме на каждую часть плана 3.2.

**Эталон цикла:** `qttypetraits.h:262–272` (замер) — как выглядит «ограничить нельзя, но и молчать нельзя»;
Core Guidelines I.9 (правило 5); контраст — `q20iterator.h:47` с сознательным «unconstrained».

### Цикл 4 — view над таблицей фаз: `std::span`, `QSpan` и ranges (план 3.1 + 3.3; ≤25 минут)

**1. Показ, разбор (1)–(6).**

```cpp
// ── core/include/trafficwatcher/core/PhaseTable.hpp (продолжение)
#include <span>                                                        // (1)
#include <ranges>

namespace trafficwatcher::core {

constexpr const Phase *firstRed(const Phase *p, std::size_t n)         // (2)
{
    std::span<const Phase> view{p, n};                                 // (3)
    for (const Phase &row : view) {
        if (row.red != Mode::Off) { return &row; }
    }
    return nullptr;
}

constexpr auto redPhases(std::span<const Phase> all)                   // (4)
{
    return all | std::views::filter([](const Phase &p) { return p.red != Mode::Off; });   // (5)
}

} // namespace trafficwatcher::core
```

1. **`<span>` в C++17 компилируется, но ничего не объявляет.** Замер: `#include <span>` на `-std=c++17` → код 0;
   использование → `error: 'span' in namespace 'std' does not name a template type` + `note: 'std::span' is only
   available from C++20 onwards`. Проверка включаемости потому и не проверка: смотри на `__cpp_lib_span` или на
   текст ошибки (правило 4).
2. **Пара `(const Phase *p, std::size_t n)`** оставлена сознательно как контраст: она и есть то, от чего `std::span`
   избавляет, и правило **SL.con.3 «Avoid bounds errors»** ([CppCoreGuidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines),
   заголовок проверен 26.11.2026) — про это. В задании (шаг 2) та же функция принимает `std::span<const Phase>`
   напрямую: здесь пара сохранена, чтобы было видно, от чего именно избавляет view.
3. **`std::span<const Phase>`** — **view, а не владелец**: `tw_core` не аллоцирует, не хранит и не копирует
   таблицу; размер типа — `sizeof(ptr)+sizeof(count)`, `size_type` — `std::size_t`.
4. **Возврат view из функции, принимающей view** — безопасен ровно потому, что владелец данных стоит в сигнатуре
   выше (`kPhases`, цикл 2); в «Ловушке» — случай, когда его нет.
5. **`std::span` в сигнатуре публичной функции + `std::views::filter`** — то самое решение, которое стоит абзаца в
   ADR-0005. Qt от `std::span` в API отказался по правилу 2 («Qt 6 only requires C++17, meaning it cannot have
   C++20 types in the API and ABI»); `tw_core` же **требует** C++20 у всех потребителей (экспорт 11.3), поэтому
   `std::span` в его API допустим — но как строка ADR, а не «ну это же стандарт». `views::filter` ленив: ничего не
   аллоцируется, композиция читается; под C++17 та же строка даёт `error: 'std::views' has not been declared` и
   `error: 'std::ranges' has not been declared` (замер, код 1).
6. **`nullptr` как «не найдено»** — в `core` ещё терпимо (тип указателя), но цикл 5 показывает: Qt уже переходит на
   `std::optional`, и смешивать два поколения в одном API — решение для ADR-0005.

**2. Делаем вместе: дырявый пример 4.**

```cpp
constexpr const Phase *firstRed(const Phase *p, std::size_t n) {
    std::span<______> view{p, n};                  // пропуск A — элемент + cv
    for (const Phase &row : view) { if (row.red != Mode::Off) return &row; }
    return ______;                                 // пропуск B — «не найдено»
}
constexpr auto redPhases(______ all)               // пропуск C — тип параметра
{ return all | ______::filter([](const Phase &p){ return p.red != Mode::Off; }); }  // пропуск D
```

- **A.** `const Phase`. Проверка: `std::span<Phase>` от `const Phase *` не собирается — отказ при инициализации (та же проба через `g++ -fsyntax-only -std=c++20`).
- **B.** `nullptr`. Проверка: `Select-String core/include/trafficwatcher/core/PhaseTable.hpp -Pattern "nullptr|throw "` → `nullptr` и ни одного `throw`: `tw_core` живёт без исключений до ADR-0003.
- **C.** `std::span<const Phase>`. Проверка: `redPhases(kPhases)` в пробе — `std::array<Phase,3>` конвертируется в `std::span` неявно; если написать `std::span<Phase>`, проба падает.
- **D.** `std::views`. Проверка: `-std=c++17` → `error: 'std::views' has not been declared` (текст замера выше).

**3. Ты делаешь (5 минут).** Две пробы этого цикла собирают `build/bsort.exe` (`std::sort(v.begin(), v.end())`) и
`build/branges.exe` (`std::ranges::sort(v)`) на `std::mt19937` с фиксированным seed и 1 000 000 `int`, обе —
`-O2 -std=c++20` (форма пробы — из мини-практики, с `-B.`). Затем:

```powershell
Push-Location "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin"
foreach ($n in 'bsort','branges') { $t = 1..5 | ForEach-Object { (Measure-Command { & "C:\Projects\TrafficWatcher\build\$n.exe" | Out-Null }).TotalMilliseconds }; "$n avg=$(($t | Measure-Object -Average).Average -as [int]) ms" }
Pop-Location
```

→ замер ассистента: **424 мс** против **373 мс** на пяти прогонах — разница одного порядка с шумом запуска
процесса. Вывод, который можно защищать: **`<ranges>` берут не ради скорости**, а ради композиции и отсутствия
пары итераторов; в ADR-0005 это строка «ranges: можно, производительность не аргумент, замер на 1e6 int — в уроке».

**4. Ловушка и тонкости.**

**Ловушка.** Висящий view не диагностируется **никакими** флагами этого тулчейна. Замеры:
`std::span<int> h(){ std::vector<int> v(4); return std::span<int>(v); }` → код 0, вывод пуст;
`QSpan<int> f(){ std::vector<int> v(4); return QSpan<int>(v); }` на заголовках Qt 6.10.2 → код 0 с
`-Wall -Wextra -Wpedantic`. То же с view над временным объектом: `redPhases(kPhases | std::views::filter(...))`
легально и живёт до конца выражения, а `auto r = std::vector<int>{1,2} | std::views::all;` — уже нет. Значит
защита — не компилятор, а **форма сигнатуры**: в `tw_core` view появляется только как параметр, а владелец
(`kPhases`, `LightBulb::phases_`) виден в той же строке вызова; функция, возвращающая view над параметром-контейнером
по значению, удаляется на ревью. Проверка в курсе — grep, а не сборка:
`Select-String -Path core/**/*.hpp -Pattern "span<.*>\s+\w+\(\s*\)"`.

**Тонкость 1.** `QSpan` ≠ `std::span`, и отличия видны в заголовке, который лежит у тебя на диске. Замер по
`qspan.h`: `using size_type = qsizetype;  // difference to std::span` (`:336`), `using difference_type = qptrdiff;
// difference to std::span` (`:337`), `static_assert` про `qsizetype::max` (`:163`), `Q_IMPLICIT constexpr
QSpanBase(std::span<S, E> other)` (`:236`) — конверсия в обе стороны есть, а **размерный тип свой**. Проверка
без линковки: проба `static_assert(std::is_same_v<decltype(std::declval<QSpan<int>>().size()), qsizetype>)` через
`-fsyntax-only -std=c++20 -I "<Qt>\include"` → код 0 (замер), и **тот же код 0 на `-std=c++17`**: `QSpan`
спроектирован так, чтобы работать в C++17 (`qspan.h:104` — «Replacement for `std::ranges::iterator_t` (which
depends on C++20 `std::ranges::begin`)»). Следствие: в `ui/` уместен `QSpan` (одинаково во всех режимах, ABI Qt),
в `core/` — `std::span` (мы требуем C++20); одна и та же функция в двух слоях с разными типами — норма, а не
ошибка, и её цена — конверсия на границе.

**Тонкость 2.** `std::ranges::to` нет даже в C++23-режиме этого тулчейна: замер `-std=c++23` → `error: 'to' is not
a member of 'std::ranges'` (код 1), и `__cpp_lib_ranges_to_container` не определяется ни в `-std=c++20`, ни в
`-std=c++23`. Причина — не стандарт, а библиотека: нужен libstdc++ 14 (`_GLIBCXX_RELEASE >= 14`, правило 3).
Следствие для плана: строка [`3.3`](../course.md#L143) «Ranges» закрывается композицией `views::` +
`std::ranges::copy/count`, а `ranges::to` попадает в ADR-0005 в колонку «запрещено до смены тулчейна».

**5. Чекпойнт.** `cmake --build --preset win-ninja-debug` → зелёная; `ctest --preset win-ninja-debug -L unit` →
unit-тест `phaseTable.firstRed` проходит; `Select-String core/include/trafficwatcher/core/PhaseTable.hpp -Pattern
"std::span|std::views"` → две строки: (3) и (5).

**Эталон цикла:** cpp20-overview, раздел «QSpan - a Qt version of std::span» (правило 2, цитата про API/ABI);
`qspan.h:336–337` с пометками «difference to std::span»; Core Guidelines SL.con.3 (пара указатель/размер).

### Цикл 5 — строки, опциональность и логи: что Qt уже решил за нас (план 3.3 + 3.4; ≤25 минут)

**1. Показ, разбор (1)–(7).** `ui/LightBulb.cpp` — первое место в репозитории, где C++20 и Qt встречаются в одной
строке (класс из урока 02, цикл 3):

```cpp
#include <QtCore/QMetaEnum>                                                 // (1)
#include <QtCore/QtTypeTraits>
#include <source_location>                                                  // (2)
#include <format>                                                           // (3)

namespace {
struct Location { const char *file; unsigned line; };                        // (4)

constexpr Location here(std::source_location l = std::source_location::current())
{
    return {l.file_name(), l.line()};
}

const char *modeName(Mode m)                                                 // (5)
{
    const QMetaEnum me = LightBulb::staticMetaObject.enumerator(
        LightBulb::staticMetaObject.indexOfEnumerator("Mode"));
    const char *key = me.valueToKey(qToUnderlying(m));                       // (6)
    return key ? key : "<unknown>";                                          // (7)
}
} // namespace
```

1. **`<QtCore/QMetaEnum>` + `<QtCore/QtTypeTraits>`** — второй нужен ради `qToUnderlying`, и он же — ответ на строку плана [`3.3`](../course.md#L143): `std::to_underlying` под C++20 недоступен (замер: `error: 'to_underlying' is not a member of 'std'` + `note: 'std::to_underlying' is only available from C++23 onwards`). Qt заранее положил свою версию с комментарием `// like std::to_underlying` (`qttypetraits.h:27`), работающую в обоих режимах (замер: `static_assert(std::is_same_v<decltype(qToUnderlying(M::A)), unsigned char>)` → код 0 на `-std=c++17` и на `-std=c++20`).
2. **`<source_location>`** — план 3.4; `__cpp_lib_source_location` на этом тулчейне — **`201907L`** (замер `-dM -E` после `#include <version>`), работает в C++20. Как гейтит себя Qt — `qproperty.h:17`: `#if __has_include(<source_location>) && __cplusplus >= 202002L && !defined(Q_QDOC)` и внутри `#if defined(__cpp_lib_source_location)` (`:19`): три условия вместо одного — правило 3 в чистом виде.
3. **`<format>`** — `__cpp_lib_format 202106L` (замер, `-std=c++20`), и `std::format` собирается **и запускается**: `std::format("{}-{}", 1, 2).size()` → программа возвращает 3, код 0. Но `QString::formatted` из той же строки плана в Qt 6.10.2 отсутствует (`Select-String qstring.h -Pattern "formatted"` → по методу ноль совпадений; есть `arg`, `asprintf`, `vasprintf` — `:354–368`), а `<print>` нет как заголовка: `fatal error: print: No such file or directory` (замер в `-std=c++20` **и** в `-std=c++23`). Рабочая форма для Qt-строк: `QString::fromUtf8(std::format("…", …).c_str())` или `arg` — выбор идёт в ADR-0005, потому что на другом тулчейне `<print>` появится, и кто-то захочет его включить.
4. **Своя `struct Location`, а не `std::source_location` в сигнатуре** — соображение ABI (правило 2), и Qt решает его жёстче: `qcompilerdetection.h:1157–1179` дословно — «If one wants to add functions that use post-C++17 APIs, one needs to: 1) make them fully inline; and 2) guard them using the necessary feature-testing macros … A problem arises on MSVC for member functions of exported classes … if Qt has been built in C++17, it won't have such a symbol, and linking will fail. The workaround: declare such functions as function templates», и определение `#define QT_POST_CXX17_API_IN_EXPORTED_CLASS template <typename = void>` (`:1176`; тот же приём — `Q_WEAK_OVERLOAD`, `:1152`). Для экспортируемого `tw_core` (11.3) это прямая инструкция: **C++20-тип в сигнатуре метода экспортируемого класса** — либо inline, либо шаблон-фасад, либо не в публичном API.
5. **`QMetaEnum`** — второй способ получить имя режима, независимый от нашего `constexpr`-кода; с циклом 2 это два источника одного знания, и между ними обязан быть тест (шаг 6 задания).
6. **`qToUnderlying(m)` вместо `static_cast<int>(m)`** — находка `10` ([`legacy-description.md`:56](../legacy-description.md#L56)) лечится здесь: `qToUnderlying` даёт `std::uint8_t`, и вызывается **та** перегрузка, которая выбрана; сигнатуры в 6.10.2 — `const char *valueToKey(int)` (`qmetaobject.h:289`) и `const char *valueToKey(quint64)` (`:292`), рядом `std::optional<quint64> keyToValue64(const char *)` (`:286`) и старый `int keyToValue(const char *key, bool *ok = nullptr)` (`:284`).
7. **`key ? key : "<unknown>"`** — `valueToKey` возвращает `nullptr` на неизвестном значении; в этом же классе Qt уже мигрирует на `std::optional` (`:280`, `:286–287`), и это ответ на план 3.4: **опциональность в Qt-коде уже двух поколений**, а смешение «-1/nullptr» с `optional` в одном API — то, что ADR-0005 обязан запретить явно.

**2. Делаем вместе: дырявый пример 5.**

```cpp
const char *modeName(Mode m) {
    const QMetaEnum me = LightBulb::staticMetaObject.enumerator(
        LightBulb::staticMetaObject.indexOfEnumerator(______));            // пропуск A
    const char *key = me.valueToKey(______(m));                            // пропуск B
    return ______;                                                         // пропуск C
}
```

- **A.** `"Mode"` — строка обязана совпасть с именем в `Q_ENUM`. Проверка: `QVERIFY(LightBulb::staticMetaObject.indexOfEnumerator("Mode") >= 0)` — падает в рантайме, если имя съехало; молча `-1` сборка не ловит.
- **B.** `qToUnderlying`. Проверка: та же проба `static_assert(std::is_same_v<decltype(qToUnderlying(M::A)), unsigned char>)` через `-fsyntax-only -std=c++20 -I "<Qt>\include"` → код 0; с `static_cast<int>` assert падает — то есть `int`-перегрузка выбиралась бы молча.
- **C.** `key ? key : "<unknown>"`. Проверка: unit-тест со `static_cast<Mode>(7)` (такой cast компилируется) → ждём `"<unknown>"`, а не `nullptr` в QML-строке.

**3. Ты делаешь (4 минуты).**

```powershell
Push-Location "C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin"
(@('#include <source_location>','#include <cstdio>','void log(const char*m,std::source_location l=std::source_location::current()){printf("%s @ %s:%u in %s\n",m,l.file_name(),l.line(),l.function_name());}','int main(){ log("tick"); }') -join "`n") | & ".\g++.exe" -B. -std=c++20 -x c++ - -o C:\Projects\TrafficWatcher\build\psl.exe
& "C:\Projects\TrafficWatcher\build\psl.exe"
Pop-Location
```

→ замеры ассистента: сборка — код 0, вывод `tick @ <stdin>:4 in int main()`. Обрати внимание на **`<stdin>`** (проба шла из stdin — из реального файла будет его путь) и на **`4`** — это строка **вызова**, а не определения: в этом весь приём с default-аргументом. Вторая часть: `@('#include <print>','int main(){}')` на `-std=c++23` → `fatal error: print: No such file or directory` (замер) — и обнови таблицу ADR-0005.

**4. Ловушка и тонкости.**

**Ловушка.** `char8_t` — не «строчка в UTF-8», а **отдельная перегрузка, которой нет в C++17**. Замер на установленных заголовках: `static_assert(std::is_constructible_v<QString, const char8_t*>);` → на `-std=c++17` код 1 с `error: parse error in template argument list`, на `-std=c++20` — код 0 (в `qstring.h:217` — `#if defined(__cpp_char8_t) || defined(Q_QDOC)`). Следствие: один и тот же `LightBulb.cpp` собирается в двух режимах **с разными наборами перегрузок**, и ошибка «не тот режим» приходит не как «нет метода», а как «parse error» — искать её надо по `__cpp_char8_t` (`202207L`, замер предопределённых макросов), а не по `__cplusplus >= 202002L`: у GCC 8.1 на `-std=c++2a` `__cplusplus` вообще `201709L` (замер).

**Тонкость 1.** `std::source_location` в дефолтном аргументе снимает **место вызова** (замер выше) и потому заменяет
`__FILE__`/`__LINE__`-макрос; но у Qt свой слой остался: `qlogging.h:168` — `#define qDebug QMessageLogger(QT_MESSAGELOG_FILE,
QT_MESSAGELOG_LINE, QT_MESSAGELOG_FUNC).debug`, и контекст включается только при `QT_MESSAGELOGCONTEXT` (`:150–158`).
Цена: в release-сборке без этого define файл/строка в лог **не попадают**, и замена `qDebug()` на свой `log()` меняет
объём бинарника и поведение фильтра логов — это уровень ADR-0005/6.2 («`qCDebug`-категории»), а не стилевая правка.
Проверка: `Select-String -Path "<Qt>\include\QtCore\qlogging.h" -Pattern "QT_MESSAGELOGCONTEXT"` → три совпадения в 150–158.

**Тонкость 2.** У `QMetaEnum` **два поколения API в одном классе** (замер по `qmetaobject.h`): `isScoped()` (`:274`), `is64Bit()` (`:275`), `value64(int)` → `std::optional<quint64>` (`:280`), `keyToValue(const char*, bool *ok)` → `int` (`:284`), `keyToValue64`/`keysToValue64` → `std::optional<quint64>` (`:286–287`), `valueToKey(int|quint64)` → `const char *` (`:289`, `:292`). Следствие, из-за которого в цикле 2 выбран `enum class Mode : std::uint8_t`: если underlying-тип знаковый и больше `int`, `valueToKey(int)` теряет точность, а `valueToKey(quint64)` меняет выбор перегрузки — тест на значение вне диапазона (`static_cast<Mode>(7)`) обязан быть в `tests/` (шаг 6).

**Тонкость 3.** `std::expected` — **тулчейн**, а не стандарт: под `-std=c++20` — `error: 'expected' is not a member of 'std'`, под `-std=c++23` на этом же компиляторе — код 0 (замер), и библиотечный гейт в libstdc++ 13 выглядит как `#if __cplusplus > 202002L && __cpp_concepts >= 202002L` (`<expected>:34`, замер по установленным заголовкам). Форма «строго больше 202002L» нужна потому, что GCC 13 на `-std=c++23` печатает `__cplusplus = 202100L` — **preview-значение**, а не `202302L` (замер): любой код, написанный как `#if __cplusplus >= 202302L`, на этом компиляторе не включится никогда. Следствие: `expected` — «разрешено после смены тулчейна», `optional` — «разрешено сейчас», и причина записана числом, а не мнением.

**5. Чекпойнт.** `ctest --preset win-ninja-debug -L unit -V 2>&1 | Select-String "modeName|PASS"` → минимум один
unit-тест с именем про `modeName` и строка `PASS` для него; `Select-String ui/LightBulb.cpp -Pattern "static_cast<int>"`
→ **пусто** (`qToUnderlying` занял его место).

**Эталон цикла:** `qcompilerdetection.h:1157–1179` («post-C++17 API» + `QT_POST_CXX17_API_IN_EXPORTED_CLASS`) — как
живут C++20-типы в экспортируемом API; `qproperty.h:17–31` — как гейтится `source_location` и почему у MSVC там
отдельная ветка («MSVC runs into an issue with constexpr with source location (error C7595)»);
[`.clang-tidy` Qt Creator](https://raw.githubusercontent.com/qt-creator/qt-creator/master/.clang-tidy) (замер) —
production-политика анализа: список начинается с `-*` (включается только перечисленное), там же `CheckOptions:
modernize-loop-convert.UseCxx20ReverseRanges: false` — **реально отключённое** C++20-преобразование, плюс
`-bugprone-unchecked-optional-access`: проверку обязательного чтения `optional` Qt Creator **выключил**, то есть
дисциплина держится на ревью и тестах, а не на линтере.

## Блок 6. Задание

**Проект: сделать режим C++20 доказуемым и поставить на границу домена первые концепты.** В репозитории должно появиться: доказанный флаг компиляции (иначе следующее ядро пишется наугад), compile-time инварианты таблицы фаз (иначе «ноль тиков» уезжает в рантайм), концепт на границе enum (иначе `static_cast<Mode>(7)` из QML — легальное значение), и заполненный ADR-0005 (иначе модуль 4 начнёт писать C++23-код).

Definition of Done:

- [ ] **D1.** `Select-String build/win-ninja-debug/compile_commands.json -Pattern "-std="` даёт **ровно одно** уникальное значение `-std=c++20`, и `-Pattern "gnu\+\+"` — пусто.
- [ ] **D2.** В `core/CMakeLists.txt` стоят `CXX_EXTENSIONS OFF` и `CXX_STANDARD_REQUIRED ON`; `cxx_std_20` — `PUBLIC`.
- [ ] **D3.** `Mode.hpp`: `enum class Mode : std::uint8_t` + `static_assert(sizeof(Mode) == 1)`.
- [ ] **D4.** `PhaseTable.hpp`: `inline constexpr std::array<Phase, N>` + два `static_assert` (сумма тиков, отсутствие нулевой фазы); ни одного `std::vector` в константном выражении.
- [ ] **D5.** `Concepts.hpp`: `concept ScopedEnum`, `requires` на `toIndex`, `if constexpr` в `acceptsAsMode`, `#error`-гейт на отсутствие `__cpp_concepts`.
- [ ] **D6.** `ui/LightBulb.cpp`: `qToUnderlying` вместо `static_cast<int>` в рефлексии; `modeName()` с веткой на `nullptr`.
- [ ] **D7.** `tests/`: ≥3 unit-теста с лейблом `unit` + negative control, который **обязан** не компилироваться; `ctest --preset win-ninja-debug -L unit` зелёный, `-L negative` зелёный.
- [ ] **D8.** `docs/adr/0005-*.md` — черновик (пишешь ты, `AGENTS.md` §1.3) с таблицей «фича | стандарт/тулчейн | гейт | цена | чем проверено»: ≥8 строк, из них ≥3 — с текстом ошибки или номером строки заголовка Qt.

### Прямые шаги

**Шаг 1 — `core/include/trafficwatcher/core/Mode.hpp` (D3).** `enum class Mode : std::uint8_t { Off = 0, On = 1, Blink = 2 };` — порядок значений фиксирован (пресеты 13.2); `static_assert(sizeof(Mode) == 1, …)` с сообщением про формат данных, а не про тип; ни `<QObject>`, ни `<QString>` (`tw_core` остаётся без Qt — урок 01). Проверка: `cmake --build --preset win-ninja-debug 2>&1 | Select-String "static assertion"` → **пусто**; временно замени `std::uint8_t` на `unsigned` → assert обязан упасть (проверка, что assert живой).

**Шаг 2 — `core/include/trafficwatcher/core/PhaseTable.hpp` (D4).** `struct Phase { Mode red; Mode green; std::uint16_t ticks; };` — агрегат без своего конструктора; `inline constexpr std::array<Phase, N> kPhases{ … }` — designated initializers **в порядке объявления**; два `static_assert` (сумма `ticks`, «нет фазы с `ticks == 0`» через `consteval`); `constexpr const Phase *firstRed(std::span<const Phase>)` + `redPhases(std::span<const Phase>)` (цикл 4). Проверка: `Select-String core/include/trafficwatcher/core/PhaseTable.hpp -Pattern "static_assert|std::span|inline constexpr"` → ≥4 строки; сборка зелёная.

**Шаг 3 — `core/include/trafficwatcher/core/Concepts.hpp` (D5).** `#ifndef __cpp_concepts` → `#error "tw_core requires a C++20 compiler"` (форма — как `qcompilerdetection.h:1317–1322`); `concept ScopedEnum = std::is_enum_v<E> && !std::is_convertible_v<E, int>;`; `toIndex` с `requires` отдельной строкой; `acceptsAsMode` с `if constexpr`; имена — только из домена (`Mode`, `Phase`), никаких `Foo`/`Bar`. Проверка: проба `int main(){ trafficwatcher::core::toIndex(3.5); }` через `g++ -fsyntax-only -std=c++20 -I core/include` → в выводе есть `constraints not satisfied`.

**Шаг 4 — `core/CMakeLists.txt` (D2).** `target_compile_features(tw_core PUBLIC cxx_std_20)` + `set_target_properties(tw_core PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON CXX_EXTENSIONS OFF)`; `target_compile_features(tw_app …)` **не** добавляется — требование приходит по `PUBLIC`-цепочке, и это проверка урока 01. Проверка: `cmake --preset win-ninja-debug; cmake --build --preset win-ninja-debug`, затем команда D1 → одна строка `-std=c++20`.

**Шаг 5 — `ui/LightBulb.cpp` + `ui/LightBulb.h` (D6).** `Q_ENUM(Mode)` остаётся из урока 02; в `.cpp` — `#include <QtCore/QtTypeTraits>`; `modeName(Mode)` через `enumerator(indexOfEnumerator("Mode"))` + `valueToKey(qToUnderlying(m))` с веткой на `nullptr`; в заголовке — **ни одного** `std::span` в сигнатуре метода экспортируемого класса (если очень хочется — `qcompilerdetection.h:1157–1179`: inline или `template <typename = void>`-фасад). Проверка: `Select-String ui/LightBulb.cpp -Pattern "static_cast<int>"` → пусто; `-Pattern "qToUnderlying|valueToKey"` → ≥2 строки.

**Шаг 6 — `tests/tst_phase_table.cpp`, `tests/tst_mode_name.cpp` (D7).** ≥3 unit-теста: `totalTicks()`, `firstRed(nullptr, 0)` → `nullptr`, `modeName(static_cast<Mode>(7))` → `"<unknown>"`; `add_test(...)` + `set_tests_properties(... PROPERTIES LABELS "unit")` (лейбл `unit` — приёмка модуля, [`course.md`:147](../course.md#L147)); negative-файл не линкуется в `tw_app` — отдельный таргет `tw_negative_concepts`, собираемый **только** для теста. Проверка: `ctest --preset win-ninja-debug -L unit` → `100% tests passed`.

**Шаг 7 — negative control в `tests/CMakeLists.txt` (D7).** `add_test(NAME concepts_reject_double COMMAND ${CMAKE_COMMAND} --build <bindir> --target tw_negative_concepts)` + `set_tests_properties(concepts_reject_double PROPERTIES WILL_FAIL TRUE LABELS "negative")`; рядом — альтернатива из тонкости 1 цикла 3: `try_compile(<var> …)` + `if(<var>) message(FATAL_ERROR …)`. Одну форму зафиксируй в ADR (контур качества), вторую оставь задокументированной. Проверка: `ctest --preset win-ninja-debug -L negative -V` → `concepts_reject_double ... Passed`; контролируемая поломка: убери `requires` → тест обязан упасть, иначе он ничего не проверяет.

**Шаг 8 — `docs/adr/0005-cpp20-feature-policy.md` (D8).** Таблица из DoD; обязательные строки, все — с замером этого урока: designated initializers, `[[no_unique_address]]`, `std::span`, `QSpan`, concepts, `if constexpr`, ranges/`ranges::to`, `<=>`, `std::format`/`<print>`/`QString::formatted`, `std::to_underlying`/`qToUnderlying`, `std::optional`, `std::expected`, `std::source_location`, `char8_t`. Колонка «гейт» — из правила 3, «чем проверено» — команда или `файл:строка`. Проверка: `Select-String docs/adr/0005-*.md -Pattern "замер|cpp_|qcompilerdetection|qstring.h"` → ≥8 строк таблицы.

### Чего не делаем

- QML-сторону (`required property`, типизированное свойство) — модуль 4 ([`course.md`:155](../course.md#L155)).
- `std::expected`, `std::ranges::to`, `<print>` — не включаем: тулчейн не позволяет (цикл 4 тонкость 2, цикл 5 тонкость 3); вернутся в 13.2.
- Импорты модулей (`import std`) — модуль 12 (воспроизводимость) или никогда; здесь не начинаем.
- `Q_CONSTINIT` в глобальном состоянии — 6.1, когда появится реальное глобальное состояние ядра.
- clang-tidy и санитайзеры как часть DoD — модуль 10; в этом уроке `.clang-tidy` только как источник эталона.
- Замена строительных заголовков доменом — **не здесь** (урок 6.1, [`course.md`:179](../course.md#L179)).

## Блок 7. Приёмка

### Рубрика DoD

| Критерий | Зачтено | Зачтено с оговоркой | Не зачтено |
|---|---|---|---|
| **D1** | одна уникальная строка `-std=c++20`; `gnu\+\+` — пусто | строка одна, но это `-std=gnu++20` | ≥2 строк или `17` |
| **D2** | `CXX_EXTENSIONS OFF` + `CXX_STANDARD_REQUIRED ON` + keyword `PUBLIC` в графе | свойства есть, keyword `PRIVATE` | только `target_compile_features` |
| **D3–D4** | оба `static_assert` падают при контролируемой поломке (проверено командами шагов 1–2) | assert есть, но один не срабатывает на обещанной поломке | таблицы нет / assert только про сумму |
| **D5** | в диагностике есть `constraints not satisfied` **и** указание на строку концепта | `requires` есть, но без `concept`-имени в тексте отказа | `enable_if` или `static_assert` в теле |
| **D6** | `static_cast<int>` в рефлексии отсутствует, `modeName` возвращает `"<unknown>"` на `static_cast<Mode>(7)` | `qToUnderlying` есть, ветки на `nullptr` нет | `Q_PROPERTY(int …)` как в находке `10` |
| **D7** | `-L unit` и `-L negative` зелёные; negative падает при снятии `requires` (проверено) | negative проходит, но его «поломка» не проверялась | тестов нет / negative всегда «Passed» |
| **D8** | ≥8 строк таблицы, ≥3 — с текстом ошибки или `файл:строка` | таблица есть, половина строк без источника | «разрешили C++20» одной строкой |

### Self-check

**1.** Чем отличается `target_compile_features(tw_core PUBLIC cxx_std_20)` от `set_property(TARGET tw_core PROPERTY CXX_STANDARD 20)` с точки зрения гарантий?

<details><summary>Ответ</summary>

Оба в итоге добавляют флаг, но: мета-фича означает режим «at minimum … but could be greater» и **не гарантирует ни одной конкретной фичи**, а диагноз откладывается на компиляцию (`cmake-compile-features(7)`, «Requiring Language Standards»); `CXX_STANDARD` без `CXX_STANDARD_REQUIRED ON` может **деградировать** до предыдущего стандарта; `CXX_EXTENSIONS` по умолчанию `ON` → `-std=gnu++20`. Гарантию фичи даёт только feature-макрос, проверенный `-dM -E`.
</details>

**2.** Почему `#include <span>` на `-std=c++17` проходит, а `std::span<int>` — нет, и что из этого следует для гейта?

<details><summary>Ответ</summary>

Заголовки libstdc++ сами ветвятся по `__cplusplus`: в C++17-режиме `<span>` не объявляет ничего, и включение успешно (замер: код 0). Значит «заголовок есть» ≠ «фича есть»: гейт обязан быть по `__cpp_lib_span` (макросу библиотеки, который появляется только после включения — правило 4), либо по `static_assert`, либо по версии компилятора. Тот же механизм у `std::expected`: `-std=c++20` → `error: 'expected' is not a member of 'std'` при успешно открытом `<expected>`.
</details>

**3.** Тебе нужно положить `std::span<const Phase>` в метод **экспортируемого** класса `tw_core`. Что не так и как решает это Qt?

<details><summary>Ответ</summary>

Проблема — не компиляция, а линковка: у MSVC-клиента метод экспортируемого класса берётся как **символ**, а библиотека, собранная в C++17, такого символа не выпустит (`qcompilerdetection.h:1167–1170`). Qt требует: полностью inline + гейт feature-макросом (`:1158–1165`), а для методов экспортируемых классов добавляет `template <typename = void>` — `QT_POST_CXX17_API_IN_EXPORTED_CLASS` (`:1176`), он же `Q_WEAK_OVERLOAD` (`:1152`). Для курса: либо inline-хелпер в заголовке, либо `const Phase*` + размер в API, либо осознанное «мы требуем C++20 у всех потребителей» в ADR-0005 (и тогда это видно в 11.3).
</details>

### Exit ticket

- Самое непонятное после урока: `______`
- Что проверю первой командой в следующем уроке: `______`

(Заполняется после задания: по нему модуль 4 начинается с ответов, а не с догадок. Защита блока — три вопроса по [`course.md`](../course.md), раздел «Курсовые ритуалы», — отдельным прогоном.)

### История: как было в Qt5/C++17 → как стало → что это даёт

| Было (старый проект, [`legacy-description.md`](../legacy-description.md)) | Стало (урок 03) | Что это даёт |
|---|---|---|
| `CMAKE_CXX_STANDARD 17` (`:22`) без `CXX_EXTENSIONS`/`REQUIRED` | `cxx_std_20` + `CXX_STANDARD 20` + `REQUIRED ON` + `EXTENSIONS OFF`, флаг виден в JSON | режим сборки — проверяемый факт, а не намерение; деградация на старом тулчейне падает конфигурацией, а не «странными» ошибками шаблонов |
| `enum Mode{Off,On,Blink}` + `Q_PROPERTY(int mode …)` (`:26`, `:56`) | `enum class Mode : std::uint8_t` + `concept ScopedEnum` + `qToUnderlying`/`QMetaEnum::valueToKey` | `7` перестаёт быть «почти режимом»: часть отказов ловится на компиляции, остальные — на одном тесте с `"<unknown>"` |
| ручной `static_cast<int>` в сериализации и логах | слой `qToUnderlying` | ширина поля в формате данных совпадает с типом; `valueToKey(int)` против `valueToKey(quint64)` перестаёт быть лотереей |
| константы режимов разбросаны по `.cpp` | `inline constexpr std::array<Phase, N>` + два `static_assert` | таблица фаз — один артефакт, инварианты проверяются компилятором до первого запуска |

## Блок 8. Справка и «дальше»

### Сводка урока: конструкции

| Конструкция | Что это | Ключевые аргументы / формы | Где применим | Где неприменим | Best practice + следствие | Тонкость | Чем проверить |
|---|---|---|---|---|---|---|---|
| `target_compile_features` | команда CMake (требование к фиче) | `<target> {INTERFACE\|PUBLIC\|PRIVATE} <feature>...`, повторные вызовы **добавляют** | `tw_core`, `tw_ui` | не заменяет поиск библиотек (`find_package`) и не включает `AUTOMOC` | `PUBLIC` для требований домена, `PRIVATE` — «только моя реализация»; иначе потребитель молча в другом режиме | `cxx_std_20` ≠ гарантия фичи: диагноз отложен до компиляции | `cmake --help-command target_compile_features`; `cmake --help-manual cmake-compile-features`; флаг в JSON |
| `CXX_STANDARD` / `CXX_STANDARD_REQUIRED` / `CXX_EXTENSIONS` | свойства таргета (int / boolean / boolean) | `20`; `ON/OFF`; `ON/OFF` (по умолчанию **`ON`**) | там, где нужен **точный** режим | глобальные `CMAKE_CXX_*`-переменные вместо свойств: течёт в чужие таргеты | `REQUIRED ON` + `EXTENSIONS OFF` в ядре; иначе «decay» к предыдущему стандарту и `-std=gnu++20` | `CMAKE_CXX_EXTENSIONS_DEFAULT` в `--help-variable` **не определена**, хотя текст свойства на неё ссылается | `cmake --help-property CXX_EXTENSIONS`; `Select-String compile_commands.json -Pattern "gnu\+\+"` |
| `__cplusplus`, `__cpp_*`, `__cpp_lib_*`, `_GLIBCXX_RELEASE` | макросы гейта (язык / библиотека) | `201703L`, `202002L`, `201707L` (designated init), `202211L` (`__cpp_lib_expected`) | preprocessing в заголовках и `#error`-гейты | версия компилятора как единственный гейт: правдоподобные числа врут (GCC 8.1 `-std=c++2a`) | язык — по предопределённым `__cpp_*`, библиотека — по `__cpp_lib_*` **после** `#include <version>` | GCC 8.1: `__cplusplus 201709L`, designated init принимает, `concept` нет; GCC 13 `-std=c++23` → `202100L` | `g++ -dM -E -std=c++20 -x c++ -`; `#include <version>` |
| `enum class E : std::uint8_t` | scoped enum с явным underlying type | `enum class` + `: type` + `= значение` | границы домена, сериализация, `Q_ENUM` | как замена `int`-свойства QML без тестов: внедиапазонный cast легален | явный underlying type всегда, если тип участвует в формате данных | без `: std::uint8_t` `sizeof(E)==4`, и `static_assert(sizeof(Mode)==1)` — единственный страж | `static_assert(sizeof(Mode) == 1)` (замер: без типа — проходит на 4) |
| designated initializers | инициализация агрегата по именам полей | `T{.a=1,.b=2}`, порядок **обязан** совпадать с объявлением | таблицы (`kPhases`), конфигурации | агрегаты со своим конструктором; структуры с базовыми классами | только агрегаты без своего конструктора; иначе форма недоступна | в C++17-режиме GCC принимает их молча (код 0), `-Wpedantic` — warning, макрос не определён | `g++ -std=c++17 -Wall -Wextra -Wpedantic` + `-dM -E` |
| `constexpr` / `consteval` | вычисление на компиляции / **только** на компиляции | `constexpr auto f()`, `consteval std::size_t g()` | инварианты таблиц, валидаторы | рантайм-валидация, если значение приходит из файла (13.2 — там нужен тест) | `consteval` для валидаторов, `constexpr` — для того, что зовётся и в рантайме | динамическая память в const-выражении — только полностью освобождённая (`…because allocated storage has not been deallocated`) | `static_assert(f()==…)`; сборка с изменённым `ticks = 0` |
| `[[no_unique_address]]` | атрибут пустого члена (C++20) | поле класса; `__has_cpp_attribute(no_unique_address)` → `201803L` | упаковщики policy/hook | ABI-чувствительные типы при смешанных тулчейнах | только при едином тулчейне, решение — в ADR-0005 | меняет раскладку и в C++17-режиме, **без диагностики** (замер `A=12 B=8`); в публичных заголовках Qt 6.10.2 — 0 употреблений | `printf("%zu", sizeof(T))` в двух `-std=` |
| `concept` / `requires` | ограничение шаблона | `template<typename E> concept C = …;`, `template<typename E> requires C<E>`, `template<C T>` | границы хелперов домена | публичные заголовки библиотеки до решения 11.3 (Qt своих не объяляет — замер) | имя концепта = часть диагностики; `requires` отдельной строкой при 2+ условиях (форма Qt) | диагностика становится **длиннее** (16 против 13 строк), но указывает на строку концепта | проба из цикла 3 (`-fsyntax-only`) |
| `std::span` / `QSpan` | view на непрерывную память | `std::span<const T>`, `span(ptr, n)`, `subspan`, `first<N>` | `core` — `std::span`; `ui` — `QSpan` | поле класса и возврат из функции без владельца в сигнатуре (замеров-диагностик нет) | параметр-тип, никогда не поле-владелец | `QSpan::size_type` = `qsizetype`, `difference_type` = `qptrdiff` (`qspan.h:336–337`); `#include <span>` в C++17 проходит, типа не даёт | `static_assert(std::is_same_v<decltype(s.size()), qsizetype>)`; grep на `span<…> f()` |
| `std::views::*` / `std::ranges::*` | ленивые представления и точки вызова | `r \| views::filter(p)`, `ranges::sort(v)`, `ranges::to` (**нет** на GCC 13) | алгоритмы над таблицей фаз | возврат view над временным контейнером; `ranges::to` до смены тулчейна | `<ranges>` вместо пар итераторов; выбор не по скорости (замер: 424 мс против 373 мс на 1e6 int) | `__cpp_lib_ranges_to_container` не определён ни в C++20, ни в C++23 этого тулчейна | `-std=c++17` → `error: 'std::views' has not been declared`; прогон `bsort`/`branges` |
| `operator<=>` / `Qt::compareThreeWay` | трёхстороннее сравнение | `= default`, `std::{strong,weak,partial}_ordering`; Qt-эквиваленты | порядок фаз, сравнение состояний | поля `double` под `strong_ordering` — `partial_ordering` не конвертируется | проси `partial_ordering` там, где есть `double`; `strong_ordering` — только для точных типов | `std::strong_ordering … = default` над `double` → функция **удалена**, ошибка на месте вызова; у `QString` `<=>` только в C++20-режиме | `g++ -std=c++20 -fsyntax-only` (замер текста ошибки) |
| `std::format` / `<print>` / `QString::formatted` | форматирование | `std::format("{}-{}",…)`, `std::print` (**нет** на GCC 13) | логи, сообщения, `modeName` | `QString::formatted` в Qt 6.10.2 — нет метода | для Qt-строк — `arg`/`asprintf`; `std::format` → в `QString` через `fromUtf8` | `<print>` нет ни в C++20, ни в C++23 (замер сборки); `__cpp_lib_format 202106L` | `Select-String qstring.h -Pattern "formatted"`; `#include <print>` |
| `std::to_underlying` / `qToUnderlying` | значение enum как целое | `std::to_underlying(e)` (C++23), `qToUnderlying(e)` (Qt, C++17+) | рефлексия `QMetaEnum`, сериализация | `std::to_underlying` в коде, который обязан собираться на C++20 | в Qt-коде — `qToUnderlying`, он версионно-нейтрален | под C++20: `note: 'std::to_underlying' is only available from C++23 onwards` | `static_assert(std::is_same_v<decltype(qToUnderlying(M::A)), unsigned char>)` |
| `std::optional` / `std::expected` | «значение или ничего» / «значение или ошибка» | `std::optional<T>`, `std::expected<T,E>` (GCC 13: только `-std=c++23`) | `keyToValue64`, ошибки парсинга (13.2) | в API одного класса вместе с `bool *ok`/`nullptr` — два поколения в одном контракте | одно поколение API; `expected` — только с гейтом `__cpp_lib_expected` | Qt сам идёт через `optional` (`qmetaobject.h:280–287`); гейт libstdc++ — `__cplusplus > 202002L` (`<expected>:34`) | `Select-String qmetaobject.h -Pattern "std::optional"`; `-dM -E` с `#include <version>` |
| `std::source_location` | место вызова как значение по умолчанию | `std::source_location l = std::source_location::current()` | диагностика, `QPropertyBindingSourceLocation` | в сигнатуре метода экспортируемого класса (ABI, правило 2) | свой `struct Location` в API, чтобы не тащить C++20-тип в ABI | Qt гейтит тремя условиями (`qproperty.h:17–19`) и обходит ошибку MSVC C7595 фасадом (`:22–25`); `QT_MESSAGELOGCONTEXT` (`qlogging.h:150–158`) | проба цикла 5 (вывод `tick @ <stdin>:4 in int main()`) |
| `char8_t` | отдельный тип для UTF-8 literal | `u8"…"`, `__cpp_char8_t 202207L` | границы кодировок, `QUtf8StringView` | API без гейта: набор перегрузок зависит от режима | не выноси `char8_t` в API без гейта | перегрузки Qt (`QString(const char8_t*)`, `qstring.h:217–219`) видны только в C++20 → «parse error» вместо «нет метода» | `static_assert(std::is_constructible_v<QString, const char8_t*>)` в двух `-std=` |
| `try_compile` / `WILL_FAIL` | проверка «не компилируется» | `try_compile(<var> PROJECT … SOURCE_DIR … [TARGET …])`; `PROPERTIES WILL_FAIL TRUE` | negative-тесты концептов | `try_compile` внутри одного таргета без `PROJECT`-формы (читай `--help-command`) | `try_compile` даёт TRUE/FALSE по результату сборки; `WILL_FAIL` инвертирует **любой** ненулевой код | `WILL_FAIL` зачитает как успех и отсутствие компилятора — ложь зелёного теста | `cmake --help-command try_compile`; `ctest --help` |

### Глоссарий урока

- **мета-фича** — `cxx_std_20`: требование «не ниже», без гарантии конкретной фичи (CMake).
- **feature-test макрос** — `__cpp_*` (язык, предопределён) и `__cpp_lib_*` (библиотека, после включения).
- **decay** — молчаливое понижение стандарта, если `CXX_STANDARD_REQUIRED` не `ON`.
- **view** — тип, описывающий чужую память (`std::span`, `QSpan`, `QStringView`); не владеет, висячесть не диагностирует.
- **post-C++17 API** — формулировка Qt: API с типами/фичами после C++17 требует inline + гейта (`qcompilerdetection.h:1157–1179`).
- **preview-значение `__cplusplus`** — `202100L` на GCC 13 в `-std=c++23`: проверка `>= 202302L` там лжёт.

### Диагностика: симптом → настоящая причина → где чинить

| Симптом | Настоящая причина | Где чинить |
|---|---|---|
| `'concept' does not name a type; did you mean 'constexpr'?` | не тот режим (или GCC 8.1 без `-fconcepts`) | цикл 1 (проверка флага), цикл 3 (7) |
| `no matching function for call to 'toIndex(double)'` + `constraints not satisfied` | концепт сработал как надо | читать последнюю `note:` — она указывает на определение концепта (цикл 3) |
| `error: 'span' in namespace 'std' does not name a template type` | TU собирается в C++17, `#include <span>` при этом прошёл | цикл 1 D2, цикл 4 (1) |
| `is not a constant expression because allocated storage has not been deallocated` | compile-time таблица на `std::vector`/`new` | цикл 2 тонкость 1 → `std::array` |
| сборка зелёная, а designated init «вне стандарта» работает | GCC принимает расширение молча в C++17 | цикл 1 ловушка; гейт по `__cpp_designated_initializers` |
| `use of deleted function 'std::strong_ordering T::operator<=>…'` | поле `double` → `partial_ordering`, конверсии нет | сводка, строка `operator<=>`; проси `partial_ordering` |
| `#error "Qt requires a C++17 compiler, and a suitable value for __cplusplus…"` (MSVC) | не задан `/Zc:__cplusplus` | цикл 1 эталон; пресет (урок 12.1) — **проверь на своей MSVC-сборке** |
| линкуется здесь, CI падает `unresolved external …` | метод экспортируемого класса с C++20-типом собран в другом режиме | цикл 5 (4): inline или `template <typename = void>` |

### Подмеченные ошибки в текущем состоянии репозитории

1. `CMakeLists.txt:3–4` — только `cmake_minimum_required` и `project(... LANGUAGES CXX)`: **ни одного таргета**; уроки 01–02 не закрыты, поэтому все prerequisites карточки помечены «ожидаемое» (блок 4, [`methodology.md`](../methodology.md)).
2. `CMakeLists.txt:1–2` — комментарий про «version … latest»; установленный CMake — `4.3.2` (замер `cmake --version`), и `cmake_minimum_required(VERSION 4.3.2)` фиксирует **минимум**, а не то, чем собирают: расхождение между «latest», «минимум» и фактом — будущий ADR-0021 (воспроизводимость, 12.1).
3. [`docs/course.md`:143](../course.md#L143) (строка `3.3`) обещает `std::to_underlying` и `QString::formatted`: первое — C++23, второго нет в Qt 6.10.2 (замеры). Правка плана — за владельцем (матрица `AGENTS.md` §1.1).
4. [`docs/course.md`:144](../course.md#L144) (строка `3.4`) обещает `std::expected` — на этом тулчейне только `-std=c++23` (замер), а `std::ranges::to` (строка `3.3`) нет и там: нужен GCC 14.
5. `docs/lessons/02-qt6-in-cmake.md:109, 189, 790, 791` — ссылки `qt-std-project-setup.html` и `cmake-qt-policies.html` отдавали 404 (проверка 26.11.2026); рабочие формы — [`qt-standard-project-setup.html`](https://doc.qt.io/qt-6/qt-standard-project-setup.html) и [`qt-cmake-policies.html`](https://doc.qt.io/qt-6/qt-cmake-policies.html), **исправлено в уроке 02** (матрица §1.1 разрешает правку `docs/lessons/*`).
6. [`docs/methodology.md` §6](../methodology.md#L304) — до правки 26.11.2026 первой строкой статуса стояло «Ни одного написанного урока пока нет: `lessons/` и `answers/` пустуют», хотя уроки `00`–`02` и их файлы ответов были в репозитории (замер `Get-ChildItem docs/lessons`, `docs/answers`): входящий в курс читал это как «материала нет». Раздел обновлён (матрица §1.1 даёт ассистенту `methodology.md` полным текстом): статусы — «написан, не закрыт», потому что слоты `> Ответ:` во всех четырёх файлах пусты. Проверка живости статуса: `Select-String docs/methodology.md -Pattern "не закрыт" -Encoding UTF8` → ≥8 строк.

### Инвентарь окружения (замер 26.11.2026)

| Компонент | Значение | Чем измерено |
|---|---|---|
| CMake | `cmake version 4.3.2` | `cmake --version \| Select-Object -First 1` |
| Компилятор курса | `g++.exe (GCC) 13.1.0`, `C:\Program Files\JetBrains\CLion 2026.1.1\bin\mingw\bin` | `g++ --version`; `_GLIBCXX_RELEASE 13` (`-dM -E` после `<version>`) |
| Второй компилятор | `g++.exe (x86_64-posix-seh-rev0, Built by MinGW-W64 project) 8.1.0`, `C:\Qt\Tools\mingw810_64\bin` | `g++ --version`; `-std=c++2a` → `__cplusplus 201709L` |
| Qt 6 | `QMake version 3.1 / Using Qt version 6.10.2`, `C:\Qt6.10.2-msvc2022\qt6.10.2-x64-msvc2022\Qt\6.10.2\msvc2022_64` | `qmake -v`; MSVC-сборка → `-fsyntax-only` (замер), линковка под MinGW невозможна |
| Qt 5 | `C:\Qt\5.15.2`, документация `C:\Qt\Docs\Qt-5.15.2` | `Get-ChildItem C:\Qt` |
| MSVC | **не установлен** | `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe` отсутствует |
| `<print>`, `QString::formatted` | нет ни в C++20, ни в C++23; метода `formatted` в `QString` нет | `fatal error: print: No such file or directory`; `Select-String qstring.h -Pattern "formatted"` |
| Свойства Qt-заголовков | `requires ` — 33 строки, `std::span` — 7, `std::three_way_comparable` — 2, `[[no_unique_address]]` — 0, `consteval` — 1, свои `concept ` — 0 | `Select-String -Path "<Qt>\include\QtCore\*.h"` |
| Qt Creator | `C:\Qt\Tools\QtCreator-7.0.0` (не бандл 6.10) | `Get-ChildItem C:\Qt\Tools` |

### Что читать

- **Разбор чужого кода (обязательный):** Qt `src/corelib/global/qcompilerdetection.h:1157–1179` — комментарий про post-C++17 API и `QT_POST_CXX17_API_IN_EXPORTED_CLASS`; прочти подряд `:1317–1337` (версия компилятора, `#error`, `static_assert` про `/permissive-`) и `:1473–1484` (LWG 3346, P0846) — весь аппарат правила 3 в 30 строках. Локально: `C:\Qt6.10.2-…\include\QtCore\qcompilerdetection.h`; upstream — [qtbase `6.10`](https://github.com/qt/qtbase/blob/6.10/src/corelib/global/qcompilerdetection.h).
- **Разбор чужого кода №2:** `qttypetraits.h:27–32` (`// like std::to_underlying`) и `:262–272` (`__cpp_lib_three_way_comparison && __cpp_lib_concepts` → `std::three_way_comparable`) — как выглядит фича, которой ещё нет в стандартной библиотеке проекта.
- [C++20 Overview — Qt 6.10](https://doc.qt.io/qt-6.10/cpp20-overview.html) — официальная позиция: chrono, `QSpan`, `operator<=>`, `Q_CONSTINIT`/`Q_NODISCARD_*`.
- [QSpan](https://doc.qt.io/qt-6/qspan.html), [QtTypeTraits](https://doc.qt.io/qt-6/qttypetraits.html), [QMetaEnum](https://doc.qt.io/qt-6/qmetaenum.html), [QStringView](https://doc.qt.io/qt-6/qstringview.html) — страницы классов из сводки.
- [C++ feature-test macros](https://en.cppreference.com/w/cpp/feature_test) и [SD-6 (SG10) Feature-test Recommendations](https://isocpp.org/std/standing-documents/sd-6-sg10-feature-test-recommendations) — имена и значения макросов; [CppCoreGuidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines) — I.9, I.10, Enum.3, SL.con.3, P.10.
- [MSVC `/std`](https://learn.microsoft.com/en-us/cpp/build/reference/std-specify-language-standard-version) — список режимов и сноска про `/Zc:__cplusplus` (**проверь на своей MSVC-сборке**: здесь MSVC не установлен).
- [`.clang-tidy` Qt Creator](https://raw.githubusercontent.com/qt-creator/qt-creator/master/.clang-tidy) — включённые проверки и `modernize-loop-convert.UseCxx20ReverseRanges: false`.

### Дальше

- Следующий урок — модуль 4, [`course.md`:150–161](../course.md#L150): `required property`, типизированное свойство `Mode` (цикл 5) вместо `int` (находка `10`), тема и `QQuickStyle` — 4.4.
- Созрели ADR: **0005** (этот урок, черновик — шаг 8), **0006** (тип свойства в QML, модуль 4), **0023** (ломает ли `std::span` в API `tw_core` стабильность экспорта — вопрос для 11.3, реестр в [`adr/readme.md`](../adr/readme.md)).
- В [`docs/answers/03-cpp20-in-qt-code.md`](../answers/03-cpp20-in-qt-code.md) — шесть вопросов слоя (а), три переноса на свой код (б) и три интервальных (уроки 00–02).

### Итог урока

Режим сборки стал фактом, который проверяется одной командой; инварианты таблицы фаз — проверкой компилятора; граница enum — концептом, чей отказ читается как спецификация; view стоит там, где виден владелец, потому что компилятор висячесть не ловит; а ADR-0005 заполнен числами, текстами ошибок и номерами строк Qt, а не предпочтениями. Дальше — QML (модуль 4): типизированное свойство требует, чтобы `Mode` уже был типом, а не числом.
