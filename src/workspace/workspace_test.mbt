///|
test "workspace reset loads r and clears every scratch vector" {
  let workspace = @workspace.KrylovWorkspace::make(3)
  workspace.p[0] = 9.0
  workspace.ap[1] = 8.0
  workspace.s[2] = 7.0
  workspace.t[0] = 6.0
  workspace.z[1] = 5.0
  workspace.reset([1.0, -2.0, 3.0])
  assert_eq(workspace.size(), 3)
  assert_eq(workspace.r, [1.0, -2.0, 3.0])
  assert_eq(workspace.p, [0.0, 0.0, 0.0])
  assert_eq(workspace.ap, [0.0, 0.0, 0.0])
  assert_eq(workspace.s, [0.0, 0.0, 0.0])
  assert_eq(workspace.t, [0.0, 0.0, 0.0])
  assert_eq(workspace.z, [0.0, 0.0, 0.0])
}

///|
test "a reset workspace matches a fresh workspace for a second problem" {
  let reused = @workspace.KrylovWorkspace::make(4)
  reused.reset([1.0, 2.0, 3.0, 4.0])
  reused.p[0] = 11.0
  reused.ap[1] = 12.0
  reused.s[2] = 13.0
  reused.t[3] = 14.0
  reused.z[0] = 15.0
  reused.reset([-4.0, 3.0, -2.0, 1.0])
  let fresh = @workspace.KrylovWorkspace::make(4)
  fresh.reset([-4.0, 3.0, -2.0, 1.0])
  assert_eq(reused.r, fresh.r)
  assert_eq(reused.p, fresh.p)
  assert_eq(reused.ap, fresh.ap)
  assert_eq(reused.s, fresh.s)
  assert_eq(reused.t, fresh.t)
  assert_eq(reused.z, fresh.z)
}

///|
test "workspace copy helpers preserve source vectors" {
  let workspace = @workspace.KrylovWorkspace::make(3)
  for i, value in [1.0, 2.0, 3.0] {
    workspace.r[i] = value
  }
  for i, value in [4.0, 5.0, 6.0] {
    workspace.z[i] = value
  }
  workspace.copy_r_to_s()
  workspace.copy_s_to_r()
  workspace.copy_z_to_p()
  assert_eq(workspace.s, [1.0, 2.0, 3.0])
  assert_eq(workspace.r, [1.0, 2.0, 3.0])
  assert_eq(workspace.p, [4.0, 5.0, 6.0])
  assert_eq(workspace.z, [4.0, 5.0, 6.0])
}
