import 'dart:async';
import '../models/cv_event.dart';

abstract class ComputerVisionService {
  Stream<CvEvent> get eventStream;
  void initialize();
  void dispose();
}
