// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart' show TypeChecker;

import '../constants.dart';
import '../shared_checkers.dart';
import '../type_helper.dart';

class IterableHelper extends TypeHelper {
  const IterableHelper();

  @override
  String serialize(
      DartType targetType, String expression, SerializeContext context) {
    if (!coreIterableTypeChecker.isAssignableFromType(targetType)) {
      return null;
    }

    var itemType = coreIterableGenericType(targetType);

    // This block will yield a regular list, which works fine for JSON
    // Although it's possible that child elements may be marked unsafe

    var isList = _coreListChecker.isAssignableFromType(targetType);
    var subField = context.serialize(itemType, closureArg);

    var optionalQuestion = context.nullable ? '?' : '';

    // In the case of trivial JSON types (int, String, etc), `subField`
    // will be identical to `substitute` – so no explicit mapping is needed.
    // If they are not equal, then we to write out the substitution.
    if (subField != closureArg) {
      if (context.useWrappers && isList) {
        var method = '\$wrapList';
        if (context.nullable) {
          method = '${method}HandleNull';
        }

        return '$method<$itemType>($expression, ($closureArg) => $subField)';
      }

      // TODO: the type could be imported from a library with a prefix!
      expression =
          '$expression$optionalQuestion.map(($closureArg) => $subField)';

      // expression now represents an Iterable (even if it started as a List
      // ...resetting `isList` to `false`.
      isList = false;
    }

    if (!isList) {
      // If the static type is not a List, generate one.
      expression += '$optionalQuestion.toList()';
    }

    return expression;
  }

  @override
  String deserialize(
      DartType targetType, String expression, DeserializeContext context) {
    if (!coreIterableTypeChecker.isAssignableFromType(targetType)) {
      return null;
    }

    var iterableGenericType = coreIterableGenericType(targetType);

    var itemSubVal = context.deserialize(iterableGenericType, closureArg);

    // If `itemSubVal` is the same, then we don't need to do anything fancy
    if (closureArg == itemSubVal) {
      return '$expression as List';
    }

    var optionalQuestion = context.nullable ? '?' : '';

    var output =
        '($expression as List)$optionalQuestion.map(($closureArg) => $itemSubVal)';

    if (_coreListChecker.isAssignableFromType(targetType)) {
      output += '$optionalQuestion.toList()';
    } else if (_coreSetChecker.isAssignableFromType(targetType)) {
      output += '$optionalQuestion.toSet()';
    }

    return output;
  }
}

final _coreListChecker = const TypeChecker.fromUrl('dart:core#List');
final _coreSetChecker = const TypeChecker.fromUrl('dart:core#Set');
