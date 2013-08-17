open HolKernel boolLib boolSimps bossLib lcsymtacs pred_setTheory pairTheory listTheory finite_mapTheory sholSyntaxTheory modelSetTheory
val _ = numLib.prefer_num()
val _ = new_theory"sholSemantics"

val FEVERY_SUBMAP = store_thm("FEVERY_SUBMAP",
  ``FEVERY P fm /\ fm0 SUBMAP fm ==> FEVERY P fm0``,
  SRW_TAC[][FEVERY_DEF,SUBMAP_DEF])

val MEM_LIST_INSERT = store_thm("MEM_LIST_INSERT",
  ``∀l x. set (LIST_INSERT x l) = x INSERT set l``,
  Induct >> simp[LIST_INSERT_def] >> rw[] >>
  rw[EXTENSION] >> metis_tac[])

val MEM_LIST_UNION = store_thm("MEM_LIST_UNION",
  ``∀l1 l2. set (LIST_UNION l1 l2) = set l1 ∪ set l2``,
  Induct >> fs[LIST_UNION_def,MEM_LIST_INSERT] >>
  rw[EXTENSION] >> metis_tac[])

val vfree_in_equation = store_thm("vfree_in_equation",
  ``VFREE_IN v (s === t) ⇔ (v = Equal (typeof s)) ∨ VFREE_IN v s ∨ VFREE_IN v t``,
  rw[equation_def,VFREE_IN_def] >> metis_tac[])

val type_ind =
  TypeBase.induction_of``:type``
  |> Q.SPECL[`K T`,`P`,`K T`,`K T`,`EVERY P`]
  |> SIMP_RULE std_ss [EVERY_DEF]
  |> UNDISCH_ALL
  |> CONJUNCT1
  |> DISCH_ALL
  |> Q.GEN`P`

