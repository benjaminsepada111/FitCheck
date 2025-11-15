/// Temporary storage for onboarding data before saving to Firebase
class OnboardingData {
  String? name;
  String? bio;
  List<String> hobbies = [];
  String? gender;
  DateTime? birthDate;
  int? weight;
  int? height;

  OnboardingData();

  bool get isComplete {
    return name != null &&
        gender != null &&
        birthDate != null &&
        weight != null &&
        height != null;
  }
}
