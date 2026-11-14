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

  /// No description provided for @chatContinueReply.
  ///
  /// In en, this message translates to:
  /// **'Continue from the interruption'**
  String get chatContinueReply;

  /// No description provided for @chatContinuePrompt.
  ///
  /// In en, this message translates to:
  /// **'Continue from where the reply was interrupted without repeating the text already received.'**
  String get chatContinuePrompt;

  /// No description provided for @chatContinueHelp.
  ///
  /// In en, this message translates to:
  /// **'Includes the incomplete reply in the new request. Regular messages skip that fragment.'**
  String get chatContinueHelp;

  /// No description provided for @chatResendAttachments.
  ///
  /// In en, this message translates to:
  /// **'Resend attachments from chat history'**
  String get chatResendAttachments;

  /// No description provided for @chatResendAttachmentsNotice.
  ///
  /// In en, this message translates to:
  /// **'This request also includes attachments from earlier messages.'**
  String get chatResendAttachmentsNotice;

  /// No description provided for @trErrInterrupted.
  ///
  /// In en, this message translates to:
  /// **'the response stream closed without a completion signal'**
  String get trErrInterrupted;

  /// No description provided for @chatIncompleteResponse.
  ///
  /// In en, this message translates to:
  /// **'Incomplete response'**
  String get chatIncompleteResponse;

  /// No description provided for @translatorStream.
  ///
  /// In en, this message translates to:
  /// **'Stream response (SSE)'**
  String get translatorStream;

  /// No description provided for @translatorStreamHelp.
  ///
  /// In en, this message translates to:
  /// **'The test chat shows text as it arrives if the server supports OpenAI Chat Completions streaming.'**
  String get translatorStreamHelp;

  /// No description provided for @translatorStreamTemplateHelp.
  ///
  /// In en, this message translates to:
  /// **'Configure streaming in the template when a full Chat and translation HTTP request is active.'**
  String get translatorStreamTemplateHelp;

  /// No description provided for @httpEditorFormatsHelp.
  ///
  /// In en, this message translates to:
  /// **'For SSE chat responses, set format to sse and text to the path of a text chunk. For multipart, use Content-Type: multipart/form-data and put files in the file field of the JSON body.'**
  String get httpEditorFormatsHelp;

  /// No description provided for @httpEditorCheckResponse.
  ///
  /// In en, this message translates to:
  /// **'Check pasted SSE'**
  String get httpEditorCheckResponse;

  /// No description provided for @httpEditorSampleSse.
  ///
  /// In en, this message translates to:
  /// **'Paste the SSE events, including blank lines'**
  String get httpEditorSampleSse;

  /// No description provided for @httpEditorAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get httpEditorAttachFile;

  /// No description provided for @httpEditorRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get httpEditorRemoveFile;

  /// No description provided for @httpEditorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file exceeds 10 MB.'**
  String get httpEditorFileTooLarge;

  /// No description provided for @httpEditorFileNeedsTemplate.
  ///
  /// In en, this message translates to:
  /// **'An attachment requires a multipart template with a file field set to files.'**
  String get httpEditorFileNeedsTemplate;

  /// No description provided for @httpEditorFileConfirm.
  ///
  /// In en, this message translates to:
  /// **'The test sends the file {name}.'**
  String httpEditorFileConfirm(String name);

  /// No description provided for @translatorTestFileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send attachments?'**
  String get translatorTestFileConfirm;

  /// No description provided for @translatorTestFileNetwork.
  ///
  /// In en, this message translates to:
  /// **'The attachments and conversation will be sent to {destination}.'**
  String translatorTestFileNetwork(String destination);

  /// No description provided for @modelPromptPreset.
  ///
  /// In en, this message translates to:
  /// **'Prompt preset'**
  String get modelPromptPreset;

  /// No description provided for @modelPromptPresetStandard.
  ///
  /// In en, this message translates to:
  /// **'Built-in prompt'**
  String get modelPromptPresetStandard;

  /// No description provided for @modelPromptPresetAdd.
  ///
  /// In en, this message translates to:
  /// **'Create preset'**
  String get modelPromptPresetAdd;

  /// No description provided for @modelPromptPresetEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit preset'**
  String get modelPromptPresetEdit;

  /// No description provided for @modelPromptPresetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get modelPromptPresetNameRequired;

  /// No description provided for @modelPromptPresetNameTaken.
  ///
  /// In en, this message translates to:
  /// **'This name is already used.'**
  String get modelPromptPresetNameTaken;

  /// No description provided for @modelPromptPresetTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the instructions.'**
  String get modelPromptPresetTextRequired;

  /// No description provided for @modelPromptPresetHelp.
  ///
  /// In en, this message translates to:
  /// **'Selecting a preset copies its text into the editor. Save to apply the text and keep changes to the preset list.'**
  String get modelPromptPresetHelp;

  /// No description provided for @ownServerAiGuide.
  ///
  /// In en, this message translates to:
  /// **'Setup prompt for an AI assistant'**
  String get ownServerAiGuide;

  /// No description provided for @ownServerAiGuideCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy the full prompt'**
  String get ownServerAiGuideCopy;

  /// No description provided for @chatsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsWorkspace;

  /// No description provided for @chatUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled chat'**
  String get chatUntitled;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a message or attach an image.'**
  String get chatEmpty;

  /// No description provided for @chatNew.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNew;

  /// No description provided for @chatNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get chatNewFolder;

  /// No description provided for @chatThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat title'**
  String get chatThreadTitle;

  /// No description provided for @chatConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get chatConnection;

  /// No description provided for @chatCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get chatCreate;

  /// No description provided for @chatFolderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get chatFolderName;

  /// No description provided for @chatPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Chats and images in this folder will be encrypted. Keep the password. It cannot be recovered.'**
  String get chatPasswordHelp;

  /// No description provided for @chatPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get chatPassword;

  /// No description provided for @chatRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get chatRepeatPassword;

  /// No description provided for @chatPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords differ'**
  String get chatPasswordMismatch;

  /// No description provided for @chatRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get chatRequired;

  /// No description provided for @chatUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock folder'**
  String get chatUnlock;

  /// No description provided for @chatLock.
  ///
  /// In en, this message translates to:
  /// **'Lock folder now'**
  String get chatLock;

  /// No description provided for @chatProtect.
  ///
  /// In en, this message translates to:
  /// **'Set folder password'**
  String get chatProtect;

  /// No description provided for @chatUnlockError.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the folder. Check the password.'**
  String get chatUnlockError;

  /// No description provided for @chatStorageError.
  ///
  /// In en, this message translates to:
  /// **'Could not read or save the chat library. Check the folder and close any other instance using it.'**
  String get chatStorageError;

  /// No description provided for @chatStorageSettings.
  ///
  /// In en, this message translates to:
  /// **'Chat storage settings'**
  String get chatStorageSettings;

  /// No description provided for @chatStorageHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose where to keep the chat library. Changing the location opens the library in the selected folder. The previous library stays in its folder.'**
  String get chatStorageHelp;

  /// No description provided for @chatChooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get chatChooseLocation;

  /// No description provided for @chatRelock.
  ///
  /// In en, this message translates to:
  /// **'Ask for the folder password again'**
  String get chatRelock;

  /// No description provided for @chatRelockRestart.
  ///
  /// In en, this message translates to:
  /// **'After restarting the app'**
  String get chatRelockRestart;

  /// No description provided for @chatRelock30.
  ///
  /// In en, this message translates to:
  /// **'30 minutes after unlocking'**
  String get chatRelock30;

  /// No description provided for @chatRelock60.
  ///
  /// In en, this message translates to:
  /// **'60 minutes after unlocking'**
  String get chatRelock60;

  /// No description provided for @chatRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRename;

  /// No description provided for @chatPin.
  ///
  /// In en, this message translates to:
  /// **'Pin chat'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin chat'**
  String get chatUnpin;

  /// No description provided for @chatMove.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get chatMove;

  /// No description provided for @chatMovePrivacy.
  ///
  /// In en, this message translates to:
  /// **'After moving, the chat uses the protection settings of its destination.'**
  String get chatMovePrivacy;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get chatDelete;

  /// No description provided for @chatNoFolder.
  ///
  /// In en, this message translates to:
  /// **'Outside folders'**
  String get chatNoFolder;

  /// No description provided for @chatUnlockToMove.
  ///
  /// In en, this message translates to:
  /// **'Unlock a protected folder before moving a chat into it.'**
  String get chatUnlockToMove;

  /// No description provided for @chatAll.
  ///
  /// In en, this message translates to:
  /// **'All chats'**
  String get chatAll;

  /// No description provided for @chatChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a chat'**
  String get chatChoose;

  /// No description provided for @chatTitleSearch.
  ///
  /// In en, this message translates to:
  /// **'Search chat titles'**
  String get chatTitleSearch;

  /// No description provided for @chatMessageSearch.
  ///
  /// In en, this message translates to:
  /// **'Search messages in this chat'**
  String get chatMessageSearch;

  /// No description provided for @chatNoMessagesFound.
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get chatNoMessagesFound;

  /// No description provided for @chatConnectionMissing.
  ///
  /// In en, this message translates to:
  /// **'The chat\'s connection is unavailable.'**
  String get chatConnectionMissing;

  /// No description provided for @chatOwnServerOriginal.
  ///
  /// In en, this message translates to:
  /// **'Own server · Original connection'**
  String get chatOwnServerOriginal;

  /// No description provided for @chatOwnServerNamed.
  ///
  /// In en, this message translates to:
  /// **'Own server · {name}'**
  String chatOwnServerNamed(String name);

  /// No description provided for @httpEditorOffline.
  ///
  /// In en, this message translates to:
  /// **'Check pasted JSON'**
  String get httpEditorOffline;

  /// No description provided for @httpEditorStatus.
  ///
  /// In en, this message translates to:
  /// **'HTTP status of the sample'**
  String get httpEditorStatus;

  /// No description provided for @httpEditorStatusError.
  ///
  /// In en, this message translates to:
  /// **'Enter a status code from 100 to 599.'**
  String get httpEditorStatusError;

  /// No description provided for @httpEditorSampleJson.
  ///
  /// In en, this message translates to:
  /// **'Paste the response JSON'**
  String get httpEditorSampleJson;

  /// No description provided for @checkSample.
  ///
  /// In en, this message translates to:
  /// **'Check sample'**
  String get checkSample;

  /// No description provided for @fillPromptSample.
  ///
  /// In en, this message translates to:
  /// **'Use sample'**
  String get fillPromptSample;

  /// No description provided for @requestTemplateImport.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get requestTemplateImport;

  /// No description provided for @requestTemplateExport.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get requestTemplateExport;

  /// No description provided for @requestTemplateImported.
  ///
  /// In en, this message translates to:
  /// **'Template imported and selected.'**
  String get requestTemplateImported;

  /// No description provided for @requestTemplateTransferError.
  ///
  /// In en, this message translates to:
  /// **'Could not transfer the template. Check the JSON format, paths and credentials.'**
  String get requestTemplateTransferError;

  /// No description provided for @openRouterTemplateHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to OpenRouter translation, test chat and network OCR. Select “Profile settings” to restore the built-in requests.'**
  String get openRouterTemplateHelp;

  /// No description provided for @modelPromptEditor.
  ///
  /// In en, this message translates to:
  /// **'Prompt editor'**
  String get modelPromptEditor;

  /// No description provided for @modelPromptInstructions.
  ///
  /// In en, this message translates to:
  /// **'Custom instructions'**
  String get modelPromptInstructions;

  /// No description provided for @modelPromptHelp.
  ///
  /// In en, this message translates to:
  /// **'These instructions are added to the built-in prompt. Leave them empty to use the built-in prompt alone. Keep the response format so the app can match the text to its frames.'**
  String get modelPromptHelp;

  /// No description provided for @modelPromptExample.
  ///
  /// In en, this message translates to:
  /// **'Expected response for two sample frames'**
  String get modelPromptExample;

  /// No description provided for @modelPromptReply.
  ///
  /// In en, this message translates to:
  /// **'Paste a reply to check its format locally'**
  String get modelPromptReply;

  /// No description provided for @modelPromptValid.
  ///
  /// In en, this message translates to:
  /// **'Both sample frames matched.'**
  String get modelPromptValid;

  /// No description provided for @modelPromptInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The reply contains malformed JSON.'**
  String get modelPromptInvalidJson;

  /// No description provided for @modelPromptMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing or unusable response for {frames}.'**
  String modelPromptMissing(String frames);

  /// No description provided for @modelViaChat.
  ///
  /// In en, this message translates to:
  /// **'External chat'**
  String get modelViaChat;

  /// No description provided for @modelNotSelected.
  ///
  /// In en, this message translates to:
  /// **'model not selected'**
  String get modelNotSelected;

  /// No description provided for @modelForOcr.
  ///
  /// In en, this message translates to:
  /// **'OCR · {model}'**
  String modelForOcr(String model);

  /// No description provided for @modelForTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation · {model}'**
  String modelForTranslation(String model);

  /// No description provided for @modelForCombined.
  ///
  /// In en, this message translates to:
  /// **'OCR · {model} (with translation)'**
  String modelForCombined(String model);

  /// No description provided for @translationReview.
  ///
  /// In en, this message translates to:
  /// **'Review translation'**
  String get translationReview;

  /// No description provided for @translationReviewScope.
  ///
  /// In en, this message translates to:
  /// **'Pages without a chapter'**
  String get translationReviewScope;

  /// No description provided for @translationReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No flagged omissions'**
  String get translationReviewEmpty;

  /// No description provided for @translationReviewNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get translationReviewNext;

  /// No description provided for @translationReviewRetry.
  ///
  /// In en, this message translates to:
  /// **'Translate omissions'**
  String get translationReviewRetry;

  /// No description provided for @ownServerProfile.
  ///
  /// In en, this message translates to:
  /// **'Server profile'**
  String get ownServerProfile;

  /// No description provided for @requestTemplate.
  ///
  /// In en, this message translates to:
  /// **'Request template'**
  String get requestTemplate;

  /// No description provided for @httpEditorChat.
  ///
  /// In en, this message translates to:
  /// **'Chat and translation'**
  String get httpEditorChat;

  /// No description provided for @httpEditorModels.
  ///
  /// In en, this message translates to:
  /// **'Model list'**
  String get httpEditorModels;

  /// No description provided for @httpEditorOperations.
  ///
  /// In en, this message translates to:
  /// **'Full HTTP requests'**
  String get httpEditorOperations;

  /// No description provided for @httpEditorLegacy.
  ///
  /// In en, this message translates to:
  /// **'Compatibility settings'**
  String get httpEditorLegacy;

  /// No description provided for @httpEditorBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get httpEditorBalance;

  /// No description provided for @httpEditorRequest.
  ///
  /// In en, this message translates to:
  /// **'HTTP request'**
  String get httpEditorRequest;

  /// No description provided for @httpEditorResponse.
  ///
  /// In en, this message translates to:
  /// **'Response rules (JSON)'**
  String get httpEditorResponse;

  /// No description provided for @httpEditorSampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Test message'**
  String get httpEditorSampleLabel;

  /// No description provided for @httpEditorSampleMessage.
  ///
  /// In en, this message translates to:
  /// **'Reply with OK.'**
  String get httpEditorSampleMessage;

  /// No description provided for @httpEditorHelp.
  ///
  /// In en, this message translates to:
  /// **'The path is relative to the profile’s base address. Leave a blank line between headers and the JSON body. Use the variables shown in the example to insert the active key or chat data.'**
  String get httpEditorHelp;

  /// No description provided for @httpEditorTips.
  ///
  /// In en, this message translates to:
  /// **'By default, HTTP 2xx is accepted. Set statuses to a list of specific codes. On 401, check the authorization header. On 404, check the path. If HTTP succeeds but extraction fails, compare the response rules to the returned JSON.'**
  String get httpEditorTips;

  /// No description provided for @httpEditorPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get httpEditorPreview;

  /// No description provided for @httpEditorSend.
  ///
  /// In en, this message translates to:
  /// **'Send test'**
  String get httpEditorSend;

  /// No description provided for @httpEditorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send {request} using this profile? The test sends a real request and may use tokens or change data on the server.'**
  String httpEditorConfirm(String request);

  /// No description provided for @httpEditorExtracted.
  ///
  /// In en, this message translates to:
  /// **'Extracted result'**
  String get httpEditorExtracted;

  /// No description provided for @httpEditorResult.
  ///
  /// In en, this message translates to:
  /// **'HTTP test result'**
  String get httpEditorResult;

  /// No description provided for @httpEditorCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get httpEditorCopy;

  /// No description provided for @httpEditorApply.
  ///
  /// In en, this message translates to:
  /// **'Use this request'**
  String get httpEditorApply;

  /// No description provided for @requestTemplateNone.
  ///
  /// In en, this message translates to:
  /// **'Profile settings'**
  String get requestTemplateNone;

  /// No description provided for @requestTemplateHelp.
  ///
  /// In en, this message translates to:
  /// **'Blank template fields use the profile settings. Edits apply to every connection using this template.'**
  String get requestTemplateHelp;

  /// No description provided for @requestTemplateAdd.
  ///
  /// In en, this message translates to:
  /// **'Create request template'**
  String get requestTemplateAdd;

  /// No description provided for @requestTemplateEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit request template'**
  String get requestTemplateEdit;

  /// No description provided for @requestTemplateDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete request template'**
  String get requestTemplateDelete;

  /// No description provided for @requestTemplateDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”? Connections using it will return to their own request settings.'**
  String requestTemplateDeleteHelp(String name);

  /// No description provided for @requestTemplateEditorHelp.
  ///
  /// In en, this message translates to:
  /// **'A template can be shared by several profiles. Enter the address, model and API key in each profile. Blank fields inherit profile settings. The grey examples are hints.'**
  String get requestTemplateEditorHelp;

  /// No description provided for @requestTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get requestTemplateName;

  /// No description provided for @requestTemplateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a template name.'**
  String get requestTemplateNameRequired;

  /// No description provided for @requestTemplateNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A template with this name already exists.'**
  String get requestTemplateNameTaken;

  /// No description provided for @requestTemplateChatPath.
  ///
  /// In en, this message translates to:
  /// **'Chat path'**
  String get requestTemplateChatPath;

  /// No description provided for @requestTemplateModelsPath.
  ///
  /// In en, this message translates to:
  /// **'Model list path'**
  String get requestTemplateModelsPath;

  /// No description provided for @requestTemplateOptions.
  ///
  /// In en, this message translates to:
  /// **'Additional chat fields (JSON)'**
  String get requestTemplateOptions;

  /// No description provided for @requestTemplateStatusPath.
  ///
  /// In en, this message translates to:
  /// **'Key details path'**
  String get requestTemplateStatusPath;

  /// No description provided for @requestTemplateStatusPathHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional GET request. The program uses the selected profile’s API key.'**
  String get requestTemplateStatusPathHelp;

  /// No description provided for @requestTemplateStatusFields.
  ///
  /// In en, this message translates to:
  /// **'Key details response fields (JSON)'**
  String get requestTemplateStatusFields;

  /// No description provided for @requestTemplatePathError.
  ///
  /// In en, this message translates to:
  /// **'Enter paths relative to the profile’s API address, without a host or query parameters.'**
  String get requestTemplatePathError;

  /// No description provided for @requestTemplateOptionsError.
  ///
  /// In en, this message translates to:
  /// **'Enter a JSON object without model, messages or stream.'**
  String get requestTemplateOptionsError;

  /// No description provided for @requestTemplateCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Keep authorization fields and API keys in the profile’s API key field.'**
  String get requestTemplateCredentialsError;

  /// No description provided for @requestTemplateStatusError.
  ///
  /// In en, this message translates to:
  /// **'For key details, provide both a path and a JSON object that maps display labels to response fields.'**
  String get requestTemplateStatusError;

  /// No description provided for @requestTemplateStatusConsent.
  ///
  /// In en, this message translates to:
  /// **'Send the saved API key to {host} to request its details.'**
  String requestTemplateStatusConsent(String host);

  /// No description provided for @ownServerOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original connection'**
  String get ownServerOriginal;

  /// No description provided for @ownServerKeyActive.
  ///
  /// In en, this message translates to:
  /// **'Active API key'**
  String get ownServerKeyActive;

  /// No description provided for @ownServerKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'First key'**
  String get ownServerKeyFirst;

  /// No description provided for @ownServerKeyNumber.
  ///
  /// In en, this message translates to:
  /// **'Key {number}'**
  String ownServerKeyNumber(int number);

  /// No description provided for @ownServerKeyNone.
  ///
  /// In en, this message translates to:
  /// **'Without a key'**
  String get ownServerKeyNone;

  /// No description provided for @ownServerKeyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add API key'**
  String get ownServerKeyAdd;

  /// No description provided for @ownServerKeyEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit key note'**
  String get ownServerKeyEditNote;

  /// No description provided for @ownServerKeyValue.
  ///
  /// In en, this message translates to:
  /// **'New API key'**
  String get ownServerKeyValue;

  /// No description provided for @ownServerKeyNote.
  ///
  /// In en, this message translates to:
  /// **'Key note'**
  String get ownServerKeyNote;

  /// No description provided for @ownServerKeyNoteHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. A label to help identify this key.'**
  String get ownServerKeyNoteHelp;

  /// No description provided for @ownServerKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key.'**
  String get ownServerKeyRequired;

  /// No description provided for @ownServerKeyNoteSecret.
  ///
  /// In en, this message translates to:
  /// **'Enter the key in the API key field. Use the note to describe it.'**
  String get ownServerKeyNoteSecret;

  /// No description provided for @ownServerKeySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the key or note.'**
  String get ownServerKeySaveFailed;

  /// No description provided for @ownServerKeyRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The selected key and its note will be removed from this app. You can choose another saved key manually.'**
  String get ownServerKeyRemoveBody;

  /// No description provided for @ownServerKeysSecureHelp.
  ///
  /// In en, this message translates to:
  /// **'Key values are stored in Windows secure storage. Requests use the key selected below.'**
  String get ownServerKeysSecureHelp;

  /// No description provided for @ownServerLoadModels.
  ///
  /// In en, this message translates to:
  /// **'Load models'**
  String get ownServerLoadModels;

  /// No description provided for @ownServerModelsNeedUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid API base URL and relative models path in the settings.'**
  String get ownServerModelsNeedUrl;

  /// No description provided for @ownServerModelsHelp.
  ///
  /// In en, this message translates to:
  /// **'Load the model list from {host} using the saved API key, if present.'**
  String ownServerModelsHelp(String host);

  /// No description provided for @ownServerSetupGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'How to connect your own server'**
  String get ownServerSetupGuideTitle;

  /// No description provided for @ownServerCopyGuide.
  ///
  /// In en, this message translates to:
  /// **'Copy instructions'**
  String get ownServerCopyGuide;

  /// No description provided for @ownServerGuideCopied.
  ///
  /// In en, this message translates to:
  /// **'Instructions copied'**
  String get ownServerGuideCopied;

  /// No description provided for @ownServerSetupGuide.
  ///
  /// In en, this message translates to:
  /// **'1. In Settings → Translator → Own server, add a profile with + and name it.\n2. Enter the base URL from your provider’s documentation. The app appends /chat/completions and /models to it. Include /v1 only if it is part of that base URL. For example, RelayModels documents https://api.relaymodels.com/v1. Use HTTP for localhost or your LAN only if the server calls for it.\n3. Save the API key in the API key field. Local servers can often work without a key. Press Load models to pick a model ID, or type it. Leave Model blank if your server can pick its own default.\n4. Send a short message in Test chat. Open Logs to see the request, HTTP status and response. Review any message text before sharing the logs. Share the service documentation and the redacted report when asking for help. Keep your key in the API key field.\n5. In More settings, you can change the relative endpoint paths and add or omit JSON fields. The expected response uses choices[].message.content for chat and data[].id for the model list.'**
  String get ownServerSetupGuide;

  /// No description provided for @ownServerOcrConnection.
  ///
  /// In en, this message translates to:
  /// **'Server connection for recognition'**
  String get ownServerOcrConnection;

  /// No description provided for @ownServerOcrSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name or address'**
  String get ownServerOcrSearch;

  /// No description provided for @ownServerOcrManual.
  ///
  /// In en, this message translates to:
  /// **'Separate address (previous settings)'**
  String get ownServerOcrManual;

  /// No description provided for @ownServerOcrMissing.
  ///
  /// In en, this message translates to:
  /// **'Profile deleted. Select another connection.'**
  String get ownServerOcrMissing;

  /// No description provided for @ownServerOcrConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Profiles are shared with Translator. Choose the recognition connection and vision model here.'**
  String get ownServerOcrConnectionHelp;

  /// No description provided for @ownServerOcrSharedSettings.
  ///
  /// In en, this message translates to:
  /// **'Shared connection settings'**
  String get ownServerOcrSharedSettings;

  /// No description provided for @ownServerOcrSharedSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Changes to the address, active key or template also apply in Translator when it uses this profile.'**
  String get ownServerOcrSharedSettingsHelp;

  /// No description provided for @revokeNetworkInfo.
  ///
  /// In en, this message translates to:
  /// **'Remove this app’s saved permission for the server. The app will ask again before sending data. The API key stays saved.'**
  String get revokeNetworkInfo;

  /// No description provided for @translatorTestDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get translatorTestDiagnostics;

  /// No description provided for @translatorTestDiagnosticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Latest attempt in this chat. Authentication headers and image data are hidden. Check the message text before sharing.'**
  String get translatorTestDiagnosticsHelp;

  /// No description provided for @translatorTestDiagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Send a message to see the request and the server response.'**
  String get translatorTestDiagnosticsEmpty;

  /// No description provided for @translatorTestRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get translatorTestRequest;

  /// No description provided for @translatorTestResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get translatorTestResponse;

  /// No description provided for @translatorTestCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy logs'**
  String get translatorTestCopyDiagnostics;

  /// No description provided for @ownServerModelsDialogHelp.
  ///
  /// In en, this message translates to:
  /// **'The list comes from {host}. The saved key is used if present. Some servers report model IDs only, without capabilities or prices.'**
  String ownServerModelsDialogHelp(String host);

  /// No description provided for @ownServerModelsConsent.
  ///
  /// In en, this message translates to:
  /// **'Send the saved API key to {host} to load its model list?'**
  String ownServerModelsConsent(String host);

  /// No description provided for @ownServerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a connection'**
  String get ownServerAdd;

  /// No description provided for @ownServerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename connection'**
  String get ownServerRename;

  /// No description provided for @ownServerName.
  ///
  /// In en, this message translates to:
  /// **'Connection name'**
  String get ownServerName;

  /// No description provided for @ownServerNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A connection with this name already exists.'**
  String get ownServerNameTaken;

  /// No description provided for @ownServerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name, address or model'**
  String get ownServerSearch;

  /// No description provided for @ownServerSortAdded.
  ///
  /// In en, this message translates to:
  /// **'By addition order'**
  String get ownServerSortAdded;

  /// No description provided for @ownServerSortName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get ownServerSortName;

  /// No description provided for @ownServerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching connections'**
  String get ownServerNoMatches;

  /// No description provided for @ownServerRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this connection?'**
  String get ownServerRemoveTitle;

  /// No description provided for @ownServerRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'The profile, its settings and all its saved keys and notes will be deleted.'**
  String get ownServerRemoveBody;

  /// No description provided for @translatorTestChat.
  ///
  /// In en, this message translates to:
  /// **'Test chat'**
  String get translatorTestChat;

  /// No description provided for @translatorTestHelp.
  ///
  /// In en, this message translates to:
  /// **'Send a short message to check the connection. The provider may charge for the request.'**
  String get translatorTestHelp;

  /// No description provided for @translatorTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get translatorTestMessage;

  /// No description provided for @translatorTestSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get translatorTestSend;

  /// No description provided for @translatorTestAttachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach image (Ctrl+V to paste)'**
  String get translatorTestAttachImage;

  /// No description provided for @translatorTestPastedImage.
  ///
  /// In en, this message translates to:
  /// **'Pasted image'**
  String get translatorTestPastedImage;

  /// No description provided for @translatorTestRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get translatorTestRemoveImage;

  /// No description provided for @translatorTestImageHint.
  ///
  /// In en, this message translates to:
  /// **'Leave the message empty to transcribe the image.'**
  String get translatorTestImageHint;

  /// No description provided for @translatorTestOcrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Transcribe the text in the image exactly as written.'**
  String get translatorTestOcrPrompt;

  /// No description provided for @translatorTestInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'Could not read the image. Use PNG, JPEG or WebP.'**
  String get translatorTestInvalidImage;

  /// No description provided for @translatorTestImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image exceeds 10 MB or 24 megapixels.'**
  String get translatorTestImageTooLarge;

  /// No description provided for @translatorTestImageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send the image?'**
  String get translatorTestImageConfirm;

  /// No description provided for @translatorTestImageNetwork.
  ///
  /// In en, this message translates to:
  /// **'The images and conversation will be sent to {destination}.'**
  String translatorTestImageNetwork(String destination);

  /// No description provided for @translatorTestNetwork.
  ///
  /// In en, this message translates to:
  /// **'The chat sends the conversation to {host} ({where}).'**
  String translatorTestNetwork(String host, String where);

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

  /// No description provided for @viewMask.
  ///
  /// In en, this message translates to:
  /// **'Mask'**
  String get viewMask;

  /// No description provided for @viewMaskHelp.
  ///
  /// In en, this message translates to:
  /// **'What will be cleaned: in red over the picture, without the translation. Bright red goes to the network, light red is only filled with plain background. Opens by itself with the brush, the eraser and \"Fit\"'**
  String get viewMaskHelp;

  /// No description provided for @maskOnly.
  ///
  /// In en, this message translates to:
  /// **'Mask only: white on black, without the picture (small holes and forgotten bits show)'**
  String get maskOnly;

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

  /// No description provided for @reportsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'What goes into a bug report: the log (which steps ran, how long they took, the file names of the pages, errors) and the settings. API keys are masked; there are no page pictures. Recognized and translated text is in it only while the test mode is on, plus up to 300 characters of an online translator\'s reply when that reply was broken. Reports stay on this computer and are never sent anywhere by themselves.'**
  String get reportsPrivacyNote;

  /// No description provided for @reportTotalPerPage.
  ///
  /// In en, this message translates to:
  /// **'total {time}'**
  String reportTotalPerPage(String time);

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String secondsShort(String value);

  /// No description provided for @minutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String minutesSeconds(String minutes, String seconds);

  /// No description provided for @stepDoneDetect.
  ///
  /// In en, this message translates to:
  /// **'Bubbles found: {count}'**
  String stepDoneDetect(String count);

  /// No description provided for @stepDoneRecognize.
  ///
  /// In en, this message translates to:
  /// **'Bubbles read: {count}'**
  String stepDoneRecognize(String count);

  /// No description provided for @stepDoneTranslate.
  ///
  /// In en, this message translates to:
  /// **'Bubbles translated: {count}'**
  String stepDoneTranslate(String count);

  /// No description provided for @stepDoneMask.
  ///
  /// In en, this message translates to:
  /// **'Mask ready'**
  String get stepDoneMask;

  /// No description provided for @stepDoneClean.
  ///
  /// In en, this message translates to:
  /// **'Cleaning done'**
  String get stepDoneClean;

  /// No description provided for @stepDoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'without text: {count}'**
  String stepDoneEmpty(String count);

  /// No description provided for @stepDoneTime.
  ///
  /// In en, this message translates to:
  /// **'{what} in {time}'**
  String stepDoneTime(String what, String time);

  /// No description provided for @stepDonePages.
  ///
  /// In en, this message translates to:
  /// **'{pages} pages, {time} per page on average'**
  String stepDonePages(String pages, String time);

  /// No description provided for @reportStepTimes.
  ///
  /// In en, this message translates to:
  /// **'Time of the steps, per page on average:'**
  String get reportStepTimes;

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

  /// No description provided for @emptyFramesTitle.
  ///
  /// In en, this message translates to:
  /// **'Frames without text: {count}'**
  String emptyFramesTitle(int count);

  /// No description provided for @emptyFramesBody.
  ///
  /// In en, this message translates to:
  /// **'These frames have no recognized text yet. Maybe they were left empty on purpose (a sound, a picture). Recognize them before translating, or translate without them? Empty frames are not sent to the translator.'**
  String get emptyFramesBody;

  /// No description provided for @emptyFramesRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember my choice (it can be changed in the settings, \"Translator\")'**
  String get emptyFramesRemember;

  /// No description provided for @emptyFramesRead.
  ///
  /// In en, this message translates to:
  /// **'Recognize them'**
  String get emptyFramesRead;

  /// No description provided for @emptyFramesSkip.
  ///
  /// In en, this message translates to:
  /// **'Translate without them'**
  String get emptyFramesSkip;

  /// No description provided for @emptyFrames.
  ///
  /// In en, this message translates to:
  /// **'Frames without text before translating'**
  String get emptyFrames;

  /// No description provided for @emptyFramesHelp.
  ///
  /// In en, this message translates to:
  /// **'What \"Translate\" does when frames on the page have no text yet.'**
  String get emptyFramesHelp;

  /// No description provided for @emptyFramesAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get emptyFramesAsk;

  /// No description provided for @emptyFramesAlwaysRead.
  ///
  /// In en, this message translates to:
  /// **'Recognize them'**
  String get emptyFramesAlwaysRead;

  /// No description provided for @emptyFramesAlwaysSkip.
  ///
  /// In en, this message translates to:
  /// **'Translate without them'**
  String get emptyFramesAlwaysSkip;

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

  /// No description provided for @missingKeyBodyReading.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sends pictures of the bubbles to {host}, which needs an API key. Check the selected connection in Settings → Recognition or save the key in Settings → Translator. You can also choose local recognition.'**
  String missingKeyBodyReading(String name, String host);

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
  /// **'the connection is not set up: check its address, model and request settings'**
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

  /// No description provided for @trErrCutOff.
  ///
  /// In en, this message translates to:
  /// **'the answer was cut off: the model ran out of \"Maximum answer length\" (translator settings → \"More settings\"). Raise it or lower \"Pages in one request\"; models that think first spend the length on thinking too'**
  String get trErrCutOff;

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

  /// No description provided for @archivePassword.
  ///
  /// In en, this message translates to:
  /// **'the archive is protected by a password: unpack it with 7-Zip or WinRAR and open the folder'**
  String get archivePassword;

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

  /// No description provided for @networkBodyReading.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" sends the pictures of the bubbles to {host} ({where}) to read their text.'**
  String networkBodyReading(String name, String host, String where);

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

  /// No description provided for @settingsOcr.
  ///
  /// In en, this message translates to:
  /// **'Recognition'**
  String get settingsOcr;

  /// No description provided for @settingsCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get settingsCleaning;

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

  /// No description provided for @sendsDataNoAddress.
  ///
  /// In en, this message translates to:
  /// **'No server address yet. The text will go to the server whose address you enter.'**
  String get sendsDataNoAddress;

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

  /// No description provided for @readLevel.
  ///
  /// In en, this message translates to:
  /// **'Recognition quality (English)'**
  String get readLevel;

  /// No description provided for @readLevelScreens.
  ///
  /// In en, this message translates to:
  /// **'Recognition quality for sites and games (English)'**
  String get readLevelScreens;

  /// No description provided for @readLevelSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple — as before'**
  String get readLevelSimple;

  /// No description provided for @readLevelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (default)'**
  String get readLevelMedium;

  /// No description provided for @readLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get readLevelHigh;

  /// No description provided for @readLevelUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get readLevelUltra;

  /// No description provided for @readLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'How many networks read each block of English text (times on a slow laptop without a graphics card, the reading of a page alone; finding the text and preparing small text come on top):\n• Simple — as before: PP-OCRv5. About 1 s.\n• Medium — PP-OCRv6 small reads too (21 MB, already there for Chinese and Japanese); of the two readings of a block, the one with more real English words is kept. About 2 s.\n• High — after Medium, the PaddleOCR-VL network reads again the blocks where either fast reader found a word missing from the dictionary (about half). Nearly Ultra, faster: about 7 s per such block, 30 s per page on average (about 1 min for a manga screenshot).\n• Ultra — PaddleOCR-VL reads every block: best of all on full comic pages. About 7 s per block, 1 min per page on average (up to 3 min).\nPaddleOCR-VL is a separate download (1.8 GB, Apache-2.0 licence) and takes about 2.5 GB of memory; the first block after starting takes 10–20 s longer, a huge block of a wall of text up to 2 min. Until it is there, High and Ultra work as Medium.\nOther languages are read as on Simple.'**
  String get readLevelInfo;

  /// No description provided for @inpainter.
  ///
  /// In en, this message translates to:
  /// **'Text removal'**
  String get inpainter;

  /// No description provided for @cleanLevel.
  ///
  /// In en, this message translates to:
  /// **'Text removal quality'**
  String get cleanLevel;

  /// No description provided for @cleanLevelSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple — as before'**
  String get cleanLevelSimple;

  /// No description provided for @cleanLevelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get cleanLevelMedium;

  /// No description provided for @cleanLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High (default)'**
  String get cleanLevelHigh;

  /// No description provided for @cleanLevelCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom combination'**
  String get cleanLevelCustom;

  /// No description provided for @cleanLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'How text is removed from the page (times on a slow laptop without a graphics card, per page on average):\n• Simple — as before: a mask by the algorithm with a margin around the letters, repainted by the AOT network. About 4 s.\n• Medium — the comic-text-detector network finds the letters themselves and AOT repaints only them: the drawing next to the text is hardly touched, 2–4 times fewer letter remains. About 6 s.\n• High — the same, repainted by LaMa: best on grey screentone and drawings. About 7 s, plus 8 s on the first run. Large pages take longer (up to 15–20 s).\nWhite bubbles are filled at once, without a network, on every level. comic-text-detector is a separate download (82 MB, GPL-3.0 licence); until it is there, the mask of Simple is used.'**
  String get cleanLevelInfo;

  /// No description provided for @colourLetters.
  ///
  /// In en, this message translates to:
  /// **'Find coloured letters over the drawing by their colour'**
  String get colourLetters;

  /// No description provided for @colourLettersInfo.
  ///
  /// In en, this message translates to:
  /// **'Medium and High: comic-text-detector sees coloured letters on plain background but often misses them over hatching or screentone. Then the colour of the letters it found is looked for in the whole text block, and the rest of the letters are removed too. It works only when almost all the found letters are of one bright colour and there is no such colour in the drawing around the text; black, white and grey text is not affected. Turn it off if a piece of the drawing of the same colour inside the text gets removed.'**
  String get colourLettersInfo;

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
  /// **'Brush: paint what to clean (B). Shift + click: a straight line from the last point'**
  String get toolBrush;

  /// No description provided for @toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser: remove parts of the mask (E). Shift + click: a straight line from the last point'**
  String get toolEraser;

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size ([ and ])'**
  String get brushSize;

  /// No description provided for @toolFitMask.
  ///
  /// In en, this message translates to:
  /// **'Fit to letters (G): a click on a red piece of the mask shrinks it around the letters. Shift + click picks several pieces for the \"Fit\" button'**
  String get toolFitMask;

  /// No description provided for @fitMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin around the letters'**
  String get fitMargin;

  /// No description provided for @toolPipette.
  ///
  /// In en, this message translates to:
  /// **'Mask pipette (I): a click on a letter adds its colour; the mask takes that colour inside the text boxes at once'**
  String get toolPipette;

  /// No description provided for @colourModeHelp.
  ///
  /// In en, this message translates to:
  /// **'The mask by the colour of the letters. The pipette looks in the selected box, else in all boxes of the page, else over the whole page (the choice is next to the colours). Auto: coloured letters over the drawing are looked for by the Mask step (as in the settings, Text removal). Pipette: click letters to add their colour to the mask. Off: no colour search'**
  String get colourModeHelp;

  /// No description provided for @colourAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get colourAuto;

  /// No description provided for @colourPick.
  ///
  /// In en, this message translates to:
  /// **'Pipette'**
  String get colourPick;

  /// No description provided for @colourOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get colourOff;

  /// No description provided for @pipetteHint.
  ///
  /// In en, this message translates to:
  /// **'Click a letter'**
  String get pipetteHint;

  /// No description provided for @pipetteColour.
  ///
  /// In en, this message translates to:
  /// **'{colour}: click to remove this colour'**
  String pipetteColour(String colour);

  /// No description provided for @pipetteTolerance.
  ///
  /// In en, this message translates to:
  /// **'Colour precision: to the right wider (the faint edges of the letters too), to the left the colour itself only. A drawing of another colour is never taken'**
  String get pipetteTolerance;

  /// No description provided for @pipetteWhereBlock.
  ///
  /// In en, this message translates to:
  /// **'box {n}'**
  String pipetteWhereBlock(int n);

  /// No description provided for @pipetteWhereBlocks.
  ///
  /// In en, this message translates to:
  /// **'boxes {list}'**
  String pipetteWhereBlocks(String list);

  /// No description provided for @pipetteWhereAll.
  ///
  /// In en, this message translates to:
  /// **'all boxes'**
  String get pipetteWhereAll;

  /// No description provided for @pipetteWherePage.
  ///
  /// In en, this message translates to:
  /// **'whole page'**
  String get pipetteWherePage;

  /// No description provided for @pipetteWhereLetters.
  ///
  /// In en, this message translates to:
  /// **'letters: {where}'**
  String pipetteWhereLetters(String where);

  /// No description provided for @pipetteWhereEverything.
  ///
  /// In en, this message translates to:
  /// **'everything: {where}'**
  String pipetteWhereEverything(String where);

  /// No description provided for @pipetteScopeLetters.
  ///
  /// In en, this message translates to:
  /// **'Letters in the boxes'**
  String get pipetteScopeLetters;

  /// No description provided for @pipetteScopeBoxes.
  ///
  /// In en, this message translates to:
  /// **'Everything in the boxes'**
  String get pipetteScopeBoxes;

  /// No description provided for @pipetteScopePage.
  ///
  /// In en, this message translates to:
  /// **'Whole page'**
  String get pipetteScopePage;

  /// No description provided for @pipetteScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'Where to look for the colour. Letters in the boxes: only pieces of the colour lying whole inside a box; the drawing of the same colour around a bubble runs off the box and is not taken. Everything in the boxes: all of the colour in a box (with a small margin). Whole page: everywhere. Without boxes, the whole page'**
  String get pipetteScopeHelp;

  /// No description provided for @fitAll.
  ///
  /// In en, this message translates to:
  /// **'Fit all'**
  String get fitAll;

  /// No description provided for @fitPicked.
  ///
  /// In en, this message translates to:
  /// **'Fit ({n})'**
  String fitPicked(int n);

  /// No description provided for @fitButtonHelp.
  ///
  /// In en, this message translates to:
  /// **'Fits the picked pieces of the mask to the letters. Shift + click on a piece picks it or unpicks it. With none picked: every piece of the mask on the page'**
  String get fitButtonHelp;

  /// No description provided for @fitNoPiece.
  ///
  /// In en, this message translates to:
  /// **'No mask here: click a red piece'**
  String get fitNoPiece;

  /// No description provided for @fitNoLetters.
  ///
  /// In en, this message translates to:
  /// **'No letters found (pieces: {n}); left as they were'**
  String fitNoLetters(int n);

  /// No description provided for @fitDone.
  ///
  /// In en, this message translates to:
  /// **'Pieces fitted: {n}'**
  String fitDone(int n);

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

  /// No description provided for @stepTranslateMore.
  ///
  /// In en, this message translates to:
  /// **'Read, translate or both'**
  String get stepTranslateMore;

  /// No description provided for @stepReadAndTranslate.
  ///
  /// In en, this message translates to:
  /// **'Read and translate'**
  String get stepReadAndTranslate;

  /// No description provided for @stepReadAndTranslateHelp.
  ///
  /// In en, this message translates to:
  /// **'Reads every box again with the selected OCR engine, then passes the text to the selected translator.'**
  String get stepReadAndTranslateHelp;

  /// No description provided for @stepReadAndTranslateTogether.
  ///
  /// In en, this message translates to:
  /// **'Read and translate in one request'**
  String get stepReadAndTranslateTogether;

  /// No description provided for @stepReadAndTranslateTogetherHelp.
  ///
  /// In en, this message translates to:
  /// **'The model by key reads every box again and translates it in the same requests.'**
  String get stepReadAndTranslateTogetherHelp;

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

  /// No description provided for @keyFitMask.
  ///
  /// In en, this message translates to:
  /// **'Fit the mask to the letters'**
  String get keyFitMask;

  /// No description provided for @keyPipette.
  ///
  /// In en, this message translates to:
  /// **'Mask pipette'**
  String get keyPipette;

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
  /// **'Key details'**
  String get keyStatusCheck;

  /// No description provided for @keyStatusRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh key details'**
  String get keyStatusRefresh;

  /// No description provided for @keyStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Asks {host} for the key name, its limit and what is left. Only the key is sent, and only when you press the button; the answer stays until the program closes.'**
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

  /// No description provided for @keyStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Key: {label}'**
  String keyStatusLabel(String label);

  /// No description provided for @priceHint.
  ///
  /// In en, this message translates to:
  /// **'Earlier requests of this model ({requests}): about {cost} for 10 bubbles (about a page).'**
  String priceHint(String requests, String cost);

  /// No description provided for @keyStatusFreeTier.
  ///
  /// In en, this message translates to:
  /// **'Free account: no credits were ever bought, so free models allow fewer requests a day.'**
  String get keyStatusFreeTier;

  /// No description provided for @keyStatusPaidTier.
  ///
  /// In en, this message translates to:
  /// **'Credits were bought for this account: free models allow more requests a day.'**
  String get keyStatusPaidTier;

  /// No description provided for @modelsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get modelsChoose;

  /// No description provided for @modelsChooseHelp.
  ///
  /// In en, this message translates to:
  /// **'The list of models from {host}; your key does not go along'**
  String modelsChooseHelp(String host);

  /// No description provided for @modelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models of {host}'**
  String modelsTitle(String host);

  /// No description provided for @modelsHelp.
  ///
  /// In en, this message translates to:
  /// **'The list comes from {host}; nothing of yours goes along (not the key either). Prices are per million tokens (a token is about 3–4 letters): for the request and for the answer. Free models allow a limited number of requests a day (see \"Key details\" in the translator settings).'**
  String modelsHelp(String host);

  /// No description provided for @modelsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search: name or id'**
  String get modelsSearch;

  /// No description provided for @modelsNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get modelsNewest;

  /// No description provided for @modelsCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest first'**
  String get modelsCheapest;

  /// No description provided for @modelsByName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get modelsByName;

  /// No description provided for @modelsByContext.
  ///
  /// In en, this message translates to:
  /// **'Longest context first'**
  String get modelsByContext;

  /// No description provided for @modelsFreeOnly.
  ///
  /// In en, this message translates to:
  /// **'Free only'**
  String get modelsFreeOnly;

  /// No description provided for @modelsVisionOnly.
  ///
  /// In en, this message translates to:
  /// **'Takes pictures'**
  String get modelsVisionOnly;

  /// No description provided for @modelsVisionHelp.
  ///
  /// In en, this message translates to:
  /// **'Needed when the page image goes to the translator (\"Send the page image\")'**
  String get modelsVisionHelp;

  /// No description provided for @modelsVisionUnknown.
  ///
  /// In en, this message translates to:
  /// **'The server does not tell which models take pictures: pick one by the service\'s documentation.'**
  String get modelsVisionUnknown;

  /// No description provided for @modelsCount.
  ///
  /// In en, this message translates to:
  /// **'Shown: {shown} of {total}'**
  String modelsCount(int shown, int total);

  /// No description provided for @modelsFree.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get modelsFree;

  /// No description provided for @modelsPrice.
  ///
  /// In en, this message translates to:
  /// **'request {prompt} · answer {completion} per million'**
  String modelsPrice(String prompt, String completion);

  /// No description provided for @modelsContext.
  ///
  /// In en, this message translates to:
  /// **'context {tokens}'**
  String modelsContext(String tokens);

  /// No description provided for @modelsVision.
  ///
  /// In en, this message translates to:
  /// **'takes pictures'**
  String get modelsVision;

  /// No description provided for @modelsNone.
  ///
  /// In en, this message translates to:
  /// **'No models like that'**
  String get modelsNone;

  /// No description provided for @modelsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get the list: {reason}'**
  String modelsFailed(String reason);

  /// No description provided for @modelsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get modelsRetry;

  /// No description provided for @modelsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Get the list again'**
  String get modelsRefresh;

  /// No description provided for @historyOpen.
  ///
  /// In en, this message translates to:
  /// **'Request history'**
  String get historyOpen;

  /// No description provided for @historyPage.
  ///
  /// In en, this message translates to:
  /// **'What the translator answered'**
  String get historyPage;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Translator history'**
  String get historyTitle;

  /// No description provided for @historyHelp.
  ///
  /// In en, this message translates to:
  /// **'The last {keep} requests to translators over the network (OpenRouter, own server): what went and what came back as it came. Kept only on this computer; the key never goes in, nor the pictures.'**
  String historyHelp(String keep);

  /// No description provided for @historyOnlyPage.
  ///
  /// In en, this message translates to:
  /// **'Only {page}'**
  String historyOnlyPage(String page);

  /// No description provided for @historyCount.
  ///
  /// In en, this message translates to:
  /// **'Shown: {shown} of {total}'**
  String historyCount(int shown, int total);

  /// No description provided for @historyNone.
  ///
  /// In en, this message translates to:
  /// **'No requests yet. They appear here after a translation through OpenRouter or your own server.'**
  String get historyNone;

  /// No description provided for @historyNoneForPage.
  ///
  /// In en, this message translates to:
  /// **'No requests for this page. Turn the filter off to see all.'**
  String get historyNoneForPage;

  /// No description provided for @historyOk.
  ///
  /// In en, this message translates to:
  /// **'Bubbles translated: {count}'**
  String historyOk(int count);

  /// No description provided for @historyMissing.
  ///
  /// In en, this message translates to:
  /// **'Translated {got} of {total}: the answer has nothing for some bubbles'**
  String historyMissing(int got, int total);

  /// No description provided for @historyFailed.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String historyFailed(String error);

  /// No description provided for @historySeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String historySeconds(String seconds);

  /// No description provided for @historyImage.
  ///
  /// In en, this message translates to:
  /// **'with the page image'**
  String get historyImage;

  /// No description provided for @historyTokens.
  ///
  /// In en, this message translates to:
  /// **'tokens: {input} in, {output} out'**
  String historyTokens(int input, int output);

  /// No description provided for @historyWarnings.
  ///
  /// In en, this message translates to:
  /// **'Found when reading the answer: {warnings}'**
  String historyWarnings(String warnings);

  /// No description provided for @historySent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get historySent;

  /// No description provided for @historyReply.
  ///
  /// In en, this message translates to:
  /// **'Answer (as it came)'**
  String get historyReply;

  /// No description provided for @historyNoReply.
  ///
  /// In en, this message translates to:
  /// **'(no answer)'**
  String get historyNoReply;

  /// No description provided for @historyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the history'**
  String get historyClear;

  /// No description provided for @historyClearAsk.
  ///
  /// In en, this message translates to:
  /// **'Clear the whole history of requests?'**
  String get historyClearAsk;

  /// No description provided for @historyCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get historyCopied;

  /// No description provided for @historyAgain.
  ///
  /// In en, this message translates to:
  /// **'the missing ones again'**
  String get historyAgain;

  /// No description provided for @untranslatedMark.
  ///
  /// In en, this message translates to:
  /// **'no translation'**
  String get untranslatedMark;

  /// No description provided for @untranslatedHelp.
  ///
  /// In en, this message translates to:
  /// **'The translator\'s answer had nothing for this bubble: it keeps its original lettering. Type a translation, or press \"Translate\" on the bubble.'**
  String get untranslatedHelp;

  /// No description provided for @reportUntranslated.
  ///
  /// In en, this message translates to:
  /// **'Bubbles without a translation (their lettering stays):'**
  String get reportUntranslated;

  /// No description provided for @reportUnread.
  ///
  /// In en, this message translates to:
  /// **'Bubbles the model left unread (they have no text; \"Recognize\" on the bubble reads it again):'**
  String get reportUnread;

  /// No description provided for @reportUntranslatedCount.
  ///
  /// In en, this message translates to:
  /// **'bubbles: {count}'**
  String reportUntranslatedCount(int count);

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
  /// **'Pages selected: {count}'**
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

  /// No description provided for @mousePickBubbles.
  ///
  /// In en, this message translates to:
  /// **'Ctrl / Shift + click on a bubble'**
  String get mousePickBubbles;

  /// No description provided for @keyPickBubbles.
  ///
  /// In en, this message translates to:
  /// **'Pick several bubbles (on the page and in the Text panel): the look, who speaks, the steps and delete go to all of them; the picked boxes are dragged together'**
  String get keyPickBubbles;

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
  /// **'Restores the drawing under the text more neatly, especially on grey screentone and under sound effects. Slower and larger than AOT. Used by the High text removal level (Settings → Tools → Text removal quality).'**
  String get modelLamaInfo;

  /// No description provided for @modelCtd.
  ///
  /// In en, this message translates to:
  /// **'Letters for text removal (comic-text-detector)'**
  String get modelCtd;

  /// No description provided for @modelCtdInfo.
  ///
  /// In en, this message translates to:
  /// **'Finds the letters themselves, so that text removal repaints them and not the drawing around them. Used by the Medium and High text removal levels. About 2 s per page. By dmMaze, licence GPL-3.0; file from EarthWL/hiyori-onnx.'**
  String get modelCtdInfo;

  /// No description provided for @modelVlm.
  ///
  /// In en, this message translates to:
  /// **'Slow accurate reader (PaddleOCR-VL 1.6)'**
  String get modelVlm;

  /// No description provided for @modelVlmInfo.
  ///
  /// In en, this message translates to:
  /// **'A picture-to-text network: reads an English block as a whole and makes the fewest mistakes. Needed by recognition quality High and Ultra. About 7 s per block on a slow laptop, about 2.5 GB of memory. By PaddlePaddle (Baidu), Apache-2.0 licence.'**
  String get modelVlmInfo;

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
  /// **'Chinese (and large Japanese text; second English reader)'**
  String get modelOcrChinese;

  /// No description provided for @modelOcrChineseInfo.
  ///
  /// In en, this message translates to:
  /// **'Reads Chinese text (PaddleOCR). For Japanese it is needed too, with manga-ocr: it reads large titles and captions. For English at recognition quality Medium and High it reads every block a second time.'**
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
  /// **'Neural networks that enlarge small text before recognition. Only the one chosen in \"Recognition → Preparing small text\" is needed.'**
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

  /// No description provided for @modelsLevel.
  ///
  /// In en, this message translates to:
  /// **'Download for a level'**
  String get modelsLevel;

  /// No description provided for @modelsLevelSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get modelsLevelSimple;

  /// No description provided for @modelsLevelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get modelsLevelMedium;

  /// No description provided for @modelsLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get modelsLevelHigh;

  /// No description provided for @modelsLevelUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get modelsLevelUltra;

  /// No description provided for @modelsLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Includes the models for the selected levels of recognition, small text preparation and cleaning, for comics and screens. The list and total size appear before the download. Set the levels in the Recognition and Cleaning sections.'**
  String get modelsLevelInfo;

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

  /// No description provided for @secretGetKey.
  ///
  /// In en, this message translates to:
  /// **'Get a key'**
  String get secretGetKey;

  /// No description provided for @pluginMoreSettings.
  ///
  /// In en, this message translates to:
  /// **'More settings'**
  String get pluginMoreSettings;

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

  /// No description provided for @checkLines.
  ///
  /// In en, this message translates to:
  /// **'Check the lines of text before recognition'**
  String get checkLines;

  /// No description provided for @checkLinesInfo.
  ///
  /// In en, this message translates to:
  /// **'Comics only. On dense text (a wall of text, text over a drawing, a screenshot of prose) the program sometimes takes several lines for one and reads only a word or two. A quick check finds such blocks, and the \"Text line finder (PP-OCR)\" network finds their lines again: about 1–7 s on a page where it is needed. Ordinary bubbles are not changed, nor are Japanese vertical columns. Usually keep it on. Turn it off if some page reads worse with the check than without it (compare \"Recognize\" with and without it, and tell the author), or if the pages are ordinary comics without dense text and every second counts.'**
  String get checkLinesInfo;

  /// No description provided for @contentSwitchedHint.
  ///
  /// In en, this message translates to:
  /// **'The boxes on this page were found in the previous mode. The new mode applies when the text is found again.'**
  String get contentSwitchedHint;

  /// No description provided for @findTextAgain.
  ///
  /// In en, this message translates to:
  /// **'Find text again'**
  String get findTextAgain;

  /// No description provided for @textPrepSeconds.
  ///
  /// In en, this message translates to:
  /// **'Network time per page'**
  String get textPrepSeconds;

  /// No description provided for @textPrepSecondsDefault.
  ///
  /// In en, this message translates to:
  /// **'1 min (default)'**
  String get textPrepSecondsDefault;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String minutesShort(String value);

  /// No description provided for @noTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noTimeLimit;

  /// No description provided for @textPrepSecondsInfo.
  ///
  /// In en, this message translates to:
  /// **'How long the network may enlarge small text on one page. It takes the smallest text first; what it has no time for is enlarged the plain way: at once, slightly lower quality. On a weak laptop \"High\" takes about 4 minutes per million pixels: a manga screenshot 20–60 s, a page covered in small text 10 minutes or more. When quality matters more than time (say, you go for a cup of tea), choose more or \"No limit\". On a graphics card the network does more in the same time.'**
  String get textPrepSecondsInfo;

  /// No description provided for @modelLines.
  ///
  /// In en, this message translates to:
  /// **'Text line finder (PP-OCR)'**
  String get modelLines;

  /// No description provided for @modelLinesInfo.
  ///
  /// In en, this message translates to:
  /// **'Finds lines of ordinary text for \"Sites and games\": screenshots, games, visual novels. In \"Comics\" it helps to read dense text (see \"Check the lines\"). Small and fast.'**
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
  /// **'Very small text (lines of about {px} px): mistakes are likely. Turn on the High level in \"Settings → Recognition → Preparing small text\" and recognize again, or take a larger screenshot.'**
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

  /// No description provided for @chatCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy the text'**
  String get chatCopyText;

  /// No description provided for @chatCopiedText.
  ///
  /// In en, this message translates to:
  /// **'Text copied (only the lines with labels). Paste it into the chat: Ctrl+V.'**
  String get chatCopiedText;

  /// No description provided for @chatPagesAll.
  ///
  /// In en, this message translates to:
  /// **'All pages ({count})'**
  String chatPagesAll(int count);

  /// No description provided for @chatPageOnly.
  ///
  /// In en, this message translates to:
  /// **'Page {page} ({count})'**
  String chatPageOnly(int page, int count);

  /// No description provided for @chatPicturePages.
  ///
  /// In en, this message translates to:
  /// **'p. {pages}'**
  String chatPicturePages(String pages);

  /// No description provided for @chatClipboardOffer.
  ///
  /// In en, this message translates to:
  /// **'The clipboard has a chat answer: {found} of {total}. Paste it?'**
  String chatClipboardOffer(int found, int total);

  /// No description provided for @chatClipboardPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get chatClipboardPaste;

  /// No description provided for @glossaryMenu.
  ///
  /// In en, this message translates to:
  /// **'Names and words…'**
  String get glossaryMenu;

  /// No description provided for @glossaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Names and words'**
  String get glossaryTitle;

  /// No description provided for @glossaryButton.
  ///
  /// In en, this message translates to:
  /// **'Glossary ({count})'**
  String glossaryButton(int count);

  /// No description provided for @glossaryHelp.
  ///
  /// In en, this message translates to:
  /// **'How to translate the names and words of this project. One line, one word: Kai --> Кай. Any other line is a note on the translation (for example: \"Leave senpai as it is\", \"The heroes are on first-name terms\"). Lines starting with # are your own remarks and go nowhere.\n\nThe glossary is kept in the project. It goes into the instructions for the chat (only the words in the text) and to translators over the network (OpenRouter and others); the offline translator does not use it. The chat may suggest new names: one button in the exchange window adds them.'**
  String get glossaryHelp;

  /// No description provided for @glossaryHint.
  ///
  /// In en, this message translates to:
  /// **'Kai --> Кай\nSenpai --> семпай\nThe heroes are on first-name terms.'**
  String get glossaryHint;

  /// No description provided for @glossaryCounts.
  ///
  /// In en, this message translates to:
  /// **'Words: {words}, notes: {notes}'**
  String glossaryCounts(int words, int notes);

  /// No description provided for @glossaryLoad.
  ///
  /// In en, this message translates to:
  /// **'Load from txt…'**
  String get glossaryLoad;

  /// No description provided for @glossarySave.
  ///
  /// In en, this message translates to:
  /// **'Save to txt…'**
  String get glossarySave;

  /// No description provided for @glossarySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String glossarySaved(String path);

  /// No description provided for @textExportMenu.
  ///
  /// In en, this message translates to:
  /// **'Export text…'**
  String get textExportMenu;

  /// No description provided for @textExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export text'**
  String get textExportTitle;

  /// No description provided for @textExportHelp.
  ///
  /// In en, this message translates to:
  /// **'The dialogues of the pages as plain text: the originals, the translations or both. Keep them, or attach them to a chat as context. The labels are the same as in the exchange with a chat (ALL.txt).'**
  String get textExportHelp;

  /// No description provided for @textExportAllPages.
  ///
  /// In en, this message translates to:
  /// **'Empty: all pages ({count})'**
  String textExportAllPages(String count);

  /// No description provided for @textExportSomePages.
  ///
  /// In en, this message translates to:
  /// **'Pages: {count}'**
  String textExportSomePages(String count);

  /// No description provided for @textExportWhat.
  ///
  /// In en, this message translates to:
  /// **'What:'**
  String get textExportWhat;

  /// No description provided for @textExportOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get textExportOriginal;

  /// No description provided for @textExportTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get textExportTranslation;

  /// No description provided for @textExportBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get textExportBoth;

  /// No description provided for @textExportTwoFiles.
  ///
  /// In en, this message translates to:
  /// **'Two files: …_original.txt and …_translation.txt (you will choose a folder).'**
  String get textExportTwoFiles;

  /// No description provided for @textExportLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels before the lines: [01-003]'**
  String get textExportLabels;

  /// No description provided for @textExportSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Who speaks: [m] [f] [n]'**
  String get textExportSpeakers;

  /// No description provided for @textExportHeadings.
  ///
  /// In en, this message translates to:
  /// **'Page headings'**
  String get textExportHeadings;

  /// No description provided for @textExportHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get textExportHeading;

  /// No description provided for @textExportHeadingHelp.
  ///
  /// In en, this message translates to:
  /// **'{number} is the number of the page, {name} the name of its file. For example: --- {number} ---'**
  String textExportHeadingHelp(String number, String name);

  /// No description provided for @textExportPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get textExportPage;

  /// No description provided for @textExportPreview.
  ///
  /// In en, this message translates to:
  /// **'How it looks'**
  String get textExportPreview;

  /// No description provided for @textExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'(no text)'**
  String get textExportEmpty;

  /// No description provided for @textExportCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get textExportCopy;

  /// No description provided for @textExportCopyShown.
  ///
  /// In en, this message translates to:
  /// **'Copy the shown one'**
  String get textExportCopyShown;

  /// No description provided for @textExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. Paste it with Ctrl+V.'**
  String get textExportCopied;

  /// No description provided for @textExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save…'**
  String get textExportSave;

  /// No description provided for @textExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved:\n{paths}'**
  String textExportSaved(String paths);

  /// No description provided for @textExportCopyRequest.
  ///
  /// In en, this message translates to:
  /// **'Copy with a request to translate'**
  String get textExportCopyRequest;

  /// No description provided for @textExportCopiedRequest.
  ///
  /// In en, this message translates to:
  /// **'Copied: a request to translate into {language} and the original with labels. Paste it into a chat: Ctrl+V. The chat\'s answer goes into \"Load text…\".'**
  String textExportCopiedRequest(String language);

  /// No description provided for @textImportMenu.
  ///
  /// In en, this message translates to:
  /// **'Load text…'**
  String get textImportMenu;

  /// No description provided for @textImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Load text'**
  String get textImportTitle;

  /// No description provided for @textImportHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste a chat\'s answer to the exported text, or open a txt file. Lines find their bubbles by the labels [02-003]; bubbles without an answer stay as they are. A label is the number of the page and of the bubble now: if pages were moved or frames removed after the export, check the list \"What changes\".'**
  String get textImportHelp;

  /// No description provided for @textImportTarget.
  ///
  /// In en, this message translates to:
  /// **'Into:'**
  String get textImportTarget;

  /// No description provided for @textImportToTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get textImportToTranslation;

  /// No description provided for @textImportToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get textImportToOriginal;

  /// No description provided for @textImportArrowHint.
  ///
  /// In en, this message translates to:
  /// **'A line \"original --> translation\" fills both the text and the translation.'**
  String get textImportArrowHint;

  /// No description provided for @textImportAnswer.
  ///
  /// In en, this message translates to:
  /// **'The chat\'s answer or the text of a file'**
  String get textImportAnswer;

  /// No description provided for @textImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste from the clipboard'**
  String get textImportPaste;

  /// No description provided for @textImportOpen.
  ///
  /// In en, this message translates to:
  /// **'Open txt…'**
  String get textImportOpen;

  /// No description provided for @textImportChanges.
  ///
  /// In en, this message translates to:
  /// **'What changes'**
  String get textImportChanges;

  /// No description provided for @textImportSummary.
  ///
  /// In en, this message translates to:
  /// **'Answers: {answered}. Bubbles to change: {changed}. Without an answer: {missing} (they stay as they are).'**
  String textImportSummary(String answered, String changed, String missing);

  /// No description provided for @textImportUnknown.
  ///
  /// In en, this message translates to:
  /// **'No such bubbles: {labels}'**
  String textImportUnknown(String labels);

  /// No description provided for @textImportNoLabels.
  ///
  /// In en, this message translates to:
  /// **'The text has no labels like [01-003]. Export the text with \"Labels before the lines\" and ask the chat to keep the labels.'**
  String get textImportNoLabels;

  /// No description provided for @textImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes: it is all as in the bubbles.'**
  String get textImportNothing;

  /// No description provided for @textImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Paste the text here: what changes will show up.'**
  String get textImportEmpty;

  /// No description provided for @textImportApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get textImportApply;

  /// No description provided for @textImportApplied.
  ///
  /// In en, this message translates to:
  /// **'Bubbles changed: {count}. Undo: Ctrl+Z.'**
  String textImportApplied(String count);

  /// No description provided for @findInsidePicked.
  ///
  /// In en, this message translates to:
  /// **'Find blocks inside each picked one'**
  String get findInsidePicked;

  /// No description provided for @keyCopyLook.
  ///
  /// In en, this message translates to:
  /// **'Copy the look of the selected bubble'**
  String get keyCopyLook;

  /// No description provided for @keyPasteLook.
  ///
  /// In en, this message translates to:
  /// **'Paste the look into the selected bubbles (the parts ticked in \"Apply to others…\")'**
  String get keyPasteLook;

  /// No description provided for @lookCopied.
  ///
  /// In en, this message translates to:
  /// **'The look of bubble {number} is copied. Ctrl+Shift+V puts it into the selected bubbles.'**
  String lookCopied(String number);

  /// No description provided for @lookNothingCopied.
  ///
  /// In en, this message translates to:
  /// **'Copy the look of a bubble first: Ctrl+Shift+C.'**
  String get lookNothingCopied;

  /// No description provided for @lookPasted.
  ///
  /// In en, this message translates to:
  /// **'Look pasted into {count} bubbles. Undo: Ctrl+Z.'**
  String lookPasted(String count);

  /// No description provided for @lookMixed.
  ///
  /// In en, this message translates to:
  /// **'differ'**
  String get lookMixed;

  /// No description provided for @mergePicked.
  ///
  /// In en, this message translates to:
  /// **'Merge into one bubble'**
  String get mergePicked;

  /// No description provided for @autoLookButton.
  ///
  /// In en, this message translates to:
  /// **'Auto…'**
  String get autoLookButton;

  /// No description provided for @autoLookMenu.
  ///
  /// In en, this message translates to:
  /// **'Auto look from the original…'**
  String get autoLookMenu;

  /// No description provided for @autoLookTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto look from the original'**
  String get autoLookTitle;

  /// No description provided for @autoLookHelp.
  ///
  /// In en, this message translates to:
  /// **'The program looks at the original letters: it picks the closest font, sets the size as in the original, and turns the colour, bold, italic and outline back to automatic, which follow the original (bold, italic and outline when \"Look as in the original\" is on in the settings). Bubbles whose original letters are not measured (very small text, or read through a chat without measuring) keep their font and size.'**
  String get autoLookHelp;

  /// No description provided for @autoLookColours.
  ///
  /// In en, this message translates to:
  /// **'Colour, bold, italic, outline from the original'**
  String get autoLookColours;

  /// No description provided for @autoLookEach.
  ///
  /// In en, this message translates to:
  /// **'Each bubble its own font'**
  String get autoLookEach;

  /// No description provided for @autoLookOne.
  ///
  /// In en, this message translates to:
  /// **'One font for all'**
  String get autoLookOne;

  /// No description provided for @autoLookThisBubble.
  ///
  /// In en, this message translates to:
  /// **'This bubble ({number})'**
  String autoLookThisBubble(String number);

  /// No description provided for @autoLookWorking.
  ///
  /// In en, this message translates to:
  /// **'Choosing the look…'**
  String get autoLookWorking;

  /// No description provided for @autoLookDone.
  ///
  /// In en, this message translates to:
  /// **'Look changed in {count} bubbles. Undo: Ctrl+Z.'**
  String autoLookDone(String count);

  /// No description provided for @autoLookUnmeasured.
  ///
  /// In en, this message translates to:
  /// **'Without measured original letters (font and size kept): {count}.'**
  String autoLookUnmeasured(String count);

  /// No description provided for @pickArea.
  ///
  /// In en, this message translates to:
  /// **'Pick every bubble inside the rectangle'**
  String get pickArea;

  /// No description provided for @mousePickArea.
  ///
  /// In en, this message translates to:
  /// **'Shift + drag over an empty place'**
  String get mousePickArea;

  /// No description provided for @pickAllBlocks.
  ///
  /// In en, this message translates to:
  /// **'Pick every bubble of the page'**
  String get pickAllBlocks;

  /// No description provided for @pickHint.
  ///
  /// In en, this message translates to:
  /// **'Several bubbles at once: Ctrl+click adds or removes a bubble, Shift+click takes all of them up to it (on the page and in this list).'**
  String get pickHint;

  /// No description provided for @pickedCount.
  ///
  /// In en, this message translates to:
  /// **'Bubbles picked: {count}'**
  String pickedCount(String count);

  /// No description provided for @pickedHelp.
  ///
  /// In en, this message translates to:
  /// **'Everything below changes in all the picked bubbles at once. The look shown is the one of bubble {number}.'**
  String pickedHelp(String number);

  /// No description provided for @recognizePicked.
  ///
  /// In en, this message translates to:
  /// **'Recognize the picked ones again'**
  String get recognizePicked;

  /// No description provided for @translatePicked.
  ///
  /// In en, this message translates to:
  /// **'Translate the picked ones again'**
  String get translatePicked;

  /// No description provided for @deletePicked.
  ///
  /// In en, this message translates to:
  /// **'Delete the picked boxes (Delete)'**
  String get deletePicked;

  /// No description provided for @unpick.
  ///
  /// In en, this message translates to:
  /// **'Drop the picks (Esc)'**
  String get unpick;

  /// No description provided for @lookApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to others…'**
  String get lookApply;

  /// No description provided for @lookApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'The look of bubble {number} for other bubbles'**
  String lookApplyTitle(String number);

  /// No description provided for @lookApplyWhat.
  ///
  /// In en, this message translates to:
  /// **'What goes'**
  String get lookApplyWhat;

  /// No description provided for @lookApplyWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get lookApplyWhere;

  /// No description provided for @lookApplyNote.
  ///
  /// In en, this message translates to:
  /// **'The text box, the turn by default and the styled words stay each bubble\'s own.'**
  String get lookApplyNote;

  /// No description provided for @lookScopePicked.
  ///
  /// In en, this message translates to:
  /// **'The picked bubbles ({count})'**
  String lookScopePicked(String count);

  /// No description provided for @lookScopePage.
  ///
  /// In en, this message translates to:
  /// **'All bubbles of this page ({count})'**
  String lookScopePage(String count);

  /// No description provided for @lookScopePickedPages.
  ///
  /// In en, this message translates to:
  /// **'All bubbles of the picked pages ({count})'**
  String lookScopePickedPages(String count);

  /// No description provided for @lookScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All bubbles of all pages ({count})'**
  String lookScopeAll(String count);

  /// No description provided for @lookApplyDone.
  ///
  /// In en, this message translates to:
  /// **'Look changed in {count} bubbles. Undo: Ctrl+Z (for each page).'**
  String lookApplyDone(String count);

  /// No description provided for @lookPartEmphasis.
  ///
  /// In en, this message translates to:
  /// **'Bold, italic, underline'**
  String get lookPartEmphasis;

  /// No description provided for @lookPartFit.
  ///
  /// In en, this message translates to:
  /// **'Hyphens and the bubble\'s shape'**
  String get lookPartFit;

  /// No description provided for @lookPartSize.
  ///
  /// In en, this message translates to:
  /// **'Size (own or as in the original)'**
  String get lookPartSize;

  /// No description provided for @textImportFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file: {error}'**
  String textImportFileError(String error);

  /// No description provided for @glossaryApply.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get glossaryApply;

  /// No description provided for @chatNewTerms.
  ///
  /// In en, this message translates to:
  /// **'The chat suggests for the glossary:'**
  String get chatNewTerms;

  /// No description provided for @chatNewTermsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to the glossary'**
  String get chatNewTermsAdd;

  /// No description provided for @chatNewTermsAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to the glossary: {count}'**
  String chatNewTermsAdded(int count);

  /// No description provided for @chatStyles.
  ///
  /// In en, this message translates to:
  /// **'Style of the translation:'**
  String get chatStyles;

  /// No description provided for @chatStylesOwn.
  ///
  /// In en, this message translates to:
  /// **'Own styles and instructions'**
  String get chatStylesOwn;

  /// No description provided for @styleNone.
  ///
  /// In en, this message translates to:
  /// **'No style'**
  String get styleNone;

  /// No description provided for @styleLiteral.
  ///
  /// In en, this message translates to:
  /// **'Close to the original'**
  String get styleLiteral;

  /// No description provided for @styleLively.
  ///
  /// In en, this message translates to:
  /// **'Lively, spoken'**
  String get styleLively;

  /// No description provided for @styleSoften.
  ///
  /// In en, this message translates to:
  /// **'Soften rude words'**
  String get styleSoften;

  /// No description provided for @styleKeepSwearing.
  ///
  /// In en, this message translates to:
  /// **'Rude words as strong'**
  String get styleKeepSwearing;

  /// No description provided for @styleHonorifics.
  ///
  /// In en, this message translates to:
  /// **'Keep -san/-kun'**
  String get styleHonorifics;

  /// No description provided for @styleOwn.
  ///
  /// In en, this message translates to:
  /// **'Own style'**
  String get styleOwn;

  /// No description provided for @chatStylesTitle.
  ///
  /// In en, this message translates to:
  /// **'Styles of translation'**
  String get chatStylesTitle;

  /// No description provided for @chatStylesHelp.
  ///
  /// In en, this message translates to:
  /// **'The chosen styles go into the instructions for the chat and to translators over the network (OpenRouter and others). An own style: the name is for the list, and what to ask is in English (chats follow it best).'**
  String get chatStylesHelp;

  /// No description provided for @chatOwnStyleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatOwnStyleName;

  /// No description provided for @chatOwnStyleText.
  ///
  /// In en, this message translates to:
  /// **'What to ask (in English)'**
  String get chatOwnStyleText;

  /// No description provided for @chatOwnStyleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a style of your own'**
  String get chatOwnStyleAdd;

  /// No description provided for @chatOwnStyleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the style'**
  String get chatOwnStyleDelete;

  /// No description provided for @chatSharedTexts.
  ///
  /// In en, this message translates to:
  /// **'One text for every mode'**
  String get chatSharedTexts;

  /// No description provided for @chatSharedTextsHelp.
  ///
  /// In en, this message translates to:
  /// **'What you wrote into the txt files stays when the mode changes: \"Recognize\", \"Translate\" and \"Recognize and translate\" work with the same files. Off: each mode gets fresh templates of its own.'**
  String get chatSharedTextsHelp;

  /// No description provided for @speakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Who speaks'**
  String get speakerLabel;

  /// No description provided for @speakerInfo.
  ///
  /// In en, this message translates to:
  /// **'Helps the translation pick the grammatical gender (in Russian, \"я пришёл\" or \"я пришла\"). The tag goes to the chat and to translators over the network (OpenRouter and others); the offline translator does not use it.\n\nIn the exchange txt files the tag stands after the label: [01-003] [f] … — it can be changed there too: [m] a man, [f] a woman, [n] no gender, [-] none.'**
  String get speakerInfo;

  /// No description provided for @speakerMale.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get speakerMale;

  /// No description provided for @speakerFemale.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get speakerFemale;

  /// No description provided for @speakerNeuter.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get speakerNeuter;

  /// No description provided for @speakerNoneTip.
  ///
  /// In en, this message translates to:
  /// **'Not told'**
  String get speakerNoneTip;

  /// No description provided for @speakerMaleTip.
  ///
  /// In en, this message translates to:
  /// **'A man'**
  String get speakerMaleTip;

  /// No description provided for @speakerFemaleTip.
  ///
  /// In en, this message translates to:
  /// **'A woman'**
  String get speakerFemaleTip;

  /// No description provided for @speakerNeuterTip.
  ///
  /// In en, this message translates to:
  /// **'No gender: a thing, a crowd, a narrator'**
  String get speakerNeuterTip;

  /// No description provided for @chatAnswerFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Offer the answer from the clipboard'**
  String get chatAnswerFromClipboard;

  /// No description provided for @chatAnswerFromClipboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Back in the exchange window with a chat answer (lines with labels) in the clipboard, the program offers to paste it.'**
  String get chatAnswerFromClipboardHelp;

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

  /// No description provided for @chatFromFilesInfoTranslate.
  ///
  /// In en, this message translates to:
  /// **'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text {separator} translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Translate\": add the translation after \"{separator}\" in ALL.txt or write it into ALL_translation.txt.'**
  String chatFromFilesInfoTranslate(String separator);

  /// No description provided for @chatFromFilesInfoRecognize.
  ///
  /// In en, this message translates to:
  /// **'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text {separator} translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Recognize\": write or correct the text from the picture, before \"{separator}\" in ALL.txt or in ALL_original.txt. A translation may come along too.'**
  String chatFromFilesInfoRecognize(String separator);

  /// No description provided for @chatFromFilesInfoBoth.
  ///
  /// In en, this message translates to:
  /// **'Takes the answer from the txt files of the exchange folder (Open the folder, below). The files are the same in every mode and show what the bubbles have now:\nALL.txt: [01-001] text {separator} translation\nALL_original.txt: the text alone, ALL_translation.txt: the translation alone; page_01.txt… the same by pages.\nChange any lines in any file and save it: what you changed goes into the bubble, lines left as they are change nothing. [f] after a label tells who speaks. You can also replace the whole of ALL.txt with the chat\'s answer.\n\n\"Recognize and translate\": both the text from the picture and the translation, in ALL.txt with \"{separator}\" between them, or apart in ALL_original.txt and ALL_translation.txt.'**
  String chatFromFilesInfoBoth(String separator);

  /// No description provided for @chatSheetPerPageOn.
  ///
  /// In en, this message translates to:
  /// **'\"Each page on a new sheet\" is on: the sheets show the bubbles of one page only.'**
  String get chatSheetPerPageOn;

  /// No description provided for @chatPromptAllPages.
  ///
  /// In en, this message translates to:
  /// **'The instructions still have the bubbles of all pages: they were changed by hand or come from an earlier exchange.'**
  String get chatPromptAllPages;

  /// No description provided for @chatUntranslated.
  ///
  /// In en, this message translates to:
  /// **'The chat seems to have left these untranslated: {labels}'**
  String chatUntranslated(String labels);

  /// No description provided for @chatUntranslatedAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get chatUntranslatedAsk;

  /// No description provided for @chatTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long for the bubble (the letters would be the smallest): {labels}'**
  String chatTooLong(String labels);

  /// No description provided for @chatAskShorter.
  ///
  /// In en, this message translates to:
  /// **'Ask for shorter ones ({count})'**
  String chatAskShorter(int count);

  /// No description provided for @chatCheckFit.
  ///
  /// In en, this message translates to:
  /// **'Check that translations fit'**
  String get chatCheckFit;

  /// No description provided for @chatCheckFitHelp.
  ///
  /// In en, this message translates to:
  /// **'After an answer is pasted, the app tries the translations in their bubbles and offers to ask the chat to shorten those too long.'**
  String get chatCheckFitHelp;

  /// No description provided for @chatPreset.
  ///
  /// In en, this message translates to:
  /// **'Instructions preset'**
  String get chatPreset;

  /// No description provided for @chatPresetStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get chatPresetStandard;

  /// No description provided for @chatPresetOwn.
  ///
  /// In en, this message translates to:
  /// **'Own (no name)'**
  String get chatPresetOwn;

  /// No description provided for @chatPresetSave.
  ///
  /// In en, this message translates to:
  /// **'Save as a preset…'**
  String get chatPresetSave;

  /// No description provided for @chatPresetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the preset'**
  String get chatPresetDelete;

  /// No description provided for @chatPresetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get chatPresetName;

  /// No description provided for @chatPresetNameHelp.
  ///
  /// In en, this message translates to:
  /// **'The same name replaces that preset.'**
  String get chatPresetNameHelp;

  /// No description provided for @chatAnswerMarks.
  ///
  /// In en, this message translates to:
  /// **'Take off around the answer'**
  String get chatAnswerMarks;

  /// No description provided for @chatAnswerMarksHelp.
  ///
  /// In en, this message translates to:
  /// **'Separated by spaces. Taken off only when it stands both at the start and at the end of an original or a translation; the end is found by itself (« → »). A lone * stays: the chat stresses a word with it.'**
  String get chatAnswerMarksHelp;

  /// No description provided for @chatAnswerMarksDefault.
  ///
  /// In en, this message translates to:
  /// **'Back to the standard ones'**
  String get chatAnswerMarksDefault;

  /// No description provided for @chatFoundInPart.
  ///
  /// In en, this message translates to:
  /// **'Answers found in this part: {found} of {total}'**
  String chatFoundInPart(int found, int total);

  /// No description provided for @chatPartPages.
  ///
  /// In en, this message translates to:
  /// **'Pages at a time'**
  String get chatPartPages;

  /// No description provided for @chatPartAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get chatPartAll;

  /// No description provided for @chatPartOf.
  ///
  /// In en, this message translates to:
  /// **'Part {part} of {parts} · pages {pages}'**
  String chatPartOf(int part, int parts, String pages);

  /// No description provided for @chatPartHelp.
  ///
  /// In en, this message translates to:
  /// **'\"Next\" keeps the answers of this part and shows the next one. \"Apply\" writes the answers of all parts.'**
  String get chatPartHelp;

  /// No description provided for @chatPartPick.
  ///
  /// In en, this message translates to:
  /// **'Go to a part'**
  String get chatPartPick;

  /// No description provided for @chatPartItem.
  ///
  /// In en, this message translates to:
  /// **'Part {part} · pages {pages} · answers {answered} of {total}'**
  String chatPartItem(int part, String pages, int answered, int total);

  /// No description provided for @chatGalleryParts.
  ///
  /// In en, this message translates to:
  /// **'All parts'**
  String get chatGalleryParts;

  /// No description provided for @chatPartsViewHelp.
  ///
  /// In en, this message translates to:
  /// **'The pictures of every part, to look at. Copying and answering are in the part itself (the list of parts over the window).'**
  String get chatPartsViewHelp;

  /// No description provided for @chatPartsPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare the other parts ({count})'**
  String chatPartsPrepare(int count);

  /// No description provided for @chatPartShown.
  ///
  /// In en, this message translates to:
  /// **'open now'**
  String get chatPartShown;

  /// No description provided for @chatPartNotPrepared.
  ///
  /// In en, this message translates to:
  /// **'Not prepared yet: its pictures come when you go to it or with \"Prepare the other parts\".'**
  String get chatPartNotPrepared;

  /// No description provided for @chatPartBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get chatPartBack;

  /// No description provided for @chatPartNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get chatPartNext;

  /// No description provided for @chatRequestSize.
  ///
  /// In en, this message translates to:
  /// **'In this request: {pieces} bubbles, {chars} characters of instructions'**
  String chatRequestSize(int pieces, int chars);

  /// No description provided for @chatRequestBig.
  ///
  /// In en, this message translates to:
  /// **'A big request: chats skip bubbles in long answers. Better send it in parts of {size} pages.'**
  String chatRequestBig(int size);

  /// No description provided for @chatRequestSplit.
  ///
  /// In en, this message translates to:
  /// **'Send in parts'**
  String get chatRequestSplit;

  /// No description provided for @chatFoundOnPage.
  ///
  /// In en, this message translates to:
  /// **'Answers found on page {page}: {found} of {total}'**
  String chatFoundOnPage(int page, int found, int total);

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

  /// No description provided for @chatAccepted.
  ///
  /// In en, this message translates to:
  /// **'Taken from earlier answers: {count} of {total}'**
  String chatAccepted(int count, int total);

  /// No description provided for @chatAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get chatAskAgain;

  /// No description provided for @chatAskAgainInfo.
  ///
  /// In en, this message translates to:
  /// **'The chat answered every bubble, but some badly (a wrong translation, a misread picture)? Write their labels here, with commas: 01-002, 03-005. The button next to it prepares a short request for them only: their pictures and instructions. Send it to the same chat and paste its answer: the new answer replaces the old one of these bubbles, the answers of the other bubbles stay. Bubbles with no answer at all are added by themselves.'**
  String get chatAskAgainInfo;

  /// No description provided for @chatAskAgainWrong.
  ///
  /// In en, this message translates to:
  /// **'Not a label: “{part}”'**
  String chatAskAgainWrong(String part);

  /// No description provided for @chatAskAgainUnknown.
  ///
  /// In en, this message translates to:
  /// **'These were not sent: {labels}'**
  String chatAskAgainUnknown(String labels);

  /// No description provided for @chatResendMissing.
  ///
  /// In en, this message translates to:
  /// **'Send the missing ones ({count})'**
  String chatResendMissing(int count);

  /// No description provided for @chatResendAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask again ({count})'**
  String chatResendAgain(int count);

  /// No description provided for @chatResendBoth.
  ///
  /// In en, this message translates to:
  /// **'Send the missing ones and ask again ({count})'**
  String chatResendBoth(int count);

  /// No description provided for @chatRoundBanner.
  ///
  /// In en, this message translates to:
  /// **'Another round: bubbles — {count} ({labels}). The pictures and instructions here are for them only; paste the chat\'s answer on the right.'**
  String chatRoundBanner(int count, String labels);

  /// No description provided for @chatRoundBack.
  ///
  /// In en, this message translates to:
  /// **'Back to the whole exchange'**
  String get chatRoundBack;

  /// No description provided for @chatUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Unchanged (as the bubbles are now): {count}'**
  String chatUnchanged(int count);

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
  /// **'Open an earlier exchange…'**
  String get chatMenuFolder;

  /// No description provided for @chatHelpMenu.
  ///
  /// In en, this message translates to:
  /// **'Help on the exchange…'**
  String get chatHelpMenu;

  /// No description provided for @chatHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Help on the exchange with a chat AI'**
  String get chatHelpTooltip;

  /// No description provided for @chatHelpSettings.
  ///
  /// In en, this message translates to:
  /// **'Help on the exchange'**
  String get chatHelpSettings;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpOpenElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get helpOpenElsewhere;

  /// No description provided for @helpOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open it in another app. The help file: {path}'**
  String helpOpenFailed(String path);

  /// No description provided for @helpSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String helpSaved(String path);

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
  /// **'The \"Chat\" button on the main screen works with any engines. For \"Translate all\" to open the exchange by itself, choose \"By hand through a chat AI\" as the translator and/or in Recognition.'**
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

  /// No description provided for @chatSelectedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Also picked on other pages: {count} (not copied with this page)'**
  String chatSelectedElsewhere(int count);

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
  /// **'Also the original and the translation in files of their own'**
  String get chatSplitFiles;

  /// No description provided for @chatSplitFilesHelp.
  ///
  /// In en, this message translates to:
  /// **'Besides ALL.txt, ALL_original.txt (the original) and ALL_translation.txt (the translation only) are written, the same for the page files. The answer is taken from whichever file is filled in.'**
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

  /// No description provided for @textCase.
  ///
  /// In en, this message translates to:
  /// **'Letter case'**
  String get textCase;

  /// No description provided for @textCaseSource.
  ///
  /// In en, this message translates to:
  /// **'As in the original'**
  String get textCaseSource;

  /// No description provided for @textCaseUpper.
  ///
  /// In en, this message translates to:
  /// **'ALL CAPITALS'**
  String get textCaseUpper;

  /// No description provided for @textCaseNormal.
  ///
  /// In en, this message translates to:
  /// **'Ordinary letters'**
  String get textCaseNormal;

  /// No description provided for @textCaseInfo.
  ///
  /// In en, this message translates to:
  /// **'Almost all comics are lettered in capitals. \"As in the original\": where a bubble of the original is in capitals, so is its translation; elsewhere ordinary letters. For a page or one bubble, use the \"Aa\" button of the Text panel.'**
  String get textCaseInfo;

  /// No description provided for @matchSource.
  ///
  /// In en, this message translates to:
  /// **'Look as in the original'**
  String get matchSource;

  /// No description provided for @matchSourceInfo.
  ///
  /// In en, this message translates to:
  /// **'The program looks at the original letters and draws the translation alike: bold where they are clearly heavier than in the page\'s other bubbles, italic where they lean, with an outline of the same colour for captions and sounds over the art. Found when the text is recognized; very small text gets no bold or italic. Turn it off for the same look in every bubble.'**
  String get matchSourceInfo;

  /// No description provided for @hyphenate.
  ///
  /// In en, this message translates to:
  /// **'Hyphenation'**
  String get hyphenate;

  /// No description provided for @hyphenateInfo.
  ///
  /// In en, this message translates to:
  /// **'Long Russian words may be broken by syllables. A break is made only where the text would otherwise have to be clearly smaller.'**
  String get hyphenateInfo;

  /// No description provided for @shapeFit.
  ///
  /// In en, this message translates to:
  /// **'Lines follow the bubble'**
  String get shapeFit;

  /// No description provided for @shapeFitInfo.
  ///
  /// In en, this message translates to:
  /// **'Lines follow the oval of the bubble, as letterers do: shorter at the top and bottom, longer in the middle; one letter size in the bubble. Works when a bubble holds one piece of text. For one bubble, see its look.'**
  String get shapeFitInfo;

  /// No description provided for @fontSuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest a font…'**
  String get fontSuggest;

  /// No description provided for @fontSuggestTitle.
  ///
  /// In en, this message translates to:
  /// **'Similar fonts'**
  String get fontSuggestTitle;

  /// No description provided for @fontSuggestHint.
  ///
  /// In en, this message translates to:
  /// **'Compared with the original letters on this page. The font is not changed by itself: pick one.'**
  String get fontSuggestHint;

  /// No description provided for @fontSuggestNoText.
  ///
  /// In en, this message translates to:
  /// **'No recognized text on this page: press Recognize first.'**
  String get fontSuggestNoText;

  /// No description provided for @fontSuggestTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The original letters on this page are too small to find a similar font: about {px} pixels, at least {min} are needed. Take a larger screenshot (zoom the page or the window in first).'**
  String fontSuggestTooSmall(int px, int min);

  /// No description provided for @fontSuggestUnmeasured.
  ///
  /// In en, this message translates to:
  /// **'The original letters on this page are not measured: press Recognize again.'**
  String get fontSuggestUnmeasured;

  /// No description provided for @fontSuggestForAll.
  ///
  /// In en, this message translates to:
  /// **'For all bubbles'**
  String get fontSuggestForAll;

  /// No description provided for @fontSuggestForBlock.
  ///
  /// In en, this message translates to:
  /// **'For this bubble only'**
  String get fontSuggestForBlock;

  /// No description provided for @fontSuggestOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get fontSuggestOriginal;

  /// No description provided for @caseToggle.
  ///
  /// In en, this message translates to:
  /// **'CAPITALS ↔ ordinary letters on this page or the selected pages'**
  String get caseToggle;

  /// No description provided for @caseToggleBlock.
  ///
  /// In en, this message translates to:
  /// **'CAPITALS ↔ ordinary letters in this bubble'**
  String get caseToggleBlock;

  /// No description provided for @sizeFromSource.
  ///
  /// In en, this message translates to:
  /// **'Size as in the original'**
  String get sizeFromSource;

  /// No description provided for @sizeFromSourcePages.
  ///
  /// In en, this message translates to:
  /// **'Letter size as in the original on this page or the selected pages (smaller in a tight bubble)'**
  String get sizeFromSourcePages;

  /// No description provided for @sizeFromSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'The size of the original letters is unknown: press Recognize again.'**
  String get sizeFromSourceUnknown;

  /// No description provided for @styleResetPages.
  ///
  /// In en, this message translates to:
  /// **'Reset the look of the bubbles on this page or the selected pages'**
  String get styleResetPages;

  /// No description provided for @hyphenateBlock.
  ///
  /// In en, this message translates to:
  /// **'Hyphenation'**
  String get hyphenateBlock;

  /// No description provided for @shapeFitBlock.
  ///
  /// In en, this message translates to:
  /// **'Follow the bubble'**
  String get shapeFitBlock;

  /// No description provided for @fromSource.
  ///
  /// In en, this message translates to:
  /// **'as in the original'**
  String get fromSource;

  /// No description provided for @textFit.
  ///
  /// In en, this message translates to:
  /// **'Fitting'**
  String get textFit;

  /// No description provided for @showLookInPanel.
  ///
  /// In en, this message translates to:
  /// **'Show the look in the panel'**
  String get showLookInPanel;

  /// No description provided for @runBigger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get runBigger;

  /// No description provided for @runSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get runSmaller;

  /// No description provided for @runClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the look of the selection'**
  String get runClear;

  /// No description provided for @runHint.
  ///
  /// In en, this message translates to:
  /// **'Select a word or sign of the translation for buttons that give it a look of its own.'**
  String get runHint;

  /// No description provided for @runAsBubble.
  ///
  /// In en, this message translates to:
  /// **'As the bubble'**
  String get runAsBubble;

  /// No description provided for @outlineNone.
  ///
  /// In en, this message translates to:
  /// **'No outline'**
  String get outlineNone;

  /// No description provided for @lookPreset.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get lookPreset;

  /// No description provided for @lookPresetNone.
  ///
  /// In en, this message translates to:
  /// **'No style'**
  String get lookPresetNone;

  /// No description provided for @lookPresetSave.
  ///
  /// In en, this message translates to:
  /// **'Save the look as a style…'**
  String get lookPresetSave;

  /// No description provided for @lookPresetName.
  ///
  /// In en, this message translates to:
  /// **'Style name'**
  String get lookPresetName;

  /// No description provided for @lookPresetUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update the style \"{name}\" from this bubble'**
  String lookPresetUpdate(String name);

  /// No description provided for @lookPresetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the style \"{name}\"'**
  String lookPresetDelete(String name);

  /// No description provided for @lookPresetHelp.
  ///
  /// In en, this message translates to:
  /// **'A style is a set of looks (font, colour, outline, bold…) put on a bubble or a word with one click. Change the style and every bubble and word with it changes.'**
  String get lookPresetHelp;

  /// No description provided for @keyPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste pages from the clipboard'**
  String get keyPaste;

  /// No description provided for @pastedPageName.
  ///
  /// In en, this message translates to:
  /// **'Pasted {time}'**
  String pastedPageName(String time);

  /// No description provided for @pasteNothing.
  ///
  /// In en, this message translates to:
  /// **'The clipboard has no picture or files'**
  String get pasteNothing;

  /// No description provided for @pasteBelow.
  ///
  /// In en, this message translates to:
  /// **'Paste from the clipboard below this page'**
  String get pasteBelow;

  /// No description provided for @addBelow.
  ///
  /// In en, this message translates to:
  /// **'Add files below this page…'**
  String get addBelow;

  /// No description provided for @repeatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Already added: {count}'**
  String repeatsTitle(String count);

  /// No description provided for @repeatsHint.
  ///
  /// In en, this message translates to:
  /// **'The same pictures are among the pages already. Tick the ones to add anyway. The small pictures: the new file and the page already open; click them or \"Compare\" to see both big.'**
  String get repeatsHint;

  /// No description provided for @repeatsCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get repeatsCompare;

  /// No description provided for @repeatsCompareNew.
  ///
  /// In en, this message translates to:
  /// **'File being added'**
  String get repeatsCompareNew;

  /// No description provided for @repeatsComparePage.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String repeatsComparePage(String number);

  /// No description provided for @repeatsCompareAdding.
  ///
  /// In en, this message translates to:
  /// **'Also being added'**
  String get repeatsCompareAdding;

  /// No description provided for @repeatsSameAs.
  ///
  /// In en, this message translates to:
  /// **'same as page {number} \"{name}\"'**
  String repeatsSameAs(String number, String name);

  /// No description provided for @repeatsSameAsNew.
  ///
  /// In en, this message translates to:
  /// **'same as \"{name}\" being added'**
  String repeatsSameAsNew(String name);

  /// No description provided for @repeatsSkipAll.
  ///
  /// In en, this message translates to:
  /// **'Skip all'**
  String get repeatsSkipAll;

  /// No description provided for @repeatsAddPicked.
  ///
  /// In en, this message translates to:
  /// **'Add ticked ({count})'**
  String repeatsAddPicked(String count);

  /// No description provided for @repeatsAddAll.
  ///
  /// In en, this message translates to:
  /// **'Add all anyway'**
  String get repeatsAddAll;

  /// No description provided for @repeatsLeft.
  ///
  /// In en, this message translates to:
  /// **'Repeats not added: {count}'**
  String repeatsLeft(String count);

  /// No description provided for @pageSort.
  ///
  /// In en, this message translates to:
  /// **'Order of pages (pages can be dragged with the mouse too)'**
  String get pageSort;

  /// No description provided for @pageSortNameUp.
  ///
  /// In en, this message translates to:
  /// **'By name: A → Z'**
  String get pageSortNameUp;

  /// No description provided for @pageSortNameDown.
  ///
  /// In en, this message translates to:
  /// **'By name: Z → A'**
  String get pageSortNameDown;

  /// No description provided for @pageSortDateUp.
  ///
  /// In en, this message translates to:
  /// **'By file date: oldest first'**
  String get pageSortDateUp;

  /// No description provided for @pageSortDateDown.
  ///
  /// In en, this message translates to:
  /// **'By file date: newest first'**
  String get pageSortDateDown;

  /// No description provided for @pageSortReverse.
  ///
  /// In en, this message translates to:
  /// **'Turn the order round'**
  String get pageSortReverse;

  /// No description provided for @pageSortDone.
  ///
  /// In en, this message translates to:
  /// **'The order of pages changed'**
  String get pageSortDone;

  /// No description provided for @gridTileSize.
  ///
  /// In en, this message translates to:
  /// **'Size of the pictures'**
  String get gridTileSize;

  /// No description provided for @pageNumbers.
  ///
  /// In en, this message translates to:
  /// **'Page numbers'**
  String get pageNumbers;

  /// No description provided for @pageNumbersHint.
  ///
  /// In en, this message translates to:
  /// **'numbers: 1,5-8,10'**
  String get pageNumbersHint;

  /// No description provided for @pageNumbersTip.
  ///
  /// In en, this message translates to:
  /// **'Pick pages by their numbers, like 1,5-8,10, and press Enter. The steps (Detect, Recognize…), the chat, the export and \"Translate selected\" work on the picked pages.'**
  String get pageNumbersTip;

  /// No description provided for @pageNumbersWrong.
  ///
  /// In en, this message translates to:
  /// **'Not a page: \"{part}\" (there are {count})'**
  String pageNumbersWrong(String part, String count);

  /// No description provided for @pageNumbersPick.
  ///
  /// In en, this message translates to:
  /// **'Pick (Enter)'**
  String get pageNumbersPick;

  /// No description provided for @translateSelected.
  ///
  /// In en, this message translates to:
  /// **'Translate selected ({count})'**
  String translateSelected(String count);

  /// No description provided for @translateShort.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateShort;

  /// No description provided for @translateShortCount.
  ///
  /// In en, this message translates to:
  /// **'Translate ({count})'**
  String translateShortCount(String count);

  /// No description provided for @translateWhich.
  ///
  /// In en, this message translates to:
  /// **'What to translate: everything or only the picked pages (remembered)'**
  String get translateWhich;

  /// No description provided for @translateAllPages.
  ///
  /// In en, this message translates to:
  /// **'Translate all'**
  String get translateAllPages;

  /// No description provided for @translateSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Pick pages first: Ctrl+click in the list, numbers like 1,5-8, or ticks in the grid'**
  String get translateSelectedHint;

  /// No description provided for @exportNumbers.
  ///
  /// In en, this message translates to:
  /// **'Picked / numbers'**
  String get exportNumbers;

  /// No description provided for @exportNumbersReady.
  ///
  /// In en, this message translates to:
  /// **'Translated among them: {done} of {count}; only these are saved'**
  String exportNumbersReady(String done, String count);

  /// No description provided for @exportNames.
  ///
  /// In en, this message translates to:
  /// **'File names'**
  String get exportNames;

  /// No description provided for @exportNamesPages.
  ///
  /// In en, this message translates to:
  /// **'As the pages'**
  String get exportNamesPages;

  /// No description provided for @exportNamesTemplate.
  ///
  /// In en, this message translates to:
  /// **'Name + number'**
  String get exportNamesTemplate;

  /// No description provided for @exportNamePrefix.
  ///
  /// In en, this message translates to:
  /// **'Name (text before the number)'**
  String get exportNamePrefix;

  /// No description provided for @exportNameStart.
  ///
  /// In en, this message translates to:
  /// **'Start at'**
  String get exportNameStart;

  /// No description provided for @exportNameStartWrong.
  ///
  /// In en, this message translates to:
  /// **'Digits only'**
  String get exportNameStartWrong;

  /// No description provided for @exportNamesExample.
  ///
  /// In en, this message translates to:
  /// **'You get: {example}  (as many digits as written in \"Start at\")'**
  String exportNamesExample(String example);

  /// No description provided for @keyNavigator.
  ///
  /// In en, this message translates to:
  /// **'Mini view: show or hide'**
  String get keyNavigator;

  /// No description provided for @navigatorToggle.
  ///
  /// In en, this message translates to:
  /// **'Mini view: the whole page with a frame around what is shown; a click or a drag in it moves the view ({key})'**
  String navigatorToggle(String key);

  /// No description provided for @settingsAsPanel.
  ///
  /// In en, this message translates to:
  /// **'Settings as a panel beside the page: the page stays in sight'**
  String get settingsAsPanel;

  /// No description provided for @settingsFullWindow.
  ///
  /// In en, this message translates to:
  /// **'Settings over the whole window'**
  String get settingsFullWindow;

  /// No description provided for @settingsView.
  ///
  /// In en, this message translates to:
  /// **'Open the settings'**
  String get settingsView;

  /// No description provided for @settingsViewFull.
  ///
  /// In en, this message translates to:
  /// **'Over the whole window'**
  String get settingsViewFull;

  /// No description provided for @settingsViewPanel.
  ///
  /// In en, this message translates to:
  /// **'As a panel beside the page'**
  String get settingsViewPanel;

  /// No description provided for @settingsViewLast.
  ///
  /// In en, this message translates to:
  /// **'As the last time'**
  String get settingsViewLast;

  /// No description provided for @settingsViewHelp.
  ///
  /// In en, this message translates to:
  /// **'While the app runs, the settings open as you left them (the button in their title). This is how they open after the app starts.'**
  String get settingsViewHelp;

  /// No description provided for @removePicked.
  ///
  /// In en, this message translates to:
  /// **'Remove the picked ({count})…'**
  String removePicked(String count);

  /// No description provided for @removePagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {count} pages from the list?'**
  String removePagesTitle(String count);

  /// No description provided for @removePagesBody.
  ///
  /// In en, this message translates to:
  /// **'The files on disk stay. Ctrl+Z right after brings the pages back, with their translation and edits.'**
  String get removePagesBody;

  /// No description provided for @removePagesYes.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePagesYes;

  /// No description provided for @pagesRemoved.
  ///
  /// In en, this message translates to:
  /// **'Taken out of the list: {count}. Ctrl+Z brings them back.'**
  String pagesRemoved(String count);

  /// No description provided for @exportRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember these settings'**
  String get exportRemember;

  /// No description provided for @exportRememberHelp.
  ///
  /// In en, this message translates to:
  /// **'Off: the window opens with the usual settings each time.'**
  String get exportRememberHelp;

  /// No description provided for @exportRemovePages.
  ///
  /// In en, this message translates to:
  /// **'Take the exported pages out of the project'**
  String get exportRemovePages;

  /// No description provided for @exportRemovePagesHelp.
  ///
  /// In en, this message translates to:
  /// **'The files on disk stay; Ctrl+Z right after brings the pages back.'**
  String get exportRemovePagesHelp;

  /// No description provided for @exportSavedRemoved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}. Taken out of the project: {count} (Ctrl+Z brings them back).'**
  String exportSavedRemoved(String path, String count);

  /// No description provided for @exportNothingWritten.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved: the pages chosen have no picture of the kind asked for (not cleaned yet, say)'**
  String get exportNothingWritten;

  /// No description provided for @exportSavedLeftOut.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}. Left out, with no picture of the kind asked for: {count}'**
  String exportSavedLeftOut(String path, String count);

  /// No description provided for @exportSavedRemovedLeft.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}. Taken out of the project: {removed} (Ctrl+Z brings them back). Left in it, with no picture of the kind asked for: {left}'**
  String exportSavedRemovedLeft(String path, String removed, String left);

  /// No description provided for @findInside.
  ///
  /// In en, this message translates to:
  /// **'Find blocks inside this box (columns, paragraphs)'**
  String get findInside;

  /// No description provided for @findInsideWhich.
  ///
  /// In en, this message translates to:
  /// **'How to find blocks inside the box'**
  String get findInsideWhich;

  /// No description provided for @findInsideAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto: columns and paragraphs'**
  String get findInsideAuto;

  /// No description provided for @findInsideColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns only'**
  String get findInsideColumns;

  /// No description provided for @findInsideParagraphs.
  ///
  /// In en, this message translates to:
  /// **'Paragraphs only'**
  String get findInsideParagraphs;

  /// No description provided for @findInsideHint.
  ///
  /// In en, this message translates to:
  /// **'You can stretch the box first: text it missed is found too. If the box was recognized, the new blocks are recognized at once.'**
  String get findInsideHint;

  /// No description provided for @findInsideNone.
  ///
  /// In en, this message translates to:
  /// **'There is one block inside: nothing to split.'**
  String get findInsideNone;

  /// No description provided for @findInsideDone.
  ///
  /// In en, this message translates to:
  /// **'Blocks found: {count}. Undo with Ctrl+Z.'**
  String findInsideDone(String count);

  /// No description provided for @appIcon.
  ///
  /// In en, this message translates to:
  /// **'Program icon'**
  String get appIcon;

  /// No description provided for @appIconGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get appIconGreen;

  /// No description provided for @appIconBlue.
  ///
  /// In en, this message translates to:
  /// **'Cat on blue'**
  String get appIconBlue;

  /// No description provided for @appIconNavy.
  ///
  /// In en, this message translates to:
  /// **'Cat on dark'**
  String get appIconNavy;

  /// No description provided for @appIconRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove your picture'**
  String get appIconRemove;

  /// No description provided for @appIconRemoved.
  ///
  /// In en, this message translates to:
  /// **'Your picture is removed.'**
  String get appIconRemoved;

  /// No description provided for @appIconRemovedBack.
  ///
  /// In en, this message translates to:
  /// **'Your picture is removed; the green icon is back.'**
  String get appIconRemovedBack;

  /// No description provided for @appIconRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the picture: {error}'**
  String appIconRemoveFailed(String error);

  /// No description provided for @appIconCustom.
  ///
  /// In en, this message translates to:
  /// **'Your picture…'**
  String get appIconCustom;

  /// No description provided for @appIconOther.
  ///
  /// In en, this message translates to:
  /// **'Another picture…'**
  String get appIconOther;

  /// No description provided for @appIconHelp.
  ///
  /// In en, this message translates to:
  /// **'The window and its taskbar button change at once. The icon of comic_translate.exe itself in its folder always stays green.'**
  String get appIconHelp;

  /// No description provided for @appIconBadPicture.
  ///
  /// In en, this message translates to:
  /// **'Could not read this picture: {error}'**
  String appIconBadPicture(String error);

  /// No description provided for @appIconNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Windows could not load this icon; the window keeps the old one.'**
  String get appIconNotLoaded;

  /// No description provided for @updateShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Update shortcuts'**
  String get updateShortcuts;

  /// No description provided for @updateShortcutsInfo.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts of this program on the desktop, in Start and pinned to the taskbar get the chosen icon. Windows may take a moment to redraw them.'**
  String get updateShortcutsInfo;

  /// No description provided for @shortcutsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts updated: {count}'**
  String shortcutsUpdated(int count);

  /// No description provided for @shortcutsNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No shortcuts found'**
  String get shortcutsNoneTitle;

  /// No description provided for @shortcutsNoneBody.
  ///
  /// In en, this message translates to:
  /// **'There are no shortcuts to this copy of the program on the desktop, in Start or on the taskbar. Put one on the desktop?'**
  String get shortcutsNoneBody;

  /// No description provided for @createDesktopShortcut.
  ///
  /// In en, this message translates to:
  /// **'Put on the desktop'**
  String get createDesktopShortcut;

  /// No description provided for @shortcutCreated.
  ///
  /// In en, this message translates to:
  /// **'Shortcut created: {path}'**
  String shortcutCreated(String path);

  /// No description provided for @shortcutsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the shortcuts: {error}'**
  String shortcutsFailed(String error);

  /// No description provided for @toolDraw.
  ///
  /// In en, this message translates to:
  /// **'Drawing (D): touch up the picture after cleaning: brush, eraser, original, fill, pipette'**
  String get toolDraw;

  /// No description provided for @drawBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush: paints the chosen colour. Shift + click: a straight line from the last point'**
  String get drawBrush;

  /// No description provided for @drawEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser: takes your strokes back off (the cleaned page shows again)'**
  String get drawEraser;

  /// No description provided for @drawOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original: brings back the picture as it was before cleaning where you paint (when cleaning took too much)'**
  String get drawOriginal;

  /// No description provided for @drawFill.
  ///
  /// In en, this message translates to:
  /// **'Fill: a click fills a bubble or a patch of one colour with the chosen colour'**
  String get drawFill;

  /// No description provided for @drawPipette.
  ///
  /// In en, this message translates to:
  /// **'Pipette: a click takes the colour from the page. In the other modes: Alt + click'**
  String get drawPipette;

  /// No description provided for @paintColour.
  ///
  /// In en, this message translates to:
  /// **'Colour of the brush and the fill ({colour}): click to choose'**
  String paintColour(String colour);

  /// No description provided for @paintColourHover.
  ///
  /// In en, this message translates to:
  /// **'Under the mouse: {colour}'**
  String paintColourHover(String colour);

  /// No description provided for @paintColourHoverNone.
  ///
  /// In en, this message translates to:
  /// **'Here the colour under the mouse shows while you pick one (pipette or Alt)'**
  String get paintColourHoverNone;

  /// No description provided for @paintColourCode.
  ///
  /// In en, this message translates to:
  /// **'Colour code'**
  String get paintColourCode;

  /// No description provided for @paintColourRecent.
  ///
  /// In en, this message translates to:
  /// **'Used lately'**
  String get paintColourRecent;

  /// No description provided for @fillTolerance.
  ///
  /// In en, this message translates to:
  /// **'Fill tolerance: how different shades the fill still takes in'**
  String get fillTolerance;

  /// No description provided for @fillSpots.
  ///
  /// In en, this message translates to:
  /// **'Spots too'**
  String get fillSpots;

  /// No description provided for @fillSpotsHelp.
  ///
  /// In en, this message translates to:
  /// **'The fill also covers spots inside what it fills: leftover letters, smudges. Off: only the colour clicked'**
  String get fillSpotsHelp;

  /// No description provided for @clearPaints.
  ///
  /// In en, this message translates to:
  /// **'Remove every touch-up of this page'**
  String get clearPaints;

  /// No description provided for @previewToggle.
  ///
  /// In en, this message translates to:
  /// **'As it will be ({key}): the page as export makes it, without boxes and mask. Again: back. Hold O: the original page'**
  String previewToggle(String key);

  /// No description provided for @previewOn.
  ///
  /// In en, this message translates to:
  /// **'As it will be. Back: {key} or click here'**
  String previewOn(String key);

  /// No description provided for @keyDraw.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get keyDraw;

  /// No description provided for @keyPreview.
  ///
  /// In en, this message translates to:
  /// **'As it will be'**
  String get keyPreview;

  /// No description provided for @drawArea.
  ///
  /// In en, this message translates to:
  /// **'Selection: outline an area (pick the shape on the right). While it is selected, the brush, eraser, original and fill work only inside it; the bar above the page fills it, brings back the original or erases the touch-ups in it. Esc drops it'**
  String get drawArea;

  /// No description provided for @areaLasso.
  ///
  /// In en, this message translates to:
  /// **'Lasso: draw the outline by hand with the button held'**
  String get areaLasso;

  /// No description provided for @areaPolygon.
  ///
  /// In en, this message translates to:
  /// **'By points: click the corners; a click on the first one, a double click or Enter fills. Backspace takes the last corner back, Esc drops it all'**
  String get areaPolygon;

  /// No description provided for @areaRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle: drag from corner to corner'**
  String get areaRectangle;

  /// No description provided for @areaEllipse.
  ///
  /// In en, this message translates to:
  /// **'Ellipse: drag across it (good for round bubbles)'**
  String get areaEllipse;

  /// No description provided for @toolPictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures (M): lay a picture (a meme) on the page or into a bubble; drag it, pull a corner (Shift: any shape), Delete removes it'**
  String get toolPictures;

  /// No description provided for @keyPictures.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get keyPictures;

  /// No description provided for @pictureFiles.
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get pictureFiles;

  /// No description provided for @pictureUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read the picture: {error}'**
  String pictureUnreadable(String error);

  /// No description provided for @pictureAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a picture…'**
  String get pictureAdd;

  /// No description provided for @pictureAddHelp.
  ///
  /// In en, this message translates to:
  /// **'The picture goes into the middle of the page. Select a bubble first to put it into the bubble. Ctrl+V lays a picture copied in a browser'**
  String get pictureAddHelp;

  /// No description provided for @pictureAddIntoBubble.
  ///
  /// In en, this message translates to:
  /// **'The picture goes into bubble {number}'**
  String pictureAddIntoBubble(String number);

  /// No description provided for @pictureToShelf.
  ///
  /// In en, this message translates to:
  /// **'Put the selected picture on the shelf'**
  String get pictureToShelf;

  /// No description provided for @pictureRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the selected picture (Delete)'**
  String get pictureRemove;

  /// No description provided for @shelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get shelf;

  /// No description provided for @shelfToggle.
  ///
  /// In en, this message translates to:
  /// **'Shelf: bubbles and pictures put away from one page, to take out on another ({count})'**
  String shelfToggle(String count);

  /// No description provided for @shelfPutBubbles.
  ///
  /// In en, this message translates to:
  /// **'Put the selected bubbles here ({count})'**
  String shelfPutBubbles(String count);

  /// No description provided for @shelfPutHelp.
  ///
  /// In en, this message translates to:
  /// **'The selected bubbles leave the page with their text, translation and look. Ctrl+Z on the page brings them back there'**
  String get shelfPutHelp;

  /// No description provided for @shelfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty. Put a bubble here with the button above, or a picture with the Pictures tool'**
  String get shelfEmpty;

  /// No description provided for @shelfPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get shelfPicture;

  /// No description provided for @shelfBubbleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Bubble without text'**
  String get shelfBubbleEmpty;

  /// No description provided for @shelfTakeHelp.
  ///
  /// In en, this message translates to:
  /// **'Click: onto this page'**
  String get shelfTakeHelp;

  /// No description provided for @shelfThrow.
  ///
  /// In en, this message translates to:
  /// **'Throw away'**
  String get shelfThrow;

  /// No description provided for @eraseShapeHelp.
  ///
  /// In en, this message translates to:
  /// **'Brush or outline: with an outline, everything inside it is erased or brought back at once'**
  String get eraseShapeHelp;

  /// No description provided for @eraseShapeBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get eraseShapeBrush;

  /// No description provided for @pasteNoPicture.
  ///
  /// In en, this message translates to:
  /// **'No picture in the clipboard. Copy one (in a browser: right click on it, Copy image) and press Ctrl+V again'**
  String get pasteNoPicture;

  /// No description provided for @keyPeekOriginal.
  ///
  /// In en, this message translates to:
  /// **'Peek at the original (hold)'**
  String get keyPeekOriginal;

  /// No description provided for @pictureOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity of the selected picture: {percent} %. Less lets the page show through'**
  String pictureOpacity(String percent);

  /// No description provided for @picturesBack.
  ///
  /// In en, this message translates to:
  /// **'Bring back pictures lost past the page\'s edges'**
  String get picturesBack;

  /// No description provided for @pasteboardHelp.
  ///
  /// In en, this message translates to:
  /// **'On the desk beside the page: drag it onto the page (any page) to put it there'**
  String get pasteboardHelp;

  /// No description provided for @selection.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get selection;

  /// No description provided for @selectionFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get selectionFill;

  /// No description provided for @selectionOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get selectionOriginal;

  /// No description provided for @selectionErase.
  ///
  /// In en, this message translates to:
  /// **'Erase touch-ups'**
  String get selectionErase;

  /// No description provided for @selectionDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop (Esc)'**
  String get selectionDrop;
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
