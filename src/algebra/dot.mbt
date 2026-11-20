pub fn[T : @luna_generic.Ring] dot(x : Array[T], y : Array[T]) -> T {
  guard x.length() == y.length() else {
    abort("dot: vectors must have equal length")
  }
  let mut total : T = @luna_generic.Zero::zero()
  for i = 0; i < x.length(); i = i + 1 {
    total = Add::add(
      total,
      Mul::mul(x[i], y[i]),
    )
  }
  total
}
