open HolKernel Parse boolLib bossLib;

val _ = new_theory "repl_fun_alt_proof";

open arithmeticTheory relationTheory listTheory lexer_implTheory;
open repl_funTheory repl_fun_altTheory bytecodeLabelsTheory bytecodeTheory;
open lcsymtacs bytecodeEvalTheory bytecodeExtraTheory;

infix \\ val op \\ = op THEN;

val code_executes_ok_def = Define `
  code_executes_ok s1 =
    let len i = if is_Label i then 0 else s1.inst_length i + 1 in
      (* termination *)
      (?s2 b. bc_next^* s1 s2 /\ bc_fetch s2 = SOME (Stop b)) \/
      (* or divergence with no output *)
      !n. ?s2. NRC bc_next n s1 s2 /\ (s2.output = s1.output)`;

(* We start by defining a new version of repl_fun called repl_fun'
   which brings with it a proof of side conditions. *)

val initial_bc_state_side_def = Define `
  initial_bc_state_side =
    let bs1 = empty_bc_state in
    let bs2 = install_code (SND (SND compile_primitives)) bs1 in
    let bs3 = bc_eval bs2 in
    let bs4 = THE bs3 in
      IS_SOME bs3 /\
      (bs4.pc = next_addr bs1.inst_length bs4.code) /\
      (bs4.stack <> [])`;

val tac = (WF_REL_TAC `measure (LENGTH o SND)` \\ REPEAT STRIP_TAC
           \\ IMP_RES_TAC lex_until_toplevel_semicolon_LESS);

val main_loop'_def = tDefine "main_loop'" `
  main_loop' (bs,s) input =
   case lex_until_toplevel_semicolon input of
   | NONE => (Terminate,T)
   | SOME (tokens,rest_of_input) =>
     case parse_elaborate_infertype_compile tokens s of
     | Success (code,s',s_exc) =>
       let code_assert = code_labels_ok bs.code in
       let s1 = install_code code bs in
       let code_assert = (code_assert /\ code_executes_ok s1) in
       (case bc_eval s1 of
        | NONE => (Diverge,code_assert)
        | SOME new_bs =>
          (case bc_fetch new_bs of
           | SOME (Stop success) =>
             let new_s = if success then s' else s_exc in
             let (res,assert) = main_loop' (new_bs,new_s) rest_of_input in
               (Result (new_bs.output) res, assert /\ code_assert)
           | _ => (ARB,F)))
     | Failure error_msg =>
         let (res,assert) = main_loop' (bs,s) rest_of_input in
           (Result error_msg res, assert)` tac

val repl_fun'_def = Define `
  repl_fun' input =
    let a1 = initial_bc_state_side in
    let (res,a2) = main_loop' (initial_bc_state,initial_repl_fun_state) input in
      (res,a1 /\ a2)`;

(* Theorem relating repl_fun' with repl_fun *)

val main_loop'_thm = prove(
  ``!bs s input. (\(bs,s) input. !res b.
      (main_loop' (bs,s) input = (res,b)) ==>
      (main_loop (bs,s) input = res)) (bs,s) input``,
  HO_MATCH_MP_TAC main_loop_ind \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [PULL_FORALL]
  \\ SIMP_TAC std_ss [Once main_loop'_def,Once main_loop_def]
  \\ Cases_on `lex_until_toplevel_semicolon input`
  \\ SIMP_TAC std_ss [] \\ Cases_on `x`
  \\ Q.MATCH_ASSUM_RENAME_TAC
       `lex_until_toplevel_semicolon input = SOME (ts,rest)` []
  \\ FULL_SIMP_TAC (srw_ss()) []
  \\ REVERSE (Cases_on `parse_elaborate_infertype_compile ts s`)
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF]
  THEN1 (Cases_on `main_loop' (bs,s) rest` \\ FULL_SIMP_TAC std_ss [])
  \\ `?code s1 s2. a = (code,s1,s2)` by METIS_TAC [pairTheory.PAIR]
  \\ FULL_SIMP_TAC (srw_ss()) []
  \\ Cases_on `bc_eval (install_code code bs)`
  \\ FULL_SIMP_TAC (srw_ss()) []
  \\ Cases_on`bc_fetch x` \\ FULL_SIMP_TAC (srw_ss())[]
  \\ Q.MATCH_ASSUM_RENAME_TAC`bc_fetch x = SOME i`[]
  \\ Cases_on`i` \\ FULL_SIMP_TAC (srw_ss())[]
  \\ Cases_on `main_loop' (x,if b then s1 else s2) rest`
  \\ FULL_SIMP_TAC (srw_ss()) []) |> SIMP_RULE std_ss [];

