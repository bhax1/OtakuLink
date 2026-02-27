import 'package:flutter/material.dart';

class LoginEnterAnimations {
  LoginEnterAnimations(this.controller) {
    // Initialize all animations immediately upon creation

    // --- 1. Logo (0.0 - 0.4) ---
    logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    logoFade = _createFade(0.0, 0.3);

    // --- 2. Slogan Words (Staggered 0.3 - 0.7) ---
    word1Slide = _createSlide(0.3, 0.5, const Offset(0, 0.5));
    word1Fade = _createFade(0.3, 0.45);

    word2Slide = _createSlide(0.4, 0.6, const Offset(0, 0.5));
    word2Fade = _createFade(0.4, 0.55);

    word3Slide = _createSlide(0.5, 0.7, const Offset(0, 0.5));
    word3Fade = _createFade(0.5, 0.65);

    // --- 3. Form Fields (Unique Directions) ---
    emailSlide = _createSlide(0.5, 0.75, const Offset(-0.5, 0.0)); // Left
    emailFade = _createFade(0.5, 0.65);

    passSlide = _createSlide(0.6, 0.85, const Offset(0.5, 0.0)); // Right
    passFade = _createFade(0.6, 0.75);

    forgotScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.7, 0.9, curve: Curves.elasticOut),
      ),
    );

    // --- 4. Actions ---
    btnSlide = _createSlide(0.75, 0.95, const Offset(0, 1.0)); // Up
    btnFade = _createFade(0.75, 0.90);

    footerFade = _createFade(0.85, 1.0);
  }

  final AnimationController controller;

  // -- Exposed Animations --
  late final Animation<double> logoScale;
  late final Animation<double> logoFade;

  late final Animation<Offset> word1Slide, word2Slide, word3Slide;
  late final Animation<double> word1Fade, word2Fade, word3Fade;

  late final Animation<Offset> emailSlide;
  late final Animation<double> emailFade;

  late final Animation<Offset> passSlide;
  late final Animation<double> passFade;

  late final Animation<double> forgotScale;

  late final Animation<Offset> btnSlide;
  late final Animation<double> btnFade;

  late final Animation<double> footerFade;

  // -- Private Helpers to keep code DRY --
  Animation<double> _createFade(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: Curves.easeIn),
      ),
    );
  }

  Animation<Offset> _createSlide(double start, double end, Offset begin) {
    return Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }
}
