# Урок 02 — Qt 6 в CMake: свой QML-модуль без `qmlRegisterType`

## Блок 1. Карточка

| Поле | Значение |
|---|---|
| Модуль / урок | **Модуль 2**, строки плана `2.1`–`2.3` ([`docs/course.md`](../course.md), «Модуль 2 — Qt 6 в CMake», строка 121). Обозначение `2.M` = строка плана; физически это цикл `M` этого файла. Циклы 4–5 берутся из строки «Тест-приёмка» модуля 2 ([`:130`](../course.md#L130)) |
| Веха | **M1** (паритет): после урока `tw_app` открывает окно из собственного QML-модуля, а `ctest -L smoke` ловит это и на headless-машине |
| Артефакт на выходе | те же три команды, что в уроке 01: `cmake --preset win-ninja-debug` → `cmake --build --preset win-ninja-debug` → `ctest --preset win-ninja-debug`; на выходе — таргет `tw_ui` из `qt_add_qml_module`, запускаемый `tw_app.exe` с окном, `≥2` теста под лейблом `smoke` (один из них — «engine загрузил модуль»), зелёный `all_qmllint` |
| На входе (prerequisites) | **ожидаемое**: урок [01](01-cmake-target-graph.md) не закрыт (замер 25.11.2026 — таргетов в репозитории ноль, [`CMakeLists.txt`](../../CMakeLists.txt) из четырёх строк). Нужно: ADR-0001 с Qt-китом **6.10.x под выбранный компилятор**, два таргета (`tw_core`, `tw_app`), один зелёный `smoke`-тест, пресеты из урока 01, зарезервированный `ui/` (ADR-0004). На этой машине Qt 6.10.2 на момент замера не установлен — в `C:\Qt` только `5.15.2` (замер 25.11.2026), все проверки циклов делаешь ты и фиксируешь в инвентаре блока 8 |
| Порождаемые ADR | **0002** (URI дописывает решение об именах — [`adr/readme.md`](../adr/readme.md), [`readme.md:149`](../readme.md#L149)); подтверждения 0001 (кит) и 0004 (`ui/` в layout) |
| Эталон урока | qt-creator, Kdenlive (+ ECM), официальный порт-гид Qt, KDAB — свод правил в преамбуле блока 5, ссылки в блоке 8 |
| Вопросы и следующий урок | [`docs/answers/02-qt6-in-cmake.md`](../answers/02-qt6-in-cmake.md); дальше — модуль 3 «C++20 в Qt-коде» ([`course.md`:137](../course.md#L137)) |

## Блок 2. Цели и доказательства

После урока ты умеешь:

| Цель | Где отрабатывается | Чем доказывается |
|---|---|---|
| **Превратить Qt6 в узел графа таргетов**: `find_package` с компонентом, версией и REQUIRED; не путать список компонентов с списком линковки | цикл 1, разбор (1)–(9) | `cmake --graphviz`: ребро `tw_ui → Qt6::Quick`; `Select-String build/win-ninja-debug/CMakeCache.txt -Pattern "^Qt6_VERSION:"` → `6.10.x` |
| **Объяснить, что делает и чего НЕ делает `qt_standard_project_setup()`**, и найти, чьё значение переменной перекрывает его | цикл 1, разбор (4)–(5), тонкость 1 | `cmake --help-command qt_standard_project_setup` против текста урока; ответ на вопрос A1 |
| **Спроектировать QML-модуль командой `qt_add_qml_module`** так, чтобы каталог исходников соответствовал target path, а `qmldir`/`qmltyperegistrar`/`qmlcachegen` никто не вызывал руками | цикл 2, разбор (1)–(9) | `Test-Path build/win-ninja-debug/<target-path>/qmldir` → `True`; в `ui/` нет ни `qml.qrc`, ни ручного `qmldir` |
| **Регистрировать C++-типы в QML макросами** и назвать цену каждого срыва условий (`QML_ELEMENT` требует заголовок внутри таргета модуля и `#include <QtQml/qqmlregistration.h>`) | цикл 3, разбор (1)–(8) | вопрос A4; `Select-String build/…/twui_qmlreg.cpp -Pattern "LightBulb"` (имя генерируемого файла — проверь свой) |
| **Построить smoke-тест загрузки модуля headless** через CTest-свойства `ENVIRONMENT`/`LABELS`/`TIMEOUT`, с negative control на `WILL_FAIL` | цикл 4, разбор (1)–(8) | вопрос A5; `ctest -L smoke` → `Passed` на `QT_QPA_PLATFORM=offscreen`; `ctest -L negative` → заведомо «упавший» тест зелёный |
| **Отличать в документации Qt то, что реализовано, от того, чего нет**: несуществующие `QTP0081` и `qmlformat --check` | цикл 2 «Ловушка», цикл 5 «Ловушка» | вопрос A6; `Select-String <официальная страница политик> -Pattern QTP0081` → 0 совпадений; `qmllint --help`/`qmlformat --help` на своей сборке |

**Как читать урок.** Блоки 1–2 и 7 — первый проход; дальше циклы строго по порядку: Qt приходит в
граф (цикл 1) → появляется модуль (2) → в него регистрируются классы (3) → загрузка доказывается
тестом (4) → статический контроль (5). Внутри цикла порядок фиксирован: **механика → почему именно
так → что будет, если нарушить → тонкости → мини-практика и чекпойнт**, в конце — «Эталон цикла».
Ссылки на upstream — ветки `master`/`develop` на 25.11.2026, номера строк там смещаются. Все проверки,
где нужна сборка, — чекпойнты для твоей машины: у ассистента Qt 6 не установлен, и цифры «замерено»
в этом уроке относятся только к документационным фактам.

### Мини-практика на 5 минут

Два замера, которые решают, готов ли ты к уроку:

```powershell
Get-ChildItem C:\Qt -Directory | Select-Object -ExpandProperty Name
cmake --help-command find_package | Select-String -Pattern "COMPONENTS" | Select-Object -First 1
```

→ в первом списке обязан быть каталог вида `6.10.x` (на этой машине на 25.11.2026 — только `5.15.2`,
`Tools`, `Docs`, `Examples`: блокер B2 урока 00 не закрыт, и цикл 1 упирается в него). Во втором —
формулировка `COMPONENTS <component>...`: с неё начинается разбор цикла 1. Если кита нет: ставь
6.10.x под компилятор из ADR-0001 — `find_package(Qt6)` ищет не «Qt вообще», а конкретный kit.

## Блок 3. Проблема урока

Урок 01 оставил приложение, в котором нет ничего, что видел бы пользователь: `app/src/main.cpp`
печатает что-то в консоль, `ui/` — пустой резерв ADR-0004. Соблазн закрыть это одной папкой —
перенести структуру старого проекта ([`legacy-description.md:27`](../legacy-description.md#L27)):
`QGuiApplication` + четыре `qmlRegisterType("TrafficLightUi", 1, 0, …)` в `main.cpp`, ручной `qmldir`
([`:30`](../legacy-description.md#L30)) и `.qrc` ([`:28`](../legacy-description.md#L28)). Такой код соберётся и будет работать — и ровно поэтому он опасен: он не проверяет себя, а его точки синхронизации позже станут API. Пять мест, где это болит, закрыты в эталоне механически:

| Дефект «как в Qt5» | Чем закрыт в Qt6/эталоном | Какой цикл |
|---|---|---|
| URI и версия модуля продублированы в каждой строке `qmlRegisterType`; опечатка живёт до runtime | `qt_add_qml_module(URI …)`: имя, версия, `qmldir`, `qmltypes` и регистрация генерятся на сборке из одного места ([`legacy-description.md:49`](../legacy-description.md#L49)) | 2, 3 |
| `set(CMAKE_AUTOMOC/AUTORCC/AUTOUIC ON)` руками в `cmake/QtSetup.cmake` ([`:20`](../legacy-description.md#L20)) | `qt_standard_project_setup()` — одна строка сразу после `find_package`, до определения таргетов | 1 |
| QML-файлы лежат в `.qrc`, путь в нём разошёлся с `qmldir` — silently | `QML_FILES`: qmlcachegen, ресурсы и структура каталога выводятся из URI | 2 |
| UI невозможно протестировать без окна: «Доработка тесты (не работают)» ([`:31`](../legacy-description.md#L31), находка `11` в таблице) | smoke-тест с `ENVIRONMENT=QT_QPA_PLATFORM=offscreen` и negative control | 4 |
| qmllint/qmlformat «когда-нибудь в CI» | `qt_add_qml_module` сам создаёт цели `<target>_qmllint` и `all_qmllint`; остаётся подцепить их в CTest | 5 |

Плюс дефект самого плана, по которому идёт урок: в строке [`2.2`](../course.md#L126) названа политика
`QTP0081`, которой **не существует** (реестр Qt — `QTP0001`–`QTP0008`), а в строке приёмки
[`course.md:130`](../course.md#L130) — флаг `qmlformat --check`, которого нет у инструмента. Оба
разобраны в «Ловушках» циклов 2 и 5; правка плана — за владельцем. К концу урока: `tw_ui` —
полноценный QML-модуль с URI из ADR-0002; `main.cpp` не знает слова `qmlRegisterType`;
`ctest -L smoke` зелёный на headless; `all_qmllint` — часть сборки.

## Блок 4. Приложение: вход → выход

| | Состояние |
|---|---|
| **Вход** (ожидаемое — урок 01 не закрыт, блок 1) | собираются `tw_core` (+ `ALIAS tw::core`) и `tw_app` из пресета `win-ninja-debug`; один тест `core/mode/smoke` под `LABELS smoke` проходит; `BUILD_TESTING` — рубильник; `ui/` зарезервирован каталогом; Qt в графе нет вообще |
| **На выходе** | `ui/` (таргет `tw_ui` из `qt_add_qml_module` + `LightBulb` с `QML_ELEMENT` + `Main.qml` с `ApplicationWindow`), `tw_app` линкует `tw_ui` и грузит модуль через `loadFromModule`, `tests/` — `tw_ui_smoke` (offscreen) и negative control, `cmake/TwQmlLint.cmake` или эквивалент — qmllint/qmlformat под CTest; в `deps.dot` — рёбра `tw_app → tw_ui → Qt6::Quick`; ADR-0002 с выбранным URI |
| **Следующий урок открывается** | с окном, чей корневой компонент загружен из собственного модуля, и с рабочей регистрацией C++-типов: модуль 3 («C++20 в Qt-коде») меняет содержимое этих классов, не трогая механику 2.2–2.3; `Qt6::Test` уже найден — модуль 8 расширяет набор тестов, а не инфраструктуру |

**Строительный код (срок жизни указан).** `ui/LightBulb.h` — настоящий класс домена из старого проекта
([`legacy-description.md:30`](../legacy-description.md#L30)), остаётся до конца курса. `ui/Main.qml` на выходе урока — трёхстрочная заглушка (`ApplicationWindow` + один `LightBulb`): интерфейс полностью пересобирается **уроком 4.1–4.2** ([`course.md`:150–155](../course.md#L150)), пункт его задания — удалить заглушечные биндинги. Если план модуля 2 принимает `Main.qml` без `required property` — это осознанный долг, а не финальная форма.

### Таблица усложнения: конструкции урока 01 меняются здесь

| Конструкция | Появилась | Как усложняется здесь |
|---|---|---|
| `ALIAS` в namespace `tw::` | урок 01, цикл 1 (7) | второй namespaced таргет: `tw::ui` рядом с `tw_ui`; и вторая сторона alias-правила — **plugin-таргет `tw_uiplugin` alias-а не имеет**, а в эталоне его линкуют явно наравне с backing ([kdenlive `src/CMakeLists.txt`](https://invent.kde.org/video/kdenlive/-/blob/master/src/CMakeLists.txt)); вопрос «что линкует `tw_app`: `tw::ui`, `tw_uiplugin`, оба» становится вопросом поведения, а не стиля |
| `PRIVATE`/`PUBLIC` — направление требования | урок 01, тонкость 1 | требование `Qt6::Quick`: в `tw_ui` — `PUBLIC`, потому что заголовки модуля упоминают `QQuickItem` (следствие ровно как формулировал урок 01: «`PRIVATE` здесь значит „модуль 2 не соберётся“» — теперь это проверяемое утверждение) |
| `$env{}` и `CMakeUserPresets.json` | урок 01, цикл 2 (7) | тот же приём везёт `CMAKE_PREFIX_PATH` к Qt-киту: машинный путь живёт в игнорируемом юзер-пресете, `find_package(Qt6)` находит кит, и в git не попадает `D:/Qt/…` из старого `cmake/QtSetup.cmake` ([`legacy-description.md:47`](../legacy-description.md#L47)) |
| `add_test(NAME …)` + `LABELS smoke` | урок 01, цикл 5 | фильтр `-L smoke` начинает ловить тесты двух природ (console и QML); появляются свойства `ENVIRONMENT` (offscreen) и `WILL_FAIL` (negative control) — из тех же `ctest --help-property-list` |
| `cmake_minimum_required(...<policy_max>)` как поколение политик | урок 01, разбор (1) | у Qt — своё поколение: `qt_standard_project_setup(REQUIRES 6.10)` и `qt_policy(SET QTP0001 NEW)` включают не `CMP…`, а `QTP…`; `QT_KNOWN_POLICY_QTP0001` — тот же приём проверки существования, что `if(POLICY CMP…)`. Проверка: `cmake --help-variable QT_KNOWN_POLICY_QTP0001` не печатает ничего — это переменная, а не справка: смотри `qt_policy` и страницу политик Qt |
| `CMAKE_EXPORT_COMPILE_COMMANDS` из `base`-пресета | урок 01, тонкость 3 | тот же файл (`compile_commands.json`) становится входом `qmllint --project` (цикл 5): на VS-пресете, где переменная игнорируется, lint-тест обязан отсутствовать или падать — иначе CI «зелёный» без проверки |

## Блок 5. Практикум

Пять циклов = строки плана `2.1`–`2.3` плюс два пункта приёмки модуля. Порядок обязан этому:
без найденного Qt6 (цикл 1) не существует команды цикла 2; без модуля нечего регистрировать (цикл 3);
без загрузки нечего тестировать (4); без тестов lint — мода (5). Правка в цикле 1 видна в цикле 4
сразу: кит не под тот компилятор — `QTP`-политики ещё живы, а линковка уже нет.

### Свод эталонных правил

Шесть правил, снятых с изученных файлов 25.11.2026 (ссылки — блок 8):

| # | Правило эталона | Где в уроке | Чем проверить |
|---|---|---|---|
| 1 | `find_package(Qt6 <мин. версия> COMPONENTS … REQUIRED)` — версия и компоненты в одном вызове, отсутствие — ошибка конфигурации | цикл 1 (1)–(3) | [qt-creator `CMakeLists.txt`](https://github.com/qt-creator/qt-creator/blob/master/CMakeLists.txt) |
| 2 | `qt_standard_project_setup()` — сразу после `find_package`, до таргетов; `REQUIRES` = baseline ADR-0001 | цикл 1 (4) | [страница команды](https://doc.qt.io/qt-6/qt-std-project-setup.html) — «usually called right after the first call to find_package() … before any targets are defined» |
| 3 | Опциональные и приватные компоненты — отдельным условным `find_package`, не общим списком | цикл 1 (8) | qt-creator: `if(Qt6_VERSION VERSION_GREATER_EQUAL 6.9.0) … OPTIONAL_COMPONENTS … QUIET` |
| 4 | Один `qt_add_qml_module` на модуль, каталоги = сегменты URI, списки файлов явные | цикл 2 | [port-гид](https://doc.qt.io/qt-6/qt6-port-to-qt-add-qml-module.html); kdenlive `ecm_add_qml_module` |
| 5 | Тип публикуется макросом у объявления, `main.cpp` не регистрирует ничего | цикл 3 | [define-types page](https://doc.qt.io/qt-6/qqmlregistration-definetypes.html) |
| 6 | Статический контроль QML — цели, созданные самой системой сборки модуля, а не самописный список файлов | цикл 5 | `<target>_qmllint` / `all_qmllint`: [qt_add_qml_module page](https://doc.qt.io/qt-6/qt-add-qml-module.html) |

### Цикл 1 — Qt6 как узел графа (план 2.1; ≤25 минут)

**1. Механика: разбор (1)–(9).** Минимальная правка корневой `CMakeLists.txt` урока 01.

```cmake
# ── CMakeLists.txt (фрагмент; всё остальное — как в уроке 01)
find_package(Qt6 6.10 REQUIRED COMPONENTS Quick QuickControls2 Test)   # (1) (2) (3)
qt_standard_project_setup(REQUIRES 6.10)                               # (4)
qt_policy(SET QTP0001 NEW)                                             # (5)

add_subdirectory(core)
add_subdirectory(ui)          # (6)
add_subdirectory(app)
```

```cmake
# ── ui/CMakeLists.txt (фрагмент цикла 2; линковка — здесь)
target_link_libraries(tw_ui PUBLIC tw::core Qt6::Quick)                # (7)
```

Что делает каждый пункт:

1. **`find_package(Qt6 … REQUIRED)`** — ищет `Qt6Config.cmake` в `CMAKE_PREFIX_PATH` (кит
   целиком: `C:/Qt/6.10.x/msvc2019_64`), `Qt6_DIR` или `QTDIR`. `REQUIRED` обязателен: без него «не нашло» — тихий `Qt6_FOUND=FALSE`, и следующая команда падает как неизвестная.
2. **`COMPONENTS Quick QuickControls2 Test`** — список компонентов = список импортируемых
   таргетов `Qt6::*` (`Quick` тянет `Gui`/`Core` транзитивно — требования едут по механизму
   `PUBLIC` из урока 01). `Test` здесь с первого цикла: приёмка модуля 2 — smoke-тест на `Qt6::Test` (цикл 4), а не «когда-нибудь в модуле 8».
3. **`6.10` до `REQUIRED`** — позиция `<min>` из `--help-command find_package`
   (`find_package(<PackageName> [<version>] [REQUIRED] [COMPONENTS <components>...])`):
   кит 6.9.2 отсекается на конфигурации, а не на первой сборке QML-файла.
4. **`qt_standard_project_setup(REQUIRES 6.10)`** — по официальной формулировке ставит
   `CMAKE_AUTOMOC` и `CMAKE_AUTOUIC` **«если они ещё не определены»**, включает `GNUInstallDirs`,
   на Windows задаёт `CMAKE_RUNTIME_OUTPUT_DIRECTORY`, включает `USE_FOLDERS`, дополняет
   `CMAKE_INSTALL_RPATH` значениями `$ORIGIN`. Ключ `REQUIRES 6.10` включает все рекомендуемые
   `QTP`-политики до 6.10 и запрещает конфигурацию на более старом Qt. Форма — `cmake --help-command qt_standard_project_setup`.
5. **`qt_policy(SET QTP0001 NEW)`** — явный вызов той же группы политик (команда с Qt 6.5):
   `QTP0001` — ресурсный префикс `/qt/qml/` по умолчанию. Явность нужна не для эффекта
   (его даёт (4)), а для читаемости: политики Qt — отдельное поколение, и в репозитории должно
   быть видно, какое принято. Форма — `cmake --help-command qt_policy`, реестр — страница политик Qt.
6. **`add_subdirectory(ui)` между `core` и `app`** — `app` линкует `tw::ui`, таргет обязан существовать до потребителя.
7. **`PUBLIC` у `Qt6::Quick`** — заголовок `LightBulb.h` упоминает типы Quick, значит Quick —
   часть API `tw_ui`; симметрично `PUBLIC tw::core` из урока 01.
8. **Приватные модули** — с Qt 6.10 `QQuickItemPrivate` требует явного
   `find_package(Qt6 REQUIRED COMPONENTS QuickPrivate)` (What's New in Qt 6.10); до 6.9 они
   подтягивались транзитивно. Эталон гейтит это по версии, а не пишет в общий список
   (qt-creator): `if(Qt6_VERSION VERSION_GREATER_EQUAL 6.9.0) find_package(Qt6 OPTIONAL_COMPONENTS CorePrivate GuiPrivate QmlPrivate QuickPrivate QUIET)`. Нам понадобится в модуле 15 (QRHI) — запись зарезервирована.
9. **Путь к киту — из пресета**: в `CMakeUserPresets.json` (игнорируется, [`.gitignore:32`](../../.gitignore#L32))
   → `"cacheVariables": { "CMAKE_PREFIX_PATH": "C:/Qt/6.10.2/msvc2019_64" }`; тот же
   `$env{}`-приём урока 01 допустим как `"$env{TW_QT_PREFIX}"` — тогда имя переменной живёт в ADR-0001.

**Почему сделано именно так.** Компоненты = таргеты: `find_package` в Qt6 — не «включить модуль»,
а импортировать готовые узлы графа с usage requirements; расхождение списка `COMPONENTS` со списком
линковки в эталоне осознанно (qt-creator строит компоненты по признаку опции сборки).
`qt_standard_project_setup` — ровно один раз и до таргетов: его эффекты — переменные **каталогной
области**, вызов позже оставит ранее определённые цели без AUTOMOC («If called later, it will not
apply to any targets defined before» — страница команды). Политики `QTP…` — тот же механизм, что
`CMP…` урока 01: поколение решений, а не булевы флаги; `REQUIRES` покупает воспроизводимость всей цепи Qt-команд.

**Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| Нет `REQUIRED`, кит не найден | `Unknown CMake command "qt_standard_project_setup"` — падает не там, где сломалось | цикл 1 (1) |
| `qt_standard_project_setup()` после `add_subdirectory(ui)` | `tw_ui` собирается без moc: `undefined reference to vtable for LightBulb` (GCC/MinGW) / `LNK2001` (MSVC) | цикл 1 (4), тонкость 2 |
| `PRIVATE` у `Qt6::Quick` в `tw_ui` | конфигурация зелёная; компиляция `tw_app` падает на `QQuickItem: No such file or directory` — требование не уехало потребителю | цикл 1 (7); тонкость 1 урока 01 |
| `CMAKE_PREFIX_PATH` хардкодом в `CMakeLists.txt` | на CI и на второй машине — дефект старого `cmake/QtSetup.cmake` ([`legacy-description.md:20`](../legacy-description.md#L20), находка `1`); локально зелёное | цикл 1 (9), `git check-ignore` из урока 01 |

**Тонкость 1.** `CMAKE_AUTOMOC`, заданный **до** `qt_standard_project_setup` (например, унаследованный
из старого `cmake/QtSetup.cmake`), победит: команда ставит значения только «if they are not already
defined» (страница). Симптом — не ошибка, а молчание: кажется, что проект живёт по стандарту Qt, а он
живёт по чужому значению. Проверка: `Select-String build/win-ninja-debug/CMakeCache.txt -Pattern "AUTOMOC"` значение из каталогного `set()` не покажет — потому смотрят наличие автoген-целей: `cmake --build build/win-ninja-debug --target help | Select-String autogen` → пусто значит `OFF` выше.

**Тонкость 2.** Ключ `REQUIRES <version>` включает политики **до названной версии**, а
`SUPPORTS_UP_TO` включает политики будущих версий, не делая их обязательными
([страница команды](https://doc.qt.io/qt-6/qt-std-project-setup.html)). Для baseline 6.10
`SUPPORTS_UP_TO 6.12` уместен **только если** сборка на 6.12 тоже принимается; без него поведение
на будущих Qt — старые политики. Проверка своего поколения: `qt_policy(GET QTP0001 v)` +
`message(STATUS "QTP0001: ${v}")`.

**Тонкость 3.** `qt_standard_project_setup` **не включает `AUTORCC`** и не обязан: в Qt6-механике
`.qrc` — это `RESOURCES` внутри `qt_add_qml_module` (цикл 2) или `qt_add_resources`, а не глобальная переменная. Старый проект ставил все три флага разом ([`legacy-description.md:20`](../legacy-description.md#L20)); перенос тройки «по привычке» создаёт второй, незаметный источник ресурсов, который потом конфликтует с генерируемыми путями. Проверка: `Select-String build/win-ninja-debug/CMakeCache.txt -Pattern "AUTORCC"` → `OFF` (проверь свой).

**Ловушка.** В строке плана [`2.2`](../course.md#L126) стоит `QTP0081` — политики с таким номером
**нет**: реестр Qt-политик — `QTP0001`–`QTP0008` ([страница политик](https://doc.qt.io/qt-6/cmake-qt-policies.html),
проверено 25.11.2026 на двух языковых версиях документации). Это тот же класс ошибки, что
`matrixPresets` урока 01: правдоподобный идентификатор, которого нет в реализации, — и его копируют. Проверенная привычка: про `QTP`-номер — вопрос к официальной странице и к `QT_KNOWN_POLICY_QTP<NNNN>` (существование переменной = существование политики).

**Мини-практика и чекпойнт (3 минуты).**

```powershell
cmake --preset win-ninja-debug
cmake --build --preset win-ninja-debug
```

→ конфигурация проходит с версией Qt в логе (`Qt6_VERSION` в кэше — непусто),
`& "C:/Qt/6.10.2/msvc2019_64/bin/qmake.exe" -query QT_VERSION` (путь — из твоего ADR-0001) совпадает
с ней до патча. Если падает на `Could not find a package configuration file provided by "Qt6"` —
список мест поиска в тексте ошибки: отсутствие кита в `CMAKE_PREFIX_PATH` отличается от кита не под
тот компилятор (второй конфигурируется, но сыпется `LNK…`/`undefined reference` — это блокер ADR-0001, а не урок).

**Эталон цикла:** [qt-creator `CMakeLists.txt`](https://github.com/qt-creator/qt-creator/blob/master/CMakeLists.txt) — условный список компонентов, `OPTIONAL_COMPONENTS … QUIET`, гейт `*Private` по `Qt6_VERSION`; [Getting started with CMake](https://doc.qt.io/qt-6/cmake-get-started.html) — порядок `find_package` → `qt_standard_project_setup` → цели, и выбор keyword `PUBLIC`/`PRIVATE`.

### Цикл 2 — `qt_add_qml_module`: свой модуль вместо `.qrc` (план 2.2; ≤25 минут)

**1. Механика: разбор (1)–(9).** Каталог `ui/`, его определение и загрузка.

```cmake
# ── (1) ui/CMakeLists.txt
qt_add_qml_module(tw_ui                                   # (2)
  URI trafficwatcher.ui                                   # (3) решение ADR-0002, см. ниже
  VERSION 1.0
  QML_FILES                                               # (4)
    Main.qml
    LightBulb.qml
  SOURCES                                                 # (5)
    LightBulb.h
    LightBulb.cpp
  DEPENDENCIES QtQuick QtQuickControls2                   # (6)
)
target_link_libraries(tw_ui PUBLIC tw::core Qt6::Quick)   # (7)
```

```cpp
// ── app/src/main.cpp — фрагмент (8)
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.loadFromModule("trafficwatcher", "Main");      // (9)
    return app.exec();
}
```

1. **Каталоги `ui/`** — структура исходников **обязана совпадать** с target path модуля: URI с
   точками → сегменты каталога; цитата страницы: «if your module URI is `MyUpperCaseThing.mylowercasething`, you need to put this in a directory called `MyUpperCaseThing/mylowercasething/`». При расхождении — **warning**, и сборка продолжается (тонкость 2).
2. **`qt_add_qml_module(tw_ui …)`** — `tw_ui` становится **backing target**: в него попадают
   `SOURCES`, сгенерированный `qmltyperegistrar`-код и ресурсы; рядом создаётся **plugin target**
   `tw_uiplugin` (имя = backing + `plugin`; `PLUGIN_TARGET` — своё; `NO_PLUGIN` — подавить). Справка — только официальная страница [Qt 6.10](https://doc.qt.io/qt-6/qt-add-qml-module.html) (в `cmake --help-command` её нет — это команда Qt; проверено 25.11.2026).
3. **`URI trafficwatcher.ui`** — **API поставки** (находка `13`: [`legacy-description.md:59`](../legacy-description.md#L59)):
   QML-код пишет `import trafficwatcher.ui`, переименование потом ломает потребителей. Кандидаты
   (`trafficwatcher.ui` vs `TrafficWatcher.UI`) — в «Задании»; решение — за ADR-0002
   ([`readme.md:149`](../readme.md#L149)). Сегменты — валидные ECMAScript identifiers.
4. **`QML_FILES`** — явный список (правило урока 01 про `file(GLOB)` здесь в силе): файлы попадают
   в ресурсы под префиксом `/qt/qml/` (это `QTP0001 NEW` из цикла 1) и компилируются
   **`qmlcachegen`** в `.qsb`; оригинал остаётся в ресурсах — в dev-конфигурации обе формы.
5. **`SOURCES`** — C++ модуля живёт внутри той же команды: `qmltyperegistrar` сканирует заголовки
   и генерирует регистрацию (цикл 3); второго источника списка файлов нет.
6. **`DEPENDENCIES QtQuick QtQuickControls2`** — метаданные о том, что C++-код модуля **использует
   из чужих модулей** (подкласс `QQuickItem`, `QPointF` в QML-видимых сигнатурах). Это не линковка:
   C++-часть требует всё равно `target_link_libraries` (7); разница `DEPENDENCIES`/`IMPORTS` — тонкость 1.
7. **Линковка**: `tw::core` — `PUBLIC` (заголовки `ui/` включают домен), `Qt6::Quick` — `PUBLIC`
   (цикл 1 (7)). `RESOURCES` — псевдоним `QML_FILES` (страница команды), но для картинок темы
   (модуль 14) естественнее `qt_add_resources` (проверь форму); `NO_CACHEGEN` не используем.
8. **`loadFromModule`** заменяет `engine.load("qrc:/qml/main.qml")`
   ([`legacy-description.md:27`](../legacy-description.md#L27)): первый аргумент — **модуль**,
   второй — тип. Сигнатура сверена с официальной страницей [QQmlApplicationEngine](https://doc.qt.io/qt-6/qqmlapplicationengine.html):
   `[slot, since 6.5] void loadFromModule(QAnyStringView uri, QAnyStringView typeName)`
   (замер 25.11.2026 — страница Qt 6.12.1; в 6.10 метод есть, «since 6.5»).
9. **`return app.exec()` без проверки загрузки** — здесь сознательно: ошибки загрузки разбирает
   цикл 4; в рабочем `main.cpp` — обработчик `objectCreated`/проверка `rootObjects()` (шаг 4).

**Почему сделано именно так.** Отказ от ручного `qmldir`/`.qrc` — не косметика: в старой схеме
([`legacy-description.md:28–30`](../legacy-description.md#L28)) четыре артефакта (имя URI в
`qmlRegisterType`, путь в `.qrc`, содержимое `qmldir`, импорт в QML) синхронизировались руками, и
каждый перенос — кандидат на «работает локально, падает у пользователя». `qt_add_qml_module`
выводит все четыре из одного имени — порт-гид Qt перечисляет переход дословно: `qmldir` →
генерируется, `qmlRegisterType` → `QML_ELEMENT`, `.qrc` → `QML_FILES`/`RESOURCES`, `engine.load("qrc:/…")` → `loadFromModule`.

**Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| URI `trafficwatcher.UI` (заглавная), каталоги `ui/` | конфигурация **зелёная** с warning про структуру каталога; `import trafficwatcher.UI` падает в рантайме «module … was not found» | цикл 2 (1), тонкость 2 |
| `NO_PLUGIN` + `tw_app` линкует только `tw::ui` без проверки | для backing-библиотеки это ровно то, что нужно (статическая регистрация в `tw_ui`); но если backing — сам `tw_app`, plugin не создаётся вовсе, и тест из цикла 4, линкующий только `tw::ui`, не увидит модуль | цикл 2 (2), цикл 4 (5) |
| QML-файл добавлен на диске, но не в `QML_FILES` | импорта нет в `qmldir`: `LightBulb is not defined` в рантайме; qmllint молчит | цикл 2 (4) |
| Забыт `DEPENDENCIES QtQuick` при подклассе `QQuickItem` | qmllint/qmltyperegistrar не видят базовый тип: предупреждения в `all_qmllint`, потенциально битый `qmltypes` | цикл 2 (6), тонкость 1 |

**Тонкость 1.** `DEPENDENCIES` против `IMPORTS` по документации ECM
([`ECMQmlModule.cmake`](https://invent.kde.org/frameworks/extra-cmake-modules/-/blob/master/modules/ECMQmlModule.cmake),
разобрана в блоке 8): `DEPENDENCIES` — что модуль **требует** (обязательно для QML-видимого C++:
подкласс `QQuickItem`, `QPointF` в сигнатуре), `IMPORTS` — что доступно **потребителю** модуля как
часть его публичного интерфейса. Симптом перепутанных мест: lint проходит, а у потребителя
«module not found» — или наоборот, мусорные зависимости в `qmldir`, раздувающие граф импортов.
Для курса: `QtQuick.Controls` (он же `ApplicationWindow` в `Main.qml`) — `IMPORTS`/`DEFAULT_IMPORTS`,
`QtQuick` — `DEPENDENCIES`; полный список keyword — synopsis официальной страницы (в `cmake --help-command` команды нет).

**Тонкость 2.** Предупреждение о несоответствии каталога — **warning**, а не ошибка: CI проходит
зелёно, а `OUTPUT_DIRECTORY` (default — target path, продолженный к `QT_QML_OUTPUT_DIRECTORY`,
если он задан — страница команды) начинает расходиться с тем, что ожидает `loadFromModule`. Симптом — две копии `qmldir` в build-дереве; лечится соответствием каталогов, а не `OUTPUT_DIRECTORY`: modernizing-страница Qt рекомендует обходиться без него при правильном layout.

**Тонкость 3.** `DISCARD_QML_CONTENTS` (новый в 6.10) оставляет в ресурсах только
qmlcachegen-байткод `.qsb`, оригиналы `.qml` — нет. Следствие, из-за которого в dev-пресете
его не включают: бинарник привязывается к версии `qmlcachegen`, собравшей `.qsb`, а потеря
оригиналов ломает runtime-отладку; для поставки 11.x это легитимная опция уменьшения пакета — с проверкой загрузки на целевом Qt (проверь на своей сборке: наличие `.qsb` без `.qml` в ресурсах).

**Ловушка.** `QTP0081` из [`course.md:126`](../course.md#L126) — см. «Ловушку» цикла 1; вторая
часть той же строки плана верна по сути: отказ от ручного `.qmldir`/`.qrc` — это то, что делает
команда. Не путай с ней `QTP0001` (префикс `/qt/qml/`) и `QTP0004` (дополнительные `qmldir`-файлы) — реестр на странице политик; на своей машине — та же страница + `qt_policy(GET …)`.

**Мини-практика и чекпойнт (5 минут).**

```powershell
cmake --build --preset win-ninja-debug
Get-ChildItem build/win-ninja-debug -Recurse -Filter qmldir | Select-Object -ExpandProperty FullName
```

→ как минимум один `qmldir` в build-дереве (путь зависит от layout — сверь с target path URI);
его содержимое — `module trafficwatcher.ui`, строки `Main`/`LightBulb`, и **ни одного** файла
`qmldir` в исходниках: `Test-Path ui/qmldir` → `False`, `Test-Path ui/resources.qrc` → `False`.

**Эталон цикла:** [kdenlive `src/CMakeLists.txt`](https://invent.kde.org/video/kdenlive/-/blob/master/src/CMakeLists.txt)
— `ecm_add_qml_module(kdenliveLib URI org.kde.kdenlive GENERATE_PLUGIN_SOURCE DEPENDENCIES QtQuick)`
+ линковка `kdenlive PUBLIC kdenliveLib kdenliveLibplugin` (разбор — self-check 3), `.qrc` у kdenlive
**сосуществует** с модулем (иконки) — тот же вывод, что тонкость 3 про AUTORCC; [Qt6 Porting Guide](https://doc.qt.io/qt-6/qt6-port-to-qt-add-qml-module.html) — таблица «было → стало»;
контраст: [shotcut](https://github.com/Mltt/Shotcut) до сих пор `.qrc`-based (`resources.qrc`,
без `qt_add_qml_module`) — так выглядит код до перехода.

### Цикл 3 — `QML_ELEMENT`: типы регистрируются сами (план 2.3; ≤25 минут)

**1. Механика: разбор (1)–(8).** Класс из плана урока — тот же `LightBulb` из старого проекта ([`legacy-description.md:30`](../legacy-description.md#L30)).

```cpp
// ── ui/LightBulb.h
#pragma once

#include <QtQml/qqmlregistration.h>          // (1)
#include <trafficwatcher/core/Mode.hpp>       // (2) PUBLIC-требование из урока 01
#include <QObject>

class LightBulb : public QObject {            // (3)
    Q_OBJECT
    QML_ELEMENT                               // (4)
    Q_PROPERTY(Mode mode READ mode WRITE setMode NOTIFY modeChanged)  // (5)
    Q_PROPERTY(bool lit READ lit NOTIFY litChanged)                   // (6)
public:
    explicit LightBulb(QObject *parent = nullptr);
    Mode mode() const;
    void setMode(Mode mode);
    bool lit() const;
signals:
    void modeChanged();
    void litChanged();
private:
    Mode mode_ = Mode::Off;
};
```

```qml
// ── ui/LightBulb.qml — компонент того же модуля (7)
import QtQuick

Rectangle {
    required property LightBulb bulb   // (8) тип из C++ — как обычный тип QML
    color: bulb.lit ? "red" : "gray"
}
```

Что здесь впервые и почему именно так:

1. **`#include <QtQml/qqmlregistration.h>`** — обязательный заголовок: без него макросы
   регистрации **раскрываются в пустоту**, а не в ошибку (см. «что будет, если нарушить»).
   Он же тянет определения `QML_ELEMENT`, `QML_NAMED_ELEMENT`, `QML_VALUE_TYPE`, `QML_SINGLETON`,
   `QML_UNCREATABLE`, `QML_FOREIGN`, `QML_ANONYMOUS`, `QML_INTERFACE` — полная страница [Defining types for QML](https://doc.qt.io/qt-6/qqmlregistration-definetypes.html).
2. **Include под углом через `trafficwatcher/core/`** — требование из урока 01 (шаг 3):
   `Mode.hpp` доехал сюда через `PUBLIC` из цикла 1 (7). Первый случай, когда решение
   прошлого урока буквально собирает этот.
3. **Наследник `QObject`** — `QML_ELEMENT` применим к любому QObject-derived классу;
   базовый тип из QtQuick (`QQuickItem`, `QQuickPaintedItem`) влечёт `DEPENDENCIES QtQuick`
   из цикла 2 (6) — здесь `LightBulb` держит состояние, а не рисует, поэтому `QObject`.
4. **`QML_ELEMENT` у объявления** — имя в QML = имя C++-класса; `QML_NAMED_ELEMENT(bulb)` —
   когда имя в QML обязано пережить переименование класса. Условие действия: класс обязан быть
   в таргете, объявленном `qt_add_qml_module` (цикл 2), и заголовок — перечислен в `SOURCES`
   либо достижим из него.
5. **`Q_PROPERTY(Mode mode …)`** — тип свойства = enum, а не `int`: магическая `2` в QML —
   находка `10` ([`legacy-description.md:56`](../legacy-description.md#L56)); закрытие — модуль 4.2,
   здесь фиксируется форма. Значения enum в QML начинаются с заглавной — `LightBulb.Mode.On`
   (страница define-types).
6. **`lit` — readonly (нет `WRITE`)** — первое «свойство-выводок»: сигнал есть, сеттера нет.
7. **QML-компонент модуля** — `LightBulb.qml` из `QML_FILES` того же модуля видит C++-тип
   без импорта собственного URI (порт-гид удаляет self-imports из старого кода).
8. **`required property LightBulb bulb`** — имя C++-класса в позиции типа работает **только
   после** регистрации макросом: это и есть проверяемая граница между «класс есть» и
   «тип доступен QML».

**Почему сделано именно так.** Четыре `qmlRegisterType` старого `main.cpp`
([`legacy-description.md:27`](../legacy-description.md#L27)) — четыре строки, которые обязаны
руками совпадать с URI, версией и списком классов. Макрос переносит регистрацию на этап сборки:
`qmltyperegistrar` генерирует init-код из заголовков, и рассинхрон «URI в CMake vs URI в C++»
становится невозможен по построению. Побочный выигрыш находки `3` legacy-таблицы: статические
сборки (модуль 19) с `qmlRegisterType` ломаются на инициализации — генерируемая регистрация живёт в том же таргете, что и модуль.

**Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| Нет `#include <QtQml/qqmlregistration.h>` | **сборка зелёная** — `QML_ELEMENT` раскрылся в пустоту; в рантайме/линте «LightBulb is not defined» | цикл 3 (1), тонкость 1 |
| Класс вне `SOURCES` модуля (например, в `tw_core`) | макрос не где-то «не сработал», а не применим: регистрация привязана к модулю; `tw_core` не знает QML — и не должен знать (модуль 6.1) | цикл 3 (4), цикл 2 (5) |
| `QML_UNCREATABLE` забыт на контроллере, который должен быть один | `LightBulb {}` создаётся из QML произвольно, состояние разъезжается | цикл 3, тонкость 2 |
| `Q_ENUM` не объявлен у `Mode` | `LightBulb.Mode.On` не разрешается в QML; числа проходят молча — до первого `setMode(4)` | шаг 2; модуль 3.3 (`std::to_underlying`) |

**Тонкость 1.** Пустое раскрытие макроса — не гипотеза: `QML_ELEMENT` определён в
`QtQml/qqmlregistration.h`, и без этого include макроса в трансляции просто нет — компилятор не
ругается только там, где он не встречался (точный механизм проверь поиском в заголовке своей сборки). Симптом всегда двухслойный: сборка проходит, QML падает. Проверка, что регистрация случилась: сгенерированный `*qmlreg*` в build-дереве содержит имя класса — `Get-ChildItem build/win-ninja-debug -Recurse -Filter "*qmlreg*" | Select-String LightBulb` → непусто.

**Тонкость 2.** `QML_SINGLETON` для C++-класса требует метаданных: свойства источника
`QT_QML_SINGLETON_TYPE` (страница `qt_add_qml_module`) плюс фабрика создания — форма зависит от
версии, проверь официальную singleton-документацию на своей 6.10. Долг записан: тема уроком 4.4
вернётся как `QML_SINGLETON` на `constexpr`-данных, а `pragma Singleton` старого `Theme.qml` ([`legacy-description.md:30`](../legacy-description.md#L30)) — её прообраз.

**Тонкость 3.** `QML_VALUE_TYPE` — для `Q_GADGET` (не QObject): имя в QML **строго строчное**,
тип обязан быть конструируемым по умолчанию и копируемым, синглтоном быть не может
([страница define-types](https://doc.qt.io/qt-6/qqmlregistration-definetypes.html)). Следствие: значения вроде координаты карты (модуль 13.1) публикуются как `modeinfo`, а не `ModeInfo`, и заглавная форма — та же «зелёная сборка / красный рантайм», что тонкость 1: значения типов проверяются qmllint по сгенерированному `qmltypes`, а он без макроса не знает о типе.

**Мини-практика и чекпойнт (3 минуты).**

```powershell
cmake --build --preset win-ninja-debug
$env:QT_QPA_PLATFORM = "offscreen"
& build/win-ninja-debug/app/tw_app.exe; $LASTEXITCODE
```

→ окно живёт до закрытия; без `QT_QPA_PLATFORM` на headless-машине — `This application failed
to start because no Qt platform plugin could be initialized` (текст — из Qt; сверь свой). Путь
к бинарнику зависит от `CMAKE_RUNTIME_OUTPUT_DIRECTORY` (цикл 1 (4)) — точное место покажет `Get-ChildItem build/win-ninja-debug -Recurse -Filter tw_app.exe`.

**Эталон цикла:** [Defining types for QML](https://doc.qt.io/qt-6/qqmlregistration-definetypes.html)
— все макросы и ограничения; [Porting Guide](https://doc.qt.io/qt-6/qt6-port-to-qt-add-qml-module.html) — строка `qmlRegisterType` → `QML_ELEMENT` таблиц перехода; KDAB [«10 Tips for Writing Robust QML Code»](https://www.kdab.com/10-tips-for-writing-robust-qml-code/) — почему регистрация должна быть у объявления, а не в main (обсуждается и в комментариях ECM к `ECMQmlModule.cmake`).

### Цикл 4 — Smoke-тест: «engine загрузил модуль» headless (приёмка модуля 2; ≤25 минут)

**1. Механика: разбор (1)–(8).** Тест из [`course.md:130`](../course.md#L130) — не скриншот,
а факт загрузки.

```cpp
// ── tests/src/QmlSmoke_test.cpp
#include <QtGui/QGuiApplication>            // (1)
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlComponent>              // (2)
#include <QtTest/QTest>
#include <memory>

class TestQmlSmoke : public QObject {
    Q_OBJECT
private slots:
    void moduleLoads() {
        QQmlApplicationEngine engine;
        engine.loadFromModule("trafficwatcher", "Main");
        QVERIFY2(!engine.rootObjects().isEmpty(),
                 qPrintable(engine.errors().isEmpty() ? "no root objects"
                                                      : engine.errors().first().toString()));  // (3)
    }
};
QTEST_MAIN(TestQmlSmoke)                    // (4)
#include "QmlSmoke_test.moc"                // (5)
```

```cmake
# ── tests/CMakeLists.txt (продолжение урока 01)
qt_add_executable(tw_ui_smoke src/QmlSmoke_test.cpp)      # (6)
target_link_libraries(tw_ui_smoke PRIVATE tw::ui Qt6::Test)
add_test(NAME ui/module/smoke COMMAND tw_ui_smoke)
set_tests_properties(ui/module/smoke PROPERTIES
  LABELS "smoke" TIMEOUT 30
  ENVIRONMENT "QT_QPA_PLATFORM=offscreen")                # (7)

add_test(NAME ui/negative/unknownType COMMAND tw_ui_smoke -functions *nope*)  # (8)
set_tests_properties(ui/negative/unknownType PROPERTIES
  LABELS "negative" WILL_FAIL TRUE)
```

1. **`QGuiApplication` (или `QApplication` для Widgets)** — `QQuickWindow`/`ApplicationWindow`
   живут только с GUI-приложением; `QTEST_MAIN` создаёт его сам — какой именно класс создаёт его
   для QML-тестов, проверь (в Qt6 есть `QTEST_QMLGUI_MAIN` — существует ли он в 6.10 и нужен ли вместо ручной связки — отметка «проверь» по официальной странице QTest macros своей версии).
2. **Проверка — `rootObjects()`, а не «нет исключений»** — `QQmlApplicationEngine` не бросает:
   ошибка загрузки — это пустой список + `engine.errors()`; тест без `errors()` в сообщении
   доказывает только то, что упал не C++.
3. **`QVERIFY2` с текстом ошибки** — в JUnit-отчёте 12.x видно *почему*: «module was not found»
   и «LightBulb is not defined» — разные поломки (цикл 2 против цикла 3), и чинят их в разных местах.
4. **`qt_add_executable`, а не `qt_add_test()`** — существование и версия появления команды
   `qt_add_test()` в этой сборке не сверены (её слой — модуль 8.2, [`course.md`:211](../course.md#L211));
   связка `qt_add_executable + Qt6::Test + add_test` верифицируема сегодня и разворачивается
   в 8.2 без переписывания.
5. **`QmlSmoke_test.moc`** — `QTEST_MAIN` требует включаемого moc-файла; путь/имя — как у
   источника (проверь `--help-command`-ом, а лучше текстом ошибки, если CMake его не нашёл);
   `tw_ui_smoke` обязан линковать `tw::ui` — иначе модуль не зарегистрирован в процессе теста (backing static: регистрация — в нём).
6. **Лейбл `smoke`** — тот же фильтр `-L smoke`, что в уроке 01, ловит теперь тесты двух природ;
   инвариант приёмки: `ctest -L smoke` обязан отработать **оба**, `Total Tests: 2`.
7. **`ENVIRONMENT "QT_QPA_PLATFORM=offscreen"`** — форма свойства (список `VAR=value`,
   разделённый `;`) — `ctest --help-property ENVIRONMENT`. Без него тест зелёный на рабочей
   станции и красный в CI — ровно находка `11` legacy-таблицы
   ([`legacy-description.md:57`](../legacy-description.md#L57)): `add_test` без `ENVIRONMENT` был там одной из причин «тесты не работают».
8. **Negative control через `WILL_FAIL`** — тест, который обязан упасть: `QTest -functions`
   с несуществующим слотом даёт ненулевой код → CTest отмечает Passed. Это доказательство, что
   прогон доходит до Qt-кода, а не «ctest не нашёл бинарник» (почему коды возврата молчат —
   урок 01, цикл 5). В CI такой тест включается отдельно: `-L negative`.

**Почему сделано именно так.** М1 требует «то же приложение крутится headless»
([`readme.md`](../readme.md), критерий вехи) — значит уже сейчас тест не имеет права на дисплей.
Тест проверяет **контракт модуля** (загрузка корня из URI), а не пиксели: проверка вида
`grabToImage` — это golden из модуля 9.3, ей здесь не место.

**Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| Тест линкует `tw_uiplugin`, но не `tw::ui` (или наоборот — только `tw::ui` при plugin-модуле) | «module trafficwatcher.ui was not found» в offscreen-прогоне: типы не зарегистрированы в этом процессе | цикл 4 (5); сравни с kdenlive: линкуются **оба** |
| Нет `ENVIRONMENT` | локально Passed; в CI «no Qt platform plugin could be initialized», код 0xc0000409-подобный краш | цикл 4 (7) |
| `TIMEOUT` нет, а engine завис на диалоге импорта | `ctest` висит до kill-таймера CI (минуты); без `-timeout` и без свойства отличить зависание от медленного теста нельзя | цикл 4 (7); модуль 8.3 |
| `WILL_FAIL` на тесте, который обязан проходить | красный прогон выглядит «как задумано»: инверсия результата спрятана в свойстве | цикл 4 (8): negative control — только на осознанно падающих |

**Тонкость 4.** Свойства `ENVIRONMENT` и `WORKING_DIRECTORY` применяются к **процессу теста**,
но не к тому, как CMake нашёл сам бинарник: `COMMAND tw_ui_smoke` разворачивается в
`$<TARGET_FILE:…>`-путь на этапе генерации — форма `add_test(NAME … COMMAND <target> …)`
(именно таргета, урок 01 тонкость про NAME-форму). Если написать `COMMAND tw_ui_smoke.exe`,
ctest будет искать файл относительно `WORKING_DIRECTORY` — и на multi-config генераторе
(цикл 2 урока 01) не найдёт: `Not Run` вместо `Failed`, код 8, а не 0.

**Проверь.** `ctest --preset win-ninja-debug -L smoke --output-on-failure; $LASTEXITCODE` → `0`,
`Total Tests: 2`; `ctest --preset win-ninja-debug -L negative` → Passed на инвертированном.
Если `Total Tests: 0` — лейблы не проставлены (не тот каталог `-T`, либо `BUILD_TESTING=OFF`:
вспоминаем рубильник урока 01).

**Эталон цикла:** находка `11` legacy-таблицы — весь список CTest-свойств, до которых мы
сегодня дошли тремя пунктами; [CTest manualProperties](https://cmake.org/cmake/help/latest/manual/ctest.1.html)
— `ENVIRONMENT`, `WILL_FAIL`, `PROCESSORS` (следующий раз — 8.3); сам паттерн
«GUI-тест через offscreen» — стандарт CI-документации Qt (страница Testing/Qt Quick — проверь актуальный адрес на своей версии документации).

### Цикл 5 — qmllint и qmlformat: статический контур без самописных списков (приёмка модуля 2; ≤20 минут)

**1. Механика: разбор (1)–(6).**

```cmake
# ── tests/CMakeLists.txt (статический контур)
add_test(NAME ui/qmllint
  COMMAND qmllint --project ${CMAKE_SOURCE_DIR}/build/win-ninja-debug/compile_commands.json
          ${CMAKE_SOURCE_DIR}/ui)                       # (1)
set_tests_properties(ui/qmllint PROPERTIES
  LABELS "static"
  ENVIRONMENT "QT_QML_GENERATE_QMLLS_INI=on")           # (2)
add_test(NAME ui/qmlformat
  COMMAND powershell -NoProfile -Command "
    foreach ($f in Get-ChildItem ${CMAKE_SOURCE_DIR}/ui -Filter *.qml) {
      $d = (& qmlformat $f.FullName) -join \"`n\"
      if ($d -ne (Get-Content -Raw $f.FullName)) { exit 1 }
    }")                                                 # (3)
set_tests_properties(ui/qmlformat PROPERTIES LABELS "static" TIMEOUT 60)
```

1. **Два входа в lint**: цель `all_qmllint` (создаётся автоматически на каждый
   `qt_add_qml_module`; состав — `cmake --build build/win-ninja-debug --target help |
   Select-String qmllint`) проверяет **то, что видит IDE-модель модуля**, а прямой `qmllint`
   по каталогу с `--project` (указание на `compile_commands.json` — форма опции есть в
   `qmllint --help`, проверь список на своей сборке) проверяет сами файлы. Разница проявляется,
   когда файл есть на диске, но не в `QML_FILES`: второй ловит, первый — нет (цикл 2, таблица
   нарушений).
2. **`QT_QML_GENERATE_QMLLS_INI=on`** — способ из документации qmllint сгенерировать
   `.qmlls.ini` рядом с QML-файлами, чтобы линтер нашёл модуль в build-дереве (страница
   Using qmllint; точное поведение — «проверь»: версия документа 6.12.1, поведение 6.10 сверяй
   на своей). Альтернатива из той же документации — запуск линта как build-цели, которая знает
   import-пути сама.
3. **qmlformat без `--check`**: у инструмента флагов проверки нет — только `-i/--inplace`
   (переписывает файл) и вывод в stdout (проверено по официальной странице qmlformat,
   замер 25.11.2026, версия документа 6.12.1). Значит CI-форма — «отформатировать в stdout и
   сравнить с исходником», как в (3); **никогда `-i` в пайплайне**: коммит-хук с `-i` правит
   дерево, CI — нет, и расхождение живёт вечно.
4. **Регистрация через CTest, а не отдельный шаг CI** — почему: отчёт 12.2 (CDash/JUnit)
   должен видеть статические проверки теми же тестами, что и динамические; отдельный шаг
   вне CTest не попадает ни в `--output-junit`, ни в историю лотов.
5. **Порог** — qmllint различает warning/error; в уроке решение принято owner'ом ADR-0003
   (политика предупреждений из урока 01 — тот же рубильник распространяется на QML; точную
   опцию `--max-warnings` или аналог проверь в `qmllint --help` своей сборки, её наличие
   в 6.10 не гарантировано).
6. **Каталог `build/…` в `--project`** — жёсткая привязка к configure-пресету: на `win-vs`
   `compile_commands.json` не генерируется (урок 01, тонкость 3), поэтому у lint-тестов есть
   смысл только на Ninja-пресетах; на VS-пресете они обязаны помечаться как не применяемые
   (`set_tests_properties(... DISABLED True)` — форма из `ctest --help-property-list`).

**Почему сделано именно так.** `qt_add_qml_module` уже знает все файлы и метаданные модуля —
qmlcachegen, qmldir, qmltypes, регистрация, lint-цели следуют из его же аргументов. Ручной
список проверяемых файлов ([`legacy-description.md:28`](../legacy-description.md#L28): `.qrc` +
`qmldir` как реестры файлов) — пятый дубликат, за который никто не платит при добавлении файла.

**Что будет, если нарушить.**

| Нарушение | Симптом | Где чинить |
|---|---|---|
| Lint без знания модели модуля (нет ни `all_qmllint`, ни import-путей) | шквал «Unqualified access» / «module not found», команда забрасывается | цикл 5 (2) |
| `qmlformat -i` в CI | рабочее дерево «исправилось» после прогона; git diff зелёный только потому, что CI пишет в свою копию — локально файлы расходятся | цикл 5 (3) |
| lint-тест без `LABELS static` | `-L smoke` в приёмке урока 01 перестает означать «запусти и собери»; фильтры CI 12.3 смешивают слои | цикл 5 (4) |
| Ожидание `qmlformat --check` | `Unknown option '--check'`, код 1, «тест всегда красный» | «Ловушка» ниже |

**Тонкость 5.** `.qmllint.ini`/`qmlformat.ini` — настройки рядом с исходниками
(страницы инструментов): молча меняют пороги и правила для всех, кто запускает инструментом
из этого каталога. Симптом «в CI красный, локально зелёный» после чужого коммита с `.ini` —
это не flaky, а конфигурация: файлы обязаны быть в индексе и под ревью (git-механика урока 01,
цикл 4: `git check-ignore -v ui/.qmllint.ini` → код 1).

**Ловушка.** Строка приёмки модуля 2 — [`course.md:130`](../course.md#L130): «`qmllint`/`qmlformat
--check` в CI». Флага `--check` у `qmlformat` нет ни в 6.10, ни в актуальной документации
(полный список опций — [qmlformat page](https://doc.qt.io/qt-6/qmlformat-tool.html), проверено
25.11.2026: `-i`, `-f`, `-F`, `-n`, `-S`, … — `--check` отсутствует). На своей сборке —
`qmlformat --help | Select-String check` → пусто. Третья находка того же класса после
`matrixPresets` (урок 01) и `QTP0081` (цикл 2): правдоподобный флаг/имя/политика переживают
проверку «похоже на правду» и не проходят проверку «существует». Привычка, ради которой этот
урок и написан: **сигнатуру проверяют инструментом**, `--help` и официальной страницей — до
того, как конструкция попадает в план, CI или чужой код.

**Мини-практика и чекпойнт (2 минуты).**

```powershell
cmake --build build/win-ninja-debug --target all_qmllint
qmllint --help | Select-String -Pattern "project|max"
qmlformat --help | Select-String -Pattern "check"
```

→ первая цель существует и проходит на файлах урока; во второй — строка `--project` (если её
нет в твоей версии — способ 2 не работает, и lint ведут через build-цель, цикл 5 (1)); третья
— **пустая**, что и требовалось проверить.

**Эталон цикла:** ECM `ecm_add_qml_module`/KDE CI — линт как цель сборки; KDAB [«10 Tips»](https://www.kdab.com/10-tips-for-writing-robust-qml-code/) — qmllint как часть культуры кода; официальная [Using qmllint](https://doc.qt.io/qt-6/qmllint.html) (точный адрес на своей версии — проверь: в 6.12 страница называется иначе; содержательное требование одно — список опций должен читаться `--help`, а не пересказываться).

## Блок 6. Задание

Пункты про результат; D1–D8 меняют артефакты приложения, D9–D10 — решение и индекс.

| # | Задание | Что должно получиться |
|---|---|---|
| D1 | Qt6 входит в граф | `find_package(Qt6 6.10 REQUIRED COMPONENTS …)` + `qt_standard_project_setup(REQUIRES 6.10)` в корне до таргетов; ни одного хардкода пути к киту; `--graphviz`: `tw_ui → Qt6::Quick`, обратного ребра `Qt6… → tw_*` нет |
| D2 | `ui/` — модуль, а не папка с файлами | `qt_add_qml_module(tw_ui URI …)`, каталоги = сегменты URI, `QML_FILES`/`SOURCES` явные; в исходниках нет `qmldir`, `qml.qrc`; warning про структуру каталога при конфигурации отсутствует |
| D3 | Тип домена опубликован | `LightBulb` с `QML_ELEMENT` и `#include <QtQml/qqmlregistration.h>`; в generated-файле регистрации имя класса есть; `qmlRegisterType` в репозитории — ноль вхождений |
| D4 | Приложение грузит модуль | `main.cpp`: `QQmlApplicationEngine` + `loadFromModule`, проверка результата (пустые `rootObjects()` → ненулевой код выхода); окно собирается на `win-ninja-debug` |
| D5 | Приёмка модуля — тесты | `ui/module/smoke` зелёный с `ENVIRONMENT=QT_QPA_PLATFORM=offscreen`, под `LABELS smoke`; `ctest -L smoke` → `Total Tests: 2` |
| D6 | Negative control | `ui/negative/*` под `WILL_FAIL`: доказывает, что прогон доходит до Qt-кода; в отчёте — строка, которую ловит инверсия |
| D7 | Статический контур | `all_qmllint` зелёный; qmllint/qmlformat под CTest с `LABELS static`; `qmlformat -i` в пайплайне не используется (проверить grep-ом по CI-файлам, когда они появятся в 12.3) |
| D8 | Граф и окружение зафиксированы | обновлённый `deps.dot`; `CMakeUserPresets.json` c `CMAKE_PREFIX_PATH` (в игноре); в `build/win-ninja-debug/CMakeCache.txt` — `Qt6_VERSION` 6.10.x |
| D9 | ADR-0002 закрыт «до конца» | в черновике (создаёт владелец) — четыре имени: продукт / `tw::` namespace / include-путь / **URI QML-модуля**, и таблица кандидатов с отказом от `TrafficWatcher.UI` или его защитой; строка 13 плана модуля 2 помечает решение принятым |
| D10 | Индекс | ≥3 коммита по причине (граф Qt / модуль и типы / тесты и lint), тег `m02-done`, `answers/02-qt6-in-cmake.md` заполнен |

### Прямые шаги

Порядок — по однослойности ошибки: сначала файлы, где ошибиться негде, кроме синтаксиса; потом
модуль и граф; потом окружение; потом тесты и статика.

**Шаг 1 — QML-файлы: `ui/Main.qml`, `ui/LightBulb.qml` (D2).** В `Main.qml` должно быть:
`import QtQuick`, `import QtQuick.Controls`, корень `ApplicationWindow` (артефакт [`course.md:129`](../course.md#L129)),
один экземпляр будущего C++-типа или QML-компонента модуля **без** импорта собственного URI;
в `LightBulb.qml` — `required property` (форма из цикла 3 (8)). Проверка: `qmlformat ui/Main.qml`
→ вывод без сообщений об ошибках парсинга (формат — второй; проверки — в шаге 8).

**Шаг 2 — класс: `ui/LightBulb.h` / `ui/LightBulb.cpp` (D3).** В заголовке: include
`<QtQml/qqmlregistration.h>` первой группой Qt-include-ов; класс — QObject-derived с `Q_OBJECT`
и `QML_ELEMENT`; минимум один `Q_PROPERTY` с NOTIFY и типом-enum, а не `int`; значения enum —
через `Q_ENUM`. В `.cpp` — минимум одна non-inline функция (иначе таргету нечего компилировать).
Проверка: `Select-String ui/LightBulb.h -Pattern "QML_ELEMENT|qqmlregistration"` → обе строки; `git grep -n qmlRegisterType` → пусто.

**Шаг 3 — определение модуля: `ui/CMakeLists.txt` (D2, D4).** В файле: `qt_add_qml_module(tw_ui …)`
с URI из ADR-0002 (ровно тем же, что в шаге 4 и в `Main.qml`); `QML_FILES` и `SOURCES` — явные
списки шагов 1–2; `DEPENDENCIES QtQuick` (базовый класс/типы — по тонкости 1 цикла 2);
`target_link_libraries(tw_ui PUBLIC tw::core Qt6::Quick)`; ни `RESOURCE_PREFIX`, ни
`OUTPUT_DIRECTORY`, ни `QT_QML_OUTPUT_DIRECTORY` (modernizing-страница — блок 8). Проверка:
`cmake --preset win-ninja-debug` без warning-а про структуру каталога;
`Test-Path build/win-ninja-debug/<target-path>/qmldir` → `True` (путь — сегменты URI).

**Шаг 4 — точка входа: `app/` (D4).** В `app/CMakeLists.txt`: `target_link_libraries(tw_app
PRIVATE tw::ui)` (для STATIC-модуля plugin-таргет линковать не нужно — сравни с kdenlive-парадом
в self-check 3; если делаешь SHARED/модуль-потребителем — линкуй и `tw_uiplugin`, и добавь
`QML_IMPORT_PATH` на каталог build-дерева модуля). В `app/src/main.cpp`: `QQmlApplicationEngine`,
`loadFromModule("<модуль>", "Main")`, путь `ui/`-модуля — **та же строка, что в CMake** (проверка —
сообщение об ошибке, если ошиблась); `qmlRegisterType` — ни одного. Проверка: запуск из шага
цикла 3 даёт окно; временный брак URI (`"trafficwatcher2"`) даёт сообщение engine в консоли — убедиться и откатить.

**Шаг 5 — тесты: `tests/` (D5, D6).** В `QmlSmoke_test.cpp` — слот с `loadFromModule` +
`QVERIFY2(!rootObjects().isEmpty(), …errors()…)`; в `tests/CMakeLists.txt` — `qt_add_executable`
+ `PRIVATE tw::ui Qt6::Test` + `add_test(NAME ui/module/smoke …)` + `set_tests_properties`
(`LABELS "smoke"`, `TIMEOUT 30`, `ENVIRONMENT "QT_QPA_PLATFORM=offscreen"`); отдельный negative
под `WILL_FAIL` + `LABELS "negative"`. Всё под гейтом `BUILD_TESTING` (урок 01). Проверка:
`ctest --preset win-ninja-debug -L smoke --output-on-failure` → два `Passed`; `ctest --preset win-ninja-debug -L negative` → Passed на инвертированном.

**Шаг 6 — статика: `tests/CMakeLists.txt` или `cmake/TwQmlLint.cmake` (D7).** Регистрация
`ui/qmllint` и `ui/qmlformat` тестами по образцу цикла 5: `LABELS "static"`, `DISABLED` на
VS-пресете (см. цикл 5 (6)), сравнение вывода `qmlformat` без `-i`. Проверка:
`cmake --build build/win-ninja-debug --target all_qmllint` → успех;
`ctest --preset win-ninja-debug -L static` → зелёный набор (на этой машине — после установки
`Qt6::` инструментов; если qmllint не в `PATH` — полный путь из кита, `$env{}`-приём урока 01).

**Шаг 7 — корень и окружение: `CMakeLists.txt`, `CMakeUserPresets.json` (D1, D8).** В корне:
`find_package(Qt6 6.10 REQUIRED COMPONENTS Quick QuickControls2 Test)` до первого таргета;
`qt_standard_project_setup(REQUIRES 6.10)`; `add_subdirectory(ui)` между `core` и `app`;
ни `CMAKE_AUTOMOC/AUTORCC/AUTOUIC` руками, ни `D:/`-путей. В `CMakeUserPresets.json` (в игноре,
[`.gitignore:32`](../../.gitignore#L32)) — `CMAKE_PREFIX_PATH` на кит. Проверка:
`Select-String CMakeLists.txt -Pattern "AUTOMOC|PREFIX_PATH"` → пусто; цепочка
`cmake --preset win-ninja-debug; cmake --build --preset win-ninja-debug; ctest --preset win-ninja-debug` — зелёная целиком; `--graphviz` обновлён (D1).

**Шаг 8 — документация и индекс (D9, D10).** ADR-0002 черновик (не пишет ассистент, форма —
`docs/adr/template.md`); `answers/02` заполнен; `.gitignore` не прячет ни один новый файл:
`git check-ignore -v ui/CMakeLists.txt ui/LightBulb.h; $LASTEXITCODE` → код **1**;
`git log --oneline -8` — три причины разделены; тег `m02-done`.

### Чего не делаем

* `qt_add_test()`, `QT_QPA_PLATFORM=minimal`-матрицы, фикстуры, `--output-junit` — модуль 8
  (свой `qt_add_test` оставлен там же, где задуман планом, — строка 8.2).
* Quick Test на `.qml`-файлах (`TestCase`), contract/golden — модуль 9; здесь только QTest C++.
* `QML_SINGLETON` темы, `qmlformat --write-defaults`, дизайн-токены — модуль 14; `pragma Singleton`
  из старого `Theme.qml` не переносится (долг записан в тонкости 2 цикла 3).
* `qt_generate_deploy_qml_app_script`, `DISCARD_QML_CONTENTS` в поставке, `windeployqt` — модули
  9.1/11; `DISCARD_QML_CONTENTS` здесь только разобран (тонкость 3 цикла 2), в сборку не входит.
* `qt_add_translations`/`I18N_TRANSLATED_LANGUAGES` — модуль 13.4; i18n-слой карточки
  `qt_standard_project_setup` в уроке не используется.
* Собственный стиль Controls, `QQuickStyle` — модуль 14; `DEPENDENCIES`/`IMPORTS` для чужих
  QML-модулей-библиотек — только когда появится второй модуль (модуль 14 же).

## Блок 7. Приёмка

### Рубрика DoD

| Пункт | Зачтено | С оговоркой | Не зачтено |
|---|---|---|---|
| D1 | `find_package` с версией и REQUIRED; `Qt6_VERSION` в кэше 6.10.x | версия есть, `REQUIRES` в setup нет (политики включены `qt_policy` вручную) | Qt ищется `if(EXISTS)`-веткой или путь хардкодом |
| D2 | warning при конфигурации нет; `qmldir` только в build-дереве | warning есть, но каталоги согласованы с URI | `qmldir`/`.qrc` в исходниках |
| D3 | `QML_ELEMENT` + include; генерируемая регистрация содержит класс | макрос есть, `qqmlregistration.h` включён косвенно через чужой заголовок | `qmlRegisterType` живёт в `main.cpp` |
| D4 | загрузка через `loadFromModule`, ошибка видна в консоли процесса | `load("qrc:/qt/qml/…")` работает, но порт-гид не соблюден | путь к qrc руками |
| D5 | `-L smoke` = 2 Passed, один — QML, headless | QML-тест проходит только с дисплеем | offscreen не настроен |
| D6 | negative control ловит «прогон не доходит до Qt» | WILL_FAIL без комментария-причины | инверсия на основном тесте |
| D7 | `all_qmllint` зелёный, qmlformat-сравнение под CTest | lint только build-целью, без файлового прохода | `--check` в CI-шпаргалке, «всегда красный» |
| D8 | `deps.dot` с двумя новыми рёбрами; юзер-пресет в игноре | граф не обновлён, рёбра видны из лога сборки | абсолютный путь к киту в git |
| D9 | ADR-0002 с четырьмя именами и таблицей кандидатов | URI выбран, обоснование на одну строку | решение «как в уроке» без ADR |
| D10 | 3+ коммита по причине, тег, ответы | коммитов два, границы причин названы | «модуль 2» одним |

### Self-check

**1.** Чем `DEPENDENCIES QtQuick` отличается от `target_link_libraries(tw_ui PUBLIC Qt6::Quick)`?
<details><summary>Ответ</summary>Первое — метаданные QML-модуля (qmltyperegistrar/qmldir/qmllint
видят базовые типы), второе — C++-требования (заголовки, линковка). Одно без другого работает
половинчато: без линковки не соберётся, без `DEPENDENCIES` — битая/пустая модель типов для потребителей и qmllint (ECM-формулировка: DEPENDENCIES обязателен для QML-видимого C++).</details>

**2.** Почему пустой `QML_ELEMENT` (без include) не ломает сборку, и чем проверить, что
регистрация случилась?
<details><summary>Ответ</summary>Макрос из `QtQml/qqmlregistration.h`; без него идентификатора
нет — в зависимых TU он просто не объявлен, а в самом заголовке компилятор его не видел бы только
если он раскрывается в пустоту (механизм — тонкость 1 цикла 3). Проверка — не сборка, а сгенерированный init-файл (`*qmlreg*`) и рантайм-загрузка в smoke-тесте.</details>

**3.** `tw_app` линкует `tw::ui`, `loadFromModule` в `main.cpp` — `module not found`. Три места,
куда смотреть, в порядке вероятности?
<details><summary>Ответ</summary>(а) не зарегистрированы типы: LightBulb вне `SOURCES`/без макроса;
(б) URI рассинхрон CMake ↔ C++ строка; (в) модуль живёт как отдельный plugin-таргет, который
не прилинкован и не в `QML_IMPORT_PATH` (случай SHARED; парный линк `kdenliveLib + kdenliveLibplugin`).</details>

### Exit ticket

Две строки: (а) какой из трёх «несуществующих» фактов (matrixPresets, QTP0081, qmlformat --check)
удивил и почему; (б) что в уроке 3.1 (`std::format`/concepts поверх этих классов) потребует
изменений в `ui/` — без (б) следующий урок пишется вслепую.

**Что назвать в отчёте о закрытии** ([`methodology.md`](../methodology.md) §4): конструкцию урока 01, которая здесь изменила поведение — например, `PUBLIC tw::core` из урока 01 стал причиной, по которой `LightBulb.h` вообще компилируется; или `LABELS smoke`, под который встал второй тест.

### История: как было в Qt5 → как стало → что это даёт

| Было (`44ffd1b`) | Стало | Что это даёт |
|---|---|---|
| `find_package(Qt5)`, `Qt5::Core`, `CMAKE_PREFIX_PATH` хардкодом ([`:20`](../legacy-description.md#L20)) | `find_package(Qt6 6.10 REQUIRED …)`, путь из пресета | на CMake 4.x Qt5-конфиги уже не работают (находка `4`), а путь в git не ломает чужую машину |
| `CMAKE_AUTOMOC/AUTORCC/AUTOUIC` руками ([`:20`](../legacy-description.md#L20)) | `qt_standard_project_setup()` (две переменные, не три) | стандартизированное поведение + политики `QTP…` одним ключом `REQUIRES` |
| 4× `qmlRegisterType`, ручной `qmldir`, `.qrc` ([`:27–30`](../legacy-description.md#L27)) | `qt_add_qml_module` + `QML_ELEMENT` | одна точка синхронизации вместо четырёх; живёт в статических сборках; включаются qmlcachegen и lint-цели |
| `engine.load("qrc:/qml/main.qml")` | `loadFromModule("trafficwatcher", "Main")` | грузится **модуль**, а не путь; переукладка ресурсов не видна коду |
| `option(BUILD_TESTS)` + тесты без CTest-свойств ([`:57`](../legacy-description.md#L57)) | `BUILD_TESTING` (урок 01) + `ENVIRONMENT`/`LABELS`/`WILL_FAIL` | «Доработка тесты (не работают)» закрывается механикой, а не везением |

## Блок 8. Справка и «дальше»

### Сводка урока: конструкции

| Конструкция | Полная форма (категория) | Ключевые аргументы | Где применима | Где неприменима | Best practice + следствие | Тонкость | Чем проверить |
|---|---|---|---|---|---|---|---|
| `find_package(Qt6 …)` | команда CMake: `find_package(<PackageName> [<version>] [REQUIRED] [COMPONENTS <components>...])` | `<version>` = минимум; `COMPONENTS` = нужные `Qt6::*` | корень, до первого таргета | вместо `FetchContent`-сборки Qt из исходников (модуль 12.1 — другой вопрос) | `REQUIRED` + версия; иначе `Unknown CMake command "qt_standard_project_setup"` | компоненты ≠ линковка: ищут больше, чем линкуют (qt-creator) | `cmake --help-command find_package`; вывод `Qt6Config` в логе |
| `qt_standard_project_setup` | команда Qt (с 6.3): `[REQUIRES <ver>] [SUPPORTS_UP_TO <ver>] [I18N_TRANSLATED_LANGUAGES <lang>...] [I18N_SOURCE_LANGUAGE <lang>]` | `REQUIRES` = baseline ADR-0001 | сразу после `find_package`, до таргетов | после `add_subdirectory`: ранее объявленные цели не получат AUTOMOC; сама команда не включает `AUTORCC` | `REQUIRES 6.10`; иначе политики не включены, поведение qmlcachegen/ресурсов — старое | ставит `CMAKE_AUTOMOC/AUTOUIC` только «if not already defined» — унаследованное значение побеждает молча | `cmake --help-command qt_standard_project_setup`; [страница команды](https://doc.qt.io/qt-6/qt-std-project-setup.html) |
| `qt_policy` | команда Qt (с 6.5): `qt_policy([SET <policy> NEW\|OLD] [GET <policy> <var>])` | `QTP0001`…`QTP0008` | когда политику надо зафиксировать точечно, не весь `REQUIRES`-блок | для `CMP…` — там `cmake_policy`, номера смешивать нельзя | явный `SET QTP0001 NEW` рядом с `REQUIRES`; иначе «какое поколение принято» не видно в репозитории | существование проверяют `QT_KNOWN_POLICY_QTP<NNNN>`; `QTP0081` не существует (реестр: QTP0001–QTP0008) | [Qt CMake policies](https://doc.qt.io/qt-6/cmake-qt-policies.html), `cmake --help-command qt_policy` |
| `qt_add_qml_module` | команда Qt (с 6.2): `qt_add_qml_module(target URI <uri> [VERSION] [QML_FILES…] [SOURCES…] [RESOURCES…] [PLUGIN_TARGET] [NO_PLUGIN] [DEPENDENCIES…] [IMPORTS…] [OUTPUT_DIRECTORY] [DISCARD_QML_CONTENTS] …)` | URI + каталоги = target path; backing + plugin-таргет | один вызов на QML-модуль (`tw_ui`) | не для «просто добавить .qml в exe» без модуля — там достаточно `qt_add_resources` (проверь форму) | явные списки, без `RESOURCE_PREFIX`/`OUTPUT_DIRECTORY` при правильном layout; иначе две копии `qmldir` и рассинхрон импортов | каталог ≠ target path — warning, сборка зелёная, импорт падает в рантайме; `DISCARD_QML_CONTENTS` (6.10) привязывает `.qsb` к версии qmlcachegen | [страница команды](https://doc.qt.io/qt-6/qt-add-qml-module.html) (в `--help-command` CMake её нет — это команда Qt); создаваемые цели: `--target help`, `all_qmllint` |
| `QML_ELEMENT` (семейство: `QML_NAMED_ELEMENT`, `QML_UNCREATABLE`, `QML_SINGLETON`, `QML_FOREIGN`, `QML_VALUE_TYPE`, `QML_ANONYMOUS`, `QML_INTERFACE`) | макросы C++ (Qt 6), в объявлении класса/гаджета | требуется `#include <QtQml/qqmlregistration.h>`; класс — в таргете `qt_add_qml_module` | публикация типа домена (`LightBulb`) | `QML_VALUE_TYPE` — только Q_GADGET, имя строчное, не singleton; QObject-типы им не публикуются | регистрация у объявления, а не в main; иначе 4 строки `qmlRegisterType` = 4 точки рассинхрона (legacy-находка `3`) | без include макрос раскрыт в пустоту: сборка зелёная, тип неизвестен в рантайме | [Defining types for QML](https://doc.qt.io/qt-6/qqmlregistration-definetypes.html); генерируемый `*qmlreg*` в build-дереве |
| `qt_add_executable` | команда Qt: wrapper над `add_executable` (`qt_add_executable(<target> <sources>...)`) | тот же смысл + обработка static-Qt (плагины), платформенные имена | `tw_app`, `tw_ui_smoke` | не даёт `add_test` — регистрация теста отдельно; не нужен в pure-Qt-free таргетах (`tw_core`) | цели приложения — через обёртку Qt6 (`cmake-get-started` использует её весь); иначе ручная линковка плагинов в static-сборках | для `tw_core` её нет: QtCore там не появилось — намеренно (модуль 6.1) | [Getting started with CMake](https://doc.qt.io/qt-6/cmake-get-started.html) |
| `loadFromModule` | метод `QQmlApplicationEngine` (since 6.5): `void loadFromModule(QAnyStringView uri, QAnyStringView typeName)` | модуль + тип, не путь | `main.cpp`, smoke-тест | `QtObject`-root с `ApplicationWindow`-требованиями окна — проверь поведение под offscreen; `QQmlComponent::loadFromModule` — другой overload (страница) | loadFromModule вместо `load("qrc:/…")`; иначе путь в ресурсах — часть API приложения | конструктор `QQmlApplicationEngine(QObject*, QAnyStringView, QAnyStringView)` — convenience, не обязателен | [QQmlApplicationEngine](https://doc.qt.io/qt-6/qqmlapplicationengine.html) (строка «since 6.5» сверена 25.11.2026) |
| `ENVIRONMENT` / `WILL_FAIL` (CTest) | свойства теста (`set_tests_properties`) | `ENVIRONMENT "VAR=value;…"`, инверсия результата | offscreen smoke, negative control | не заменяют `WORKING_DIRECTORY` для поиска файлов; `WILL_FAIL` инвертует всё, включая «бинарник не найден» | negative control обязателен с первого UI-теста; иначе красный CI неотличим от сломанного пайплайна | см. тонкость 4 цикла 4: `COMMAND <file.exe>` без target-формы → `Not Run`, код 8 | `ctest --help-property ENVIRONMENT`, `--help-property-list` |
| `all_qmllint` / `<target>_qmllint` | build-цели, создаваемые `qt_add_qml_module` | цель сборки, не тест | CI-шаг «собрать цель»; обвязка под CTest — цикл 5 | на VS-пресете без `compile_commands.json` — слепой lint (урок 01, тонкость 3) | линтеруют модель модуля, а не каталог вслепую; иначе «Unqualified access»-шум | `qmlformat --check` не существует (замер по официальной странице 25.11.2026) | `qmllint --help`, `qmlformat --help`, [qmlformat page](https://doc.qt.io/qt-6/qmlformat-tool.html) |

### Глоссарий урока

| Термин | Дальше идёт без перевода |
|---|---|
| backing target | таргет, в который скомпилированы C++-код и сгенерированная регистрация модуля (`tw_ui`) |
| plugin target | `tw_uiplugin`: регистрация модуля отдельной библиотекой (дефолт — `<backing>plugin`) |
| target path модуля | URI с точками → `/`; задаёт структуру каталогов и `OUTPUT_DIRECTORY` по умолчанию |
| qmldir | манифест модуля; в Qt6 генерируется, руками не пишется |
| qmlcachegen / `.qsb` | байткод QML в ресурсах рядом с оригиналом; `.qsb` привязан к версии генератора |
| `QTP…`-политика | поколение поведения Qt6 CMake-API (не путать с `CMP…` CMake) |
| QML-модуль (URI) | единица импорта в QML; API поставки уровня имени (ADR-0002) |
| offscreen | `QT_QPA_PLATFORM=offscreen`: GUI-код без дисплея |

### Диагностика: симптом → настоящая причина → где чинить

| Симптом | Настоящая причина | Где чинить |
|---|---|---|
| `Could not find a package configuration file provided by "Qt6"` | нет кита в `CMAKE_PREFIX_PATH`/`QTDIR`; список путей — в тексте ошибки | цикл 1 (1), (9); шаг 7 |
| `Unknown CMake command "qt_standard_project_setup"` | `find_package(Qt6 Core)` не вызван или упал без `REQUIRED` | цикл 1 (1) |
| `This application failed to start because no Qt platform plugin could be initialized` | headless-среда без `QT_QPA_PLATFORM=offscreen` | цикл 4 (7) |
| `module "trafficwatcher.ui" was not found` | рассинхрон URI↔каталоги, либо модуль не прилинкован к процессу | циклы 2 (1), 4 (5) |
| `LightBulb is not defined` при зелёной сборке | нет `#include <QtQml/qqmlregistration.h>` / класс вне `SOURCES` | цикл 3, тонкость 1 |
| warning «source directory structure … does not match» | layout не по target path | цикл 2 (1), тонкость 2 |
| `undefined reference to vtable for LightBulb` | moc не запустился: setup после таргетов либо `CMAKE_AUTOMOC=OFF` унаследован | цикл 1, тонкость 1–2 |
| qmllint: `Unqualified access` на всё подряд | lint без модели модуля (нет import-путей/`--project`) | цикл 5 (1)–(2) |
| `qmlformat: Unknown option '--check'` | флага не существует | цикл 5, «Ловушка» |
| ctest: `Not Run`, код 8 | `COMMAND` — литеральный путь `.exe`, а не таргет | цикл 4, тонкость 4 |
| QML-окно не грузит тему/стиль (будущее) | `DEPENDENCIES`/`IMPORTS` не описывают чужой QML-модуль | цикл 2, тонкость 1; модуль 14 |

### Подмеченные ошибки в текущем состоянии репозитория

* [`course.md:126`](../course.md#L126) — политика `QTP0081` не существует (реестр QTP0001–QTP0008,
  проверка 25.11.2026). Правка строки — за владельцем; урок проверяет её в «Ловушке» цикла 2.
* [`course.md:130`](../course.md#L130) — `qmlformat --check`: флага нет у инструмента (страница
  qmlformat, тот же замер). Формулировку приёмки стоит заменить на «qmlformat в CI (сравнение
  вывода)» — тоже решение владельца плана.
* [`readme.md:149`](../readme.md#L149) — мост курса обещает URI вида `trafficwatcher/<подмодуль>`;
  в плане урока 2.2 пример `TrafficWatcher.UI` ([`legacy-description.md:66`](../legacy-description.md#L66)).
  Два документа расходятся — ADR-0002 обязан выбрать (D9), до выбора в уроке везде стоит
  `trafficwatcher.ui` как кандидат, а не решение.
* [`legacy-description.md:49`](../legacy-description.md#L49) — находка `3` описывает ровно механику
  циклов 2–3: пока `ui/` не пересобран этим уроком, это единственный живой дефект-источник урока.
* [`.gitignore:34–45`](../../.gitignore#L34) — Qt-блок игнорирует `moc_*.cpp`, `qrc_*.cpp`, `*.qm`:
  легитимный источник генерации — только build-каталог, и если `moc_*` появится в `ui/` — это
  симптом ручного вызова moc (проверка: `git status --porcelain` после сборки).
* [`CMakeLists.txt:3`](../../CMakeLists.txt#L3) — если урок 01 ещё не закрыт, пин `4.3.2`
  актуален и блокирует конфигурацию из бандла CLion; этот урок на нём не стоит, но шаг 7 чинит и его.

### Инвентарь окружения (замер 25.11.2026)

* `C:\Qt` содержит `5.15.2` (+ `Docs`, `Examples`, `Tools`) — **Qt 6.10.2 не установлен**; каталога
  `cmake-build-debug/` на диске нет; `cmake` — 4.3.2 (`PATH`), бандл CLion — 4.2.2 (уроки 00–01).
  Все сборки/тесты этого урока — замеры читателя, вносится в таблицу после своего прогона.
* Документационные факта, проверенные ассистентом 25.11.2026 (версия страниц — Qt 6.12.1,
  если не сказано иное): synopsis `qt_add_qml_module` (включая `DISCARD_QML_CONTENTS`,
  `NO_GENERATE_QTCONF` помечен «since Qt 6.12»); текст «should match the target path … will issue
  a warning» и пример `MyUpperCaseThing/mylowercasething/`; `qt_standard_project_setup` — только
  AUTOMOC/AUTOUIC «if not already defined», без AUTORCC; `QQmlApplicationEngine::loadFromModule`
  — `[slot, since 6.5]`, `QAnyStringView`; реестр политик QTP0001–QTP0008; список опций qmlformat
  без `--check`; What's New 6.10: `FooPrivate` через явный `COMPONENTS`, `NO_PLUGINS`/`INCLUDE_PLUGIN_TYPES`/`EXCLUDE_PLUGINS` у `qt_deploy_runtime_dependencies`.
* Не сверено (в уроке помечено «проверь»): существование/семантика `QTEST_QMLGUI_MAIN` в 6.10;
  `qt_add_test()` (отложено в 8.2); опции `qmllint --project`/`--max-warnings` на 6.10; имена
  генерируемых файлов регистрации; поведение `RESOURCES`-псевдонима. Upstream (qt-creator,
  kdenlive, ECM, shotcut) изучены 25.11.2026 в `master`/`develop`; номера строк смещаются.

### Что читать

1. **Разбор чужого кода (обязательный пункт).** [kdenlive `src/CMakeLists.txt`](https://invent.kde.org/video/kdenlive/-/blob/master/src/CMakeLists.txt)
   — найди в нём все четыре конструкции цикла 2 (`ecm_add_qml_module`, `DEPENDENCIES`, линк
   `kdenliveLib + kdenliveLibplugin`, `add_dependencies(kdenlive all_qmllint)`) и ответь: что делает
   ECM-обёртка **сверх** `qt_add_qml_module` (подсказка — `ecm_finalize_qml_module` и смысл
   `GENERATE_PLUGIN_SOURCE`), и почему KDE не зовёт qt-команду напрямую. Ответ — на строках файла.
2. [ECM `ECMQmlModule.cmake`](https://invent.kde.org/frameworks/extra-cmake-modules/-/blob/master/modules/ECMQmlModule.cmake)
   — комментарии про `DEPENDENCIES`/`IMPORTS` и `PRIVATE`→`QT_QML_INTERNAL_TYPE`; это самый подробный разбор тонкости 1 цикла 2 вне документации Qt.
3. [Porting to qt_add_qml_module](https://doc.qt.io/qt-6/qt6-port-to-qt-add-qml-module.html) и
   [Modernizing QML modules](https://doc.qt.io/qt-6/qt6-modernize-qml-modules.html) — таблицы
   «было → стало» и список устаревших keyword-ов (`RESOURCE_PREFIX`, `IMPORT_PATH`,
   `QT_QML_OUTPUT_DIRECTORY` против `DEPENDENCIES TARGET`).
4. Инструменты на своей машине: `cmake --help-command find_package`, страница
   `qt_standard_project_setup`, `qt_policy`, `ctest --help-property ENVIRONMENT`,
   `qmllint --help`, `qmlformat --help`. Уроки курса: [01](01-cmake-target-graph.md) (граф,
   пресеты, CTest), [course.md](../course.md) модуль 8.2 (`qt_add_test()`), модуль 11.1 (деплой QML-приложения).

### Итог урока

* **ADR:** **0002** закрывает выбор URI (D9; реестр и очередь — [`adr/readme.md`](../adr/readme.md));
  подтверждает 0001 (кит 6.10.x под компилятор ADR) и 0004 (`ui/` в layout занят). Черновики создаёт
  владелец; ассистент проверяет форму по [`template.md`](../adr/template.md).
* **Файлы:** `ui/{CMakeLists.txt, LightBulb.h, LightBulb.cpp, Main.qml, LightBulb.qml}` (имена/раскладка —
  по выбранному URI), правки `CMakeLists.txt` (корень), `app/{CMakeLists.txt, src/main.cpp}`,
  `tests/{CMakeLists.txt, src/QmlSmoke_test.cpp}`; опционально `cmake/TwQmlLint.cmake`; ADR-0002; тег `m02-done`.
* **Состояние, с которым открывается следующий урок:** Qt6 — узел графа с политиками `QTP`;
  `trafficwatcher.ui` грузится `loadFromModule` в app и в smoke-тесте headless; типы домена
  опубликованы макросами; qmllint/qmlformat под CTest; `Mode.hpp` — строительный, живой со
  следующего урока (6.1 — замена).
* **Следующий урок:** модуль 3 «C++20 в Qt-коде» ([`course.md`:137](../course.md#L137)) —
  `constexpr`/concepts/Ranges поверх `LightBulb`/`TrafficLightState`; механика сборки там не меняется,
  меняется содержимое заголовков, которые этот урок сделал частью API.
* **Выброшено из урока намеренно:** `QTP0081` (не существует), `qmlformat --check` (не существует),
  `qt_add_test()` (несверенная версия появления — 8.2), `DISCARD_QML_CONTENTS` в dev-сборке
  (привязка `.qsb` к генератору — 11.x), Quick Test/golden (модуль 9), переводы (13.4).
