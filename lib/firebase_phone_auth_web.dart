// lib/firebase_phone_auth_web.dart

import 'dart:js_util' as js_util;

import 'package:js/js.dart';

@JS('firebase.auth.RecaptchaVerifier')
class RecaptchaVerifier {
  external factory RecaptchaVerifier(String container, [dynamic parameters]);
  external dynamic render();
}

@JS('firebase.auth')
external dynamic get firebaseAuth;

@JS()
class ConfirmationResult {
  external Promise confirm(String code);
}

@JS()
class Promise {
  external void then(
    void Function(dynamic) onFulfilled, [
    Function? onRejected,
  ]);
}

class FirebasePhoneAuthWeb {
  dynamic recaptchaVerifier;
  dynamic confirmationResult;

  void initRecaptcha() {
    recaptchaVerifier = RecaptchaVerifier(
      'recaptcha-container',
      js_util.jsify({
        'size': 'invisible',
        'callback': (dynamic response) {
          // reCAPTCHA success callback
          print('reCAPTCHA solved!');
        },
      }),
    );

    // render widget
    recaptchaVerifier.render();
  }

  Future<void> sendOTP(String phoneNumber) async {
    final auth = firebaseAuth;

    confirmationResult = await js_util.promiseToFuture(
      auth.signInWithPhoneNumber(phoneNumber, recaptchaVerifier),
    );
  }

  Future<void> confirmOTP(String code) async {
    if (confirmationResult == null) throw Exception('No confirmation result');

    await js_util.promiseToFuture(confirmationResult.confirm(code));
  }
}
