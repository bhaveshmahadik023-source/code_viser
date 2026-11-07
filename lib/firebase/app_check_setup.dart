
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> activateAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    // Web configuration
    providerWeb: kDebugMode
        ? WebDebugProvider()
        : ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_SITE_KEY'),

    // Android configuration
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );
}
