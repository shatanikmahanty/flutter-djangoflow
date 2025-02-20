import 'package:djangoflow_auth/djangoflow_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class FacebookSocialLogin extends SocialLogin<LoginResult> {
  final List<String> permissions;
  final LoginBehavior loginBehavior;

  FacebookSocialLogin({
    this.permissions = const ['email', 'public_profile'],
    this.loginBehavior = LoginBehavior.nativeWithFallback,
    required super.type,
  });
  @override
  Future<LoginResult?> login() async => await FacebookAuth.instance.login(
        loginBehavior: loginBehavior,
        permissions: permissions,
      );

  @override
  Future<void> logout() async {
    final accessToken = await FacebookAuth.instance.accessToken;
    if (accessToken != null) {
      await FacebookAuth.instance.logOut();
    }
  }
}
