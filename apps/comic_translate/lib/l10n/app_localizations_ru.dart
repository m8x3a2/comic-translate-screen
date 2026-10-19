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
  String get showInFolder => 'Показать в папке';

  @override
  String get goToPage => 'Перейти к странице';

  @override
  String reasonModelMissing(String name) {
    return 'модель «$name» не скачана';
  }

  @override
  String reasonTranslation(String message) {
    return 'ошибка перевода: $message';
  }

  @override
  String get reasonImage => 'не удалось прочитать картинку';

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
}
