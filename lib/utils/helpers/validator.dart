import '../../export.dart';

class Validator {
  const Validator();

  static String? Function(String?) phone({int length = 11}) {
    return (String? value) {
      if (value!.length == length) {
        return null;
      }
      return "Please enter a valid $length-digit phone number";
    };
  }

  static String? bvn(String? value) {
    final regex = RegExp(r"^\d{11}$");
    value = harmonize(value);
    if (value.isEmpty || !regex.hasMatch(value)) {
      return "please enter a valid bvn number";
    }
    return null;
  }

  static String? email(String? value) {
    const Pattern emailPattern =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    final regex = RegExp(emailPattern.toString());
    value = harmonize(value).trim();
    if (value.isEmpty || !regex.hasMatch(value)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  static bool isEmailValid(String? email) {
    final emailRegex = RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    );
    return emailRegex.hasMatch(email!);
  }

  static String? Function(String?) string({
    int minLength = 1,
    int? maxLength,
    String? error,
  }) {
    return (String? value) {
      value = harmonize(value);

      if (value.isEmpty && value.length < minLength) {
        return error ?? "Field is required.";
      }

      if (maxLength != null) {
        if (minLength == maxLength && value.length != minLength) {
          return "Field must be $minLength characters";
        }
        if (value.length < minLength || value.length > maxLength) {
          return "Field must be $minLength-$maxLength characters";
        }
      }
      if (value.length < minLength) {
        return "Field must have a minimum of $minLength characters";
      }
      if (maxLength != null && value.length < maxLength) {
        return "Field must not have more than $maxLength characters";
      }
      return null;
    };
  }

  static String? dateOfBirthValidator(DateTime? selectedDate) {
    if (selectedDate == null) {
      return 'Field is required.';
    }

    final day = selectedDate.day;
    final month = selectedDate.month;
    final year = selectedDate.year;

    if (day > 31 || month > 12 || year < 1900) {
      return 'Field must be a valid date';
    }

    return null; // Return null when validation passes
  }

  static String date(String? value) {
    const error = "Field must be a valid date";
    value = harmonize(value);
    if (value.isEmpty) {
      return "Field is required.";
    }
    if (value.length != 10) {
      return error;
    }
    final day = value.substring(0, 2).toInt();
    final month = value.substring(3, 5).toInt();
    final year = value.substring(6, 10).toInt();
    if (day == -1 ||
        month == -1 ||
        year == -1 ||
        day > 31 ||
        month > 12 ||
        year < 1900) {
      return error;
    }
    return '';
  }

  static String Function(String?) confirmPwd({
    String? password,
    String? error,
    int minLength = 8,
  }) {
    return (String? value) {
      value = harmonize(value);

      if (value.isEmpty) {
        return "Password is required";
      }
      if (value.length < minLength) {
        return "Password must be at least $minLength characters";
      }
      if (value != password) {
        return error ?? "Passwords do not match";
      }
      return '';
    };
  }

  static String? Function(String?) password({int minLength = 8}) {
    return (String? value) {
      value = harmonize(value);

      if (value.isEmpty) {
        return "Password is required";
      }
      if (value.length < minLength) {
        return "Password must be at least $minLength characters";
      }
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        return 'Password must contain at least one uppercase letter.';
      }
      if (!RegExp(r'[!@#$&*]').hasMatch(value)) {
        return 'Password must contain at least one special character (!@#&*).';
      }
      if (!RegExp(r'[a-zA-Z0-9]').hasMatch(value)) {
        return 'Password must contain alphanumeric characters.';
      }
      return null;
    };
  }

  static String? Function(String?) amount([double? minAmount, String? error]) {
    return (String? value) {
      value = harmonize(value);
      if (value.isEmpty) {
        return error ?? "Amount is required.";
      }

      final amount = double.tryParse(value);
      if (amount == null) {
        return error ?? "Invalid Amount.";
      }

      if (minAmount != null && amount < minAmount) {
        return error ?? "Amount can't be less than ${minAmount.toInt()}";
      }

      return null;
    };
  }

  static String harmonize(String? value) =>
      value == null ? "" : value.replaceAll(",", "").trim();
}

enum InputType { txt, date, money, tel, pwd, num, email }
