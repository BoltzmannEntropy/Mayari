import 'package:flutter_riverpod/flutter_riverpod.dart';

final highlightModeProvider = StateProvider<bool>((ref) => false);

final currentPageProvider = StateProvider<int>((ref) => 1);

final totalPagesProvider = StateProvider<int>((ref) => 0);

final selectedTextProvider = StateProvider<String?>((ref) => null);
