import 'package:flutter/material.dart';

const paginationLoadErrorMessage =
    'Daha fazla içerik yüklenemedi. Tekrar denemek için aşağı kaydırın.';

class PaginationTrigger {
  PaginationTrigger({this.throttle = const Duration(milliseconds: 200)});

  final Duration throttle;
  DateTime? _lastCheck;

  bool shouldLoad(ScrollController controller, {double threshold = 280}) {
    if (!controller.hasClients) return false;

    final now = DateTime.now();
    final lastCheck = _lastCheck;
    if (lastCheck != null && now.difference(lastCheck) < throttle) {
      return false;
    }

    _lastCheck = now;
    final position = controller.position;
    return position.pixels >= position.maxScrollExtent - threshold;
  }
}

void showPaginationLoadErrorSnack(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text(paginationLoadErrorMessage)));
}
