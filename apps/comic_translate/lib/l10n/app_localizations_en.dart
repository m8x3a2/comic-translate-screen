// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Comic Translate Screen';

  @override
  String get homeTagline => 'Translate comics on your own computer';

  @override
  String get openFiles => 'Open files…';

  @override
  String get openFolder => 'Open folder…';

  @override
  String get addPages => 'Add pages';

  @override
  String get dropHint => 'or drag files into this window';

  @override
  String get supportedFormats =>
      'Images (PNG, JPG, WEBP, BMP), comic archives (CBZ, ZIP, EPUB, CBR, CB7, CBT), PDF, Photoshop files (PSD) and projects (.ctsproj)';

  @override
  String get privacyLocal =>
      'Everything runs on this computer; nothing is sent anywhere.';

  @override
  String privacySends(String host) {
    return 'For translation, the text is sent to $host';
  }

  @override
  String get importing => 'Opening files…';

  @override
  String importFailed(String name, String error) {
    return 'Could not open $name: $error';
  }

  @override
  String skippedFiles(String names) {
    return 'Skipped (not images, archives or PDF): $names';
  }

  @override
  String get noPagesFound => 'No pages found in the selected files';

  @override
  String get closeAll => 'Close all pages';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get removePage => 'Remove page';

  @override
  String get translateAll => 'Translate all';

  @override
  String get translateAgain => 'Translate again';

  @override
  String get stop => 'Stop';

  @override
  String get stopping => 'Stopping…';

  @override
  String get report => 'Report';

  @override
  String get export => 'Export';

  @override
  String get settings => 'Settings';

  @override
  String get sourceLanguage => 'Source language';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get languageAuto => 'Auto';

  @override
  String get languageAutoHint =>
      'Source language: found by the letters of each bubble (Latin, Cyrillic, Japanese, Korean, Chinese). For English pages, choosing English reads more accurately.';

  @override
  String get viewOriginal => 'Original';

  @override
  String get viewTranslated => 'Translation';

  @override
  String get showBoxes => 'Text boxes';

  @override
  String get zoomFit => 'Fit to window';

  @override
  String get zoomActual => 'Actual size';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get notTranslatedYet => 'This page is not translated yet';

  @override
  String pageEnlarged(String factor) {
    return 'Enlarged ×$factor for sharp text';
  }

  @override
  String get textPanel => 'Text';

  @override
  String get noTextFound => 'No text found on this page';

  @override
  String get translateToSeeText => 'Translate the page to see its text here';

  @override
  String get stageLoading => 'Loading models';

  @override
  String stageDownloading(String percent) {
    return 'Downloading models: $percent%';
  }

  @override
  String get stageDetect => 'Finding text';

  @override
  String get stageOcr => 'Reading text';

  @override
  String get stageTranslate => 'Translating';

  @override
  String get stageClean => 'Removing text';

  @override
  String get stageRender => 'Drawing the translation';

  @override
  String get stageExport => 'Saving';

  @override
  String progressPage(String current, String total) {
    return 'Page $current of $total';
  }

  @override
  String remaining(String time) {
    return 'about $time left';
  }

  @override
  String pagesSummary(String total, String done) {
    return 'Pages: $total, translated: $done';
  }

  @override
  String statusSkipped(String reason) {
    return 'Skipped: $reason';
  }

  @override
  String get statusDone => 'Translated';

  @override
  String get statusRunning => 'In progress';

  @override
  String get reportTitle => 'Translation report';

  @override
  String reportSummary(String done, String total, String time) {
    return 'Translated $done of $total pages in $time';
  }

  @override
  String get reportCancelled => 'Stopped before the end';

  @override
  String get reportsPrivacyNote =>
      'What goes into a bug report: the log (which steps ran, how long they took, the file names of the pages, errors) and the settings. API keys are masked; there are no page pictures. Recognized and translated text is in it only while the test mode is on, plus up to 300 characters of an online translator\'s reply when that reply was broken. Reports stay on this computer and are never sent anywhere by themselves.';

  @override
  String reportTotalPerPage(String time) {
    return 'total $time';
  }

  @override
  String secondsShort(String value) {
    return '$value s';
  }

  @override
  String minutesSeconds(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String stepDoneDetect(String count) {
    return 'Bubbles found: $count';
  }

  @override
  String stepDoneRecognize(String count) {
    return 'Bubbles read: $count';
  }

  @override
  String stepDoneTranslate(String count) {
    return 'Bubbles translated: $count';
  }

  @override
  String get stepDoneMask => 'Mask ready';

  @override
  String get stepDoneClean => 'Cleaning done';

  @override
  String stepDoneTime(String what, String time) {
    return '$what in $time';
  }

  @override
  String stepDonePages(String pages, String time) {
    return '$pages pages, $time per page on average';
  }

  @override
  String get reportStepTimes => 'Time of the steps, per page on average:';

  @override
  String get reportSkipped => 'Skipped pages';

  @override
  String reportExported(String path) {
    return 'Text and cleaned pages were saved to $path';
  }

  @override
  String get reportNoSkipped => 'Every page went through.';

  @override
  String reportStopped(String reason) {
    return 'Translation stopped: $reason. The remaining pages were not sent.';
  }

  @override
  String get handEditedTitle => 'Pages changed by hand';

  @override
  String handEditedBody(String count) {
    return 'Pages to translate that were changed by hand (text, boxes, formatting or cleaning): $count. Translating them again replaces those changes; Ctrl+Z on a page brings them back while the program is open.';
  }

  @override
  String get handEditedTranslate => 'Translate again';

  @override
  String get handEditedSkip => 'Skip them';

  @override
  String get missingAddressTitle => 'Server address needed';

  @override
  String missingAddressBody(String name) {
    return '\"$name\" has no server address. Enter it in Settings → Translator (for example https://openrouter.ai/api/v1, or http://localhost:1234/v1 for LM Studio), or choose another translator.';
  }

  @override
  String get missingKeyTitle => 'API key needed';

  @override
  String missingKeyBody(String name, String host) {
    return '\"$name\" sends text to $host, which needs an API key. Enter it in Settings → Translator (it is stored in Windows secure storage), or choose a local translator.';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get goToPage => 'Go to page';

  @override
  String reasonModelMissing(String name) {
    return 'model \"$name\" is not downloaded';
  }

  @override
  String get reasonImage => 'the image could not be read';

  @override
  String get reasonWorkerStopped =>
      'page processing stopped unexpectedly (details are in the log; you can create a bug report in Settings)';

  @override
  String withDetails(String text, String details) {
    return '$text (details: $details)';
  }

  @override
  String get trErrConfig =>
      'the translator is not set up: enter the server address and model in Settings';

  @override
  String get trErrAuth =>
      'the server did not accept the API key; check the key in Settings';

  @override
  String get trErrCredits =>
      'the translator account has run out of money or credits';

  @override
  String get trErrNotFound => 'wrong server address or model name';

  @override
  String get trErrRateLimit =>
      'the server is busy with too many requests and asks to wait; try again later';

  @override
  String get trErrServer => 'the translator\'s server failed; try again later';

  @override
  String get trErrNetwork =>
      'no connection to the translator\'s server; check the internet connection';

  @override
  String get trErrTimeout => 'the translator\'s server did not answer in time';

  @override
  String get trErrBadReply =>
      'the translator answered in a form the program cannot read';

  @override
  String get trErrCutOff =>
      'the answer was cut off: the model ran out of \"Maximum answer length\" (translator settings → \"More settings\"). Raise it or lower \"Pages in one request\"; models that think first spend the length on thinking too';

  @override
  String get trErrOther => 'translation failed';

  @override
  String get needsArchiveTool =>
      'CBR, RAR, CB7 and 7Z need 7-Zip (7-zip.org) or WinRAR installed';

  @override
  String exportFailed(String error) {
    return 'Could not save the pages: $error';
  }

  @override
  String importedAs(String model) {
    return 'installed as $model';
  }

  @override
  String get notAModelFile => 'not a known model file';

  @override
  String get unexpectedError =>
      'Something went wrong. Details are in the log; a bug report helps fix it.';

  @override
  String runFailed(String error) {
    return 'Could not start: $error';
  }

  @override
  String get networkTitle => 'Send text over the network?';

  @override
  String networkBody(String name, String host, String where) {
    return '\"$name\" sends the recognized text to $host ($where).';
  }

  @override
  String get networkWhereLan => 'a computer on your local network';

  @override
  String get networkWhereCloud => 'an internet service';

  @override
  String get networkBodyImage =>
      'Page images are sent too (setting \"Send page image\").';

  @override
  String get networkOffline =>
      'To work fully offline, choose a local translator in Settings.';

  @override
  String get allowOnce => 'Allow this time';

  @override
  String get allowAlways => 'Always allow for this server';

  @override
  String get downloadTitle => 'Download models?';

  @override
  String downloadBody(String size) {
    return 'These models are needed and not downloaded yet ($size in total). They are saved on this computer and then work without internet.';
  }

  @override
  String downloadFrom(String size, String host) {
    return '$size, from $host';
  }

  @override
  String get download => 'Download';

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get exportTitle => 'Choose a folder for the translated pages';

  @override
  String exportDone(String count, String path) {
    return 'Saved $count page(s) to $path';
  }

  @override
  String get nothingToExport => 'No translated pages yet';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsTranslator => 'Translator';

  @override
  String get settingsTools => 'Recognition and cleaning';

  @override
  String get settingsText => 'Text';

  @override
  String get settingsUpscale => 'Enlarging';

  @override
  String get settingsExport => 'Export';

  @override
  String get settingsModels => 'Models';

  @override
  String get settingsAbout => 'About';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'As in Windows';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get uiLanguage => 'Interface language';

  @override
  String get useGpu => 'Use the graphics card (DirectML)';

  @override
  String get useGpuHelp =>
      'Faster on some computers; if something does not work, the processor is used automatically.';

  @override
  String get testMode => 'Test mode';

  @override
  String get testModeHelp =>
      'Saves every step of each run for bug reports (uses disk space).';

  @override
  String get openLogs => 'Open logs folder';

  @override
  String get bugReport => 'Create bug report';

  @override
  String get bugReportHelp =>
      'A zip with logs and settings, without keys and without pictures.';

  @override
  String bugReportDone(String path) {
    return 'Report saved: $path';
  }

  @override
  String unexpectedErrorReported(String path) {
    return 'Something went wrong. A bug report was saved: $path';
  }

  @override
  String get autoBugReport => 'Build a bug report automatically';

  @override
  String get autoBugReportHelp =>
      'After an unexpected error the program saves a report by itself and shows where it is. It stays on this computer.';

  @override
  String get autoBugReportOffTitle => 'Turn off automatic bug reports?';

  @override
  String get autoBugReportOffText =>
      'This is an important feature: the report keeps what happened right at the moment of the error, so the problem can be found and fixed. It stays only on your computer and is never sent anywhere; it has no API keys and no page images.\n\nWithout it, a report has to be built by hand after an error, and details may already be lost.';

  @override
  String get autoBugReportKeepOn => 'Keep it on';

  @override
  String get autoBugReportTurnOff => 'Turn off';

  @override
  String get translator => 'Translator';

  @override
  String get privacyLocalBadge => 'On this computer';

  @override
  String get privacyLanBadge => 'Local network';

  @override
  String get privacyCloudBadge => 'Internet';

  @override
  String sendsDataWarning(String host) {
    return 'Sends text outside this computer: $host';
  }

  @override
  String get savedSecurely =>
      'Stored in Windows secure storage, never in files or logs. Each translator (and later each online text recognizer) keeps its own key. A saved key is never shown in full, only its last 4 characters.';

  @override
  String get secretSet => 'Saved';

  @override
  String get secretNotSet => 'Not set';

  @override
  String get secretRemove => 'Delete key';

  @override
  String get approvals => 'Allowed servers';

  @override
  String get approvalsNone => 'None yet; the app asks before sending anything.';

  @override
  String get revoke => 'Revoke';

  @override
  String get extraContext => 'Extra context for the translator';

  @override
  String get extraContextHelp =>
      'For example names, setting or tone of the comic.';

  @override
  String get sendPageImage => 'Send page image';

  @override
  String get sendPageImageHelp =>
      'Helps some models understand the scene; the whole page is sent to the translator.';

  @override
  String get detector => 'Text detection';

  @override
  String get ocr => 'Text recognition';

  @override
  String get readLevel => 'Recognition quality (English)';

  @override
  String get readLevelScreens =>
      'Recognition quality for sites and games (English)';

  @override
  String get readLevelSimple => 'Simple — as before';

  @override
  String get readLevelMedium => 'Medium (default)';

  @override
  String get readLevelHigh => 'High';

  @override
  String get readLevelUltra => 'Ultra';

  @override
  String get readLevelInfo =>
      'How many networks read each block of English text (times on a slow laptop without a graphics card, the reading of a page alone; finding the text and preparing small text come on top):\n• Simple — as before: PP-OCRv5. About 1 s.\n• Medium — PP-OCRv6 small reads too (21 MB, already there for Chinese and Japanese); of the two readings of a block, the one with more real English words is kept. About 2 s.\n• High — after Medium, the PaddleOCR-VL network reads again the blocks where either fast reader found a word missing from the dictionary (about half). Nearly Ultra, faster: about 7 s per such block, 30 s per page on average (about 1 min for a manga screenshot).\n• Ultra — PaddleOCR-VL reads every block: best of all on full comic pages. About 7 s per block, 1 min per page on average (up to 3 min).\nPaddleOCR-VL is a separate download (1.8 GB, Apache-2.0 licence) and takes about 2.5 GB of memory; the first block after starting takes 10–20 s longer, a huge block of a wall of text up to 2 min. Until it is there, High and Ultra work as Medium.\nOther languages are read as on Simple.';

  @override
  String get inpainter => 'Text removal';

  @override
  String get cleanLevel => 'Text removal quality';

  @override
  String get cleanLevelSimple => 'Simple — as before';

  @override
  String get cleanLevelMedium => 'Medium';

  @override
  String get cleanLevelHigh => 'High (default)';

  @override
  String get cleanLevelCustom => 'Custom combination';

  @override
  String get cleanLevelInfo =>
      'How text is removed from the page (times on a slow laptop without a graphics card, per page on average):\n• Simple — as before: a mask by the algorithm with a margin around the letters, repainted by the AOT network. About 4 s.\n• Medium — the comic-text-detector network finds the letters themselves and AOT repaints only them: the drawing next to the text is hardly touched, 2–4 times fewer letter remains. About 6 s.\n• High — the same, repainted by LaMa: best on grey screentone and drawings. About 7 s, plus 8 s on the first run. Large pages take longer (up to 15–20 s).\nWhite bubbles are filled at once, without a network, on every level. comic-text-detector is a separate download (82 MB, GPL-3.0 licence); until it is there, the mask of Simple is used.';

  @override
  String get hdStrategy => 'Cleaning large pages';

  @override
  String get hdResize => 'Shrink (faster)';

  @override
  String get hdCrop => 'In pieces (more precise)';

  @override
  String get hdOriginal => 'Full size (slow)';

  @override
  String get resizeLimit => 'Shrink to (px, long side)';

  @override
  String get cropMargin => 'Piece margin (px)';

  @override
  String get cropTrigger => 'Use pieces from (px)';

  @override
  String get textPrep => 'Preparing small text for reading';

  @override
  String get textPrepScreens =>
      'Preparing small text for reading (sites and games)';

  @override
  String get fixCyrillic => 'Fix Latin look-alikes in Cyrillic text';

  @override
  String get fixCyrillicHelp =>
      '\"HET\" becomes \"НЕТ\"; may also change Latin words.';

  @override
  String get font => 'Font';

  @override
  String get fontDefault => 'Pangolin (built in)';

  @override
  String get minFontSize => 'Smallest size (pt)';

  @override
  String get maxFontSize => 'Largest size (pt)';

  @override
  String get textColor => 'Text colour';

  @override
  String get outline => 'Outline';

  @override
  String get outlineColor => 'Outline colour';

  @override
  String get outlineWidth => 'Outline width';

  @override
  String get upperCase => 'Upper case';

  @override
  String get alignment => 'Alignment';

  @override
  String get alignLeft => 'Left';

  @override
  String get alignCenter => 'Centre';

  @override
  String get alignRight => 'Right';

  @override
  String get placeInBlock => 'Centre the text in its bubble';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get underline => 'Underline';

  @override
  String get upscaleHelp =>
      'On small pages the translation is drawn on an enlarged copy, so the letters stay sharp. The method only affects the picture.';

  @override
  String get upscaleMode => 'When to enlarge';

  @override
  String get upscaleAuto => 'Automatically (small pages)';

  @override
  String get upscaleOff => 'Never';

  @override
  String get upscaleWidth => 'To width';

  @override
  String get upscaleWidthValue => 'Width (px)';

  @override
  String get upscaleMethod => 'Method';

  @override
  String get upscaleFast => 'Fast (Lanczos)';

  @override
  String get upscaleGood => 'Good (neural network) — coming later';

  @override
  String get upscaleBest => 'Best (larger neural network) — coming later';

  @override
  String get imageFormat => 'Image format';

  @override
  String get formatSource => 'Same as the original';

  @override
  String get autoExport => 'After \"Translate all\", also save';

  @override
  String get autoExportHelp =>
      'Into a comic_translate_<date> folder next to the original files.';

  @override
  String get exportRawText => 'Recognized text';

  @override
  String get exportTranslatedText => 'Translated text';

  @override
  String get exportCleaned => 'Cleaned pages';

  @override
  String get modelsFolder => 'Models folder';

  @override
  String get modelsFolderHelp =>
      'Models already downloaded are not moved; copy them or use Import.';

  @override
  String get changeFolder => 'Change…';

  @override
  String get defaultFolder => 'Default';

  @override
  String get open => 'Open';

  @override
  String get importModels => 'Import from disk…';

  @override
  String get importModelsHelp =>
      'Model files or zip archives copied from another computer; they are recognized by checksum.';

  @override
  String importModelsDone(String count) {
    return 'Installed model files: $count';
  }

  @override
  String get modelInstalled => 'Downloaded';

  @override
  String get modelMissing => 'Not downloaded';

  @override
  String get modelCorrupt => 'Damaged';

  @override
  String get verify => 'Check';

  @override
  String get delete => 'Delete';

  @override
  String deleteModelConfirm(String name) {
    return 'Delete $name? It can be downloaded again later.';
  }

  @override
  String get verifyOk => 'Files are intact';

  @override
  String verifyBad(String files) {
    return 'Damaged files: $files';
  }

  @override
  String get aboutIndependent =>
      'An independent project based on ogkalu2/comic-translate; not the official version.';

  @override
  String get aboutPrivacy =>
      'No accounts, no telemetry. Data leaves this computer only for a translator you choose, and the app asks first.';

  @override
  String get license => 'License: Apache 2.0';

  @override
  String get dataFolder => 'Data folder';

  @override
  String get thirdPartyLicenses => 'Third-party licenses';

  @override
  String aboutAuthor(String author) {
    return 'Author: $author';
  }

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get drawingPages => 'Drawing the edited pages…';

  @override
  String get toolPan => 'Hand: move the page, click a bubble to select it (H)';

  @override
  String get toolBoxes =>
      'Boxes: draw a box around text, move or resize it (R)';

  @override
  String get toolText => 'Translation: move, resize and turn the text (T)';

  @override
  String get toolBrush => 'Brush: paint what to clean (B)';

  @override
  String get toolEraser => 'Eraser: remove parts of the mask (E)';

  @override
  String get brushSize => 'Brush size ([ and ])';

  @override
  String get clearMask => 'Remove the whole mask';

  @override
  String get undo => 'Undo (Ctrl+Z)';

  @override
  String get redo => 'Redo (Ctrl+Y)';

  @override
  String get stepDetect => 'Find text';

  @override
  String get stepDetectHelp =>
      'finds the text on this page and puts boxes around it';

  @override
  String get stepRecognize => 'Recognize';

  @override
  String get stepRecognizeHelp => 'reads the text in the boxes';

  @override
  String get stepTranslate => 'Translate';

  @override
  String get stepTranslateHelp =>
      'translates the recognized text of this page (finds and reads it first if needed)';

  @override
  String get stepMask => 'Mask';

  @override
  String get stepMaskHelp =>
      'marks the letters to remove in red; correct it with the brush and the eraser';

  @override
  String get stepClean => 'Clean';

  @override
  String get stepCleanHelp => 'removes the marked text from the picture';

  @override
  String get fontFile => 'Font file…';

  @override
  String get fontSize => 'Size';

  @override
  String get sizeAuto => 'Auto';

  @override
  String get sizeUnknown =>
      'The size is chosen once the bubble has a translation';

  @override
  String get colorAuto => 'As in the original';

  @override
  String get textStyle => 'Style';

  @override
  String get verticalText => 'Vertical text';

  @override
  String get rotation => 'Rotation';

  @override
  String get styleToAll => 'To all on the page';

  @override
  String get styleReset => 'Reset';

  @override
  String get findReplace => 'Find and replace (Ctrl+F)';

  @override
  String get noBlocksHint =>
      'No text boxes on this page yet. Use “Find text” above the page, “Translate all”, or draw boxes with the Boxes tool.';

  @override
  String get recognizeBlock => 'Recognize this box again';

  @override
  String get translateBlock => 'Translate this box again';

  @override
  String get deleteBlock => 'Delete the box (Delete)';

  @override
  String get deselect => 'Close (Esc)';

  @override
  String get sourceText => 'Recognized text';

  @override
  String get translationText => 'Translation';

  @override
  String get textLook => 'Look of the text';

  @override
  String get findHint => 'Find';

  @override
  String get matchCase => 'Match case';

  @override
  String get wholeWord => 'Whole words';

  @override
  String get useRegex => 'Regular expression';

  @override
  String get preserveCase =>
      'Preserve case: the replacement takes the case of the found text (hello → world, HELLO → WORLD, Hello → World)';

  @override
  String get previousMatch => 'Previous (Shift+Enter)';

  @override
  String get nextMatch => 'Next (Enter)';

  @override
  String get searchInTranslation => 'In translations';

  @override
  String get searchInSource => 'In recognized text';

  @override
  String get searchAllPages => 'All pages';

  @override
  String get searchThisPage => 'This page';

  @override
  String badRegex(String error) {
    return 'Not a valid regular expression: $error';
  }

  @override
  String matchesSummary(String count, String pages) {
    return 'Found: $count on $pages page(s)';
  }

  @override
  String get replaceHint => 'Replace with';

  @override
  String get replace => 'Replace';

  @override
  String get replaceAll => 'Replace all';

  @override
  String replacedCount(String count) {
    return 'Replaced: $count';
  }

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutsTooltip => 'Keyboard shortcuts (F1)';

  @override
  String get keysGroupFiles => 'Pages';

  @override
  String get keysGroupTools => 'Tools';

  @override
  String get keysGroupEdit => 'Editing';

  @override
  String get keysGroupMouse => 'Mouse';

  @override
  String get keyOpen => 'Open files';

  @override
  String get keyTranslateAll => 'Translate all';

  @override
  String get keyPan => 'Hand: move the page, select a bubble';

  @override
  String get keyBoxes => 'Boxes around the text';

  @override
  String get keyText => 'Move, resize and turn the translation';

  @override
  String get keyBrush => 'Brush: mark what to clean';

  @override
  String get keyEraser => 'Eraser: unmark';

  @override
  String get keyUndo => 'Undo';

  @override
  String get keyRedo => 'Redo';

  @override
  String get keyDelete => 'Delete the selected box';

  @override
  String get keyDeselect => 'Deselect the bubble';

  @override
  String get keyFind => 'Find and replace';

  @override
  String get keyFindNext => 'Next / previous match (in the find field)';

  @override
  String get mouseWheel => 'Wheel';

  @override
  String get mouseWheelHelp => 'Zoom in and out';

  @override
  String get mouseMiddle => 'Middle button, drag';

  @override
  String get mouseMiddleHelp => 'Move the page with any tool';

  @override
  String get mouseDouble => 'Double click on a translation';

  @override
  String get mouseDoubleHelp =>
      'Edit its text in the right panel (Translation tool)';

  @override
  String get keysNote =>
      'Keys without Ctrl or Alt do nothing while you type in a text field. They work with any keyboard layout. To change them: Settings → Keys.';

  @override
  String get keysGroupWindow => 'Window';

  @override
  String get keyHelp => 'This list of keys';

  @override
  String get keyFullScreen => 'Full screen on and off';

  @override
  String get keyPreviousPage => 'Previous page';

  @override
  String get keyNextPage => 'Next page';

  @override
  String get keyBrushSmaller => 'Smaller brush';

  @override
  String get keyBrushLarger => 'Larger brush';

  @override
  String get settingsKeys => 'Keys';

  @override
  String get keysSettingsHelp =>
      'Click an action to give it another key or combination. Keys without Ctrl or Alt do nothing while you type in a text field.';

  @override
  String get keysNone => 'no key';

  @override
  String get keysChange => 'Change the key';

  @override
  String get keysDefault => 'Back to the default key';

  @override
  String keysCaptureTitle(String action) {
    return 'New key: $action';
  }

  @override
  String get keysCaptureBody =>
      'Press a key or a combination with Ctrl, Shift or Alt.';

  @override
  String keysCaptureTaken(String action) {
    return 'Now used by \"$action\": it will be taken from there.';
  }

  @override
  String get keysCaptureReserved =>
      'Text fields and windows need this key; choose another one.';

  @override
  String get keysCaptureNoKey => 'No key';

  @override
  String get fullScreenOn => 'Full screen. Press F11 to leave it.';

  @override
  String secretSavedTail(String tail) {
    return 'Saved: …$tail';
  }

  @override
  String get secretShow => 'Show what you typed';

  @override
  String get secretHide => 'Hide';

  @override
  String get secretReplace => 'Replace';

  @override
  String get secretReplaceHint => 'Paste a new key to replace the saved one';

  @override
  String get secretRemoveTitle => 'Delete the key?';

  @override
  String get secretRemoveBody =>
      'The saved key is removed from Windows secure storage. To translate with this service again, paste the key anew. The key itself stays valid on the service\'s site: revoke it there if you no longer need it.';

  @override
  String get keyStatusCheck => 'Key details';

  @override
  String get keyStatusRefresh => 'Refresh key details';

  @override
  String keyStatusHelp(String host) {
    return 'Asks $host for the key name, its limit and what is left. Only the key is sent, and only when you press the button; the answer stays until the program closes.';
  }

  @override
  String get keyStatusNeedsKey => 'Save the API key first';

  @override
  String get keyStatusChecking => 'Checking…';

  @override
  String keyStatusLimit(String limit, String used, String left) {
    return 'Limit $limit, spent $used, left $left';
  }

  @override
  String keyStatusNoLimit(String used) {
    return 'The key has no limit. Spent: $used';
  }

  @override
  String keyStatusToday(String today, String month) {
    return 'Spent today (UTC): $today, this month: $month';
  }

  @override
  String get keyStatusDelay =>
      'The service updates these numbers a few minutes late; the usage below is counted at once.';

  @override
  String get keyStatusResetDaily => 'The limit starts again every day.';

  @override
  String get keyStatusResetWeekly => 'The limit starts again every week.';

  @override
  String get keyStatusResetMonthly => 'The limit starts again every month.';

  @override
  String keyStatusFree(String used, String limit, String left) {
    return 'Free models today: $used of $limit requests, $left left';
  }

  @override
  String get keyStatusFreeNote =>
      'Free models also allow about 20 requests per minute; the server does not report that limit in advance.';

  @override
  String keyStatusLabel(String label) {
    return 'Key: $label';
  }

  @override
  String get keyStatusFreeTier =>
      'Free account: no credits were ever bought, so free models allow fewer requests a day.';

  @override
  String get keyStatusPaidTier =>
      'Credits were bought for this account: free models allow more requests a day.';

  @override
  String get modelsChoose => 'Choose…';

  @override
  String modelsChooseHelp(String host) {
    return 'The list of models from $host; your key does not go along';
  }

  @override
  String modelsTitle(String host) {
    return 'Models of $host';
  }

  @override
  String modelsHelp(String host) {
    return 'The list comes from $host; nothing of yours goes along (not the key either). Prices are per million tokens (a token is about 3–4 letters): for the request and for the answer. Free models allow a limited number of requests a day (see \"Key details\" in the translator settings).';
  }

  @override
  String get modelsSearch => 'Search: name or id';

  @override
  String get modelsNewest => 'Newest first';

  @override
  String get modelsCheapest => 'Cheapest first';

  @override
  String get modelsByName => 'By name';

  @override
  String get modelsByContext => 'Longest context first';

  @override
  String get modelsFreeOnly => 'Free only';

  @override
  String get modelsVisionOnly => 'Takes pictures';

  @override
  String get modelsVisionHelp =>
      'Needed when the page image goes to the translator (\"Send the page image\")';

  @override
  String modelsCount(int shown, int total) {
    return 'Shown: $shown of $total';
  }

  @override
  String get modelsFree => 'free';

  @override
  String modelsPrice(String prompt, String completion) {
    return 'request $prompt · answer $completion per million';
  }

  @override
  String modelsContext(String tokens) {
    return 'context $tokens';
  }

  @override
  String get modelsVision => 'takes pictures';

  @override
  String get modelsNone => 'No models like that';

  @override
  String modelsFailed(String reason) {
    return 'Could not get the list: $reason';
  }

  @override
  String get modelsRetry => 'Try again';

  @override
  String get modelsRefresh => 'Get the list again';

  @override
  String get historyOpen => 'Request history';

  @override
  String get historyPage => 'What the translator answered';

  @override
  String get historyTitle => 'Translator history';

  @override
  String historyHelp(String keep) {
    return 'The last $keep requests to translators over the network (OpenRouter, own server): what went and what came back as it came. Kept only on this computer; the key never goes in, nor the pictures.';
  }

  @override
  String historyOnlyPage(String page) {
    return 'Only $page';
  }

  @override
  String historyCount(int shown, int total) {
    return 'Shown: $shown of $total';
  }

  @override
  String get historyNone =>
      'No requests yet. They appear here after a translation through OpenRouter or your own server.';

  @override
  String get historyNoneForPage =>
      'No requests for this page. Turn the filter off to see all.';

  @override
  String historyOk(int count) {
    return 'Bubbles translated: $count';
  }

  @override
  String historyMissing(int got, int total) {
    return 'Translated $got of $total: the answer has nothing for some bubbles';
  }

  @override
  String historyFailed(String error) {
    return 'Error: $error';
  }

  @override
  String historySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get historyImage => 'with the page image';

  @override
  String historyTokens(int input, int output) {
    return 'tokens: $input in, $output out';
  }

  @override
  String historyWarnings(String warnings) {
    return 'Found when reading the answer: $warnings';
  }

  @override
  String get historySent => 'Sent';

  @override
  String get historyReply => 'Answer (as it came)';

  @override
  String get historyNoReply => '(no answer)';

  @override
  String get historyClear => 'Clear the history';

  @override
  String get historyClearAsk => 'Clear the whole history of requests?';

  @override
  String get historyCopied => 'Copied';

  @override
  String get historyAgain => 'the missing ones again';

  @override
  String get untranslatedMark => 'no translation';

  @override
  String get untranslatedHelp =>
      'The translator\'s answer had nothing for this bubble: it keeps its original lettering. Type a translation, or press \"Translate\" on the bubble.';

  @override
  String get reportUntranslated =>
      'Bubbles without a translation (their lettering stays):';

  @override
  String reportUntranslatedCount(int count) {
    return 'bubbles: $count';
  }

  @override
  String keyStatusFailed(String reason) {
    return 'Could not check: $reason';
  }

  @override
  String keyStatusAt(String time) {
    return 'Checked at $time';
  }

  @override
  String get usageTitle => 'Usage on this computer';

  @override
  String get usageHelp =>
      'The program counts the requests from the servers\' replies. The counter is kept only on this computer and is never sent anywhere. Tokens marked ≈ are estimated: that server does not report them.';

  @override
  String get usageNone => 'No requests to translation servers yet.';

  @override
  String get usageModel => 'Model';

  @override
  String get usageToday => 'Today';

  @override
  String get usageTotal => 'Total';

  @override
  String usageRequests(String count) {
    return 'requests: $count';
  }

  @override
  String usageTokens(String count) {
    return 'tokens: $count';
  }

  @override
  String usageCost(String cost) {
    return 'cost: $cost';
  }

  @override
  String usageSince(String date) {
    return 'Counted since $date';
  }

  @override
  String get usageReset => 'Reset the counter';

  @override
  String get usageResetTitle => 'Reset the counter?';

  @override
  String get usageResetBody =>
      'The local counter starts from zero. Nothing changes on the servers or in your account.';

  @override
  String get reset => 'Reset';

  @override
  String get openProject => 'Open project…';

  @override
  String get saveProject => 'Save project (Ctrl+S)';

  @override
  String get saveProjectAs => 'Save project as… (Ctrl+Shift+S)';

  @override
  String get recentProjects => 'Recent projects';

  @override
  String get projectFileType => 'Comic Translate Screen projects';

  @override
  String get untitledProject => 'Untitled';

  @override
  String projectSavedAt(String time) {
    return 'Saved at $time';
  }

  @override
  String get projectSaving => 'Saving…';

  @override
  String get projectUnsaved => 'Not saved';

  @override
  String get projectNoFile => 'Not saved in a project yet (Ctrl+S)';

  @override
  String projectSaveFailed(String error) {
    return 'Could not save the project: $error';
  }

  @override
  String projectOpenFailed(String error) {
    return 'Could not open the project: $error';
  }

  @override
  String get projectNewer =>
      'it was saved by a newer version of the program; please update it';

  @override
  String get projectNotProject =>
      'this is not a Comic Translate Screen project';

  @override
  String get projectDamaged => 'the file is damaged';

  @override
  String get unsavedTitle => 'Save the changes?';

  @override
  String get unsavedNew =>
      'The pages and edits are not saved in a project yet. Unless you save them, they will be lost.';

  @override
  String unsavedProject(String name) {
    return '“$name” has unsaved changes.';
  }

  @override
  String get dontSave => 'Don\'t save';

  @override
  String get saveAs => 'Save as…';

  @override
  String get recoveryTitle => 'Restore your previous work?';

  @override
  String recoveryBody(String pages, String time) {
    return 'Last time the program closed without saving your work. A copy was kept: $pages page(s), $time.';
  }

  @override
  String get recoveryRestore => 'Restore';

  @override
  String get recoveryDiscard => 'Delete the copy';

  @override
  String get recoveryRestored =>
      'Your previous work is back. Save it as a project to keep it.';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get removeFromList => 'Remove from the list';

  @override
  String get settingsProjects => 'Projects';

  @override
  String get projectAutosave => 'Save projects automatically';

  @override
  String get projectAutosaveHelp =>
      'A project that has a file saves itself a couple of seconds after every change and after every page of “Translate all”. Work that is not saved in a project yet is copied every 2 minutes, so it can be restored after a crash.';

  @override
  String get openingProject => 'Opening the project…';

  @override
  String get keySave => 'Save the project';

  @override
  String get keySaveAs => 'Save the project as a new file';

  @override
  String get exportWhat => 'What to save';

  @override
  String get exportTranslatedPages => 'Pages with the translation';

  @override
  String get exportCleanedPages => 'Cleaned pages (text removed)';

  @override
  String get exportRecognizedJson => 'Recognized text (JSON)';

  @override
  String get exportTranslatedJson => 'Translation as text (JSON)';

  @override
  String get exportWhere => 'Save as';

  @override
  String get exportFolder => 'Folder';

  @override
  String get exportReaderNote =>
      'CBZ, CB7 and PDF are for comic readers: they hold pictures of one kind (with the translation if it is chosen), without texts.';

  @override
  String get exportNeeds7zip => 'CB7 needs 7-Zip installed';

  @override
  String get exportPdfFormat =>
      'In a PDF, PNG keeps every pixel; the other formats become JPEG.';

  @override
  String get exportWhich => 'Pages';

  @override
  String exportAllPages(String count) {
    return 'All finished pages ($count)';
  }

  @override
  String get exportCurrentPage => 'Only the current page';

  @override
  String exportByChapter(String count) {
    return 'A separate file for each chapter ($count)';
  }

  @override
  String get exportStart => 'Export…';

  @override
  String get exportingPages => 'Exporting…';

  @override
  String exportSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get fontAdd => 'Add a font…';

  @override
  String get fontAddHelp =>
      'Fonts are copied into the program\'s folder and appear in every font list. A project keeps the fonts its bubbles use.';

  @override
  String fontsAdded(String count) {
    return 'Fonts added: $count';
  }

  @override
  String get fontRemove => 'Remove the font';

  @override
  String get boxesAll => 'All boxes';

  @override
  String boxesGrow(String px) {
    return 'Make all boxes larger by $px px';
  }

  @override
  String boxesShrink(String px) {
    return 'Make all boxes smaller by $px px';
  }

  @override
  String get boxesDeleteAll => 'Delete all boxes of the page';

  @override
  String get languagesForAll => 'Use this page\'s languages for all pages';

  @override
  String pagesPicked(String count) {
    return 'Pages selected: $count';
  }

  @override
  String get pagesPickedClear => 'Clear the selection';

  @override
  String stepsForPicked(String count) {
    return 'for $count selected pages';
  }

  @override
  String get mousePickPages => 'Ctrl / Shift + click on a page';

  @override
  String get keyPickPages => 'Select several pages for the steps';

  @override
  String get settingsReset => 'Reset this section';

  @override
  String get settingsResetAll => 'Reset all settings';

  @override
  String get settingsResetTitle => 'Reset the settings?';

  @override
  String settingsResetBody(String name) {
    return 'The settings of “$name” go back to how they were at first. API keys, projects and downloaded models stay.';
  }

  @override
  String get settingsResetAllBody =>
      'Every setting goes back to how it was at first, including the translator\'s server and model and the approved servers. API keys, the recent projects and downloaded models stay. If the models were in another folder, the program looks in the usual folder again (the files stay where they are).';

  @override
  String get settingsResetDone => 'Settings reset';

  @override
  String get mouseGrab => 'Space or Ctrl + left button, drag';

  @override
  String get modelDetector => 'Text and bubble finder (RT-DETR)';

  @override
  String get modelDetectorInfo =>
      'Finds the text and the speech bubbles on a page. Needed always, for every language. Small and fast.';

  @override
  String get modelAot => 'Text removal (AOT)';

  @override
  String get modelAotInfo =>
      'Erases the original text and paints the background under it. The default: fast, fine for weak computers.';

  @override
  String get modelLama => 'Better text removal (LaMa)';

  @override
  String get modelLamaInfo =>
      'Restores the drawing under the text more neatly, especially on grey screentone and under sound effects. Slower and larger than AOT. Used by the High text removal level (Settings → Tools → Text removal quality).';

  @override
  String get modelCtd => 'Letters for text removal (comic-text-detector)';

  @override
  String get modelCtdInfo =>
      'Finds the letters themselves, so that text removal repaints them and not the drawing around them. Used by the Medium and High text removal levels. About 2 s per page. By dmMaze, licence GPL-3.0; file from EarthWL/hiyori-onnx.';

  @override
  String get modelVlm => 'Slow accurate reader (PaddleOCR-VL 1.6)';

  @override
  String get modelVlmInfo =>
      'A picture-to-text network: reads an English block as a whole and makes the fewest mistakes. Needed by recognition quality High and Ultra. About 7 s per block on a slow laptop, about 2.5 GB of memory. By PaddlePaddle (Baidu), Apache-2.0 licence.';

  @override
  String get modelOcrEn => 'English';

  @override
  String get modelOcrEnInfo =>
      'Reads English text (PaddleOCR). Needed when the original is in English.';

  @override
  String get modelOcrLatin => 'French, German, Spanish, Italian, Dutch';

  @override
  String get modelOcrLatinInfo =>
      'Reads text in these languages: Latin letters with accents (PaddleOCR).';

  @override
  String get modelOcrEslav => 'Russian';

  @override
  String get modelOcrEslavInfo =>
      'Reads Russian text (PaddleOCR, Cyrillic). Needed when the original is in Russian.';

  @override
  String get modelOcrKorean => 'Korean';

  @override
  String get modelOcrKoreanInfo =>
      'Reads Korean text (PaddleOCR): manhwa and webtoons.';

  @override
  String get modelOcrChinese =>
      'Chinese (and large Japanese text; second English reader)';

  @override
  String get modelOcrChineseInfo =>
      'Reads Chinese text (PaddleOCR). For Japanese it is needed too, with manga-ocr: it reads large titles and captions. For English at recognition quality Medium and High it reads every block a second time.';

  @override
  String get modelOcrJapanese => 'Japanese (manga-ocr)';

  @override
  String get modelOcrJapaneseInfo =>
      'Reads Japanese text, also vertical; trained on manga. Works together with the Chinese model.';

  @override
  String get modelOsd => 'Language detection';

  @override
  String get modelOsdInfo =>
      'Tells the language of the original by its letters, for the source language \"Auto\". Small (3.7 MB), runs on the processor.';

  @override
  String get modelsCore => 'Main (always needed)';

  @override
  String get modelsLanguages => 'Text recognition by language';

  @override
  String get modelsLanguagesHelp =>
      'Download only the languages you translate from. When a model is missing, the program offers to download it before translating.';

  @override
  String get modelsExtra => 'Extra';

  @override
  String get modelsTextPrep => 'Text preparation';

  @override
  String get modelsTextPrepHelp =>
      'Neural networks that enlarge small text before recognition. Only the one chosen in \"Recognition and cleaning → Preparing small text\" is needed.';

  @override
  String modelsNeeded(String language) {
    return 'Download what “$language” needs';
  }

  @override
  String get modelsAll => 'Download all';

  @override
  String get modelsVerifyAll => 'Check all';

  @override
  String get modelsNothingNeeded => 'Everything needed is downloaded';

  @override
  String modelsSummary(String count, String total, String size) {
    return 'Downloaded $count of $total · $size on disk';
  }

  @override
  String get modelsVerifyAllOk => 'All downloaded models are fine';

  @override
  String modelsVerifyAllBad(String names) {
    return 'Damaged: $names. Download them again.';
  }

  @override
  String get useGpuInfo =>
      'Text finding, recognition and cleaning run on the graphics card through DirectML, which is part of Windows and works with NVIDIA, AMD and Intel. On a weak or old card it may be no faster than the processor. Translation is not sped up: it runs on the translator\'s server.';

  @override
  String get gpuChecking => 'Checking the graphics card…';

  @override
  String get speedTestButton => 'Test the speed';

  @override
  String get speedTestTitle => 'Graphics card or processor';

  @override
  String speedTestNeedsModels(String models) {
    return 'The test needs these models: $models. Download them in Settings → Models.';
  }

  @override
  String speedTestRunning(String what) {
    return 'Timing a test page on the $what… (about a minute)';
  }

  @override
  String get speedTestOnCpu => 'processor';

  @override
  String get speedTestOnGpu => 'graphics card';

  @override
  String speedSeconds(String n) {
    return '$n s';
  }

  @override
  String speedTestCpu(String time) {
    return 'Processor: $time per page';
  }

  @override
  String speedTestGpu(String time) {
    return 'Graphics card: $time per page';
  }

  @override
  String speedTestCpuFailed(String reason) {
    return 'Processor: error ($reason)';
  }

  @override
  String speedTestGpuFailed(String reason) {
    return 'Graphics card: failed ($reason)';
  }

  @override
  String get speedTestGpuFaster =>
      'The graphics card is faster: it is better to use it.';

  @override
  String get speedTestCpuBetter =>
      'The processor is as fast or faster: there is no need to switch the graphics card on.';

  @override
  String speedTestSmallGain(String percent) {
    return 'The graphics card is faster by only $percent %: too little to be worth it, the processor is enough.';
  }

  @override
  String get speedTestGpuFailedVerdict =>
      'These models do not run properly on this graphics card: the program will use the processor.';

  @override
  String speedTestReport(String path) {
    return 'A report for the developer is saved: $path';
  }

  @override
  String get speedTestUseGpu => 'Use the graphics card';

  @override
  String get speedTestKeepCpu => 'Keep the processor';

  @override
  String get speedTestUseGpuAnyway => 'Switch it on anyway';

  @override
  String speedTestLast(String cpu, String gpu) {
    return 'Last test: processor $cpu, graphics card $gpu per page.';
  }

  @override
  String get speedTestLastFailed =>
      'Last test: the graphics card failed; the processor is used.';

  @override
  String gpuFallback(String models) {
    return 'The graphics card could not run: $models. These steps go on on the processor; the translation continues. This is remembered: next time they start on the processor (Settings → General).';
  }

  @override
  String get gpuFallbackHint =>
      'If this happens again, switch the graphics card off. To help fix it, build a bug report and send it to the developer.';

  @override
  String speedTestPartial(String models) {
    return 'These steps do not run on this graphics card and stay on the processor (already counted in its time): $models.';
  }

  @override
  String gpuCpuModelsNote(String models) {
    return 'Do not run on this graphics card, so they run on the processor: $models.';
  }

  @override
  String get gpuCpuModelsRetry => 'Try again';

  @override
  String gpuFallbackOcr(String language) {
    return 'text recognition ($language)';
  }

  @override
  String get gpuTurnOff => 'Switch the graphics card off';

  @override
  String gpuFound(String cards) {
    return 'Works: $cards. The most powerful one is used.';
  }

  @override
  String get gpuOnlyIntegrated =>
      'This graphics is built into the processor: it is rarely faster than the processor itself.';

  @override
  String gpuOldDrivers(String cards) {
    return 'Old drivers: $cards. If something goes wrong, update them from the maker\'s site.';
  }

  @override
  String get gpuNotUsableTitle => 'The graphics card cannot be used';

  @override
  String gpuNoCard(String names) {
    return 'No graphics card was found, only the standard Windows display driver ($names).';
  }

  @override
  String gpuDirectmlFailed(String reason) {
    return 'A test run on the graphics card failed: $reason';
  }

  @override
  String get gpuNotUsableTail =>
      'The work stays on the processor: it runs on any computer, only slower. If there is a graphics card, update its driver and try again.';

  @override
  String get testModeInfo =>
      'While it is on, the steps of every processed page are saved: the boxes found, the recognized text, the request to the translator (without the key), the mask, the cleaning and the result. Clicks and edits (font, spacing) are not recorded. A short log is always kept.\n\nWhen something goes wrong:\n1. Turn test mode on.\n2. Do the same thing again.\n3. Press “Make a bug report”.\n4. Send the archive to the developer. Then test mode can be turned off.';

  @override
  String get bugReportInfo =>
      'A report can be made without test mode too: it holds the log and the settings (without API keys). If test mode was on, it also holds the steps of the last run as text (recognized text and translation included), without pictures.';

  @override
  String get extraContextInfo =>
      'Written once and sent to the translator with every page. For example: “Characters: Maya (a girl), Timothy the cat. A comedy. Friends speak informally.” Helps with names, gender and forms of address.';

  @override
  String get sendPageImageInfo =>
      'The model sees the drawing and better understands who speaks and what happens. The picture of the whole page goes to the translator\'s server; requests cost more, and the model must understand images.';

  @override
  String get textPrepInfo =>
      'Pieces of the page with small text (lines thinner than 20 px) are enlarged before recognition; ordinary text is left alone. Without a neural network it is instant. Neural networks restore the shape of the letters but take longer (times on a slow laptop, for a screenshot page of small text): Simple about 1 s, Medium about 2 s (best on manga screenshots), High about 15 s (best overall, the default for comics); faster with the graphics card. For sites and games Plain ×1.5 is best. The program offers to download the model it needs.';

  @override
  String get hdStrategyField => 'How to clean large pages';

  @override
  String get hdStrategyInfo =>
      'The cleaning network is trained on small pictures.\n• Shrink (default): a copy of the page is shrunk to the limit and cleaned; only the cleaned places are put back on the full-size page. Fast.\n• In pieces: the parts around the text are cleaned at full size. More precise on large pages, but slower.\n• Full size: the whole page at once. The slowest, needs much memory.';

  @override
  String get resizeLimitInfo =>
      'The long side of the shrunk copy, in pixels. Larger is neater but slower. 960 is the original\'s value.';

  @override
  String get cropMarginInfo =>
      'How much background around the text goes into a piece: the network needs to see what to paint in.';

  @override
  String get cropTriggerInfo =>
      'Pages smaller than this (long side) are cleaned whole, not in pieces.';

  @override
  String get fontSizeInfo =>
      'The program picks the font size itself so that the translation fits the bubble, within these limits. When even the smallest does not fit, the page may be enlarged (see “Enlarging”).';

  @override
  String get lineSpacingInfo =>
      '1 is normal spacing, 1.5 is half as much again. A single bubble can have its own in “Text style”.';

  @override
  String get outlineWidthInfo =>
      'The outline is a light (or dark) edge around the letters so that the text reads over the drawing. The width is in pixels on each side of a letter.';

  @override
  String get imageFormatInfo =>
      '“Same as the source” keeps the format of the original. PNG loses nothing but files are larger; JPG and WEBP are smaller, with a slight loss of quality.';

  @override
  String get webtoonMode => 'Webtoon';

  @override
  String get webtoonModeHelp =>
      'All pages as one strip, as webtoons are read. A bubble cut by the edge between two pages is translated and cleaned whole. Wheel: scroll; Ctrl + wheel: zoom.';

  @override
  String get mouseWheelStrip => 'Webtoon: scroll the strip; with Ctrl: zoom';

  @override
  String get exportStrip => 'Webtoon strip';

  @override
  String get exportStripPages => 'Page by page';

  @override
  String get exportStripSingle => 'One picture';

  @override
  String get exportStripSlices => 'Cut again';

  @override
  String get exportSliceHeight => 'Height of a part, px';

  @override
  String get exportStripHelp =>
      'Each cut goes along an even row near this height (between panels), not through a bubble. Pictures taller than JPEG or WebP allow are saved as PNG.';

  @override
  String get exportStripSingleHelp =>
      'All pages (of each chapter) one below the other in one picture. A very tall picture is saved as PNG.';

  @override
  String get secretShowSaved => 'Show key';

  @override
  String get secretHideSaved => 'Hide key';

  @override
  String get secretCopy => 'Copy';

  @override
  String get secretGetKey => 'Get a key';

  @override
  String get pluginMoreSettings => 'More settings';

  @override
  String get secretCopied => 'Key copied';

  @override
  String get formatPsd => 'PSD (layers for Photoshop)';

  @override
  String get exportPsdHelp =>
      'Each page becomes a Photoshop file: the page as it was, the cleaned places, and the translation as editable text layers. Cleaned pages are saved as PNG.';

  @override
  String get exportPsdPagesOnly => 'PSD files are saved page by page.';

  @override
  String psdImportForeign(String name) {
    return '$name: this PSD was not made by Comic Translate. Its visible picture layers were joined into the page, its text layers became editable text.';
  }

  @override
  String psdImportUnsupported(String name, String features) {
    return '$name: some Photoshop features are not carried over ($features); the page may look a little different.';
  }

  @override
  String get psdFeatureSmartObjects => 'smart objects';

  @override
  String get psdFeatureMasks => 'masks';

  @override
  String get psdFeatureClipping => 'clipping masks';

  @override
  String get psdFeatureAdjustments => 'adjustment layers';

  @override
  String get psdFeatureBlendModes => 'blend modes';

  @override
  String get psdFeatureOpacity => 'layer opacity';

  @override
  String get splitWords =>
      'Split glued words on this page or the selected pages (English): \"REALLIFE\" becomes \"REAL LIFE\"';

  @override
  String get splitWordsBlock => 'Split glued words in this bubble (English)';

  @override
  String splitWordsDone(String count) {
    return 'Words split: $count. Undo with Ctrl+Z.';
  }

  @override
  String get splitWordsNone =>
      'No glued words found (only English text is checked).';

  @override
  String get splitWordsMissing =>
      'The word list is missing from the program folder (data\\flutter_assets\\assets\\dict).';

  @override
  String get splitGluedWords => 'Split glued English words after recognition';

  @override
  String get splitGluedWordsInfo =>
      'On very small text the recognizer often reads two words as one: \"REALLIFE\", \"MYINSTINCTS\". Words missing from the dictionary are split into dictionary words; letters are never changed. The same is done by the button in the text panel, for a page or one bubble.';

  @override
  String get checkLines => 'Check the lines of text before recognition';

  @override
  String get checkLinesInfo =>
      'Comics only. On dense text (a wall of text, text over a drawing, a screenshot of prose) the program sometimes takes several lines for one and reads only a word or two. A quick check finds such blocks, and the \"Text line finder (PP-OCR)\" network finds their lines again: about 1–7 s on a page where it is needed. Ordinary bubbles are not changed, nor are Japanese vertical columns. Usually keep it on. Turn it off if some page reads worse with the check than without it (compare \"Recognize\" with and without it, and tell the author), or if the pages are ordinary comics without dense text and every second counts.';

  @override
  String get contentSwitchedHint =>
      'The boxes on this page were found in the previous mode. The new mode applies when the text is found again.';

  @override
  String get findTextAgain => 'Find text again';

  @override
  String get textPrepSeconds => 'Network time per page';

  @override
  String get textPrepSecondsDefault => '1 min (default)';

  @override
  String minutesShort(String value) {
    return '$value min';
  }

  @override
  String get noTimeLimit => 'No limit';

  @override
  String get textPrepSecondsInfo =>
      'How long the network may enlarge small text on one page. It takes the smallest text first; what it has no time for is enlarged the plain way: at once, slightly lower quality. On a weak laptop \"High\" takes about 4 minutes per million pixels: a manga screenshot 20–60 s, a page covered in small text 10 minutes or more. When quality matters more than time (say, you go for a cup of tea), choose more or \"No limit\". On a graphics card the network does more in the same time.';

  @override
  String get modelLines => 'Text line finder (PP-OCR)';

  @override
  String get modelLinesInfo =>
      'Finds lines of ordinary text for \"Sites and games\": screenshots, games, visual novels. In \"Comics\" it helps to read dense text (see \"Check the lines\"). Small and fast.';

  @override
  String get modelOpusEnRu => 'Offline translation English → Russian (OPUS-MT)';

  @override
  String get modelOpusRuEn => 'Offline translation Russian → English (OPUS-MT)';

  @override
  String get modelOpusInfo =>
      'Translates on this computer without internet or keys (translator \"Offline (OPUS-MT)\"). About 0.4–0.7 s per bubble. Licence CC-BY 4.0, Helsinki-NLP.';

  @override
  String get modelW2xCunet => 'waifu2x CUNet (level Simple)';

  @override
  String get modelW2xCunetInfo =>
      'A fast neural network that enlarges small text twice before recognition. About 1 s per screenshot page. Licence MIT (nagadomi, waifu2x).';

  @override
  String get modelW2xSwin => 'waifu2x Swin-UNet (level Medium)';

  @override
  String get modelW2xSwinInfo =>
      'Enlarges small text twice before recognition; the best in the experiment on manga screenshots. About 2 s per screenshot page. Licence MIT (nagadomi, waifu2x).';

  @override
  String get modelFatality => 'Fatality Comix (level High)';

  @override
  String get modelFatalityInfo =>
      'Removes print screening and enlarges small text; the best on reduced comic pages but slow (about 15 s per screenshot page). By Twittman, licence CC-BY-NC-SA 4.0: non-commercial use only. Converted to ONNX by this project.';

  @override
  String get downloadNetworkFailed =>
      'Could not download a model: the connection to the model site keeps breaking (4 tries). Check the internet and try again — the download continues where it stopped. If the site cannot be reached, download the files on another computer and add them with \"Import from disk…\" in \"Models\".';

  @override
  String panelHide(String name) {
    return 'Hide: $name';
  }

  @override
  String panelShow(String name) {
    return 'Show: $name';
  }

  @override
  String get panelPages => 'Pages';

  @override
  String get panelTools => 'Tools';

  @override
  String get pageGridOpen => 'All pages over the whole window';

  @override
  String pageGridTitle(String count) {
    return 'All pages ($count)';
  }

  @override
  String pageGridPicked(String count) {
    return 'Ticked: $count';
  }

  @override
  String get pageGridPickAll => 'Tick all';

  @override
  String get pageGridPickNone => 'Untick';

  @override
  String get pageGridClose => 'Close';

  @override
  String get pageGridHint =>
      'A click ticks a page for the steps (Detect, Recognize, Translate…), dragging moves it, a double click opens it. Esc closes.';

  @override
  String get pageGridLocked =>
      'While pages are being translated they cannot be moved.';

  @override
  String get contentKind => 'What you translate';

  @override
  String get contentKindInfo =>
      'Comics: the program looks for speech bubbles and captions. Sites and games: it looks for lines of ordinary text (screenshots, games, visual novels, phone screens).';

  @override
  String get contentComics => 'Comics';

  @override
  String get contentComicsHelp => 'speech bubbles and captions';

  @override
  String get contentScreens => 'Sites and games';

  @override
  String get contentScreensHelp =>
      'lines of ordinary text: screenshots, games, visual novels';

  @override
  String get detectorScreens => 'Text detection (sites and games)';

  @override
  String tinyTextTryHigh(String px) {
    return 'Very small text (lines of about $px px): mistakes are likely. Turn on the High level in \"Settings → Recognition and cleaning → Preparing small text\" and recognize again, or take a larger screenshot.';
  }

  @override
  String tinyTextLarger(String px) {
    return 'Very small text (lines of about $px px): mistakes are likely even after the neural network. Take a larger screenshot: zoom the page or window in first.';
  }

  @override
  String get chatTitle => 'Exchange with a chat AI';

  @override
  String get chatSubtitle =>
      'ChatGPT, Gemini, Claude or any other. The program sends nothing itself: you carry the pictures and the instructions over, then paste the answer here.';

  @override
  String get chatModeBoth => 'Read and translate';

  @override
  String get chatModeRecognize => 'Read';

  @override
  String get chatModeTranslate => 'Translate';

  @override
  String chatPieces(int count, int pages) {
    return 'Pieces of text: $count, pages: $pages';
  }

  @override
  String get chatNoPieces =>
      'Nothing to send: find the text first (and read it, to translate it).';

  @override
  String get chatSheets => 'Sheets';

  @override
  String get chatGroupingSize => 'as many as fit';

  @override
  String get chatGroupingCount => 'a set number';

  @override
  String get chatPerSheet => 'Pieces on a sheet';

  @override
  String get chatSheetSize => 'Sheet size';

  @override
  String get chatSheetPerPage => 'Each page on new sheets';

  @override
  String get chatContextImage => 'Picture of the page';

  @override
  String get chatContextOff => 'do not send';

  @override
  String get chatContextSeparate => 'as its own picture';

  @override
  String get chatContextOnSheet => 'on the sheet';

  @override
  String get chatGroups => 'Own sheets';

  @override
  String get chatGroupsHint => 'e.g. 1-4, 5-6';

  @override
  String chatGroupsError(String part, int count) {
    return 'Not understood: \"$part\". Number the pieces from 1 to $count, e.g. 1-4, 5-6.';
  }

  @override
  String get chatStep1 => '1. Send to the chat';

  @override
  String get chatStep1Help =>
      'Copy the pictures and paste them into the chat (Ctrl+V), then copy the instructions, paste them too and send.';

  @override
  String get chatStep1TextHelp =>
      'Copy the instructions with the text, paste them into the chat (Ctrl+V) and send.';

  @override
  String get chatPreparing => 'Preparing the pictures…';

  @override
  String chatExportFailed(String error) {
    return 'Could not prepare the files: $error';
  }

  @override
  String chatCopyPictures(int count) {
    return 'Copy the pictures ($count)';
  }

  @override
  String get chatCopyPrompt => 'Copy the instructions';

  @override
  String get chatCopyOne => 'Copy only this picture';

  @override
  String get chatShowPrompt => 'Instructions for the chat';

  @override
  String get chatOpenFolder => 'Open the folder';

  @override
  String chatCopiedPictures(int count) {
    return 'Pictures copied: $count. Paste them into the chat: Ctrl+V.';
  }

  @override
  String chatCopiedOne(String name) {
    return 'Copied: $name. Paste it into the chat: Ctrl+V.';
  }

  @override
  String get chatCopiedPrompt =>
      'Instructions copied. Paste them into the chat: Ctrl+V.';

  @override
  String get chatCopyText => 'Copy the text';

  @override
  String get chatCopiedText =>
      'Text copied (only the lines with labels). Paste it into the chat: Ctrl+V.';

  @override
  String chatPagesAll(int count) {
    return 'All pages ($count)';
  }

  @override
  String chatPageOnly(int page, int count) {
    return 'Page $page ($count)';
  }

  @override
  String chatPicturePages(String pages) {
    return 'p. $pages';
  }

  @override
  String chatClipboardOffer(int found, int total) {
    return 'The clipboard has a chat answer: $found of $total. Paste it?';
  }

  @override
  String get chatClipboardPaste => 'Paste';

  @override
  String get glossaryMenu => 'Names and words…';

  @override
  String get glossaryTitle => 'Names and words';

  @override
  String glossaryButton(int count) {
    return 'Glossary ($count)';
  }

  @override
  String get glossaryHelp =>
      'How to translate the names and words of this project. One line, one word: Kai --> Кай. Any other line is a note on the translation (for example: \"Leave senpai as it is\", \"The heroes are on first-name terms\"). Lines starting with # are your own remarks and go nowhere.\n\nThe glossary is kept in the project. It goes into the instructions for the chat (only the words in the text) and to translators over the network (OpenRouter and others); the offline translator does not use it. The chat may suggest new names: one button in the exchange window adds them.';

  @override
  String get glossaryHint =>
      'Kai --> Кай\nSenpai --> семпай\nThe heroes are on first-name terms.';

  @override
  String glossaryCounts(int words, int notes) {
    return 'Words: $words, notes: $notes';
  }

  @override
  String get glossaryLoad => 'Load from txt…';

  @override
  String get glossarySave => 'Save to txt…';

  @override
  String glossarySaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get textExportMenu => 'Export text…';

  @override
  String get textExportTitle => 'Export text';

  @override
  String get textExportHelp =>
      'The dialogues of the pages as plain text: the originals, the translations or both. Keep them, or attach them to a chat as context. The labels are the same as in the exchange with a chat (ALL.txt).';

  @override
  String textExportAllPages(String count) {
    return 'Empty: all pages ($count)';
  }

  @override
  String textExportSomePages(String count) {
    return 'Pages: $count';
  }

  @override
  String get textExportWhat => 'What:';

  @override
  String get textExportOriginal => 'Original';

  @override
  String get textExportTranslation => 'Translation';

  @override
  String get textExportBoth => 'Both';

  @override
  String get textExportTwoFiles =>
      'Two files: …_original.txt and …_translation.txt (you will choose a folder).';

  @override
  String get textExportLabels => 'Labels before the lines: [01-003]';

  @override
  String get textExportSpeakers => 'Who speaks: [m] [f] [n]';

  @override
  String get textExportHeadings => 'Page headings';

  @override
  String get textExportHeading => 'Heading';

  @override
  String textExportHeadingHelp(String number, String name) {
    return '$number is the number of the page, $name the name of its file. For example: --- $number ---';
  }

  @override
  String get textExportPage => 'Page';

  @override
  String get textExportPreview => 'How it looks';

  @override
  String get textExportEmpty => '(no text)';

  @override
  String get textExportCopy => 'Copy';

  @override
  String get textExportCopyShown => 'Copy the shown one';

  @override
  String get textExportCopied => 'Copied. Paste it with Ctrl+V.';

  @override
  String get textExportSave => 'Save…';

  @override
  String textExportSaved(String paths) {
    return 'Saved:\n$paths';
  }

  @override
  String get glossaryApply => 'Done';

  @override
  String get chatNewTerms => 'The chat suggests for the glossary:';

  @override
  String get chatNewTermsAdd => 'Add to the glossary';

  @override
  String chatNewTermsAdded(int count) {
    return 'Added to the glossary: $count';
  }

  @override
  String get chatStyles => 'Style of the translation:';

  @override
  String get chatStylesOwn => 'Own styles and instructions';

  @override
  String get styleNone => 'No style';

  @override
  String get styleLiteral => 'Close to the original';

  @override
  String get styleLively => 'Lively, spoken';

  @override
  String get styleSoften => 'Soften rude words';

  @override
  String get styleKeepSwearing => 'Rude words as strong';

  @override
  String get styleHonorifics => 'Keep -san/-kun';

  @override
  String get styleOwn => 'Own style';

  @override
  String get chatStylesTitle => 'Styles of translation';

  @override
  String get chatStylesHelp =>
      'The chosen styles go into the instructions for the chat and to translators over the network (OpenRouter and others). An own style: the name is for the list, and what to ask is in English (chats follow it best).';

  @override
  String get chatOwnStyleName => 'Name';

  @override
  String get chatOwnStyleText => 'What to ask (in English)';

  @override
  String get chatOwnStyleAdd => 'Add a style of your own';

  @override
  String get chatOwnStyleDelete => 'Delete the style';

  @override
  String get chatSharedTexts => 'One text for every mode';

  @override
  String get chatSharedTextsHelp =>
      'What you wrote into the txt files stays when the mode changes: \"Recognize\", \"Translate\" and \"Recognize and translate\" work with the same files. Off: each mode gets fresh templates of its own.';

  @override
  String get speakerLabel => 'Who speaks';

  @override
  String get speakerInfo =>
      'Helps the translation pick the grammatical gender (in Russian, \"я пришёл\" or \"я пришла\"). The tag goes to the chat and to translators over the network (OpenRouter and others); the offline translator does not use it.\n\nIn the exchange txt files the tag stands after the label: [01-003] [f] … — it can be changed there too: [m] a man, [f] a woman, [n] no gender, [-] none.';

  @override
  String get speakerMale => 'M';

  @override
  String get speakerFemale => 'F';

  @override
  String get speakerNeuter => 'N';

  @override
  String get speakerNoneTip => 'Not told';

  @override
  String get speakerMaleTip => 'A man';

  @override
  String get speakerFemaleTip => 'A woman';

  @override
  String get speakerNeuterTip => 'No gender: a thing, a crowd, a narrator';

  @override
  String get chatAnswerFromClipboard => 'Offer the answer from the clipboard';

  @override
  String get chatAnswerFromClipboardHelp =>
      'Back in the exchange window with a chat answer (lines with labels) in the clipboard, the program offers to paste it.';

  @override
  String get chatCopyFailed =>
      'Could not copy: another program holds the clipboard. Try again, or open the folder and drag the files into the chat.';

  @override
  String get chatStep2 => '2. Paste the chat\'s answer';

  @override
  String get chatAnswerHint => '[01-003] text';

  @override
  String get chatAnswerHintBoth => '[01-003] I\'M LATE! --> Я ОПОЗДАЛ!';

  @override
  String get chatPaste => 'Paste';

  @override
  String get chatFromFiles => 'Take from the txt files';

  @override
  String chatFromFilesInfoTranslate(String separator) {
    return 'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text $separator translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Translate\": add the translation after \"$separator\" in ALL.txt or write it into ALL_translation.txt.';
  }

  @override
  String chatFromFilesInfoRecognize(String separator) {
    return 'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text $separator translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Recognize\": write or correct the text from the picture, before \"$separator\" in ALL.txt or in ALL_original.txt. A translation may come along too.';
  }

  @override
  String chatFromFilesInfoBoth(String separator) {
    return 'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text $separator translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Recognize and translate\": both the text from the picture and the translation, in ALL.txt with \"$separator\" between them, or apart in ALL_original.txt and ALL_translation.txt.';
  }

  @override
  String get chatSheetPerPageOn =>
      '\"Each page on a new sheet\" is on: the sheets show the bubbles of one page only.';

  @override
  String get chatOpenTxt => 'Open a txt file…';

  @override
  String chatFound(int found, int total) {
    return 'Answers found: $found of $total';
  }

  @override
  String chatFromFilesNote(String files) {
    return 'From the files: $files';
  }

  @override
  String chatMissing(String labels) {
    return 'No answer: $labels';
  }

  @override
  String chatAccepted(int count, int total) {
    return 'Taken from earlier answers: $count of $total';
  }

  @override
  String get chatAskAgain => 'Ask again';

  @override
  String get chatAskAgainInfo =>
      'The chat answered every bubble, but some badly (a wrong translation, a misread picture)? Write their labels here, with commas: 01-002, 03-005. The button next to it prepares a short request for them only: their pictures and instructions. Send it to the same chat and paste its answer: the new answer replaces the old one of these bubbles, the answers of the other bubbles stay. Bubbles with no answer at all are added by themselves.';

  @override
  String chatAskAgainWrong(String part) {
    return 'Not a label: “$part”';
  }

  @override
  String chatAskAgainUnknown(String labels) {
    return 'These were not sent: $labels';
  }

  @override
  String chatResendMissing(int count) {
    return 'Send the missing ones ($count)';
  }

  @override
  String chatResendAgain(int count) {
    return 'Ask again ($count)';
  }

  @override
  String chatResendBoth(int count) {
    return 'Send the missing ones and ask again ($count)';
  }

  @override
  String chatRoundBanner(int count, String labels) {
    return 'Another round: bubbles — $count ($labels). The pictures and instructions here are for them only; paste the chat\'s answer on the right.';
  }

  @override
  String get chatRoundBack => 'Back to the whole exchange';

  @override
  String chatUnchanged(int count) {
    return 'Unchanged (as the bubbles are now): $count';
  }

  @override
  String chatUnknown(String labels) {
    return 'Not sent (left out): $labels';
  }

  @override
  String chatNoArrow(String sep, String labels) {
    return 'Without \"$sep\" (all taken as the translation): $labels';
  }

  @override
  String chatRepeated(String labels) {
    return 'Answered twice (the first one counts): $labels';
  }

  @override
  String get chatApply => 'Apply';

  @override
  String get chatApplyContinue => 'Apply and go on';

  @override
  String chatApplied(int count) {
    return 'Pieces filled in: $count';
  }

  @override
  String chatLost(String labels) {
    return 'Not found on the page any more (boxes removed?): $labels';
  }

  @override
  String get chatButton => 'Chat';

  @override
  String get chatButtonHelp =>
      'Read and translate with ChatGPT, Gemini, Claude… by hand, for the selected pages';

  @override
  String get chatMenuBoth => 'Read and translate through a chat…';

  @override
  String get chatMenuRecognize => 'Read through a chat…';

  @override
  String get chatMenuTranslate => 'Translate through a chat…';

  @override
  String get chatMenuFolder => 'Answer for an earlier exchange…';

  @override
  String get chatNotExchangeFolder =>
      'This folder has no exchange.json: it is not an exchange folder.';

  @override
  String get stageExchange => 'Waiting for the chat\'s answer';

  @override
  String get chatSettingsHelp =>
      'The \"Chat\" button on the main screen works with any engines. For \"Translate all\" to open the exchange by itself, choose \"By hand through a chat AI\" as the translator and/or in Tools → Reading.';

  @override
  String get chatTogether => 'Read and translate in one message';

  @override
  String get chatTogetherHelp =>
      'When both go through the chat. Off: first the reading, then a second round with the text to translate.';

  @override
  String get chatPicturesTitle => 'Pictures';

  @override
  String get chatImages => 'What to make';

  @override
  String get chatImagesSheets => 'Sheets (several pieces on a picture)';

  @override
  String get chatImagesCrops => 'A picture for each piece';

  @override
  String get chatImagesBoth => 'Both';

  @override
  String get chatImagesInfo =>
      'Sheets are easier to send: one picture holds many pieces, each with its label above it. Single pictures are named like the labels (01-003.png) and go in folders of a set number.';

  @override
  String get chatGroupingInfo =>
      'As many as fit: a sheet is filled up to its size. A set number: the same number of pieces on each sheet. In the exchange window you can also make your own sheets, e.g. 1-4, 5-6.';

  @override
  String get chatSheetSizePx => 'Sheet size (pixels)';

  @override
  String get chatSheetSizeInfo =>
      'The longest side of a sheet. Chats shrink large pictures, and small letters stop being readable; 1600 works well for most chats.';

  @override
  String get chatContextInfo =>
      'A smaller picture of the whole page with the labelled boxes on it: helps the chat see who speaks and what happens. Also works when only translating.';

  @override
  String get chatCropsPerFolder => 'Pictures in a folder';

  @override
  String get chatAnswerTitle => 'Answer';

  @override
  String get chatTextFiles => 'Text files';

  @override
  String get chatTextFilesAll => 'ALL.txt for all pages';

  @override
  String get chatTextFilesPages => 'A file for each page';

  @override
  String get chatTextFilesBoth => 'Both';

  @override
  String get chatTextFilesInfo =>
      'Files with one line per label in the exchange folder. Paste the chat\'s answer into them and press \"Take from the txt files\": ALL.txt first, then the page files for what is still missing.';

  @override
  String get chatPlaceholder => 'Text for pieces without an answer';

  @override
  String get chatPlaceholderHelp =>
      'Empty: such pieces stay as they are. Something like ⟦empty⟧ makes them easy to find.';

  @override
  String get chatPromptsTitle => 'Instructions for the chat';

  @override
  String chatPromptsHelp(String names) {
    return 'In English: chats follow it best. The program puts the languages, the labels, the text with labels and what you wrote about the comic in place of these words: $names.';
  }

  @override
  String get chatPromptDefault => 'Back to the built-in one';

  @override
  String chatCopySelected(int count) {
    return 'Copy the picked ($count)';
  }

  @override
  String get chatSelectAll => 'Pick all';

  @override
  String get chatSelectNone => 'Pick none';

  @override
  String get chatGalleryOpen => 'Open the pictures large';

  @override
  String get chatGalleryPictures => 'Pictures';

  @override
  String get chatGalleryPieces => 'Pieces and sheets';

  @override
  String get chatPiecesHelp =>
      'All the pieces in order. Click a piece to start a new sheet with it; click again to undo.';

  @override
  String chatGroupsNow(String groups) {
    return 'Sheets: $groups';
  }

  @override
  String get chatGroupsAuto => 'as set above';

  @override
  String get chatGroupsClear => 'Remove all breaks';

  @override
  String get chatGroupsApply => 'Use these sheets';

  @override
  String get chatNewSheetHere => 'A new sheet from here';

  @override
  String chatGroupsNumbers(String first, int count, String last) {
    return '1 = [$first] … $count = [$last]';
  }

  @override
  String get chatPromptChanged =>
      'Instructions for the chat (changed this time)';

  @override
  String get chatPromptUndo => 'Undo my changes';

  @override
  String get chatPromptTemplate => 'Change for good…';

  @override
  String get chatOneField => 'One field';

  @override
  String get chatTwoFields => 'Two fields';

  @override
  String get chatOriginalField => 'Original';

  @override
  String get chatTranslationField => 'Translation';

  @override
  String get chatAnswerHintTranslation => '[01-003] translation';

  @override
  String get chatApart => 'Original and translation as two lists';

  @override
  String get chatApartHelp =>
      'When reading and translating in one message: the chat writes all the originals, then ===, then all the translations; the answer goes into two fields.';

  @override
  String get chatPromptBothApart => 'Read and translate, two lists';

  @override
  String get chatSplitFiles =>
      'Also the original and the translation in files of their own';

  @override
  String get chatSplitFilesHelp =>
      'Besides ALL.txt, ALL_original.txt (the original) and ALL_translation.txt (the translation only) are written, the same for the page files. The answer is taken from whichever file is filled in.';

  @override
  String get chatSeparator => 'Between the original and the translation';

  @override
  String get chatSeparatorHelp =>
      'Any sign, --> by default. It goes into the instructions; the usual arrows are understood as well.';

  @override
  String get textCase => 'Letter case';

  @override
  String get textCaseSource => 'As in the original';

  @override
  String get textCaseUpper => 'ALL CAPITALS';

  @override
  String get textCaseNormal => 'Ordinary letters';

  @override
  String get textCaseInfo =>
      'Almost all comics are lettered in capitals. \"As in the original\": where a bubble of the original is in capitals, so is its translation; elsewhere ordinary letters. For a page or one bubble, use the \"Aa\" button of the Text panel.';

  @override
  String get matchSource => 'Look as in the original';

  @override
  String get matchSourceInfo =>
      'The program looks at the original letters and draws the translation alike: bold where they are clearly heavier than in the page\'s other bubbles, italic where they lean, with an outline of the same colour for captions and sounds over the art. Found when the text is recognized; very small text gets no bold or italic. Turn it off for the same look in every bubble.';

  @override
  String get hyphenate => 'Hyphenation';

  @override
  String get hyphenateInfo =>
      'Long Russian words may be broken by syllables. A break is made only where the text would otherwise have to be clearly smaller.';

  @override
  String get shapeFit => 'Lines follow the bubble';

  @override
  String get shapeFitInfo =>
      'Lines follow the oval of the bubble, as letterers do: shorter at the top and bottom, longer in the middle; one letter size in the bubble. Works when a bubble holds one piece of text. For one bubble, see its look.';

  @override
  String get fontSuggest => 'Suggest a font…';

  @override
  String get fontSuggestTitle => 'Similar fonts';

  @override
  String get fontSuggestHint =>
      'Compared with the original letters on this page. The font is not changed by itself: pick one.';

  @override
  String get fontSuggestNoText =>
      'No recognized text on this page: press Recognize first.';

  @override
  String get fontSuggestForAll => 'For all bubbles';

  @override
  String get fontSuggestForBlock => 'For this bubble only';

  @override
  String get fontSuggestOriginal => 'Original';

  @override
  String get caseToggle =>
      'CAPITALS ↔ ordinary letters on this page or the selected pages';

  @override
  String get caseToggleBlock => 'CAPITALS ↔ ordinary letters in this bubble';

  @override
  String get sizeFromSource => 'Size as in the original';

  @override
  String get sizeFromSourcePages =>
      'Letter size as in the original on this page or the selected pages (smaller in a tight bubble)';

  @override
  String get sizeFromSourceUnknown =>
      'The size of the original letters is unknown: press Recognize again.';

  @override
  String get styleResetPages =>
      'Reset the look of the bubbles on this page or the selected pages';

  @override
  String get hyphenateBlock => 'Hyphenation';

  @override
  String get shapeFitBlock => 'Follow the bubble';

  @override
  String get fromSource => 'as in the original';

  @override
  String get textFit => 'Fitting';

  @override
  String get showLookInPanel => 'Show the look in the panel';

  @override
  String get runBigger => 'Larger';

  @override
  String get runSmaller => 'Smaller';

  @override
  String get runClear => 'Clear the look of the selection';

  @override
  String get runHint =>
      'Select a word or sign of the translation for buttons that give it a look of its own.';

  @override
  String get runAsBubble => 'As the bubble';

  @override
  String get outlineNone => 'No outline';

  @override
  String get lookPreset => 'Style';

  @override
  String get lookPresetNone => 'No style';

  @override
  String get lookPresetSave => 'Save the look as a style…';

  @override
  String get lookPresetName => 'Style name';

  @override
  String lookPresetUpdate(String name) {
    return 'Update the style \"$name\" from this bubble';
  }

  @override
  String lookPresetDelete(String name) {
    return 'Delete the style \"$name\"';
  }

  @override
  String get lookPresetHelp =>
      'A style is a set of looks (font, colour, outline, bold…) put on a bubble or a word with one click. Change the style and every bubble and word with it changes.';

  @override
  String get keyPaste => 'Paste pages from the clipboard';

  @override
  String pastedPageName(String time) {
    return 'Pasted $time';
  }

  @override
  String get pasteNothing => 'The clipboard has no picture or files';

  @override
  String get pasteBelow => 'Paste from the clipboard below this page';

  @override
  String get addBelow => 'Add files below this page…';

  @override
  String repeatsTitle(String count) {
    return 'Already added: $count';
  }

  @override
  String get repeatsHint =>
      'The same pictures are among the pages already. Tick the ones to add anyway. The small pictures: the new file and the page already open; click them or \"Compare\" to see both big.';

  @override
  String get repeatsCompare => 'Compare';

  @override
  String get repeatsCompareNew => 'File being added';

  @override
  String repeatsComparePage(String number) {
    return 'Page $number';
  }

  @override
  String get repeatsCompareAdding => 'Also being added';

  @override
  String repeatsSameAs(String number, String name) {
    return 'same as page $number \"$name\"';
  }

  @override
  String repeatsSameAsNew(String name) {
    return 'same as \"$name\" being added';
  }

  @override
  String get repeatsSkipAll => 'Skip all';

  @override
  String repeatsAddPicked(String count) {
    return 'Add ticked ($count)';
  }

  @override
  String get repeatsAddAll => 'Add all anyway';

  @override
  String repeatsLeft(String count) {
    return 'Repeats not added: $count';
  }

  @override
  String get pageSort =>
      'Order of pages (pages can be dragged with the mouse too)';

  @override
  String get pageSortNameUp => 'By name: A → Z';

  @override
  String get pageSortNameDown => 'By name: Z → A';

  @override
  String get pageSortDateUp => 'By file date: oldest first';

  @override
  String get pageSortDateDown => 'By file date: newest first';

  @override
  String get pageSortReverse => 'Turn the order round';

  @override
  String get pageSortDone => 'The order of pages changed';

  @override
  String get gridTileSize => 'Size of the pictures';

  @override
  String get pageNumbers => 'Page numbers';

  @override
  String get pageNumbersHint => 'numbers: 1,5-8,10';

  @override
  String get pageNumbersTip =>
      'Pick pages by their numbers, like 1,5-8,10, and press Enter. The steps (Detect, Recognize…), the chat, the export and \"Translate selected\" work on the picked pages.';

  @override
  String pageNumbersWrong(String part, String count) {
    return 'Not a page: \"$part\" (there are $count)';
  }

  @override
  String get pageNumbersPick => 'Pick (Enter)';

  @override
  String translateSelected(String count) {
    return 'Translate selected ($count)';
  }

  @override
  String get translateShort => 'Translate';

  @override
  String translateShortCount(String count) {
    return 'Translate ($count)';
  }

  @override
  String get translateWhich =>
      'What to translate: everything or only the picked pages (remembered)';

  @override
  String get translateAllPages => 'Translate all';

  @override
  String get translateSelectedHint =>
      'Pick pages first: Ctrl+click in the list, numbers like 1,5-8, or ticks in the grid';

  @override
  String get exportNumbers => 'Picked / numbers';

  @override
  String exportNumbersReady(String done, String count) {
    return 'Translated among them: $done of $count; only these are saved';
  }

  @override
  String get exportNames => 'File names';

  @override
  String get exportNamesPages => 'As the pages';

  @override
  String get exportNamesTemplate => 'Name + number';

  @override
  String get exportNamePrefix => 'Name (text before the number)';

  @override
  String get exportNameStart => 'Start at';

  @override
  String get exportNameStartWrong => 'Digits only';

  @override
  String exportNamesExample(String example) {
    return 'You get: $example  (as many digits as written in \"Start at\")';
  }

  @override
  String get keyNavigator => 'Mini view: show or hide';

  @override
  String navigatorToggle(String key) {
    return 'Mini view: the whole page with a frame around what is shown; a click or a drag in it moves the view ($key)';
  }

  @override
  String get settingsAsPanel =>
      'Settings as a panel beside the page: the page stays in sight';

  @override
  String get settingsFullWindow => 'Settings over the whole window';

  @override
  String get settingsView => 'Open the settings';

  @override
  String get settingsViewFull => 'Over the whole window';

  @override
  String get settingsViewPanel => 'As a panel beside the page';

  @override
  String get settingsViewLast => 'As the last time';

  @override
  String get settingsViewHelp =>
      'While the app runs, the settings open as you left them (the button in their title). This is how they open after the app starts.';

  @override
  String removePicked(String count) {
    return 'Remove the picked ($count)…';
  }

  @override
  String removePagesTitle(String count) {
    return 'Remove $count pages from the list?';
  }

  @override
  String get removePagesBody =>
      'The files on disk stay. The translation and edits of these pages are lost unless saved in a project or exported.';

  @override
  String get removePagesYes => 'Remove';
}