val repl_fun'_thm = store_thm("repl_fun'_thm",
  ``!input res b. (repl_fun' input = (res,b)) ==> (repl_fun input = res)``,
  SIMP_TAC std_ss [repl_fun_def,repl_fun'_def,LET_DEF] \\ REPEAT STRIP_TAC
  \\ Cases_on `main_loop' (initial_bc_state,initial_repl_fun_state) input`
  \\ FULL_SIMP_TAC std_ss [] \\ METIS_TAC [main_loop'_thm]);


(* proof of repl_fun_alt' = repl_fun' *)

val tac = (WF_REL_TAC `measure (LENGTH o FST o SND)` \\ REPEAT STRIP_TAC
           \\ IMP_RES_TAC lex_until_top_semicolon_alt_LESS);

val main_loop_alt'_def = tDefine "main_loop_alt'" `
  main_loop_alt' bs input state init =
    case repl_step state of
      | INR (error_msg,x) =>
       (case lex_until_top_semicolon_alt input of
        | NONE => (Result error_msg Terminate,T)
        | SOME (ts,rest) =>
            let (res,assert) = main_loop_alt' bs rest (SOME (ts,x)) F in
              (Result error_msg res, assert))
      | INL (code,new_state) =>
        let bs = (install_bc_lists code bs) in
        let code_assert = code_executes_ok bs in
          case bc_eval bs of
          | NONE => (Diverge,code_assert)
          | SOME new_bs =>
            let new_s = (bc_fetch new_bs = SOME (Stop T)) in
            let out = if init then I else Result (REVERSE new_bs.output) in
              (case lex_until_top_semicolon_alt input of
               | NONE => (out Terminate,code_assert)
               | SOME (ts,rest) =>
                  let (res,assert) =
                    main_loop_alt' new_bs rest (SOME (ts,new_s,new_state)) F in
                      (out res, assert /\ code_assert)) `
  tac

val repl_fun_alt'_def = Define `
  repl_fun_alt' input =
    let a1 = initial_bc_state_side in
    let (res,a2) = main_loop_alt' empty_bc_state input NONE T in
      (res,a1 /\ a2)`;

val bc_eval_SOME_code = prove(
  ``(bc_eval bs1 = SOME bs2) ==> (bs2.code = bs1.code)``,
  REPEAT STRIP_TAC
  \\ IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
  \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves);

val temp_def = Define `
  temp x y = (SND y ==> (x = y))`;

val temp_simp = prove(
  ``!f1 f2.
      temp ((\(res,assert). (Result b' res,assert)) f1)
           ((\(res,assert). (Result b' res,assert)) f2) =
      temp f1 f2``,
  Cases \\ Cases \\ FULL_SIMP_TAC (srw_ss()) [temp_def]);

val temp_REFL = prove(
  ``!x. temp x x``,
  Cases \\ FULL_SIMP_TAC (srw_ss()) [temp_def]);

val bc_next_output = prove(
  ``!x y. bc_next x y ==> isPREFIX x.output y.output``,
  HO_MATCH_MP_TAC bc_next_ind \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC (srw_ss()) [bump_pc_def] \\ SRW_TAC [] []
  \\ SRW_TAC[][rich_listTheory.IS_PREFIX_SNOC]
  \\ rw[bc_fetch_with_stack]);

val bc_next_output = prove(
  ``!x y. bc_next^* x y ==> isPREFIX x.output y.output``,
  HO_MATCH_MP_TAC RTC_INDUCT
  \\ FULL_SIMP_TAC std_ss [rich_listTheory.IS_PREFIX_REFL]
  \\ REPEAT STRIP_TAC \\ IMP_RES_TAC bc_next_output
  \\ IMP_RES_TAC rich_listTheory.IS_PREFIX_TRANS);

val bc_output = prove(
  ``RTC bc_next x y /\ RTC bc_next y z /\ (z.output = x.output) ==>
    (y.output = x.output)``,
  REPEAT STRIP_TAC \\ IMP_RES_TAC bc_next_output
  \\ METIS_TAC [rich_listTheory.IS_PREFIX_ANTISYM]);

val code_executes_ok_strip_labels = prove(
  ``code_executes_ok bs1 /\ length_ok bs1.inst_length ==>
    code_executes_ok (strip_labels bs1)``,
  SIMP_TAC std_ss [code_executes_ok_def,GSYM ilength_def,LET_DEF]
  \\ REPEAT STRIP_TAC THEN1
   (DISJ1_TAC \\ Q.EXISTS_TAC `strip_labels s2`
    \\ IMP_RES_TAC bc_next_strip_labels_RTC
    \\ FULL_SIMP_TAC std_ss []
    \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
    \\ METIS_TAC [bc_fetch_strip_labels])
  \\ DISJ2_TAC \\ REPEAT GEN_TAC
  \\ POP_ASSUM MP_TAC
  \\ POP_ASSUM (STRIP_ASSUME_TAC o Q.SPECL [`n`]) \\ STRIP_TAC
  \\ Q.EXISTS_TAC `strip_labels s2`
  \\ POP_ASSUM MP_TAC
  \\ POP_ASSUM MP_TAC
  \\ POP_ASSUM MP_TAC
  \\ Q.SPEC_TAC (`bs1`,`s1`)
  \\ Q.SPEC_TAC (`s2`,`s2`)
  \\ Induct_on `n`
  THEN1 (ONCE_REWRITE_TAC [NRC_0] \\ SIMP_TAC (srw_ss()) [strip_labels_def])
  \\ ONCE_REWRITE_TAC [NRC]
  \\ SIMP_TAC std_ss [PULL_FORALL,PULL_EXISTS] \\ REPEAT STRIP_TAC
  \\ Q.EXISTS_TAC `strip_labels z`
  \\ `bc_next^* s1 z` by METIS_TAC [RTC_RULES] \\ IMP_RES_TAC NRC_RTC
  \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
  \\ FULL_SIMP_TAC std_ss [strip_labels_output,AND_IMP_INTRO]
  \\ REVERSE STRIP_TAC THEN1
   (Q.PAT_ASSUM `!xx.bbb` MATCH_MP_TAC \\ FULL_SIMP_TAC std_ss []
    \\ IMP_RES_TAC bc_output \\ FULL_SIMP_TAC std_ss [])
  \\ MATCH_MP_TAC (bc_next_strip_labels |> REWRITE_RULE [AND_IMP_INTRO])
  \\ FULL_SIMP_TAC std_ss []);

val next_addr_thm = prove(
  ``!xs l. next_addr l xs = code_length l xs``,
  Induct \\ SRW_TAC [] [code_length_def,ilength_def,ADD1]
  \\ FULL_SIMP_TAC std_ss []);

val temp_assum = prove(
  ``temp x y <=> (SND y ==> temp x y)``,
  SIMP_TAC std_ss [temp_def]);

val unstrip_labels = prove(
  ``!bs1 bs2. length_ok bs1.inst_length /\
              bc_next (strip_labels bs1) bs2 ==> ?bs3. bc_next bs1 bs3``,
  METIS_TAC [bc_next_strip_IMP]);

val bc_next_strip_labels_NRC = store_thm("bc_next_strip_labels_NRC",
  ``!n s1 s2. length_ok s1.inst_length /\ NRC bc_next n s1 s2 ==>
              NRC bc_next n (strip_labels s1) (strip_labels s2)``,
  Induct >> simp[NRC] >> rw[] >>
  qexists_tac`strip_labels z` >>
  METIS_TAC[bc_next_strip_labels,bc_next_preserves_inst_length])

val unstrip_labels_NRC = store_thm("unstrip_labels_NRC",
  ``!n bs1 bs2. length_ok bs1.inst_length /\
                NRC bc_next n (strip_labels bs1) bs2 ==>
                ?bs3. NRC bc_next n bs1 bs3``,
  Induct >> simp[NRC] >> rw[] >>
  imp_res_tac unstrip_labels >>
  `z = strip_labels bs3` by METIS_TAC[bc_next_strip_labels,bc_eval1_thm,optionTheory.SOME_11] >>
  `length_ok z.inst_length` by METIS_TAC[strip_labels_inst_length,bc_next_preserves_inst_length] >>
  `NRC bc_next n (strip_labels bs3) (strip_labels bs2)` by METIS_TAC[bc_next_strip_labels_NRC,strip_labels_idempot] >>
  METIS_TAC[strip_labels_inst_length] )

val NRC_bc_next_determ = store_thm("NRC_bc_next_determ",
  ``!n s1 s2. NRC bc_next n s1 s2 ==> !s3. NRC bc_next n s1 s3 ==> s3 = s2``,
  Induct>>simp[NRC]>>rw[]>>fs[bc_eval1_thm]>> METIS_TAC[])

val bc_eval_NONE_strip_labels = prove(
  ``(bc_eval bs1 = NONE) /\ code_executes_ok bs1 /\
    length_ok bs1.inst_length ==>
    (bc_eval (strip_labels bs1) = NONE)``,
  rw[] >>
  `!bs2. bc_next^* bs1 bs2 ==> ?bs3. bc_next bs2 bs3` by (
    rw[] >> spose_not_then strip_assume_tac >>
    imp_res_tac RTC_bc_next_bc_eval >>
    fs[] ) >>
  Cases_on`bc_eval (strip_labels bs1)`>>rw[] >>
  imp_res_tac bc_eval_SOME_RTC_bc_next >>
  imp_res_tac bc_next_strip_labels_RTC >>
  rfs[strip_labels_inst_length] >>
  `strip_labels (strip_labels bs1) = strip_labels bs1` by METIS_TAC[strip_labels_idempot] >>
  fs[] >>
  `length_ok x.inst_length` by ALL_TAC THEN1
    (IMP_RES_TAC RTC_bc_next_preserves
     \\ FULL_SIMP_TAC (srw_ss()) [strip_labels_def]) >>
  qsuff_tac`?bs3. bc_next (strip_labels x) bs3` >- METIS_TAC[unstrip_labels] >>
  `?n. NRC bc_next n (strip_labels bs1) x` by METIS_TAC[RTC_eq_NRC] >>
  `?bs3. NRC bc_next n bs1 bs3` by METIS_TAC[unstrip_labels_NRC] >>
  `NRC bc_next n (strip_labels bs1) (strip_labels bs3)` by METIS_TAC[bc_next_strip_labels_NRC] >>
  `?bs4. bc_next bs3 bs4` by METIS_TAC[RTC_eq_NRC] >>
  `length_ok bs3.inst_length` by METIS_TAC[RTC_bc_next_preserves,RTC_eq_NRC] >>
  qsuff_tac`strip_labels x = strip_labels bs3` >- METIS_TAC[bc_next_strip_labels] >>
  METIS_TAC[NRC_bc_next_determ,strip_labels_idempot])

val bc_eval_SOME_strip_labels = prove(
  ``(bc_eval bs1 = SOME bs2) /\ code_executes_ok bs1 /\
    length_ok bs1.inst_length ==>
    (bc_eval (strip_labels bs1) = SOME (strip_labels bs2))``,
  rw[] >>
  imp_res_tac bc_eval_SOME_RTC_bc_next >>
  imp_res_tac bc_next_strip_labels_RTC >>
  imp_res_tac RTC_bc_next_bc_eval >>
  first_x_assum match_mp_tac >>
  `length_ok bs2.inst_length` by ALL_TAC THEN1
    (IMP_RES_TAC RTC_bc_next_preserves
     \\ FULL_SIMP_TAC (srw_ss()) [strip_labels_def]) >>
  METIS_TAC[unstrip_labels]);

val length_ok_inst_length = prove(
  ``length_ok real_inst_length``,
  EVAL_TAC \\ SIMP_TAC std_ss []);

val install_code_NIL = prove(
  ``install_code code (install_code [] bs) =
    install_code code bs``,
  SIMP_TAC (srw_ss()) [install_code_def]);

val lex_lemma = prove(
  ``lex_until_toplevel_semicolon input =
    case lex_until_top_semicolon_alt input of
    | NONE => NONE
    | SOME (ts,rest) => SOME (MAP token_of_sym ts, rest)``,
  ASSUME_TAC lex_until_top_semicolon_alt_thm
  \\ Cases_on `lex_until_top_semicolon_alt input` \\ TRY (Cases_on `x`)
  \\ FULL_SIMP_TAC (srw_ss()) []);

val install_bc_lists_MAP_bc_num = prove(
  ``!code bs. install_bc_lists (MAP bc_num code ++ xs) bs =
              install_bc_lists xs (bs with <| code := bs.code ++ code |>)``,
  Induct \\ SIMP_TAC std_ss [install_bc_lists_def,APPEND,MAP,APPEND_NIL]
  THEN1 (REPEAT STRIP_TAC \\ AP_TERM_TAC
    \\ SIMP_TAC (srw_ss()) (TypeBase.updates_of ``:bc_state``))
  \\ REPEAT STRIP_TAC
  \\ `FST (bc_num h) <> 18` by ALL_TAC
  THEN1 (Cases_on `h` THEN TRY (Cases_on `b`)
         THEN TRY (Cases_on `l`) THEN EVAL_TAC)
  \\ ASM_SIMP_TAC (srw_ss()) [num_bc_bc_num]
  \\ ASM_SIMP_TAC std_ss [APPEND,GSYM APPEND_ASSOC]);

(*
val install_bc_lists_lemma = prove(
  ``install_bc_lists (bc_num_lists xs ys) bs =
    install_code (REVERSE ys) (install_code (REVERSE xs) bs)``,
  SIMP_TAC std_ss [bc_num_lists_def, GSYM APPEND_ASSOC,
    install_bc_lists_def,install_bc_lists_MAP_bc_num,APPEND,
    install_bc_lists_MAP_bc_num |> Q.INST [`xs`|->`[]`]
      |> SIMP_RULE std_ss [APPEND_NIL]]
  \\ SIMP_TAC (srw_ss()) [install_code_def]);
*)

(*
val install_bc_lists_thm = LIST_CONJ [
  install_bc_lists_lemma |> Q.INST [`xs`|->`[]`]
    |> SIMP_RULE std_ss [EVAL ``REVERSE []``],
  install_bc_lists_lemma |> Q.INST [`ys`|->`[]`]
    |> SIMP_RULE std_ss [EVAL ``REVERSE []``],
  install_bc_lists_lemma]
*)

(*
val main_loop_alt_eq = prove(
  ``!input ts b s1 s2 bs res.
      (bs.inst_length = real_inst_length) ==>
      temp
      (main_loop_alt' (strip_labels bs) input (SOME (ts,b,
         code_length real_inst_length bs.code,
         all_labels real_inst_length bs.code,s1,s2)) F)
      (case parse_elaborate_infertype_compile
            (MAP token_of_sym ts) (if b then s1 else s2) of
             Success (code,s',s_exc) =>
               (let code_assert = code_labels_ok bs.code in
                let s1 = install_code (cpam s'.rcompiler_state) code bs in
                let code_assert = (code_assert /\ code_executes_ok s1) in
                case bc_eval s1 of
                  NONE => (Diverge, code_assert)
                | SOME new_bs =>
                    let s = if bc_fetch new_bs = SOME Stop then s_exc else s' in
                    let (res,assert) = main_loop' (new_bs, s) input in
                      (Result (new_bs.output) res, assert /\ code_assert))
           | Failure error_msg =>
               let (res,assert) = main_loop' (bs,if b then s1 else s2) input in
                 (Result error_msg res, assert))``,
  STRIP_TAC \\ completeInduct_on `LENGTH input` \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [PULL_FORALL]
  \\ POP_ASSUM MP_TAC \\ POP_ASSUM (K ALL_TAC) \\ STRIP_TAC
  \\ SIMP_TAC std_ss [Once main_loop_alt'_def,repl_step_def]
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF]
  \\ REVERSE (Cases_on `parse_elaborate_infertype_compile
       (MAP token_of_sym ts) (if b then s1 else s2)`)
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF] THEN1
   (SIMP_TAC std_ss [Once main_loop'_def]
    \\ SIMP_TAC std_ss [lex_lemma]
    \\ Cases_on `lex_until_top_semicolon_alt input` \\ FULL_SIMP_TAC std_ss []
    THEN1 (SIMP_TAC std_ss [temp_def])
    \\ Cases_on `x` \\ FULL_SIMP_TAC (srw_ss()) []
    \\ `STRLEN r < STRLEN input` by
          METIS_TAC [lexer_implTheory.lex_until_top_semicolon_alt_LESS]
    \\ Q.PAT_ASSUM `!xx.bbb` (MP_TAC o Q.SPEC `r`)
    \\ FULL_SIMP_TAC std_ss [] \\ REPEAT STRIP_TAC
    \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF]
    \\ POP_ASSUM (MP_TAC o Q.SPECL [`q`,`F`,`if b then s1 else s2`,
         `if b then s1 else s2`,`bs`])
    \\ FULL_SIMP_TAC std_ss [temp_simp])
  \\ `?code s' s_exc. a = (code,s',s_exc)` by METIS_TAC [pairTheory.PAIR]
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF]
  \\ SIMP_TAC std_ss [temp_def] \\ STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [install_code_NIL,install_bc_lists_thm]
  \\ `(install_code (cpam s'.rcompiler_state)
        (REVERSE (inst_labels
           (FUNION (all_labels real_inst_length bs.code)
              (collect_labels (REVERSE code) (code_length real_inst_length bs.code)
                 real_inst_length)) (REVERSE code))) (strip_labels bs)) =
      strip_labels (install_code (cpam s'.rcompiler_state) code bs)` by ALL_TAC
  THEN1
   (POP_ASSUM MP_TAC
    \\ CONV_TAC (DEPTH_CONV PairRules.PBETA_CONV) \\ SIMP_TAC std_ss []
    \\ REPEAT STRIP_TAC \\ FULL_SIMP_TAC std_ss []
    \\ `code_labels_ok bs.code` by ALL_TAC THEN1
     (Cases_on `bc_eval (install_code (cpam s'.rcompiler_state) code bs)`
      \\ FULL_SIMP_TAC std_ss []) \\ POP_ASSUM MP_TAC
    \\ POP_ASSUM (K ALL_TAC) \\ STRIP_TAC
    \\ SIMP_TAC (srw_ss()) [strip_labels_def,install_code_def]
    \\ FULL_SIMP_TAC std_ss []
    \\ IMP_RES_TAC (REWRITE_RULE [GSYM code_labels_ok_def] code_labels_APPEND)
    \\ FULL_SIMP_TAC std_ss []
    \\ FULL_SIMP_TAC std_ss [GSYM code_labels_def,next_addr_thm]
    \\ ASM_SIMP_TAC std_ss [code_labels_def,code_length_inst_labels,
         length_ok_inst_length])
  \\ FULL_SIMP_TAC std_ss []
  \\ Q.PAT_ASSUM `SND xx` MP_TAC \\ ASM_SIMP_TAC std_ss [GSYM temp_def]
  \\ Q.ABBREV_TAC `bs1 = install_code (cpam s'.rcompiler_state) code bs`
  \\ ASSUME_TAC length_ok_inst_length
  \\ `bs1.inst_length = real_inst_length` by ALL_TAC THEN1
    (UNABBREV_ALL_TAC \\ ASM_SIMP_TAC (srw_ss()) [install_code_def])
  \\ Cases_on `bc_eval bs1`
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF,temp_REFL] THEN1
   (ONCE_REWRITE_TAC [temp_assum] \\ FULL_SIMP_TAC std_ss [] \\ REPEAT STRIP_TAC
    \\ `bc_eval (strip_labels bs1) = NONE` by METIS_TAC [bc_eval_NONE_strip_labels]
    \\ FULL_SIMP_TAC std_ss [] \\ FULL_SIMP_TAC std_ss [temp_def]
    \\ REPEAT STRIP_TAC
    \\ MATCH_MP_TAC code_executes_ok_strip_labels
    \\ FULL_SIMP_TAC std_ss [])
  \\ ONCE_REWRITE_TAC [temp_assum]
  \\ CONV_TAC (RATOR_CONV (DEPTH_CONV PairRules.PBETA_CONV))
  \\ FULL_SIMP_TAC std_ss [] \\ STRIP_TAC
  \\ Q.PAT_ASSUM `SND xxx` (K ALL_TAC)
  \\ `bc_eval (strip_labels bs1) =
      SOME (strip_labels x)` by METIS_TAC [bc_eval_SOME_strip_labels]
  \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [main_loop'_def]
  \\ SIMP_TAC std_ss [lex_lemma]
  \\ Cases_on `lex_until_top_semicolon_alt input`
  \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF,temp_REFL]
  THEN1
   (SIMP_TAC std_ss [temp_def] \\ REPEAT STRIP_TAC
    THEN1 (FULL_SIMP_TAC (srw_ss()) [strip_labels_def])
    \\ MATCH_MP_TAC code_executes_ok_strip_labels \\ ASM_SIMP_TAC std_ss [])
  \\ Cases_on `x'` \\ FULL_SIMP_TAC (srw_ss()) [LET_DEF]
  \\ `STRLEN r < STRLEN input` by
        METIS_TAC [lexer_implTheory.lex_until_top_semicolon_alt_LESS]
  \\ Q.PAT_ASSUM `!xx.bbb` (MP_TAC o Q.SPEC `r`)
  \\ FULL_SIMP_TAC std_ss []
  \\ REPEAT STRIP_TAC
  \\ `bs.code ++ REVERSE code = x.code` by ALL_TAC THEN1
    (Q.UNABBREV_TAC `bs1`
     \\ IMP_RES_TAC bc_eval_SOME_code
     \\ FULL_SIMP_TAC (srw_ss()) [install_code_def])
  \\ `code_length real_inst_length bs.code + code_length real_inst_length (REVERSE code) =
      code_length real_inst_length x.code` by ALL_TAC THEN1
   (POP_ASSUM (MP_TAC o GSYM)
    \\ FULL_SIMP_TAC std_ss [code_length_def,MAP_APPEND,SUM_APPEND])
  \\ FULL_SIMP_TAC std_ss []
  \\ `code_executes_ok (strip_labels bs1)` by
         METIS_TAC [code_executes_ok_strip_labels]
  \\ FULL_SIMP_TAC std_ss []
  \\ `(strip_labels x).output = x.output` by ALL_TAC THEN1
        FULL_SIMP_TAC (srw_ss()) [strip_labels_def]
  \\ FULL_SIMP_TAC std_ss []
  \\ SIMP_TAC std_ss [temp_simp]
  \\ `FUNION (all_labels real_inst_length bs.code)
           (collect_labels (REVERSE code) (code_length real_inst_length bs.code)
              real_inst_length) = all_labels real_inst_length x.code` by ALL_TAC THEN1
   (FULL_SIMP_TAC std_ss [all_labels_def]
    \\ Q.PAT_ASSUM `bs.code ++ code = x.code` (MP_TAC o GSYM)
    \\ FULL_SIMP_TAC std_ss [collect_labels_APPEND])
  \\ `x.inst_length = real_inst_length` by ALL_TAC THEN1
   (IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
    \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
    \\ FULL_SIMP_TAC std_ss [])
  \\ `(bc_fetch x = SOME Stop) = (bc_fetch (strip_labels x) = SOME Stop)` by ALL_TAC
  THEN1 (FULL_SIMP_TAC std_ss [bc_fetch_strip_labels])
  \\ FULL_SIMP_TAC std_ss []);

val PAIR_I = prove(
  ``(\(r,a). (r,a)) = I``,
  SIMP_TAC std_ss [FUN_EQ_THM,pairTheory.FORALL_PROD]);

val temp_INTRO = prove(
  ``!f1 f2. temp f1 f2 ==> !res. ((res,T) = f2) ==> (f1 = f2)``,
  Cases \\ Cases \\ FULL_SIMP_TAC std_ss [temp_def]);

val code_length_intro = prove(
  ``!c1. SUM (MAP (SUC o real_inst_length) (FILTER ($~ o is_Label) c1)) =
         code_length real_inst_length c1``,
  Induct \\ FULL_SIMP_TAC (srw_ss()) [code_length_def,ilength_def,MAP,SUM]
  \\ REPEAT STRIP_TAC \\ SRW_TAC [] [] \\ FULL_SIMP_TAC std_ss [] \\ EVAL_TAC
  \\ SIMP_TAC std_ss [ADD1]);

val IS_SOME_IFF_EXISTS = prove(
  ``!x. IS_SOME x <=> ?y. x = SOME y``,
  Cases \\ SRW_TAC [] []);

val repl_fun_alt_correct = store_thm("repl_fun_alt_correct",
  ``!input res b.
       (repl_fun' input = (res,T)) ==>
       (repl_fun_alt' input = (res,T))``,
  SIMP_TAC std_ss [repl_fun_alt'_def,FUN_EQ_THM,repl_fun'_def,LET_DEF]
  \\ SIMP_TAC (srw_ss()) [Once main_loop_alt'_def,Once repl_step_def,LET_DEF]
  \\ REPEAT GEN_TAC
  \\ Cases_on `main_loop' (initial_bc_state,initial_repl_fun_state) input`
  \\ FULL_SIMP_TAC std_ss [] \\ STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [initial_bc_state_side_def,initial_bc_state_def,LET_DEF]
  \\ FULL_SIMP_TAC std_ss [GSYM empty_bc_state_def,LET_DEF]
  \\ Q.ABBREV_TAC `emp_bc_state =
       (install_code []
          (REVERSE
             (inst_labels
                (collect_labels (PrintE ++ [Stop]) 0 real_inst_length)
                (PrintE ++ [Stop]))) empty_bc_state)`
  \\ Q.ABBREV_TAC `bs1 = (install_code [] (SND (SND compile_primitives))
           <|stack := []; code := PrintE ++ [Stop]; pc := 0;
                   refs := FEMPTY; handler := 0; clock := NONE;
                   output := ""; cons_names := [];
                   inst_length := real_inst_length |>)`
  \\ FULL_SIMP_TAC std_ss [collect_labels_APPEND |> Q.SPECL [`c1`,`c2`,`0`]
        |> REWRITE_RULE [ADD_CLAUSES] |> GSYM,GSYM all_labels_def]
  \\ `(install_code []
        (REVERSE
           (inst_labels
              (all_labels real_inst_length
                 (PrintE ++ [Stop] ++
                  REVERSE (SND (SND compile_primitives))))
              (REVERSE (SND (SND compile_primitives)))))
        emp_bc_state) = strip_labels bs1` by ALL_TAC THEN1
   (SIMP_TAC std_ss [GSYM all_labels_def]
    \\ UNABBREV_ALL_TAC
    \\ Q.ABBREV_TAC `l = real_inst_length`
    \\ Q.ABBREV_TAC `c1 = PrintE ++ [Stop]`
    \\ Q.ABBREV_TAC `c2 = REVERSE (SND (SND compile_primitives))`
    \\ SIMP_TAC (srw_ss()) [install_code_def,strip_labels_def,empty_bc_state_def]
    \\ SIMP_TAC std_ss [code_labels_def,inst_labels_def,GSYM all_labels_def]
    \\ Q.UNABBREV_TAC `c2` \\ REPEAT STRIP_TAC THEN1
     (FULL_SIMP_TAC std_ss [GSYM code_labels_def] \\ Q.UNABBREV_TAC `l`
      \\ FULL_SIMP_TAC std_ss [all_labels_def,collect_labels_APPEND]
      \\ FULL_SIMP_TAC std_ss [GSYM all_labels_def]
      \\ Q.ABBREV_TAC `c2 = REVERSE (SND (SND compile_primitives))`
      \\ ONCE_REWRITE_TAC [EQ_SYM_EQ]
      \\ MATCH_MP_TAC (REWRITE_RULE [GSYM code_labels_def] code_labels_APPEND)
      \\ UNABBREV_ALL_TAC
      \\ SIMP_TAC (srw_ss()) [uses_label_def,PrintE_def,MAP]
      \\ FULL_SIMP_TAC std_ss [AC DISJ_COMM DISJ_ASSOC])
    \\ UNABBREV_ALL_TAC
    \\ FULL_SIMP_TAC std_ss [code_length_intro]
    \\ MATCH_MP_TAC code_length_inst_labels
    \\ FULL_SIMP_TAC std_ss [length_ok_inst_length])
  \\ FULL_SIMP_TAC std_ss []
  \\ `emp_bc_state.inst_length = (THE (bc_eval bs1)).inst_length` by ALL_TAC
  THEN1
   (UNABBREV_ALL_TAC \\ SIMP_TAC (srw_ss()) [install_code_def]
    \\ Q.PAT_ASSUM `IS_SOME pat` MP_TAC
    \\ SIMP_TAC std_ss [IS_SOME_IFF_EXISTS] \\ STRIP_TAC
    \\ IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
    \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
    \\ FULL_SIMP_TAC (srw_ss()) [empty_bc_state_def,install_code_def])
  \\ `bs1.inst_length = real_inst_length` by ALL_TAC THEN1
   (UNABBREV_ALL_TAC \\ SIMP_TAC (srw_ss()) [install_code_def,
      empty_bc_state_def,FUN_EQ_THM])
  \\ `code_executes_ok bs1` by ALL_TAC THEN1
   (Q.PAT_ASSUM `IS_SOME pat` MP_TAC
    \\ SIMP_TAC std_ss [IS_SOME_IFF_EXISTS] \\ STRIP_TAC
    \\ IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
    \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
    \\ FULL_SIMP_TAC (srw_ss()) [code_executes_ok_def,LET_DEF]
    \\ DISJ1_TAC \\ Q.EXISTS_TAC `(THE (bc_eval bs1))`
    \\ FULL_SIMP_TAC std_ss [] \\ DISJ2_TAC
    \\ REPEAT (POP_ASSUM (K ALL_TAC))
    \\ Q.SPEC_TAC (`bs1.code`,`xs`) \\ Induct
    \\ FULL_SIMP_TAC (srw_ss()) [] \\ SRW_TAC [] []
    \\ FULL_SIMP_TAC std_ss [ADD1])
  \\ ASSUME_TAC length_ok_inst_length
  \\ `code_executes_ok (strip_labels bs1)` by ALL_TAC THEN1
   (MATCH_MP_TAC code_executes_ok_strip_labels
    \\ FULL_SIMP_TAC std_ss [])
  \\ Cases_on `(bc_eval bs1)` THEN1 FULL_SIMP_TAC (srw_ss()) []
  \\ `bc_eval (strip_labels bs1) = SOME (strip_labels x)` by ALL_TAC
  THEN1 (MATCH_MP_TAC bc_eval_SOME_strip_labels
         \\ FULL_SIMP_TAC std_ss [length_ok_inst_length])
  \\ FULL_SIMP_TAC std_ss []
  \\ `(strip_labels x).output = x.output` by ALL_TAC
  THEN1 (FULL_SIMP_TAC (srw_ss()) [strip_labels_def])
  \\ FULL_SIMP_TAC std_ss []
  \\ ONCE_REWRITE_TAC [EQ_SYM_EQ]
  \\ Q.PAT_ASSUM `main_loop' (bs,initial_repl_fun_state) input = (res,T)` MP_TAC
  \\ ONCE_REWRITE_TAC [EQ_SYM_EQ]
  \\ SIMP_TAC std_ss [Once main_loop'_def]
  \\ `x.inst_length = real_inst_length` by ALL_TAC THEN1
   (UNABBREV_ALL_TAC \\ ASM_SIMP_TAC (srw_ss()) []
    \\ IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
    \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
    \\ FULL_SIMP_TAC std_ss [])
  \\ Q.ABBREV_TAC `ii = (code_length real_inst_length ((PrintE ++ [Stop])))`
  \\ `PrintE ++ [Stop] ++ (REVERSE (SND (SND compile_primitives))) =
      x.code` by ALL_TAC THEN1
     (UNABBREV_ALL_TAC
      \\ IMP_RES_TAC bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next
      \\ IMP_RES_TAC bytecodeExtraTheory.RTC_bc_next_preserves
      \\ FULL_SIMP_TAC (srw_ss()) [install_code_def,empty_bc_state_def])
  \\ `(ii + code_length real_inst_length (REVERSE (SND (SND compile_primitives))) =
       code_length real_inst_length x.code)` by ALL_TAC THEN1
   (POP_ASSUM (ASSUME_TAC o GSYM) \\ UNABBREV_ALL_TAC
    \\ FULL_SIMP_TAC std_ss [code_length_def,MAP_APPEND,SUM_APPEND])
  \\ FULL_SIMP_TAC std_ss [lex_lemma,install_bc_lists_thm]
  \\ Cases_on `lex_until_top_semicolon_alt input` \\ FULL_SIMP_TAC std_ss []
  \\ Q.MATCH_ASSUM_RENAME_TAC
       `lex_until_top_semicolon_alt input = SOME ts_rest` []
  \\ Cases_on `ts_rest` \\ FULL_SIMP_TAC std_ss []
  \\ FULL_SIMP_TAC (srw_ss()) []
  \\ FULL_SIMP_TAC std_ss [PAIR_I]
  \\ Q.SPEC_TAC (`res`,`res`)
  \\ HO_MATCH_MP_TAC temp_INTRO
  \\ FULL_SIMP_TAC std_ss []
  \\ `(bc_fetch (strip_labels x) = SOME Stop) =
      (bc_fetch x = SOME Stop)` by ALL_TAC
  THEN1 (FULL_SIMP_TAC std_ss [bc_fetch_strip_labels])
  \\ MP_TAC (Q.SPECL [`r'`,`q'`,`bc_fetch x = SOME Stop`,
        `initial_repl_fun_state`,`initial_repl_fun_state`,`x`] main_loop_alt_eq)
  \\ FULL_SIMP_TAC std_ss []);

val _ = delete_const "temp";
*)

val _ = export_theory();
