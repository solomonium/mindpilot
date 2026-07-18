class Strings {
  ///CRITICAL APP STRINGS PLEASE DO NOT MODIFY WITH OUT CONSULTATION
  ///

  String helloUser(String name) => "Hi $name";
  String welcomeBack(String name) => "Welcome Back, $name";

  String get userName => 'John Doe';

  ///
  ///
  ///CRITICAL APP STRINGS PLEASE DO NOT MODIFY WITH OUT CONSULTATION

  ///error string
  String get tooShortName => 'name is too short';
  String get invalidEmail => 'Enter a valid email';

  ///short words

  String get dontHaveAcct => "Don't have an account? ";
  String get alreadyHaveAcct => "Already have an account? ";
  String get signUp => 'Sign Up ';
  String get createAccount => 'Create Account';
  String get chooseAccount => 'Choose an Account';
  String get email => 'Email';
  String get welcomeSignIn => 'Welcome to MindPilot, sign in to continue';
  String get comFinanceMadeSimple => 'Your AI-powered personal agent';
  String get password => 'Password';
  String get enterPwd => 'Enter Password';
  String get login => 'Log in';

  /// Signup
  String get firstName => 'First Name';
  String get lastName => 'Last Name';
  String get confirmPassword => 'Confirm Password';
  String get termsAndPrivacy => 'By signing up, you agree to our Terms of Service and Privacy Policy.';

  /// Home Screen
  String get readyToMake => 'Ready to make today productive?';
  String get welcomeBackSubtitle => 'Welcome back!';
  String get dailyInsight => 'Daily Insight';
  String get quickActions => 'Quick Actions';
  String get focusSession => 'Focus Session';
  String get todaysProgress => "Today's Progress";
  String get viewAll => 'View All';
  String get createTask => 'Create Task';
  String get todaysTasks => "Today's Tasks";
  String get noTasks => 'No tasks for today. Start by creating one!';

  /// Decision Analyzer
  String get decisionAnalyzer => 'Decision Analyzer';
  String get analyzeDecision => 'Analyze My Decision';
  String get decisionQuestion => 'What decision are you\nthinking about?';
  String get decisionDesc => 'Describe your situation in detail. The Mind Pilot will analyze and guide you.';
  String get importanceTitle => 'How important is this decision?';
  String get feelingTitle => 'How do you feel about this?';
  String get low => 'Low';
  String get high => 'High';

  /// Analysis Result
  String get analysisResult => 'Analysis Result';
  String get overallRecommendation => 'Overall Recommendation';
  String get analysisBreakdown => 'Analysis Breakdown';
  String get breakdownDesc => 'Based on your input, here is the structured clarity you need.';
  String get textColor => 'Text Color';
  String get continueAnalysis => 'Continue';
  String get done => 'Done';

  /// Journal
  String get myJournal => 'My Journal';
  String get noEntries => 'No journal entries yet.';
  String get deleteEntry => 'Delete Entry?';
  String get deleteConfirm => 'Are you sure you want to delete this journal entry? This action cannot be undone.';
  String get delete => 'Delete';
  String get cancel => 'Cancel';
  String get journalTip => 'Tip: Swipe left on any entry to delete it from your journal.';
  String get notificationTip => 'Swipe left on any alert or update to delete it.';

  /// AI Preferences
  String get aiPreferences => 'AI Preferences';
  String get responseStyle => 'Response Style';
  String get responseTone => 'AI Response Tone';
  String get toneDesc => 'Choose how detailed you want the AI responses to be.';
  String get personality => 'Personality';
  String get aiPersona => 'AI Persona';
  String get personaDesc => 'Select the primary personality trait of your AI assistant.';
  String get chatManagement => 'Chat Management';
  String get resetContext => 'Reset AI Context';
  String get resetContextDesc => 'Clear the current conversation memory for a fresh start.';
  String get savePreferences => 'Save Preferences';

  /// Personalization
  String get personalizeTitle => 'Personalize MindPilot';
  String get personalizeDesc => 'Select your main focus areas.\nYou can choose as many as you like.';
  String get skip => 'Skip';
  String get continueBtn => 'Continue';

  /// App Preferences
  String get appPreferences => 'App Preferences';
  String get appearance => 'Appearance';
  String get notifications => 'Notifications';
  String get pushNotifications => 'Push Notifications';
  String get taskReminder => '9 PM Task Reminder';
  String get emailNotifications => 'Email Notifications';
  String get lightMode => 'Light Mode';
  String get darkMode => 'Dark Mode';
  String get systemDefault => 'System Default';

  /// Status & Notifications
  String get aiContextReset => 'AI context reset successfully.';
  String get preferencesSaved => 'AI preferences saved!';
  String get entryDeleted => 'Entry removed from journal';
  String get entryAdded => 'Entry added successfully';
  String get errorSaving => 'Error saving preferences';
  String get pleaseDescribe => 'Please describe your situation first.';

  /// Task Creation
  String get createTaskTitle => 'Create New Task';
  String get taskAccomplish => 'What do you want to accomplish?';
  String get taskDescHint => 'Setting clear tasks helps you stay focused and productive.';
  String get taskTitleLabel => 'Task Title';
  String get taskTitleHint => 'e.g., Morning Meditation';
  String get taskDescriptionLabel => 'Description (Optional)';
  String get taskDescriptionHint => 'Details about your task...';
  String get startTimeLabel => 'Starting Time';
  String get setStartTime => 'Set Start Time';
  String get durationLabel => 'Duration';
  String get taskCreated => 'Task created successfully!';
  String get enterTaskTitle => 'Please enter a task title';
  String get checkInternet => 'Please check your internet connection and try again.';
}
