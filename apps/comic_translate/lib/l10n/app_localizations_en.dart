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
  String get inpainter => 'Text removal';

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
  String get upscaleSmallText => 'Enlarge small text before reading';

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
  String get keyStatusCheck => 'Check balance';

  @override
  String keyStatusHelp(String host) {
    return 'Asks $host what is left of the key\'s limit. Only the key is sent, and only when you press the button.';
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
    return 'Pages selected: $count (Ctrl or Shift + click)';
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
      'Restores the drawing under the text more neatly, especially under sound effects. Slower and larger than AOT. Chosen in Settings → Tools.';

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
  String get modelOcrChinese => 'Chinese (and large Japanese text)';

  @override
  String get modelOcrChineseInfo =>
      'Reads Chinese text (PaddleOCR). For Japanese it is needed too, with manga-ocr: it reads large titles and captions.';

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
  String get upscaleSmallTextInfo =>
      'When text lines are thinner than about 30 pixels (screenshots, small scans), the page is enlarged up to 4 times before recognition. There are far fewer mistakes; normal pages hardly change.';

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
}
