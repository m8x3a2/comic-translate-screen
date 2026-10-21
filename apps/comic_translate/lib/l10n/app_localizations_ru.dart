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
      'Картинки (PNG, JPG, WEBP, BMP), архивы комиксов (CBZ, ZIP, EPUB, CBR, CB7, CBT), PDF, файлы Photoshop (PSD) и проекты (.ctsproj)';

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
  String get languageAuto => 'Авто';

  @override
  String get languageAutoHint =>
      'Язык оригинала определяется по буквам каждого пузыря (латиница, кириллица, японский, корейский, китайский). Английские страницы точнее читаются, если выбрать English.';

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
  String get handEditedTitle => 'Есть страницы, исправленные вручную';

  @override
  String handEditedBody(String count) {
    return 'Страниц, исправленных вручную (текст, рамки, оформление или очистка): $count. Если перевести их заново, правки заменятся; вернуть их можно Ctrl+Z на странице, пока программа открыта.';
  }

  @override
  String get handEditedTranslate => 'Перевести заново';

  @override
  String get handEditedSkip => 'Пропустить их';

  @override
  String get missingAddressTitle => 'Нужен адрес сервера';

  @override
  String missingAddressBody(String name) {
    return 'У переводчика «$name» не указан адрес сервера. Укажите его в «Настройки → Переводчик» (например, https://openrouter.ai/api/v1, а для LM Studio — http://localhost:1234/v1) или выберите другой переводчик.';
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
      'Хранится в защищённом хранилище Windows, никогда в файлах и журналах. У каждого переводчика (а позже и у каждого облачного распознавания) свой ключ. Сохранённый ключ целиком не показывается — только последние 4 символа.';

  @override
  String get secretSet => 'Сохранён';

  @override
  String get secretNotSet => 'Не задан';

  @override
  String get secretRemove => 'Удалить ключ';

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
  String get hdStrategy => 'Очистка больших страниц';

  @override
  String get hdResize => 'Уменьшать (быстрее)';

  @override
  String get hdCrop => 'По фрагментам (точнее)';

  @override
  String get hdOriginal => 'Исходный размер (медленно)';

  @override
  String get resizeLimit => 'Уменьшать до (px, длинная сторона)';

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
  String get preserveCase =>
      'Сохранять регистр: замена пишется так же, как найденное (привет → мир, ПРИВЕТ → МИР, Привет → Мир)';

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
      'Клавиши без Ctrl и Alt не срабатывают, пока вы печатаете в поле. Работают при любой раскладке. Изменить их: Настройки → Клавиши.';

  @override
  String get keysGroupWindow => 'Окно';

  @override
  String get keyHelp => 'Этот список клавиш';

  @override
  String get keyFullScreen => 'Во весь экран и обратно';

  @override
  String get keyPreviousPage => 'Предыдущая страница';

  @override
  String get keyNextPage => 'Следующая страница';

  @override
  String get keyBrushSmaller => 'Кисть меньше';

  @override
  String get keyBrushLarger => 'Кисть больше';

  @override
  String get settingsKeys => 'Клавиши';

  @override
  String get keysSettingsHelp =>
      'Щёлкните по действию, чтобы назначить ему другую клавишу или сочетание. Клавиши без Ctrl и Alt не срабатывают, пока вы печатаете в поле.';

  @override
  String get keysNone => 'нет клавиши';

  @override
  String get keysChange => 'Изменить клавишу';

  @override
  String get keysDefault => 'Вернуть клавишу по умолчанию';

  @override
  String keysCaptureTitle(String action) {
    return 'Новая клавиша: $action';
  }

  @override
  String get keysCaptureBody =>
      'Нажмите клавишу или сочетание с Ctrl, Shift или Alt.';

  @override
  String keysCaptureTaken(String action) {
    return 'Сейчас это сочетание у «$action» — там оно будет снято.';
  }

  @override
  String get keysCaptureReserved =>
      'Эта клавиша нужна полям ввода и окнам; выберите другую.';

  @override
  String get keysCaptureNoKey => 'Без клавиши';

  @override
  String get fullScreenOn => 'Полноэкранный режим. Выйти — F11.';

  @override
  String secretSavedTail(String tail) {
    return 'Сохранён: …$tail';
  }

  @override
  String get secretShow => 'Показать введённое';

  @override
  String get secretHide => 'Скрыть';

  @override
  String get secretReplace => 'Заменить';

  @override
  String get secretReplaceHint =>
      'Вставьте новый ключ, чтобы заменить сохранённый';

  @override
  String get secretRemoveTitle => 'Удалить ключ?';

  @override
  String get secretRemoveBody =>
      'Сохранённый ключ будет удалён из защищённого хранилища Windows. Чтобы снова переводить через этот сервис, вставьте ключ заново. Сам ключ на сайте сервиса продолжит действовать: если он больше не нужен, отзовите его там.';

  @override
  String get keyStatusCheck => 'Проверить остаток';

  @override
  String keyStatusHelp(String host) {
    return 'Спрашивает у $host, сколько осталось по лимиту ключа. Отправляется только ключ и только по нажатию.';
  }

  @override
  String get keyStatusNeedsKey => 'Сначала сохраните ключ API';

  @override
  String get keyStatusChecking => 'Проверяю…';

  @override
  String keyStatusLimit(String limit, String used, String left) {
    return 'Лимит $limit, потрачено $used, осталось $left';
  }

  @override
  String keyStatusNoLimit(String used) {
    return 'У ключа нет лимита. Потрачено: $used';
  }

  @override
  String keyStatusToday(String today, String month) {
    return 'Потрачено сегодня (по UTC): $today, за месяц: $month';
  }

  @override
  String get keyStatusDelay =>
      'Сервер обновляет эти цифры с задержкой в несколько минут; расход ниже считается сразу.';

  @override
  String get keyStatusResetDaily => 'Лимит обновляется каждый день.';

  @override
  String get keyStatusResetWeekly => 'Лимит обновляется каждую неделю.';

  @override
  String get keyStatusResetMonthly => 'Лимит обновляется каждый месяц.';

  @override
  String keyStatusFree(String used, String limit, String left) {
    return 'Бесплатные модели сегодня: $used из $limit запросов, осталось $left';
  }

  @override
  String get keyStatusFreeNote =>
      'У бесплатных моделей есть ещё предел — около 20 запросов в минуту; заранее сервер его не сообщает.';

  @override
  String keyStatusFailed(String reason) {
    return 'Не удалось проверить: $reason';
  }

  @override
  String keyStatusAt(String time) {
    return 'Проверено в $time';
  }

  @override
  String get usageTitle => 'Расход на этом компьютере';

  @override
  String get usageHelp =>
      'Программа считает запросы по ответам серверов. Счётчик хранится только на этом компьютере и никуда не отправляется. Токены со значком ≈ посчитаны примерно: этот сервер их не сообщает.';

  @override
  String get usageNone => 'Запросов к серверам перевода ещё не было.';

  @override
  String get usageModel => 'Модель';

  @override
  String get usageToday => 'Сегодня';

  @override
  String get usageTotal => 'Всего';

  @override
  String usageRequests(String count) {
    return 'запросов: $count';
  }

  @override
  String usageTokens(String count) {
    return 'токенов: $count';
  }

  @override
  String usageCost(String cost) {
    return 'стоимость: $cost';
  }

  @override
  String usageSince(String date) {
    return 'Считается с $date';
  }

  @override
  String get usageReset => 'Сбросить счётчик';

  @override
  String get usageResetTitle => 'Сбросить счётчик?';

  @override
  String get usageResetBody =>
      'Счётчик на этом компьютере начнётся с нуля. На серверах и в вашем аккаунте ничего не изменится.';

  @override
  String get reset => 'Сбросить';

  @override
  String get openProject => 'Открыть проект…';

  @override
  String get saveProject => 'Сохранить проект (Ctrl+S)';

  @override
  String get saveProjectAs => 'Сохранить проект как… (Ctrl+Shift+S)';

  @override
  String get recentProjects => 'Недавние проекты';

  @override
  String get projectFileType => 'Проекты Comic Translate Screen';

  @override
  String get untitledProject => 'Без названия';

  @override
  String projectSavedAt(String time) {
    return 'Сохранено в $time';
  }

  @override
  String get projectSaving => 'Сохраняю…';

  @override
  String get projectUnsaved => 'Не сохранено';

  @override
  String get projectNoFile => 'Ещё не сохранено в проект (Ctrl+S)';

  @override
  String projectSaveFailed(String error) {
    return 'Не удалось сохранить проект: $error';
  }

  @override
  String projectOpenFailed(String error) {
    return 'Не удалось открыть проект: $error';
  }

  @override
  String get projectNewer =>
      'он сохранён более новой версией программы — обновите программу';

  @override
  String get projectNotProject => 'это не файл проекта Comic Translate Screen';

  @override
  String get projectDamaged => 'файл повреждён';

  @override
  String get unsavedTitle => 'Сохранить изменения?';

  @override
  String get unsavedNew =>
      'Страницы и правки ещё не сохранены в проект. Если их не сохранить, они пропадут.';

  @override
  String unsavedProject(String name) {
    return 'В проекте «$name» есть несохранённые изменения.';
  }

  @override
  String get dontSave => 'Не сохранять';

  @override
  String get saveAs => 'Сохранить как…';

  @override
  String get recoveryTitle => 'Восстановить прошлую работу?';

  @override
  String recoveryBody(String pages, String time) {
    return 'В прошлый раз программа закрылась, не сохранив работу. Сохранилась копия: страниц — $pages, $time.';
  }

  @override
  String get recoveryRestore => 'Восстановить';

  @override
  String get recoveryDiscard => 'Удалить копию';

  @override
  String get recoveryRestored =>
      'Прошлая работа восстановлена. Сохраните её в проект, чтобы не потерять.';

  @override
  String get fileNotFound => 'Файл не найден';

  @override
  String get removeFromList => 'Убрать из списка';

  @override
  String get settingsProjects => 'Проекты';

  @override
  String get projectAutosave => 'Автосохранение проекта';

  @override
  String get projectAutosaveHelp =>
      'Проект, у которого есть файл, сохраняется сам через пару секунд после каждой правки и после каждой страницы «Перевести всё». Работа, ещё не сохранённая в проект, раз в 2 минуты копируется, чтобы её можно было восстановить после сбоя.';

  @override
  String get openingProject => 'Открываю проект…';

  @override
  String get keySave => 'Сохранить проект';

  @override
  String get keySaveAs => 'Сохранить проект в новый файл';

  @override
  String get exportWhat => 'Что сохранить';

  @override
  String get exportTranslatedPages => 'Страницы с переводом';

  @override
  String get exportCleanedPages => 'Очищенные страницы (без текста)';

  @override
  String get exportRecognizedJson => 'Распознанный текст (JSON)';

  @override
  String get exportTranslatedJson => 'Перевод текстом (JSON)';

  @override
  String get exportWhere => 'Сохранить как';

  @override
  String get exportFolder => 'Папка';

  @override
  String get exportReaderNote =>
      'CBZ, CB7 и PDF — для читалок комиксов: в них только картинки одного вида (с переводом, если он выбран), без текстов.';

  @override
  String get exportNeeds7zip => 'Для CB7 нужен установленный 7-Zip';

  @override
  String get exportPdfFormat =>
      'В PDF формат PNG сохраняет картинку без потерь, остальные становятся JPEG.';

  @override
  String get exportWhich => 'Страницы';

  @override
  String exportAllPages(String count) {
    return 'Все готовые ($count)';
  }

  @override
  String get exportCurrentPage => 'Только текущая';

  @override
  String exportByChapter(String count) {
    return 'Отдельный файл для каждой главы ($count)';
  }

  @override
  String get exportStart => 'Экспортировать…';

  @override
  String get exportingPages => 'Экспортирую…';

  @override
  String exportSaved(String path) {
    return 'Сохранено: $path';
  }

  @override
  String get fontAdd => 'Добавить шрифт…';

  @override
  String get fontAddHelp =>
      'Шрифты копируются в папку программы и появляются во всех списках шрифтов. Проект хранит шрифты, которые использованы в его пузырях.';

  @override
  String fontsAdded(String count) {
    return 'Добавлено шрифтов: $count';
  }

  @override
  String get fontRemove => 'Убрать шрифт';

  @override
  String get boxesAll => 'Все рамки';

  @override
  String boxesGrow(String px) {
    return 'Все рамки больше на $px px';
  }

  @override
  String boxesShrink(String px) {
    return 'Все рамки меньше на $px px';
  }

  @override
  String get boxesDeleteAll => 'Удалить все рамки страницы';

  @override
  String get languagesForAll => 'Языки этой страницы — для всех страниц';

  @override
  String pagesPicked(String count) {
    return 'Выбрано страниц: $count (Ctrl или Shift + щелчок)';
  }

  @override
  String get pagesPickedClear => 'Снять выбор';

  @override
  String stepsForPicked(String count) {
    return 'для выбранных страниц: $count';
  }

  @override
  String get mousePickPages => 'Ctrl / Shift + щелчок по странице';

  @override
  String get keyPickPages => 'Выбрать несколько страниц для шагов';

  @override
  String get settingsReset => 'Сбросить раздел';

  @override
  String get settingsResetAll => 'Сбросить все настройки';

  @override
  String get settingsResetTitle => 'Сбросить настройки?';

  @override
  String settingsResetBody(String name) {
    return 'Настройки раздела «$name» вернутся к начальным. Ключи API, проекты и скачанные модели не затрагиваются.';
  }

  @override
  String get settingsResetAllBody =>
      'Все настройки вернутся к начальным, в том числе адрес и модель переводчика и разрешённые серверы. Ключи API, список недавних проектов и скачанные модели не затрагиваются. Если модели лежали в другой папке, программа снова будет искать их в обычной (сами файлы останутся на месте).';

  @override
  String get settingsResetDone => 'Настройки сброшены';

  @override
  String get mouseGrab => 'Пробел или Ctrl + левая кнопка, тянуть';

  @override
  String get modelDetector => 'Поиск текста и пузырей (RT-DETR)';

  @override
  String get modelDetectorInfo =>
      'Находит на странице текст и пузыри. Нужна всегда, для любого языка. Небольшая и быстрая.';

  @override
  String get modelAot => 'Очистка текста (AOT)';

  @override
  String get modelAotInfo =>
      'Стирает исходный текст и дорисовывает фон под ним. Стоит по умолчанию: быстрая, подходит для слабых компьютеров.';

  @override
  String get modelLama => 'Очистка текста, качественнее (LaMa)';

  @override
  String get modelLamaInfo =>
      'Аккуратнее восстанавливает рисунок под текстом, особенно под звукоподражаниями. Медленнее и больше AOT. Выбирается в Настройки → Инструменты.';

  @override
  String get modelOcrEn => 'Английский';

  @override
  String get modelOcrEnInfo =>
      'Распознаёт английский текст (PaddleOCR). Нужна, если оригинал на английском.';

  @override
  String get modelOcrLatin =>
      'Французский, немецкий, испанский, итальянский, нидерландский';

  @override
  String get modelOcrLatinInfo =>
      'Распознаёт текст на этих языках: латиница с надстрочными знаками (PaddleOCR).';

  @override
  String get modelOcrEslav => 'Русский';

  @override
  String get modelOcrEslavInfo =>
      'Распознаёт русский текст (PaddleOCR, кириллица). Нужна, если оригинал на русском.';

  @override
  String get modelOcrKorean => 'Корейский';

  @override
  String get modelOcrKoreanInfo =>
      'Распознаёт корейский текст (PaddleOCR): манхва и вебтуны.';

  @override
  String get modelOcrChinese => 'Китайский (и крупный японский текст)';

  @override
  String get modelOcrChineseInfo =>
      'Распознаёт китайский текст (PaddleOCR). Для японского тоже нужна, вместе с manga-ocr: читает крупные заголовки и надписи.';

  @override
  String get modelOcrJapanese => 'Японский (manga-ocr)';

  @override
  String get modelOcrJapaneseInfo =>
      'Распознаёт японский текст, в том числе вертикальный; обучена на манге. Работает вместе с китайской моделью.';

  @override
  String get modelOsd => 'Определение языка';

  @override
  String get modelOsdInfo =>
      'Определяет язык оригинала по буквам — для языка «Авто». Маленькая (3,7 МБ), работает на процессоре.';

  @override
  String get modelsCore => 'Основные (нужны всегда)';

  @override
  String get modelsLanguages => 'Распознавание текста по языкам';

  @override
  String get modelsLanguagesHelp =>
      'Скачайте только те языки, с которых переводите. Если модели не хватает, программа сама предложит скачать её перед переводом.';

  @override
  String get modelsExtra => 'Дополнительно';

  @override
  String modelsNeeded(String language) {
    return 'Скачать нужные для «$language»';
  }

  @override
  String get modelsAll => 'Скачать все';

  @override
  String get modelsVerifyAll => 'Проверить все';

  @override
  String get modelsNothingNeeded => 'Всё нужное уже скачано';

  @override
  String modelsSummary(String count, String total, String size) {
    return 'Скачано $count из $total · $size на диске';
  }

  @override
  String get modelsVerifyAllOk => 'Все скачанные модели в порядке';

  @override
  String modelsVerifyAllBad(String names) {
    return 'Повреждены: $names. Скачайте их заново.';
  }

  @override
  String get useGpuInfo =>
      'Поиск текста, распознавание и очистка считаются на видеокарте через DirectML — он встроен в Windows и работает с NVIDIA, AMD и Intel. На слабой или старой видеокарте может быть не быстрее процессора. Перевод это не ускоряет: он идёт на сервере переводчика.';

  @override
  String get gpuChecking => 'Проверяю видеокарту…';

  @override
  String get speedTestButton => 'Проверить скорость';

  @override
  String get speedTestTitle => 'Видеокарта или процессор';

  @override
  String speedTestNeedsModels(String models) {
    return 'Для проверки нужны модели: $models. Скачайте их в «Настройки → Модели».';
  }

  @override
  String speedTestRunning(String what) {
    return 'Замеряю тестовую страницу: $what… (около минуты)';
  }

  @override
  String get speedTestOnCpu => 'процессор';

  @override
  String get speedTestOnGpu => 'видеокарта';

  @override
  String speedSeconds(String n) {
    return '$n с';
  }

  @override
  String speedTestCpu(String time) {
    return 'Процессор: $time на страницу';
  }

  @override
  String speedTestGpu(String time) {
    return 'Видеокарта: $time на страницу';
  }

  @override
  String speedTestCpuFailed(String reason) {
    return 'Процессор: ошибка ($reason)';
  }

  @override
  String speedTestGpuFailed(String reason) {
    return 'Видеокарта: не справилась ($reason)';
  }

  @override
  String get speedTestGpuFaster => 'Видеокарта быстрее — лучше считать на ней.';

  @override
  String get speedTestCpuBetter =>
      'Процессор не медленнее видеокарты — включать её не нужно.';

  @override
  String get speedTestGpuFailedVerdict =>
      'На этой видеокарте модели работают с ошибками — программа будет считать на процессоре.';

  @override
  String speedTestReport(String path) {
    return 'Отчёт для разработчика сохранён: $path';
  }

  @override
  String get speedTestUseGpu => 'Включить видеокарту';

  @override
  String get speedTestKeepCpu => 'Оставить процессор';

  @override
  String get speedTestUseGpuAnyway => 'Всё равно включить';

  @override
  String speedTestLast(String cpu, String gpu) {
    return 'Последняя проверка: процессор $cpu, видеокарта $gpu на страницу.';
  }

  @override
  String get speedTestLastFailed =>
      'Последняя проверка: видеокарта не справилась, считает процессор.';

  @override
  String gpuFallback(String models) {
    return 'Видеокарта не справилась: $models. Эти шаги дальше считаются на процессоре, перевод продолжается.';
  }

  @override
  String get gpuFallbackHint =>
      'Если это повторяется, выключите видеокарту. Чтобы помочь исправить, соберите отчёт об ошибке и пришлите его разработчику.';

  @override
  String get gpuTurnOff => 'Выключить видеокарту';

  @override
  String gpuFound(String cards) {
    return 'Работает: $cards. Считает самая мощная.';
  }

  @override
  String get gpuOnlyIntegrated =>
      'Это видеокарта, встроенная в процессор: она редко быстрее самого процессора.';

  @override
  String gpuOldDrivers(String cards) {
    return 'Старые драйверы: $cards. Если будут ошибки, обновите их с сайта производителя.';
  }

  @override
  String get gpuNotUsableTitle => 'Видеокарту использовать нельзя';

  @override
  String gpuNoCard(String names) {
    return 'Видеокарта не найдена, только стандартный видеодрайвер Windows ($names).';
  }

  @override
  String gpuDirectmlFailed(String reason) {
    return 'Пробный расчёт на видеокарте не удался: $reason';
  }

  @override
  String get gpuNotUsableTail =>
      'Расчёты останутся на процессоре: это работает на любом компьютере, просто медленнее. Если видеокарта есть, обновите её драйвер и попробуйте снова.';

  @override
  String get testModeInfo =>
      'Пока режим включён, для каждой обработанной страницы сохраняются её шаги: найденные рамки, распознанный текст, запрос к переводчику (без ключа), маска, очистка и итог. Нажатия и правки (шрифт, интервал) не записываются. Короткий журнал программа ведёт всегда.\n\nЕсли что-то пошло не так:\n1. Включите режим.\n2. Повторите то же действие.\n3. Нажмите «Собрать отчёт об ошибке».\n4. Отправьте архив разработчику. Потом режим можно выключить.';

  @override
  String get bugReportInfo =>
      'Отчёт собирается и без режима тестирования: в архив попадают журнал и настройки (без ключей API). Если режим был включён — ещё и записи шагов последней обработки текстом (в том числе распознанный текст и перевод), без картинок.';

  @override
  String get extraContextInfo =>
      'Пишется один раз и отправляется переводчику с каждой страницей. Например: «Герои: Майя (девушка), кот Тимофей. Комедия. Друзья говорят на „ты“». Помогает с именами, родом и обращениями.';

  @override
  String get sendPageImageInfo =>
      'Модель видит рисунок и лучше понимает, кто говорит и что происходит. Картинка всей страницы уходит на сервер переводчика; запрос дороже, а модель должна уметь работать с изображениями.';

  @override
  String get upscaleSmallTextInfo =>
      'Если строки текста тоньше примерно 30 точек (скриншоты, маленькие сканы), страница перед распознаванием увеличивается до 4 раз. Ошибок становится заметно меньше; на обычных страницах почти ничего не меняется.';

  @override
  String get hdStrategyField => 'Как очищать большие страницы';

  @override
  String get hdStrategyInfo =>
      'Нейросеть очистки обучена на небольших картинках.\n• Уменьшать (по умолчанию): копия страницы уменьшается до предела и очищается, а на страницу в полном размере переносятся только очищенные места. Быстро.\n• По фрагментам: куски вокруг текста очищаются в полном размере. Точнее на больших страницах, но медленнее.\n• Исходный размер: вся страница целиком. Самое медленное, нужно много памяти.';

  @override
  String get resizeLimitInfo =>
      'Длинная сторона уменьшенной копии в точках. Больше — аккуратнее, но медленнее. 960 — как в оригинале.';

  @override
  String get cropMarginInfo =>
      'Сколько фона вокруг текста берётся во фрагмент: нейросети нужно видеть, что дорисовывать.';

  @override
  String get cropTriggerInfo =>
      'Страницы меньше этого размера (по длинной стороне) очищаются целиком, а не по фрагментам.';

  @override
  String get fontSizeInfo =>
      'Программа сама подбирает размер шрифта, чтобы перевод поместился в пузырь, — в этих пределах. Если не помещается даже наименьший, страница может увеличиться (раздел «Увеличение»).';

  @override
  String get lineSpacingInfo =>
      '1 — обычный интервал, 1,5 — в полтора раза больше. Для отдельного пузыря можно задать свой в «Оформлении текста».';

  @override
  String get outlineWidthInfo =>
      'Обводка — светлая (или тёмная) кайма вокруг букв, чтобы текст читался поверх рисунка. Толщина — в точках с каждой стороны буквы.';

  @override
  String get imageFormatInfo =>
      '«Как у исходника» — в том же формате, что и оригинал. PNG — без потерь, но файлы больше; JPG и WEBP — меньше, с небольшой потерей качества.';

  @override
  String get webtoonMode => 'Вебтун';

  @override
  String get webtoonModeHelp =>
      'Все страницы одной лентой, как читают вебтуны. Пузырь, разрезанный краем страницы, переводится и очищается целиком. Колесо — прокрутка, Ctrl + колесо — масштаб.';

  @override
  String get mouseWheelStrip => 'Вебтун: прокрутка ленты; с Ctrl — масштаб';

  @override
  String get exportStrip => 'Лента вебтуна';

  @override
  String get exportStripPages => 'По страницам';

  @override
  String get exportStripSingle => 'Одной картинкой';

  @override
  String get exportStripSlices => 'Нарезать заново';

  @override
  String get exportSliceHeight => 'Высота части, px';

  @override
  String get exportStripHelp =>
      'Разрез проходит по ровной строке рядом с этой высотой (между кадрами), а не через пузырь. Картинки выше, чем допускают JPEG или WebP, сохраняются в PNG.';

  @override
  String get exportStripSingleHelp =>
      'Все страницы (каждой главы) одна под другой в одной картинке. Очень длинная картинка сохраняется в PNG.';

  @override
  String get secretShowSaved => 'Показать ключ';

  @override
  String get secretHideSaved => 'Скрыть ключ';

  @override
  String get secretCopy => 'Копировать';

  @override
  String get secretCopied => 'Ключ скопирован';

  @override
  String get formatPsd => 'PSD (слои для Photoshop)';

  @override
  String get exportPsdHelp =>
      'Каждая страница — файл Photoshop: страница как была, очищенные места и перевод редактируемыми текстовыми слоями. Очищенные страницы сохраняются в PNG.';

  @override
  String get exportPsdPagesOnly => 'PSD сохраняются по страницам.';

  @override
  String psdImportForeign(String name) {
    return '$name: этот PSD сделан не в Comic Translate. Видимые слои с картинкой склеены в страницу, текстовые слои стали редактируемым текстом.';
  }

  @override
  String psdImportUnsupported(String name, String features) {
    return '$name: часть возможностей Photoshop не переносится ($features); страница может выглядеть немного иначе.';
  }

  @override
  String get psdFeatureSmartObjects => 'смарт-объекты';

  @override
  String get psdFeatureMasks => 'маски';

  @override
  String get psdFeatureClipping => 'обтравочные маски';

  @override
  String get psdFeatureAdjustments => 'корректирующие слои';

  @override
  String get psdFeatureBlendModes => 'режимы наложения';

  @override
  String get psdFeatureOpacity => 'непрозрачность слоёв';
}
