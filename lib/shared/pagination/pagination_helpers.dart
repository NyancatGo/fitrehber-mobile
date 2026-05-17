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

/// Sayfalama hatası bildirir. [onRetry] verilirse "Tekrar Dene" aksiyonu ekler.
void showPaginationLoadErrorSnack(BuildContext context, {VoidCallback? onRetry}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text(paginationLoadErrorMessage),
      action: onRetry == null
          ? null
          : SnackBarAction(label: 'Tekrar Dene', onPressed: onRetry),
    ),
  );
}
