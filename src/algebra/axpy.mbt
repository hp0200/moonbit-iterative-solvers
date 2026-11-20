///|
pub fn[T : @luna_generic.Ring] axpy(a : T, x : Array[T], y : Array[T]) -> Unit {
  guard x.length() == y.length() else {
    abort("axpy: vectors must have equal length")
  }
  for i = 0; i < x.length(); i = i + 1 {
    y[i] = Add::add(y[i], Mul::mul(a, x[i]))
  }
}
