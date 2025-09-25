import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  AccessCredentials? _credentials;
  
  // Stream controller for authentication state changes
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  
  // Keys for SharedPreferences
  static const String _isSignedInKey = 'google_auth_is_signed_in';
  static const String _userEmailKey = 'google_auth_user_email';
  static const String _userDisplayNameKey = 'google_auth_user_display_name';
  static const String _userPhotoUrlKey = 'google_auth_user_photo_url';

  // Google Tasks API scope - now that basic auth is working
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/tasks',
  ];

  /// Stream of authentication state changes
  Stream<bool> get authStateChanges => _authStateController.stream;

  /// Save authentication state to persistent storage
  Future<void> _saveAuthState(GoogleSignInAccount? account) async {
    final prefs = await SharedPreferences.getInstance();
    if (account != null) {
      await prefs.setBool(_isSignedInKey, true);
      await prefs.setString(_userEmailKey, account.email);
      await prefs.setString(_userDisplayNameKey, account.displayName ?? '');
      await prefs.setString(_userPhotoUrlKey, account.photoUrl ?? '');
      debugPrint('Saved authentication state for: ${account.email}');
    } else {
      await prefs.setBool(_isSignedInKey, false);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userDisplayNameKey);
      await prefs.remove(_userPhotoUrlKey);
      debugPrint('Cleared authentication state');
    }
    _authStateController.add(account != null);
  }

  /// Load authentication state from persistent storage
  Future<bool> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isSignedIn = prefs.getBool(_isSignedInKey) ?? false;
    if (isSignedIn) {
      final email = prefs.getString(_userEmailKey);
      debugPrint('Loaded stored authentication state for: $email');
    }
    return isSignedIn;
  }

  /// Initialize the Google Sign-In with platform-specific client ID
  Future<void> initialize() async {
    try {
      await dotenv.load();
      
      String? clientId;
      String platformName;
      
      // Get platform-specific client ID from environment
      if (Platform.isAndroid) {
        clientId = dotenv.env['GOOGLE_ANDROID_CLIENT_ID'];
        platformName = 'Android';
      } else if (Platform.isIOS) {
        clientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
        platformName = 'iOS';
      } else if (Platform.isMacOS) {
        // macOS uses the same implementation as iOS but needs its own client ID
        clientId = dotenv.env['GOOGLE_MACOS_CLIENT_ID'] ?? dotenv.env['GOOGLE_IOS_CLIENT_ID'];
        platformName = 'macOS';
      } else {
        // For web or other platforms
        clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
        platformName = 'Web';
      }

      if (clientId == null || clientId.isEmpty || clientId.contains('your_')) {
        throw Exception('Google Client ID not configured for $platformName. Please set up your OAuth credentials in .env file');
      }

      debugPrint('Initializing Google Sign-In for $platformName');
      debugPrint('Using client ID: ${clientId.substring(0, 20)}...');

      // Configure Google Sign-In based on platform
      if (Platform.isAndroid) {
        // For Android, don't use clientId parameter - it uses the SHA-1 fingerprint instead
        _googleSignIn = GoogleSignIn(
          scopes: _scopes,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        // For iOS and macOS, use the clientId parameter
        // macOS uses the same google_sign_in_ios implementation
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
          // Force browser-based authentication for better compatibility
          forceCodeForRefreshToken: true,
        );
      } else {
        // For Web and other platforms
        _googleSignIn = GoogleSignIn(
          clientId: clientId,
          scopes: _scopes,
        );
      }

      // Listen for sign-in state changes
      _googleSignIn!.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
        _currentUser = account;
        _saveAuthState(account);
      });

      // Check stored authentication state first
      final hasStoredAuth = await _loadAuthState();
      
      // Try to sign in silently on app start
      final silentSignInResult = await _googleSignIn!.signInSilently();
      
      // If silent sign-in failed but we have stored auth state, emit the stored state
      if (silentSignInResult == null && hasStoredAuth) {
        debugPrint('Silent sign-in failed, but stored auth state indicates user was signed in');
        // The stored state will be used by the UI until the user manually signs in again
        _authStateController.add(true);
      } else if (silentSignInResult != null) {
        debugPrint('Silent sign-in successful');
        _currentUser = silentSignInResult;
        await _saveAuthState(silentSignInResult);
      } else {
        debugPrint('No stored authentication and silent sign-in failed');
        await _saveAuthState(null);
      }
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
        await _saveAuthState(account);
        debugPrint('Successfully signed in: ${account.email}');
      } else {
        debugPrint('Sign in was canceled or failed');
        await _saveAuthState(null);
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
      } else if (Platform.isMacOS) {
        debugPrint('macOS: Make sure you have configured the URL scheme in Info.plist');
        debugPrint('macOS: The authentication will open in the default browser');
        debugPrint('macOS: Check that your Google Cloud Console has macOS client ID configured');
        debugPrint('macOS: Ensure keychain sharing is enabled in entitlements');
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
      await _saveAuthState(null);
      debugPrint('Successfully signed out');
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

  /// Check if user is signed in (checks both current user and stored state)
  bool get isSignedIn => _currentUser != null;
  
  /// Check if user is signed in based on stored state (async)
  Future<bool> get isSignedInStored async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSignedInKey) ?? false;
  }

  /// Get current user
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Get user email (from current user or stored data)
  String? get userEmail => _currentUser?.email;
  
  /// Get user email from stored data (async)
  Future<String?> get userEmailStored async {
    if (_currentUser?.email != null) return _currentUser!.email;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Get user display name (from current user or stored data)
  String? get userDisplayName => _currentUser?.displayName;
  
  /// Get user display name from stored data (async)
  Future<String?> get userDisplayNameStored async {
    if (_currentUser?.displayName != null) return _currentUser!.displayName;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDisplayNameKey);
  }

  /// Get user photo URL (from current user or stored data)
  String? get userPhotoUrl => _currentUser?.photoUrl;
  
  /// Get user photo URL from stored data (async)
  Future<String?> get userPhotoUrlStored async {
    if (_currentUser?.photoUrl != null) return _currentUser!.photoUrl;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhotoUrlKey);
  }

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
          } else if (Platform.isMacOS) {
            return 'Sign in was canceled. On macOS, authentication opens in the default browser.';
          }
          return 'Sign in was canceled';
        case 'sign_in_failed':
          if (Platform.isIOS) {
            return 'Sign in failed. Please ensure your iOS OAuth Client ID is correctly configured in the Google Cloud Console and Info.plist.';
          } else if (Platform.isMacOS) {
            return 'Sign in failed. Please ensure your macOS OAuth Client ID is correctly configured in the Google Cloud Console and Info.plist, and keychain sharing is enabled.';
          }
          return 'Sign in failed. Please try again';
        case 'network_error':
          return 'Network error. Please check your connection';
        case 'sign_in_required':
          return 'Please sign in to access Google Tasks';
        default:
          if (Platform.isIOS) {
            return 'Authentication error: ${error.message}. On iOS, make sure the URL scheme is configured correctly.';
          } else if (Platform.isMacOS) {
            return 'Authentication error: ${error.message}. On macOS, make sure the URL scheme is configured correctly and keychain sharing is enabled.';
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
    } else if (Platform.isMacOS) {
      return '''
macOS Setup Instructions:
1. Configure your macOS OAuth Client ID in the Google Cloud Console (or use iOS client ID)
2. Update the URL scheme in macos/Runner/Info.plist with your client ID
3. Enable keychain sharing in macos/Runner/DebugProfile.entitlements and macos/Runner/Release.entitlements
4. Authentication will open in the default browser
5. Make sure your .env file contains GOOGLE_MACOS_CLIENT_ID (or GOOGLE_IOS_CLIENT_ID will be used as fallback)
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
  
  /// Dispose of resources
  void dispose() {
    _authStateController.close();
  }
}