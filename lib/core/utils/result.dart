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
