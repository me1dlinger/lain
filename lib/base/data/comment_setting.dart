import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/setting.dart';

/// Master switch of the comment feature. Off by default: most libraries do not
/// run a comment server, and a switch that is already on would make the app
/// ask one that nothing can answer.
final commentSwitchNotifier = ValueNotifier<bool>(false);

/// The configured comment servers, in the order they were added.
final commentServers = <CommentServer>[];

/// Id of the server the comment page asks, or null when none is selected.
final commentActiveServerIdNotifier = ValueNotifier<String?>(null);

/// Whether the stored settings have been read into the notifiers above.
///
/// Until they have, every assignment is just `Setting.load()` putting a
/// default or a read value in place; writing the file then would overwrite it
/// with a half-filled snapshot. `Setting.load()` turns this on at its end.
bool commentSettingsLoaded = false;

bool _saveScheduled = false;

/// Writes the settings once the current microtask queue drains, so a burst of
/// changes - a switch flipped twice, a page assigning a few settings - costs a
/// single whole-file write instead of one per assignment.
///
/// The last value wins: the file is built from the notifiers when the write
/// happens, not from the values at the time each change was reported.
void _scheduleCommentSave() {
  if (!commentSettingsLoaded || _saveScheduled) {
    return;
  }
  _saveScheduled = true;
  scheduleMicrotask(() {
    _saveScheduled = false;
    if (commentSettingsLoaded) {
      setting.save();
    }
  });
}

/// Turns on automatic saving of the two notifiers.
///
/// Called by `Setting.load()` once the stored values are in place: a listener
/// registered earlier would fire for every value it puts in place and write
/// the file before it has been read.
void watchCommentSettings() {
  if (commentSettingsLoaded) {
    return;
  }
  commentSettingsLoaded = true;
  commentSwitchNotifier.addListener(_scheduleCommentSave);
  commentActiveServerIdNotifier.addListener(_scheduleCommentSave);
}

/// The server the comment page asks.
///
/// Falls back to the only server there is when the stored id is missing or
/// names a server that has since been deleted, so a list of one does not need
/// to be selected by hand.
CommentServer? get activeCommentServer {
  final id = commentActiveServerIdNotifier.value;
  if (id != null) {
    for (final server in commentServers) {
      if (server.id == id) {
        return server;
      }
    }
  }
  if (commentServers.length == 1) {
    return commentServers.first;
  }
  return null;
}

/// Records that [baseUrl] answered [server], so the next request asks it first
/// and a move between home and away does not probe both addresses.
void markCommentServerAlive(CommentServer server, String baseUrl) {
  final url = baseUrl.trim();
  if (url.isEmpty) {
    return;
  }
  server.lastGoodUrl = url;
  setting.save();
}

/// Adds [server], or replaces the stored one with the same id, keeping its
/// place in the list. Selects it when [activate] is set.
Future<void> upsertCommentServer(
  CommentServer server, {
  bool activate = true,
}) async {
  final index = commentServers.indexWhere((e) => e.id == server.id);
  if (index < 0) {
    commentServers.add(server);
  } else {
    commentServers[index] = server;
  }
  if (activate) {
    commentActiveServerIdNotifier.value = server.id;
  }
  setting.save();
  await Future<void>.value();
}

/// Removes the server with [id]. When that was the active one, the first of
/// the remaining servers takes over, or nothing does when none is left.
Future<void> deleteCommentServer(String id) async {
  commentServers.removeWhere((e) => e.id == id);
  if (commentActiveServerIdNotifier.value == id) {
    commentActiveServerIdNotifier.value =
        commentServers.isEmpty ? null : commentServers.first.id;
  }
  setting.save();
  await Future<void>.value();
}
