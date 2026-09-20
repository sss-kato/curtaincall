import 'package:curtaincall/app/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  // T-23（D-04 §10 T-F1）で bootstrap() を await する形に置き換える（D-04 §5.1）。
  // ensureInitialized はその前提として今のうちに置く（bootstrap 内で DB・アセットを触るため）。
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CurtainCallApp()));
}
