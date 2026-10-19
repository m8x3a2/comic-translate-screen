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
      'Images (PNG, JPG, WEBP, BMP), comic archives (CBZ, ZIP, EPUB, CBR, CB7, CBT) and PDF';

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
  String get closeAllConfirm =>
      'Close all pages? Translations that were not exported will be lost.';

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
  String get missingKeyTitle => 'API key needed';

  @override
  String missingKeyBody(String name, String host) {
    return '\"$name\" sends text to $host, which needs an API key. Enter it in Settings → Translator (it is stored in Windows secure storage), or choose a local translator.';
  }

  @override
  String get openSettings => 'Open settings';

  @override
  String get exitTitle => 'Close the program?';

  @override
  String exitBody(String count) {
    return '$count translated page(s) were not exported and will be lost.';
  }

  @override
  String get exitAnyway => 'Close';

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
      'Stored in Windows secure storage, never in files or logs.';

  @override
  String get secretSet => 'Saved';

  @override
  String get secretNotSet => 'Not set';

  @override
  String get secretRemove => 'Remove';

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
  String get hdStrategy => 'Large pages';

  @override
  String get hdResize => 'Resize';

  @override
  String get hdCrop => 'In pieces';

  @override
  String get hdOriginal => 'Original size';

  @override
  String get resizeLimit => 'Resize limit (px)';

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
  String get fontOther => 'Font installed in Windows';

  @override
  String get fontOtherHint => 'Font name, e.g. Comic Sans MS';

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
}
