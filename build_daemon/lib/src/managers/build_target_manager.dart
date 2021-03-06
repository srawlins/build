// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:watcher/watcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/build_target.dart';

bool _isBlacklistedPath(String filePath, Set<RegExp> blackListedPatterns) =>
    blackListedPatterns.any((pattern) => filePath.contains(pattern));

bool _shouldBuild(BuildTarget target, Iterable<WatchEvent> changes) =>
    target is DefaultBuildTarget &&
    changes.any((change) =>
        !_isBlacklistedPath(change.path, target.blackListPatterns.toSet()));

/// Manages the set of build targets, and corresponding listeners, tracked by
/// the Dart Build Daemon.
class BuildTargetManager {
  var _buildTargets = <BuildTarget, Set<WebSocketChannel>>{};

  bool Function(BuildTarget, Iterable<WatchEvent>) shouldBuild;

  bool get isEmpty => _buildTargets.isEmpty;

  Set<BuildTarget> get targets => _buildTargets.keys.toSet();

  Set<WebSocketChannel> channels(BuildTarget target) => _buildTargets[target];

  BuildTargetManager(
      {bool Function(BuildTarget, Iterable<WatchEvent>) shouldBuildOverride})
      : shouldBuild = shouldBuildOverride ?? _shouldBuild;

  void addBuildTarget(BuildTarget target, WebSocketChannel channel) {
    _buildTargets
        .putIfAbsent(target, () => Set<WebSocketChannel>())
        .add(channel);
  }

  void removeChannel(WebSocketChannel channel) =>
      _buildTargets = Map.fromEntries(_buildTargets.entries
          .map((e) => MapEntry(e.key, e.value..remove(channel)))
          .where((e) => e.value.isNotEmpty));

  Set<BuildTarget> targetsForChanges(List<WatchEvent> changes) =>
      targets.where((target) => shouldBuild(target, changes)).toSet();
}
