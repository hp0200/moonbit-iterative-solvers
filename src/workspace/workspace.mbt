///|
pub struct KrylovWorkspace {
  r : Array[Double]
  p : Array[Double]
  ap : Array[Double]
  s : Array[Double]
  t : Array[Double]
  z : Array[Double]
}

///|
pub fn KrylovWorkspace::make(n : Int32) -> KrylovWorkspace {
  KrylovWorkspace::{
    r: Array::make(n, 0.0),
    p: Array::make(n, 0.0),
    ap: Array::make(n, 0.0),
    s: Array::make(n, 0.0),
    t: Array::make(n, 0.0),
    z: Array::make(n, 0.0),
  }
}

///|
pub fn KrylovWorkspace::size(self : KrylovWorkspace) -> Int32 {
  self.r.length()
}

///|
pub fn KrylovWorkspace::reset(
  self : KrylovWorkspace,
  b : Array[Double],
) -> Unit {
  guard b.length() == self.size() else {
    abort("KrylovWorkspace::reset: right-hand side length mismatch")
  }
  for i = 0; i < b.length(); i = i + 1 {
    self.r[i] = b[i]
    self.p[i] = 0.0
    self.ap[i] = 0.0
    self.s[i] = 0.0
    self.t[i] = 0.0
    self.z[i] = 0.0
  }
}

///|
pub fn KrylovWorkspace::clear_work(self : KrylovWorkspace) -> Unit {
  for i = 0; i < self.size(); i = i + 1 {
    self.p[i] = 0.0
    self.ap[i] = 0.0
    self.s[i] = 0.0
    self.t[i] = 0.0
    self.z[i] = 0.0
  }
}

///|
pub fn KrylovWorkspace::copy_r_to_s(self : KrylovWorkspace) -> Unit {
  for i = 0; i < self.size(); i = i + 1 {
    self.s[i] = self.r[i]
  }
}

///|
pub fn KrylovWorkspace::copy_s_to_r(self : KrylovWorkspace) -> Unit {
  for i = 0; i < self.size(); i = i + 1 {
    self.r[i] = self.s[i]
  }
}

///|
pub fn KrylovWorkspace::copy_z_to_p(self : KrylovWorkspace) -> Unit {
  for i = 0; i < self.size(); i = i + 1 {
    self.p[i] = self.z[i]
  }
}
