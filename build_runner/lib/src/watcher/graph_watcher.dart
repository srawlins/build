// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:build_runner_core/build_runner_core.dart';
import 'package:logging/logging.dart';

import 'asset_change.dart';
import 'node_watcher.dart';

PackageNodeWatcher _default(PackageNode node) => PackageNodeWatcher(node);

/// Allows watching an entire graph of packages to schedule rebuilds.
class PackageGraphWatcher {
  // TODO: Consider pulling logging out and providing hooks instead.
  final Logger _logger;
  final PackageNodeWatcher Function(PackageNode) _strategy;
  final PackageGraph _graph;

  var _readyCompleter = Completer<Null>();
  Future<Null> get ready => _readyCompleter.future;

  StreamController<AssetChange> controller;

  /// Creates a new watcher for a [PackageGraph].
  ///
  /// May optionally specify a [watch] strategy, otherwise will attempt a
  /// reasonable default based on the current platform.
  PackageGraphWatcher(
    this._graph, {
    Logger logger,
    PackageNodeWatcher watch(PackageNode node),
  })  : _logger = logger ?? Logger('build_runner'),
        _strategy = watch ?? _default;

  /// Returns a stream of records for assets that changed in the package graph.
  Stream<AssetChange> watch() {
    if (controller != null) return controller.stream;
    List<StreamSubscription> subscriptions;
    controller = StreamController<AssetChange>(
      sync: true,
      onListen: () {
        subscriptions = logTimedSync(
          _logger,
          'Setting up file watchers',
          () => _watch(controller),
        );
      },
      onCancel: () {
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
        _readyCompleter = Completer<Null>();
        var done = controller.close();
        controller = null;
        return done;
      },
    );
    return controller.stream;
  }

  List<StreamSubscription> _watch(StreamSink<AssetChange> sink) {
    final subscriptions = <StreamSubscription>[];
    var allWatchers = <PackageNodeWatcher>[];
    _graph.allPackages.forEach((name, node) {
      if (node.dependencyType == DependencyType.hosted ||
          node.dependencyType == DependencyType.github) {
        return;
      }
      final nestedPackages = _nestedPaths(node);
      final nodeWatcher = _strategy(node);
      allWatchers.add(nodeWatcher);
      subscriptions.add(nodeWatcher.watch().listen((event) {
        // TODO: Consider a faster filtering strategy.
        if (nestedPackages.any((path) => event.id.path.startsWith(path))) {
          return;
        }
        sink.add(event);
      }));
    });
    // Asynchronously complete the `_readyCompleter` once all the watchers
    // are done.
    () async {
      await Future.wait(
          allWatchers.map((nodeWatcher) => nodeWatcher.watcher.ready));
      _readyCompleter.complete();
    }();
    return subscriptions;
  }

  // Returns a set of all package paths that are "nested" within a node.
  //
  // This allows the watcher to optimize and avoid duplicate events.
  List<String> _nestedPaths(PackageNode rootNode) {
    return _graph.allPackages.values
        .where((node) {
          return node.path.length > rootNode.path.length &&
              node.path.startsWith(rootNode.path);
        })
        .map((node) =>
            node.path.substring(rootNode.path.length + 1) +
            Platform.pathSeparator)
        .toList();
  }
}
