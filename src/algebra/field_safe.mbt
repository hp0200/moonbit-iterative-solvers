///|
pub trait FieldSafe {
  fn div_safe(Self, Self) -> Self?
}

///|
pub trait ToDouble {
  fn to_double(Self) -> Double
}

///|
pub impl FieldSafe for Double with fn div_safe(numerator, denominator) {
  if denominator == 0.0 {
    None
  } else {
    Some(numerator / denominator)
  }
}

///|
pub impl ToDouble for Double with fn to_double(value) {
  value
}
