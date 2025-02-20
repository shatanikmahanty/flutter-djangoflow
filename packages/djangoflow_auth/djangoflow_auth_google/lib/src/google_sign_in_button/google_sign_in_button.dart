export 'stub/google_sign_in_button_stub.dart'
    if (dart.library.html) './web/google_sign_in_button_web.dart'
    if (dart.library.io) './mobile/google_sign_in_button_mobile.dart';

import 'package:flutter/material.dart';

import 'gsi_button_config_wrapper/gsi_button_config_wrapper.dart';
export 'gsi_button_config_wrapper/gsi_button_config_wrapper.dart';
export 'google_sign_in_web_button.dart';

abstract class BaseGoogleSignInButton extends StatelessWidget {
  const BaseGoogleSignInButton(
      {super.key,
      this.onPressed,
      required this.child,
      this.configurationWrapper});
  final VoidCallback? onPressed;

  /// The configuration wrapper for the button. Used for web-only.
  final GSIButtonConfigWrapper? configurationWrapper;

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
