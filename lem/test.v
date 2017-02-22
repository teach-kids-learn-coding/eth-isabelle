
Require Import Bvector.
Require Import Zdigits.
Require Import ZArith.

Section test.

Search (_ mod _).

Open Scope Z.


Lemma mod_add : forall a b c n, a mod n = b mod n -> (a+c) mod n = (b+c) mod n.
intros.
rewrite <- Zplus_mod_idemp_l.
rewrite H.
rewrite Zplus_mod_idemp_l.
reflexivity.
Qed.

Lemma mod_mul_eq : forall a b n m,
  n > 0 -> m > 0 ->
  (a-b) mod (n*m) = 0 ->
  (a-b) mod n = 0.
intros.
Search (_ mod _ = 0).
apply Zmod_divides.
omega.
apply Zmod_divides in H1.
elim H1; intros.
exists (m*x).
rewrite H2.
ring.
assert (n*m > 0).
apply Zmult_gt_0_compat; auto.
omega.
Qed.

Search ((_ - _) mod _ = 0 ).

Lemma mod_zero_minus : forall a b n, n > 0 ->
  (a-b) mod n = 0 ->
  a mod n = b mod n.
intros.
apply Zmod_divides in H0; try omega.
elim H0; clear H0; intros.
replace a with (b+x*n); try omega.
apply Z_mod_plus_full.
replace (x*n) with (n*x); try omega.
ring.
Qed.

Lemma mod_minus_zero : forall a b n, n > 0 ->
  a mod n = b mod n ->
  (a-b) mod n = 0.
intros.
assert ((a+(-b)) mod n = (b+(-b)) mod n).
apply mod_add; auto.
replace (a-b) with (a+ -b); try omega.
replace (b + -b) with 0 in H1; try omega.
rewrite Zmod_0_l in H1.
assumption.
Qed.

Lemma mod_mul_actual_eq : forall a b n m,
  n > 0 -> m > 0 ->
  a mod (n*m) = b mod (n*m) ->
  a mod n = b mod n.
intros.
apply mod_zero_minus; trivial.
eapply mod_mul_eq; trivial.
eapply H0.
apply mod_minus_zero; trivial.
apply Zmult_gt_0_compat; auto.
Qed.

Eval cbv in (-1 mod 2).

Lemma div2_cancel : forall a, Z.div2 (2*a) = a.
intros.
rewrite Z.div2_div.
replace (2*a) with (a*2).
apply Z_div_mult.
omega.
omega.
Qed.

(*
Z.add_b2z_double_div2: forall (a0 : bool) (a : Z), (Z.b2z a0 + 2 * a) / 2 = a
*)


(* need relation between testbit and mod two_power_nat *)

Search Z.testbit.

(*
Z.testbit_spec':
  forall a n : Z, 0 <= n -> Z.b2z (Z.testbit a n) = (a / 2 ^ n) mod 2
*)

Lemma modmud : forall n a, n > 0 -> a mod n = a - n*(a/n).
intros.
rewrite (Z.div_mod a n) at 2; try omega.
Qed.


Check Zmult_gt_0_compat.

(*
Z.div_mod
     : forall a b : Z, b <> 0 -> a = b * (a / b) + a mod b
*)
Lemma collect : forall a n m, n > 0 -> m > 0 ->
 a mod n + n*((a/n) mod m) = a mod (n*m).
intros.
replace (a mod n) with (a-n*(a/n)); try rewrite modmud; auto.
replace (a mod (n*m)) with (a-n*m*(a/(n*m))); try rewrite modmud; auto.
rewrite Z.div_div; try omega.
ring.
apply Zmult_gt_0_compat; trivial.
Qed.

Check Z.testbit.

Search (Fin.t _ -> nat).

Lemma finite_empty : Fin.t 0 -> False.
intros.
inversion H.
Qed.

