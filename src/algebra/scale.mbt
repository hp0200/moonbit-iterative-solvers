///|
pub fn[T : @luna_generic.Ring] scale(a : T, x : Array[T]) -> Unit {
  for i = 0; i < x.length(); i = i + 1 {
    x[i] = Mul::mul(a, x[i])
  }
}
