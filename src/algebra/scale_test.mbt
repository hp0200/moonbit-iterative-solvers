test "scale multiplies every vector entry in place" {
  let values = [1.0, -2.0, 3.5]
  @algebra.scale(-2.0, values)
  assert_eq(values, [-2.0, 4.0, -7.0])
}
