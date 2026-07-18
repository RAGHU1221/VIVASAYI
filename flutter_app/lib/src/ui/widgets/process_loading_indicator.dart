import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// சிறிய, inline loading indicator — 4-dot bounce animation (LottieFiles).
/// Full-page splash-ku [TractorLoadingIndicator] use pannunga; ithu buttons,
/// API-call spinners, inline "செயலாகிறது..." states-ku பொருந்தும்.
///
/// Usage (CircularProgressIndicator-ku direct replacement):
///   ProcessLoadingIndicator()                    // default 28px
///   ProcessLoadingIndicator(size: 40)             // bigger
///   ProcessLoadingIndicator(color: Colors.white)  // dark background-la
class ProcessLoadingIndicator extends StatelessWidget {
  final double size;

  /// Non-null aana, animation-oda default 4 colours-ah replace pannி,
  /// intha single color-la mattum tint pannும் (e.g. white text button mela).
  final Color? color;

  const ProcessLoadingIndicator({super.key, this.size = 28, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/process_loading.json',
        fit: BoxFit.contain,
        repeat: true,
        delegates: color == null
            ? null
            : LottieDelegates(
                values: [
                  ValueDelegate.color(const ['**'], value: color),
                ],
              ),
      ),
    );
  }
}
