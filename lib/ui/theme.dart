import 'package:flutter/material.dart';
import '../analysis/finger_classifier.dart';

const kBg = Color(0xFF0B1020);
const kCard = Color(0xFF141B33);
const kAccent = Color(0xFF38BDF8);

const fingerColors = <Finger, Color>{
  Finger.thumb: Color(0xFFFB923C),
  Finger.indexFinger: Color(0xFF4ADE80),
  Finger.middle: Color(0xFF38BDF8),
  Finger.ring: Color(0xFFC084FC),
  Finger.pinky: Color(0xFFF472B6),
};

Color stateColor(FingerState s) => switch (s) {
      FingerState.extended => const Color(0xFF22C55E),
      FingerState.folded => const Color(0xFFEF4444),
      FingerState.undetermined => const Color(0xFFF59E0B),
    };

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent, brightness: Brightness.dark, surface: kCard),
    );
