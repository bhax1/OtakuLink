class AppValidators {
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Required';

    // 1. Length Check
    if (value.length < 6) return 'Must be at least 6 characters';

    return null; // Valid
  }

  static String? confirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (password != confirmPassword) return 'Passwords do not match';
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Required';

    // 1. Length Check
    if (value.length < 3) return 'Minimum 3 characters required';
    if (value.length > 20) return 'Maximum 20 characters allowed';

    // 2. Content Check (Letters, numbers, underscores, dots only)
    // (This automatically prevents emails, '@', and spaces)
    final validCharacters = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!validCharacters.hasMatch(value)) {
      return 'Only letters, numbers, underscores, and dots allowed';
    }

    // 3. Consecutive Characters Check
    if (value.contains('..') || value.contains('__')) {
      return 'Cannot contain consecutive dots or underscores';
    }

    // 4. Start/End Character Check
    if (value.startsWith('.') || value.endsWith('.')) {
      return 'Cannot start or end with a dot';
    }
    if (value.startsWith('_') || value.endsWith('_')) {
      return 'Cannot start or end with an underscore';
    }

    // 5. Reserved Words Check (Expanded slightly for security)
    final reservedWords = ['admin', 'root', 'system', 'support', 'mod'];
    if (reservedWords.contains(value.toLowerCase())) {
      return 'This username is reserved';
    }

    return null; // Valid
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Required';

    // 1. Robust standard email regex (Fixes the TLD length bug)
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';

    return null; // Valid
  }
}
