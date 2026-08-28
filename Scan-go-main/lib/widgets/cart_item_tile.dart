import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/cart_item.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onRemoveCompletely;

  const CartItemTile({
    super.key,
    required this.item,
    this.onRemoveCompletely,
  });

  Widget _buildPlaceholderImage() {
    IconData iconData = Icons.fastfood;
    Color color = Colors.orange;

    if (item.product.id.contains('doritos')) {
      iconData = Icons.fastfood;
      color = const Color(0xFFD97706);
    } else if (item.product.id.contains('tuna')) {
      iconData = Icons.set_meal;
      color = const Color(0xFF0284C7);
    } else if (item.product.id.contains('honey')) {
      iconData = Icons.hive;
      color = const Color(0xFFCA8A04);
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: color, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPlaceholderImage(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.product.weight,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0284C7), // Light teal blue from screenshot
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(item.product.price),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Stepper "-" button
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              // Stepper "+" orange button
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFA8C16), // Vibrant orange matching screenshot
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Trash bin icon
              GestureDetector(
                onTap: onRemoveCompletely,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
