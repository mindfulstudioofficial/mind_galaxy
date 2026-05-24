import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ja')
  ];

  /// No description provided for @simpleMode.
  ///
  /// In en, this message translates to:
  /// **'Simple Input'**
  String get simpleMode;

  /// No description provided for @bulkMode.
  ///
  /// In en, this message translates to:
  /// **'Bulk Input'**
  String get bulkMode;

  /// No description provided for @inputHint.
  ///
  /// In en, this message translates to:
  /// **'Give your thoughts a voice... (e.g.) Tonight, I noticed the stars.'**
  String get inputHint;

  /// No description provided for @insightHint.
  ///
  /// In en, this message translates to:
  /// **'Insights & Learnings (e.g.) Small shifts can change everything.'**
  String get insightHint;

  /// No description provided for @actionHint.
  ///
  /// In en, this message translates to:
  /// **'Action (small steps are enough)'**
  String get actionHint;

  /// No description provided for @saveThought.
  ///
  /// In en, this message translates to:
  /// **'⭐ Save Thought'**
  String get saveThought;

  /// No description provided for @adSpace.
  ///
  /// In en, this message translates to:
  /// **'Ad Space'**
  String get adSpace;

  /// No description provided for @observationMode.
  ///
  /// In en, this message translates to:
  /// **'Observation Mode'**
  String get observationMode;

  /// No description provided for @meteorShower.
  ///
  /// In en, this message translates to:
  /// **'Meteor Shower'**
  String get meteorShower;

  /// No description provided for @returnToGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Return to Galaxy'**
  String get returnToGalaxy;

  /// No description provided for @deleteThought.
  ///
  /// In en, this message translates to:
  /// **'Delete Thought'**
  String get deleteThought;

  /// No description provided for @revisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Revisit Thoughts'**
  String get revisitTitle;

  /// No description provided for @weeklyGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Weekly Galaxy'**
  String get weeklyGalaxy;

  /// No description provided for @revisitPromptAddAction.
  ///
  /// In en, this message translates to:
  /// **'Would you like to take this one step now?'**
  String get revisitPromptAddAction;

  /// No description provided for @revisitPromptAddInsight.
  ///
  /// In en, this message translates to:
  /// **'Would you like to add a new insight to this thought?'**
  String get revisitPromptAddInsight;

  /// No description provided for @revisitPromptReflectTimePassed.
  ///
  /// In en, this message translates to:
  /// **'Try putting into words what changed over time.'**
  String get revisitPromptReflectTimePassed;

  /// No description provided for @revisitPromptDeepen.
  ///
  /// In en, this message translates to:
  /// **'Would you like to deepen this thought from your current perspective?'**
  String get revisitPromptDeepen;

  /// No description provided for @starRevisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Star Revisit'**
  String get starRevisitTitle;

  /// No description provided for @revisitThoughtLabel.
  ///
  /// In en, this message translates to:
  /// **'Past thought:'**
  String get revisitThoughtLabel;

  /// No description provided for @laterButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterButtonLabel;

  /// No description provided for @updateContentButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Update content'**
  String get updateContentButtonLabel;

  /// No description provided for @revisitComplete.
  ///
  /// In en, this message translates to:
  /// **'Revisit complete'**
  String get revisitComplete;

  /// No description provided for @tutorialStep0.
  ///
  /// In en, this message translates to:
  /// **'What you think becomes a star'**
  String get tutorialStep0;

  /// No description provided for @tutorialInputHint.
  ///
  /// In en, this message translates to:
  /// **'What is on your mind right now?'**
  String get tutorialInputHint;

  /// No description provided for @tutorialPressEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Enter when done'**
  String get tutorialPressEnter;

  /// No description provided for @tutorialStep2.
  ///
  /// In en, this message translates to:
  /// **'That became a star'**
  String get tutorialStep2;

  /// No description provided for @tutorialStep3.
  ///
  /// In en, this message translates to:
  /// **'Drag the star and try classifying it'**
  String get tutorialStep3;

  /// No description provided for @tutorialFuture.
  ///
  /// In en, this message translates to:
  /// **'Up: Future'**
  String get tutorialFuture;

  /// No description provided for @tutorialPast.
  ///
  /// In en, this message translates to:
  /// **'Down: Past'**
  String get tutorialPast;

  /// No description provided for @tutorialEmotion.
  ///
  /// In en, this message translates to:
  /// **'Left: Emotion'**
  String get tutorialEmotion;

  /// No description provided for @tutorialAction.
  ///
  /// In en, this message translates to:
  /// **'Right: Action'**
  String get tutorialAction;

  /// No description provided for @tutorialStep4.
  ///
  /// In en, this message translates to:
  /// **'With insight and action,\nyour star grows'**
  String get tutorialStep4;

  /// No description provided for @tutorialStep5.
  ///
  /// In en, this message translates to:
  /// **'This is your universe'**
  String get tutorialStep5;

  /// No description provided for @tutorialStep6.
  ///
  /// In en, this message translates to:
  /// **'From now on, tap the +\nin the bottom-right to add thoughts'**
  String get tutorialStep6;

  /// No description provided for @tutorialStep7Title.
  ///
  /// In en, this message translates to:
  /// **'Your Galaxy in a Week'**
  String get tutorialStep7Title;

  /// No description provided for @tutorialStep7Body.
  ///
  /// In en, this message translates to:
  /// **'As your stars increase, Weekly Galaxy helps you review patterns.\nTap to begin.'**
  String get tutorialStep7Body;

  /// No description provided for @supportDeveloperTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Developer'**
  String get supportDeveloperTitle;

  /// No description provided for @meteorSupportContent.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad to unlock a 12-hour meteor shower?'**
  String get meteorSupportContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discardInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this input?'**
  String get discardInputTitle;

  /// No description provided for @discardInputMessage.
  ///
  /// In en, this message translates to:
  /// **'Any unsaved text will be lost.'**
  String get discardInputMessage;

  /// No description provided for @discardInputConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardInputConfirm;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get approve;

  /// No description provided for @meteorSupportNotice.
  ///
  /// In en, this message translates to:
  /// **'Meteor shower activated for 12 hours'**
  String get meteorSupportNotice;

  /// No description provided for @weeklyGalaxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Galaxy'**
  String get weeklyGalaxyTitle;

  /// No description provided for @accountSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Account / Sync'**
  String get accountSyncTitle;

  /// No description provided for @premiumPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Plan'**
  String get premiumPlanTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @aboutAppTitle.
  ///
  /// In en, this message translates to:
  /// **'About This App'**
  String get aboutAppTitle;

  /// No description provided for @aboutAppDescription.
  ///
  /// In en, this message translates to:
  /// **'MindGalaxy helps you record thoughts as stars and revisit them over time.'**
  String get aboutAppDescription;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @categoryFuture.
  ///
  /// In en, this message translates to:
  /// **'Future'**
  String get categoryFuture;

  /// No description provided for @categoryEmotion.
  ///
  /// In en, this message translates to:
  /// **'Emotion'**
  String get categoryEmotion;

  /// No description provided for @categoryAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get categoryAction;

  /// No description provided for @categoryPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get categoryPast;

  /// No description provided for @categoryUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get categoryUncategorized;

  /// No description provided for @meteorRewardAd.
  ///
  /// In en, this message translates to:
  /// **'Meteor Shower Reward Ad'**
  String get meteorRewardAd;

  /// No description provided for @futureLoginFeature.
  ///
  /// In en, this message translates to:
  /// **'Login feature coming soon'**
  String get futureLoginFeature;

  /// No description provided for @guestModeStatus.
  ///
  /// In en, this message translates to:
  /// **'Guest mode (no sign-in)'**
  String get guestModeStatus;

  /// No description provided for @loginOptionalDescription.
  ///
  /// In en, this message translates to:
  /// **'You can use the app without signing in. Sign in only when you want sync.'**
  String get loginOptionalDescription;

  /// No description provided for @loginBenefitSummary.
  ///
  /// In en, this message translates to:
  /// **'Signing in prepares your account for future sync and device transfer. You can keep using guest mode with no problem.'**
  String get loginBenefitSummary;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get loginWithApple;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutButton;

  /// No description provided for @loginConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'You can stay signed in until you need sync features.'**
  String get loginConnectedHint;

  /// No description provided for @loginSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get loginSuccessSnack;

  /// No description provided for @loginCancelledSnack.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled'**
  String get loginCancelledSnack;

  /// No description provided for @loginSetupRequiredSnack.
  ///
  /// In en, this message translates to:
  /// **'Sign-in will be available after Firebase setup'**
  String get loginSetupRequiredSnack;

  /// No description provided for @loginUnsupportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign In is not available on this device'**
  String get loginUnsupportedSnack;

  /// No description provided for @loginFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again later.'**
  String get loginFailedSnack;

  /// No description provided for @logoutSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get logoutSuccessSnack;

  /// No description provided for @loginSampleGoogleName.
  ///
  /// In en, this message translates to:
  /// **'Google User'**
  String get loginSampleGoogleName;

  /// No description provided for @loginSampleAppleName.
  ///
  /// In en, this message translates to:
  /// **'Apple User'**
  String get loginSampleAppleName;

  /// No description provided for @loginStatusWithProvider.
  ///
  /// In en, this message translates to:
  /// **'{name} (signed in with {provider})'**
  String loginStatusWithProvider(String name, String provider);

  /// No description provided for @futureBillingPlan.
  ///
  /// In en, this message translates to:
  /// **'Billing plans coming soon'**
  String get futureBillingPlan;

  /// No description provided for @insightShort.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightShort;

  /// No description provided for @actionShort.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionShort;

  /// No description provided for @thoughtLabel.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get thoughtLabel;

  /// No description provided for @createdAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAtLabel;

  /// No description provided for @weeklyDensity.
  ///
  /// In en, this message translates to:
  /// **'Weekly Density'**
  String get weeklyDensity;

  /// No description provided for @weeklyAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Weekly Analysis'**
  String get weeklyAnalysis;

  /// No description provided for @weeklyInsightsLabel.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get weeklyInsightsLabel;

  /// No description provided for @weeklyActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get weeklyActionsLabel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @starsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stars'**
  String starsCount(int count);

  /// No description provided for @noThoughtsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No thoughts yet this week'**
  String get noThoughtsThisWeek;

  /// No description provided for @generatingImageForDownload.
  ///
  /// In en, this message translates to:
  /// **'Generating image and downloading...'**
  String get generatingImageForDownload;

  /// No description provided for @generatingImageForShare.
  ///
  /// In en, this message translates to:
  /// **'Generating image and opening share menu...'**
  String get generatingImageForShare;

  /// No description provided for @shareThoughtText.
  ///
  /// In en, this message translates to:
  /// **'MindGalaxy - I captured a thought. #MindGalaxy'**
  String get shareThoughtText;

  /// No description provided for @generatingWeeklyImageForDownload.
  ///
  /// In en, this message translates to:
  /// **'Generating Weekly Galaxy image and downloading...'**
  String get generatingWeeklyImageForDownload;

  /// No description provided for @generatingWeeklyImageForShare.
  ///
  /// In en, this message translates to:
  /// **'Generating Weekly Galaxy image and opening share menu...'**
  String get generatingWeeklyImageForShare;

  /// No description provided for @shareWeeklyGalaxyText.
  ///
  /// In en, this message translates to:
  /// **'MindGalaxy - Sharing my universe from this week. #MindGalaxy #WeeklyGalaxy'**
  String get shareWeeklyGalaxyText;

  /// No description provided for @shareWeeklyGalaxyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share Weekly Galaxy'**
  String get shareWeeklyGalaxyTooltip;

  /// No description provided for @insightLabel.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightLabel;

  /// No description provided for @popupInsightHint.
  ///
  /// In en, this message translates to:
  /// **'Write your learnings and insights...'**
  String get popupInsightHint;

  /// No description provided for @actionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get actionLabel;

  /// No description provided for @popupActionHint.
  ///
  /// In en, this message translates to:
  /// **'Action (small steps are OK)'**
  String get popupActionHint;

  /// No description provided for @releaseStarToGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Release this star into your galaxy'**
  String get releaseStarToGalaxy;

  /// No description provided for @comingSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon...'**
  String get comingSoonLabel;

  /// No description provided for @privacyPolicyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load the privacy policy.'**
  String get privacyPolicyLoadFailed;

  /// No description provided for @weekdayMonShort.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMonShort;

  /// No description provided for @weekdayTueShort.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTueShort;

  /// No description provided for @weekdayWedShort.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWedShort;

  /// No description provided for @weekdayThuShort.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThuShort;

  /// No description provided for @weekdayFriShort.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFriShort;

  /// No description provided for @weekdaySatShort.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySatShort;

  /// No description provided for @weekdaySunShort.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySunShort;

  /// No description provided for @observationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search past stars'**
  String get observationSearchHint;

  /// No description provided for @observationSearchNoResult.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get observationSearchNoResult;

  /// No description provided for @observationSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String observationSearchResultCount(int current, int total);

  /// No description provided for @observationSearchPreviousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous search result'**
  String get observationSearchPreviousTooltip;

  /// No description provided for @observationSearchNextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next search result'**
  String get observationSearchNextTooltip;

  /// No description provided for @weekOfMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Week {week}, {month}/{year}'**
  String weekOfMonthLabel(int year, int month, int week);

  /// No description provided for @weeklyPreviousWeekTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show previous week'**
  String get weeklyPreviousWeekTooltip;

  /// No description provided for @weeklyNextWeekTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show next week'**
  String get weeklyNextWeekTooltip;

  /// No description provided for @weeklyBackToCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Back to current week'**
  String get weeklyBackToCurrentWeek;

  /// No description provided for @noThoughtsInSelectedWeek.
  ///
  /// In en, this message translates to:
  /// **'No thoughts recorded this week'**
  String get noThoughtsInSelectedWeek;

  /// No description provided for @weeklyPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select week to view'**
  String get weeklyPickerTitle;

  /// No description provided for @weeklyPickerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get weeklyPickerApply;

  /// No description provided for @weeklyPickerYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get weeklyPickerYearLabel;

  /// No description provided for @weeklyPickerMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get weeklyPickerMonthLabel;

  /// No description provided for @weeklyPickerWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weeklyPickerWeekLabel;

  /// No description provided for @weeklyPickerYearSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get weeklyPickerYearSuffix;

  /// No description provided for @weeklyPickerMonthSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get weeklyPickerMonthSuffix;

  /// No description provided for @weeklyPickerWeekSuffix.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weeklyPickerWeekSuffix;
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
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
