// lib/services/guest_session.dart
import 'package:flutter/material.dart';

/// Session-based guest account management
/// Creates local guest sessions that are lost when browser closes
class GuestSession {
  static String? _guestId;
  static String? _guestName;
  static bool _isGuest = false;
  static final List<VoidCallback> _listeners = [];

  /// Get or create a guest session ID
  static String getGuestId() {
    if (_guestId == null) {
      _guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
    }
    return _guestId!;
  }

  /// Get or create a guest name
  static String getGuestName() {
    if (_guestName == null) {
      _guestName = 'Guest User';
    }
    return _guestName!;
  }

  /// Check if current session is a guest
  static bool get isGuest => _isGuest;

  /// Start a new guest session
  static void startGuestSession() {
    _isGuest = true;
    _guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
    _guestName = 'Guest User';
    _notifyListeners();
  }

  /// Clear the current guest session
  static void clearSession() {
    _guestId = null;
    _guestName = null;
    _isGuest = false;
    _notifyListeners();
  }

  /// Add a listener for session changes
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of changes
  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Generate a random string for unique guest IDs
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }

  /// Get guest display info
  static Map<String, String> getGuestInfo() {
    // Ensure we have a guest ID
    final guestId = getGuestId();
    return {
      'id': guestId,
      'name': getGuestName(),
      'shortId': guestId.substring(0, 8),
    };
  }
}
