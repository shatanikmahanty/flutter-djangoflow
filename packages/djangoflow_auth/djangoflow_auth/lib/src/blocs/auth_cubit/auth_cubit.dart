import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:djangoflow_auth/src/blocs/auth_cubit/auth_cubit_base.dart';
import 'package:djangoflow_auth/src/exceptions/login_provider_not_found_exception.dart';
import 'package:djangoflow_auth/src/interfaces/social_login.dart';
import 'package:djangoflow_auth/src/models/social_login_type/social_login_type.dart';
import 'package:djangoflow_openapi/djangoflow_openapi.dart';

class AuthCubit extends HydratedAuthCubitBase {
  AuthApi? authApi;

  static AuthCubit get instance => _instance;
  static final AuthCubit _instance = AuthCubit._internal();
  AuthCubit._internal() : super(const AuthState.initial());

  @override
  AuthState? fromJson(Map<String, dynamic> json) => AuthState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(AuthState state) => state.toJson();

  /// Authenticate and request token for user from the Social Auth Provider
  /// eg, facebook, google etc.
  @override
  Future<R?> requestTokenFromSocialProvider<R>(SocialLoginType type) async {
    final provider = _firstWhereSocialLogin(type);
    if (provider == null) {
      throw _loginProviderNotFoundException(type);
    }

    final response = (await provider.login()) as R?;
    return response;
  }

  @override
  Future<void> logoutFromSocialProvider(SocialLoginType type) async {
    final socialLogin = _firstWhereSocialLogin(type);
    if (socialLogin == null) {
      throw _loginProviderNotFoundException(type);
    }

    await socialLogin.logout();
  }

  SocialLogin<dynamic>? _firstWhereSocialLogin(SocialLoginType type) =>
      socialLogins.firstWhereOrNull(
        (element) => element.type == type,
      );

  LoginProviderNotFoundException _loginProviderNotFoundException(
          SocialLoginType type,
          {String? message}) =>
      LoginProviderNotFoundException(
        message ?? 'Social Provider ${type.provider.name} was not found',
      );

  /// Logout user, also removes token from storage and logs out user from social logins
  @override
  Future<void> logout() async {
    for (final provider in socialLogins) {
      await provider.logout();
    }
    emit(
      const AuthState.unauthenticated(),
    );
  }

  /// Register or invite user to the system
  @override
  Future<UserIdentity?> registerOrInviteUser({
    required UserIdentityRequest userIdentityRequest,
  }) async =>
      _authApiChecker<UserIdentity?>(() async {
        final result = (await authApi?.authUsersCreate(
          userIdentityRequest: userIdentityRequest,
        ))
            ?.data;

        return result;
      });

  /// Request OTP for verification.
  @override
  Future<void> requestOTP({required OTPObtainRequest otpObtainRequest}) async =>
      _authApiChecker(
        () async => (
          await authApi?.authOtpCreate(
            oTPObtainRequest: otpObtainRequest,
          ),
        ),
      );

  /// Authenticates the user based on provided credentials (e.g., username+password or email+OTP etc)
  /// and logs them in by obtaining and processing a JWT token.
  @override
  Future<void> obtainTokenAndLogin({
    required TokenObtainRequest tokenObtainRequest,
  }) async =>
      _authApiChecker(() async {
        final tokenResult = (await authApi?.authTokenCreate(
          tokenObtainRequest: tokenObtainRequest,
        ))
            ?.data;
        final token = tokenResult?.token;

        await _loginUsingToken(token);
      });

  Future<void> _loginUsingToken(String? token) async {
    if (token != null) {
      emit(AuthState.authenticated(token: token));
    } else {
      throw Exception('Could not retrieve token');
    }
  }

  /// Login user with magic link. magiclink should not be empty
  /// It supports only email at the moment.
  @override
  Future<void> loginWithMagicLink({required String magiclink}) async {
    try {
      final credentials = utf8
          .decode(base64.decode(const Base64Codec().normalize(magiclink)))
          .split('/');

      await obtainTokenAndLogin(
        tokenObtainRequest: TokenObtainRequest(
          email: credentials[0],
          otp: credentials[1],
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Login user with social provider token data that was retrieved via [requestTokenFromSocialProvider]
  /// This will retrieve token from backend and login user
  @override
  Future<void> loginWithSocialProviderToken(
          {required SocialTokenObtainRequest socialTokenObtainRequest}) async =>
      _authApiChecker(() async {
        final result = (await authApi?.authSocialCreate(
                socialTokenObtainRequest: socialTokenObtainRequest))
            ?.data;
        if (result?.token != null) {
          _loginUsingToken(result!.token!);
        } else {
          throw Exception('Could not retrieve token for social login');
        }
      });

  @override
  Future<void> changePassword({
    required String id,
    required ChangePasswordRequest changePasswordRequest,
  }) =>
      _authApiChecker(() async {
        await authApi?.authUsersSetPasswordCreate(
          id: id,
          changePasswordRequest: changePasswordRequest,
        );
      });

  Future<T> _authApiChecker<T>(Future<T> Function() function) async {
    if (authApi == null) {
      throw Exception('AuthApi is not initialized');
    }
    return await function();
  }
}