val TYPE_SUBST_tyvars = store_thm("TYPE_SUBST_tyvars",
  ``∀ty tyin tyin'.
    (TYPE_SUBST tyin ty = TYPE_SUBST tyin' ty) ⇔
    ∀x. MEM x (tyvars ty) ⇒
        REV_ASSOCD (Tyvar x) tyin' (Tyvar x) =
        REV_ASSOCD (Tyvar x) tyin  (Tyvar x)``,
  ho_match_mp_tac type_ind >>
  simp[tyvars_def] >>
  conj_tac >- metis_tac[] >>
  Induct >> simp[] >>
  gen_tac >> strip_tac >> fs[] >>
  rpt gen_tac >> EQ_TAC >> strip_tac >> fs[] >>
  fs[MEM_LIST_UNION] >> metis_tac[])

val tvars_VSUBST_subset = store_thm("tvars_VSUBST_subset",
  ``∀t sub. set (tvars (VSUBST sub t)) ⊆ set (tvars t) ∪ set (FLAT (MAP (tvars o FST) sub))``,
  Induct >> simp[VSUBST_def,tvars_def] >- (
    rw[SUBSET_DEF,MEM_FLAT] >>
    Q.ISPECL_THEN[`sub`,`Var s t`,`Var s t`]mp_tac REV_ASSOCD_MEM >>
    rw[] >> fs[tvars_def] >>
    disj2_tac >> HINT_EXISTS_TAC >> simp[MEM_MAP] >>
    HINT_EXISTS_TAC >> simp[] )
  >- (
    fs[SUBSET_DEF,MEM_LIST_UNION] >>
    metis_tac[] )
  >- (
    rw[] >>
    fs[SUBSET_DEF,MEM_LIST_UNION,tvars_def,VSUBST_def] >>
    rw[] >> fs[] >>
    res_tac >> fs[tvars_def] >>
    fs[MEM_FLAT,MEM_MAP,MEM_FILTER,pairTheory.EXISTS_PROD] >>
    fsrw_tac[DNF_ss][] >> metis_tac[]))

val INST_CORE_tvars = store_thm("INST_CORE_tvars",
  ``∀env tyin t tyin'.
    (∀x. MEM x (tvars t) ⇒
         REV_ASSOCD (Tyvar x) tyin' (Tyvar x) =
         REV_ASSOCD (Tyvar x) tyin  (Tyvar x)) ∧
    (∀s s'. MEM (s,s') env ⇒
            ∃x ty. s = Var x ty ∧ s' = Var x (TYPE_SUBST tyin ty))
    ⇒
    INST_CORE env tyin t = INST_CORE env tyin' t``,
  ho_match_mp_tac INST_CORE_ind >>
  strip_tac >- (
    simp[INST_CORE_def] >>
    rw[] >> fs[tvars_def] >>
    metis_tac[TYPE_SUBST_tyvars] ) >>
  strip_tac >- (
    simp[INST_CORE_def] >>
    rw[] >> fs[tvars_def] >>
    metis_tac[TYPE_SUBST_tyvars] ) >>
  strip_tac >- (
    simp[INST_CORE_def] >>
    rw[] >> fs[tvars_def,MEM_LIST_UNION] >>
    rw[] >>
    TRY (
    `INST_CORE env tyin t = INST_CORE env tyin' t` by (
      first_x_assum match_mp_tac >>
      metis_tac[] )) >>
    TRY (
    `INST_CORE env tyin t' = INST_CORE env tyin' t'` by (
      first_x_assum match_mp_tac >>
      metis_tac[] )) >>
    fs[] ) >>
  simp[tvars_def,MEM_LIST_UNION] >>
  simp[INST_CORE_def] >>
  rpt gen_tac >> strip_tac >> rpt gen_tac >>
  Q.PAT_ABBREV_TAC`env1 = X::env` >>
  Q.PAT_ABBREV_TAC`env2 = X::env` >>
  Q.PAT_ABBREV_TAC`env3 = X::env` >>
  Q.PAT_ABBREV_TAC`env4 = X::env` >>
  strip_tac >>
  `env1 = env3` by metis_tac[TYPE_SUBST_tyvars] >>
  `INST_CORE env1 tyin t = INST_CORE env1 tyin' t` by (
    first_x_assum match_mp_tac >>
    simp[] >> metis_tac[TYPE_SUBST_tyvars] ) >>
  `TYPE_SUBST tyin' ty = TYPE_SUBST tyin ty` by metis_tac[TYPE_SUBST_tyvars] >>
  Cases_on`IS_RESULT (INST_CORE env3 tyin t)`>>rfs[] >> fs[] >>
  Cases_on`CLASH (INST_CORE env3 tyin' t) = Var x (TYPE_SUBST tyin ty)`>>fs[] >>
  `INST_CORE [] tyin t = INST_CORE [] tyin' t` by (
    first_x_assum match_mp_tac >> simp[] ) >>
  `env2 = env4` by (
    simp[Abbr`env2`,Abbr`env4`]) >>
  fs[] >>
  Q.PAT_ABBREV_TAC`sub = [(Var X Y,Var A Z)]` >>
  `INST_CORE env4 tyin (VSUBST sub t) = INST_CORE env4 tyin' (VSUBST sub t)` by (
    first_x_assum match_mp_tac >>
    rw[] >- (
      imp_res_tac (SIMP_RULE std_ss [SUBSET_DEF] tvars_VSUBST_subset) >>
      fs[Abbr`sub`,tvars_def] ) >>
    metis_tac[] ) >>
  fs[])

val RACONV_welltyped = store_thm("RACONV_welltyped",
  ``∀t1 env t2.
    EVERY (λ(x,y). welltyped x ∧ welltyped y ∧ typeof x = typeof y) env ∧
    welltyped t1 ∧ RACONV env (t1,t2) ⇒
    welltyped t2``,
  Induct >>
  simp[Once RACONV_cases] >- (
    rw[] >> rw[WELLTYPED_CLAUSES] )
  >- (
    rw[WELLTYPED_CLAUSES] >>
    pop_assum mp_tac >>
    simp[Once RACONV_cases] >>
    rw[] >> rw[WELLTYPED_CLAUSES] >>
    metis_tac[RACONV_TYPE,FST,SND] )
  >- (
    rw[Once RACONV_cases] >>
    pop_assum mp_tac >>
    rw[Once RACONV_cases] >>
    rw[WELLTYPED_CLAUSES] >>
    first_x_assum match_mp_tac >>
    qmatch_assum_abbrev_tac`RACONV env' pp` >>
    qexists_tac`env'` >>
    simp[Abbr`env'`]))

val ACONV_welltyped = store_thm("ACONV_welltyped",
  ``∀t1 t2. ACONV t1 t2 ∧ welltyped t1 ⇒ welltyped t2``,
  rw[ACONV_def] >>
  metis_tac[RACONV_welltyped,EVERY_DEF])

val (semantics_rules,semantics_ind,semantics_cases) = xHol_reln"semantics"`
  (typeset τ (Tyvar s) (τ s)) ∧

  (typeset τ (Tyapp (Typrim "bool" 0) []) boolset) ∧

  (typeset τ x mx ∧ typeset τ y my
   ⇒
   typeset τ (Tyapp (Typrim "->" 2) [x;y]) (funspace mx my)) ∧

  (LENGTH (tvars p) = LENGTH args ∧
   tyin = ZIP (args, MAP Tyvar (STRING_SORT (tvars p))) ∧
   semantics FEMPTY τ (INST tyin p) mp ∧ w <: mrty ∧ holds mp w ∧
   INST tyin p has_type Fun rty Bool ∧ typeset τ rty mrty
   ⇒
   typeset τ (Tyapp (Tydefined op p) args) (mrty suchthat holds mp)) ∧

  (FLOOKUP σ (n,ty) = SOME m
   ⇒
   semantics σ τ (Var n ty) m) ∧

  (typeset τ ty mty
   ⇒
   semantics σ τ (Const "=" (Fun ty (Fun ty Bool)) Prim)
    (abstract mty (funspace mty boolset)
       (λx. abstract mty boolset (λy. boolean (x = y))))) ∧

  (typeset τ ty mty
   ⇒
   semantics σ τ (Const "@" (Fun (Fun ty Bool) ty) Prim)
     (abstract (funspace mty boolset) mty
       (λp. let mp = (mty suchthat holds p) in
            ch (if ∃x. x <: mp then mp else mty)))) ∧

  (welltyped t ∧ closed t ∧
   set(tvars t) ⊆ set (tyvars (typeof t)) ∧
   INST tyin t has_type ty ∧
   semantics FEMPTY τ (INST tyin t) mt
   ⇒
   semantics σ τ (Const s ty (Defined t)) mt) ∧

  (typeset τ (Tyapp (Tydefined op p) args) maty ∧
   tyin = ZIP(args, MAP Tyvar (STRING_SORT (tvars p))) ∧
   INST tyin p has_type Fun rty Bool ∧ typeset τ rty mrty
   ⇒
   semantics σ τ (Const s (Fun (Tyapp (Tydefined op p) args) rty) (Tyrep op p))
    (abstract maty mrty (λx. x))) ∧

  (typeset τ (Tyapp (Tydefined op p) args) maty ∧
   tyin = ZIP(args, MAP Tyvar (STRING_SORT (tvars p))) ∧
   INST tyin p has_type Fun rty Bool ∧ typeset τ rty mrty ∧
   semantics FEMPTY τ (INST tyin p) mp
   ⇒
   semantics σ τ (Const s (Fun rty (Tyapp (Tydefined op p) args)) (Tyabs op p))
    (abstract mrty maty (λx. if holds mp x then x else ch maty))) ∧

  (semantics σ τ t mt ∧
   semantics σ τ u mu ∧
   welltyped (Comb t u)
   ⇒
   semantics σ τ (Comb t u) (apply mt mu)) ∧

  (typeset τ ty mty ∧
   b has_type tyb ∧
   typeset τ tyb mtyb ∧
   (∀x. x <: mty ⇒ (mb x) <: mtyb ∧ semantics (σ |+ ((n,ty),x)) τ b (mb x))
   ⇒
   semantics σ τ (Abs n ty b) (abstract mty mtyb mb))`

val typeset_Bool = store_thm("typeset_Bool",
  ``typeset τ Bool ty ⇔ ty = boolset``,
  simp[Once semantics_cases])
val _ = export_rewrites["typeset_Bool"]

val type_valuation_def = Define`
  type_valuation τ ⇔ ∀x. ∃y. y <: τ x`

val a_type_valuation_exists = store_thm("a_type_valuation_exists",
  ``∃τ:string->V. type_valuation τ``,
  rw[type_valuation_def,GSYM SKOLEM_THM] >>
  metis_tac[BOOLEAN_IN_BOOLSET])

val term_valuation_def = Define`
  term_valuation τ σ ⇔
    FEVERY (λ(v,m). ∃mty. typeset τ (SND v) mty ∧ m <: mty) σ`

val term_valuation_FEMPTY = store_thm("term_valuation_FEMPTY",
  ``term_valuation τ FEMPTY``,
  rw[term_valuation_def,FEVERY_DEF])
val _ = export_rewrites["term_valuation_FEMPTY"]

val typeset_inhabited = store_thm("typeset_inhabited",
  ``∀ty τ mty. type_valuation τ ∧ typeset τ ty mty ⇒ ∃m. m <: mty``,
  ho_match_mp_tac type_ind >>
  conj_tac >- (
    simp[type_valuation_def] >>
    simp[Once semantics_cases] ) >>
  rpt gen_tac >> strip_tac >>
  simp[Once semantics_cases] >>
  rw[] >- metis_tac[BOOLEAN_IN_BOOLSET]
  >- (
    match_mp_tac FUNSPACE_INHABITED >>
    fs[] >> metis_tac[] ) >>
  simp[suchthat_def] >>
  metis_tac[] )

val semantics_11 = store_thm("semantics_11",
  ``(∀τ ty mty. typeset τ ty mty ⇒
        ∀mty'. type_valuation τ ∧ typeset τ ty mty' ⇒ mty' = mty) ∧
    (∀σ τ t mt. semantics σ τ t mt ⇒
        ∀mt'. type_valuation τ ∧ semantics σ τ t mt' ⇒ mt' = mt)``,
  ho_match_mp_tac semantics_ind >>
  conj_tac >- simp[Once semantics_cases] >>
  conj_tac >- simp[Once semantics_cases] >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp[Once semantics_cases] >>
    PROVE_TAC[] ) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp[Once semantics_cases] >> rw[] >>
    `Fun ty Bool = Fun rty Bool` by (
      metis_tac[WELLTYPED_LEMMA] ) >>
    fs[] ) >>
  conj_tac >- simp[Once semantics_cases] >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp[Once semantics_cases] >> rw[] >> rw[]) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp[Once semantics_cases] >> rw[] >> rw[]) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp[Once semantics_cases] >> rw[] >> rw[] >>
    qspecl_then[`sizeof t`,`t`,`[]`,`tyin`]mp_tac INST_CORE_HAS_TYPE >>
    qspecl_then[`sizeof t`,`t`,`[]`,`tyin'`]mp_tac INST_CORE_HAS_TYPE >>
    simp[] >> ntac 2 strip_tac >> fs[INST_def] >>
    `INST_CORE [] tyin' t = INST_CORE [] tyin t` by (
      match_mp_tac INST_CORE_tvars >>
      fs[SUBSET_DEF] >>
      imp_res_tac WELLTYPED_LEMMA >> rw[] >> fs[] >>
      metis_tac[TYPE_SUBST_tyvars] ) >>
    fs[] ) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp_tac std_ss [Once semantics_cases] >>
    rw[] >> metis_tac[] ) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp_tac (srw_ss()) [Once semantics_cases] >>
    rpt strip_tac >>
    BasicProvers.VAR_EQ_TAC >>
    `mrty = mty'` by metis_tac[] >>
    `maty = mty` by metis_tac[] >>
    qsuff_tac`mp = mt`>-metis_tac[] >>
    first_x_assum match_mp_tac >>
    simp[] ) >>
  conj_tac >- (
    rpt gen_tac >> strip_tac >>
    simp_tac std_ss [Once semantics_cases] >>
    simp_tac (srw_ss()) [] >>
    rw[] >> metis_tac[] ) >>
  rpt gen_tac >>
  strip_tac >>
  simp_tac std_ss [Once semantics_cases] >>
  rw[] >>
  imp_res_tac WELLTYPED_LEMMA >> rw[] >>
  match_mp_tac ABSTRACT_EQ >>
  conj_tac >- metis_tac[typeset_inhabited] >>
  fs[] >> res_tac >> fs[])

