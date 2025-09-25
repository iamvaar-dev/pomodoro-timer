import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  AccessCredentials? _credentials;

  // Google Tasks API scope - now that basic auth is working
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/tasks',
  ];

  /// Initialize the Google Sign-In with platform-specific client ID
  Future<void> initialize() async {
    try {
      await dotenv.load();
      
      String? clientId;
      
      // Get platform-specific client ID from environment
      if (Platform.isAndroid) {
        clientId = dotenv.env['GOOGLE_ANDROID_CLIENT_ID'];
      } else if (Platform.isIOS) {
        clientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
      } else {
        // For web or other platforms
        clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      }

      if (clientId == null || clientId.isEmpty || clientId.contains('your_')) {
        String platform = Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'Web';
        throw Exception('Google Client ID not configured for $platform. Please set up your OAuth credentials in .env file');
      }

      debugPrint('Initializing Google Sign-In for ${Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'Web'}');
      debugPrint('Using client ID: ${clientId.substring(0, 20)}...');

      _googleSignIn = GoogleSignIn(
        clientId: clientId,
        scopes: _scopes,
        // Force browser-based authentication on iOS for better compatibility
        forceCodeForRefreshToken: Platform.isIOS,
      );

      // Listen for sign-in state changes
      _googleSignIn!.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
        _currentUser = account;
      });

      // Try to sign in silently on app start
      await _googleSignIn!.signInSilently();
    } catch (e) {
      debugPrint('Error initializing Google Auth: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  /// On iOS, this will open Safari/browser for authentication
  /// On Android, this will use the native Google Sign-In flow
  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      // On iOS, this will automatically open Safari for authentication
      // The google_sign_in package handles the browser flow automatically
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account != null) {
        _currentUser = account;
        await _getAccessCredentials();
        debugPrint('Successfully signed in: ${account.email}');
      } else {
        debugPrint('Sign in was canceled or failed');
      }
      return account;
    } catch (e) {
      debugPrint('Error signing in: $e');
      
      // Check for specific OAuth errors
      String errorString = e.toString().toLowerCase();
      if (errorString.contains('403') || errorString.contains('access_denied')) {
        debugPrint('OAuth 403 Error: This usually means:');
        debugPrint('1. The OAuth consent screen is not properly configured');
        debugPrint('2. The requested scopes are not approved in Google Cloud Console');
        debugPrint('3. The app is not verified for the requested scopes');
      }
      
      // Provide platform-specific error guidance
      if (Platform.isIOS) {
        debugPrint('iOS: Make sure you have configured the URL scheme in Info.plist');
        debugPrint('iOS: The authentication will open in Safari browser');
        debugPrint('iOS: Check that your Google Cloud Console has iOS client ID configured');
      }
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _currentUser = null;
      _credentials = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Force re-authentication to get updated scopes
  Future<GoogleSignInAccount?> reAuthenticate() async {
    try {
      debugPrint('Re-authenticating to get updated scopes...');
      await signOut();
      // Small delay to ensure sign out is complete
      await Future.delayed(const Duration(milliseconds: 500));
      return await signIn();
    } catch (e) {
      debugPrint('Error re-authenticating: $e');
      return null;
    }
  }

  /// Get access credentials for API calls
  Future<AccessCredentials?> _getAccessCredentials() async {
    try {
      if (_currentUser == null) return null;

      final GoogleSignInAuthentication auth = await _currentUser!.authentication;
      
      _credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          auth.accessToken!,
          DateTime.now().toUtc().add(const Duration(hours: 1)), // Must be UTC
        ),
        auth.idToken,
        _scopes,
      );

      return _credentials;
    } catch (e) {
      debugPrint('Error getting access credentials: $e');
      return null;
    }
  }

  /// Get current access credentials
  Future<AccessCredentials?> getCredentials() async {
    if (_credentials == null && _currentUser != null) {
      await _getAccessCredentials();
    }
    return _credentials;
  }

  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Get current user
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Get user email
  String? get userEmail => _currentUser?.email;

  /// Get user display name
  String? get userDisplayName => _currentUser?.displayName;

  /// Get user photo URL
  String? get userPhotoUrl => _currentUser?.photoUrl;

  /// Refresh access token if needed
  Future<bool> refreshTokenIfNeeded() async {
    try {
      if (_credentials == null || _currentUser == null) return false;

      // Check if token is close to expiry (refresh 5 minutes before)
      final now = DateTime.now();
      final expiryBuffer = _credentials!.accessToken.expiry.subtract(const Duration(minutes: 5));
      
      if (now.isAfter(expiryBuffer)) {
        await _getAccessCredentials();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
  }

  /// Handle authentication errors
  String getAuthErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'sign_in_canceled':
          if (Platform.isIOS) {
            return 'Sign in was canceled. On iOS, authentication opens in Safari browser.';
          }
          return 'Sign in was canceled';
        case 'sign_in_failed':
          if (Platform.isIOS) {
            return 'Sign in failed. Please ensure your iOS OAuth Client ID is correctly configured in the Google Cloud Console and Info.plist.';
          }
          return 'Sign in failed. Please try again';
        case 'network_error':
          return 'Network error. Please check your connection';
        case 'sign_in_required':
          return 'Please sign in to access Google Tasks';
        default:
          if (Platform.isIOS) {
            return 'Authentication error: ${error.message}. On iOS, make sure the URL scheme is configured correctly.';
          }
          return 'Authentication error: ${error.message}';
      }
    }
    return 'An unexpected error occurred during authentication';
  }

  /// Get platform-specific setup instructions
  String getSetupInstructions() {
    if (Platform.isIOS) {
      return '''
iOS Setup Instructions:
1. Configure your iOS OAuth Client ID in the Google Cloud Console
2. Update the URL scheme in ios/Runner/Info.plist with your client ID
3. Authentication will open in Safari browser
4. Make sure your .env file contains the correct GOOGLE_IOS_CLIENT_ID
''';
    } else if (Platform.isAndroid) {
      return '''
Android Setup Instructions:
1. Configure your Android OAuth Client ID in the Google Cloud Console
2. Make sure your .env file contains the correct GOOGLE_ANDROID_CLIENT_ID
3. Authentication uses the native Google Sign-In flow
''';
    } else {
      return '''
Web Setup Instructions:
1. Configure your Web OAuth Client ID in the Google Cloud Console
2. Make sure your .env file contains the correct GOOGLE_WEB_CLIENT_ID
''';
    }
  }
}