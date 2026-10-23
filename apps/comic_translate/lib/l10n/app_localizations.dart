import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Comic Translate Screen'**
  String get appTitle;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Translate comics on your own computer'**
  String get homeTagline;

  /// No description provided for @openFiles.
  ///
  /// In en, this message translates to:
  /// **'Open files…'**
  String get openFiles;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder…'**
  String get openFolder;

  /// No description provided for @addPages.
  ///
  /// In en, this message translates to:
  /// **'Add pages'**
  String get addPages;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'or drag files into this window'**
  String get dropHint;

  /// No description provided for @supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Images (PNG, JPG, WEBP, BMP), comic archives (CBZ, ZIP, EPUB, CBR, CB7, CBT), PDF, Photoshop files (PSD) and projects (.ctsproj)'**
  String get supportedFormats;

  /// No description provided for @privacyLocal.
  ///
  /// In en, this message translates to:
  /// **'Everything runs on this computer; nothing is sent anywhere.'**
  String get privacyLocal;

  /// No description provided for @privacySends.
  ///
  /// In en, this message translates to:
  /// **'For translation, the text is sent to {host}'**
  String privacySends(String host);

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Opening files…'**
  String get importing;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {name}: {error}'**
  String importFailed(String name, String error);

  /// No description provided for @skippedFiles.
  ///
  /// In en, this message translates to:
  /// **'Skipped (not images, archives or PDF): {names}'**
  String skippedFiles(String names);

  /// No description provided for @noPagesFound.
  ///
  /// In en, this message translates to:
  /// **'No pages found in the selected files'**
  String get noPagesFound;

  /// No description provided for @closeAll.
  ///
  /// In en, this message translates to:
  /// **'Close all pages'**
  String get closeAll;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @removePage.
  ///
  /// In en, this message translates to:
  /// **'Remove page'**
  String get removePage;

  /// No description provided for @translateAll.
  ///
  /// In en, this message translates to:
  /// **'Translate all'**
  String get translateAll;

  /// No description provided for @translateAgain.
  ///
  /// In en, this message translates to:
  /// **'Translate again'**
  String get translateAgain;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping…'**
  String get stopping;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get sourceLanguage;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get targetLanguage;

  /// No description provided for @languageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get languageAuto;

  /// No description provided for @languageAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Source language: found by the letters of each bubble (Latin, Cyrillic, Japanese, Korean, Chinese). For English pages, choosing English reads more accurately.'**
  String get languageAutoHint;

  /// No description provided for @viewOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get viewOriginal;

  /// No description provided for @viewTranslated.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get viewTranslated;

  /// No description provided for @showBoxes.
  ///
  /// In en, this message translates to:
  /// **'Text boxes'**
  String get showBoxes;

  /// No description provided for @zoomFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to window'**
  String get zoomFit;

  /// No description provided for @zoomActual.
  ///
  /// In en, this message translates to:
  /// **'Actual size'**
  String get zoomActual;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @notTranslatedYet.
  ///
  /// In en, this message translates to:
  /// **'This page is not translated yet'**
  String get notTranslatedYet;

  /// No description provided for @pageEnlarged.
  ///
  /// In en, this message translates to:
  /// **'Enlarged ×{factor} for sharp text'**
  String pageEnlarged(String factor);

  /// No description provided for @textPanel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textPanel;

  /// No description provided for @noTextFound.
  ///
  /// In en, this message translates to:
  /// **'No text found on this page'**
  String get noTextFound;

  /// No description provided for @translateToSeeText.
  ///
  /// In en, this message translates to:
  /// **'Translate the page to see its text here'**
  String get translateToSeeText;

  /// No description provided for @stageLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading models'**
  String get stageLoading;

  /// No description provided for @stageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading models: {percent}%'**
  String stageDownloading(String percent);

  /// No description provided for @stageDetect.
  ///
  /// In en, this message translates to:
  /// **'Finding text'**
  String get stageDetect;

  /// No description provided for @stageOcr.
  ///
  /// In en, this message translates to:
  /// **'Reading text'**
  String get stageOcr;

  /// No description provided for @stageTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translating'**
  String get stageTranslate;

  /// No description provided for @stageClean.
  ///
  /// In en, this message translates to:
  /// **'Removing text'**
  String get stageClean;

  /// No description provided for @stageRender.
  ///
  /// In en, this message translates to:
  /// **'Drawing the translation'**
  String get stageRender;

  /// No description provided for @stageExport.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get stageExport;

  /// No description provided for @progressPage.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String progressPage(String current, String total);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'about {time} left'**
  String remaining(String time);

  /// No description provided for @pagesSummary.
  ///
  /// In en, this message translates to:
  /// **'Pages: {total}, translated: {done}'**
  String pagesSummary(String total, String done);

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {reason}'**
  String statusSkipped(String reason);

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Translated'**
  String get statusDone;

  /// No description provided for @statusRunning.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusRunning;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation report'**
  String get reportTitle;

  /// No description provided for @reportSummary.
  ///
  /// In en, this message translates to:
  /// **'Translated {done} of {total} pages in {time}'**
  String reportSummary(String done, String total, String time);

  /// No description provided for @reportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped before the end'**
  String get reportCancelled;

  /// No description provided for @reportSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped pages'**
  String get reportSkipped;

  /// No description provided for @reportExported.
  ///
  /// In en, this message translates to:
  /// **'Text and cleaned pages were saved to {path}'**
  String reportExported(String path);

  /// No description provided for @reportNoSkipped.
  ///
  /// In en, this message translates to:
  /// **'Every page went through.'**
  String get reportNoSkipped;

  /// No description provided for @reportStopped.
  ///
  /// In en, this message translates to:
  /// **'Translation stopped: {reason}. The remaining pages were not sent.'**
  String reportStopped(String reason);

  /// No description provided for @handEditedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pages changed by hand'**
  String get handEditedTitle;

  /// No description provided for @handEditedBody.
  ///
  /// In en, this message translates to:
  /// **'Pages to translate that were changed by hand (text, boxes, formatting or cleaning): {count}. Translating them again replaces those changes; Ctrl+Z on a page brings them back while the program is open.'**
  String handEditedBody(String count);

  /// No description provided for @handEditedTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate again'**
  String get handEditedTranslate;

  /// No description provided for @handEditedSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip them'**
  String get handEditedSkip;

  /// No description provided for @missingAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Server address needed'**
  String get missingAddressTitle;

  /// No description provided for @missingAddressBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has no server address. Enter it in Settings → Translator (for example https://openrouter.ai/api/v1, or http://localhost:1234/v1 for LM Studio), or choose another translator.'**
  String missingAddressBody(String name);

  /// No description provided for @missingKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'API key needed'**
  String get missingKeyTitle;

  /// No description provided for @missingKeyBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sends text to {host}, which needs an API key. Enter it in Settings → Translator (it is stored in Windows secure storage), or choose a local translator.'**
  String missingKeyBody(String name, String host);

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get showInFolder;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @reasonModelMissing.
  ///
  /// In en, this message translates to:
  /// **'model \"{name}\" is not downloaded'**
  String reasonModelMissing(String name);

  /// No description provided for @reasonImage.
  ///
  /// In en, this message translates to:
  /// **'the image could not be read'**
  String get reasonImage;

  /// No description provided for @reasonWorkerStopped.
  ///
  /// In en, this message translates to:
  /// **'page processing stopped unexpectedly (details are in the log; you can create a bug report in Settings)'**
  String get reasonWorkerStopped;

  /// No description provided for @withDetails.
  ///
  /// In en, this message translates to:
  /// **'{text} (details: {details})'**
  String withDetails(String text, String details);

  /// No description provided for @trErrConfig.
  ///
  /// In en, this message translates to:
  /// **'the translator is not set up: enter the server address and model in Settings'**
  String get trErrConfig;

  /// No description provided for @trErrAuth.
  ///
  /// In en, this message translates to:
  /// **'the server did not accept the API key; check the key in Settings'**
  String get trErrAuth;

  /// No description provided for @trErrCredits.
  ///
  /// In en, this message translates to:
  /// **'the translator account has run out of money or credits'**
  String get trErrCredits;

  /// No description provided for @trErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'wrong server address or model name'**
  String get trErrNotFound;

  /// No description provided for @trErrRateLimit.
  ///
  /// In en, this message translates to:
  /// **'the server is busy with too many requests and asks to wait; try again later'**
  String get trErrRateLimit;

  /// No description provided for @trErrServer.
  ///
  /// In en, this message translates to:
  /// **'the translator\'s server failed; try again later'**
  String get trErrServer;

  /// No description provided for @trErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'no connection to the translator\'s server; check the internet connection'**
  String get trErrNetwork;

  /// No description provided for @trErrTimeout.
  ///
  /// In en, this message translates to:
  /// **'the translator\'s server did not answer in time'**
  String get trErrTimeout;

  /// No description provided for @trErrBadReply.
  ///
  /// In en, this message translates to:
  /// **'the translator answered in a form the program cannot read'**
  String get trErrBadReply;

  /// No description provided for @trErrOther.
  ///
  /// In en, this message translates to:
  /// **'translation failed'**
  String get trErrOther;

  /// No description provided for @needsArchiveTool.
  ///
  /// In en, this message translates to:
  /// **'CBR, RAR, CB7 and 7Z need 7-Zip (7-zip.org) or WinRAR installed'**
  String get needsArchiveTool;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the pages: {error}'**
  String exportFailed(String error);

  /// No description provided for @importedAs.
  ///
  /// In en, this message translates to:
  /// **'installed as {model}'**
  String importedAs(String model);

  /// No description provided for @notAModelFile.
  ///
  /// In en, this message translates to:
  /// **'not a known model file'**
  String get notAModelFile;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Details are in the log; a bug report helps fix it.'**
  String get unexpectedError;

  /// No description provided for @runFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start: {error}'**
  String runFailed(String error);

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Send text over the network?'**
  String get networkTitle;

  /// No description provided for @networkBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sends the recognized text to {host} ({where}).'**
  String networkBody(String name, String host, String where);

  /// No description provided for @networkWhereLan.
  ///
  /// In en, this message translates to:
  /// **'a computer on your local network'**
  String get networkWhereLan;

  /// No description provided for @networkWhereCloud.
  ///
  /// In en, this message translates to:
  /// **'an internet service'**
  String get networkWhereCloud;

  /// No description provided for @networkBodyImage.
  ///
  /// In en, this message translates to:
  /// **'Page images are sent too (setting \"Send page image\").'**
  String get networkBodyImage;

  /// No description provided for @networkOffline.
  ///
  /// In en, this message translates to:
  /// **'To work fully offline, choose a local translator in Settings.'**
  String get networkOffline;

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow this time'**
  String get allowOnce;

  /// No description provided for @allowAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow for this server'**
  String get allowAlways;

  /// No description provided for @downloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download models?'**
  String get downloadTitle;

  /// No description provided for @downloadBody.
  ///
  /// In en, this message translates to:
  /// **'These models are needed and not downloaded yet ({size} in total). They are saved on this computer and then work without internet.'**
  String downloadBody(String size);

  /// No description provided for @downloadFrom.
  ///
  /// In en, this message translates to:
  /// **'{size}, from {host}'**
  String downloadFrom(String size, String host);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder for the translated pages'**
  String get exportTitle;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} page(s) to {path}'**
  String exportDone(String count, String path);

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No translated pages yet'**
  String get nothingToExport;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsTranslator.
  ///
  /// In en, this message translates to:
  /// **'Translator'**
  String get settingsTranslator;

  /// No description provided for @settingsTools.
  ///
  /// In en, this message translates to:
  /// **'Recognition and cleaning'**
  String get settingsTools;

  /// No description provided for @settingsText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get settingsText;

  /// No description provided for @settingsUpscale.
  ///
  /// In en, this message translates to:
  /// **'Enlarging'**
  String get settingsUpscale;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExport;

  /// No description provided for @settingsModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsModels;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'As in Windows'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @uiLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get uiLanguage;

  /// No description provided for @useGpu.
  ///
  /// In en, this message translates to:
  /// **'Use the graphics card (DirectML)'**
  String get useGpu;

  /// No description provided for @useGpuHelp.
  ///
  /// In en, this message translates to:
  /// **'Faster on some computers; if something does not work, the processor is used automatically.'**
  String get useGpuHelp;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode'**
  String get testMode;

  /// No description provided for @testModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Saves every step of each run for bug reports (uses disk space).'**
  String get testModeHelp;

  /// No description provided for @openLogs.
  ///
  /// In en, this message translates to:
  /// **'Open logs folder'**
  String get openLogs;

  /// No description provided for @bugReport.
  ///
  /// In en, this message translates to:
  /// **'Create bug report'**
  String get bugReport;

  /// No description provided for @bugReportHelp.
  ///
  /// In en, this message translates to:
  /// **'A zip with logs and settings, without keys and without pictures.'**
  String get bugReportHelp;

  /// No description provided for @bugReportDone.
  ///
  /// In en, this message translates to:
  /// **'Report saved: {path}'**
  String bugReportDone(String path);

  /// No description provided for @unexpectedErrorReported.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. A bug report was saved: {path}'**
  String unexpectedErrorReported(String path);

  /// No description provided for @autoBugReport.
  ///
  /// In en, this message translates to:
  /// **'Build a bug report automatically'**
  String get autoBugReport;

  /// No description provided for @autoBugReportHelp.
  ///
  /// In en, this message translates to:
  /// **'After an unexpected error the program saves a report by itself and shows where it is. It stays on this computer.'**
  String get autoBugReportHelp;

  /// No description provided for @autoBugReportOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off automatic bug reports?'**
  String get autoBugReportOffTitle;

  /// No description provided for @autoBugReportOffText.
  ///
  /// In en, this message translates to:
  /// **'This is an important feature: the report keeps what happened right at the moment of the error, so the problem can be found and fixed. It stays only on your computer and is never sent anywhere; it has no API keys and no page images.\n\nWithout it, a report has to be built by hand after an error, and details may already be lost.'**
  String get autoBugReportOffText;

  /// No description provided for @autoBugReportKeepOn.
  ///
  /// In en, this message translates to:
  /// **'Keep it on'**
  String get autoBugReportKeepOn;

  /// No description provided for @autoBugReportTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get autoBugReportTurnOff;

  /// No description provided for @translator.
  ///
  /// In en, this message translates to:
  /// **'Translator'**
  String get translator;

  /// No description provided for @privacyLocalBadge.
  ///
  /// In en, this message translates to:
  /// **'On this computer'**
  String get privacyLocalBadge;

  /// No description provided for @privacyLanBadge.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get privacyLanBadge;

  /// No description provided for @privacyCloudBadge.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get privacyCloudBadge;

  /// No description provided for @sendsDataWarning.
  ///
  /// In en, this message translates to:
  /// **'Sends text outside this computer: {host}'**
  String sendsDataWarning(String host);

  /// No description provided for @savedSecurely.
  ///
  /// In en, this message translates to:
  /// **'Stored in Windows secure storage, never in files or logs. Each translator (and later each online text recognizer) keeps its own key. A saved key is never shown in full, only its last 4 characters.'**
  String get savedSecurely;

  /// No description provided for @secretSet.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get secretSet;

  /// No description provided for @secretNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get secretNotSet;

  /// No description provided for @secretRemove.
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get secretRemove;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Allowed servers'**
  String get approvals;

  /// No description provided for @approvalsNone.
  ///
  /// In en, this message translates to:
  /// **'None yet; the app asks before sending anything.'**
  String get approvalsNone;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @extraContext.
  ///
  /// In en, this message translates to:
  /// **'Extra context for the translator'**
  String get extraContext;

  /// No description provided for @extraContextHelp.
  ///
  /// In en, this message translates to:
  /// **'For example names, setting or tone of the comic.'**
  String get extraContextHelp;

  /// No description provided for @sendPageImage.
  ///
  /// In en, this message translates to:
  /// **'Send page image'**
  String get sendPageImage;

  /// No description provided for @sendPageImageHelp.
  ///
  /// In en, this message translates to:
  /// **'Helps some models understand the scene; the whole page is sent to the translator.'**
  String get sendPageImageHelp;

  /// No description provided for @detector.
  ///
  /// In en, this message translates to:
  /// **'Text detection'**
  String get detector;

  /// No description provided for @ocr.
  ///
  /// In en, this message translates to:
  /// **'Text recognition'**
  String get ocr;

  /// No description provided for @inpainter.
  ///
  /// In en, this message translates to:
  /// **'Text removal'**
  String get inpainter;

  /// No description provided for @hdStrategy.
  ///
  /// In en, this message translates to:
  /// **'Cleaning large pages'**
  String get hdStrategy;

  /// No description provided for @hdResize.
  ///
  /// In en, this message translates to:
  /// **'Shrink (faster)'**
  String get hdResize;

  /// No description provided for @hdCrop.
  ///
  /// In en, this message translates to:
  /// **'In pieces (more precise)'**
  String get hdCrop;

  /// No description provided for @hdOriginal.
  ///
  /// In en, this message translates to:
  /// **'Full size (slow)'**
  String get hdOriginal;

  /// No description provided for @resizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Shrink to (px, long side)'**
  String get resizeLimit;

  /// No description provided for @cropMargin.
  ///
  /// In en, this message translates to:
  /// **'Piece margin (px)'**
  String get cropMargin;

  /// No description provided for @cropTrigger.
  ///
  /// In en, this message translates to:
  /// **'Use pieces from (px)'**
  String get cropTrigger;

  /// No description provided for @textPrep.
  ///
  /// In en, this message translates to:
  /// **'Preparing small text for reading'**
  String get textPrep;

  /// No description provided for @textPrepScreens.
  ///
  /// In en, this message translates to:
  /// **'Preparing small text for reading (sites and games)'**
  String get textPrepScreens;

  /// No description provided for @fixCyrillic.
  ///
  /// In en, this message translates to:
  /// **'Fix Latin look-alikes in Cyrillic text'**
  String get fixCyrillic;

  /// No description provided for @fixCyrillicHelp.
  ///
  /// In en, this message translates to:
  /// **'\"HET\" becomes \"НЕТ\"; may also change Latin words.'**
  String get fixCyrillicHelp;

  /// No description provided for @font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// No description provided for @fontDefault.
  ///
  /// In en, this message translates to:
  /// **'Pangolin (built in)'**
  String get fontDefault;

  /// No description provided for @minFontSize.
  ///
  /// In en, this message translates to:
  /// **'Smallest size (pt)'**
  String get minFontSize;

  /// No description provided for @maxFontSize.
  ///
  /// In en, this message translates to:
  /// **'Largest size (pt)'**
  String get maxFontSize;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text colour'**
  String get textColor;

  /// No description provided for @outline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outline;

  /// No description provided for @outlineColor.
  ///
  /// In en, this message translates to:
  /// **'Outline colour'**
  String get outlineColor;

  /// No description provided for @outlineWidth.
  ///
  /// In en, this message translates to:
  /// **'Outline width'**
  String get outlineWidth;

  /// No description provided for @upperCase.
  ///
  /// In en, this message translates to:
  /// **'Upper case'**
  String get upperCase;

  /// No description provided for @alignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignment;

  /// No description provided for @alignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get alignCenter;

  /// No description provided for @alignRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get alignRight;

  /// No description provided for @placeInBlock.
  ///
  /// In en, this message translates to:
  /// **'Centre the text in its bubble'**
  String get placeInBlock;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @upscaleHelp.
  ///
  /// In en, this message translates to:
  /// **'On small pages the translation is drawn on an enlarged copy, so the letters stay sharp. The method only affects the picture.'**
  String get upscaleHelp;

  /// No description provided for @upscaleMode.
  ///
  /// In en, this message translates to:
  /// **'When to enlarge'**
  String get upscaleMode;

  /// No description provided for @upscaleAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatically (small pages)'**
  String get upscaleAuto;

  /// No description provided for @upscaleOff.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get upscaleOff;

  /// No description provided for @upscaleWidth.
  ///
  /// In en, this message translates to:
  /// **'To width'**
  String get upscaleWidth;

  /// No description provided for @upscaleWidthValue.
  ///
  /// In en, this message translates to:
  /// **'Width (px)'**
  String get upscaleWidthValue;

  /// No description provided for @upscaleMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get upscaleMethod;

  /// No description provided for @upscaleFast.
  ///
  /// In en, this message translates to:
  /// **'Fast (Lanczos)'**
  String get upscaleFast;

  /// No description provided for @upscaleGood.
  ///
  /// In en, this message translates to:
  /// **'Good (neural network) — coming later'**
  String get upscaleGood;

  /// No description provided for @upscaleBest.
  ///
  /// In en, this message translates to:
  /// **'Best (larger neural network) — coming later'**
  String get upscaleBest;

  /// No description provided for @imageFormat.
  ///
  /// In en, this message translates to:
  /// **'Image format'**
  String get imageFormat;

  /// No description provided for @formatSource.
  ///
  /// In en, this message translates to:
  /// **'Same as the original'**
  String get formatSource;

  /// No description provided for @autoExport.
  ///
  /// In en, this message translates to:
  /// **'After \"Translate all\", also save'**
  String get autoExport;

  /// No description provided for @autoExportHelp.
  ///
  /// In en, this message translates to:
  /// **'Into a comic_translate_<date> folder next to the original files.'**
  String get autoExportHelp;

  /// No description provided for @exportRawText.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get exportRawText;

  /// No description provided for @exportTranslatedText.
  ///
  /// In en, this message translates to:
  /// **'Translated text'**
  String get exportTranslatedText;

  /// No description provided for @exportCleaned.
  ///
  /// In en, this message translates to:
  /// **'Cleaned pages'**
  String get exportCleaned;

  /// No description provided for @modelsFolder.
  ///
  /// In en, this message translates to:
  /// **'Models folder'**
  String get modelsFolder;

  /// No description provided for @modelsFolderHelp.
  ///
  /// In en, this message translates to:
  /// **'Models already downloaded are not moved; copy them or use Import.'**
  String get modelsFolderHelp;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change…'**
  String get changeFolder;

  /// No description provided for @defaultFolder.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultFolder;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @importModels.
  ///
  /// In en, this message translates to:
  /// **'Import from disk…'**
  String get importModels;

  /// No description provided for @importModelsHelp.
  ///
  /// In en, this message translates to:
  /// **'Model files or zip archives copied from another computer; they are recognized by checksum.'**
  String get importModelsHelp;

  /// No description provided for @importModelsDone.
  ///
  /// In en, this message translates to:
  /// **'Installed model files: {count}'**
  String importModelsDone(String count);

  /// No description provided for @modelInstalled.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get modelInstalled;

  /// No description provided for @modelMissing.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get modelMissing;

  /// No description provided for @modelCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get modelCorrupt;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get verify;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteModelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? It can be downloaded again later.'**
  String deleteModelConfirm(String name);

  /// No description provided for @verifyOk.
  ///
  /// In en, this message translates to:
  /// **'Files are intact'**
  String get verifyOk;

  /// No description provided for @verifyBad.
  ///
  /// In en, this message translates to:
  /// **'Damaged files: {files}'**
  String verifyBad(String files);

  /// No description provided for @aboutIndependent.
  ///
  /// In en, this message translates to:
  /// **'An independent project based on ogkalu2/comic-translate; not the official version.'**
  String get aboutIndependent;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'No accounts, no telemetry. Data leaves this computer only for a translator you choose, and the app asks first.'**
  String get aboutPrivacy;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License: Apache 2.0'**
  String get license;

  /// No description provided for @dataFolder.
  ///
  /// In en, this message translates to:
  /// **'Data folder'**
  String get dataFolder;

  /// No description provided for @thirdPartyLicenses.
  ///
  /// In en, this message translates to:
  /// **'Third-party licenses'**
  String get thirdPartyLicenses;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author: {author}'**
  String aboutAuthor(String author);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @drawingPages.
  ///
  /// In en, this message translates to:
  /// **'Drawing the edited pages…'**
  String get drawingPages;

  /// No description provided for @toolPan.
  ///
  /// In en, this message translates to:
  /// **'Hand: move the page, click a bubble to select it (H)'**
  String get toolPan;

  /// No description provided for @toolBoxes.
  ///
  /// In en, this message translates to:
  /// **'Boxes: draw a box around text, move or resize it (R)'**
  String get toolBoxes;

  /// No description provided for @toolText.
  ///
  /// In en, this message translates to:
  /// **'Translation: move, resize and turn the text (T)'**
  String get toolText;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush: paint what to clean (B)'**
  String get toolBrush;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser: remove parts of the mask (E)'**
  String get toolEraser;

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size ([ and ])'**
  String get brushSize;

  /// No description provided for @clearMask.
  ///
  /// In en, this message translates to:
  /// **'Remove the whole mask'**
  String get clearMask;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo (Ctrl+Z)'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo (Ctrl+Y)'**
  String get redo;

  /// No description provided for @stepDetect.
  ///
  /// In en, this message translates to:
  /// **'Find text'**
  String get stepDetect;

  /// No description provided for @stepDetectHelp.
  ///
  /// In en, this message translates to:
  /// **'finds the text on this page and puts boxes around it'**
  String get stepDetectHelp;

  /// No description provided for @stepRecognize.
  ///
  /// In en, this message translates to:
  /// **'Recognize'**
  String get stepRecognize;

  /// No description provided for @stepRecognizeHelp.
  ///
  /// In en, this message translates to:
  /// **'reads the text in the boxes'**
  String get stepRecognizeHelp;

  /// No description provided for @stepTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get stepTranslate;

  /// No description provided for @stepTranslateHelp.
  ///
  /// In en, this message translates to:
  /// **'translates the recognized text of this page (finds and reads it first if needed)'**
  String get stepTranslateHelp;

  /// No description provided for @stepMask.
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get stepMask;

  /// No description provided for @stepMaskHelp.
  ///
  /// In en, this message translates to:
  /// **'marks the letters to remove in red; correct it with the brush and the eraser'**
  String get stepMaskHelp;

  /// No description provided for @stepClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get stepClean;

  /// No description provided for @stepCleanHelp.
  ///
  /// In en, this message translates to:
  /// **'removes the marked text from the picture'**
  String get stepCleanHelp;

  /// No description provided for @fontFile.
  ///
  /// In en, this message translates to:
  /// **'Font file…'**
  String get fontFile;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fontSize;

  /// No description provided for @sizeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get sizeAuto;

  /// No description provided for @sizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The size is chosen once the bubble has a translation'**
  String get sizeUnknown;

  /// No description provided for @colorAuto.
  ///
  /// In en, this message translates to:
  /// **'As in the original'**
  String get colorAuto;

  /// No description provided for @textStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get textStyle;

  /// No description provided for @verticalText.
  ///
  /// In en, this message translates to:
  /// **'Vertical text'**
  String get verticalText;

  /// No description provided for @rotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// No description provided for @styleToAll.
  ///
  /// In en, this message translates to:
  /// **'To all on the page'**
  String get styleToAll;

  /// No description provided for @styleReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get styleReset;

  /// No description provided for @findReplace.
  ///
  /// In en, this message translates to:
  /// **'Find and replace (Ctrl+F)'**
  String get findReplace;

  /// No description provided for @noBlocksHint.
  ///
  /// In en, this message translates to:
  /// **'No text boxes on this page yet. Use “Find text” above the page, “Translate all”, or draw boxes with the Boxes tool.'**
  String get noBlocksHint;

  /// No description provided for @recognizeBlock.
  ///
  /// In en, this message translates to:
  /// **'Recognize this box again'**
  String get recognizeBlock;

  /// No description provided for @translateBlock.
  ///
  /// In en, this message translates to:
  /// **'Translate this box again'**
  String get translateBlock;

  /// No description provided for @deleteBlock.
  ///
  /// In en, this message translates to:
  /// **'Delete the box (Delete)'**
  String get deleteBlock;

  /// No description provided for @deselect.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get deselect;

  /// No description provided for @sourceText.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get sourceText;

  /// No description provided for @translationText.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationText;

  /// No description provided for @textLook.
  ///
  /// In en, this message translates to:
  /// **'Look of the text'**
  String get textLook;

  /// No description provided for @findHint.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findHint;

  /// No description provided for @matchCase.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get matchCase;

  /// No description provided for @wholeWord.
  ///
  /// In en, this message translates to:
  /// **'Whole words'**
  String get wholeWord;

  /// No description provided for @useRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get useRegex;

  /// No description provided for @preserveCase.
  ///
  /// In en, this message translates to:
  /// **'Preserve case: the replacement takes the case of the found text (hello → world, HELLO → WORLD, Hello → World)'**
  String get preserveCase;

  /// No description provided for @previousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous (Shift+Enter)'**
  String get previousMatch;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next (Enter)'**
  String get nextMatch;

  /// No description provided for @searchInTranslation.
  ///
  /// In en, this message translates to:
  /// **'In translations'**
  String get searchInTranslation;

  /// No description provided for @searchInSource.
  ///
  /// In en, this message translates to:
  /// **'In recognized text'**
  String get searchInSource;

  /// No description provided for @searchAllPages.
  ///
  /// In en, this message translates to:
  /// **'All pages'**
  String get searchAllPages;

  /// No description provided for @searchThisPage.
  ///
  /// In en, this message translates to:
  /// **'This page'**
  String get searchThisPage;

  /// No description provided for @badRegex.
  ///
  /// In en, this message translates to:
  /// **'Not a valid regular expression: {error}'**
  String badRegex(String error);

  /// No description provided for @matchesSummary.
  ///
  /// In en, this message translates to:
  /// **'Found: {count} on {pages} page(s)'**
  String matchesSummary(String count, String pages);

  /// No description provided for @replaceHint.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceHint;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceAll;

  /// No description provided for @replacedCount.
  ///
  /// In en, this message translates to:
  /// **'Replaced: {count}'**
  String replacedCount(String count);

  /// No description provided for @shortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shortcutsTitle;

  /// No description provided for @shortcutsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts (F1)'**
  String get shortcutsTooltip;

  /// No description provided for @keysGroupFiles.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get keysGroupFiles;

  /// No description provided for @keysGroupTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get keysGroupTools;

  /// No description provided for @keysGroupEdit.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get keysGroupEdit;

  /// No description provided for @keysGroupMouse.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get keysGroupMouse;

  /// No description provided for @keyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open files'**
  String get keyOpen;

  /// No description provided for @keyTranslateAll.
  ///
  /// In en, this message translates to:
  /// **'Translate all'**
  String get keyTranslateAll;

  /// No description provided for @keyPan.
  ///
  /// In en, this message translates to:
  /// **'Hand: move the page, select a bubble'**
  String get keyPan;

  /// No description provided for @keyBoxes.
  ///
  /// In en, this message translates to:
  /// **'Boxes around the text'**
  String get keyBoxes;

  /// No description provided for @keyText.
  ///
  /// In en, this message translates to:
  /// **'Move, resize and turn the translation'**
  String get keyText;

  /// No description provided for @keyBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush: mark what to clean'**
  String get keyBrush;

  /// No description provided for @keyEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser: unmark'**
  String get keyEraser;

  /// No description provided for @keyUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get keyUndo;

  /// No description provided for @keyRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get keyRedo;

  /// No description provided for @keyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the selected box'**
  String get keyDelete;

  /// No description provided for @keyDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect the bubble'**
  String get keyDeselect;

  /// No description provided for @keyFind.
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get keyFind;

  /// No description provided for @keyFindNext.
  ///
  /// In en, this message translates to:
  /// **'Next / previous match (in the find field)'**
  String get keyFindNext;

  /// No description provided for @mouseWheel.
  ///
  /// In en, this message translates to:
  /// **'Wheel'**
  String get mouseWheel;

  /// No description provided for @mouseWheelHelp.
  ///
  /// In en, this message translates to:
  /// **'Zoom in and out'**
  String get mouseWheelHelp;

  /// No description provided for @mouseMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle button, drag'**
  String get mouseMiddle;

  /// No description provided for @mouseMiddleHelp.
  ///
  /// In en, this message translates to:
  /// **'Move the page with any tool'**
  String get mouseMiddleHelp;

  /// No description provided for @mouseDouble.
  ///
  /// In en, this message translates to:
  /// **'Double click on a translation'**
  String get mouseDouble;

  /// No description provided for @mouseDoubleHelp.
  ///
  /// In en, this message translates to:
  /// **'Edit its text in the right panel (Translation tool)'**
  String get mouseDoubleHelp;

  /// No description provided for @keysNote.
  ///
  /// In en, this message translates to:
  /// **'Keys without Ctrl or Alt do nothing while you type in a text field. They work with any keyboard layout. To change them: Settings → Keys.'**
  String get keysNote;

  /// No description provided for @keysGroupWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get keysGroupWindow;

  /// No description provided for @keyHelp.
  ///
  /// In en, this message translates to:
  /// **'This list of keys'**
  String get keyHelp;

  /// No description provided for @keyFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen on and off'**
  String get keyFullScreen;

  /// No description provided for @keyPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get keyPreviousPage;

  /// No description provided for @keyNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get keyNextPage;

  /// No description provided for @keyBrushSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller brush'**
  String get keyBrushSmaller;

  /// No description provided for @keyBrushLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger brush'**
  String get keyBrushLarger;

  /// No description provided for @settingsKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get settingsKeys;

  /// No description provided for @keysSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Click an action to give it another key or combination. Keys without Ctrl or Alt do nothing while you type in a text field.'**
  String get keysSettingsHelp;

  /// No description provided for @keysNone.
  ///
  /// In en, this message translates to:
  /// **'no key'**
  String get keysNone;

  /// No description provided for @keysChange.
  ///
  /// In en, this message translates to:
  /// **'Change the key'**
  String get keysChange;

  /// No description provided for @keysDefault.
  ///
  /// In en, this message translates to:
  /// **'Back to the default key'**
  String get keysDefault;

  /// No description provided for @keysCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'New key: {action}'**
  String keysCaptureTitle(String action);

  /// No description provided for @keysCaptureBody.
  ///
  /// In en, this message translates to:
  /// **'Press a key or a combination with Ctrl, Shift or Alt.'**
  String get keysCaptureBody;

  /// No description provided for @keysCaptureTaken.
  ///
  /// In en, this message translates to:
  /// **'Now used by \"{action}\": it will be taken from there.'**
  String keysCaptureTaken(String action);

  /// No description provided for @keysCaptureReserved.
  ///
  /// In en, this message translates to:
  /// **'Text fields and windows need this key; choose another one.'**
  String get keysCaptureReserved;

  /// No description provided for @keysCaptureNoKey.
  ///
  /// In en, this message translates to:
  /// **'No key'**
  String get keysCaptureNoKey;

  /// No description provided for @fullScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Full screen. Press F11 to leave it.'**
  String get fullScreenOn;

  /// No description provided for @secretSavedTail.
  ///
  /// In en, this message translates to:
  /// **'Saved: …{tail}'**
  String secretSavedTail(String tail);

  /// No description provided for @secretShow.
  ///
  /// In en, this message translates to:
  /// **'Show what you typed'**
  String get secretShow;

  /// No description provided for @secretHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get secretHide;

  /// No description provided for @secretReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get secretReplace;

  /// No description provided for @secretReplaceHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a new key to replace the saved one'**
  String get secretReplaceHint;

  /// No description provided for @secretRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the key?'**
  String get secretRemoveTitle;

  /// No description provided for @secretRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The saved key is removed from Windows secure storage. To translate with this service again, paste the key anew. The key itself stays valid on the service\'s site: revoke it there if you no longer need it.'**
  String get secretRemoveBody;

  /// No description provided for @keyStatusCheck.
  ///
  /// In en, this message translates to:
  /// **'Check balance'**
  String get keyStatusCheck;

  /// No description provided for @keyStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Asks {host} what is left of the key\'s limit. Only the key is sent, and only when you press the button.'**
  String keyStatusHelp(String host);

  /// No description provided for @keyStatusNeedsKey.
  ///
  /// In en, this message translates to:
  /// **'Save the API key first'**
  String get keyStatusNeedsKey;

  /// No description provided for @keyStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get keyStatusChecking;

  /// No description provided for @keyStatusLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit {limit}, spent {used}, left {left}'**
  String keyStatusLimit(String limit, String used, String left);

  /// No description provided for @keyStatusNoLimit.
  ///
  /// In en, this message translates to:
  /// **'The key has no limit. Spent: {used}'**
  String keyStatusNoLimit(String used);

  /// No description provided for @keyStatusToday.
  ///
  /// In en, this message translates to:
  /// **'Spent today (UTC): {today}, this month: {month}'**
  String keyStatusToday(String today, String month);

  /// No description provided for @keyStatusDelay.
  ///
  /// In en, this message translates to:
  /// **'The service updates these numbers a few minutes late; the usage below is counted at once.'**
  String get keyStatusDelay;

  /// No description provided for @keyStatusResetDaily.
  ///
  /// In en, this message translates to:
  /// **'The limit starts again every day.'**
  String get keyStatusResetDaily;

  /// No description provided for @keyStatusResetWeekly.
  ///
  /// In en, this message translates to:
  /// **'The limit starts again every week.'**
  String get keyStatusResetWeekly;

  /// No description provided for @keyStatusResetMonthly.
  ///
  /// In en, this message translates to:
  /// **'The limit starts again every month.'**
  String get keyStatusResetMonthly;

  /// No description provided for @keyStatusFree.
  ///
  /// In en, this message translates to:
  /// **'Free models today: {used} of {limit} requests, {left} left'**
  String keyStatusFree(String used, String limit, String left);

  /// No description provided for @keyStatusFreeNote.
  ///
  /// In en, this message translates to:
  /// **'Free models also allow about 20 requests per minute; the server does not report that limit in advance.'**
  String get keyStatusFreeNote;

  /// No description provided for @keyStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check: {reason}'**
  String keyStatusFailed(String reason);

  /// No description provided for @keyStatusAt.
  ///
  /// In en, this message translates to:
  /// **'Checked at {time}'**
  String keyStatusAt(String time);

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage on this computer'**
  String get usageTitle;

  /// No description provided for @usageHelp.
  ///
  /// In en, this message translates to:
  /// **'The program counts the requests from the servers\' replies. The counter is kept only on this computer and is never sent anywhere. Tokens marked ≈ are estimated: that server does not report them.'**
  String get usageHelp;

  /// No description provided for @usageNone.
  ///
  /// In en, this message translates to:
  /// **'No requests to translation servers yet.'**
  String get usageNone;

  /// No description provided for @usageModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get usageModel;

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get usageTotal;

  /// No description provided for @usageRequests.
  ///
  /// In en, this message translates to:
  /// **'requests: {count}'**
  String usageRequests(String count);

  /// No description provided for @usageTokens.
  ///
  /// In en, this message translates to:
  /// **'tokens: {count}'**
  String usageTokens(String count);

  /// No description provided for @usageCost.
  ///
  /// In en, this message translates to:
  /// **'cost: {cost}'**
  String usageCost(String cost);

  /// No description provided for @usageSince.
  ///
  /// In en, this message translates to:
  /// **'Counted since {date}'**
  String usageSince(String date);

  /// No description provided for @usageReset.
  ///
  /// In en, this message translates to:
  /// **'Reset the counter'**
  String get usageReset;

  /// No description provided for @usageResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the counter?'**
  String get usageResetTitle;

  /// No description provided for @usageResetBody.
  ///
  /// In en, this message translates to:
  /// **'The local counter starts from zero. Nothing changes on the servers or in your account.'**
  String get usageResetBody;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @openProject.
  ///
  /// In en, this message translates to:
  /// **'Open project…'**
  String get openProject;

  /// No description provided for @saveProject.
  ///
  /// In en, this message translates to:
  /// **'Save project (Ctrl+S)'**
  String get saveProject;

  /// No description provided for @saveProjectAs.
  ///
  /// In en, this message translates to:
  /// **'Save project as… (Ctrl+Shift+S)'**
  String get saveProjectAs;

  /// No description provided for @recentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent projects'**
  String get recentProjects;

  /// No description provided for @projectFileType.
  ///
  /// In en, this message translates to:
  /// **'Comic Translate Screen projects'**
  String get projectFileType;

  /// No description provided for @untitledProject.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledProject;

  /// No description provided for @projectSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Saved at {time}'**
  String projectSavedAt(String time);

  /// No description provided for @projectSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get projectSaving;

  /// No description provided for @projectUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get projectUnsaved;

  /// No description provided for @projectNoFile.
  ///
  /// In en, this message translates to:
  /// **'Not saved in a project yet (Ctrl+S)'**
  String get projectNoFile;

  /// No description provided for @projectSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the project: {error}'**
  String projectSaveFailed(String error);

  /// No description provided for @projectOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the project: {error}'**
  String projectOpenFailed(String error);

  /// No description provided for @projectNewer.
  ///
  /// In en, this message translates to:
  /// **'it was saved by a newer version of the program; please update it'**
  String get projectNewer;

  /// No description provided for @projectNotProject.
  ///
  /// In en, this message translates to:
  /// **'this is not a Comic Translate Screen project'**
  String get projectNotProject;

  /// No description provided for @projectDamaged.
  ///
  /// In en, this message translates to:
  /// **'the file is damaged'**
  String get projectDamaged;

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Save the changes?'**
  String get unsavedTitle;

  /// No description provided for @unsavedNew.
  ///
  /// In en, this message translates to:
  /// **'The pages and edits are not saved in a project yet. Unless you save them, they will be lost.'**
  String get unsavedNew;

  /// No description provided for @unsavedProject.
  ///
  /// In en, this message translates to:
  /// **'“{name}” has unsaved changes.'**
  String unsavedProject(String name);

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dontSave;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveAs;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your previous work?'**
  String get recoveryTitle;

  /// No description provided for @recoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Last time the program closed without saving your work. A copy was kept: {pages} page(s), {time}.'**
  String recoveryBody(String pages, String time);

  /// No description provided for @recoveryRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get recoveryRestore;

  /// No description provided for @recoveryDiscard.
  ///
  /// In en, this message translates to:
  /// **'Delete the copy'**
  String get recoveryDiscard;

  /// No description provided for @recoveryRestored.
  ///
  /// In en, this message translates to:
  /// **'Your previous work is back. Save it as a project to keep it.'**
  String get recoveryRestored;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from the list'**
  String get removeFromList;

  /// No description provided for @settingsProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get settingsProjects;

  /// No description provided for @projectAutosave.
  ///
  /// In en, this message translates to:
  /// **'Save projects automatically'**
  String get projectAutosave;

  /// No description provided for @projectAutosaveHelp.
  ///
  /// In en, this message translates to:
  /// **'A project that has a file saves itself a couple of seconds after every change and after every page of “Translate all”. Work that is not saved in a project yet is copied every 2 minutes, so it can be restored after a crash.'**
  String get projectAutosaveHelp;

  /// No description provided for @openingProject.
  ///
  /// In en, this message translates to:
  /// **'Opening the project…'**
  String get openingProject;

  /// No description provided for @keySave.
  ///
  /// In en, this message translates to:
  /// **'Save the project'**
  String get keySave;

  /// No description provided for @keySaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save the project as a new file'**
  String get keySaveAs;

  /// No description provided for @exportWhat.
  ///
  /// In en, this message translates to:
  /// **'What to save'**
  String get exportWhat;

  /// No description provided for @exportTranslatedPages.
  ///
  /// In en, this message translates to:
  /// **'Pages with the translation'**
  String get exportTranslatedPages;

  /// No description provided for @exportCleanedPages.
  ///
  /// In en, this message translates to:
  /// **'Cleaned pages (text removed)'**
  String get exportCleanedPages;

  /// No description provided for @exportRecognizedJson.
  ///
  /// In en, this message translates to:
  /// **'Recognized text (JSON)'**
  String get exportRecognizedJson;

  /// No description provided for @exportTranslatedJson.
  ///
  /// In en, this message translates to:
  /// **'Translation as text (JSON)'**
  String get exportTranslatedJson;

  /// No description provided for @exportWhere.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get exportWhere;

  /// No description provided for @exportFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get exportFolder;

  /// No description provided for @exportReaderNote.
  ///
  /// In en, this message translates to:
  /// **'CBZ, CB7 and PDF are for comic readers: they hold pictures of one kind (with the translation if it is chosen), without texts.'**
  String get exportReaderNote;

  /// No description provided for @exportNeeds7zip.
  ///
  /// In en, this message translates to:
  /// **'CB7 needs 7-Zip installed'**
  String get exportNeeds7zip;

  /// No description provided for @exportPdfFormat.
  ///
  /// In en, this message translates to:
  /// **'In a PDF, PNG keeps every pixel; the other formats become JPEG.'**
  String get exportPdfFormat;

  /// No description provided for @exportWhich.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get exportWhich;

  /// No description provided for @exportAllPages.
  ///
  /// In en, this message translates to:
  /// **'All finished pages ({count})'**
  String exportAllPages(String count);

  /// No description provided for @exportCurrentPage.
  ///
  /// In en, this message translates to:
  /// **'Only the current page'**
  String get exportCurrentPage;

  /// No description provided for @exportByChapter.
  ///
  /// In en, this message translates to:
  /// **'A separate file for each chapter ({count})'**
  String exportByChapter(String count);

  /// No description provided for @exportStart.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get exportStart;

  /// No description provided for @exportingPages.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportingPages;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String exportSaved(String path);

  /// No description provided for @fontAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a font…'**
  String get fontAdd;

  /// No description provided for @fontAddHelp.
  ///
  /// In en, this message translates to:
  /// **'Fonts are copied into the program\'s folder and appear in every font list. A project keeps the fonts its bubbles use.'**
  String get fontAddHelp;

  /// No description provided for @fontsAdded.
  ///
  /// In en, this message translates to:
  /// **'Fonts added: {count}'**
  String fontsAdded(String count);

  /// No description provided for @fontRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the font'**
  String get fontRemove;

  /// No description provided for @boxesAll.
  ///
  /// In en, this message translates to:
  /// **'All boxes'**
  String get boxesAll;

  /// No description provided for @boxesGrow.
  ///
  /// In en, this message translates to:
  /// **'Make all boxes larger by {px} px'**
  String boxesGrow(String px);

  /// No description provided for @boxesShrink.
  ///
  /// In en, this message translates to:
  /// **'Make all boxes smaller by {px} px'**
  String boxesShrink(String px);

  /// No description provided for @boxesDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all boxes of the page'**
  String get boxesDeleteAll;

  /// No description provided for @languagesForAll.
  ///
  /// In en, this message translates to:
  /// **'Use this page\'s languages for all pages'**
  String get languagesForAll;

  /// No description provided for @pagesPicked.
  ///
  /// In en, this message translates to:
  /// **'Pages selected: {count} (Ctrl or Shift + click)'**
  String pagesPicked(String count);

  /// No description provided for @pagesPickedClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the selection'**
  String get pagesPickedClear;

  /// No description provided for @stepsForPicked.
  ///
  /// In en, this message translates to:
  /// **'for {count} selected pages'**
  String stepsForPicked(String count);

  /// No description provided for @mousePickPages.
  ///
  /// In en, this message translates to:
  /// **'Ctrl / Shift + click on a page'**
  String get mousePickPages;

  /// No description provided for @keyPickPages.
  ///
  /// In en, this message translates to:
  /// **'Select several pages for the steps'**
  String get keyPickPages;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset this section'**
  String get settingsReset;

  /// No description provided for @settingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings'**
  String get settingsResetAll;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the settings?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetBody.
  ///
  /// In en, this message translates to:
  /// **'The settings of “{name}” go back to how they were at first. API keys, projects and downloaded models stay.'**
  String settingsResetBody(String name);

  /// No description provided for @settingsResetAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every setting goes back to how it was at first, including the translator\'s server and model and the approved servers. API keys, the recent projects and downloaded models stay. If the models were in another folder, the program looks in the usual folder again (the files stay where they are).'**
  String get settingsResetAllBody;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings reset'**
  String get settingsResetDone;

  /// No description provided for @mouseGrab.
  ///
  /// In en, this message translates to:
  /// **'Space or Ctrl + left button, drag'**
  String get mouseGrab;

  /// No description provided for @modelDetector.
  ///
  /// In en, this message translates to:
  /// **'Text and bubble finder (RT-DETR)'**
  String get modelDetector;

  /// No description provided for @modelDetectorInfo.
  ///
  /// In en, this message translates to:
  /// **'Finds the text and the speech bubbles on a page. Needed always, for every language. Small and fast.'**
  String get modelDetectorInfo;

  /// No description provided for @modelAot.
  ///
  /// In en, this message translates to:
  /// **'Text removal (AOT)'**
  String get modelAot;

  /// No description provided for @modelAotInfo.
  ///
  /// In en, this message translates to:
  /// **'Erases the original text and paints the background under it. The default: fast, fine for weak computers.'**
  String get modelAotInfo;

  /// No description provided for @modelLama.
  ///
  /// In en, this message translates to:
  /// **'Better text removal (LaMa)'**
  String get modelLama;

  /// No description provided for @modelLamaInfo.
  ///
  /// In en, this message translates to:
  /// **'Restores the drawing under the text more neatly, especially under sound effects. Slower and larger than AOT. Chosen in Settings → Tools.'**
  String get modelLamaInfo;

  /// No description provided for @modelOcrEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get modelOcrEn;

  /// No description provided for @modelOcrEnInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads English text (PaddleOCR). Needed when the original is in English.'**
  String get modelOcrEnInfo;

  /// No description provided for @modelOcrLatin.
  ///
  /// In en, this message translates to:
  /// **'French, German, Spanish, Italian, Dutch'**
  String get modelOcrLatin;

  /// No description provided for @modelOcrLatinInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads text in these languages: Latin letters with accents (PaddleOCR).'**
  String get modelOcrLatinInfo;

  /// No description provided for @modelOcrEslav.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get modelOcrEslav;

  /// No description provided for @modelOcrEslavInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads Russian text (PaddleOCR, Cyrillic). Needed when the original is in Russian.'**
  String get modelOcrEslavInfo;

  /// No description provided for @modelOcrKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get modelOcrKorean;

  /// No description provided for @modelOcrKoreanInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads Korean text (PaddleOCR): manhwa and webtoons.'**
  String get modelOcrKoreanInfo;

  /// No description provided for @modelOcrChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese (and large Japanese text)'**
  String get modelOcrChinese;

  /// No description provided for @modelOcrChineseInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads Chinese text (PaddleOCR). For Japanese it is needed too, with manga-ocr: it reads large titles and captions.'**
  String get modelOcrChineseInfo;

  /// No description provided for @modelOcrJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese (manga-ocr)'**
  String get modelOcrJapanese;

  /// No description provided for @modelOcrJapaneseInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads Japanese text, also vertical; trained on manga. Works together with the Chinese model.'**
  String get modelOcrJapaneseInfo;

  /// No description provided for @modelOsd.
  ///
  /// In en, this message translates to:
  /// **'Language detection'**
  String get modelOsd;

  /// No description provided for @modelOsdInfo.
  ///
  /// In en, this message translates to:
  /// **'Tells the language of the original by its letters, for the source language \"Auto\". Small (3.7 MB), runs on the processor.'**
  String get modelOsdInfo;

  /// No description provided for @modelsCore.
  ///
  /// In en, this message translates to:
  /// **'Main (always needed)'**
  String get modelsCore;

  /// No description provided for @modelsLanguages.
  ///
  /// In en, this message translates to:
  /// **'Text recognition by language'**
  String get modelsLanguages;

  /// No description provided for @modelsLanguagesHelp.
  ///
  /// In en, this message translates to:
  /// **'Download only the languages you translate from. When a model is missing, the program offers to download it before translating.'**
  String get modelsLanguagesHelp;

  /// No description provided for @modelsExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get modelsExtra;

  /// No description provided for @modelsTextPrep.
  ///
  /// In en, this message translates to:
  /// **'Text preparation'**
  String get modelsTextPrep;

  /// No description provided for @modelsTextPrepHelp.
  ///
  /// In en, this message translates to:
  /// **'Neural networks that enlarge small text before recognition. Only the one chosen in \"Recognition and cleaning → Preparing small text\" is needed.'**
  String get modelsTextPrepHelp;

  /// No description provided for @modelsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Download what “{language}” needs'**
  String modelsNeeded(String language);

  /// No description provided for @modelsAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get modelsAll;

  /// No description provided for @modelsVerifyAll.
  ///
  /// In en, this message translates to:
  /// **'Check all'**
  String get modelsVerifyAll;

  /// No description provided for @modelsNothingNeeded.
  ///
  /// In en, this message translates to:
  /// **'Everything needed is downloaded'**
  String get modelsNothingNeeded;

  /// No description provided for @modelsSummary.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {count} of {total} · {size} on disk'**
  String modelsSummary(String count, String total, String size);

  /// No description provided for @modelsVerifyAllOk.
  ///
  /// In en, this message translates to:
  /// **'All downloaded models are fine'**
  String get modelsVerifyAllOk;

  /// No description provided for @modelsVerifyAllBad.
  ///
  /// In en, this message translates to:
  /// **'Damaged: {names}. Download them again.'**
  String modelsVerifyAllBad(String names);

  /// No description provided for @useGpuInfo.
  ///
  /// In en, this message translates to:
  /// **'Text finding, recognition and cleaning run on the graphics card through DirectML, which is part of Windows and works with NVIDIA, AMD and Intel. On a weak or old card it may be no faster than the processor. Translation is not sped up: it runs on the translator\'s server.'**
  String get useGpuInfo;

  /// No description provided for @gpuChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the graphics card…'**
  String get gpuChecking;

  /// No description provided for @speedTestButton.
  ///
  /// In en, this message translates to:
  /// **'Test the speed'**
  String get speedTestButton;

  /// No description provided for @speedTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Graphics card or processor'**
  String get speedTestTitle;

  /// No description provided for @speedTestNeedsModels.
  ///
  /// In en, this message translates to:
  /// **'The test needs these models: {models}. Download them in Settings → Models.'**
  String speedTestNeedsModels(String models);

  /// No description provided for @speedTestRunning.
  ///
  /// In en, this message translates to:
  /// **'Timing a test page on the {what}… (about a minute)'**
  String speedTestRunning(String what);

  /// No description provided for @speedTestOnCpu.
  ///
  /// In en, this message translates to:
  /// **'processor'**
  String get speedTestOnCpu;

  /// No description provided for @speedTestOnGpu.
  ///
  /// In en, this message translates to:
  /// **'graphics card'**
  String get speedTestOnGpu;

  /// No description provided for @speedSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String speedSeconds(String n);

  /// No description provided for @speedTestCpu.
  ///
  /// In en, this message translates to:
  /// **'Processor: {time} per page'**
  String speedTestCpu(String time);

  /// No description provided for @speedTestGpu.
  ///
  /// In en, this message translates to:
  /// **'Graphics card: {time} per page'**
  String speedTestGpu(String time);

  /// No description provided for @speedTestCpuFailed.
  ///
  /// In en, this message translates to:
  /// **'Processor: error ({reason})'**
  String speedTestCpuFailed(String reason);

  /// No description provided for @speedTestGpuFailed.
  ///
  /// In en, this message translates to:
  /// **'Graphics card: failed ({reason})'**
  String speedTestGpuFailed(String reason);

  /// No description provided for @speedTestGpuFaster.
  ///
  /// In en, this message translates to:
  /// **'The graphics card is faster: it is better to use it.'**
  String get speedTestGpuFaster;

  /// No description provided for @speedTestCpuBetter.
  ///
  /// In en, this message translates to:
  /// **'The processor is as fast or faster: there is no need to switch the graphics card on.'**
  String get speedTestCpuBetter;

  /// No description provided for @speedTestSmallGain.
  ///
  /// In en, this message translates to:
  /// **'The graphics card is faster by only {percent} %: too little to be worth it, the processor is enough.'**
  String speedTestSmallGain(String percent);

  /// No description provided for @speedTestGpuFailedVerdict.
  ///
  /// In en, this message translates to:
  /// **'These models do not run properly on this graphics card: the program will use the processor.'**
  String get speedTestGpuFailedVerdict;

  /// No description provided for @speedTestReport.
  ///
  /// In en, this message translates to:
  /// **'A report for the developer is saved: {path}'**
  String speedTestReport(String path);

  /// No description provided for @speedTestUseGpu.
  ///
  /// In en, this message translates to:
  /// **'Use the graphics card'**
  String get speedTestUseGpu;

  /// No description provided for @speedTestKeepCpu.
  ///
  /// In en, this message translates to:
  /// **'Keep the processor'**
  String get speedTestKeepCpu;

  /// No description provided for @speedTestUseGpuAnyway.
  ///
  /// In en, this message translates to:
  /// **'Switch it on anyway'**
  String get speedTestUseGpuAnyway;

  /// No description provided for @speedTestLast.
  ///
  /// In en, this message translates to:
  /// **'Last test: processor {cpu}, graphics card {gpu} per page.'**
  String speedTestLast(String cpu, String gpu);

  /// No description provided for @speedTestLastFailed.
  ///
  /// In en, this message translates to:
  /// **'Last test: the graphics card failed; the processor is used.'**
  String get speedTestLastFailed;

  /// No description provided for @gpuFallback.
  ///
  /// In en, this message translates to:
  /// **'The graphics card could not run: {models}. These steps go on on the processor; the translation continues. This is remembered: next time they start on the processor (Settings → General).'**
  String gpuFallback(String models);

  /// No description provided for @gpuFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'If this happens again, switch the graphics card off. To help fix it, build a bug report and send it to the developer.'**
  String get gpuFallbackHint;

  /// No description provided for @speedTestPartial.
  ///
  /// In en, this message translates to:
  /// **'These steps do not run on this graphics card and stay on the processor (already counted in its time): {models}.'**
  String speedTestPartial(String models);

  /// No description provided for @gpuCpuModelsNote.
  ///
  /// In en, this message translates to:
  /// **'Do not run on this graphics card, so they run on the processor: {models}.'**
  String gpuCpuModelsNote(String models);

  /// No description provided for @gpuCpuModelsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get gpuCpuModelsRetry;

  /// No description provided for @gpuFallbackOcr.
  ///
  /// In en, this message translates to:
  /// **'text recognition ({language})'**
  String gpuFallbackOcr(String language);

  /// No description provided for @gpuTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Switch the graphics card off'**
  String get gpuTurnOff;

  /// No description provided for @gpuFound.
  ///
  /// In en, this message translates to:
  /// **'Works: {cards}. The most powerful one is used.'**
  String gpuFound(String cards);

  /// No description provided for @gpuOnlyIntegrated.
  ///
  /// In en, this message translates to:
  /// **'This graphics is built into the processor: it is rarely faster than the processor itself.'**
  String get gpuOnlyIntegrated;

  /// No description provided for @gpuOldDrivers.
  ///
  /// In en, this message translates to:
  /// **'Old drivers: {cards}. If something goes wrong, update them from the maker\'s site.'**
  String gpuOldDrivers(String cards);

  /// No description provided for @gpuNotUsableTitle.
  ///
  /// In en, this message translates to:
  /// **'The graphics card cannot be used'**
  String get gpuNotUsableTitle;

  /// No description provided for @gpuNoCard.
  ///
  /// In en, this message translates to:
  /// **'No graphics card was found, only the standard Windows display driver ({names}).'**
  String gpuNoCard(String names);

  /// No description provided for @gpuDirectmlFailed.
  ///
  /// In en, this message translates to:
  /// **'A test run on the graphics card failed: {reason}'**
  String gpuDirectmlFailed(String reason);

  /// No description provided for @gpuNotUsableTail.
  ///
  /// In en, this message translates to:
  /// **'The work stays on the processor: it runs on any computer, only slower. If there is a graphics card, update its driver and try again.'**
  String get gpuNotUsableTail;

  /// No description provided for @testModeInfo.
  ///
  /// In en, this message translates to:
  /// **'While it is on, the steps of every processed page are saved: the boxes found, the recognized text, the request to the translator (without the key), the mask, the cleaning and the result. Clicks and edits (font, spacing) are not recorded. A short log is always kept.\n\nWhen something goes wrong:\n1. Turn test mode on.\n2. Do the same thing again.\n3. Press “Make a bug report”.\n4. Send the archive to the developer. Then test mode can be turned off.'**
  String get testModeInfo;

  /// No description provided for @bugReportInfo.
  ///
  /// In en, this message translates to:
  /// **'A report can be made without test mode too: it holds the log and the settings (without API keys). If test mode was on, it also holds the steps of the last run as text (recognized text and translation included), without pictures.'**
  String get bugReportInfo;

  /// No description provided for @extraContextInfo.
  ///
  /// In en, this message translates to:
  /// **'Written once and sent to the translator with every page. For example: “Characters: Maya (a girl), Timothy the cat. A comedy. Friends speak informally.” Helps with names, gender and forms of address.'**
  String get extraContextInfo;

  /// No description provided for @sendPageImageInfo.
  ///
  /// In en, this message translates to:
  /// **'The model sees the drawing and better understands who speaks and what happens. The picture of the whole page goes to the translator\'s server; requests cost more, and the model must understand images.'**
  String get sendPageImageInfo;

  /// No description provided for @textPrepInfo.
  ///
  /// In en, this message translates to:
  /// **'Pieces of the page with small text (lines thinner than 20 px) are enlarged before recognition; ordinary text is left alone. Without a neural network it is instant. Neural networks restore the shape of the letters but take longer (times on a slow laptop, for a screenshot page of small text): Simple about 1 s, Medium about 2 s (best on manga screenshots), High about 15 s (best overall, the default for comics); faster with the graphics card. For sites and games Plain ×1.5 is best. The program offers to download the model it needs.'**
  String get textPrepInfo;

  /// No description provided for @hdStrategyField.
  ///
  /// In en, this message translates to:
  /// **'How to clean large pages'**
  String get hdStrategyField;

  /// No description provided for @hdStrategyInfo.
  ///
  /// In en, this message translates to:
  /// **'The cleaning network is trained on small pictures.\n• Shrink (default): a copy of the page is shrunk to the limit and cleaned; only the cleaned places are put back on the full-size page. Fast.\n• In pieces: the parts around the text are cleaned at full size. More precise on large pages, but slower.\n• Full size: the whole page at once. The slowest, needs much memory.'**
  String get hdStrategyInfo;

  /// No description provided for @resizeLimitInfo.
  ///
  /// In en, this message translates to:
  /// **'The long side of the shrunk copy, in pixels. Larger is neater but slower. 960 is the original\'s value.'**
  String get resizeLimitInfo;

  /// No description provided for @cropMarginInfo.
  ///
  /// In en, this message translates to:
  /// **'How much background around the text goes into a piece: the network needs to see what to paint in.'**
  String get cropMarginInfo;

  /// No description provided for @cropTriggerInfo.
  ///
  /// In en, this message translates to:
  /// **'Pages smaller than this (long side) are cleaned whole, not in pieces.'**
  String get cropTriggerInfo;

  /// No description provided for @fontSizeInfo.
  ///
  /// In en, this message translates to:
  /// **'The program picks the font size itself so that the translation fits the bubble, within these limits. When even the smallest does not fit, the page may be enlarged (see “Enlarging”).'**
  String get fontSizeInfo;

  /// No description provided for @lineSpacingInfo.
  ///
  /// In en, this message translates to:
  /// **'1 is normal spacing, 1.5 is half as much again. A single bubble can have its own in “Text style”.'**
  String get lineSpacingInfo;

  /// No description provided for @outlineWidthInfo.
  ///
  /// In en, this message translates to:
  /// **'The outline is a light (or dark) edge around the letters so that the text reads over the drawing. The width is in pixels on each side of a letter.'**
  String get outlineWidthInfo;

  /// No description provided for @imageFormatInfo.
  ///
  /// In en, this message translates to:
  /// **'“Same as the source” keeps the format of the original. PNG loses nothing but files are larger; JPG and WEBP are smaller, with a slight loss of quality.'**
  String get imageFormatInfo;

  /// No description provided for @webtoonMode.
  ///
  /// In en, this message translates to:
  /// **'Webtoon'**
  String get webtoonMode;

  /// No description provided for @webtoonModeHelp.
  ///
  /// In en, this message translates to:
  /// **'All pages as one strip, as webtoons are read. A bubble cut by the edge between two pages is translated and cleaned whole. Wheel: scroll; Ctrl + wheel: zoom.'**
  String get webtoonModeHelp;

  /// No description provided for @mouseWheelStrip.
  ///
  /// In en, this message translates to:
  /// **'Webtoon: scroll the strip; with Ctrl: zoom'**
  String get mouseWheelStrip;

  /// No description provided for @exportStrip.
  ///
  /// In en, this message translates to:
  /// **'Webtoon strip'**
  String get exportStrip;

  /// No description provided for @exportStripPages.
  ///
  /// In en, this message translates to:
  /// **'Page by page'**
  String get exportStripPages;

  /// No description provided for @exportStripSingle.
  ///
  /// In en, this message translates to:
  /// **'One picture'**
  String get exportStripSingle;

  /// No description provided for @exportStripSlices.
  ///
  /// In en, this message translates to:
  /// **'Cut again'**
  String get exportStripSlices;

  /// No description provided for @exportSliceHeight.
  ///
  /// In en, this message translates to:
  /// **'Height of a part, px'**
  String get exportSliceHeight;

  /// No description provided for @exportStripHelp.
  ///
  /// In en, this message translates to:
  /// **'Each cut goes along an even row near this height (between panels), not through a bubble. Pictures taller than JPEG or WebP allow are saved as PNG.'**
  String get exportStripHelp;

  /// No description provided for @exportStripSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'All pages (of each chapter) one below the other in one picture. A very tall picture is saved as PNG.'**
  String get exportStripSingleHelp;

  /// No description provided for @secretShowSaved.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get secretShowSaved;

  /// No description provided for @secretHideSaved.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get secretHideSaved;

  /// No description provided for @secretCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get secretCopy;

  /// No description provided for @secretCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get secretCopied;

  /// No description provided for @formatPsd.
  ///
  /// In en, this message translates to:
  /// **'PSD (layers for Photoshop)'**
  String get formatPsd;

  /// No description provided for @exportPsdHelp.
  ///
  /// In en, this message translates to:
  /// **'Each page becomes a Photoshop file: the page as it was, the cleaned places, and the translation as editable text layers. Cleaned pages are saved as PNG.'**
  String get exportPsdHelp;

  /// No description provided for @exportPsdPagesOnly.
  ///
  /// In en, this message translates to:
  /// **'PSD files are saved page by page.'**
  String get exportPsdPagesOnly;

  /// No description provided for @psdImportForeign.
  ///
  /// In en, this message translates to:
  /// **'{name}: this PSD was not made by Comic Translate. Its visible picture layers were joined into the page, its text layers became editable text.'**
  String psdImportForeign(String name);

  /// No description provided for @psdImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{name}: some Photoshop features are not carried over ({features}); the page may look a little different.'**
  String psdImportUnsupported(String name, String features);

  /// No description provided for @psdFeatureSmartObjects.
  ///
  /// In en, this message translates to:
  /// **'smart objects'**
  String get psdFeatureSmartObjects;

  /// No description provided for @psdFeatureMasks.
  ///
  /// In en, this message translates to:
  /// **'masks'**
  String get psdFeatureMasks;

  /// No description provided for @psdFeatureClipping.
  ///
  /// In en, this message translates to:
  /// **'clipping masks'**
  String get psdFeatureClipping;

  /// No description provided for @psdFeatureAdjustments.
  ///
  /// In en, this message translates to:
  /// **'adjustment layers'**
  String get psdFeatureAdjustments;

  /// No description provided for @psdFeatureBlendModes.
  ///
  /// In en, this message translates to:
  /// **'blend modes'**
  String get psdFeatureBlendModes;

  /// No description provided for @psdFeatureOpacity.
  ///
  /// In en, this message translates to:
  /// **'layer opacity'**
  String get psdFeatureOpacity;

  /// No description provided for @splitWords.
  ///
  /// In en, this message translates to:
  /// **'Split glued words on this page or the selected pages (English): \"REALLIFE\" becomes \"REAL LIFE\"'**
  String get splitWords;

  /// No description provided for @splitWordsBlock.
  ///
  /// In en, this message translates to:
  /// **'Split glued words in this bubble (English)'**
  String get splitWordsBlock;

  /// No description provided for @splitWordsDone.
  ///
  /// In en, this message translates to:
  /// **'Words split: {count}. Undo with Ctrl+Z.'**
  String splitWordsDone(String count);

  /// No description provided for @splitWordsNone.
  ///
  /// In en, this message translates to:
  /// **'No glued words found (only English text is checked).'**
  String get splitWordsNone;

  /// No description provided for @splitWordsMissing.
  ///
  /// In en, this message translates to:
  /// **'The word list is missing from the program folder (data\\flutter_assets\\assets\\dict).'**
  String get splitWordsMissing;

  /// No description provided for @splitGluedWords.
  ///
  /// In en, this message translates to:
  /// **'Split glued English words after recognition'**
  String get splitGluedWords;

  /// No description provided for @splitGluedWordsInfo.
  ///
  /// In en, this message translates to:
  /// **'On very small text the recognizer often reads two words as one: \"REALLIFE\", \"MYINSTINCTS\". Words missing from the dictionary are split into dictionary words; letters are never changed. The same is done by the button in the text panel, for a page or one bubble.'**
  String get splitGluedWordsInfo;

  /// No description provided for @modelLines.
  ///
  /// In en, this message translates to:
  /// **'Text line finder (PP-OCR)'**
  String get modelLines;

  /// No description provided for @modelLinesInfo.
  ///
  /// In en, this message translates to:
  /// **'Finds lines of ordinary text for \"Sites and games\": screenshots, games, visual novels. Small and fast.'**
  String get modelLinesInfo;

  /// No description provided for @modelOpusEnRu.
  ///
  /// In en, this message translates to:
  /// **'Offline translation English → Russian (OPUS-MT)'**
  String get modelOpusEnRu;

  /// No description provided for @modelOpusRuEn.
  ///
  /// In en, this message translates to:
  /// **'Offline translation Russian → English (OPUS-MT)'**
  String get modelOpusRuEn;

  /// No description provided for @modelOpusInfo.
  ///
  /// In en, this message translates to:
  /// **'Translates on this computer without internet or keys (translator \"Offline (OPUS-MT)\"). About 0.4–0.7 s per bubble. Licence CC-BY 4.0, Helsinki-NLP.'**
  String get modelOpusInfo;

  /// No description provided for @modelW2xCunet.
  ///
  /// In en, this message translates to:
  /// **'waifu2x CUNet (level Simple)'**
  String get modelW2xCunet;

  /// No description provided for @modelW2xCunetInfo.
  ///
  /// In en, this message translates to:
  /// **'A fast neural network that enlarges small text twice before recognition. About 1 s per screenshot page. Licence MIT (nagadomi, waifu2x).'**
  String get modelW2xCunetInfo;

  /// No description provided for @modelW2xSwin.
  ///
  /// In en, this message translates to:
  /// **'waifu2x Swin-UNet (level Medium)'**
  String get modelW2xSwin;

  /// No description provided for @modelW2xSwinInfo.
  ///
  /// In en, this message translates to:
  /// **'Enlarges small text twice before recognition; the best in the experiment on manga screenshots. About 2 s per screenshot page. Licence MIT (nagadomi, waifu2x).'**
  String get modelW2xSwinInfo;

  /// No description provided for @modelFatality.
  ///
  /// In en, this message translates to:
  /// **'Fatality Comix (level High)'**
  String get modelFatality;

  /// No description provided for @modelFatalityInfo.
  ///
  /// In en, this message translates to:
  /// **'Removes print screening and enlarges small text; the best on reduced comic pages but slow (about 15 s per screenshot page). By Twittman, licence CC-BY-NC-SA 4.0: non-commercial use only. Converted to ONNX by this project.'**
  String get modelFatalityInfo;

  /// No description provided for @downloadNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download a model: the connection to the model site keeps breaking (4 tries). Check the internet and try again — the download continues where it stopped. If the site cannot be reached, download the files on another computer and add them with \"Import from disk…\" in \"Models\".'**
  String get downloadNetworkFailed;

  /// No description provided for @panelHide.
  ///
  /// In en, this message translates to:
  /// **'Hide: {name}'**
  String panelHide(String name);

  /// No description provided for @panelShow.
  ///
  /// In en, this message translates to:
  /// **'Show: {name}'**
  String panelShow(String name);

  /// No description provided for @panelPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get panelPages;

  /// No description provided for @panelTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get panelTools;

  /// No description provided for @pageGridOpen.
  ///
  /// In en, this message translates to:
  /// **'All pages over the whole window'**
  String get pageGridOpen;

  /// No description provided for @pageGridTitle.
  ///
  /// In en, this message translates to:
  /// **'All pages ({count})'**
  String pageGridTitle(String count);

  /// No description provided for @pageGridPicked.
  ///
  /// In en, this message translates to:
  /// **'Ticked: {count}'**
  String pageGridPicked(String count);

  /// No description provided for @pageGridPickAll.
  ///
  /// In en, this message translates to:
  /// **'Tick all'**
  String get pageGridPickAll;

  /// No description provided for @pageGridPickNone.
  ///
  /// In en, this message translates to:
  /// **'Untick'**
  String get pageGridPickNone;

  /// No description provided for @pageGridClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get pageGridClose;

  /// No description provided for @pageGridHint.
  ///
  /// In en, this message translates to:
  /// **'A click ticks a page for the steps (Detect, Recognize, Translate…), dragging moves it, a double click opens it. Esc closes.'**
  String get pageGridHint;

  /// No description provided for @pageGridLocked.
  ///
  /// In en, this message translates to:
  /// **'While pages are being translated they cannot be moved.'**
  String get pageGridLocked;

  /// No description provided for @contentKind.
  ///
  /// In en, this message translates to:
  /// **'What you translate'**
  String get contentKind;

  /// No description provided for @contentKindInfo.
  ///
  /// In en, this message translates to:
  /// **'Comics: the program looks for speech bubbles and captions. Sites and games: it looks for lines of ordinary text (screenshots, games, visual novels, phone screens).'**
  String get contentKindInfo;

  /// No description provided for @contentComics.
  ///
  /// In en, this message translates to:
  /// **'Comics'**
  String get contentComics;

  /// No description provided for @contentComicsHelp.
  ///
  /// In en, this message translates to:
  /// **'speech bubbles and captions'**
  String get contentComicsHelp;

  /// No description provided for @contentScreens.
  ///
  /// In en, this message translates to:
  /// **'Sites and games'**
  String get contentScreens;

  /// No description provided for @contentScreensHelp.
  ///
  /// In en, this message translates to:
  /// **'lines of ordinary text: screenshots, games, visual novels'**
  String get contentScreensHelp;

  /// No description provided for @detectorScreens.
  ///
  /// In en, this message translates to:
  /// **'Text detection (sites and games)'**
  String get detectorScreens;

  /// No description provided for @tinyTextTryHigh.
  ///
  /// In en, this message translates to:
  /// **'Very small text (lines of about {px} px): mistakes are likely. Turn on the High level in \"Settings → Recognition and cleaning → Preparing small text\" and recognize again, or take a larger screenshot.'**
  String tinyTextTryHigh(String px);

  /// No description provided for @tinyTextLarger.
  ///
  /// In en, this message translates to:
  /// **'Very small text (lines of about {px} px): mistakes are likely even after the neural network. Take a larger screenshot: zoom the page or window in first.'**
  String tinyTextLarger(String px);

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange with a chat AI'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ChatGPT, Gemini, Claude or any other. The program sends nothing itself: you carry the pictures and the instructions over, then paste the answer here.'**
  String get chatSubtitle;

  /// No description provided for @chatModeBoth.
  ///
  /// In en, this message translates to:
  /// **'Read and translate'**
  String get chatModeBoth;

  /// No description provided for @chatModeRecognize.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatModeRecognize;

  /// No description provided for @chatModeTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get chatModeTranslate;

  /// No description provided for @chatPieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces of text: {count}, pages: {pages}'**
  String chatPieces(int count, int pages);

  /// No description provided for @chatNoPieces.
  ///
  /// In en, this message translates to:
  /// **'Nothing to send: find the text first (and read it, to translate it).'**
  String get chatNoPieces;

  /// No description provided for @chatSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets'**
  String get chatSheets;

  /// No description provided for @chatGroupingSize.
  ///
  /// In en, this message translates to:
  /// **'as many as fit'**
  String get chatGroupingSize;

  /// No description provided for @chatGroupingCount.
  ///
  /// In en, this message translates to:
  /// **'a set number'**
  String get chatGroupingCount;

  /// No description provided for @chatPerSheet.
  ///
  /// In en, this message translates to:
  /// **'Pieces on a sheet'**
  String get chatPerSheet;

  /// No description provided for @chatSheetSize.
  ///
  /// In en, this message translates to:
  /// **'Sheet size'**
  String get chatSheetSize;

  /// No description provided for @chatSheetPerPage.
  ///
  /// In en, this message translates to:
  /// **'Each page on new sheets'**
  String get chatSheetPerPage;

  /// No description provided for @chatContextImage.
  ///
  /// In en, this message translates to:
  /// **'Picture of the page'**
  String get chatContextImage;

  /// No description provided for @chatContextOff.
  ///
  /// In en, this message translates to:
  /// **'do not send'**
  String get chatContextOff;

  /// No description provided for @chatContextSeparate.
  ///
  /// In en, this message translates to:
  /// **'as its own picture'**
  String get chatContextSeparate;

  /// No description provided for @chatContextOnSheet.
  ///
  /// In en, this message translates to:
  /// **'on the sheet'**
  String get chatContextOnSheet;

  /// No description provided for @chatGroups.
  ///
  /// In en, this message translates to:
  /// **'Own sheets'**
  String get chatGroups;

  /// No description provided for @chatGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1-4, 5-6'**
  String get chatGroupsHint;

  /// No description provided for @chatGroupsError.
  ///
  /// In en, this message translates to:
  /// **'Not understood: \"{part}\". Number the pieces from 1 to {count}, e.g. 1-4, 5-6.'**
  String chatGroupsError(String part, int count);

  /// No description provided for @chatStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Send to the chat'**
  String get chatStep1;

  /// No description provided for @chatStep1Help.
  ///
  /// In en, this message translates to:
  /// **'Copy the pictures and paste them into the chat (Ctrl+V), then copy the instructions, paste them too and send.'**
  String get chatStep1Help;

  /// No description provided for @chatStep1TextHelp.
  ///
  /// In en, this message translates to:
  /// **'Copy the instructions with the text, paste them into the chat (Ctrl+V) and send.'**
  String get chatStep1TextHelp;

  /// No description provided for @chatPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the pictures…'**
  String get chatPreparing;

  /// No description provided for @chatExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the files: {error}'**
  String chatExportFailed(String error);

  /// No description provided for @chatCopyPictures.
  ///
  /// In en, this message translates to:
  /// **'Copy the pictures ({count})'**
  String chatCopyPictures(int count);

  /// No description provided for @chatCopyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Copy the instructions'**
  String get chatCopyPrompt;

  /// No description provided for @chatCopyOne.
  ///
  /// In en, this message translates to:
  /// **'Copy only this picture'**
  String get chatCopyOne;

  /// No description provided for @chatShowPrompt.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the chat'**
  String get chatShowPrompt;

  /// No description provided for @chatOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open the folder'**
  String get chatOpenFolder;

  /// No description provided for @chatCopiedPictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures copied: {count}. Paste them into the chat: Ctrl+V.'**
  String chatCopiedPictures(int count);

  /// No description provided for @chatCopiedOne.
  ///
  /// In en, this message translates to:
  /// **'Copied: {name}. Paste it into the chat: Ctrl+V.'**
  String chatCopiedOne(String name);

  /// No description provided for @chatCopiedPrompt.
  ///
  /// In en, this message translates to:
  /// **'Instructions copied. Paste them into the chat: Ctrl+V.'**
  String get chatCopiedPrompt;

  /// No description provided for @chatCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy: another program holds the clipboard. Try again, or open the folder and drag the files into the chat.'**
  String get chatCopyFailed;

  /// No description provided for @chatStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Paste the chat\'s answer'**
  String get chatStep2;

  /// No description provided for @chatAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'[01-003] text'**
  String get chatAnswerHint;

  /// No description provided for @chatAnswerHintBoth.
  ///
  /// In en, this message translates to:
  /// **'[01-003] I\'M LATE! --> Я ОПОЗДАЛ!'**
  String get chatAnswerHintBoth;

  /// No description provided for @chatPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get chatPaste;

  /// No description provided for @chatFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Take from the txt files'**
  String get chatFromFiles;

  /// No description provided for @chatFromFilesHelp.
  ///
  /// In en, this message translates to:
  /// **'The answer can be written into ALL.txt or page_NN.txt in the exchange folder (Open the folder).'**
  String get chatFromFilesHelp;

  /// No description provided for @chatOpenTxt.
  ///
  /// In en, this message translates to:
  /// **'Open a txt file…'**
  String get chatOpenTxt;

  /// No description provided for @chatFound.
  ///
  /// In en, this message translates to:
  /// **'Answers found: {found} of {total}'**
  String chatFound(int found, int total);

  /// No description provided for @chatFromFilesNote.
  ///
  /// In en, this message translates to:
  /// **'From the files: {files}'**
  String chatFromFilesNote(String files);

  /// No description provided for @chatMissing.
  ///
  /// In en, this message translates to:
  /// **'No answer: {labels}'**
  String chatMissing(String labels);

  /// No description provided for @chatUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not sent (left out): {labels}'**
  String chatUnknown(String labels);

  /// No description provided for @chatNoArrow.
  ///
  /// In en, this message translates to:
  /// **'Without \"{sep}\" (all taken as the translation): {labels}'**
  String chatNoArrow(String sep, String labels);

  /// No description provided for @chatRepeated.
  ///
  /// In en, this message translates to:
  /// **'Answered twice (the first one counts): {labels}'**
  String chatRepeated(String labels);

  /// No description provided for @chatApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get chatApply;

  /// No description provided for @chatApplyContinue.
  ///
  /// In en, this message translates to:
  /// **'Apply and go on'**
  String get chatApplyContinue;

  /// No description provided for @chatApplied.
  ///
  /// In en, this message translates to:
  /// **'Pieces filled in: {count}'**
  String chatApplied(int count);

  /// No description provided for @chatLost.
  ///
  /// In en, this message translates to:
  /// **'Not found on the page any more (boxes removed?): {labels}'**
  String chatLost(String labels);

  /// No description provided for @chatButton.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatButton;

  /// No description provided for @chatButtonHelp.
  ///
  /// In en, this message translates to:
  /// **'Read and translate with ChatGPT, Gemini, Claude… by hand, for the selected pages'**
  String get chatButtonHelp;

  /// No description provided for @chatMenuBoth.
  ///
  /// In en, this message translates to:
  /// **'Read and translate through a chat…'**
  String get chatMenuBoth;

  /// No description provided for @chatMenuRecognize.
  ///
  /// In en, this message translates to:
  /// **'Read through a chat…'**
  String get chatMenuRecognize;

  /// No description provided for @chatMenuTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate through a chat…'**
  String get chatMenuTranslate;

  /// No description provided for @chatMenuFolder.
  ///
  /// In en, this message translates to:
  /// **'Answer for an earlier exchange…'**
  String get chatMenuFolder;

  /// No description provided for @chatNotExchangeFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder has no exchange.json: it is not an exchange folder.'**
  String get chatNotExchangeFolder;

  /// No description provided for @stageExchange.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the chat\'s answer'**
  String get stageExchange;

  /// No description provided for @chatSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'The \"Chat\" button on the main screen works with any engines. For \"Translate all\" to open the exchange by itself, choose \"By hand through a chat AI\" as the translator and/or in Tools → Reading.'**
  String get chatSettingsHelp;

  /// No description provided for @chatTogether.
  ///
  /// In en, this message translates to:
  /// **'Read and translate in one message'**
  String get chatTogether;

  /// No description provided for @chatTogetherHelp.
  ///
  /// In en, this message translates to:
  /// **'When both go through the chat. Off: first the reading, then a second round with the text to translate.'**
  String get chatTogetherHelp;

  /// No description provided for @chatPicturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get chatPicturesTitle;

  /// No description provided for @chatImages.
  ///
  /// In en, this message translates to:
  /// **'What to make'**
  String get chatImages;

  /// No description provided for @chatImagesSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets (several pieces on a picture)'**
  String get chatImagesSheets;

  /// No description provided for @chatImagesCrops.
  ///
  /// In en, this message translates to:
  /// **'A picture for each piece'**
  String get chatImagesCrops;

  /// No description provided for @chatImagesBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get chatImagesBoth;

  /// No description provided for @chatImagesInfo.
  ///
  /// In en, this message translates to:
  /// **'Sheets are easier to send: one picture holds many pieces, each with its label above it. Single pictures are named like the labels (01-003.png) and go in folders of a set number.'**
  String get chatImagesInfo;

  /// No description provided for @chatGroupingInfo.
  ///
  /// In en, this message translates to:
  /// **'As many as fit: a sheet is filled up to its size. A set number: the same number of pieces on each sheet. In the exchange window you can also make your own sheets, e.g. 1-4, 5-6.'**
  String get chatGroupingInfo;

  /// No description provided for @chatSheetSizePx.
  ///
  /// In en, this message translates to:
  /// **'Sheet size (pixels)'**
  String get chatSheetSizePx;

  /// No description provided for @chatSheetSizeInfo.
  ///
  /// In en, this message translates to:
  /// **'The longest side of a sheet. Chats shrink large pictures, and small letters stop being readable; 1600 works well for most chats.'**
  String get chatSheetSizeInfo;

  /// No description provided for @chatContextInfo.
  ///
  /// In en, this message translates to:
  /// **'A smaller picture of the whole page with the labelled boxes on it: helps the chat see who speaks and what happens. Also works when only translating.'**
  String get chatContextInfo;

  /// No description provided for @chatCropsPerFolder.
  ///
  /// In en, this message translates to:
  /// **'Pictures in a folder'**
  String get chatCropsPerFolder;

  /// No description provided for @chatAnswerTitle.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get chatAnswerTitle;

  /// No description provided for @chatTextFiles.
  ///
  /// In en, this message translates to:
  /// **'Text files'**
  String get chatTextFiles;

  /// No description provided for @chatTextFilesAll.
  ///
  /// In en, this message translates to:
  /// **'ALL.txt for all pages'**
  String get chatTextFilesAll;

  /// No description provided for @chatTextFilesPages.
  ///
  /// In en, this message translates to:
  /// **'A file for each page'**
  String get chatTextFilesPages;

  /// No description provided for @chatTextFilesBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get chatTextFilesBoth;

  /// No description provided for @chatTextFilesInfo.
  ///
  /// In en, this message translates to:
  /// **'Files with one line per label in the exchange folder. Paste the chat\'s answer into them and press \"Take from the txt files\": ALL.txt first, then the page files for what is still missing.'**
  String get chatTextFilesInfo;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Text for pieces without an answer'**
  String get chatPlaceholder;

  /// No description provided for @chatPlaceholderHelp.
  ///
  /// In en, this message translates to:
  /// **'Empty: such pieces stay as they are. Something like ⟦empty⟧ makes them easy to find.'**
  String get chatPlaceholderHelp;

  /// No description provided for @chatPromptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the chat'**
  String get chatPromptsTitle;

  /// No description provided for @chatPromptsHelp.
  ///
  /// In en, this message translates to:
  /// **'In English: chats follow it best. The program puts the languages, the labels, the text with labels and what you wrote about the comic in place of these words: {names}.'**
  String chatPromptsHelp(String names);

  /// No description provided for @chatPromptDefault.
  ///
  /// In en, this message translates to:
  /// **'Back to the built-in one'**
  String get chatPromptDefault;

  /// No description provided for @chatCopySelected.
  ///
  /// In en, this message translates to:
  /// **'Copy the picked ({count})'**
  String chatCopySelected(int count);

  /// No description provided for @chatSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Pick all'**
  String get chatSelectAll;

  /// No description provided for @chatSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Pick none'**
  String get chatSelectNone;

  /// No description provided for @chatGalleryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the pictures large'**
  String get chatGalleryOpen;

  /// No description provided for @chatGalleryPictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get chatGalleryPictures;

  /// No description provided for @chatGalleryPieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces and sheets'**
  String get chatGalleryPieces;

  /// No description provided for @chatPiecesHelp.
  ///
  /// In en, this message translates to:
  /// **'All the pieces in order. Click a piece to start a new sheet with it; click again to undo.'**
  String get chatPiecesHelp;

  /// No description provided for @chatGroupsNow.
  ///
  /// In en, this message translates to:
  /// **'Sheets: {groups}'**
  String chatGroupsNow(String groups);

  /// No description provided for @chatGroupsAuto.
  ///
  /// In en, this message translates to:
  /// **'as set above'**
  String get chatGroupsAuto;

  /// No description provided for @chatGroupsClear.
  ///
  /// In en, this message translates to:
  /// **'Remove all breaks'**
  String get chatGroupsClear;

  /// No description provided for @chatGroupsApply.
  ///
  /// In en, this message translates to:
  /// **'Use these sheets'**
  String get chatGroupsApply;

  /// No description provided for @chatNewSheetHere.
  ///
  /// In en, this message translates to:
  /// **'A new sheet from here'**
  String get chatNewSheetHere;

  /// No description provided for @chatGroupsNumbers.
  ///
  /// In en, this message translates to:
  /// **'1 = [{first}] … {count} = [{last}]'**
  String chatGroupsNumbers(String first, int count, String last);

  /// No description provided for @chatPromptChanged.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the chat (changed this time)'**
  String get chatPromptChanged;

  /// No description provided for @chatPromptUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo my changes'**
  String get chatPromptUndo;

  /// No description provided for @chatPromptTemplate.
  ///
  /// In en, this message translates to:
  /// **'Change for good…'**
  String get chatPromptTemplate;

  /// No description provided for @chatOneField.
  ///
  /// In en, this message translates to:
  /// **'One field'**
  String get chatOneField;

  /// No description provided for @chatTwoFields.
  ///
  /// In en, this message translates to:
  /// **'Two fields'**
  String get chatTwoFields;

  /// No description provided for @chatOriginalField.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get chatOriginalField;

  /// No description provided for @chatTranslationField.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get chatTranslationField;

  /// No description provided for @chatAnswerHintTranslation.
  ///
  /// In en, this message translates to:
  /// **'[01-003] translation'**
  String get chatAnswerHintTranslation;

  /// No description provided for @chatApart.
  ///
  /// In en, this message translates to:
  /// **'Original and translation as two lists'**
  String get chatApart;

  /// No description provided for @chatApartHelp.
  ///
  /// In en, this message translates to:
  /// **'When reading and translating in one message: the chat writes all the originals, then ===, then all the translations; the answer goes into two fields.'**
  String get chatApartHelp;

  /// No description provided for @chatPromptBothApart.
  ///
  /// In en, this message translates to:
  /// **'Read and translate, two lists'**
  String get chatPromptBothApart;

  /// No description provided for @chatSplitFiles.
  ///
  /// In en, this message translates to:
  /// **'Original and translation in separate files'**
  String get chatSplitFiles;

  /// No description provided for @chatSplitFilesHelp.
  ///
  /// In en, this message translates to:
  /// **'ALL_original.txt for the original text and ALL_translation.txt for the translation only (the same for the page files).'**
  String get chatSplitFilesHelp;

  /// No description provided for @chatSeparator.
  ///
  /// In en, this message translates to:
  /// **'Between the original and the translation'**
  String get chatSeparator;

  /// No description provided for @chatSeparatorHelp.
  ///
  /// In en, this message translates to:
  /// **'Any sign, --> by default. It goes into the instructions; the usual arrows are understood as well.'**
  String get chatSeparatorHelp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