val semantics_typeset = store_thm("semantics_typeset",
  ``(∀τ ty mty. typeset τ ty mty ⇒ type_valuation τ ⇒ ∃mt. mt <: mty) ∧
    (∀σ τ t mt. semantics σ τ t mt ⇒
        type_valuation τ ∧ term_valuation τ σ ⇒
           ∃mty. welltyped t ∧ typeset τ (typeof t) mty ∧ mt <: mty)``,
  ho_match_mp_tac (theorem"semantics_strongind") >>
  simp[INDSET_INHABITED,FUNSPACE_INHABITED] >>
  conj_tac >- simp[type_valuation_def] >>
  conj_tac >- metis_tac[BOOLEAN_IN_BOOLSET] >>
  conj_tac >- ( rw[suchthat_def] >> metis_tac[] ) >>
  conj_tac >- (
    simp[Once has_type_cases] >> rw[] >>
    fs[term_valuation_def] >>
    imp_res_tac FEVERY_FLOOKUP >>
    fs[] >> metis_tac[]) >>
  conj_tac >- (
    rw[Once has_type_cases] >>
    rw[Once semantics_cases] >>
    rw[Once (Q.SPECL[`τ`,`Fun X Y`](CONJUNCT1 semantics_cases))] >>
    fsrw_tac[DNF_ss][] >>
    rpt(qexists_tac`mty`)>>simp[]>>
    match_mp_tac ABSTRACT_IN_FUNSPACE >> rw[] >>
    match_mp_tac ABSTRACT_IN_FUNSPACE >> rw[] >>
    metis_tac[BOOLEAN_IN_BOOLSET] ) >>
  conj_tac >- (
    rw[Once has_type_cases] >>
    rw[Once semantics_cases] >>
    rw[Once (Q.SPECL[`τ`,`Fun X Y`](CONJUNCT1 semantics_cases))] >>
    fsrw_tac[DNF_ss][] >>
    rpt(qexists_tac`mty`)>>simp[]>>
    match_mp_tac ABSTRACT_IN_FUNSPACE >> rw[] >>
    fs[suchthat_def] >> rw[] >- (
      qmatch_abbrev_tac`ch s <: mty` >>
      `ch s <: s` by (
        match_mp_tac ch_def >>
        simp[Abbr`s`,suchthat_def] >>
        metis_tac[] ) >>
      fs[Abbr`s`,suchthat_def] ) >>
    match_mp_tac ch_def >>
    metis_tac[] ) >>
  conj_tac >- (
    rw[] >>
    imp_res_tac WELLTYPED_LEMMA >> fs[] >> rw[] >>
    fs[term_valuation_def,FEVERY_DEF] >>
    metis_tac[WELLTYPED_LEMMA] ) >>
  conj_tac >- (
    rw[] >>
    imp_res_tac WELLTYPED_LEMMA >> fs[] >> rw[] >>
    qpat_assum`typeset τ (X Y) Z` mp_tac >> rw[Once semantics_cases] >>
    imp_res_tac semantics_11 >>
    rpt BasicProvers.VAR_EQ_TAC >>
    rw[Once semantics_cases] >>
    fsrw_tac[DNF_ss][] >>
    rw[Once semantics_cases] >>
    fsrw_tac[DNF_ss][] >>
    qmatch_assum_rename_tac`typeset τ ty my`[] >>
    map_every qexists_tac[`my`,`mp`,`mrty`,`rty`,`w`] >>
    simp[] >>
    match_mp_tac ABSTRACT_IN_FUNSPACE >>
    fs[suchthat_def] >>
    imp_res_tac WELLTYPED_LEMMA >>
    fs[] >> rw[] >> imp_res_tac semantics_11 >> rw[] ) >>
  conj_tac >- (
    rw[] >>
    imp_res_tac WELLTYPED_LEMMA >> fs[] >> rw[] >>
    qpat_assum`typeset τ (X Y) Z` mp_tac >> rw[Once semantics_cases] >>
    qpat_assum`typeset τ (X Y) Z` mp_tac >> rw[Once semantics_cases] >>
    imp_res_tac semantics_11 >>
    rpt BasicProvers.VAR_EQ_TAC >>
    rw[Once semantics_cases] >>
    fsrw_tac[DNF_ss][] >>
    rw[Once (Q.SPECL[`τ`,`X Y Z`](CONJUNCT1 semantics_cases))] >>
    fsrw_tac[DNF_ss][] >>
    qmatch_assum_rename_tac`typeset τ ty my`[] >>
    map_every qexists_tac[`my`,`mp`,`mrty`,`rty`,`w`] >>
    simp[] >>
    match_mp_tac ABSTRACT_IN_FUNSPACE >>
    rw[] >>
    rw[] >- (
      fs[suchthat_def] >>
      imp_res_tac WELLTYPED_LEMMA >> fs[] >>
      rpt BasicProvers.VAR_EQ_TAC >>
      imp_res_tac semantics_11 >>
      rpt BasicProvers.VAR_EQ_TAC >>
      rw[] ) >>
    match_mp_tac ch_def >>
    fs[suchthat_def] >>
    metis_tac[] ) >>
  conj_tac >- (
    rw[] >> fs[] >>
    fs[Once (Q.SPECL[`τ`,`Fun X Y`](CONJUNCT1 semantics_cases))] >>
    imp_res_tac semantics_11 >>
    rpt BasicProvers.VAR_EQ_TAC >>
    qexists_tac`my` >> simp[] >>
    match_mp_tac APPLY_IN_RANSPACE >>
    qmatch_assum_rename_tac`typeset τ (typeof u) tu`[] >>
    qexists_tac`tu` >> simp[]) >>
  rw[] >> fs[] >>
  simp[Once semantics_cases] >>
  imp_res_tac WELLTYPED_LEMMA >>
  fs[WELLTYPED] >> fsrw_tac[DNF_ss][] >>
  BasicProvers.VAR_EQ_TAC >>
  qmatch_assum_rename_tac`typeset τ (typeof t) mtt`[] >>
  map_every qexists_tac[`mty`,`mtt`] >> rw[] >>
  match_mp_tac ABSTRACT_IN_FUNSPACE >> rw[])

