import 'product.dart';

enum CvEventType { productDetected, productRemoved, cartCleared }

class CvEvent {
  final CvEventType type;
  final Product? product;
  final dynamic productId;

  const CvEvent({
    required this.type,
    this.product,
    this.productId,
  });

  factory CvEvent.detected(Product product) => CvEvent(
        type: CvEventType.productDetected,
        product: product,
      );

  factory CvEvent.removed(dynamic productId) => CvEvent(
        type: CvEventType.productRemoved,
        productId: productId,
      );

  factory CvEvent.cleared() => const CvEvent(
        type: CvEventType.cartCleared,
      );
}
