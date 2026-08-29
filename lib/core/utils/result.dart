/// 统一结果包装（application-AGENTS.md「统一结果包装」）。
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final String? errorCode;
  const Failure(this.message, {this.errorCode});
}

/// UI 侧取值助手：避免泛型提升书写负担（T 可空时 `is Success` 无法直接取 data）。
extension ResultX<T> on Result<T> {
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  String? get errorMessage =>
      this is Failure<T> ? (this as Failure<T>).message : null;
  bool get isFailure => this is Failure<T>;
}