val semantics_raconv = store_thm("semantics_raconv",
  ``∀env tp.
      RACONV env tp ⇒
      ∀σ1 σ2 τ.
        type_valuation τ ∧
        term_valuation τ σ1 ∧
        term_valuation τ σ2 ∧
        (∀x1 ty1 x2 ty2.
          ALPHAVARS env (Var x1 ty1,Var x2 ty2) ⇒
            (semantics σ1 τ (Var x1 ty1) =
             semantics σ2 τ (Var x2 ty2))) ∧
        EVERY (λ(x,y). welltyped x ∧ welltyped y ∧ typeof x = typeof y) env ∧
        welltyped (FST tp) ∧ welltyped (SND tp)
        ⇒
        (semantics σ1 τ (FST tp) =
         semantics σ2 τ (SND tp))``,
  ho_match_mp_tac RACONV_strongind >>
  simp[FORALL_PROD] >>
  conj_tac >- (
    rw[] >>
    simp[Once FUN_EQ_THM] >>
    simp[Once semantics_cases] >>
    simp[Once semantics_cases,SimpRHS] ) >>
  conj_tac >- (
    rw[] >>
    simp[Once FUN_EQ_THM] >>
    simp[Once semantics_cases] >>
    simp[Once semantics_cases,SimpRHS] >>
    simp[Once (CONJUNCT1 semantics_cases)] >>
    simp[Once (CONJUNCT1 semantics_cases),SimpRHS] >>
    srw_tac[DNF_ss][] >> rfs[] >>
    `semantics σ1 τ s1 = semantics σ2 τ s2` by metis_tac[] >>
    `semantics σ1 τ t1 = semantics σ2 τ t2` by metis_tac[] >>
    simp[] >>
    EQ_TAC >>
    strip_tac >>
    map_every qexists_tac[`mt`,`mu`] >> rw[] >>
    `∃msy. typeset τ (typeof s2) msy ∧ mt <: msy` by metis_tac[semantics_typeset,WELLTYPED] >>
    `∃msy. typeset τ (typeof s1) msy ∧ mt <: msy` by metis_tac[semantics_typeset,WELLTYPED] >>
    rfs[Once(Q.SPECL[`τ`,`Fun X Y`](CONJUNCT1 semantics_cases))] >>
    metis_tac[] ) >>
  rw[] >>
  simp[Once FUN_EQ_THM] >>
  simp[Once semantics_cases] >>
  simp[Once semantics_cases,SimpRHS] >>
  rw[] >>
  rw[EQ_IMP_THM] >>
  map_every qexists_tac[`mb`,`mty`,`mtyb`,`tyb`] >>
  simp[] >>
  qmatch_assum_abbrev_tac`RACONV env' (t1,t2)` >>
  qspecl_then[`env'`,`t1,t2`]mp_tac RACONV_TYPE >>
  simp[Abbr`env'`] >> strip_tac >>
  (conj_tac >- metis_tac[WELLTYPED,WELLTYPED_LEMMA]) >>
  rw[] >>
  first_x_assum(qspec_then`x`mp_tac) >> rw[] >>
  qmatch_abbrev_tac`semantics σ2' τ tq m` >>
  qmatch_assum_abbrev_tac`semantics σ1' τ tp m` >>
  (qsuff_tac`semantics σ1' τ tp = semantics σ2' τ tq` >- metis_tac[]) >>
  (first_x_assum match_mp_tac ORELSE (match_mp_tac EQ_SYM >> first_x_assum match_mp_tac)) >>
  fs[term_valuation_def] >>
  (conj_tac >- (
    simp[Abbr`σ2'`,Abbr`σ1'`] >>
    match_mp_tac (CONJUNCT2 FEVERY_STRENGTHEN_THM) >>
    simp[] >> metis_tac[] )) >>
  (conj_tac >- (
    simp[Abbr`σ2'`,Abbr`σ1'`] >>
    match_mp_tac (CONJUNCT2 FEVERY_STRENGTHEN_THM) >>
    simp[] >> metis_tac[] )) >>
  simp[ALPHAVARS_def] >>
  (rw[] >- (
    simp[FUN_EQ_THM] >>
    simp[Once semantics_cases] >>
    simp[Once semantics_cases,SimpRHS] >>
    simp[FLOOKUP_DEF,Abbr`σ1'`,Abbr`σ2'`] )) >>
  qmatch_assum_rename_tac`ALPHAVARS env (Var va vta, Var vb vtb)`[] >>
  first_x_assum(qspecl_then[`va`,`vta`,`vb`,`vtb`]mp_tac) >>
  simp[] >>
  simp[FUN_EQ_THM,Once(CONJUNCT2 semantics_cases)] >>
  simp[Once(CONJUNCT2 semantics_cases)] >>
  simp[Once(CONJUNCT2 semantics_cases)] >>
  simp[Once(CONJUNCT2 semantics_cases)] >>
  simp[Abbr`σ1'`,Abbr`σ2'`,FLOOKUP_UPDATE])

