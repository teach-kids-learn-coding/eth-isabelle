(*
   Copyright 2017 Myriam Begel

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

theory "HoareCFG"

imports "HoareTripleForInstructions"
"../attic/CFG"
"../EvmFacts"

begin
type_synonym pred = "(state_element set \<Rightarrow> bool)"

(* We define here the program logic for CFGs *)
(* We start with Hoare triples valid for the execution of one instruction *)

(* We have add more instructions here *)
inductive triple_inst :: "pred \<Rightarrow> pos_inst \<Rightarrow> pred \<Rightarrow> bool" where
  inst_push_n :
    "triple_inst
      (\<langle> h \<le> 1023 \<and> length lst > 0 \<and> 32 \<ge> length lst \<and> Gverylow \<le> g \<and> m \<ge> 0\<rangle> \<and>*
       continuing \<and>* program_counter n \<and>*
       memory_usage m \<and>* stack_height h \<and>*
       gas_pred g \<and>* rest)
      (n, Stack (PUSH_N lst))
      (continuing \<and>* memory_usage m \<and>*
       program_counter (n + 1 + int (length lst)) \<and>*
       stack_height (Suc h) \<and>* gas_pred (g - Gverylow) \<and>*
       stack h (word_rcat lst) \<and>* rest)"
| inst_stop :
    "triple_inst
      (\<langle> h \<le> 1024 \<and> 0 \<le> g \<and> m \<ge> 0\<rangle> \<and>* continuing \<and>* memory_usage m \<and>*
       program_counter n \<and>* stack_height h \<and>* gas_pred g \<and>* rest)
      (n, Misc STOP)
      (stack_height h \<and>* not_continuing \<and>* memory_usage m \<and>*
       program_counter n \<and>* action (ContractReturn []) \<and>*
       gas_pred g \<and>* rest)"
| inst_jumpdest :
    "triple_inst
      (\<langle> h \<le> 1024 \<and> Gjumpdest \<le> g \<and> m \<ge> 0\<rangle> \<and>*
       continuing \<and>* memory_usage m \<and>* program_counter n \<and>*
       stack_height h \<and>* gas_pred g \<and>* rest)
      (n, Pc JUMPDEST)
      (continuing \<and>* program_counter (n + 1) \<and>*
       memory_usage m \<and>* stack_height h \<and>*
       gas_pred (g - Gjumpdest) \<and>* rest)"
| inst_strengthen_pre:
    "triple_inst p i q \<Longrightarrow> (\<And>s. r s \<longrightarrow> p s) \<Longrightarrow> triple_inst r i q"
| inst_false_pre:
    "triple_inst \<langle>False\<rangle> i post"

inductive triple_seq :: "pred \<Rightarrow> pos_inst list \<Rightarrow> pred \<Rightarrow> bool" where
  seq_inst :
  "\<lbrakk>triple_inst pre x q;
    triple_seq q xs post \<rbrakk> \<Longrightarrow>
   triple_seq pre (x#xs) post"
| seq_empty:
  "(\<And>s. pre s \<longrightarrow> post s) \<Longrightarrow>
   triple_seq pre [] post"
| seq_strengthen_pre:
  "triple_seq p xs q \<Longrightarrow>
   (\<And>s. r s \<longrightarrow> p s) \<Longrightarrow>
   triple_seq r xs q"
| seq_false_pre:
  "triple_seq \<langle>False\<rangle> xs post"

inductive triple_cfg :: "cfg \<Rightarrow> pred \<Rightarrow> vertex \<Rightarrow> pred \<Rightarrow> bool" where
  cfg_no :
  "triple_seq pre insts post \<Longrightarrow>
   triple_cfg cfg pre (n, insts, No) post"
| cfg_next :
  "\<lbrakk>i = n + inst_size_list insts;
    cfg_blocks cfg i = Some (bi, ti);
    triple_seq pre insts (program_counter i \<and>* q);
    triple_cfg cfg (program_counter i \<and>* q) (i, bi, ti) post\<rbrakk> \<Longrightarrow>
   triple_cfg cfg pre (n, insts, Next) post"
| cfg_jump :
  "\<lbrakk>cfg_blocks cfg dest = Some (bi, ti);
    bi = (dest, Pc JUMPDEST) # bbi;
    triple_seq pre insts
      (program_counter (n + inst_size_list insts) \<and>* gas_pred g \<and>*
       memory_usage m \<and>* stack_height (Suc h) \<and>*
       stack h (word_of_int dest::256 word) \<and>*
       \<langle> h \<le> 1023 \<and> Gmid \<le> g \<and> m \<ge> 0\<rangle> \<and>*
       continuing \<and>* rest);
    triple_cfg cfg
      (program_counter dest \<and>* gas_pred (g - Gmid) \<and>*
       memory_usage m \<and>* stack_height h \<and>*
       continuing \<and>* rest)
      (dest, bi, ti) post\<rbrakk> \<Longrightarrow>
   triple_cfg cfg pre (n, insts, Jump) post"
| cfg_jumpi :
  "\<lbrakk>j = n + 1 + inst_size_list insts;
    cfg_blocks cfg dest = Some (bi, ti);
    bi = (dest, Pc JUMPDEST) # bbi;
    cfg_blocks cfg j = Some (bj, tj);
    triple_seq pre insts
      ((\<langle> h \<le> 1022  \<and> Ghigh \<le> g \<and> m \<ge> 0\<rangle> \<and>*
       stack_height (Suc (Suc h)) \<and>*
       stack (Suc h) (word_of_int dest::256 word) \<and>*
       stack h cond \<and>* gas_pred g \<and>*
       continuing \<and>* memory_usage m \<and>*
       program_counter (n + inst_size_list insts) \<and>* rest));
    r = (stack_height h \<and>* gas_pred (g - Ghigh) \<and>*
         continuing \<and>* memory_usage m \<and>* rest);
    (cond \<noteq> 0 \<Longrightarrow> triple_cfg cfg (r \<and>* program_counter dest) (dest, bi, ti) post);
    (cond = 0 \<Longrightarrow> triple_cfg cfg (r \<and>* program_counter j) (j, bj, tj) post)\<rbrakk> \<Longrightarrow>
   triple_cfg cfg pre (n, insts, Jumpi) post"
| cfg_false_pre:
  "triple_cfg cfg \<langle>False\<rangle> i post"

(* Group lemmas *)
lemmas as_set_simps =
balance_as_set_def contract_action_as_set_def annotation_failure_as_set
contexts_as_set_def constant_ctx_as_set_def memory_as_set_def storage_as_set_def
data_sent_as_set_def log_as_set_def stack_as_set_def instruction_result_as_set_def
program_as_set_def variable_ctx_as_set_def constant_ctx_as_set_def ext_program_as_set_def

lemmas sep_tools_simps =
emp_sep sep_true pure_sepD pure_sep sep_lc sep_three imp_sepL sep_impL

lemmas sep_fun_simps =
caller_sep  sep_caller sep_caller_sep
balance_sep sep_balance sep_balance_sep
not_continuing_sep sep_not_continuing_sep
this_account_sep sep_this_account sep_this_account_sep
action_sep sep_action sep_action_sep
memory8_sepD memory8_sepI memory8_sep_h_cancelD sep_memory8 sep_memory8_sep memory8_sep
memory_usage_sep sep_memory_usage sep_memory_usage_sep
memory_range_sep sep_memory_range
continuing_sep sep_continuing_sep
gas_pred_sep sep_gas_pred
gas_any_sep sep_gas_any_sep sep_gas_pred_sep sep_gas_pred gas_pred_sep
program_counter_sep sep_program_counter sep_program_counter_sep
stack_height_sep sep_stack_height sep_stack_height_sep
stack_sep sep_stack sep_stack_sep
block_number_pred_sep sep_block_number_pred_sep
sep_log_number_sep sep_logged
storage_sep sep_storage
code_sep sep_code sep_sep_code sep_code_sep

lemmas inst_numbers_simps =
dup_inst_numbers_def storage_inst_numbers.simps stack_inst_numbers.simps
pc_inst_numbers.simps info_inst_numbers.simps inst_stack_numbers.simps
arith_inst_numbers.simps sarith_inst_nums.simps storage_inst_numbers.simps
bits_stack_nums.simps memory_inst_numbers.simps swap_inst_numbers_def
log_inst_numbers.simps  misc_inst_numbers.simps

lemmas inst_size_simps =
inst_size_def inst_code.simps bits_inst_code.simps sarith_inst_code.simps
arith_inst_code.simps info_inst_code.simps dup_inst_code_def
memory_inst_code.simps storage_inst_code.simps pc_inst_code.simps
stack_inst_code.simps swap_inst_code_def log_inst_code.simps misc_inst_code.simps

lemmas stack_simps=
stack_0_0_op_def stack_0_1_op_def stack_1_1_op_def
stack_2_1_op_def stack_3_1_op_def

lemmas gas_value_simps =
Gjumpdest_def Gzero_def Gbase_def Gcodedeposit_def Gcopy_def
Gmemory_def Gverylow_def Glow_def Gsha3word_def Gcall_def
Gtxcreate_def Gtxdatanonzero_def Gtxdatazero_def Gexp_def
Ghigh_def Glogdata_def Gmid_def Gblockhash_def Gsha3_def
Gsreset_def Glog_def Glogtopic_def  Gcallstipend_def Gcallvalue_def
Gcreate_def Gnewaccount_def Gtransaction_def Gexpbyte_def
Gsset_def Gsuicide_def Gbalance_def Gsload_def Gextcode_def

lemmas instruction_sem_simps =
instruction_sem_def constant_mark_def stack_simps
subtract_gas.simps vctx_advance_pc_def
check_resources_def vctx_next_instruction_def
meter_gas_def C_def Cmem_def M_def
new_memory_consumption.simps
thirdComponentOfC_def pop_def
vctx_next_instruction_default_def vctx_next_instruction_def
blockedInstructionContinue_def vctx_pop_stack_def
blocked_jump_def strict_if_def
general_dup_def

lemmas advance_simps=
vctx_advance_pc_def vctx_next_instruction_def

lemmas instruction_memory =
mload_def mstore_def mstore8_def calldatacopy_def
codecopy_def extcodecopy_def

lemmas instruction_simps =
instruction_failure_result_def sha3_def
instruction_sem_simps gas_value_simps
inst_size_simps inst_numbers_simps
instruction_memory

(* Define the semantic for triple_inst and prove it sound *)
definition triple_inst_sem :: "pred \<Rightarrow> pos_inst \<Rightarrow> pred \<Rightarrow> bool" where
"triple_inst_sem pre inst post ==
    \<forall>co_ctx presult rest stopper n.
			no_assertion co_ctx \<longrightarrow>
      (pre \<and>* code {inst} \<and>* rest) (instruction_result_as_set co_ctx presult) \<longrightarrow>
      ((post \<and>* code {inst} \<and>* rest) (instruction_result_as_set co_ctx
          (program_sem stopper co_ctx 1 n presult)))"

lemma inst_strengthen_pre_sem:
  assumes  "triple_inst_sem P c Q"
  and      "(\<forall> s. R s \<longrightarrow> P s)"
  shows    " triple_inst_sem R c Q"
  using assms(1)
  apply (simp add: triple_inst_sem_def)
  apply(clarify)
  apply(drule_tac x = co_ctx in spec)
  apply(simp)
  apply(drule_tac x = presult in spec)
  apply(drule_tac x = rest in spec)
  apply simp
  apply (erule impE)
   apply (sep_drule assms(2)[rule_format])
   apply assumption
  apply simp
done

lemma inst_false_pre_sem:
  "triple_inst_sem \<langle>False\<rangle> i q"
by(simp add: triple_inst_sem_def sep_basic_simps pure_def)

lemma inst_stop_sem:
"triple_inst_sem
  (\<langle> h \<le> 1024 \<and> 0 \<le> g \<and> m \<ge> 0\<rangle> \<and>* continuing \<and>* memory_usage m  \<and>* program_counter n \<and>* stack_height h \<and>* gas_pred g \<and>* rest)
  (n, Misc STOP)
  (stack_height h \<and>* not_continuing \<and>* memory_usage m \<and>* program_counter n \<and>* action (ContractReturn []) \<and>* gas_pred g \<and>* rest )"
 apply(simp add: triple_inst_sem_def program_sem.simps as_set_simps sep_conj_ac)
 apply(clarify)
 apply(simp split: instruction_result.splits)
 apply(simp add: vctx_next_instruction_def)
 apply(split option.splits)
 apply(simp add: sep_conj_commute[where P="rest"] sep_conj_assoc)
 apply(clarify)
 apply(rule conjI)
  apply(clarsimp split:option.splits)
 apply(subgoal_tac "(case program_content (cctx_program co_ctx) n of
               None \<Rightarrow> Some (Misc STOP) | Some i \<Rightarrow> Some i) =
              Some (Misc STOP)")
  apply(clarsimp)
  apply(rule conjI; rule impI; rule conjI; clarsimp;
  simp add: instruction_sem_simps stop_def gas_value_simps inst_numbers_simps)
  apply(simp add: sep_not_continuing_sep sep_action_sep del:sep_program_counter_sep)
  apply(sep_select 2; simp only:sep_fun_simps;simp)
 apply(simp split: option.splits)
 apply(rule allI; rule impI; simp)
done

lemma inst_push_sem:
"triple_inst_sem
  (\<langle> h \<le> 1023 \<and> length lst > 0 \<and> 32 \<ge> length lst \<and> Gverylow \<le> g \<and> m \<ge> 0\<rangle> \<and>*
   continuing \<and>* program_counter n \<and>*
   memory_usage m \<and>* stack_height h \<and>*
   gas_pred g \<and>* rest)
  (n, Stack (PUSH_N lst))
  (continuing \<and>* memory_usage m \<and>*
   program_counter (n + 1 + int (length lst)) \<and>*
   stack_height (Suc h) \<and>* gas_pred (g - Gverylow) \<and>*
   stack h (word_rcat lst) \<and>* rest)"
 apply(simp add: triple_inst_sem_def program_sem.simps as_set_simps sep_conj_ac)
 apply(clarify)
 apply(simp split: instruction_result.splits)
 apply(simp add: vctx_next_instruction_def)
 apply(simp add: sep_conj_commute[where P="rest"] sep_conj_assoc)
 apply(simp add: instruction_sem_simps inst_numbers_simps)
 apply(simp add: advance_simps inst_size_simps)
 apply(clarify)
 apply clarsimp
 apply(rename_tac rest0 vctx)
 apply (erule_tac P="(rest0 \<and>* rest)" in back_subst)
 apply(auto simp add: as_set_simps)
done

lemma inst_jumpdest_sem:
"triple_inst_sem
  (\<langle> h \<le> 1024 \<and> Gjumpdest \<le> g \<and> 0 \<le> m \<rangle> \<and>*
   continuing \<and>* memory_usage m \<and>*
   program_counter n \<and>* stack_height h \<and>* gas_pred g \<and>* rest)
  (n, Pc JUMPDEST)
  (continuing \<and>* program_counter (n + 1) \<and>*
   memory_usage m \<and>* stack_height h \<and>* gas_pred (g - Gjumpdest) \<and>* rest)"
 apply(simp add: triple_inst_sem_def program_sem.simps as_set_simps sep_conj_ac)
 apply(clarify)
 apply(simp split: instruction_result.splits)
 apply(simp add: vctx_next_instruction_def)
 apply(simp add: sep_conj_commute[where P="rest"] sep_conj_assoc)
 apply(simp add: instruction_sem_simps inst_numbers_simps)
 apply(simp add: advance_simps inst_size_simps)
 apply(clarify)
 apply(rename_tac rest0 vctx)
 apply (erule_tac P="(rest0 \<and>* rest)" in back_subst)
 apply(auto simp add: as_set_simps)
done

lemma triple_inst_soundness:
  "triple_inst p i q \<Longrightarrow> triple_inst_sem p i q"
  apply(induction rule:triple_inst.induct)
      apply(simp only: inst_push_sem)
     apply(simp only: inst_stop_sem)
    apply(simp only: inst_jumpdest_sem)
   apply(simp add: inst_strengthen_pre_sem)
  apply(simp add: inst_false_pre_sem)
done

(* Define the semantic of triple_seq and prove it sound *)

definition triple_seq_sem :: "pred \<Rightarrow> pos_inst list \<Rightarrow> pred \<Rightarrow> bool" where
"triple_seq_sem pre insts post ==
    \<forall>co_ctx presult rest stopper net.
			no_assertion co_ctx \<longrightarrow>
      (pre ** code (set insts) ** rest) (instruction_result_as_set co_ctx presult) \<longrightarrow>
      ((post ** code (set insts) ** rest) (instruction_result_as_set co_ctx (program_sem stopper co_ctx (length insts) net presult)))"

lemma inst_seq_eq:
"triple_inst P i Q \<Longrightarrow> triple_seq_sem P [i] Q"
 apply(drule triple_inst_soundness)
 apply(simp add: triple_inst_sem_def triple_seq_sem_def)
 apply(fastforce)
done

lemma seq_compose_soundness:
notes sep_fun_simps[simp del]
shows
"triple_seq_sem P xs R \<Longrightarrow> triple_seq_sem R ys Q \<Longrightarrow> triple_seq_sem P (xs@ys) Q "
 apply(simp (no_asm) add: triple_seq_sem_def)
 apply clarsimp
 apply(subst (asm) triple_seq_sem_def[where pre=P])
 apply clarsimp
 apply(rename_tac co_ctx presult rest stopper net)
 apply(drule_tac x = "co_ctx" in spec, simp)
 apply(drule_tac x = "presult" in spec)
 apply(drule_tac x = "code ((set ys) - (set xs)) ** rest" in spec)
 apply(simp add: code_more sep_conj_ac)
 apply(drule_tac x = stopper in spec)
 apply(drule_tac x = "net" in spec)
 apply(clarsimp simp add: triple_seq_sem_def)
 apply(drule_tac x = "co_ctx" in spec; simp)
 apply(drule_tac x = "program_sem stopper co_ctx (length xs) net presult" in spec)
 apply(drule_tac x = "code ((set xs) - (set ys)) ** rest" in spec)
 apply(simp add: code_more sep_conj_ac code_union_comm)
 apply(drule_tac x = stopper in spec)
 apply(drule_tac x = "net" in spec)
 apply(simp add: execution_continue)
done

lemma triple_seq_empty:
"(\<And>s. pre s \<longrightarrow> post s) \<Longrightarrow> triple_seq_sem pre [] post"
 apply (simp add: triple_seq_sem_def program_sem.simps imp_sepL)
 apply(clarify)
 apply(drule allI)
 apply(simp add: imp_sepL)
done

lemma seq_strengthen_pre_sem:
  assumes  "triple_seq_sem P c Q"
  and      "(\<forall> s. R s \<longrightarrow> P s)"
  shows    " triple_seq_sem R c Q"
  using assms(1)
  apply (simp add: triple_seq_sem_def)
  apply(clarify)
  apply(drule_tac x = co_ctx in spec)
  apply(simp)
  apply(drule_tac x = presult in spec)
  apply(drule_tac x = rest in spec)
  apply simp
  apply(erule impE)
   apply(sep_drule assms(2)[rule_format])
   apply assumption
  apply simp
done

lemma triple_seq_soundness:
"triple_seq P xs Q \<Longrightarrow> triple_seq_sem P xs Q"
 apply(induction rule: triple_seq.induct)
    apply(drule inst_seq_eq)
    apply(rename_tac pre x q xs post)
    apply(subgoal_tac "x#xs = [x]@xs")
     apply(simp only: seq_compose_soundness)
    apply(simp)
   apply(simp add: triple_seq_empty)
  apply(simp add: seq_strengthen_pre_sem)
 apply(simp add: triple_seq_sem_def)
done

(* Re-define program_sem_t and prove the new one equivalent to the original one *)
(* It makes some proofs easier *)

(*val program_sem_t_alt: constant_ctx -> network -> instruction_result -> instruction_result*)
function (sequential,domintros)  program_sem_t_alt  :: " constant_ctx \<Rightarrow> network \<Rightarrow> instruction_result \<Rightarrow> instruction_result "  where
"program_sem_t_alt c net  (InstructionToEnvironment x y z) = (InstructionToEnvironment x y z)"
|" program_sem_t_alt c net InstructionAnnotationFailure = InstructionAnnotationFailure"
|" program_sem_t_alt c net (InstructionContinue v) =
     (if \<not> (check_annotations v c) then InstructionAnnotationFailure else
     (case  vctx_next_instruction v c of
        None => InstructionToEnvironment (ContractFail [ShouldNotHappen]) v None
      | Some i =>
        if check_resources v c(vctx_stack   v) i net then
          (* This if is required to prove that vctx_gas is stictly decreasing on program_sem's recursion *)
          (if(vctx_gas   v) \<le>( 0 :: int) then
              instruction_sem v c i net
          else  program_sem_t_alt c net (instruction_sem v c i net))
        else
          InstructionToEnvironment (ContractFail
              ((case  inst_stack_numbers i of
                 (consumed, produced) =>
                 (if (((int (List.length(vctx_stack   v)) + produced) - consumed) \<le>( 1024 :: int)) then [] else [TooLongStack])
                  @ (if meter_gas i v c net \<le>(vctx_gas   v) then [] else [OutOfGas])
               )
              ))
              v None
     ))"
by pat_completeness auto

termination program_sem_t_alt
  apply (relation "measure (\<lambda>(c,net,ir). nat (case ir of InstructionContinue v \<Rightarrow>  vctx_gas v | _ \<Rightarrow> 0))")
   apply (simp)
  apply clarsimp
  subgoal for const net var inst
    apply (case_tac "instruction_sem var const inst net" ; simp)
    apply (clarsimp simp add: check_resources_def prod.case_eq_if )
     apply (frule instruction_sem_continuing)
     apply (erule (3) inst_sem_gas_consume)
  apply (simp add: vctx_next_instruction_def split:option.splits)
    done
done
declare program_sem_t_alt.simps[simp del]

lemma program_sem_t_alt_eq_continue:
"program_sem_t cctx net (InstructionContinue x) = program_sem_t_alt cctx net (InstructionContinue x)"
thm program_sem_t.induct[where P="\<lambda>x y z. program_sem_t x y z = program_sem_t_alt x y z"]
 apply(induction
 rule: program_sem_t.induct[where P="\<lambda>x y z. program_sem_t x y z = program_sem_t_alt x y z"] )
 apply(case_tac p; clarsimp)
   apply(simp (no_asm) add:program_sem_t_alt.simps program_sem_t.simps)
   apply(simp split:option.splits)
  apply(simp add:program_sem_t_alt.simps program_sem_t.simps)+
done

lemma program_sem_t_alt_eq:
"program_sem_t_alt cctx net pr = program_sem_t cctx net pr"
 apply(case_tac pr)
   apply(simp add: program_sem_t_alt_eq_continue)
  apply(simp add: program_sem_t.simps program_sem_t_alt.simps)+
done

(* program_sem_t_alt never returns InstructionContinue  *)

lemma program_sem_no_gas_not_continuing_1:
  "\<lbrakk>vctx_gas var \<le> 0 ; 0\<le> vctx_memory_usage var \<rbrakk> \<Longrightarrow>
\<forall>v. program_sem_t_alt const net (InstructionContinue var) \<noteq> InstructionContinue v"
 by(simp add: program_sem_t_alt_eq program_sem_no_gas_not_continuing)

(* How to compose program_sem and program_sem_t_alt *)

lemma program_sem_t_alt_exec_continue_1:
" program_sem_t_alt co_ctx net
   (program_sem stopper co_ctx (Suc 0) net presult) =
  program_sem_t_alt co_ctx net presult"
 apply(case_tac presult)
   apply(simp add: program_sem.simps program_sem_t_alt.simps)
   apply(insert program_sem_no_gas_not_continuing_1)[1]
   apply(drule_tac x=x1 and y=co_ctx in meta_spec2)
   apply(drule_tac x=net in meta_spec)
   apply(simp split: option.splits)
   apply (rule conjI)
    apply (simp add: program_sem_t_alt.simps)
   apply clarsimp
   apply (simp add: program_sem_t_alt.simps)
   apply(clarsimp)
   apply(simp add: check_resources_def)
   apply(case_tac "inst_stack_numbers x2"; clarsimp)
   apply(case_tac "instruction_sem x1 co_ctx x2 net")
     apply(drule_tac x=x1a in spec; simp)
    apply (simp add: program_sem_t_alt.simps)+
  apply (simp add: program_sem_t_alt.simps program_sem.simps)+
done

lemma program_sem_t_alt_exec_continue:
notes sep_fun_simps[simp del]
shows
"program_sem_t_alt co_ctx net (program_sem stopper co_ctx k net presult) =
       program_sem_t_alt co_ctx net presult"
 apply(induction k arbitrary: presult)
  apply(simp add: program_sem.simps)
 apply(drule_tac x="program_sem stopper co_ctx 1 net presult" in meta_spec)
 apply(simp add:program_sem_t_alt_exec_continue_1)
done

(* Define the semantic of triple_cfg using program_sem_t and prove it sound *)

definition triple_cfg_sem_t :: "cfg \<Rightarrow> pred \<Rightarrow> vertex \<Rightarrow> pred \<Rightarrow> bool" where
"triple_cfg_sem_t c pre v post ==
    \<forall> co_ctx presult rest net (stopper::instruction_result \<Rightarrow> unit).
				no_assertion co_ctx \<longrightarrow>
        (cctx_program co_ctx = program_from_cfg c) \<longrightarrow>
        wf_cfg c \<longrightarrow>
        cfg_blocks c (v_ind v) = Some (snd v) \<longrightarrow>
       (pre ** code (cfg_insts c) ** rest) (instruction_result_as_set co_ctx presult) \<longrightarrow>
       ((post ** code (cfg_insts c) ** rest) (instruction_result_as_set co_ctx
            (program_sem_t_alt co_ctx net presult)))"

(* Lemmas to group code elements *)
lemma block_in_insts_:
"n \<in> set xs \<Longrightarrow>
cfg_blocks c n = Some (b, t) \<Longrightarrow>
set b \<subseteq> set (cfg_insts_aux c xs)"
apply(induction xs)
 apply(simp)
apply(case_tac "n \<in> set xs")
 apply(case_tac "cfg_blocks c a = None")
	apply(auto)
done

lemma block_in_insts:
"wf_cfg c \<Longrightarrow>
cfg_blocks c n = Some (b, t) \<Longrightarrow>
set b \<subseteq> cfg_insts c"
apply(simp add: wf_cfg_def cfg_insts_def)
apply(drule_tac x = n in spec)+
apply(drule_tac x=b in spec)
apply(erule conjE)
apply(drule_tac x = t in spec)
apply(erule conjE, simp add: block_in_insts_)+
done

lemma decomp_set:
"P \<subseteq> Q =
(Q = (Q - P) \<union> P)"
by auto

lemma code_decomp:
" P \<subseteq> Q \<Longrightarrow>
{CodeElm (pos, i) |pos i.
         (pos, i) \<in> Q} =
({CodeElm (pos, i) |pos i.
         (pos, i) \<in> Q \<and> (pos, i) \<notin> P} \<union>
        {CodeElm (pos, i) |pos i.
         (pos, i) \<in> P})
"
by auto

lemma subset_minus:
"P \<inter> Q = {} \<Longrightarrow> P \<subseteq> R - Q \<Longrightarrow> P \<subseteq> R"
by auto

lemma code_code_sep_:
"P \<subseteq> Q \<Longrightarrow>
(code P \<and>* code (Q - P) \<and>* r) s =
(code Q \<and>* r) s"
 apply(simp)
 apply(rule iffI; rule conjI; (erule conjE)+)
		apply(simp add: code_decomp)
		apply(subgoal_tac "{CodeElm (pos, i) |pos i. (pos, i) \<in> P} \<inter> {CodeElm (pos, i) |pos i.
         (pos, i) \<in> Q \<and> (pos, i) \<notin> P} = {}")
		 apply(auto simp add: subset_minus)[1]
		apply(auto)[1]
	 apply(auto simp add: subset_minus diff_diff_union code_decomp)[1]
	apply(subgoal_tac "{CodeElm (pos, i) |pos i.
     (pos, i) \<in> Q \<and> (pos, i) \<notin> P} \<subseteq> {CodeElm (pos, i) |pos i.
     (pos, i) \<in> Q}")
	 apply(simp)
	apply(auto)[1]
 apply(rule conjI)
	apply(auto)[1]
 apply(auto simp add: subset_minus diff_diff_union code_decomp)
done

lemma code_code_sep:
"wf_cfg cfg \<Longrightarrow>
cfg_blocks cfg n = Some (insts, ty) \<Longrightarrow>
(code (set insts) \<and>* code (cfg_insts cfg - set insts) \<and>* r) s =
(code (cfg_insts cfg) \<and>* r) s"
 apply(subgoal_tac "set insts \<subseteq> cfg_insts cfg")
	apply(simp only: code_code_sep_)
 apply(simp add: block_in_insts)
done

lemma sep_code_code_sep:
"wf_cfg cfg \<Longrightarrow>
cfg_blocks cfg n = Some (insts, ty) \<Longrightarrow>
(p \<and>* code (set insts) \<and>* code (cfg_insts cfg - set insts) \<and>* r) s =
(p \<and>* code (cfg_insts cfg) \<and>* r) s"
 apply(rule iffI)
  apply(sep_select_asm 3)
	apply(sep_select_asm 3)
  apply(sep_select 2)
	apply(simp only: code_code_sep)
 apply(sep_select 3)
 apply(sep_select 3)
 apply(sep_select_asm 2)
 apply(simp only: code_code_sep)
done

lemma sep_sep_sep_code_code:
"wf_cfg cfg \<Longrightarrow>
cfg_blocks cfg n = Some (insts, ty) \<Longrightarrow>
(p \<and>* q \<and>* r \<and>* code (set insts) \<and>* code (cfg_insts cfg - set insts)) s =
(p \<and>* q \<and>* r \<and>* code (cfg_insts cfg)) s"
 apply(rule iffI)
  apply(sep_select_asm 5)
	apply(sep_select_asm 5)
  apply(sep_select 4)
	apply(simp only: code_code_sep)
 apply(sep_select 5)
 apply(sep_select 5)
 apply(sep_select_asm 4)
 apply(simp only: code_code_sep)
done

(*NEXT case *)

lemma cfg_next_sem_t:
notes sep_fun_simps[simp del]
shows
"\<And>cfg n i ii bi ti pre insts q post.
       i = n + inst_size_list insts \<Longrightarrow>
       cfg_blocks cfg i = Some (bi, ti) \<Longrightarrow>
       triple_seq pre insts (program_counter i \<and>* q) \<Longrightarrow>
       triple_cfg_sem_t cfg (program_counter i \<and>* q) (i, bi, ti) post \<Longrightarrow>
       triple_cfg_sem_t cfg pre (n, insts, Next) post"
 apply(drule triple_seq_soundness)
 apply(simp only: triple_seq_sem_def triple_cfg_sem_t_def)
 apply(rule allI)+
 apply(clarify)
 apply(rename_tac co_ctx presult rest net stopper)
 apply(drule_tac x = "co_ctx" in spec)+
 apply(drule_tac x = "(program_sem stopper co_ctx (length insts) net presult)" in spec)
 apply(drule_tac x = "rest" in spec)
 apply(drule_tac x = presult in spec)
 apply(drule_tac x = "code (cfg_insts cfg - set insts) \<and>* rest" in spec)
 apply(simp add: sep_code_code_sep)
 apply(drule_tac x = "stopper" in spec)
 apply(drule_tac x = "net" in spec)
 apply(simp add: code_code_sep)
 apply(drule_tac x = "net" in spec)
 apply (erule_tac P="(post \<and>* code (cfg_insts cfg) \<and>* rest)" in back_subst)
 apply(subst program_sem_t_alt_exec_continue )
 apply(simp)
done

(* Definition of uniq_stateelm to say that a set have a most one element for some state elements *)

definition
 uniq_stateelm :: "state_element set \<Rightarrow> bool"
where
 "uniq_stateelm s ==
(\<forall>v. PcElm v \<in> s \<longrightarrow> (\<forall>x. PcElm x \<in> s \<longrightarrow> x = v)) \<and>
(\<forall>v. GasElm v \<in> s \<longrightarrow> (\<forall>x. GasElm x \<in> s \<longrightarrow> x = v)) \<and>
(\<forall>v. StackHeightElm v \<in> s \<longrightarrow> (\<forall>v'. StackHeightElm v' \<in> s \<longrightarrow> v' = v)) \<and>
(\<forall>v. StackHeightElm v \<in> s \<longrightarrow> (\<forall>h u. h \<ge> v \<longrightarrow> StackElm (h,u) \<notin> s))"

lemma uniq_gaselm:
"s = instruction_result_as_set co_ctx presult \<Longrightarrow>
(\<forall>v. GasElm v \<in> s \<longrightarrow> (\<forall>x. GasElm x \<in> s \<longrightarrow> x = v))"
by(simp add:instruction_result_as_set_def split:instruction_result.splits)

lemma uniq_gaselm_plus[rule_format]:
"instruction_result_as_set co_ctx presult = s + y \<Longrightarrow>
(\<forall>v. GasElm v \<in> s \<longrightarrow> (\<forall>x. GasElm x \<in> s \<longrightarrow> x = v))"
by (drule sym, drule uniq_gaselm, simp add: plus_set_def)

lemma uniq_pcelm:
"s = instruction_result_as_set co_ctx presult \<Longrightarrow>
(\<forall>v. PcElm v \<in> s \<longrightarrow> (\<forall>x. PcElm x \<in> s \<longrightarrow> x = v))"
by(simp add:instruction_result_as_set_def split:instruction_result.splits)

lemma uniq_pcelm_plus[rule_format]:
"instruction_result_as_set co_ctx presult = s + y \<Longrightarrow>
(\<forall>v. PcElm v \<in> s \<longrightarrow> (\<forall>x. PcElm x \<in> s \<longrightarrow> x = v))"
by (drule sym, drule uniq_pcelm, simp add: plus_set_def)

lemma uniq_stackheightelm:
"x = instruction_result_as_set co_ctx presult \<Longrightarrow>
(\<forall>v. StackHeightElm v \<in> x \<longrightarrow> (\<forall>v'. StackHeightElm v' \<in> x \<longrightarrow> v' = v))"
by (simp add:instruction_result_as_set_def split:instruction_result.splits)

lemma uniq_stackheightelm_plus[rule_format]:
"instruction_result_as_set co_ctx presult = x + y \<Longrightarrow>
(\<forall>v. StackHeightElm v \<in> x \<longrightarrow> (\<forall>v'. StackHeightElm v' \<in> x \<longrightarrow> v' = v))"
by (drule sym, drule uniq_stackheightelm, simp add: plus_set_def)

lemma stack_max_elm:
"s = instruction_result_as_set co_ctx presult \<Longrightarrow>
(\<forall>v. StackHeightElm v \<in> s \<longrightarrow> (\<forall>h u. h \<ge> v \<longrightarrow> StackElm (h,u) \<notin> s))"
by(simp add:instruction_result_as_set_def split:instruction_result.splits)

lemma stack_max_elm_plus[rule_format]:
"instruction_result_as_set co_ctx presult = s + y \<Longrightarrow>
(\<forall>v. StackHeightElm v \<in> s \<longrightarrow> (\<forall>h u. h \<ge> v \<longrightarrow> StackElm (h,u) \<notin> s))"
by (drule sym, drule stack_max_elm, simp add: plus_set_def)

lemmas uniq_stateelm_simps=
uniq_stateelm_def
uniq_gaselm_plus uniq_pcelm_plus uniq_stackheightelm_plus
stack_max_elm_plus

lemma inst_res_as_set_uniq_stateelm:
"(pre \<and>* code (cfg_insts cfg) \<and>* resta)
        (instruction_result_as_set co_ctx
          presult) \<Longrightarrow>
       \<exists>s. pre s \<and> uniq_stateelm s"
apply(clarsimp simp add: sep_conj_def)
apply(rule_tac x=x in exI)
apply(simp add: uniq_stateelm_simps)
done

lemma uniq_stateelm_subset:
"Q = P + R \<Longrightarrow> uniq_stateelm Q \<Longrightarrow> uniq_stateelm P"
by(simp add: uniq_stateelm_simps plus_set_def)

lemma uniq_stateelm_inst_res:
"uniq_stateelm (instruction_result_as_set co_ctx presult)"
apply(case_tac presult)
apply(simp add: as_set_simps uniq_stateelm_simps)+
done

(*Lemmas for Jump and Jumpi *)
lemmas uint_word_reverse = word_of_int_inverse[OF refl]

lemma sep_conj_imp:
"(P \<and>* R) s \<Longrightarrow> \<forall>t. P t \<longrightarrow> Q t \<Longrightarrow> (Q \<and>* R) s"
apply(simp add: sep_conj_def)
apply(fastforce)
done

lemma pc_after_inst:
"triple_inst pre x post \<Longrightarrow> x = (n, i) \<Longrightarrow> reg_inst i \<Longrightarrow>
\<exists>s. pre s \<and> uniq_stateelm s \<Longrightarrow>
\<exists>q. post = (program_counter (n + inst_size i) ** q) \<and>
    (\<exists>s0. (program_counter (n + inst_size i) ** q) s0 \<and> uniq_stateelm s0)"
 apply(induct rule: triple_inst.induct; clarsimp)
   apply(rule_tac x="(continuing \<and>*
            memory_usage m \<and>*
            stack_height (Suc h) \<and>*
            gas_pred (g - Gverylow) \<and>*
            stack h (word_rcat lst) \<and>*
            rest)" in exI)
   apply(rule conjI)
    apply(simp add: inst_size_simps del: sep_fun_simps sep_lc)
    apply (rule ext)
    apply (rule iffI)
     apply(sep_select_asm  3)
     apply(sep_cancel)+
     apply(simp add: program_counter_def)
    apply(sep_select 3)
    apply(sep_cancel)+
    apply(simp add: program_counter_def)
   apply(rule_tac x="(s - {GasElm g} - {PcElm n} -
         {StackHeightElm h}) \<union> {GasElm (g - Gverylow)} \<union> {StackElm (h, word_rcat lst)} \<union>
{ StackHeightElm (Suc h)} \<union> {PcElm (n + inst_size (Stack (PUSH_N lst)))}" in exI)
   apply(clarsimp simp add: gas_value_simps)
   apply(rule conjI)
    apply(erule_tac P=rest in back_subst)
    apply(auto simp add: uniq_stateelm_def)[1]
   apply (auto simp add: uniq_stateelm_def)[1]
  apply(rule_tac x="continuing \<and>*
            memory_usage m \<and>*
            stack_height h \<and>*
            gas_pred (g - Gjumpdest) \<and>* rest" in exI)
  apply(rule conjI)
   apply(simp add: inst_size_simps)
  apply(rule_tac x="(s - {GasElm g} - {PcElm n}) \<union> {GasElm (g - Gjumpdest)} \<union>
				{PcElm (n + inst_size (Pc JUMPDEST))}" in exI)
  apply(clarsimp simp add: gas_value_simps)
  apply(rule conjI)
   apply(erule_tac P=rest in back_subst)
   apply(auto simp add: uniq_stateelm_def)[1]
  apply (auto simp add: uniq_stateelm_def)[1]
 apply(drule meta_mp)
 apply(rule_tac x=s in exI; rule conjI; simp)
 apply(assumption)
apply(simp add: pure_def)
done

lemma triple_seq_empty_case[OF _ refl] :
"triple_seq q xs r \<Longrightarrow> xs = [] \<Longrightarrow>
 \<exists>q'. (\<forall>s. q s \<longrightarrow> q' s) \<and> (\<forall>s. q' s \<longrightarrow> r s)"
  apply(induct rule: triple_seq.induct, simp_all)
apply(rule_tac x=post in exI, simp)
  apply force
apply(rule_tac x=post in exI, simp)
apply(simp add: pure_def)
done

lemma triple_seq_empty_case' :
"triple_seq q [] r \<Longrightarrow>
 (\<forall>s. q s \<longrightarrow> r s)"
by(drule triple_seq_empty_case, fastforce)

lemma pc_after_seq:
notes sep_fun_simps[simp del]
shows
" triple_seq pre insts post' \<Longrightarrow>
\<exists>s. pre s \<and> uniq_stateelm s \<Longrightarrow>
\<forall>s. post' s = (program_counter m \<and>* post) s \<Longrightarrow>
fst (hd insts) = n \<Longrightarrow>
insts \<noteq> [] \<Longrightarrow>
seq_block insts \<Longrightarrow>
reg_block insts \<Longrightarrow>
 m = n + inst_size_list insts"
 apply(induction arbitrary:n post rule:triple_seq.induct)
    apply(simp)
    apply(case_tac xs; clarsimp)
     apply(drule triple_seq_empty_case'; clarsimp)
     apply(simp add: reg_block_def)
     apply(drule_tac n=a and i=b and pre=pre and post=q in pc_after_inst; clarsimp)
      apply(fastforce)
     apply(thin_tac "uniq_stateelm s")
		 apply(thin_tac "\<forall>s. _ s = _ s")
     apply(simp add: program_counter_sep uniq_stateelm_def)
    apply(drule_tac x="a + inst_size b" and y=posta in meta_spec2)
    apply(clarsimp)
    apply(simp add:reg_block_def)
    apply(erule conjE)+
    apply(drule_tac n=a and i=b in pc_after_inst)
       apply(simp)+
     apply(fastforce)
    apply(drule meta_mp; clarsimp)
   apply(clarsimp)
  apply(drule_tac x=n and y=post in meta_spec2)
  apply(drule meta_mp)
  apply(clarsimp)
   apply(rule_tac x=s in exI)
   apply(fastforce)
  apply(simp)
 apply (fastforce simp: pure_def)
done

lemma
"cfg_blocks cfg n = Some (bi, ti) \<Longrightarrow>
b \<in> set bi \<Longrightarrow>
n \<in> set xs \<Longrightarrow>
b \<in> set (cfg_pos_insts (cfg_vertices cfg xs))"
 apply(induction xs; simp)
 apply(case_tac "n=a";simp)
  apply(case_tac ti)
     apply(simp)
    apply(clarsimp)
    apply(induction bi)
     apply(simp)
    apply(simp)
    apply(case_tac bi; clarsimp)
oops

lemma
"cfg_blocks cfg n = Some (bi, ti) \<Longrightarrow>
 bi = (n, i) # bbi \<Longrightarrow>
 wf_cfg cfg \<Longrightarrow>
 program_content (program_from_cfg cfg) n = Some i"
 apply(simp add: program_from_cfg_def cfg_content_def)
 apply(induction "cfg_indexes cfg")
  apply(simp add: wf_cfg_def)
 apply(simp)
oops

(* JUMP case *)
lemma extract_info_jump:
"cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
 wf_cfg cfg \<Longrightarrow>
 cfg_blocks cfg n = Some (insts, Jump) \<Longrightarrow>
uint (word_of_int dest::w256) = dest \<and>
program_content (program_from_cfg cfg) (n + inst_size_list insts) = Some (Pc JUMP)"
 apply(rule conjI)
  apply(subst (asm) wf_cfg_def)
  apply(drule spec2[where x="dest" and y="bi"])
  apply(drule spec[where x="ti"])
  apply(drule conjunct1)
  apply(drule mp, assumption)
  apply(erule conjE)+
  apply(simp add: uint_word_reverse)
 apply(subst (asm) wf_cfg_def)
 apply(drule spec2[where x=n and y=insts])
 apply(drule spec[where x=Jump])
 apply(drule conjunct2, drule conjunct2)
 apply(drule conjunct1)
 apply(simp)
done

lemma program_content_some:
"cfg_blocks cfg dest = Some ((dest, Pc JUMPDEST) # bbi, ti) \<Longrightarrow>
 {CodeElm (pos, i) |pos i. (pos, i) \<in> cfg_insts cfg}
       \<subseteq> instruction_result_as_set co_ctx
           (InstructionContinue x1) \<Longrightarrow>
 program_content (program_from_cfg cfg) dest = Some (Pc JUMPDEST)"
sorry


lemma jump_sem:
notes sep_fun_simps[simp del]
shows
"cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
 bi = (dest, Pc JUMPDEST) # bbi \<Longrightarrow>
 no_assertion co_ctx \<Longrightarrow>
 cctx_program co_ctx = program_from_cfg cfg \<Longrightarrow>
 wf_cfg cfg \<Longrightarrow>
 cfg_blocks cfg n = Some (insts, Jump) \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        (continuing \<and>*
         gas_pred g \<and>*
         program_counter (n + inst_size_list insts) \<and>*
         stack_height (Suc h) \<and>*
         stack h (word_of_int dest) \<and>*
         memory_usage m \<and>*
         \<langle> h \<le> 1023 \<and> Gmid \<le> g \<and> 0 \<le> m \<rangle> \<and>*
         restb) \<and>*
        rest)
        (instruction_result_as_set co_ctx presult) \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        (continuing \<and>*
         program_counter dest \<and>*
         stack_height h \<and>*
         gas_pred (g - Gmid) \<and>*
         memory_usage m \<and>* restb) \<and>*
        rest)
        (instruction_result_as_set co_ctx
          (program_sem stopper co_ctx (Suc 0) net
            presult))"
 apply (sep_simp_asm simp: code_sep continuing_sep memory_usage_sep pure_sep gas_pred_sep stack_sep stack_height_sep program_counter_sep )
 apply(clarsimp)
 apply(insert extract_info_jump[where cfg=cfg and n=n and dest=dest and bi=bi and ti=ti and insts=insts]; clarsimp)
 apply(case_tac presult)
   apply(simp add: program_sem.simps instruction_sem_simps inst_numbers_simps)
   apply(clarsimp)
   apply(simp add: instruction_sem_simps jump_def inst_numbers_simps)
   apply (sep_simp simp: code_sep continuing_sep memory_usage_sep pure_sep gas_pred_sep stack_sep stack_height_sep program_counter_sep)+
   apply(clarsimp split: option.splits)
   apply(rule conjI)
		apply(clarsimp simp add: instruction_simps program_content_some)
	 apply(clarsimp simp add: instruction_simps program_content_some)
	 apply(rule conjI)
    apply(erule_tac P="restb \<and>* rest" in back_subst)
    apply(auto simp add: as_set_simps)[1]
	 apply(simp add: instruction_result_as_set_def contexts_as_set_def)
	 apply(auto simp add: as_set_simps)[1]
  apply(simp)+
done

lemma cfg_jump_sem_t:
notes sep_fun_simps[simp del]
shows
"\<And>cfg dest bi ti bbi pre insts p g m h rest post n.
       cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
       bi = (dest, Pc JUMPDEST) # bbi \<Longrightarrow>
       triple_seq pre insts
        (program_counter (n + inst_size_list insts) \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack_height (Suc h) \<and>*
         stack h (word_of_int dest) \<and>*
         \<langle> h \<le> 1023 \<and> Gmid \<le> g \<and> 0 \<le> m \<rangle> \<and>*
         continuing \<and>* rest) \<Longrightarrow>
       triple_cfg cfg
        (program_counter dest \<and>*
         gas_pred (g - Gmid) \<and>*
         memory_usage m \<and>*
         stack_height h \<and>* continuing \<and>* rest)
        (dest, bi, ti) post \<Longrightarrow>
       triple_cfg_sem_t cfg
        (program_counter dest \<and>*
         gas_pred (g - Gmid) \<and>*
         memory_usage m \<and>*
         stack_height h \<and>* continuing \<and>* rest)
        (dest, bi, ti) post \<Longrightarrow>
       triple_cfg_sem_t cfg pre (n, insts, Jump) post"
 apply(simp only: triple_cfg_sem_t_def; clarify)
 apply(drule_tac x=co_ctx and y="(program_sem stopper co_ctx (Suc (length insts)) net presult)" in spec2)
 apply(drule_tac x=resta and y=net in spec2)
 apply(drule_tac x=stopper in spec)
 apply(clarify)
 apply(case_tac "insts")
  apply(drule mp)
   apply(simp)
  apply(cut_tac q=pre and r="(program_counter (n + inst_size_list insts) \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack_height (Suc h) \<and>*
         stack h (word_of_int dest) \<and>*
         \<langle> h \<le> 1023 \<and> Gmid \<le> g \<and> 0 \<le> m \<rangle> \<and>* continuing \<and>* rest)"
        in triple_seq_empty_case')
   apply(clarsimp)
  apply(drule mp)
   apply(clarsimp)
   apply(drule_tac P=pre in sep_conj_imp, assumption)
   apply(drule_tac bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and g=g and h=h and presult=presult and
         m=m and restb=rest and rest=resta
         in jump_sem; simp)
   apply(simp)
  apply(simp add: program_sem_t_alt_exec_continue)
 apply(cut_tac m="n + inst_size_list insts" and n=n
			 and post=" (gas_pred g \<and>* memory_usage m \<and>* stack_height (Suc h) \<and>*
         stack h (word_of_int dest) \<and>* \<langle> h \<le> 1023 \<and> Gmid \<le> g \<and> 0 \<le> m \<rangle> \<and>* continuing \<and>* rest)"
			 in pc_after_seq)
        apply(assumption)
			 apply(simp add: inst_res_as_set_uniq_stateelm)
		  apply(simp add: wf_cfg_def)
     apply(simp add: wf_cfg_def)
     apply(drule_tac x=n and y=insts in spec2; drule conjunct1)
	   apply(drule_tac x=Jump in spec; simp)
    apply(fastforce)
   apply(simp add: wf_cfg_def)
  apply(simp add: wf_cfg_def)
	apply(simp add: reg_vertex_def)
	apply(drule_tac x=n and y=insts in spec2; drule conjunct1)
	apply(drule_tac x=Jump in spec; simp)
 apply(thin_tac "_ = _ # _")
 apply(drule triple_seq_soundness)
 apply(simp only: triple_seq_sem_def)
 apply(rename_tac cfg dest bi ti bbi pre insts p g m h restb post n
       co_ctx presult rest net stopper a list)
 apply(drule_tac x = "co_ctx" in spec)
 apply(drule_tac x = "presult" and y = "code (cfg_insts cfg - set insts) \<and>* rest" in spec2)
 apply(clarsimp)
 apply(simp add: sep_code_code_sep )
 apply(drule_tac x = "stopper" and y= net in spec2)
 apply (erule impE)
  prefer 2
  apply (erule_tac P="post \<and>* code (cfg_insts cfg) \<and>* rest" in back_subst)
  apply(subst program_sem_t_alt_exec_continue; simp )
  apply(simp add: code_code_sep)
  apply(drule_tac co_ctx=co_ctx and stopper=stopper and insts=insts and net=net and
    presult="(program_sem stopper co_ctx (length insts) net presult)" and h=h
    and g=g and m=m and rest=rest
   in jump_sem; simp)
done

(* JUMPI case *)

lemma diff_set_commute:
"A - {b} - {c} = A - {c} - {b}"
by(auto)

lemma diff_set_commute_code:
"A - {CodeElm (pos, i) |pos i.
        (pos, i) \<in> cfg_insts cfg} - {c} = A - {c} - {CodeElm (pos, i) |pos i.
        (pos, i) \<in> cfg_insts cfg}"
by(auto)

lemma extract_info_jumpi:
"      cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
       cfg_blocks cfg j = Some (bj, tj) \<Longrightarrow>
       wf_cfg cfg \<Longrightarrow>
       cfg_blocks cfg n = Some (insts, Jumpi) \<Longrightarrow>
dest = uint (word_of_int dest::256 word) \<and>
program_content (program_from_cfg cfg) (n + inst_size_list insts) = Some (Pc JUMPI)"
 apply(rule conjI; simp add: wf_cfg_def)
 apply(drule spec2[where x=dest and y=bi])
 apply(drule conjunct1)
 apply(drule spec[where x=ti])
 apply(simp add: uint_word_reverse)
done

lemma set_change_stack:
"instruction_result_as_set co_ctx
        (InstructionContinue
          (x1\<lparr>vctx_stack := ta, vctx_pc := k,
                vctx_gas := g\<rparr>)) -
       {StackHeightElm (length ta)} =
instruction_result_as_set co_ctx
        (InstructionContinue
          (x1\<lparr>vctx_stack := cond # ta, vctx_pc := k,
                vctx_gas := g\<rparr>)) -
       {StackElm (length ta, cond)} -
       {StackHeightElm (Suc (length ta))}"
by(auto simp add: as_set_simps)

lemma set_change_stack_2:
"vctx_stack x1 = word_of_int dest # cond # ta \<Longrightarrow>
instruction_result_as_set co_ctx
        (InstructionContinue
          (x1\<lparr>vctx_stack := cond # ta,
                vctx_pc := p,
                vctx_gas := g\<rparr>)) -
       {StackHeightElm (Suc (length ta))}=
instruction_result_as_set co_ctx
        (InstructionContinue
          (x1\<lparr>vctx_pc := p,
                vctx_gas := g\<rparr>)) -
       {StackElm (Suc (length ta), word_of_int dest)} -
       {StackHeightElm (Suc (Suc (length ta)))}"
by(auto simp add: as_set_simps)


lemma jumpi_sem_zero:
notes sep_fun_simps[simp del]
shows
"      cfg_blocks cfg i = Some (bi, ti) \<Longrightarrow>
       cfg_blocks cfg j = Some (bj, tj) \<Longrightarrow>
			 j = n + 1 + inst_size_list insts \<Longrightarrow>
       no_assertion co_ctx \<Longrightarrow>
       cctx_program co_ctx = program_from_cfg cfg \<Longrightarrow>
       wf_cfg cfg \<Longrightarrow>
       cfg_blocks cfg n = Some (insts, Jumpi) \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        (continuing \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack h 0 \<and>*
         stack_height (Suc (Suc h)) \<and>*
         program_counter (n + inst_size_list insts) \<and>*
         stack (Suc h) (word_of_int i) \<and>*
         \<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>* restb) \<and>*
        rest)
        (instruction_result_as_set co_ctx presult) \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        ((continuing \<and>*
          stack_height h \<and>*
          gas_pred (g - Ghigh) \<and>*
          memory_usage m \<and>* restb) \<and>*
         program_counter j) \<and>*
        rest)
        (instruction_result_as_set co_ctx
          (program_sem stopper co_ctx (Suc 0) net
            presult))"
 apply (sep_simp_asm simp: stack_sep stack_height_sep memory_usage_sep pure_sep gas_pred_sep program_counter_sep )
 apply(clarsimp)
 apply(insert extract_info_jumpi[where cfg=cfg and n=n and dest=i and j=j and bi=bi and ti=ti and insts=insts and bj=bj and tj=tj])
 apply(clarsimp)
 apply(simp add: program_sem.simps instruction_sem_simps)
 apply(split instruction_result.splits)
 apply(rule conjI;clarsimp)
  apply(simp add:instruction_sem_simps inst_numbers_simps)
  apply(simp add: jumpi_def advance_simps instruction_sem_simps inst_size_simps)
  apply (sep_subst simp: stack_sep memory_usage_sep gas_pred_sep  stack_height_sep program_counter_sep, simp)+
  apply (erule_tac P="(continuing \<and>* restb \<and>* code (cfg_insts cfg) \<and>* rest)" in back_subst)
  apply(subst diff_set_commute[where c="StackHeightElm _"])+
  apply(subst set_change_stack[where cond=0])
  apply(subst diff_set_commute[where c="StackHeightElm _"])
  apply(subst set_change_stack_2[where dest=i])
  apply(simp)
  apply(auto simp add: as_set_simps)[1]
 apply(rule conjI; clarsimp)
 apply(sep_simp simp:continuing_sep)
 apply(simp)
done

lemma jumpi_sem_non_zero:
notes sep_fun_simps[simp del]
shows
"      cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
       cfg_blocks cfg j = Some (bj, tj) \<Longrightarrow>
			 bi = (dest, Pc JUMPDEST) # bbi \<Longrightarrow>
       no_assertion co_ctx \<Longrightarrow>
       cctx_program co_ctx = program_from_cfg cfg \<Longrightarrow>
       wf_cfg cfg \<Longrightarrow>
       cfg_blocks cfg n = Some (insts, Jumpi) \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        (continuing \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack h cond \<and>*
         stack_height (Suc (Suc h)) \<and>*
         program_counter (n + inst_size_list insts) \<and>*
         stack (Suc h) (word_of_int dest) \<and>*
         \<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>* restb) \<and>*
        rest)
        (instruction_result_as_set co_ctx presult) \<Longrightarrow>
       cond \<noteq> 0 \<Longrightarrow>
       (code (cfg_insts cfg) \<and>*
        ((continuing \<and>*
          memory_usage m \<and>*
          stack_height h \<and>* gas_pred (g - Ghigh) \<and>* restb) \<and>*
         program_counter dest) \<and>*
        rest)
        (instruction_result_as_set co_ctx
          (program_sem stopper co_ctx (Suc 0) net presult))"
 apply (sep_simp_asm simp: code_sep memory_usage_sep pure_sep gas_pred_sep stack_sep stack_height_sep program_counter_sep )
 apply(clarsimp)
 apply(insert extract_info_jumpi[where cfg=cfg and n=n and dest=dest and j=j and bi=bi and ti=ti and insts=insts and bj=bj and tj=tj])
 apply(clarsimp)
 apply(simp add: program_sem.simps instruction_sem_simps)
 apply(split instruction_result.splits)
 apply(rule conjI;clarsimp)
  apply(simp add:instruction_sem_simps inst_numbers_simps)
  apply(simp add: jumpi_def jump_def advance_simps instruction_sem_simps inst_size_simps)
	apply(sep_simp simp: code_sep)
  apply (sep_simp simp: memory_usage_sep gas_pred_sep stack_sep stack_height_sep program_counter_sep)+
  apply(simp add: instruction_sem_simps split: option.splits)
	apply(rule conjI)
	 apply(clarsimp simp add: instruction_simps)
	 apply(simp add: continuing_sep program_content_some)
	apply(clarsimp simp add: instruction_simps program_content_some)
  apply(rule conjI)
   apply (erule_tac P="(continuing \<and>* restb \<and>* rest)" in back_subst)
   apply(subst diff_set_commute[where c="StackHeightElm _"])+
   apply(subst diff_set_commute_code[where c="StackHeightElm _"])+
   apply(subst set_change_stack[where cond=cond])
   apply(subst diff_set_commute[where c="StackHeightElm _"])
   apply(subst set_change_stack_2[where dest=dest])
   apply(simp)
   apply(auto simp add: as_set_simps)[1]
	apply(simp add: instruction_result_as_set_def contexts_as_set_def)
	apply(auto simp add: as_set_simps)[1]
 apply(rule conjI; clarsimp)
 apply(sep_simp simp:continuing_sep)
 apply(simp)
done

lemma cfg_jumpi_sem_t:
notes sep_fun_simps[simp del]
shows
"\<And>j n insts cfg dest bi ti bbi bj tj pre h g m cond p
       rest r post.
       j = n + 1 + inst_size_list insts \<Longrightarrow>
       cfg_blocks cfg dest = Some (bi, ti) \<Longrightarrow>
       bi = (dest, Pc JUMPDEST) # bbi \<Longrightarrow>
       cfg_blocks cfg j = Some (bj, tj) \<Longrightarrow>
       triple_seq pre insts
        (\<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>*
         stack_height (Suc (Suc h)) \<and>*
         stack (Suc h) (word_of_int dest) \<and>*
         stack h cond \<and>*
         gas_pred g \<and>*
         continuing \<and>*
         memory_usage m \<and>* program_counter (n + inst_size_list insts) \<and>* rest) \<Longrightarrow>
       r =
       (stack_height h \<and>*
        gas_pred (g - Ghigh) \<and>*
        continuing \<and>* memory_usage m \<and>* rest) \<Longrightarrow>
       (cond \<noteq> 0 \<Longrightarrow>
        triple_cfg cfg (r \<and>* program_counter dest)
         (dest, bi, ti) post) \<Longrightarrow>
       (cond \<noteq> 0 \<Longrightarrow>
        triple_cfg_sem_t cfg (r \<and>* program_counter dest)
         (dest, bi, ti) post) \<Longrightarrow>
       (cond = 0 \<Longrightarrow>
        triple_cfg cfg (r \<and>* program_counter j)
         (j, bj, tj) post) \<Longrightarrow>
       (cond = 0 \<Longrightarrow>
        triple_cfg_sem_t cfg (r \<and>* program_counter j)
         (j, bj, tj) post) \<Longrightarrow>
       triple_cfg_sem_t cfg pre (n, insts, Jumpi) post"
 apply(simp only: triple_cfg_sem_t_def; clarify)
 apply(case_tac "insts")
  apply(case_tac "cond = 0"; clarify)
   apply(thin_tac "0 \<noteq> 0 \<Longrightarrow> _")+
   apply(simp)
   apply(drule_tac x=co_ctx in spec; simp; drule_tac x="(program_sem (\<lambda>x. ()) co_ctx (Suc 0) net presult)" in spec)
   apply(drule_tac x=resta in spec)
   apply(drule mp)
    apply(cut_tac q=pre and r="(program_counter n \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack h 0 \<and>*
         stack_height (Suc (Suc h)) \<and>*
         stack (Suc h) (word_of_int dest) \<and>*
         \<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>* continuing \<and>* rest)"
        in triple_seq_empty_case')
     apply(clarsimp)
    apply(clarsimp)
    apply(drule_tac P=pre in sep_conj_imp, assumption)
    apply(drule_tac bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and g=g and h=h and presult=presult and
         m=m and restb=rest and rest=resta
         in jumpi_sem_zero; simp)
    apply(simp)
   apply(drule_tac x=net in spec)
   apply(simp add: program_sem_t_alt_exec_continue)
  apply(clarsimp)
  apply(drule_tac x=co_ctx in spec; simp; drule_tac x="(program_sem (\<lambda>x. ()) co_ctx (Suc 0) net presult)" in spec)
  apply(drule_tac x=resta in spec)
  apply(drule mp)
   apply(cut_tac q=pre and r="(program_counter n \<and>*
         gas_pred g \<and>*
         memory_usage m \<and>*
         stack h cond \<and>*
         stack_height (Suc (Suc h)) \<and>*
         stack (Suc h) (word_of_int dest) \<and>*
         \<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>* continuing \<and>* rest)"
        in triple_seq_empty_case')
    apply(clarsimp)
   apply(clarsimp)
   apply(drule_tac P=pre in sep_conj_imp, assumption)
   apply(drule_tac bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and g=g and h=h and presult=presult and
         m=m and restb=rest and rest=resta
         in jumpi_sem_non_zero; simp)
   apply(simp)
  apply(drule_tac x=net in spec)
  apply(simp add: program_sem_t_alt_exec_continue)
 apply(cut_tac m="n + inst_size_list insts" and n=n
			 and post=" (gas_pred g \<and>* memory_usage m \<and>* stack_height (Suc (Suc h)) \<and>*
         stack (Suc h) (word_of_int dest) \<and>* stack h cond \<and>* \<langle> h \<le> 1022 \<and> Ghigh \<le> g \<and> 0 \<le> m \<rangle> \<and>*
         continuing \<and>* rest)"
			 in pc_after_seq)
        apply(assumption)
			 apply(simp add: inst_res_as_set_uniq_stateelm)
		  apply(simp add: wf_cfg_def)
     apply(simp add: wf_cfg_def)
     apply(drule_tac x=n and y=insts in spec2; drule conjunct1)
	   apply(drule_tac x=Jumpi in spec; simp)
    apply(fastforce)
   apply(simp add: wf_cfg_def)
  apply(simp add: wf_cfg_def)
	apply(simp add: reg_vertex_def)
	apply(drule_tac x=n and y=insts in spec2; drule conjunct1)
	apply(drule_tac x=Jumpi in spec; simp)
(* <<<<<<< HEAD
  apply(drule triple_seq_soundness)
  apply(simp only: triple_seq_sem_def; clarify)
  apply(rename_tac j n insts cfg dest bi ti bbi bj tj pre h g m cond p
       restb r post co_ctx presult rest net stopper)
  apply(drule_tac x = "co_ctx" and y=presult in spec2)
  apply(drule_tac x = "code (cfg_insts cfg - set insts) \<and>* rest" in spec)
  apply(drule_tac x = "stopper" and y=net in spec2)
  apply(clarsimp)
  apply(simp add: sep_code_code_sep )
	apply(simp add: code_code_sep)
	apply(case_tac "cond=0"; clarsimp)
	 apply(drule_tac x = "co_ctx" in spec)
	 apply(clarsimp)
   apply(drule_tac x = "(program_sem stopper co_ctx (Suc (length insts)) net presult)" in spec)
   apply(drule_tac x = "rest" in spec)
   apply (erule impE)
    prefer 2
    apply(drule_tac x = "net" in spec)
    apply (erule_tac P="post \<and>* code (cfg_insts cfg) \<and>* rest" in back_subst)
    apply(subst program_sem_t_alt_exec_continue; simp )
   apply(drule_tac presult="(program_sem stopper co_ctx (length insts) net presult)" and
		cfg=cfg and j="n + 1 + inst_size_list insts" and bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and bj=bj and tj=tj and h=h and g=g and net=net and
	  i=dest and restb=restb and co_ctx=co_ctx and rest=rest and stopper=stopper and m=m
  in jumpi_sem_zero; simp)
   apply(sep_simp simp:program_counter_sep)
   apply(simp)
	 apply(drule_tac x = "co_ctx" in spec)
	 apply(clarsimp)
   apply(drule_tac x = "(program_sem stopper co_ctx (Suc (length insts)) net presult)" in spec)
   apply(drule_tac x = "rest" in spec)
   apply (erule impE)
    prefer 2
    apply(drule_tac x = "net" in spec)
    apply (erule_tac P="post \<and>* code (cfg_insts cfg) \<and>* rest" in back_subst)
    apply(subst program_sem_t_alt_exec_continue; simp)
   apply(drule_tac co_ctx=co_ctx and stopper=stopper and insts=insts and
		g=g and restb=restb and n=n and bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and tj=tj and g=g and
======= *)
 apply(thin_tac "_ = _ # _")
 apply(drule triple_seq_soundness)
 apply(simp only: triple_seq_sem_def; clarify)
 apply(rename_tac j n insts cfg dest bi ti bbi bj tj pre h g m cond p
       restb r post co_ctx presult rest net stopper a b
       list)
 apply(drule_tac x = "co_ctx" and y=presult in spec2)
 apply(drule_tac x = "code (cfg_insts cfg - set insts) \<and>* rest" in spec)
 apply(drule_tac x = "stopper" and y=net in spec2)
 apply(clarsimp)
 apply(simp add: sep_code_code_sep )
 apply(simp add: code_code_sep)
 apply(case_tac "cond=0"; clarsimp)
  apply(drule_tac x = "co_ctx" in spec)
	apply(clarsimp)
  apply(drule_tac x = "(program_sem stopper co_ctx (Suc (length insts)) net presult)" in spec)
  apply(drule_tac x = "rest" in spec)
  apply (erule impE)
   prefer 2
   apply(drule_tac x = "net" in spec)
   apply (erule_tac P="post \<and>* code (cfg_insts cfg) \<and>* rest" in back_subst)
   apply(subst program_sem_t_alt_exec_continue; simp )
  apply(drule_tac presult="(program_sem stopper co_ctx (length insts) net presult)" and
		cfg=cfg and j="n + 1 + inst_size_list insts" and bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and bj=bj and tj=tj and h=h and g=g and net=net and
	  i=dest and restb=restb and co_ctx=co_ctx and rest=rest and stopper=stopper and m=m
  in jumpi_sem_zero; simp)
  apply(sep_simp simp:program_counter_sep)
  apply(simp)
 apply(drule_tac x = "co_ctx" in spec)
 apply(clarsimp)
 apply(drule_tac x = "(program_sem stopper co_ctx (Suc (length insts)) net presult)" in spec)
 apply(drule_tac x = "rest" in spec)
 apply (erule impE)
  prefer 2
  apply(drule_tac x = "net" in spec)
  apply (erule_tac P="post \<and>* code (cfg_insts cfg) \<and>* rest" in back_subst)
  apply(subst program_sem_t_alt_exec_continue; simp)
 apply(drule_tac co_ctx=co_ctx and stopper=stopper and insts=insts and
		g=g and restb=restb and n=n and bi="(dest, Pc JUMPDEST) # bbi" and ti=ti and tj=tj and g=g and
(* >>>>>>> [CFG] Remove 'insts not empty' in wf_cfg for Jump and Jumpi blocks *)
		dest=dest and net=net and
    presult="(program_sem stopper co_ctx (length insts) net presult)" and h=h
  in jumpi_sem_non_zero; simp del:sep_lc)
done

(* NO case *)
lemma program_sem_to_environment:
"program_sem st c k n (InstructionToEnvironment x y z) = InstructionToEnvironment x y z"
 by(induction k; simp add: program_sem.simps)

lemma program_sem_failure:
"program_sem st c k n (InstructionAnnotationFailure) = InstructionAnnotationFailure"
 by(induction k; simp add: program_sem.simps)

lemma pc_before_inst:
"triple_inst pre x post \<Longrightarrow>
x = (n, i) \<Longrightarrow>
pre s \<and> uniq_stateelm s \<Longrightarrow>
PcElm n \<in> s"
 apply(induct rule: triple_inst.induct; clarsimp)
 apply(simp add: pure_def)
done

lemma pc_before_seq:
"triple_seq pre insts post \<Longrightarrow>
fst (hd insts) = n \<Longrightarrow>
insts \<noteq> [] \<Longrightarrow>
pre s \<and> uniq_stateelm s \<Longrightarrow>
PcElm n \<in> s"
 apply(induction rule:triple_seq.induct; clarsimp)
   apply(simp add: pc_before_inst)
 apply(simp add: pure_def)
done

lemma execution_stop:
"\<forall>v. program_sem stopper co_ctx k net presult \<noteq>
		InstructionContinue v \<Longrightarrow>
program_sem_t_alt co_ctx net presult = program_sem stopper co_ctx k net presult"
 apply(case_tac "program_sem stopper co_ctx k net presult")
   apply(fastforce)
  apply(insert program_sem_t_alt_exec_continue[where stopper=stopper and co_ctx=co_ctx and k=k and net=net and presult=presult])
  apply(drule sym[where t="program_sem_t_alt co_ctx net presult"])
  apply(clarsimp simp add: program_sem_t_alt.simps)
 apply(insert program_sem_t_alt_exec_continue[where stopper=stopper and co_ctx=co_ctx and k=k and net=net and presult=presult])
 apply(drule sym[where t="program_sem_t_alt co_ctx net presult"])
 apply(clarsimp simp add: program_sem_t_alt.simps)
done

lemma pc_advance_continue:
"reg_inst i \<Longrightarrow>
        program_content (cctx_program co_ctx)
         (vctx_pc x) = Some i \<Longrightarrow>
       vctx_next_instruction x co_ctx = Some x2 \<Longrightarrow>
       check_resources x co_ctx (vctx_stack x) x2 net \<Longrightarrow>
       instruction_sem x co_ctx x2 net =
       InstructionContinue x1 \<Longrightarrow>
       vctx_pc x + int (length (inst_code i)) = vctx_pc x1"
apply(case_tac x2; simp add: instruction_simps)
						apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps split:list.splits; clarsimp)
					 apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps split:list.splits; clarsimp)
					apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps Let_def M_def split:list.splits if_splits; clarsimp)
				 apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps split:list.splits; clarsimp)
				apply(split option.splits; clarsimp; simp add: instruction_simps split:list.splits; clarsimp)
			 apply(rename_tac y; case_tac y; clarsimp)
						 apply(simp add: instruction_simps M_def split:list.splits; clarsimp)+
			apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps sstore_def vctx_update_storage_def split:list.splits; clarsimp)
		 apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps reg_inst.simps pc_def split:list.splits; clarsimp)
		apply(rename_tac y; case_tac y; clarsimp; simp add: instruction_simps split:list.splits; clarsimp)
	 apply(simp add: instruction_simps swap_def split:list.splits option.splits; clarsimp)
	apply(rename_tac y; case_tac y; simp add: instruction_simps log_def split:list.splits; clarsimp)
 apply(rename_tac y; case_tac y; clarsimp)
		 apply(simp add: instruction_simps reg_inst.simps create_def call_def callcode_def delegatecall_def Let_def split:list.splits if_splits; clarsimp)+
