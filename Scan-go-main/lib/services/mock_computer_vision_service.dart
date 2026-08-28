import 'dart:async';
import '../models/cv_event.dart';
import '../models/product.dart';
import 'computer_vision_service.dart';

class MockComputerVisionService implements ComputerVisionService {
  final _controller = StreamController<CvEvent>.broadcast();

  @override
  Stream<CvEvent> get eventStream => _controller.stream;

  @override
  void initialize() {}

  void simulateAddProduct(Product product) {
    _controller.add(CvEvent.detected(product));
  }

  void simulateRemoveProduct(dynamic productId) {
    _controller.add(CvEvent.removed(productId));
  }

  void simulateClearCart() {
    _controller.add(CvEvent.cleared());
  }

  @override
  void dispose() {
    _controller.close();
  }
}