val semantics_aconv = store_thm("semantics_aconv",
  ``∀σ τ s t.
      type_valuation τ ∧ term_valuation τ σ ∧ welltyped s ∧ ACONV s t
      ⇒ semantics σ τ s = semantics σ τ t``,
  rw[] >> imp_res_tac ACONV_welltyped >>
  fs[ACONV_def]  >>
  qspecl_then[`[]`,`s,t`] mp_tac semantics_raconv >>
  rw[] >> first_x_assum match_mp_tac >> rw[] >>
  fs[ALPHAVARS_def])

val semantics_vfree_in = store_thm("semantics_vfree_in",
  ``∀τ σ1 σ2 t.
      type_valuation τ ∧
      term_valuation τ σ1 ∧ term_valuation τ σ2 ∧
      welltyped t ∧
      (∀x ty. VFREE_IN (Var x ty) t ⇒ (FLOOKUP σ1 (x,ty) = FLOOKUP σ2 (x,ty)))
      ⇒ semantics σ1 τ t = semantics σ2 τ t``,
  gen_tac >> (CONV_TAC (RESORT_FORALL_CONV List.rev)) >> Induct
  >- (
    rw[FUN_EQ_THM] >>
    rw[Once semantics_cases] >>
    rw[Once semantics_cases] )
  >- (
    rw[FUN_EQ_THM] >>
    rw[Once semantics_cases] >>
    rw[Once semantics_cases,SimpRHS] )
  >- (
    rw[FUN_EQ_THM] >>
    rw[Once semantics_cases] >>
    rw[Once semantics_cases,SimpRHS] >>
    metis_tac[]) >>
  rw[FUN_EQ_THM] >>
  rw[Once semantics_cases] >>
  rw[Once semantics_cases,SimpRHS] >>
  rw[EQ_IMP_THM] >>
  map_every qexists_tac[`mb`,`mty`,`mtyb`,`tyb`] >>
  rw[] >>
  (qsuff_tac`semantics (σ1 |+ ((s,t),x)) τ t' = semantics (σ2 |+ ((s,t),x)) τ t'` >- metis_tac[]) >>
  first_x_assum match_mp_tac >>
  fs[term_valuation_def] >>
  rw[FLOOKUP_UPDATE] >>
  TRY (
    match_mp_tac (CONJUNCT2 FEVERY_STRENGTHEN_THM) >>
    fs[] >> metis_tac[] ) >>
  fs[] )