(*
Lemma split_fin : forall n (k:Fin.t (S n)),
 (k = Fin.F1 \/ exists k0, k = Fin.FS k0).
intros.
set (vv := Fin.to_nat k).
set (v := proj1_sig vv).
assert (v = O \/ exists v0, v = S v0).
case v;auto.
intros.
right.
exists n0; trivial.
elim H; clear H; intros.
left.
assert (proj1_sig vv = O); trivial.
assert (Fin.of_nat_lt (proj2_sig vv) = k).
apply Fin.of_nat_to_nat_inv.
rewrite <- H1.
case vv.
assert (vv = exist _ O (proj2_sig vv)).
case vv; trivial.
setoid_rewrite H0 in H2.
cbv.
Search proj1_sig.
Check EqdepFacts.eq_dep.

inversion H0.
*)

Search List.nth.

Lemma vector_list_cons : forall A n (tl:Vector.t A n) a,
   Vector.to_list (a :: tl) = (a :: Vector.to_list tl)%list.
trivial.
Qed.

Lemma to_binary_testbit : forall (n:nat) (k:nat) a,
  (k < n)%nat ->
  Z.testbit a (Z.of_nat k) =
  List.nth k (Vector.to_list (Z_to_binary n a)) false.
induction n; intros.
inversion H.
replace (Vector.to_list (Z_to_binary (S n) a))
  with (Z.odd a :: Vector.to_list (Z_to_binary n (Z.div2 a)))%list;trivial.
assert (forall k0, (k0 < k)%nat -> Z.testbit (Z.div2 a) (Z.of_nat k0) =
        List.nth k0 (Vector.to_list (Z_to_binary n (Z.div2 a))) false).
intros.
apply IHn; auto; try omega.
assert (k=O \/ exists k0, k = S k0).
case k; eauto.
elim H1; clear H1 IHn; intros.
rewrite H1.
trivial.
elim H1; clear H1; intros.
rewrite H1.
replace (List.nth (S x)
  (Z.odd a :: Vector.to_list (Z_to_binary n (Z.div2 a))) false) with
  (List.nth x (Vector.to_list (Z_to_binary n (Z.div2 a))) false); trivial.
rewrite <- H0; try omega.
rewrite Z.div2_spec.
rewrite Z.shiftr_spec.
replace (Z.of_nat (S x)) with (Z.of_nat x + 1); trivial.
rewrite Nat2Z.inj_succ.
omega.
apply Nat2Z.is_nonneg.
Qed.

Lemma bvector_destruct : forall n (w:Bvector (S n)), exists h tl, w = h ::tl.
intros.
Check Vector.tl.
exists (Vector.hd w).
exists (Vector.tl w).
apply Vector.eta.
Qed.

Lemma bvector_empty : forall (w:Bvector 0), w = [].
apply VectorDef.case0; trivial.
Qed.


Lemma bvector_to_list_eq :
  forall n (v w:Bvector n),
  Vector.to_list v = Vector.to_list w ->
  v = w.
induction n; intros.
rewrite bvector_empty.
rewrite (bvector_empty v).
trivial.
elim (bvector_destruct _ v); intros.
elim H0; clear H0; intros.
elim (bvector_destruct _ w); intros.
elim H1; clear H1; intros.
rewrite H0; rewrite H0 in H; clear H0.
rewrite H1; rewrite H1 in H; clear H1.
rewrite !vector_list_cons in H.
inversion H.
assert (x0 = x2).
apply IHn; trivial.
rewrite H0; trivial.
Qed.


Search Vector.to_list.
Search List.nth.

Lemma list_nth_eq :
  forall A n def (v w:list A),
  length v = n -> length w = n ->
  (forall k, (k < n)%nat -> List.nth k v def = List.nth k w def) ->
  v = w.
induction n; intros.
Search (length _ = O).
rewrite List.length_zero_iff_nil in H, H0.
rewrite H; rewrite H0; trivial.
Search (length _ = (S _)).
destruct v.
inversion H.
destruct w.
inversion H0.

