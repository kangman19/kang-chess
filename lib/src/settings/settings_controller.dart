import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/board/board_theme.dart';
import '../ui/board/piece_set.dart';

/// Persisted user preferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs)
      : _theme = BoardTheme.byId(_prefs.getString(_kTheme)),
        _pieceSet = PieceSet.byName(_prefs.getString(_kPieces)),
        _showCoordinates = _prefs.getBool(_kCoords) ?? true,
        _showLegalMoves = _prefs.getBool(_kLegal) ?? true,
        _highlightLastMove = _prefs.getBool(_kLastMove) ?? true,
        _premovesEnabled = _prefs.getBool(_kPremoves) ?? true,
        _reviewDepth = _prefs.getInt(_kDepth) ?? 14;

  static Future<SettingsController> load() async =>
      SettingsController(await SharedPreferences.getInstance());

  static const _kTheme = 'board_theme';
  static const _kPieces = 'piece_set';
  static const _kCoords = 'show_coordinates';
  static const _kLegal = 'show_legal_moves';
  static const _kLastMove = 'highlight_last_move';
  static const _kPremoves = 'premoves_enabled';
  static const _kDepth = 'review_depth';

  static const reviewDepths = [10, 14, 18, 22];

  final SharedPreferences _prefs;

  BoardTheme _theme;
  PieceSet _pieceSet;
  bool _showCoordinates;
  bool _showLegalMoves;
  bool _highlightLastMove;
  bool _premovesEnabled;
  int _reviewDepth;

  BoardTheme get theme => _theme;
  PieceSet get pieceSet => _pieceSet;
  bool get showCoordinates => _showCoordinates;
  bool get showLegalMoves => _showLegalMoves;
  bool get highlightLastMove => _highlightLastMove;
  bool get premovesEnabled => _premovesEnabled;
  int get reviewDepth => _reviewDepth;

  set theme(BoardTheme value) {
    _theme = value;
    _prefs.setString(_kTheme, value.id);
    notifyListeners();
  }

  set pieceSet(PieceSet value) {
    _pieceSet = value;
    _prefs.setString(_kPieces, value.name);
    notifyListeners();
  }

  set showCoordinates(bool value) {
    _showCoordinates = value;
    _prefs.setBool(_kCoords, value);
    notifyListeners();
  }

  set showLegalMoves(bool value) {
    _showLegalMoves = value;
    _prefs.setBool(_kLegal, value);
    notifyListeners();
  }

  set highlightLastMove(bool value) {
    _highlightLastMove = value;
    _prefs.setBool(_kLastMove, value);
    notifyListeners();
  }

  set premovesEnabled(bool value) {
    _premovesEnabled = value;
    _prefs.setBool(_kPremoves, value);
    notifyListeners();
  }

  set reviewDepth(int value) {
    _reviewDepth = value;
    _prefs.setInt(_kDepth, value);
    notifyListeners();
  }
}