val _ = Parse.add_infix("closes_over",450,Parse.NONASSOC)
val _ = Parse.overload_on("closes_over",``λσ t. ∀x ty. VFREE_IN (Var x ty) t ⇒ (x,ty) ∈ FDOM σ``)

val semantics_closes_over = store_thm("semantics_closes_over",
  ``∀t σ τ m. type_valuation τ ∧ semantics σ τ t m ⇒ σ closes_over t``,
  Induct
  >- (
    simp[Once semantics_cases,FLOOKUP_DEF] )
  >- (
    simp[Once semantics_cases] )
  >- (
    simp[Once semantics_cases] >>
    rw[] >> metis_tac[])
  >- (
    simp[Once semantics_cases] >>
    rpt gen_tac >> strip_tac >>
    `∃x. x <: mty` by metis_tac[typeset_inhabited] >>
    res_tac >>
    fs[FDOM_FUPDATE] >>
    metis_tac[]))

val closes_over_aconv = store_thm("closes_over_aconv",
  ``∀σ t t'. σ closes_over t ∧ ACONV t t' ⇒ σ closes_over t'``,
  rw[] >> metis_tac[VFREE_IN_ACONV])

val closes_over_equation = store_thm("closes_over_equation",
  ``σ closes_over l === r ⇔ σ closes_over l ∧ σ closes_over r``,
  rw[vfree_in_equation] >> metis_tac[])

val closes_over_extend = store_thm("closes_over_extend",
  ``∀σ t σ'. σ closes_over t ∧ σ ⊑ σ' ⇒ σ' closes_over t``,
  rw[SUBMAP_DEF])

val tac =
  qho_match_abbrev_tac`apply (apply (abstract a b f) x) y = z` >>
  `apply (abstract a b f) x = f x` by (
    match_mp_tac APPLY_ABSTRACT >>
    unabbrev_all_tac >> simp[] >>
    conj_tac >- metis_tac[semantics_typeset,semantics_11,WELLTYPED] >>
    match_mp_tac ABSTRACT_IN_FUNSPACE >>
    metis_tac[semantics_typeset,WELLTYPED,BOOLEAN_IN_BOOLSET] ) >>
  simp[Abbr`f`,Abbr`b`] >>
  qho_match_abbrev_tac`apply (abstract a b f) y = z` >>
  `apply (abstract a b f) y = f y `  by (
    match_mp_tac APPLY_ABSTRACT >>
    unabbrev_all_tac >> simp[] >>
    metis_tac[semantics_typeset,semantics_11,WELLTYPED,BOOLEAN_IN_BOOLSET] ) >>
  unabbrev_all_tac >> simp[]

val semantics_equation = store_thm("semantics_equation",
  ``∀σ τ s t mty ms mt mst.
    type_valuation τ ∧ term_valuation τ σ ∧
    semantics σ τ s ms ∧ semantics σ τ t mt ∧
    (typeof s = typeof t) ∧ mst = boolean (ms = mt)
    ⇒ semantics σ τ (s === t) mst``,
  rw[equation_def] >>
  simp[Once semantics_cases] >>
  simp[Once semantics_cases] >>
  simp[Once semantics_cases] >>
  srw_tac[DNF_ss][] >>
  imp_res_tac semantics_typeset >> simp[] >>
  map_every qexists_tac[`mt`,`ms`,`mty`] >> simp[] >>
  match_mp_tac EQ_SYM >> tac)

