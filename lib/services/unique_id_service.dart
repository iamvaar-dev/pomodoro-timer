import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for generating unique IDs consistently across the application
class UniqueIdService {
  static final UniqueIdService _instance = UniqueIdService._internal();
  factory UniqueIdService() => _instance;
  UniqueIdService._internal();

  static const Uuid _uuid = Uuid();

  /// Generate a unique task ID using UUID v4
  static String generateTaskId() {
    return _uuid.v4();
  }

  /// Generate a deterministic ID based on content (for deduplication)
  static String generateContentHash(String title, String? notes, DateTime? dueDate, bool isCompleted) {
    final content = '$title|${notes ?? ''}|${dueDate?.toIso8601String() ?? ''}|$isCompleted';
    final bytes = utf8.encode(content.toLowerCase().trim());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars for shorter hash
  }

  /// Check if two tasks have the same content (for duplicate detection)
  static bool hasSameContent(
    String title1, String? notes1, DateTime? dueDate1, bool isCompleted1,
    String title2, String? notes2, DateTime? dueDate2, bool isCompleted2,
  ) {
    return title1.trim().toLowerCase() == title2.trim().toLowerCase() &&
           (notes1?.trim() ?? '') == (notes2?.trim() ?? '') &&
           _isSameDate(dueDate1, dueDate2) &&
           isCompleted1 == isCompleted2;
  }

  /// Compare dates ignoring time components
  static bool _isSameDate(DateTime? date1, DateTime? date2) {
    if (date1 == null && date2 == null) return true;
    if (date1 == null || date2 == null) return false;
    
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Validate that an ID is a valid UUID
  static bool isValidUuid(String id) {
    try {
      // Check if it matches UUID v4 pattern
      final regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      return regex.hasMatch(id.toLowerCase());
    } catch (e) {
      return false;
    }
  }
}