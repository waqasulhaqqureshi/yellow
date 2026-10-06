/// Stub — Smart Reply is no longer used.
///
/// All chat logic is now handled by [HeuristicReplyEngine] which works
/// entirely in Dart with zero native dependencies. This file is kept only
/// for backward compatibility with any remaining imports; it is a no-op.
class SmartReplyService {
  bool get available => false;

  void addMessage({required String text, required bool fromHuman}) {
    // No-op.
  }

  Future<String?> suggest() async => null;

  void close() {
    // No-op.
  }
}