val semantics_equation_imp = store_thm("semantics_equation_imp",
  ``∀σ τ s t mst.
    type_valuation τ ∧ term_valuation τ σ ∧ semantics σ τ (s === t) mst ⇒
    ∃ms mt.
    semantics σ τ s ms ∧ semantics σ τ t mt ∧
    (typeof s = typeof t) ∧ mst = boolean (ms = mt)``,
  rw[equation_def] >>
  fs[Q.SPECL[`σ`,`τ`,`Comb X Y`](CONJUNCT2 semantics_cases)] >>
  fs[Q.SPECL[`σ`,`τ`,`Equal X`](CONJUNCT2 semantics_cases)] >>
  qmatch_assum_rename_tac`semantics σ τ s ms`[] >> rw[] >>
  qmatch_assum_rename_tac`semantics σ τ t mt`[] >>
  map_every qexists_tac[`ms`,`mt`] >> rw[] >> tac)

val term_valuation_extend = store_thm("term_valuation_extend",
  ``∀τ σ σ'. term_valuation τ σ' ∧ σ ⊑ σ' ⇒ term_valuation τ σ``,
  metis_tac[term_valuation_def,FEVERY_SUBMAP])

val semantics_extend_term_valuation = store_thm("semantics_extend_term_valuation",
  ``∀σ τ t m σ'. type_valuation τ ∧ term_valuation τ σ' ∧
                 semantics σ τ t m ∧ σ ⊑ σ'
                 ⇒ semantics σ' τ t m``,
  rw[] >>
  imp_res_tac term_valuation_extend >>
  `welltyped t` by metis_tac[semantics_typeset] >>
  `σ closes_over t` by metis_tac[semantics_closes_over] >>
  qsuff_tac`semantics σ' τ t = semantics σ τ t`>-rw[] >>
  match_mp_tac semantics_vfree_in >> simp[] >>
  fs[SUBMAP_DEF,FLOOKUP_DEF])

val semantics_reduce_term_valuation = store_thm("semantics_reduce_term_valuation",
  ``∀σ τ t m σ'. type_valuation τ ∧ term_valuation τ σ' ∧
                 semantics σ' τ t m ∧ σ ⊑ σ' ∧
                 σ closes_over t
                 ⇒ semantics σ τ t m``,
  rw[] >>
  imp_res_tac term_valuation_extend >>
  `welltyped t` by metis_tac[semantics_typeset] >>
  qsuff_tac`semantics σ τ t = semantics σ' τ t`>-rw[] >>
  match_mp_tac semantics_vfree_in >> simp[] >>
  fs[SUBMAP_DEF,FLOOKUP_DEF])

val has_meaning_def = Define`
  has_meaning t = ∀τ σ. type_valuation τ ∧ term_valuation τ σ ⇒
    ∃σ' m. σ ⊑ σ' ∧ term_valuation τ σ' ∧ σ' closes_over t ∧
           semantics σ' τ t m`

val has_meaning_welltyped = store_thm("has_meaning_welltyped",
  ``∀t. has_meaning t ⇒ welltyped t``,
  rw[has_meaning_def] >>
  metis_tac[a_type_valuation_exists,semantics_typeset
           ,term_valuation_def,CONJUNCT1 FEVERY_STRENGTHEN_THM
           ,SUBMAP_FEMPTY])

val has_meaning_aconv = store_thm("has_meaning_aconv",
  ``∀t t'. has_meaning t ∧ ACONV t t' ⇒ has_meaning t'``,
  rw[] >>
  imp_res_tac has_meaning_welltyped >>
  fs[has_meaning_def] >> rw[] >>
  metis_tac[semantics_aconv,closes_over_aconv,ACONV_welltyped])

val equation_has_meaning = store_thm("equation_has_meaning",
  ``∀s t. has_meaning s ∧ has_meaning t ∧ typeof s = typeof t ⇒ has_meaning (s === t)``,
  rw[has_meaning_def] >>
  first_x_assum(qspecl_then[`τ`,`σ`]mp_tac) >> simp[] >>
  disch_then(qx_choosel_then[`σ1`,`m1`]strip_assume_tac) >>
  first_x_assum(qspecl_then[`τ`,`σ1`]mp_tac) >> simp[] >>
  disch_then(qx_choosel_then[`σ2`,`m2`]strip_assume_tac) >>
  map_every qexists_tac[`σ2`,`boolean(m1=m2)`] >>
  conj_asm1_tac >- metis_tac[SUBMAP_TRANS] >>
  conj_asm1_tac >- metis_tac[term_valuation_extend] >>
  simp[closes_over_equation] >>
  conj_tac >- metis_tac[closes_over_extend] >>
  match_mp_tac semantics_equation >> simp[] >>
  map_every qexists_tac[`m2`,`m1`] >> simp[boolean_def] >>
  metis_tac[semantics_extend_term_valuation])

val equation_has_meaning_iff = store_thm("equation_has_meaning_iff",
  ``∀s t. has_meaning (s === t) ⇔ has_meaning s ∧ has_meaning t ∧ typeof s = typeof t``,
  rw[] >> reverse EQ_TAC >- metis_tac[equation_has_meaning] >>
  simp[has_meaning_def] >> strip_tac >>
  simp[CONJ_ASSOC] >>
  simp[GSYM FORALL_AND_THM,GSYM IMP_CONJ_THM] >>
  reverse conj_tac >- (
    strip_assume_tac a_type_valuation_exists >>
    first_x_assum(qspecl_then[`τ`,`FEMPTY`]mp_tac) >>
    simp[SUBMAP_FEMPTY] >>
    disch_then(qx_choosel_then[`σ`,`me`]strip_assume_tac) >>
    `welltyped (s === t)` by metis_tac[semantics_typeset] >>
    fs[equation_def]) >>
  rpt gen_tac >> strip_tac >>
  first_x_assum(qspecl_then[`τ`,`σ`]mp_tac) >> simp[] >>
  strip_tac >> fs[closes_over_equation] >>
  pop_assum mp_tac >>
  simp[Once (CONJUNCT2 semantics_cases),equation_def] >>
  simp[Once (CONJUNCT2 semantics_cases)] >> rw[] >>
  metis_tac[])