done

lemma stop_after_no_continue:
notes sep_fun_simps[simp del] last_def[simp del]
shows
"insts = (vctx_pc x,i)#xs \<Longrightarrow>
last_no insts \<Longrightarrow>
seq_block insts \<Longrightarrow>
reg_vertex (m, insts, No) \<Longrightarrow>
\<forall>a b. (a,b)\<in> (set insts) \<longrightarrow>
   (program_content (cctx_program co_ctx) a = Some b \<or>
   program_content (cctx_program co_ctx) a = None \<and> b = Misc STOP) \<Longrightarrow>
cctx_program co_ctx = program_from_cfg cfg \<Longrightarrow>
\<forall>v. program_sem stopper co_ctx (length insts) net (InstructionContinue x) \<noteq>
		InstructionContinue v"
 apply(induction insts arbitrary: i x xs)
  apply(simp)
 apply(clarsimp)
 apply(case_tac xs)
	apply(simp)
	apply(thin_tac "(\<And>i x xs. False \<Longrightarrow> _ x i xs \<Longrightarrow> _ x i xs \<Longrightarrow> _ x i xs \<Longrightarrow> \<forall>v. _ x i xs v)")
  apply(simp add: last_no_def)
	apply(case_tac i; simp)
	apply(case_tac x13; simp)
		apply(simp add: program_sem.simps instruction_simps stop_def split: if_splits)
    apply(case_tac "program_content (program_from_cfg cfg) (vctx_pc x)";
          simp add: program_sem.simps instruction_simps stop_def split: option.splits if_splits)
	 apply(simp add: program_sem.simps instruction_simps ret_def split: if_splits list.splits)
	apply(simp add: program_sem.simps instruction_simps suicide_def split: if_splits list.splits)
 apply(drule subst[OF program_sem.simps(2), where P="\<lambda>u. u = _"])
 apply(simp add: instruction_simps)
 apply(simp split: if_splits)
	apply(simp add: program_sem_failure)
 apply(simp split: option.splits)
	apply(simp add: program_sem_to_environment)
 apply(simp add: program_sem_to_environment split: if_splits)
 apply(clarsimp)
 apply(drule_tac x="b" in meta_spec; simp)
 apply(case_tac "(instruction_sem x co_ctx x2 net)")
	 apply(simp)
	 apply(drule_tac x=x1 and y=list in meta_spec2)
	 apply(subgoal_tac "vctx_pc x + int (length (inst_code i)) = vctx_pc x1")
		apply(simp add: last_no_def reg_block_def reg_vertex_def)
	 apply(insert pc_advance_continue[where co_ctx=co_ctx])
   apply(drule_tac x=i and y=x in meta_spec2;
          drule_tac x=x2 and y=net in meta_spec2; drule_tac x=x1 in meta_spec)
   apply(simp add: reg_block_def reg_vertex_def)
   apply(drule_tac x="vctx_pc x" and y=i in spec2; simp)
   apply(drule conjunct1, erule disjE; simp)
	apply(simp add: program_sem_failure)
 apply(simp add: program_sem_to_environment)
