/// {@template son_unsupported_object_exception}
/// Error thrown by SON serialization if an object cannot be serialized.
///
/// The [unsupportedObject] field holds that object that failed to be
/// serialized.
///
/// If an object isn't directly serializable, the serializer calls the `toJson`
/// or the `toMap` method on the object. If either of those calls fail, the
/// error will be stored in the [cause] field. If the call returns an object
/// that isn't directly serializable, the [cause] is null.
/// {@endtemplate}
class SonUnsupportedObjectException<T extends Object?> implements Exception {
  /// {@macro son_unsupported_object_exception}
  const SonUnsupportedObjectException(this.unsupportedObject, {this.cause});

  /// The object that could not be serialized.
  final T unsupportedObject;

  /// The exception thrown when trying to convert the object.
  final Object? cause;

  @override
  String toString() {
    final safeString = Error.safeToString(unsupportedObject);
    final prefix = switch (cause) {
      Object() => 'Converting object to an encodable object failed:',
      _ => 'Converting object did not return an encodable object:',
    };
    return '$prefix $safeString';
  }
}