val _ = Parse.add_infix("|=",450,Parse.NONASSOC)

val sequent_def = xDefine"sequent"`
  h |= c ⇔ EVERY (λt. t has_type Bool) (c::h) ∧
           EVERY has_meaning (c::h) ∧
           ∀σ τ. type_valuation τ ∧
                 term_valuation τ σ ∧
                 EVERY (λt. semantics σ τ t true) h ∧
                 σ closes_over c
                 ⇒
                 semantics σ τ c true`

val ASSUME_correct = store_thm("ASSUME_correct",
  ``∀p. has_meaning p ∧ p has_type Bool ⇒ [p] |= p``,
  rw[sequent_def])

val REFL_correct = store_thm("REFL_correct",
  ``∀t. has_meaning t ⇒ [] |= t === t``,
  rw[sequent_def,EQUATION_HAS_TYPE_BOOL,has_meaning_welltyped,equation_has_meaning] >>
  match_mp_tac semantics_equation >>
  fs[has_meaning_def,closes_over_equation] >>
  simp[boolean_def] >>
  metis_tac[semantics_reduce_term_valuation])

val binary_inference_rule = store_thm("binary_inference_rule",
  ``∀h1 h2 p1 p2 q.
    (p1 has_type Bool ∧ p2 has_type Bool ⇒ q has_type Bool) ∧
    (has_meaning p1 ∧ has_meaning p2 ⇒ has_meaning q) ∧
    (∀σ τ. type_valuation τ ∧ term_valuation τ σ ∧
           semantics σ τ p1 true ∧ semantics σ τ p2 true ∧
           σ closes_over q ⇒
           semantics σ τ q true) ∧
    h1 |= p1 ∧ h2 |= p2
    ⇒ TERM_UNION h1 h2 |= q``,
  rpt gen_tac >> strip_tac >>
  fs[sequent_def,ALL_BOOL_TERM_UNION] >>
  conj_tac >- (
    fs[EVERY_MEM] >>
    metis_tac[TERM_UNION_NONEW,TERM_UNION_THM,has_meaning_aconv] ) >>
  rw[] >>
  `∃σ1 m1. σ ⊑ σ1 ∧ term_valuation τ σ1 ∧ σ1 closes_over p1 ∧ semantics σ1 τ p1 m1` by
    metis_tac[has_meaning_def] >>
  `∃σ2 m2. σ1 ⊑ σ2 ∧ term_valuation τ σ2 ∧ σ2 closes_over p2 ∧ semantics σ2 τ p2 m2` by
    metis_tac[has_meaning_def] >>
  `semantics σ2 τ p1 m1` by metis_tac[semantics_extend_term_valuation] >>
  `σ2 closes_over p1` by metis_tac[closes_over_extend] >>
  `σ ⊑ σ2` by metis_tac[SUBMAP_TRANS] >>
  `semantics σ2 τ p1 true ∧ semantics σ2 τ p2 true` by (
    conj_tac >>
    first_x_assum match_mp_tac >> simp[] >>
    fs[EVERY_MEM] >>
    metis_tac[TERM_UNION_THM,semantics_aconv,welltyped_def
             ,TERM_UNION_NONEW,semantics_extend_term_valuation]) >>
  `m1 = true ∧ m2 = true` by metis_tac[semantics_11] >>
  `semantics σ2 τ q true` by (
    first_x_assum match_mp_tac >>
    simp[] >> metis_tac[closes_over_extend] ) >>
  metis_tac[semantics_reduce_term_valuation])

val TRANS_correct = store_thm("TRANS_correct",
  ``∀h1 h2 l m1 m2 r.
      h1 |= l === m1 ∧ h2 |= m2 === r ∧ ACONV m1 m2
      ⇒ TERM_UNION h1 h2 |= l === r``,
  rw[] >> match_mp_tac binary_inference_rule >>
  map_every qexists_tac[`l === m1`,`m2 === r`] >>
  simp[EQUATION_HAS_TYPE_BOOL] >>
  conj_tac >- metis_tac[ACONV_TYPE] >>
  conj_tac >- (
    fs[equation_has_meaning_iff] >>
    metis_tac[has_meaning_welltyped,ACONV_TYPE] ) >>
  rw[] >>
  match_mp_tac semantics_equation >>
  qspecl_then[`σ`,`τ`,`l`,`m1`,`true`]mp_tac semantics_equation_imp >> simp[] >>
  disch_then(qx_choosel_then[`ml`,`mm1`]strip_assume_tac) >>
  qspecl_then[`σ`,`τ`,`m2`,`r`,`true`]mp_tac semantics_equation_imp >> simp[] >>
  disch_then(qx_choosel_then[`mm2`,`mr`]strip_assume_tac) >>
  map_every qexists_tac[`ml`,`mr`] >>
  `semantics σ τ m1 mm2` by metis_tac[semantics_aconv,semantics_typeset] >>
  `mm1 = mm2` by metis_tac[semantics_11] >>
  `typeof m1 = typeof m2` by metis_tac[ACONV_TYPE,semantics_typeset] >>
  fs[boolean_def] >> rw[] >> fs[] >> rfs[])

val _ = export_theory()

