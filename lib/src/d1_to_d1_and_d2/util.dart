/// Utility functions that are specific to the Dart1 -> Dart1/Dart2 codemod.
library over_react_codemod.src.d1_to_d1_and_d2.util;

import 'package:analyzer/analyzer.dart';

import '../constants.dart';
import '../util.dart';

typedef String CompanionBuilder(String className,
    {String annotations, String commentPrefix, String docComment});

/// Returns the source code for a companion `@Props()` or `@AbstractProps()`
/// class named [className].
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
///
/// If the [docComment] string is non-null and non-empty, it will be included
/// before the class.
///
/// If the [annotations] string is non-null and non-empty, it will be included
/// before the class.
///
/// If given, [commentPrefix] will be inserted at the beginning of the
/// double-slash comment on the companion class declaration. Use this as a way
/// to reference a cleanup ticket or issue number.
String buildPropsCompanionClass(
  String className, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) =>
    _buildPropsOrStateCompanionClass(className, propsMetaType,
        annotations: annotations,
        commentPrefix: commentPrefix,
        docComment: docComment,
        typeParameters: typeParameters);

/// Returns the source code for a companion `@State()` or `@AbstractState()`
/// class named [className].
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
///
/// If the [docComment] string is non-null and non-empty, it will be included
/// before the class.
///
/// If the [annotations] string is non-null and non-empty, it will be included
/// before the class.
///
/// If given, [commentPrefix] will be inserted at the beginning of the
/// double-slash comment on the companion class declaration. Use this as a way
/// to reference a cleanup ticket or issue number.
String buildStateCompanionClass(
  String className, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) =>
    _buildPropsOrStateCompanionClass(className, stateMetaType,
        annotations: annotations,
        commentPrefix: commentPrefix,
        docComment: docComment,
        typeParameters: typeParameters);

/// Returns the source code for a companion class based on the given
/// [className] and [metaType].
///
/// The returned class will have the following attributes:
/// - Name: the result of calling [stripPrivateGeneratedPrefix] on [className].
/// - Super class: the class name with the private generated prefix.
///   [className]
/// - Mixin: same as super class but with a `AccessorsMixin` suffix.
/// - A static meta field typed as [metaType] (should be either `PropsMeta` or
///   `StateMeta`) and with an initialized value of `$metaFor<name>` where name
///   is the same as the class name.
/// - Annotations if [annotations] is non-null and non-empty.
/// - A doc comment if [docComment] is non-null and non-empty.
/// - A single-line comment indicating that this class is temporary and will be
///   removed when Dart 1 support is no longer needed. If a [commentPrefix] is
///   given, it will be inserted at the beginning of this single-line comment.
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
String _buildPropsOrStateCompanionClass(
  String className,
  String metaType, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) {
  annotations ??= '';
  commentPrefix ??= '';
  docComment ??= '';

  final classCommentsAndAnnotations = <String>[];
  if (docComment.isNotEmpty) {
    classCommentsAndAnnotations.add(docComment);
  }
  if (annotations.isNotEmpty) {
    classCommentsAndAnnotations.add(annotations);
  }
  classCommentsAndAnnotations.add(
      '// ${commentPrefix}This will be removed once the transition to Dart 2 is complete.');

  var typeParamsOnClass = '';
  var typeParamsOnSuper = '';
  if (typeParameters != null) {
    typeParamsOnClass = typeParameters.toSource();
    typeParamsOnSuper = (StringBuffer()
          ..write('<')
          ..write(
              typeParameters.typeParameters.map((t) => t.name.name).join(', '))
          ..write('>'))
        .toString();
  }

  final strippedClassName = stripPrivateGeneratedPrefix(className);
  final mixinIgnoreComment = buildIgnoreComment(
    mixinOfNonClass: true,
    undefinedClass: true,
  );
  final metaIgnoreComment = buildIgnoreComment(
    constInitializedWithNonConstantValue: true,
    undefinedClass: true,
    undefinedIdentifier: true,
  );
  // With triple-quote strings, the first newline is ignored if the first line
  // is empty, so this string purposely includes an extra blank line.
  return '''

${classCommentsAndAnnotations.join('\n')}
class $strippedClassName$typeParamsOnClass extends ${privateGeneratedPrefix}$strippedClassName$typeParamsOnSuper
    with
        $mixinIgnoreComment
        ${privateGeneratedPrefix}${strippedClassName}AccessorsMixin$typeParamsOnSuper {
  $metaIgnoreComment
  static const $metaType meta = ${privateGeneratedPrefix}metaFor$strippedClassName;
}
''';
}

/// Returns the Dart-2-compatible class name for the given props or state
/// [className].
///
/// Use to rename a class in the original Dart-1-only format to the
/// version expected for forwards-compatibility with Dart 2, while also
/// accounting for already-renamed classes. In other words, if the given class
/// name is already correct, the same value will be returned.
///
///     renamePropsOrStateClass('FooProps');
///     // '_$FooProps'
///     renamePropsOrStateClass('_$FooProps');
///     // '_$FooProps'
///     renamePropsOrStateClass('_FooProps');
///     // '_$_FooProps'
///     renamePropsOrStateClass('_$_FooProps');
///     // '_$_FooProps'
String renamePropsOrStateClass(String className) {
  return '$privateGeneratedPrefix${stripPrivateGeneratedPrefix(className)}';
}
