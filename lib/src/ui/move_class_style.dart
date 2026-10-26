import 'package:flutter/material.dart';

import '../domain/move_classification.dart';

extension MoveClassStyle on MoveClass {
  Color get color => switch (this) {
        MoveClass.brilliant => const Color(0xFF1BACA6),
        MoveClass.great => const Color(0xFF5C8BB0),
        MoveClass.best => const Color(0xFF7FA650),
        MoveClass.excellent => const Color(0xFF96BC4B),
        MoveClass.good => const Color(0xFF8E9F7E),
        MoveClass.book => const Color(0xFFA88865),
        MoveClass.inaccuracy => const Color(0xFFF0C15C),
        MoveClass.mistake => const Color(0xFFE6912C),
        MoveClass.miss => const Color(0xFFEE6B55),
        MoveClass.blunder => const Color(0xFFCA3431),
      };

  /// Short badge text drawn on the board and in move lists.
  String get badge => switch (this) {
        MoveClass.best => '★',
        MoveClass.excellent => '!',
        MoveClass.good => '✓',
        MoveClass.book => 'B',
        _ => symbol,
      };
}
