// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';

import 'utils.dart';

String sandbox;

void main() {
  expectTestPasses("pattern().validate() succeeds if there's a file matching "
      "the pattern and the child entry", () {
    scheduleSandbox();

    d.file('foo', 'blap').create();

    d.filePattern(new RegExp(r'f..'), 'blap').validate();
  });

  expectTestPasses("pattern().validate() succeeds if there's a dir matching "
      "the pattern and the child entry", () {
    scheduleSandbox();

    d.dir('foo', [
      d.file('bar', 'baz')
    ]).create();

    d.dirPattern(new RegExp(r'f..'), [
      d.file('bar', 'baz')
    ]).validate();
  });

  expectTestPasses("pattern().validate() succeeds if there's multiple files "
      "matching the pattern but only one matching the child entry", () {
    scheduleSandbox();

    d.file('foo', 'blap').create();
    d.file('fee', 'blak').create();
    d.file('faa', 'blut').create();

    d.filePattern(new RegExp(r'f..'), 'blap').validate();
  });

  expectTestFailure("pattern().validate() fails if there's no file matching "
      "the pattern", () {
    scheduleSandbox();

    d.filePattern(new RegExp(r'f..'), 'bar').validate();
  }, (error) {
    expect(error.toString(),
        matches(r"^No entry found in '[^']+' matching /f\.\./\.$"));
  });

  expectTestFailure("pattern().validate() fails if there's a file matching the "
      "pattern but not the entry", () {
    scheduleSandbox();

    d.file('foo', 'bap').create();
    d.filePattern(new RegExp(r'f..'), 'bar').validate();
  }, (error) {
    expect(error.toString(),
        matches(r"^Caught error\n"
            r"| File 'foo' should contain:\n"
            r"| | bar\n"
            r"| but actually contained:\n"
            r"| X bap\n"
            r"while validating\n"
            r"| foo$"));
  });

  expectTestFailure("pattern().validate() fails if there's a dir matching the "
      "pattern but not the entry", () {
    scheduleSandbox();

    d.dir('foo', [
      d.file('bar', 'bap')
    ]).create();

    d.dirPattern(new RegExp(r'f..'), [
      d.file('bar', 'baz')
    ]).validate();
  }, (error) {
    expect(error.toString(),
        matches(r"^Caught error\n"
            r"| File 'bar' should contain:\n"
            r"| | baz\n"
            r"| but actually contained:\n"
            r"| X bap"
            r"while validating\n"
            r"| foo\n"
            r"| '-- bar$"));
  });

  expectTestFailure("pattern().validate() fails if there's multiple files "
      "matching the pattern and the child entry", () {
    scheduleSandbox();

    d.file('foo', 'bar').create();
    d.file('fee', 'bar').create();
    d.file('faa', 'bar').create();
    d.filePattern(new RegExp(r'f..'), 'bar').validate();
  }, (error) {
    expect(error.toString(), matches(
        r"^Multiple valid entries found in '[^']+' matching "
        r"\/f\.\./:\n"
        r"\* faa\n"
        r"\* fee\n"
        r"\* foo$"));
  });
}
