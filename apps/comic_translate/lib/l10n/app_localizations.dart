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
  /// **'Images (PNG, JPG, WEBP, BMP), comic archives (CBZ, ZIP, EPUB, CBR, CB7, CBT) and PDF'**
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

  /// No description provided for @closeAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close all pages? Translations that were not exported will be lost.'**
  String get closeAllConfirm;

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

  /// No description provided for @reasonTranslation.
  ///
  /// In en, this message translates to:
  /// **'translation failed: {message}'**
  String reasonTranslation(String message);

  /// No description provided for @reasonImage.
  ///
  /// In en, this message translates to:
  /// **'the image could not be read'**
  String get reasonImage;

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
  /// **'Stored in Windows secure storage, never in files or logs.'**
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
  /// **'Remove'**
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

  /// No description provided for @fontOther.
  ///
  /// In en, this message translates to:
  /// **'Font installed in Windows'**
  String get fontOther;

  /// No description provided for @fontOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Font name, e.g. Comic Sans MS'**
  String get fontOtherHint;

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
