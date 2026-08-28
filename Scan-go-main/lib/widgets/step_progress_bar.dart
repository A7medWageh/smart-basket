import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1, 2, or 3
  final int totalSteps;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final stepNum = index + 1;
        final isCompleted = stepNum <= currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.darkNavyTop
                  : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
