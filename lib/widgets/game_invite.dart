import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

Future<void> inviteFriendToGame(
  BuildContext context, {
  required String hostId,
  required AppUser invitee,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final db = context.read<DatabaseService>();

  try {
    final gameId = await db.createGame(
      hostId,
      GameSettings(isPrivate: true),
      invitedUserId: invitee.id,
    );
    await Clipboard.setData(ClipboardData(text: gameId));
    try {
      await SharePlus.instance.share(
        ShareParams(text: 'Join me in Quoridor, ${invitee.username}! Code: $gameId'),
      );
    } catch (_) {}
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Invite sent to ${invitee.username}. Game code copied.'),
      ),
    );
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    router.go('/game/$gameId');
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not send invite: $e')),
    );
  }
}
