pub fn[T : @luna_generic.Ring + ToDouble] norm_real(x : Array[T]) -> Double {
  let squared_norm = dot(x, x)
  Double::sqrt(ToDouble::to_double(squared_norm))
}
