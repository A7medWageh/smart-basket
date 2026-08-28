import 'package:flutter/material.dart';

class ScanGoLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final double fontSize;
  final bool isDarkBackground;

  const ScanGoLogo({
    super.key,
    this.width,
    this.height,
    this.fontSize = 28,
    this.isDarkBackground = true,
  });

  static const String logoAsset = 'assets/scango_logo.png';

  @override
  Widget build(BuildContext context) {
    final double effectiveHeight = height ?? (fontSize * 2.2);

    return Image.asset(
      logoAsset,
      width: width,
      height: effectiveHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
