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
  /// **'Images (PNG, JPG, WEBP, BMP), comic archives (CBZ, ZIP, EPUB, CBR, CB7, CBT), PDF and projects (.ctsproj)'**
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
  /// **'Large pages'**
  String get hdStrategy;

  /// No description provided for @hdResize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get hdResize;

  /// No description provided for @hdCrop.
  ///
  /// In en, this message translates to:
  /// **'In pieces'**
  String get hdCrop;

  /// No description provided for @hdOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original size'**
  String get hdOriginal;

  /// No description provided for @resizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Resize limit (px)'**
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

  /// No description provided for @upscaleSmallText.
  ///
  /// In en, this message translates to:
  /// **'Enlarge small text before reading'**
  String get upscaleSmallText;

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

  /// No description provided for @keyPages.
  ///
  /// In en, this message translates to:
  /// **'Previous / next page'**
  String get keyPages;

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

  /// No description provided for @keyBrushSize.
  ///
  /// In en, this message translates to:
  /// **'Smaller / larger brush'**
  String get keyBrushSize;

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
  /// **'Letter keys do nothing while you type in a text field. They work with any keyboard layout.'**
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