assert (a=a0 /\ v = w).
split.
assert (List.nth O (a :: v) def = List.nth O (a0 :: w) def).
apply H1; omega.
simpl in H2; assumption.
apply (IHn def v w); intros; auto.
assert (List.nth (S k) (a :: v) def = List.nth (S k) (a0 :: w) def).
apply H1; omega.
trivial.
elim H2; clear H2; intros.
rewrite H2; rewrite H3; trivial.
Qed.

Lemma vector_empty : forall A (w:Vector.t A 0), w = [].
intro.
apply (VectorDef.case0); trivial.
Qed.

Lemma vector_destruct : forall A n (w:Vector.t A (S n)), exists h tl, w = h ::tl.
intros.
exists (Vector.hd w).
exists (Vector.tl w).
apply Vector.eta.
Qed.

Lemma vector_to_list_eq :
  forall A n (v w:Vector.t A n),
  Vector.to_list v = Vector.to_list w ->
  v = w.
induction n; intros.
rewrite vector_empty.
rewrite (vector_empty _ v).
trivial.
elim (vector_destruct _ _ v); intros.
elim H0; clear H0; intros.
elim (vector_destruct _ _ w); intros.
elim H1; clear H1; intros.
rewrite H0; rewrite H0 in H; clear H0.
rewrite H1; rewrite H1 in H; clear H1.
rewrite !vector_list_cons in H.
inversion H.
assert (x0 = x2).
apply IHn; trivial.
rewrite H0; trivial.
Qed.



Lemma to_list_length : forall A n (v : Vector.t A n),
  length (Vector.to_list v) = n.
intros.
induction n.
rewrite (vector_empty _ v).
trivial.
elim (vector_destruct _ _ v); intros.
elim H; clear H; intros.
rewrite H; clear H.
rewrite !vector_list_cons; simpl.
rewrite IHn; trivial.
Qed.

Lemma to_binary_testbit_eq : forall n a b,
  (forall k, 0 <= k < Z.of_nat n -> Z.testbit a k = Z.testbit b k) ->
  Z_to_binary n a = Z_to_binary n b.
intros.
apply bvector_to_list_eq.
apply (list_nth_eq bool n false); intros.
apply to_list_length.
apply to_list_length.
rewrite <- !to_binary_testbit; trivial.
rewrite H; trivial.
omega.
Qed.

Check collect.

(*
collect
     : forall a n m : Z,
       n > 0 -> m > 0 -> a mod n + n * ((a / n) mod m) = a mod (n * m)
*)

Lemma two_power_succ : forall n, two_power_nat (S n) = 2 * two_power_nat n.
intro.
rewrite !two_power_nat_equiv.
rewrite Nat2Z.inj_succ.
Search (_ ^(Z.succ _)).
rewrite Z.pow_succ_r; trivial.
omega.
Qed.

Lemma two_power_pos : forall n, two_power_nat n > 0.
intros.
rewrite two_power_nat_equiv.
apply Z.lt_gt.
apply Z.pow_pos_nonneg; try omega.
Qed.

Lemma mod_combine : forall a b n,
  a mod 2 = b mod 2 ->
  Z.div2 a mod (two_power_nat n) = Z.div2 b mod (two_power_nat n) ->
  a mod two_power_nat (S n) = b mod two_power_nat (S n).
intros.
rewrite !two_power_succ.
rewrite <- !collect; try omega; try apply two_power_pos.
rewrite !Zdiv2_div in H0.
rewrite H0; rewrite H; trivial.
Qed.

Lemma mod_sameness : forall n m a b,
  n > 0 ->
  a mod n + n * m = b mod n + n * m ->
  a mod n = b mod n.
intros.
rewrite !modmud; trivial.
rewrite !modmud in H0; trivial.
omega.
Qed.

Lemma mul_sameness : forall n m1 m2 a b,
  n > 0 ->
  0 <= a < n ->
  0 <= b < n ->
  a + n * m1 = b + n * m2 ->
  m1 = m2.
intros.
assert (a = n * m2 - n*m1 + b).
omega.
replace (n * m2 - n*m1) with (n*(m2-m1)) in H3; try ring.
assert (m2-m1 = a/n).
eapply Zdiv_unique.
apply H1.
assumption.
replace (a/n) with 0 in H4; try omega.
Search (_/_ = 0).
rewrite Z.div_small; omega.
Qed.

