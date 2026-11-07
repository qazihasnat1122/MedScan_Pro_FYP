enum AppLanguage { en, ur }

class AppStrings {
  final AppLanguage language;
  AppStrings(this.language);

  bool get isUrdu => language == AppLanguage.ur;

  // General & Common
  String get appTitle => isUrdu ? 'میڈ اسکین پرو' : 'MedScan Pro';
  String get save => isUrdu ? 'محفوظ کریں' : 'Save';
  String get cancel => isUrdu ? 'منسوخ کریں' : 'Cancel';
  String get delete => isUrdu ? 'حذف کریں' : 'Delete';
  String get edit => isUrdu ? 'تبدیل کریں' : 'Edit';
  String get done => isUrdu ? 'مکمل' : 'Done';
  String get close => isUrdu ? 'بند کریں' : 'Close';
  String get search => isUrdu ? 'تلاش کریں...' : 'Search...';
  String get loading => isUrdu ? 'براہ کرم انتظار کریں...' : 'Please wait...';
  String get error => isUrdu ? 'خرابی پیش آگئی' : 'Error occurred';
  String get success => isUrdu ? 'کامیاب' : 'Success';

  // Navigation
  String get navHome => isUrdu ? 'ڈیش بورڈ' : 'Dashboard';
  String get navMedicines => isUrdu ? 'دوائیاں' : 'Medicines';
  String get navScan => isUrdu ? 'اسکین' : 'Scan';
  String get navRecords => isUrdu ? 'ریکارڈز' : 'Records';
  String get navAlerts => isUrdu ? 'انتباہات' : 'Alerts';
  String get navChat => isUrdu ? 'اے آئی چیٹ' : 'AI Chat';
  String get navProfile => isUrdu ? 'پروفائل' : 'Profile';

  // Theme & Appearance
  String get appearance => isUrdu ? 'ظاہری شکل و صورت' : 'Appearance';
  String get themeMode => isUrdu ? 'تھیم موڈ' : 'Theme Mode';
  String get lightTheme => isUrdu ? 'روشن موڈ (Light)' : 'Bright Light Mode';
  String get darkTheme => isUrdu ? 'ڈارک موڈ (Dark)' : 'Deep Dark Mode';
  String get selectTheme => isUrdu ? 'تھیم کا انتخاب کریں' : 'Select Theme';

  // Language
  String get languageSettings =>
      isUrdu ? 'زبان کی ترتیبات' : 'Language Settings';
  String get selectLanguage => isUrdu ? 'زبان منتخب کریں' : 'Select Language';
  String get english => 'English';
  String get urdu => 'اردو (Urdu)';

  // Alarms & Reminders
  String get alarmsAndReminders =>
      isUrdu ? 'دوا کے الارم اور یاد دہانی' : 'Medicine Alarms & Reminders';
  String get testAlarm => isUrdu ? 'ٹیسٹ الارم بجائیں' : 'Test Alarm Now';
  String get alarmScheduled =>
      isUrdu ? 'الارم کامیابی سے شیڈول ہو گیا' : 'Alarm scheduled successfully';
  String get testAlarmTriggered =>
      isUrdu ? 'ٹیسٹ الارم الرٹ بھیج دیا گیا!' : 'Test alarm alert triggered!';
  String get reminderTimes => isUrdu ? 'یاد دہانی کے اوقات' : 'Reminder Times';
  String get addReminderTime => isUrdu ? 'نیا وقت شامل کریں' : 'Add Dose Time';
  String get takeWithWater => isUrdu ? 'پانی کے ساتھ لیں' : 'Take with water';
  String get timeForDose => isUrdu
      ? 'دوا لینے کا وقت ہو گیا ہے!'
      : 'Time to take your medication dose!';

  // Auth Screen
  String get welcomeBack => isUrdu ? 'خوش آمدید' : 'Welcome Back';
  String get signInSubtitle => isUrdu
      ? 'اپنے اکاؤنٹ میں سائن ان کریں'
      : 'Sign in to access your medication profile';
  String get createAccountSubtitle =>
      isUrdu ? 'نئے اکاؤنٹ کی رجسٹریشن' : 'Register your medical account';
  String get email => isUrdu ? 'ای میل ایڈریس' : 'Email Address';
  String get password => isUrdu ? 'پاس ورڈ' : 'Password';
  String get fullName => isUrdu ? 'مکمل نام' : 'Full Name';
  String get signIn => isUrdu ? 'سائن ان کریں' : 'Sign In';
  String get signUp => isUrdu ? 'رجسٹر کریں' : 'Sign Up';
  String get dontHaveAccount =>
      isUrdu ? 'کیا اکاؤنٹ نہیں ہے؟' : "Don't have an account?";
  String get alreadyHaveAccount =>
      isUrdu ? 'پہلے سے اکاؤنٹ موجود ہے؟' : 'Already have an account?';
  String get consumerPatient => isUrdu ? 'صارف / مریض' : 'Consumer / Patient';
  String get manufacturer => isUrdu ? 'دوا ساز کمپنی' : 'Manufacturer';

