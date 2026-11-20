///|
test "dot computes the expected inner product" {
  assert_eq(@algebra.dot([1.0, 2.0, 3.0], [4.0, -1.0, 2.0]), 8.0)
}
