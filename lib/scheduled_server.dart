// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:http_multi_server/http_multi_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'scheduled_test.dart';
import 'src/scheduled_server/handler.dart';
import 'src/utils.dart';

/// A class representing an HTTP server that's scheduled to run in the course of
/// the test. This class allows the server's request handling to be scheduled
/// synchronously.
///
/// The server expects requests to be received in the order [handle] is called,
/// and expects that no additional requests will be received.
class ScheduledServer {
  /// The description of the server.
  final String description;

  /// The wrapped server.
  final Future<HttpServer> _server;

  /// The queue of handlers to run for upcoming requests. Each [Future] will
  /// complete once the schedule reaches the point where that handler was
  /// scheduled.
  final _handlers = new Queue<Handler>();

  /// The map of method-path pairs to unscheduled handlers.
  ///
  /// These handlers are run whenever a request with the corresponding method
  /// and path is made.
  final _unscheduledHandlers = new Map<Pair<String, String>, shelf.Handler>();

  /// The number of servers created. Used for auto-generating descriptions;
  static var _count = 0;

  ScheduledServer._(this._server, this.description);

  /// Creates a new server listening on an automatically-allocated port on
  /// localhost (both IPv4 and IPv6, if available).
  ///
  /// [description] is used to refer to the server in debugging messages.
  factory ScheduledServer([String description]) {
    var id = _count++;
    if (description == null) description = 'scheduled server $id';

    ScheduledServer scheduledServer;
    scheduledServer = new ScheduledServer._(
        schedule/*<Future<HttpServer>>*/(() async {
      var server = await HttpMultiServer.loopback(0);
      shelf_io.serveRequests(server, scheduledServer._handleRequest);
      currentSchedule.onComplete.schedule(() => server.close(force: true));
      return server;
    }, "starting '$description'"), description);
    return scheduledServer;
  }

  /// The port on which the server is listening.
  Future<int> get port => _server.then((s) => s.port);

  /// The base URL of the server, including its port.
  Future<Uri> get url => port.then((p) => Uri.parse("http://localhost:$p"));

  /// Schedules [handler] to handle a request to the server with [method] and
  /// [path]. The schedule will wait until an HTTP request is received. If that
  /// request doesn't have the expected [method] and [path], it will fail.
  /// Otherwise, it will run [fn]. If [fn] returns a [Future], the schedule will
  /// wait until that [Future] completes.
  ///
  /// The request must be received at the point in the schedule at which
  /// [handle] was called, or in the task immediately prior (to allow for
  /// non-deterministic asynchronicity). Otherwise, an error will be thrown.
  void handle(String method, String path, shelf.Handler fn) {
    var handler = new Handler(this, method, path, fn);
    _handlers.add(handler);
    schedule(() {
      handler.ready = true;
      return handler.result;
    }, "'$description' waiting for $method $path");
  }

  /// Runs [fn] against any requests that are made to [method] and [path].
  ///
  /// Unlike [handle], this doesn't schedule a single response; it sets up a
  /// handler that's active for the duration of the server's existence. The
  /// handler may be called multiple times or not at all.
  void handleUnscheduled(String method, String path, shelf.Handler fn) {
    _unscheduledHandlers[new Pair<String, String>(method, path)] = fn;
  }

  /// The handler for incoming [shelf.Request]s to this server.
  ///
  /// This dispatches the request to the first handler in the queue. It's that
  /// handler's responsibility to check that the method/path are correct and
  /// that it's being run at the correct time.
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    try {
      var unscheduled = _unscheduledHandlers[
          new Pair(request.method, request.requestedUri.path)];
      if (unscheduled != null) return unscheduled(request);

      if (_handlers.isEmpty) {
        fail("'$description' received ${request.method} "
            "${request.requestedUri.path} when no more requests were "
            "expected.");
      }
      return await _handlers.removeFirst().fn(request);
    } catch (error, stackTrace) {
      if (error is shelf.HijackException) throw error;

      registerException(error, stackTrace);

      return new shelf.Response.internalServerError(
          body: error.toString(),
          headers: {'content-type': 'text/plain'});
    }
  }
}
