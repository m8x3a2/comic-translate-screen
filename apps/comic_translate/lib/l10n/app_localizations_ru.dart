// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Comic Translate Screen';

  @override
  String get homeTagline => 'Перевод комиксов на вашем компьютере';

  @override
  String get openFiles => 'Открыть файлы…';

  @override
  String get openFolder => 'Открыть папку…';

  @override
  String get addPages => 'Добавить страницы';

  @override
  String get dropHint => 'или перетащите файлы в это окно';

  @override
  String get supportedFormats =>
      'Картинки (PNG, JPG, WEBP, BMP), архивы комиксов (CBZ, ZIP, EPUB, CBR, CB7, CBT) и PDF';

  @override
  String get privacyLocal =>
      'Всё работает на этом компьютере, ничего никуда не отправляется.';

  @override
  String privacySends(String host) {
    return 'Для перевода текст отправляется на $host';
  }

  @override
  String get importing => 'Открываю файлы…';

  @override
  String importFailed(String name, String error) {
    return 'Не удалось открыть $name: $error';
  }

  @override
  String skippedFiles(String names) {
    return 'Пропущено (не картинки, не архивы и не PDF): $names';
  }

  @override
  String get noPagesFound => 'В выбранных файлах не найдено страниц';

  @override
  String get closeAll => 'Закрыть все страницы';

  @override
  String get closeAllConfirm =>
      'Закрыть все страницы? Неэкспортированные переводы пропадут.';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Сохранить';

  @override
  String get removePage => 'Убрать страницу';

  @override
  String get translateAll => 'Перевести всё';

  @override
  String get translateAgain => 'Перевести заново';

  @override
  String get stop => 'Остановить';

  @override
  String get stopping => 'Останавливаю…';

  @override
  String get report => 'Отчёт';

  @override
  String get export => 'Экспорт';

  @override
  String get settings => 'Настройки';

  @override
  String get sourceLanguage => 'Язык оригинала';

  @override
  String get targetLanguage => 'Язык перевода';

  @override
  String get viewOriginal => 'Оригинал';

  @override
  String get viewTranslated => 'Перевод';

  @override
  String get showBoxes => 'Рамки текста';

  @override
  String get zoomFit => 'По размеру окна';

  @override
  String get zoomActual => 'Исходный размер';

  @override
  String get zoomIn => 'Увеличить';

  @override
  String get zoomOut => 'Уменьшить';

  @override
  String get notTranslatedYet => 'Эта страница ещё не переведена';

  @override
  String pageEnlarged(String factor) {
    return 'Увеличена ×$factor для чёткого текста';
  }

  @override
  String get textPanel => 'Текст';

  @override
  String get noTextFound => 'На странице не найден текст';

  @override
  String get translateToSeeText =>
      'Переведите страницу, чтобы увидеть здесь её текст';

  @override
  String get stageLoading => 'Загрузка моделей';

  @override
  String stageDownloading(String percent) {
    return 'Скачивание моделей: $percent%';
  }

  @override
  String get stageDetect => 'Поиск текста';

  @override
  String get stageOcr => 'Распознавание текста';

  @override
  String get stageTranslate => 'Перевод';

  @override
  String get stageClean => 'Удаление текста';

  @override
  String get stageRender => 'Наложение перевода';

  @override
  String get stageExport => 'Сохранение';

  @override
  String progressPage(String current, String total) {
    return 'Страница $current из $total';
  }

  @override
  String remaining(String time) {
    return 'осталось около $time';
  }

  @override
  String pagesSummary(String total, String done) {
    return 'Страниц: $total, переведено: $done';
  }

  @override
  String statusSkipped(String reason) {
    return 'Пропущена: $reason';
  }

  @override
  String get statusDone => 'Переведена';

  @override
  String get statusRunning => 'Обрабатывается';

  @override
  String get reportTitle => 'Отчёт о переводе';

  @override
  String reportSummary(String done, String total, String time) {
    return 'Переведено $done из $total страниц за $time';
  }

  @override
  String get reportCancelled => 'Остановлено до конца';

  @override
  String get reportSkipped => 'Пропущенные страницы';

  @override
  String reportExported(String path) {
    return 'Текст и очищенные страницы сохранены в $path';
  }

  @override
  String get reportNoSkipped => 'Все страницы обработаны.';

  @override
  String reportStopped(String reason) {
    return 'Перевод остановлен: $reason. Остальные страницы не отправлялись.';
  }

  @override
  String get missingKeyTitle => 'Нужен ключ API';

  @override
  String missingKeyBody(String name, String host) {
    return '«$name» отправляет текст на $host, а там нужен ключ API. Укажите его в «Настройки → Переводчик» (он хранится в защищённом хранилище Windows) или выберите локальный переводчик.';
  }

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get exitTitle => 'Закрыть программу?';

  @override
  String exitBody(String count) {
    return 'Переведённых, но не экспортированных страниц: $count. Они пропадут.';
  }

  @override
  String get exitAnyway => 'Закрыть';

  @override
  String get showInFolder => 'Показать в папке';

  @override
  String get goToPage => 'Перейти к странице';

  @override
  String reasonModelMissing(String name) {
    return 'модель «$name» не скачана';
  }

  @override
  String get reasonImage => 'не удалось прочитать картинку';

  @override
  String get reasonWorkerStopped =>
      'обработка страниц неожиданно остановилась (подробности в журнале; в настройках можно собрать отчёт об ошибке)';

  @override
  String withDetails(String text, String details) {
    return '$text (подробности: $details)';
  }

  @override
  String get trErrConfig =>
      'переводчик не настроен: укажите адрес сервера и модель в настройках';

  @override
  String get trErrAuth =>
      'сервер не принял ключ API; проверьте ключ в настройках';

  @override
  String get trErrCredits =>
      'на счёте переводчика закончились деньги или кредиты';

  @override
  String get trErrNotFound => 'неверный адрес сервера или название модели';

  @override
  String get trErrRateLimit =>
      'сервер перегружен запросами и просит подождать; попробуйте позже';

  @override
  String get trErrServer => 'сбой на сервере переводчика; попробуйте позже';

  @override
  String get trErrNetwork =>
      'нет связи с сервером переводчика; проверьте интернет';

  @override
  String get trErrTimeout => 'сервер переводчика не ответил вовремя';

  @override
  String get trErrBadReply =>
      'переводчик ответил в виде, который программа не может прочитать';

  @override
  String get trErrOther => 'ошибка перевода';

  @override
  String get needsArchiveTool =>
      'для CBR, RAR, CB7 и 7Z нужен установленный 7-Zip (7-zip.org) или WinRAR';

  @override
  String exportFailed(String error) {
    return 'Не удалось сохранить страницы: $error';
  }

  @override
  String importedAs(String model) {
    return 'установлен как $model';
  }

  @override
  String get notAModelFile => 'не файл известной модели';

  @override
  String get unexpectedError =>
      'Что-то пошло не так. Подробности в журнале; отчёт об ошибке поможет это исправить.';

  @override
  String runFailed(String error) {
    return 'Не удалось начать: $error';
  }

  @override
  String get networkTitle => 'Отправлять текст через сеть?';

  @override
  String networkBody(String name, String host, String where) {
    return '«$name» отправляет распознанный текст на $host ($where).';
  }

  @override
  String get networkWhereLan => 'компьютер в вашей локальной сети';

  @override
  String get networkWhereCloud => 'сервис в интернете';

  @override
  String get networkBodyImage =>
      'Картинки страниц тоже отправляются (настройка «Отправлять картинку страницы»).';

  @override
  String get networkOffline =>
      'Чтобы работать полностью без сети, выберите локальный переводчик в настройках.';

  @override
  String get allowOnce => 'Разрешить сейчас';

  @override
  String get allowAlways => 'Всегда разрешать для этого сервера';

  @override
  String get downloadTitle => 'Скачать модели?';

  @override
  String downloadBody(String size) {
    return 'Нужны модели, которые ещё не скачаны (всего $size). Они сохранятся на компьютере и дальше будут работать без интернета.';
  }

  @override
  String downloadFrom(String size, String host) {
    return '$size, с $host';
  }

  @override
  String get download => 'Скачать';

  @override
  String downloadFailed(String error) {
    return 'Не удалось скачать: $error';
  }

  @override
  String get exportTitle => 'Выберите папку для переведённых страниц';

  @override
  String exportDone(String count, String path) {
    return 'Сохранено страниц: $count, папка $path';
  }

  @override
  String get nothingToExport => 'Пока нет переведённых страниц';

  @override
  String get settingsGeneral => 'Общие';

  @override
  String get settingsTranslator => 'Переводчик';

  @override
  String get settingsTools => 'Распознавание и очистка';

  @override
  String get settingsText => 'Текст';

  @override
  String get settingsUpscale => 'Увеличение';

  @override
  String get settingsExport => 'Экспорт';

  @override
  String get settingsModels => 'Модели';

  @override
  String get settingsAbout => 'О программе';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Как в Windows';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get uiLanguage => 'Язык интерфейса';

  @override
  String get useGpu => 'Использовать видеокарту (DirectML)';

  @override
  String get useGpuHelp =>
      'На некоторых компьютерах быстрее; если что-то не работает, автоматически используется процессор.';

  @override
  String get testMode => 'Режим тестирования';

  @override
  String get testModeHelp =>
      'Сохраняет все шаги каждого запуска для отчётов об ошибках (занимает место на диске).';

  @override
  String get openLogs => 'Открыть папку логов';

  @override
  String get bugReport => 'Собрать отчёт об ошибке';

  @override
  String get bugReportHelp =>
      'Архив с логами и настройками, без ключей и без картинок.';

  @override
  String bugReportDone(String path) {
    return 'Отчёт сохранён: $path';
  }

  @override
  String get translator => 'Переводчик';

  @override
  String get privacyLocalBadge => 'На этом компьютере';

  @override
  String get privacyLanBadge => 'Локальная сеть';

  @override
  String get privacyCloudBadge => 'Интернет';

  @override
  String sendsDataWarning(String host) {
    return 'Отправляет текст за пределы компьютера: $host';
  }

  @override
  String get savedSecurely =>
      'Хранится в защищённом хранилище Windows, никогда в файлах и логах.';

  @override
  String get secretSet => 'Сохранён';

  @override
  String get secretNotSet => 'Не задан';

  @override
  String get secretRemove => 'Удалить';

  @override
  String get approvals => 'Разрешённые серверы';

  @override
  String get approvalsNone => 'Пока нет; программа спросит перед отправкой.';

  @override
  String get revoke => 'Отозвать';

  @override
  String get extraContext => 'Дополнительный контекст для переводчика';

  @override
  String get extraContextHelp => 'Например, имена, мир или стиль комикса.';

  @override
  String get sendPageImage => 'Отправлять картинку страницы';

  @override
  String get sendPageImageHelp =>
      'Помогает некоторым моделям понять сцену; переводчику отправляется вся страница.';

  @override
  String get detector => 'Поиск текста';

  @override
  String get ocr => 'Распознавание текста';

  @override
  String get inpainter => 'Удаление текста';

  @override
  String get hdStrategy => 'Большие страницы';

  @override
  String get hdResize => 'Уменьшать';

  @override
  String get hdCrop => 'По фрагментам';

  @override
  String get hdOriginal => 'Исходный размер';

  @override
  String get resizeLimit => 'Предел размера (px)';

  @override
  String get cropMargin => 'Отступ фрагмента (px)';

  @override
  String get cropTrigger => 'Фрагменты начиная с (px)';

  @override
  String get upscaleSmallText =>
      'Увеличивать мелкий текст перед распознаванием';

  @override
  String get fixCyrillic => 'Исправлять латинские двойники в кириллице';

  @override
  String get fixCyrillicHelp =>
      '«HET» станет «НЕТ»; может задеть и латинские слова.';

  @override
  String get font => 'Шрифт';

  @override
  String get fontDefault => 'Pangolin (встроенный)';

  @override
  String get fontOther => 'Шрифт из Windows';

  @override
  String get fontOtherHint => 'Название шрифта, например Comic Sans MS';

  @override
  String get minFontSize => 'Наименьший размер (pt)';

  @override
  String get maxFontSize => 'Наибольший размер (pt)';

  @override
  String get textColor => 'Цвет текста';

  @override
  String get outline => 'Обводка';

  @override
  String get outlineColor => 'Цвет обводки';

  @override
  String get outlineWidth => 'Толщина обводки';

  @override
  String get upperCase => 'Заглавные буквы';

  @override
  String get alignment => 'Выравнивание';

  @override
  String get alignLeft => 'Слева';

  @override
  String get alignCenter => 'По центру';

  @override
  String get alignRight => 'Справа';

  @override
  String get placeInBlock => 'Центрировать текст в пузыре';

  @override
  String get lineSpacing => 'Межстрочный интервал';

  @override
  String get bold => 'Жирный';

  @override
  String get italic => 'Курсив';

  @override
  String get underline => 'Подчёркнутый';

  @override
  String get upscaleHelp =>
      'На маленьких страницах перевод рисуется на увеличенной копии, поэтому буквы остаются чёткими. Способ влияет только на рисунок.';

  @override
  String get upscaleMode => 'Когда увеличивать';

  @override
  String get upscaleAuto => 'Автоматически (маленькие страницы)';

  @override
  String get upscaleOff => 'Никогда';

  @override
  String get upscaleWidth => 'До ширины';

  @override
  String get upscaleWidthValue => 'Ширина (px)';

  @override
  String get upscaleMethod => 'Способ';

  @override
  String get upscaleFast => 'Быстро (Lanczos)';

  @override
  String get upscaleGood => 'Хорошо (нейросеть) — позже';

  @override
  String get upscaleBest => 'Лучше (большая нейросеть) — позже';

  @override
  String get imageFormat => 'Формат картинок';

  @override
  String get formatSource => 'Как у исходника';

  @override
  String get autoExport => 'После «Перевести всё» также сохранять';

  @override
  String get autoExportHelp =>
      'В папку comic_translate_<дата> рядом с исходными файлами.';

  @override
  String get exportRawText => 'Распознанный текст';

  @override
  String get exportTranslatedText => 'Переведённый текст';

  @override
  String get exportCleaned => 'Очищенные страницы';

  @override
  String get modelsFolder => 'Папка моделей';

  @override
  String get modelsFolderHelp =>
      'Уже скачанные модели не переносятся сами; скопируйте их или воспользуйтесь импортом.';

  @override
  String get changeFolder => 'Изменить…';

  @override
  String get defaultFolder => 'По умолчанию';

  @override
  String get open => 'Открыть';

  @override
  String get importModels => 'Импорт с диска…';

  @override
  String get importModelsHelp =>
      'Файлы моделей или zip-архивы с другого компьютера; распознаются по контрольной сумме.';

  @override
  String importModelsDone(String count) {
    return 'Установлено файлов моделей: $count';
  }

  @override
  String get modelInstalled => 'Скачана';

  @override
  String get modelMissing => 'Не скачана';

  @override
  String get modelCorrupt => 'Повреждена';

  @override
  String get verify => 'Проверить';

  @override
  String get delete => 'Удалить';

  @override
  String deleteModelConfirm(String name) {
    return 'Удалить «$name»? Её можно будет скачать снова.';
  }

  @override
  String get verifyOk => 'Файлы в порядке';

  @override
  String verifyBad(String files) {
    return 'Повреждённые файлы: $files';
  }

  @override
  String get aboutIndependent =>
      'Независимый проект на основе ogkalu2/comic-translate, не официальная версия.';

  @override
  String get aboutPrivacy =>
      'Без аккаунтов и без телеметрии. Данные уходят с компьютера только к выбранному вами переводчику, и программа сначала спрашивает.';

  @override
  String get license => 'Лицензия: Apache 2.0';

  @override
  String get dataFolder => 'Папка данных';

  @override
  String get thirdPartyLicenses => 'Лицензии компонентов';

  @override
  String version(String version) {
    return 'Версия $version';
  }

  @override
  String get drawingPages => 'Рисую изменённые страницы…';

  @override
  String get toolPan => 'Рука: двигать страницу, щелчок выбирает пузырь (H)';

  @override
  String get toolBoxes =>
      'Рамки: обвести текст рамкой, двигать и менять размер (R)';

  @override
  String get toolText =>
      'Перевод: двигать, растягивать и поворачивать текст (T)';

  @override
  String get toolBrush => 'Кисть: закрасить то, что нужно очистить (B)';

  @override
  String get toolEraser => 'Ластик: стереть лишнее из маски (E)';

  @override
  String get brushSize => 'Размер кисти ([ и ])';

  @override
  String get clearMask => 'Убрать всю маску';

  @override
  String get undo => 'Отменить (Ctrl+Z)';

  @override
  String get redo => 'Повторить (Ctrl+Y)';

  @override
  String get stepDetect => 'Найти текст';

  @override
  String get stepDetectHelp =>
      'находит текст на странице и обводит его рамками';

  @override
  String get stepRecognize => 'Распознать';

  @override
  String get stepRecognizeHelp => 'читает текст в рамках';

  @override
  String get stepTranslate => 'Перевести';

  @override
  String get stepTranslateHelp =>
      'переводит распознанный текст страницы (если нужно, сначала находит и читает его)';

  @override
  String get stepMask => 'Маска';

  @override
  String get stepMaskHelp =>
      'отмечает красным буквы, которые нужно убрать; поправьте кистью и ластиком';

  @override
  String get stepClean => 'Очистить';

  @override
  String get stepCleanHelp => 'убирает отмеченный текст с картинки';

  @override
  String get fontFile => 'Файл шрифта…';

  @override
  String get fontSize => 'Размер';

  @override
  String get sizeAuto => 'Авто';

  @override
  String get colorAuto => 'Как в оригинале';

  @override
  String get textStyle => 'Начертание';

  @override
  String get verticalText => 'Вертикальный текст';

  @override
  String get rotation => 'Поворот';

  @override
  String get styleToAll => 'Ко всем на странице';

  @override
  String get styleReset => 'Сбросить';

  @override
  String get findReplace => 'Поиск и замена (Ctrl+F)';

  @override
  String get noBlocksHint =>
      'На этой странице ещё нет рамок с текстом. Нажмите «Найти текст» над страницей или «Перевести всё», либо нарисуйте рамки инструментом «Рамки».';

  @override
  String get recognizeBlock => 'Распознать эту рамку заново';

  @override
  String get translateBlock => 'Перевести эту рамку заново';

  @override
  String get deleteBlock => 'Удалить рамку (Delete)';

  @override
  String get deselect => 'Свернуть (Esc)';

  @override
  String get sourceText => 'Распознанный текст';

  @override
  String get translationText => 'Перевод';

  @override
  String get textLook => 'Оформление текста';

  @override
  String get findHint => 'Найти';

  @override
  String get matchCase => 'С учётом регистра';

  @override
  String get wholeWord => 'Слово целиком';

  @override
  String get useRegex => 'Регулярное выражение';

  @override
  String get previousMatch => 'Предыдущее (Shift+Enter)';

  @override
  String get nextMatch => 'Следующее (Enter)';

  @override
  String get searchInTranslation => 'В переводе';

  @override
  String get searchInSource => 'В распознанном тексте';

  @override
  String get searchAllPages => 'Все страницы';

  @override
  String get searchThisPage => 'Эта страница';

  @override
  String badRegex(String error) {
    return 'Ошибка в регулярном выражении: $error';
  }

  @override
  String matchesSummary(String count, String pages) {
    return 'Найдено: $count, страниц: $pages';
  }

  @override
  String get replaceHint => 'Заменить на';

  @override
  String get replace => 'Заменить';

  @override
  String get replaceAll => 'Заменить все';

  @override
  String replacedCount(String count) {
    return 'Заменено: $count';
  }

  @override
  String get shortcutsTitle => 'Горячие клавиши';

  @override
  String get shortcutsTooltip => 'Горячие клавиши (F1)';

  @override
  String get keysGroupFiles => 'Страницы';

  @override
  String get keysGroupTools => 'Инструменты';

  @override
  String get keysGroupEdit => 'Правка';

  @override
  String get keysGroupMouse => 'Мышь';

  @override
  String get keyOpen => 'Открыть файлы';

  @override
  String get keyTranslateAll => 'Перевести всё';

  @override
  String get keyPages => 'Предыдущая / следующая страница';

  @override
  String get keyPan => 'Рука: двигать страницу, выбрать пузырь';

  @override
  String get keyBoxes => 'Рамки вокруг текста';

  @override
  String get keyText => 'Двигать, растягивать и поворачивать перевод';

  @override
  String get keyBrush => 'Кисть: отметить, что очистить';

  @override
  String get keyEraser => 'Ластик: снять отметку';

  @override
  String get keyBrushSize => 'Кисть меньше / больше';

  @override
  String get keyUndo => 'Отменить';

  @override
  String get keyRedo => 'Повторить';

  @override
  String get keyDelete => 'Удалить выбранную рамку';

  @override
  String get keyDeselect => 'Снять выбор с пузыря';

  @override
  String get keyFind => 'Поиск и замена';

  @override
  String get keyFindNext => 'Следующее / предыдущее совпадение (в поле поиска)';

  @override
  String get mouseWheel => 'Колёсико';

  @override
  String get mouseWheelHelp => 'Приблизить и отдалить';

  @override
  String get mouseMiddle => 'Средняя кнопка, тянуть';

  @override
  String get mouseMiddleHelp => 'Двигать страницу в любом инструменте';

  @override
  String get mouseDouble => 'Двойной щелчок по переводу';

  @override
  String get mouseDoubleHelp =>
      'Правка его текста в правой панели (инструмент «Перевод»)';

  @override
  String get keysNote =>
      'Буквенные клавиши не срабатывают, пока вы печатаете в поле. Работают при любой раскладке.';
}