(*
Theorem Zdiv_unique:
 forall a b q r, 0 <= r < b ->
   a = b*q + r -> q = a/b.
*)

Lemma mod_sameness2 : forall n m1 m2 a b,
  n > 0 ->
  a mod n + n * m1 = b mod n + n * m2 ->
  m1 = m2.
intros.
assert (0 <= a mod n < n).
apply Z_mod_lt; omega.
assert (0 <= b mod n < n).
apply Z_mod_lt; omega.
eapply mul_sameness; try apply H0; trivial.
Qed.

Lemma mod_sameness3 : forall n m1 m2 a b,
  n > 0 ->
  a mod n + n * m1 = b mod n + n * m2 ->
  a mod n = b mod n.
intros.
assert (m1 = m2).
eapply mod_sameness2; eassumption.
rewrite H1 in H0.
eapply mod_sameness; eassumption.
Qed.

Lemma mod_down : forall a b n,
  a mod two_power_nat (S n) = b mod two_power_nat (S n) ->
  Z.div2 a mod two_power_nat n = Z.div2 b mod two_power_nat n.
intros.
rewrite !two_power_succ in H.
rewrite <- !collect in H; try omega; try apply two_power_pos.
Search Z.div2.
rewrite !Z.div2_div.
assert (a mod 2 = b mod 2).
eapply (mod_sameness3 2 ((a / 2) mod two_power_nat n)).


omega.
eassumption.
omega.
Qed.

Lemma mod_extra : forall a b n,
  a mod two_power_nat (S n) = b mod two_power_nat (S n) ->
  a mod 2 = b mod 2.
intros.
rewrite !two_power_succ in H.


(* testbit condition should be equivalent with mod 2**n *)
Lemma testbits_mod : forall n a b,
  (forall k, 0 <= k < Z.of_nat n -> Z.testbit a k = Z.testbit b k) <->
  a mod two_power_nat n = b mod two_power_nat n.
induction n; intros.
rewrite two_power_nat_equiv.
simpl.
split; intros.
rewrite !modmud; try omega.
rewrite !Z.mul_1_l.
rewrite !Z.div_1_r.
omega.
omega.
split; intros.
apply mod_combine.
assert (Z.testbit a 0 = Z.testbit b 0).
apply H.
split; try omega.
rewrite Nat2Z.inj_succ.
omega.

rewrite <- !Z.bit0_mod.
rewrite H0.
trivial.

apply IHn; intros.

rewrite !Z.div2_spec.
rewrite !Z.shiftr_spec; try omega.
apply H.
rewrite Nat2Z.inj_succ.
omega.

apply Z.b2z_inj.
rewrite !Z.testbit_spec'; try omega.

Search Z.testbit.


Lemma div2_mod2 : forall n a,
   (Z.div2 a mod two_power_nat n) mod 2 = Z.div2 (a mod (2*Z.of_nat n)) mod 2.
intros.
Search Z.shiftl.
assert ((exists b, 2*b=a \/ 2*b+1=a)).
admit.
elim H; clear H; intros.
elim H; clear H; intros;rewrite <- H; clear H.
simpl.
induction n; intros.
simpl.
admit.
simpl.

Lemma to_binary_mod : forall n a b,
  a mod (two_power_nat n) = b mod (two_power_nat n) ->
  Z_to_binary n a = Z_to_binary n b.
induction n; intros.
simpl; reflexivity.
rewrite (Zmod2_twice a).
rewrite (Zmod2_twice b).
simpl.
case (Zmod2 b).
case (Zmod2 a).
simpl.
Search (_ mod _ = _ mod _).

a mod two_power_nat (S n) = b mod two_power_nat (S n) ->
(Z.div2 a) mod two_power_nat n = (Z.div2 b) mod two_power_nat n

Variable k : nat.
Variable a b : Bvector k.








