test "norm_real matches the Euclidean norm" {
  let actual = @algebra.norm_real([3.0, -4.0])
  assert_true(Double::abs(actual - 5.0) < 1.0e-12)
}

test "norm_real of the zero vector is zero" {
  assert_eq(@algebra.norm_real([0.0, 0.0, 0.0]), 0.0)
}