done

lemma cfg_no_sem_t:
notes sep_fun_simps[simp del]
shows
" triple_seq pre insts post \<Longrightarrow>
  triple_cfg_sem_t cfg pre (n, insts, No) post"
 apply(simp add: triple_cfg_sem_t_def; clarsimp)
 apply(insert pc_before_seq[where n=n and pre=pre and insts=insts and post=post]; simp)
 apply(drule triple_seq_soundness)
 apply(simp add: triple_seq_sem_def)
 apply(rename_tac co_ctx presult rest net)
 apply(drule_tac x = co_ctx in spec)
 apply(clarify)
 apply(drule_tac x = presult and y = "code (cfg_insts cfg - set insts) \<and>* rest" in spec2)
 apply(drule mp)
 apply(simp add: sep_code_code_sep)
 apply(drule_tac x="\<lambda>x. ()" and y=net in spec2)
 apply(subgoal_tac "wf_cfg cfg")
  prefer 2 apply(assumption)
 apply(subst (asm) wf_cfg_def)
 apply(simp)
 apply(drule spec2[where x=n and y=insts])
 apply(erule conjE)
 apply(drule spec[where x=No])
 apply(drule mp, assumption)
 apply(drule conjunct2, drule conjunct2, drule conjunct2, drule conjunct1)
 apply(drule conjunct2)+
 apply(simp add: sep_code_code_sep)
 apply(subst execution_stop[where k="length insts" and stopper="\<lambda>x. ()"])
 apply(case_tac presult)
    apply(case_tac insts)
     apply(clarsimp)
    apply(subgoal_tac "a = (vctx_pc x1, snd a)")
     apply(cut_tac x=x1 and i="snd a" and xs=list and m=n and co_ctx=co_ctx and net=net
      in stop_after_no_continue[where insts=insts and stopper="\<lambda>x. ()" and cfg=cfg]; simp)
       (* apply(simp add: wf_cfg_def) *)
      apply(simp add: wf_cfg_def)
     apply(drule_tac r=rest and s="instruction_result_as_set co_ctx (InstructionContinue x1)"
        in sep_code_code_sep[where p=pre]; simp)
     apply(sep_simp simp: code_sep[where rest="pre \<and>* _" and pairs="set _"])
     apply(simp add: instruction_result_as_set_def)
     apply(clarsimp)
     apply(subgoal_tac "CodeElm (aa, ba) \<in> insert (ContinuingElm True) (contexts_as_set x1 co_ctx)")
      apply(clarsimp)
     apply(subgoal_tac "CodeElm (aa, ba) \<in> {CodeElm (pos, i) |pos i. (pos, i) \<in> set list}")
      apply(rule_tac A="{CodeElm (pos, i) |pos i. (pos, i) \<in> set list}" in set_rev_mp; simp)
     apply(simp)
    apply(clarsimp)
    apply(simp add: sep_conj_def[where P=pre])
    apply(clarsimp)
    apply(drule_tac x=x in meta_spec)
    apply(drule meta_mp)
     apply(simp)
     apply(rule_tac Q="instruction_result_as_set co_ctx (InstructionContinue x1)"
           and R=y in uniq_stateelm_subset)
      apply(simp)
     apply(rule uniq_stateelm_inst_res)
    apply(subgoal_tac "PcElm n \<in> instruction_result_as_set co_ctx (InstructionContinue x1)")
     apply(thin_tac "instruction_result_as_set _ _ = _")
     apply(drule subst[OF instruction_result_as_set_def, where P="\<lambda>u. PcElm n \<in> u"], simp)
		 apply(simp add: wf_cfg_def)
		 apply(drule_tac x=n and y="(a, b) # list" in spec2, simp)
    apply(simp add: plus_set_def)
   apply(simp add: program_sem_failure)
  apply(simp add: program_sem_to_environment)
 apply(simp)
done


lemma triple_cfg_soundness_t :
notes sep_fun_simps[simp del]
shows
"triple_cfg c pre v post \<Longrightarrow> triple_cfg_sem_t c pre v post"
 apply(induction rule: triple_cfg.induct)
     apply(simp add: cfg_no_sem_t)
    apply(simp add: cfg_next_sem_t)
   apply(simp add: cfg_jump_sem_t)
  apply(simp add: cfg_jumpi_sem_t)
 apply(simp add: triple_cfg_sem_t_def)
done

end
