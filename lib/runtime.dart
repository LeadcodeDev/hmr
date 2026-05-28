/// Child-side runtime API for applications launched by the hmr supervisor.
///
/// Import this *only* from your app's `bin/main.dart`. The supervisor itself
/// uses `package:hmr/hmr.dart` instead.
library;

export 'src/domain/events.dart';
export 'src/runtime/hmr_runtime.dart';
