import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLogo => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.textWhite,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      );

  static TextStyle get buttonText => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textWhite,
      );

  static TextStyle get badgeText => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );
}
