///|
test "FieldSafe::div_safe returns a value or rejects zero divisor" {
  assert_eq(@algebra.FieldSafe::div_safe(6.0, 3.0), Some(2.0))
  assert_eq(@algebra.FieldSafe::div_safe(1.0, 0.0), None)
}

///|
test "ToDouble::to_double preserves a Double" {
  assert_eq(@algebra.ToDouble::to_double(3.5), 3.5)
}