  // Medicines Screen
  String get myMedicines => isUrdu ? 'میری دوائیں' : 'My Medicines';
  String get addMedicine => isUrdu ? 'نئی دوا شامل کریں' : 'Add Medication';
  String get medicineName => isUrdu ? 'دوا کا نام' : 'Medicine Name';
  String get strength =>
      isUrdu ? 'طاقت (مثلاً 500 ملی گرام)' : 'Strength (e.g. 500mg)';
  String get dosage =>
      isUrdu ? 'خوراک (مثلاً 1 گولی)' : 'Dosage (e.g. 1 Tablet)';
  String get frequency => isUrdu ? 'تعدد (کتنی بار)' : 'Frequency';
  String get mealInstruction => isUrdu ? 'کھانے کی ہدایات' : 'Meal Instruction';
  String get beforeMeal => isUrdu ? 'کھانے سے پہلے' : 'Before Meal';
  String get afterMeal => isUrdu ? 'کھانے کے بعد' : 'After Meal';
  String get withMeal => isUrdu ? 'کھانے کے ساتھ' : 'With Meal';
  String get noMedicinesYet => isUrdu
      ? 'ابھی تک کوئی دوا شامل نہیں کی گئی'
      : 'No medications registered yet';
  String get saveMedication => isUrdu ? 'دوا محفوظ کریں' : 'Save Medication';
  String get editReminders =>
      isUrdu ? 'الارم اور اوقات تبدیل کریں' : 'Edit Reminders & Alarms';

  // Scan Screen
  String get scanMedicine =>
      isUrdu ? 'دوا اسکین کریں' : 'Scan Medicine';
  String get scanBarcodeOrQr =>
      isUrdu ? 'بار کوڈ یا کیو آر اسکین کریں' : 'Scan Barcode or QR';
  String get ocrCamera =>
      isUrdu ? 'پیکیجنگ کی تصویر لیں' : 'Capture Packaging (OCR)';
  String get verifyingMedicine =>
      isUrdu ? 'دوا کی اصلیت چیک کی جا رہی ہے...' : 'Verifying authenticity...';
  String get authenticMedicine =>
      isUrdu ? 'اصلی دوا تصدیق شدہ' : 'Authentic Medicine Verified';
  String get counterfeitWarning =>
      isUrdu ? 'انتباہ: مشکوک یا جعلی دوا!' : 'Warning: Potential Counterfeit!';

  // Records & Emergency
  String get medicalRecords => isUrdu ? 'طبی ریکارڈز' : 'Medical Records';
  String get emergencyProfile =>
      isUrdu ? 'ہنگامی طبی پروفائل' : 'Emergency Profile';
  String get bloodGroup => isUrdu ? 'خون کا گروپ' : 'Blood Group';
  String get allergies => isUrdu ? 'الرجی' : 'Known Allergies';
  String get medicalConditions =>
      isUrdu ? 'بیماریاں یا طبی حالات' : 'Medical Conditions';
  String get emergencyContact =>
      isUrdu ? 'ہنگامی رابطہ نمبر' : 'Emergency Contact';

  // Safety & Alerts
  String get safetyAlerts =>
      isUrdu ? 'حفاظتی انتباہات اور نوٹس' : 'Safety Alerts & Recalls';
  String get noActiveAlerts => isUrdu
      ? 'کوئی فعال حفاظتی انتباہ نہیں ہے'
      : 'No active drug alerts or recalls';
  String get recallNotice =>
      isUrdu ? 'واپسی کا نوٹس (Recall)' : 'Recall Notice';

  // AI Chat
  String get aiAssistant =>
      isUrdu ? 'اے آئی ادویات معاون' : 'AI Medicine Assistant';
  String get askMedicationQuestion => isUrdu
      ? 'دوا یا نسخے کے متعلق سوال پوچھیں...'
      : 'Ask about dosages, interactions, food...';
  String get send => isUrdu ? 'بھیجیں' : 'Send';
  String get geminiKeyTitle =>
      isUrdu ? 'جیمنائی اے آئی کی (Gemini Key)' : 'Gemini LLM Key';
  String get voicePlayback => isUrdu ? 'آواز میں سنیں' : 'Listen with Audio';
  String get copyResponse => isUrdu ? 'جواب کاپی کریں' : 'Copy Response';
  String get aiDisclaimer => isUrdu
      ? 'اے آئی کی معلومات صرف حوالہ اور آگاہی کے لیے ہیں، یہ غلط ہو سکتی ہیں اور طبی تشخیص کا متبادل نہیں ہیں۔'
      : 'AI-generated info is for reference only and may be incorrect. It does not provide medical diagnosis or replace a doctor.';

  // Profile & Settings
  String get accountSettings =>
      isUrdu ? 'اکاؤنٹ اور ترتیبات' : 'Account & Settings';
  String get signOut => isUrdu ? 'لاگ آؤٹ' : 'Sign Out';
  String get confirmSignOut => isUrdu
      ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
      : 'Are you sure you want to sign out?';
}
