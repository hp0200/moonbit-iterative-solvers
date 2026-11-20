///|
test "axpy computes y += a * x" {
  let x = [1.0, 2.0, 3.0]
  let y = [10.0, -2.0, 0.5]
  @algebra.axpy(2.0, x, y)
  assert_eq(y, [12.0, 2.0, 6.5])
}

///|
test "axpy supports aliasing x and y" {
  let values = [1.0, 2.0, 3.0]
  @algebra.axpy(2.0, values, values)
  assert_eq(values, [3.0, 6.0, 9.0])
}
