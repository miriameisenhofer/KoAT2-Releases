model main {
  var A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V;
  states f2, f1, f13, f20, f31, f45, f60;
  transition t0 := {
    from   := f2;
    to     := f1;
    guard  := A = 1;
    action := A' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t1 := {
    from   := f2;
    to     := f13;
    guard  := 0 >= A;
    action := B' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t2 := {
    from   := f2;
    to     := f13;
    guard  := A > 1;
    action := B' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t3 := {
    from   := f13;
    to     := f20;
    guard  := A >= B;
    action := C' = B + 1, D' = S, E' = T, F' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t4 := {
    from   := f20;
    to     := f20;
    guard  := B >= F;
    action := D' = S, E' = T, F' = F + 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t5 := {
    from   := f31;
    to     := f31;
    guard  := B >= F;
    action := F' = F + 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t6 := {
    from   := f45;
    to     := f45;
    guard  := B >= F;
    action := F' = F + 1, G' = S, H' = T, I' = U, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t7 := {
    from   := f60;
    to     := f60;
    guard  := J >= F;
    action := F' = F + 1, K' = K - 1, L' = S, M' = T, N' = U, O' = V, P' = K, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t8 := {
    from   := f60;
    to     := f13;
    guard  := F > J;
    action := B' = B + 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t9 := {
    from   := f45;
    to     := f60;
    guard  := F > B;
    action := F' = 1, K' = B, J' = S, Q' = T, R' = U, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t10 := {
    from   := f31;
    to     := f1;
    guard  := F > B && A = C;
    action := C' = A, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t11 := {
    from   := f31;
    to     := f45;
    guard  := A > C && F > B;
    action := F' = 1, G' = S, H' = T, I' = U, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t12 := {
    from   := f31;
    to     := f45;
    guard  := C > A && F > B;
    action := F' = 1, G' = S, H' = T, I' = U, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t13 := {
    from   := f20;
    to     := f31;
    guard  := 0 > E && F > B;
    action := F' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t14 := {
    from   := f20;
    to     := f31;
    guard  := E > 0 && F > B;
    action := F' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t15 := {
    from   := f20;
    to     := f31;
    guard  := F > B && E = 0;
    action := E' = 0, F' = 1, S' = ?, T' = ?, U' = ?, V' = ?;
  };
  transition t16 := {
    from   := f13;
    to     := f1;
    guard  := B > A;
    action := S' = ?, T' = ?, U' = ?, V' = ?;
  };
}
strategy dumb {
  Region init := { state = f2 };
}
