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
  String get reportsPrivacyNote =>
      'Что попадает в отчёт об ошибке: журнал (какие шаги запускались, сколько длились, имена файлов страниц, ошибки) и настройки. Ключи API в нём замазаны, картинок страниц нет. Распознанный и переведённый текст попадает, только пока включён «Режим тестирования», и ещё до 300 знаков ответа онлайн-переводчика, если он прислал испорченный ответ. Отчёты остаются на этом компьютере и сами никуда не отправляются.';

  @override
  String reportTotalPerPage(String time) {
    return 'всего $time';
  }

  @override
  String secondsShort(String value) {
    return '$value с';
  }

  @override
  String minutesSeconds(String minutes, String seconds) {
    return '$minutes мин $seconds с';
  }

  @override
  String stepDoneDetect(String count) {
    return 'Найдено пузырей: $count';
  }

  @override
  String stepDoneRecognize(String count) {
    return 'Распознано пузырей: $count';
  }

  @override
  String stepDoneTranslate(String count) {
    return 'Переведено пузырей: $count';
  }

  @override
  String get stepDoneMask => 'Маска готова';

  @override
  String get stepDoneClean => 'Очистка готова';

  @override
  String stepDoneTime(String what, String time) {
    return '$what — за $time';
  }

  @override
  String stepDonePages(String pages, String time) {
    return '$pages стр., в среднем $time на страницу';
  }

  @override
  String get reportStepTimes => 'Время шагов, в среднем на страницу:';

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
  String unexpectedErrorReported(String path) {
    return 'Что-то пошло не так. Отчёт об ошибке собран: $path';
  }

  @override
  String get autoBugReport => 'Собирать отчёт об ошибке автоматически';

  @override
  String get autoBugReportHelp =>
      'При неожиданной ошибке программа сама сохранит отчёт и покажет, где он лежит. Отчёт остаётся на этом компьютере.';

  @override
  String get autoBugReportOffTitle => 'Выключить автоматические отчёты?';

  @override
  String get autoBugReportOffText =>
      'Это важная функция: отчёт сохраняет, что происходило в самый момент ошибки, — по нему ошибку можно найти и исправить. Он хранится только на вашем компьютере и никуда не отправляется, в нём нет ключей API и картинок страниц.\n\nБез неё отчёт придётся собирать вручную после ошибки, и часть подробностей может уже потеряться.';

  @override
  String get autoBugReportKeepOn => 'Оставить включённым';

  @override
  String get autoBugReportTurnOff => 'Выключить';

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
  String get readLevel => 'Качество распознавания (английский)';

  @override
  String get readLevelScreens =>
      'Качество распознавания для сайтов и игр (английский)';

  @override
  String get readLevelSimple => 'Простой — как было раньше';

  @override
  String get readLevelMedium => 'Средний (по умолчанию)';

  @override
  String get readLevelHigh => 'Высокий';

  @override
  String get readLevelUltra => 'Ультра';

  @override
  String get readLevelInfo =>
      'Сколько нейросетей читает каждый блок английского текста (время — на слабом ноутбуке без видеокарты, только само чтение страницы; поиск текста и подготовка мелкого текста идут сверху):\n• Простой — как было раньше: PP-OCRv5. Около 1 с.\n• Средний — ещё и PP-OCRv6 small (21 МБ, для китайского и японского она уже есть); из двух прочтений блока берётся то, где больше настоящих английских слов. Около 2 с.\n• Высокий — после «Среднего» нейросеть PaddleOCR-VL перечитывает блоки, в которых хоть одна из двух быстрых нашла слово не из словаря (примерно половину). Почти как «Ультра», но быстрее: около 7 с на такой блок, в среднем 30 с на страницу (скрин манги — около 1 мин).\n• Ультра — PaddleOCR-VL читает каждый блок: лучше всех на полных страницах комиксов. Около 7 с на блок, в среднем 1 мин на страницу (до 3 мин).\nPaddleOCR-VL скачивается отдельно (1,8 ГБ, лицензия Apache-2.0) и занимает около 2,5 ГБ памяти; первый блок после запуска читается на 10–20 с дольше, огромный блок «стены текста» — до 2 мин. Пока её нет, «Высокий» и «Ультра» работают как «Средний».\nДругие языки читаются как на «Простом».';

  @override
  String get inpainter => 'Удаление текста';

  @override
  String get cleanLevel => 'Качество очистки';

  @override
  String get cleanLevelSimple => 'Простой — как было раньше';

  @override
  String get cleanLevelMedium => 'Средний';

  @override
  String get cleanLevelHigh => 'Высокий (по умолчанию)';

  @override
  String get cleanLevelCustom => 'Своё сочетание';

  @override
  String get cleanLevelInfo =>
      'Как убирается текст со страницы (время — на слабом ноутбуке без видеокарты, в среднем на страницу):\n• Простой — как было раньше: маска по алгоритму с запасом вокруг букв, перерисовывает нейросеть AOT. Около 4 с.\n• Средний — нейросеть comic-text-detector находит сами буквы, AOT перерисовывает только их: рисунок рядом с текстом почти не задевается, остатков букв в 2–4 раза меньше. Около 6 с.\n• Высокий — то же, но перерисовывает LaMa: лучше всего на сером растре и рисунке. Около 7 с, первый запуск ещё +8 с. Большие страницы — дольше (до 15–20 с).\nБелые пузыри на всех уровнях заливаются сразу, без нейросети. comic-text-detector скачивается отдельно (82 МБ, лицензия GPL-3.0); пока его нет, используется маска «Простого».';

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
  String get textPrep => 'Подготовка мелкого текста к распознаванию';

  @override
  String get textPrepScreens =>
      'Подготовка мелкого текста к распознаванию (сайты и игры)';

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
  String aboutAuthor(String author) {
    return 'Автор: $author';
  }

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
  String get sizeUnknown => 'Размер подберётся, когда в пузыре будет перевод';

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
  String get keyStatusCheck => 'Сведения о ключе';

  @override
  String get keyStatusRefresh => 'Обновить сведения о ключе';

  @override
  String keyStatusHelp(String host) {
    return 'Спрашивает у $host имя ключа, лимит и сколько осталось. Отправляется только ключ и только по нажатию; ответ виден до закрытия программы.';
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
  String keyStatusLabel(String label) {
    return 'Ключ: $label';
  }

  @override
  String get keyStatusFreeTier =>
      'Бесплатный аккаунт: кредиты ни разу не покупались, поэтому у бесплатных моделей меньше запросов в день.';

  @override
  String get keyStatusPaidTier =>
      'На этот аккаунт покупали кредиты: у бесплатных моделей больше запросов в день.';

  @override
  String get modelsChoose => 'Выбрать…';

  @override
  String modelsChooseHelp(String host) {
    return 'Список моделей с $host; ваш ключ туда не отправляется';
  }

  @override
  String modelsTitle(String host) {
    return 'Модели $host';
  }

  @override
  String modelsHelp(String host) {
    return 'Список приходит с $host; ничего вашего туда не отправляется (ключ тоже). Цены — за миллион токенов (токен — примерно 3–4 буквы): за запрос и за ответ. У бесплатных моделей ограничено число запросов в день (см. «Сведения о ключе» в настройках переводчика).';
  }

  @override
  String get modelsSearch => 'Поиск: название или id';

  @override
  String get modelsNewest => 'Сначала новые';

  @override
  String get modelsCheapest => 'Сначала дешёвые';

  @override
  String get modelsByName => 'По названию';

  @override
  String get modelsByContext => 'Сначала с большим контекстом';

  @override
  String get modelsFreeOnly => 'Только бесплатные';

  @override
  String get modelsVisionOnly => 'Видит картинки';

  @override
  String get modelsVisionHelp =>
      'Нужно, когда переводчику уходит картинка страницы («Отправлять картинку страницы»)';

  @override
  String modelsCount(int shown, int total) {
    return 'Показано: $shown из $total';
  }

  @override
  String get modelsFree => 'бесплатно';

  @override
  String modelsPrice(String prompt, String completion) {
    return 'запрос $prompt · ответ $completion за миллион';
  }

  @override
  String modelsContext(String tokens) {
    return 'контекст $tokens';
  }

  @override
  String get modelsVision => 'видит картинки';

  @override
  String get modelsNone => 'Таких моделей нет';

  @override
  String modelsFailed(String reason) {
    return 'Не удалось получить список: $reason';
  }

  @override
  String get modelsRetry => 'Повторить';

  @override
  String get modelsRefresh => 'Обновить список';

  @override
  String get historyOpen => 'История запросов';

  @override
  String get historyPage => 'Что ответил переводчик';

  @override
  String get historyTitle => 'История переводчика';

  @override
  String historyHelp(String keep) {
    return 'Последние $keep запросов к переводчикам через сеть (OpenRouter, свой сервер): что ушло и что пришло — как есть. Хранится только на этом компьютере; ключ и картинки сюда не попадают.';
  }

  @override
  String historyOnlyPage(String page) {
    return 'Только $page';
  }

  @override
  String historyCount(int shown, int total) {
    return 'Показано: $shown из $total';
  }

  @override
  String get historyNone =>
      'Запросов ещё нет. Они появятся здесь после перевода через OpenRouter или свой сервер.';

  @override
  String get historyNoneForPage =>
      'Для этой страницы запросов нет. Снимите фильтр, чтобы увидеть все.';

  @override
  String historyOk(int count) {
    return 'Переведено пузырей: $count';
  }

  @override
  String historyMissing(int got, int total) {
    return 'Переведено $got из $total: на часть пузырей в ответе ничего нет';
  }

  @override
  String historyFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String historySeconds(String seconds) {
    return '$seconds с';
  }

  @override
  String get historyImage => 'с картинкой страницы';

  @override
  String historyTokens(int input, int output) {
    return 'токены: $input в запросе, $output в ответе';
  }

  @override
  String historyWarnings(String warnings) {
    return 'При разборе ответа: $warnings';
  }

  @override
  String get historySent => 'Отправлено';

  @override
  String get historyReply => 'Ответ (как пришёл)';

  @override
  String get historyNoReply => '(ответа нет)';

  @override
  String get historyClear => 'Очистить историю';

  @override
  String get historyClearAsk => 'Очистить всю историю запросов?';

  @override
  String get historyCopied => 'Скопировано';

  @override
  String get historyAgain => 'досылка';

  @override
  String get untranslatedMark => 'нет перевода';

  @override
  String get untranslatedHelp =>
      'В ответе переводчика для этого пузыря ничего не было: на картинке остаётся оригинальный текст. Впишите перевод или нажмите «Перевести» у пузыря.';

  @override
  String get reportUntranslated =>
      'Пузыри без перевода (оригинальный текст остался):';

  @override
  String reportUntranslatedCount(int count) {
    return 'пузырей: $count';
  }

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
    return 'Выбрано страниц: $count';
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
      'Аккуратнее восстанавливает рисунок под текстом, особенно на сером растре и под звукоподражаниями. Медленнее и больше AOT. Нужна уровню очистки «Высокий» (Настройки → Инструменты → Качество очистки).';

  @override
  String get modelCtd => 'Буквы для очистки (comic-text-detector)';

  @override
  String get modelCtdInfo =>
      'Находит сами буквы, чтобы при очистке перерисовывались только они, а не рисунок вокруг. Нужна уровням очистки «Средний» и «Высокий». Около 2 с на страницу. Автор dmMaze, лицензия GPL-3.0; файл из EarthWL/hiyori-onnx.';

  @override
  String get modelVlm => 'Медленный точный чтец (PaddleOCR-VL 1.6)';

  @override
  String get modelVlmInfo =>
      'Нейросеть «картинка → текст»: читает английский блок целиком и ошибается реже всех. Нужна качеству распознавания «Высокий» и «Ультра». Около 7 с на блок на слабом ноутбуке, около 2,5 ГБ памяти. Автор PaddlePaddle (Baidu), лицензия Apache-2.0.';

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
  String get modelOcrChinese =>
      'Китайский (и крупный японский текст; второй чтец английского)';

  @override
  String get modelOcrChineseInfo =>
      'Распознаёт китайский текст (PaddleOCR). Для японского тоже нужна, вместе с manga-ocr: читает крупные заголовки и надписи. Для английского на «Среднем» и «Высоком» качестве распознавания читает каждый блок второй раз.';

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
  String get modelsTextPrep => 'Подготовка текста';

  @override
  String get modelsTextPrepHelp =>
      'Нейросети, которые перед распознаванием увеличивают мелкий текст. Нужна только та, что выбрана в «Распознавание и очистка → Подготовка мелкого текста».';

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
  String speedTestSmallGain(String percent) {
    return 'Видеокарта быстрее всего на $percent % — разница небольшая, хватит и процессора.';
  }

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
    return 'Видеокарта не справилась: $models. Эти шаги дальше считаются на процессоре, перевод продолжается. Программа это запомнила и в следующий раз сразу запустит их на процессоре (Настройки → Общие).';
  }

  @override
  String get gpuFallbackHint =>
      'Если это повторяется, выключите видеокарту. Чтобы помочь исправить, соберите отчёт об ошибке и пришлите его разработчику.';

  @override
  String speedTestPartial(String models) {
    return 'Эти шаги на этой видеокарте не работают и считаются на процессоре (время видеокарты это уже учитывает): $models.';
  }

  @override
  String gpuCpuModelsNote(String models) {
    return 'Не работают на этой видеокарте, поэтому считаются на процессоре: $models.';
  }

  @override
  String get gpuCpuModelsRetry => 'Попробовать снова';

  @override
  String gpuFallbackOcr(String language) {
    return 'распознавание текста ($language)';
  }

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
  String get textPrepInfo =>
      'Кусочки страницы с мелким текстом (строки тоньше 20 точек) перед распознаванием увеличиваются; обычный текст не трогается. Без нейросети — мгновенно. Нейросети восстанавливают форму букв, но работают дольше (время — на слабом ноутбуке, для страницы-скриншота с мелким текстом): «Простой» — около 1 с, «Средний» — около 2 с (лучший на скриншотах манги), «Высокий» — около 15 с (лучший в целом, выбран для комиксов по умолчанию); с видеокартой быстрее. Для сайтов и игр лучше всего «Обычное ×1,5». Нужную модель программа предложит скачать.';

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
  String get secretGetKey => 'Получить ключ';

  @override
  String get pluginMoreSettings => 'Дополнительно';

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

  @override
  String get splitWords =>
      'Разделить слипшиеся слова на этой странице или выбранных страницах (английский): «REALLIFE» станет «REAL LIFE»';

  @override
  String get splitWordsBlock =>
      'Разделить слипшиеся слова в этом пузыре (английский)';

  @override
  String splitWordsDone(String count) {
    return 'Разделено слов: $count. Отменить — Ctrl+Z.';
  }

  @override
  String get splitWordsNone =>
      'Слипшихся слов не найдено (проверяется только английский текст).';

  @override
  String get splitWordsMissing =>
      'В папке программы нет словаря (data\\flutter_assets\\assets\\dict).';

  @override
  String get splitGluedWords =>
      'Разделять слипшиеся английские слова сразу после распознавания';

  @override
  String get splitGluedWordsInfo =>
      'На очень мелком тексте распознавание часто читает два слова как одно: «REALLIFE», «MYINSTINCTS». Слова, которых нет в словаре, делятся на слова из словаря; буквы не меняются. То же делает кнопка в панели «Текст» — для страницы или одного пузыря.';

  @override
  String get checkLines => 'Проверять строки перед распознаванием';

  @override
  String get checkLinesInfo =>
      'Только для комиксов. На плотном тексте (стена текста, текст поверх рисунка, скрин с абзацами) программа иногда принимает несколько строк за одну и читает лишь слово-другое. Быстрая проверка находит такие блоки, и нейросеть «Поиск строк текста (PP-OCR)» находит их строки заново: около 1–7 с на странице, где это нужно. Обычные пузыри не меняются, японские вертикальные колонки тоже. Обычно держите включённой. Выключать стоит, если на какой-то странице с проверкой текст распознаётся хуже, чем без неё (сравните «Распознать» с ней и без неё и напишите автору), или если страницы — обычные комиксы без плотного текста и важна каждая секунда.';

  @override
  String get contentSwitchedHint =>
      'Рамки на этой странице найдены в прежнем режиме. Новый режим заработает, когда текст будет найден заново.';

  @override
  String get findTextAgain => 'Найти текст заново';

  @override
  String get textPrepSeconds => 'Время нейросети на страницу';

  @override
  String get textPrepSecondsDefault => '1 мин (по умолчанию)';

  @override
  String minutesShort(String value) {
    return '$value мин';
  }

  @override
  String get noTimeLimit => 'Без ограничения';

  @override
  String get textPrepSecondsInfo =>
      'Сколько нейросеть может увеличивать мелкий текст на одной странице. Сначала она берёт самый мелкий текст; что не успела — увеличивается обычным способом: мгновенно, качество чуть ниже. На слабом ноутбуке «Высокий» тратит около 4 минут на миллион точек: скрин манги — 20–60 с, страница, сплошь покрытая мелким текстом, — 10 минут и больше. Если качество важнее времени (например, отходите попить чай) — поставьте больше или «Без ограничения». На видеокарте нейросеть успевает больше за то же время.';

  @override
  String get modelLines => 'Поиск строк текста (PP-OCR)';

  @override
  String get modelLinesInfo =>
      'Находит строки обычного текста для «Сайтов и игр»: скриншоты, игры, визуальные новеллы. В «Комиксах» помогает читать плотный текст (см. «Проверять строки»). Небольшая и быстрая.';

  @override
  String get modelOpusEnRu => 'Офлайн-перевод английский → русский (OPUS-MT)';

  @override
  String get modelOpusRuEn => 'Офлайн-перевод русский → английский (OPUS-MT)';

  @override
  String get modelOpusInfo =>
      'Переводит прямо на компьютере, без интернета и ключей (переводчик «Офлайн (OPUS-MT)»). Около 0,4–0,7 с на пузырь. Лицензия CC-BY 4.0, Helsinki-NLP.';

  @override
  String get modelW2xCunet => 'waifu2x CUNet (уровень «Простой»)';

  @override
  String get modelW2xCunetInfo =>
      'Быстрая нейросеть, увеличивает мелкий текст в 2 раза перед распознаванием. Около 1 с на страницу-скриншот. Лицензия MIT (nagadomi, waifu2x).';

  @override
  String get modelW2xSwin => 'waifu2x Swin-UNet (уровень «Средний»)';

  @override
  String get modelW2xSwinInfo =>
      'Увеличивает мелкий текст в 2 раза перед распознаванием; лучшая в опыте на скриншотах манги. Около 2 с на страницу-скриншот. Лицензия MIT (nagadomi, waifu2x).';

  @override
  String get modelFatality => 'Fatality Comix (уровень «Высокий»)';

  @override
  String get modelFatalityInfo =>
      'Убирает типографский растр и увеличивает мелкий текст; лучшая на уменьшенных страницах комиксов, но медленная (около 15 с на страницу-скриншот). Автор Twittman, лицензия CC-BY-NC-SA 4.0: только некоммерческое использование. Переведена в ONNX этим проектом.';

  @override
  String get downloadNetworkFailed =>
      'Не удалось скачать модель: связь с сайтом моделей обрывается (4 попытки). Проверьте интернет и попробуйте ещё раз — скачивание продолжится с того места, где остановилось. Если сайт недоступен, скачайте файлы на другом компьютере и добавьте их кнопкой «Импорт с диска…» в разделе «Модели».';

  @override
  String panelHide(String name) {
    return 'Скрыть: $name';
  }

  @override
  String panelShow(String name) {
    return 'Показать: $name';
  }

  @override
  String get panelPages => 'Страницы';

  @override
  String get panelTools => 'Инструменты';

  @override
  String get pageGridOpen => 'Все страницы на всё окно';

  @override
  String pageGridTitle(String count) {
    return 'Все страницы ($count)';
  }

  @override
  String pageGridPicked(String count) {
    return 'Отмечено: $count';
  }

  @override
  String get pageGridPickAll => 'Отметить все';

  @override
  String get pageGridPickNone => 'Снять отметки';

  @override
  String get pageGridClose => 'Закрыть';

  @override
  String get pageGridHint =>
      'Щелчок отмечает страницу для шагов (Найти текст, Распознать, Перевести…), перетаскивание переставляет её, двойной щелчок открывает. Esc — закрыть.';

  @override
  String get pageGridLocked =>
      'Пока идёт перевод, переставлять страницы нельзя.';

  @override
  String get contentKind => 'Что переводим';

  @override
  String get contentKindInfo =>
      'Комиксы: программа ищет пузыри и подписи. Сайты и игры: ищет строки обычного текста (скриншоты, игры, визуальные новеллы, экран телефона).';

  @override
  String get contentComics => 'Комиксы';

  @override
  String get contentComicsHelp => 'пузыри и подписи';

  @override
  String get contentScreens => 'Сайты и игры';

  @override
  String get contentScreensHelp =>
      'строки обычного текста: скриншоты, игры, визуальные новеллы';

  @override
  String get detectorScreens => 'Поиск текста (сайты и игры)';

  @override
  String tinyTextTryHigh(String px) {
    return 'Очень мелкий текст (строки около $px точек): возможны ошибки. Включите уровень «Высокий» в «Настройки → Распознавание и очистка → Подготовка мелкого текста» и распознайте заново — или сделайте снимок крупнее.';
  }

  @override
  String tinyTextLarger(String px) {
    return 'Очень мелкий текст (строки около $px точек): возможны ошибки даже после нейросети. Сделайте снимок крупнее — увеличьте масштаб страницы или окна перед скриншотом.';
  }

  @override
  String get chatTitle => 'Обмен с чатом';

  @override
  String get chatSubtitle =>
      'ChatGPT, Gemini, Claude или любой другой. Программа сама ничего не отправляет: вы переносите картинки и инструкцию в чат, а потом вставляете сюда его ответ.';

  @override
  String get chatModeBoth => 'Распознать и перевести';

  @override
  String get chatModeRecognize => 'Распознать';

  @override
  String get chatModeTranslate => 'Перевести';

  @override
  String chatPieces(int count, int pages) {
    return 'Пузырей с текстом: $count, страниц: $pages';
  }

  @override
  String get chatNoPieces =>
      'Нечего отправлять: сначала найдите текст (а чтобы переводить — и распознайте его).';

  @override
  String get chatSheets => 'Листы';

  @override
  String get chatGroupingSize => 'сколько поместится';

  @override
  String get chatGroupingCount => 'по количеству';

  @override
  String get chatPerSheet => 'Пузырей на листе';

  @override
  String get chatSheetSize => 'Размер листа';

  @override
  String get chatSheetPerPage => 'Каждая страница с нового листа';

  @override
  String get chatContextImage => 'Картинка страницы';

  @override
  String get chatContextOff => 'не отправлять';

  @override
  String get chatContextSeparate => 'отдельной картинкой';

  @override
  String get chatContextOnSheet => 'на листе';

  @override
  String get chatGroups => 'Свои листы';

  @override
  String get chatGroupsHint => 'например 1-4, 5-6';

  @override
  String chatGroupsError(String part, int count) {
    return 'Непонятно: «$part». Номера пузырей от 1 до $count, например 1-4, 5-6.';
  }

  @override
  String get chatStep1 => '1. Отправьте в чат';

  @override
  String get chatStep1Help =>
      'Скопируйте картинки и вставьте их в чат (Ctrl+V), затем скопируйте инструкцию, тоже вставьте и отправьте.';

  @override
  String get chatStep1TextHelp =>
      'Скопируйте инструкцию вместе с текстом, вставьте в чат (Ctrl+V) и отправьте.';

  @override
  String get chatPreparing => 'Готовлю картинки…';

  @override
  String chatExportFailed(String error) {
    return 'Не удалось подготовить файлы: $error';
  }

  @override
  String chatCopyPictures(int count) {
    return 'Копировать картинки ($count)';
  }

  @override
  String get chatCopyPrompt => 'Копировать инструкцию';

  @override
  String get chatCopyOne => 'Скопировать только эту картинку';

  @override
  String get chatShowPrompt => 'Инструкция для чата';

  @override
  String get chatOpenFolder => 'Открыть папку';

  @override
  String chatCopiedPictures(int count) {
    return 'Скопировано картинок: $count. Вставьте их в чат: Ctrl+V.';
  }

  @override
  String chatCopiedOne(String name) {
    return 'Скопировано: $name. Вставьте в чат: Ctrl+V.';
  }

  @override
  String get chatCopiedPrompt =>
      'Инструкция скопирована. Вставьте её в чат: Ctrl+V.';

  @override
  String get chatCopyText => 'Копировать текст';

  @override
  String get chatCopiedText =>
      'Текст скопирован (только строки с метками). Вставьте его в чат: Ctrl+V.';

  @override
  String chatPagesAll(int count) {
    return 'Все страницы ($count)';
  }

  @override
  String chatPageOnly(int page, int count) {
    return 'Страница $page ($count)';
  }

  @override
  String chatPicturePages(String pages) {
    return 'стр. $pages';
  }

  @override
  String chatClipboardOffer(int found, int total) {
    return 'В буфере ответ чата: $found из $total. Вставить?';
  }

  @override
  String get chatClipboardPaste => 'Вставить';

  @override
  String get glossaryMenu => 'Словарь имён и терминов…';

  @override
  String get glossaryTitle => 'Словарь имён и терминов';

  @override
  String glossaryButton(int count) {
    return 'Словарь ($count)';
  }

  @override
  String get glossaryHelp =>
      'Как переводить имена и слова в этом проекте. Одна строка — одно слово: Kai --> Кай. Любая другая строка — пояснение для перевода (например: «Senpai не переводить», «Герои говорят друг другу „ты“»). Строки с # — ваши заметки, они никуда не уходят.\n\nСловарь хранится в проекте. Он уходит в инструкцию для чата (там — только слова, которые есть в тексте) и переводчику через сеть (OpenRouter и другие); офлайн-переводчик его не учитывает. Чат может предложить новые имена — их можно добавить одной кнопкой в окне обмена.';

  @override
  String get glossaryHint =>
      'Kai --> Кай\nSenpai --> семпай\nГерои говорят друг другу «ты».';

  @override
  String glossaryCounts(int words, int notes) {
    return 'Слов: $words, пояснений: $notes';
  }

  @override
  String get glossaryLoad => 'Загрузить из txt…';

  @override
  String get glossarySave => 'Сохранить в txt…';

  @override
  String glossarySaved(String path) {
    return 'Сохранено: $path';
  }

  @override
  String get textExportMenu => 'Выгрузить текст…';

  @override
  String get textExportTitle => 'Выгрузить текст';

  @override
  String get textExportHelp =>
      'Диалоги страниц обычным текстом: оригинал, перевод или оба. Можно сохранить себе или приложить в чат как контекст. Метки — те же, что в обмене с чатом (ALL.txt).';

  @override
  String textExportAllPages(String count) {
    return 'Пусто — все страницы ($count)';
  }

  @override
  String textExportSomePages(String count) {
    return 'Страниц: $count';
  }

  @override
  String get textExportWhat => 'Что:';

  @override
  String get textExportOriginal => 'Оригинал';

  @override
  String get textExportTranslation => 'Перевод';

  @override
  String get textExportBoth => 'Оба';

  @override
  String get textExportTwoFiles =>
      'Два файла: …_original.txt и …_translation.txt (выберете папку).';

  @override
  String get textExportLabels => 'Метки перед строками: [01-003]';

  @override
  String get textExportSpeakers => 'Кто говорит: [m] [f] [n]';

  @override
  String get textExportHeadings => 'Заголовки страниц';

  @override
  String get textExportHeading => 'Заголовок';

  @override
  String textExportHeadingHelp(String number, String name) {
    return '$number — номер страницы, $name — имя её файла. Например: --- $number ---';
  }

  @override
  String get textExportPage => 'Страница';

  @override
  String get textExportPreview => 'Как будет выглядеть';

  @override
  String get textExportEmpty => '(текста нет)';

  @override
  String get textExportCopy => 'Копировать';

  @override
  String get textExportCopyShown => 'Копировать показанный';

  @override
  String get textExportCopied => 'Скопировано. Вставьте: Ctrl+V.';

  @override
  String get textExportSave => 'Сохранить…';

  @override
  String textExportSaved(String paths) {
    return 'Сохранено:\n$paths';
  }

  @override
  String get glossaryApply => 'Готово';

  @override
  String get chatNewTerms => 'Чат предлагает добавить в словарь:';

  @override
  String get chatNewTermsAdd => 'Добавить в словарь';

  @override
  String chatNewTermsAdded(int count) {
    return 'Добавлено в словарь: $count';
  }

  @override
  String get chatStyles => 'Стиль перевода:';

  @override
  String get chatStylesOwn => 'Свои стили и инструкции';

  @override
  String get styleNone => 'Без стиля';

  @override
  String get styleLiteral => 'Дословно';

  @override
  String get styleLively => 'Живо, разговорно';

  @override
  String get styleSoften => 'Смягчить грубости';

  @override
  String get styleKeepSwearing => 'Грубости как в оригинале';

  @override
  String get styleHonorifics => 'Сохранить -сан/-кун';

  @override
  String get styleOwn => 'Свой стиль';

  @override
  String get chatStylesTitle => 'Стили перевода';

  @override
  String get chatStylesHelp =>
      'Выбранные стили добавляются в инструкцию для чата и уходят переводчику через сеть (OpenRouter и другие). Свой стиль: название — для списка, а что просить — по-английски (так чаты понимают лучше).';

  @override
  String get chatOwnStyleName => 'Название';

  @override
  String get chatOwnStyleText => 'Что просить (по-английски)';

  @override
  String get chatOwnStyleAdd => 'Добавить свой стиль';

  @override
  String get chatOwnStyleDelete => 'Удалить стиль';

  @override
  String get chatSharedTexts => 'Общий текст для всех режимов';

  @override
  String get chatSharedTextsHelp =>
      'Вписанное в txt-файлы остаётся при смене режима: «Распознать», «Перевести» и «Распознать и перевести» работают с одними и теми же файлами. Если выключить, у каждого режима свои чистые заготовки.';

  @override
  String get speakerLabel => 'Кто говорит';

  @override
  String get speakerInfo =>
      'Помогает переводу выбрать род: «я пришёл» или «я пришла». Тег уходит в чат и переводчику через сеть (OpenRouter и другие); офлайн-переводчик его не учитывает.\n\nВ txt-файлах обмена тег стоит после метки: [01-003] [f] … — там его можно и поменять: [m] — мужчина, [f] — женщина, [n] — без рода, [-] — убрать.';

  @override
  String get speakerMale => 'М';

  @override
  String get speakerFemale => 'Ж';

  @override
  String get speakerNeuter => 'Ср';

  @override
  String get speakerNoneTip => 'Не указано';

  @override
  String get speakerMaleTip => 'Мужчина';

  @override
  String get speakerFemaleTip => 'Женщина';

  @override
  String get speakerNeuterTip => 'Без рода: предмет, толпа, рассказчик';

  @override
  String get chatAnswerFromClipboard => 'Предлагать ответ из буфера';

  @override
  String get chatAnswerFromClipboardHelp =>
      'Вернулись в окно обмена, а в буфере ответ чата (строки с метками) — программа предложит вставить его.';

  @override
  String get chatCopyFailed =>
      'Не удалось скопировать: буфер обмена занят другой программой. Попробуйте ещё раз или откройте папку и перетащите файлы в чат.';

  @override
  String get chatStep2 => '2. Вставьте ответ чата';

  @override
  String get chatAnswerHint => '[01-003] текст';

  @override
  String get chatAnswerHintBoth => '[01-003] I\'M LATE! --> Я ОПОЗДАЛ!';

  @override
  String get chatPaste => 'Вставить из буфера';

  @override
  String get chatFromFiles => 'Взять из txt-файлов';

  @override
  String chatFromFilesInfoTranslate(String separator) {
    return 'Берёт ответ из txt-файлов в папке обмена (кнопка «Открыть папку» внизу). Файлы одинаковые во всех режимах и показывают, что сейчас в пузырях:\nALL.txt — [01-001] текст $separator перевод\nALL_original.txt — только текст, ALL_translation.txt — только перевод; page_01.txt… — то же по страницам.\nПравьте любые строки в любом файле и сохраните его: изменённое попадёт в пузырь, нетронутые строки ничего не меняют. [f] после метки — кто говорит. Можно и заменить всё содержимое ALL.txt ответом чата.\n\n«Перевести»: допишите перевод после «$separator» в ALL.txt или впишите его в ALL_translation.txt.';
  }

  @override
  String chatFromFilesInfoRecognize(String separator) {
    return 'Берёт ответ из txt-файлов в папке обмена (кнопка «Открыть папку» внизу). Файлы одинаковые во всех режимах и показывают, что сейчас в пузырях:\nALL.txt — [01-001] текст $separator перевод\nALL_original.txt — только текст, ALL_translation.txt — только перевод; page_01.txt… — то же по страницам.\nПравьте любые строки в любом файле и сохраните его: изменённое попадёт в пузырь, нетронутые строки ничего не меняют. [f] после метки — кто говорит. Можно и заменить всё содержимое ALL.txt ответом чата.\n\n«Распознать»: впишите или исправьте текст с картинки — перед «$separator» в ALL.txt или в ALL_original.txt. Заодно можно дать и перевод.';
  }

  @override
  String chatFromFilesInfoBoth(String separator) {
    return 'Берёт ответ из txt-файлов в папке обмена (кнопка «Открыть папку» внизу). Файлы одинаковые во всех режимах и показывают, что сейчас в пузырях:\nALL.txt — [01-001] текст $separator перевод\nALL_original.txt — только текст, ALL_translation.txt — только перевод; page_01.txt… — то же по страницам.\nПравьте любые строки в любом файле и сохраните его: изменённое попадёт в пузырь, нетронутые строки ничего не меняют. [f] после метки — кто говорит. Можно и заменить всё содержимое ALL.txt ответом чата.\n\n«Распознать и перевести»: нужны и текст с картинки, и перевод — в ALL.txt через «$separator» или по отдельности в ALL_original.txt и ALL_translation.txt.';
  }

  @override
  String get chatSheetPerPageOn =>
      'Включено «Каждая страница с нового листа» — на листах будут пузыри только одной страницы.';

  @override
  String get chatOpenTxt => 'Открыть txt-файл…';

  @override
  String chatFound(int found, int total) {
    return 'Найдено ответов: $found из $total';
  }

  @override
  String chatFromFilesNote(String files) {
    return 'Взято из файлов: $files';
  }

  @override
  String chatMissing(String labels) {
    return 'Нет ответа: $labels';
  }

  @override
  String chatAccepted(int count, int total) {
    return 'Уже принято из прошлых ответов: $count из $total';
  }

  @override
  String get chatAskAgain => 'Ещё спросить';

  @override
  String get chatAskAgainInfo =>
      'Чат ответил на все пузыри, но где-то плохо (неверный перевод, ошибка при чтении с картинки)? Впишите сюда метки этих пузырей через запятую: 01-002, 03-005. Кнопка рядом подготовит короткий запрос только на них — их картинки и инструкцию. Отправьте его в тот же чат и вставьте ответ: новый ответ заменит старый у этих пузырей, ответы остальных пузырей сохранятся. Пузыри совсем без ответа добавляются сами.';

  @override
  String chatAskAgainWrong(String part) {
    return 'Это не метка: «$part»';
  }

  @override
  String chatAskAgainUnknown(String labels) {
    return 'Таких меток не было: $labels';
  }

  @override
  String chatResendMissing(int count) {
    return 'Дослать недостающее ($count)';
  }

  @override
  String chatResendAgain(int count) {
    return 'Спросить ещё раз ($count)';
  }

  @override
  String chatResendBoth(int count) {
    return 'Дослать и переспросить ($count)';
  }

  @override
  String chatRoundBanner(int count, String labels) {
    return 'Досылка: пузырей — $count ($labels). Картинки и инструкция здесь — только для них; ответ чата вставьте справа.';
  }

  @override
  String get chatRoundBack => 'Вернуться к полной выгрузке';

  @override
  String chatUnchanged(int count) {
    return 'Без изменений (как в пузырях сейчас): $count';
  }

  @override
  String chatUnknown(String labels) {
    return 'Таких не отправляли (пропущены): $labels';
  }

  @override
  String chatNoArrow(String sep, String labels) {
    return 'Без «$sep» (всё взято как перевод): $labels';
  }

  @override
  String chatRepeated(String labels) {
    return 'Ответ дан дважды (взят первый): $labels';
  }

  @override
  String get chatApply => 'Применить';

  @override
  String get chatApplyContinue => 'Применить и продолжить';

  @override
  String chatApplied(int count) {
    return 'Записано пузырей: $count';
  }

  @override
  String chatLost(String labels) {
    return 'Больше нет на странице (рамки удалены?): $labels';
  }

  @override
  String get chatButton => 'Чат';

  @override
  String get chatButtonHelp =>
      'Распознать и перевести с ChatGPT, Gemini, Claude… вручную, для выбранных страниц';

  @override
  String get chatMenuBoth => 'Распознать и перевести через чат…';

  @override
  String get chatMenuRecognize => 'Распознать через чат…';

  @override
  String get chatMenuTranslate => 'Перевести через чат…';

  @override
  String get chatMenuFolder => 'Ответ для прошлой выгрузки…';

  @override
  String get chatNotExchangeFolder =>
      'В этой папке нет exchange.json — это не папка обмена.';

  @override
  String get stageExchange => 'Ждёт ответа чата';

  @override
  String get chatSettingsHelp =>
      'Кнопка «Чат» на главном экране работает при любых настройках. Чтобы «Перевести всё» само открывало обмен, выберите «Вручную через чат» в разделе «Переводчик» и/или в «Инструменты → Распознавание».';

  @override
  String get chatTogether => 'Распознавать и переводить одним сообщением';

  @override
  String get chatTogetherHelp =>
      'Когда и то, и другое идёт через чат. Выключено: сначала распознавание, потом второй заход с текстом для перевода.';

  @override
  String get chatPicturesTitle => 'Картинки';

  @override
  String get chatImages => 'Что делать';

  @override
  String get chatImagesSheets => 'Листы (несколько пузырей на картинке)';

  @override
  String get chatImagesCrops => 'По картинке на каждый пузырь';

  @override
  String get chatImagesBoth => 'И то, и другое';

  @override
  String get chatImagesInfo =>
      'Листы удобнее отправлять: на одной картинке много пузырей, над каждым его метка. Отдельные картинки называются как метки (01-003.png) и лежат по папкам по заданному числу.';

  @override
  String get chatGroupingInfo =>
      'Сколько поместится: лист заполняется до своего размера. По количеству: на каждом листе одинаковое число пузырей. В окне обмена можно задать и свои листы, например 1-4, 5-6.';

  @override
  String get chatSheetSizePx => 'Размер листа (точек)';

  @override
  String get chatSheetSizeInfo =>
      'Самая длинная сторона листа. Чаты уменьшают большие картинки, и мелкие буквы перестают читаться; 1600 подходит большинству чатов.';

  @override
  String get chatContextInfo =>
      'Уменьшенная картинка всей страницы с подписанными рамками: помогает чату понять, кто говорит и что происходит. Работает и когда только переводим.';

  @override
  String get chatCropsPerFolder => 'Картинок в папке';

  @override
  String get chatAnswerTitle => 'Ответ';

  @override
  String get chatTextFiles => 'Текстовые файлы';

  @override
  String get chatTextFilesAll => 'ALL.txt на все страницы';

  @override
  String get chatTextFilesPages => 'Файл на каждую страницу';

  @override
  String get chatTextFilesBoth => 'И то, и другое';

  @override
  String get chatTextFilesInfo =>
      'Файлы с одной строкой на метку в папке обмена. Вставьте в них ответ чата и нажмите «Взять из txt-файлов»: сначала берётся ALL.txt, потом файлы страниц для того, чего не хватило.';

  @override
  String get chatPlaceholder => 'Текст для пузырей без ответа';

  @override
  String get chatPlaceholderHelp =>
      'Пусто — такие пузыри не меняются. Что-нибудь вроде ⟦пусто⟧ поможет их быстро найти.';

  @override
  String get chatPromptsTitle => 'Инструкции для чата';

  @override
  String chatPromptsHelp(String names) {
    return 'На английском: так чаты выполняют точнее. Вместо этих слов программа подставит языки, метки, текст с метками и то, что вы написали о комиксе: $names.';
  }

  @override
  String get chatPromptDefault => 'Вернуть стандартную';

  @override
  String chatCopySelected(int count) {
    return 'Копировать выбранные ($count)';
  }

  @override
  String get chatSelectAll => 'Выбрать все';

  @override
  String get chatSelectNone => 'Снять выбор';

  @override
  String get chatGalleryOpen => 'Раскрыть картинки крупно';

  @override
  String get chatGalleryPictures => 'Картинки';

  @override
  String get chatGalleryPieces => 'Пузыри и листы';

  @override
  String get chatPiecesHelp =>
      'Все пузыри по порядку. Щёлкните пузырь — с него начнётся новый лист; ещё раз — отменить.';

  @override
  String chatGroupsNow(String groups) {
    return 'Листы: $groups';
  }

  @override
  String get chatGroupsAuto => 'как задано в окне';

  @override
  String get chatGroupsClear => 'Убрать все разрывы';

  @override
  String get chatGroupsApply => 'Применить листы';

  @override
  String get chatNewSheetHere => 'Новый лист отсюда';

  @override
  String chatGroupsNumbers(String first, int count, String last) {
    return '1 = [$first] … $count = [$last]';
  }

  @override
  String get chatPromptChanged => 'Инструкция для чата (изменена на этот раз)';

  @override
  String get chatPromptUndo => 'Отменить мои правки';

  @override
  String get chatPromptTemplate => 'Изменить насовсем…';

  @override
  String get chatOneField => 'Одно поле';

  @override
  String get chatTwoFields => 'Два поля';

  @override
  String get chatOriginalField => 'Оригинал';

  @override
  String get chatTranslationField => 'Перевод';

  @override
  String get chatAnswerHintTranslation => '[01-003] перевод';

  @override
  String get chatApart => 'Оригинал и перевод двумя списками';

  @override
  String get chatApartHelp =>
      'Когда распознаём и переводим одним сообщением: чат пишет все оригиналы, потом ===, потом все переводы; ответ раскладывается по двум полям.';

  @override
  String get chatPromptBothApart => 'Распознать и перевести двумя списками';

  @override
  String get chatSplitFiles => 'Ещё и оригинал с переводом в отдельных файлах';

  @override
  String get chatSplitFilesHelp =>
      'Кроме ALL.txt пишутся ALL_original.txt (оригинал) и ALL_translation.txt (только перевод), так же для файлов страниц. Ответ берётся из того файла, который заполнен.';

  @override
  String get chatSeparator => 'Между оригиналом и переводом';

  @override
  String get chatSeparatorHelp =>
      'Любой знак, по умолчанию -->. Он попадёт в инструкцию для чата; обычные стрелки тоже понимаются.';

  @override
  String get textCase => 'Регистр';

  @override
  String get textCaseSource => 'Как в оригинале';

  @override
  String get textCaseUpper => 'ВСЕ ЗАГЛАВНЫЕ';

  @override
  String get textCaseNormal => 'Обычные буквы';

  @override
  String get textCaseInfo =>
      'Почти все комиксы написаны заглавными буквами. «Как в оригинале»: где в пузыре оригинала заглавные, перевод тоже будет заглавными, иначе — обычными буквами. Для страницы или одного пузыря — кнопка «Аа» в панели «Текст».';

  @override
  String get matchSource => 'Оформление как в оригинале';

  @override
  String get matchSourceInfo =>
      'Программа смотрит на буквы оригинала и рисует перевод так же: жирным, где буквы заметно толще, чем в других пузырях страницы; курсивом, где они наклонены; с обводкой того же цвета у надписей и звуков поверх рисунка. Определяется при распознавании; у очень мелкого текста жирность и наклон не определяются. Выключите, чтобы оформление было одинаковым для всех пузырей.';

  @override
  String get hyphenate => 'Переносы по слогам';

  @override
  String get hyphenateInfo =>
      'Длинные русские слова можно переносить по слогам («пре-восходительство»). Перенос ставится только там, где без него текст пришлось бы заметно уменьшить.';

  @override
  String get shapeFit => 'Строки по форме пузыря';

  @override
  String get shapeFitInfo =>
      'Строки ложатся по овалу пузыря, как у леттеров: сверху и снизу короче, посередине длиннее; размер букв в пузыре один. Работает, когда в пузыре один кусок текста. Для одного пузыря — в его оформлении.';

  @override
  String get fontSuggest => 'Подобрать шрифт…';

  @override
  String get fontSuggestTitle => 'Похожие шрифты';

  @override
  String get fontSuggestHint =>
      'Сравнение с буквами оригинала на этой странице. Шрифт сам не меняется: выберите подходящий.';

  @override
  String get fontSuggestNoText =>
      'На странице нет распознанного текста: сначала нажмите «Распознать».';

  @override
  String get fontSuggestForAll => 'Для всех пузырей';

  @override
  String get fontSuggestForBlock => 'Только для этого пузыря';

  @override
  String get fontSuggestOriginal => 'Оригинал';

  @override
  String get caseToggle =>
      'ЗАГЛАВНЫЕ ↔ обычные буквы на этой странице или выбранных страницах';

  @override
  String get caseToggleBlock => 'ЗАГЛАВНЫЕ ↔ обычные буквы в этом пузыре';

  @override
  String get sizeFromSource => 'Размер как в оригинале';

  @override
  String get sizeFromSourcePages =>
      'Размер букв как в оригинале на этой странице или выбранных страницах (в тесном пузыре меньше)';

  @override
  String get sizeFromSourceUnknown =>
      'Размер букв оригинала неизвестен: нажмите «Распознать» ещё раз.';

  @override
  String get styleResetPages =>
      'Сбросить оформление пузырей на этой странице или выбранных страницах';

  @override
  String get hyphenateBlock => 'Переносы';

  @override
  String get shapeFitBlock => 'По форме пузыря';

  @override
  String get fromSource => 'как в оригинале';

  @override
  String get textFit => 'Вписывание';

  @override
  String get showLookInPanel => 'Показывать оформление в панели';

  @override
  String get runBigger => 'Крупнее';

  @override
  String get runSmaller => 'Мельче';

  @override
  String get runClear => 'Убрать оформление выделенного';

  @override
  String get runHint =>
      'Выделите слово или знак в переводе — появятся кнопки, чтобы оформить его отдельно.';

  @override
  String get runAsBubble => 'Как у пузыря';

  @override
  String get outlineNone => 'Без обводки';

  @override
  String get lookPreset => 'Стиль';

  @override
  String get lookPresetNone => 'Без стиля';

  @override
  String get lookPresetSave => 'Сохранить оформление как стиль…';

  @override
  String get lookPresetName => 'Название стиля';

  @override
  String lookPresetUpdate(String name) {
    return 'Обновить стиль «$name» по этому пузырю';
  }

  @override
  String lookPresetDelete(String name) {
    return 'Удалить стиль «$name»';
  }

  @override
  String get lookPresetHelp =>
      'Стиль — набор оформления (шрифт, цвет, обводка, жирный…), который ставится одним щелчком на пузырь или слово. Изменили стиль — изменились все пузыри и слова с ним.';

  @override
  String get keyPaste => 'Вставить страницы из буфера обмена';

  @override
  String pastedPageName(String time) {
    return 'Вставка $time';
  }

  @override
  String get pasteNothing => 'В буфере обмена нет картинки или файлов';

  @override
  String get pasteBelow => 'Вставить из буфера под эту страницу';

  @override
  String get addBelow => 'Добавить файлы под эту страницу…';

  @override
  String repeatsTitle(String count) {
    return 'Уже добавлены: $count';
  }

  @override
  String get repeatsHint =>
      'Такие же картинки уже есть среди страниц. Отметьте те, что всё равно нужно добавить. Миниатюры: новый файл и страница, которая уже есть; щелчок по ним или по «Сравнить» покажет обе крупно.';

  @override
  String get repeatsCompare => 'Сравнить';

  @override
  String get repeatsCompareNew => 'Добавляемый файл';

  @override
  String repeatsComparePage(String number) {
    return 'Страница $number';
  }

  @override
  String get repeatsCompareAdding => 'Тоже добавляется';

  @override
  String repeatsSameAs(String number, String name) {
    return 'как страница $number «$name»';
  }

  @override
  String repeatsSameAsNew(String name) {
    return 'как «$name» из добавляемых';
  }

  @override
  String get repeatsSkipAll => 'Пропустить все';

  @override
  String repeatsAddPicked(String count) {
    return 'Добавить отмеченные ($count)';
  }

  @override
  String get repeatsAddAll => 'Всё равно добавить все';

  @override
  String repeatsLeft(String count) {
    return 'Повторы не добавлены: $count';
  }

  @override
  String get pageSort =>
      'Порядок страниц (страницы можно и перетаскивать мышкой)';

  @override
  String get pageSortNameUp => 'По имени: А → Я';

  @override
  String get pageSortNameDown => 'По имени: Я → А';

  @override
  String get pageSortDateUp => 'По дате файла: старые сначала';

  @override
  String get pageSortDateDown => 'По дате файла: новые сначала';

  @override
  String get pageSortReverse => 'Перевернуть порядок';

  @override
  String get pageSortDone => 'Порядок страниц изменён';

  @override
  String get gridTileSize => 'Размер миниатюр';

  @override
  String get pageNumbers => 'Номера страниц';

  @override
  String get pageNumbersHint => 'номера: 1,5-8,10';

  @override
  String get pageNumbersTip =>
      'Выбрать страницы номерами, например 1,5-8,10, и нажать Enter. Выбранные страницы берут шаги (Найти текст, Распознать…), обмен с чатом, экспорт и «Перевести выбранные».';

  @override
  String pageNumbersWrong(String part, String count) {
    return 'Не понял «$part»: страниц всего $count';
  }

  @override
  String get pageNumbersPick => 'Выбрать (Enter)';

  @override
  String translateSelected(String count) {
    return 'Перевести выбранные ($count)';
  }

  @override
  String get translateShort => 'Перевести';

  @override
  String translateShortCount(String count) {
    return 'Перевести ($count)';
  }

  @override
  String get translateWhich =>
      'Что переводить: всё или только выбранные страницы (выбор запоминается)';

  @override
  String get translateAllPages => 'Перевести всё';

  @override
  String get translateSelectedHint =>
      'Выберите страницы: Ctrl+щелчок в списке, номера вроде 1,5-8 или галочки в сетке';

  @override
  String get exportNumbers => 'Выбранные / номера';

  @override
  String exportNumbersReady(String done, String count) {
    return 'Переведённых среди них: $done из $count — сохранятся только они';
  }

  @override
  String get exportNames => 'Имена файлов';

  @override
  String get exportNamesPages => 'Как у страниц';

  @override
  String get exportNamesTemplate => 'Имя + номер';

  @override
  String get exportNamePrefix => 'Имя (текст перед номером)';

  @override
  String get exportNameStart => 'Начать с';

  @override
  String get exportNameStartWrong => 'Только цифры';

  @override
  String exportNamesExample(String example) {
    return 'Получится: $example  (цифр в номере столько, сколько написано в «Начать с»)';
  }

  @override
  String get keyNavigator => 'Мини-вид: показать или скрыть';

  @override
  String navigatorToggle(String key) {
    return 'Мини-вид — вся страница с рамкой того, что видно; щелчок или перетаскивание в нём переносит вид ($key)';
  }

  @override
  String get settingsAsPanel =>
      'Настройки панелью рядом со страницей: страница остаётся видна';

  @override
  String get settingsFullWindow => 'Настройки на всё окно';

  @override
  String get settingsView => 'Открывать настройки';

  @override
  String get settingsViewFull => 'На всё окно';

  @override
  String get settingsViewPanel => 'Панелью рядом со страницей';

  @override
  String get settingsViewLast => 'Как в прошлый раз';

  @override
  String get settingsViewHelp =>
      'Пока программа открыта, настройки открываются так, как вы их оставили (кнопка в заголовке настроек). Здесь — как открывать после запуска программы.';

  @override
  String removePicked(String count) {
    return 'Убрать выбранные ($count)…';
  }

  @override
  String removePagesTitle(String count) {
    return 'Убрать из списка страниц: $count?';
  }

  @override
  String get removePagesBody =>
      'Файлы на диске останутся. Перевод и правки этих страниц пропадут, если они не сохранены в проект или не экспортированы.';

  @override
  String get removePagesYes => 'Убрать';
}
