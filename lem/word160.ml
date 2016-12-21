(*Generated by Lem from lem/word160.lem.*)
(*
  Copyright 2016 Sami MÃ¤kelÃ¤

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
open Lem_pervasives
open Lem_word

type word160 = W160 of bool * bool list

(* perhaps should truncate here? *)
(*val bs_to_w160 : bitSequence -> word160*)
let bs_to_w160 seq:word160=  ((match resizeBitSeq (Some( 160)) seq with
 | BitSeq( _, s, b) -> W160( s, b)
))

(*val w160_to_bs : word160 -> bitSequence*)
let w160_to_bs (W160( s, b)):bitSequence=  (BitSeq( (Some( 160)), s, b))

(*val word160BinTest : forall 'a. (bitSequence -> bitSequence -> 'a) -> word160 -> word160 -> 'a*)
let word160BinTest binop w1 w2:'a=  (binop (w160_to_bs w1) (w160_to_bs w2))

(*val word160BinOp : (bitSequence -> bitSequence -> bitSequence) -> word160 -> word160 -> word160*)
let word160BinOp binop w1 w2:word160=  (bs_to_w160 (binop (w160_to_bs w1) (w160_to_bs w2)))

(*val word160NatOp : (bitSequence -> nat -> bitSequence) -> word160 -> nat -> word160*)
let word160NatOp binop w1 n:word160=  (bs_to_w160 (binop (w160_to_bs w1) n))

(*val word160UnaryOp : (bitSequence -> bitSequence) -> word160 -> word160*)
let word160UnaryOp op w:word160=  (bs_to_w160 (op (w160_to_bs w)))

(*val word160ToNatural : word160 -> natural*)
let word160ToNatural w:Nat_big_num.num=  (naturalFromBitSeq (w160_to_bs w))

(*val word160ToInteger : word160 -> integer*)
let word160ToInteger w:Nat_big_num.num=  (integerFromBitSeq (w160_to_bs w))

(*val word160FromInteger : integer -> word160*)
let word160FromInteger i:word160=  (bs_to_w160 (bitSeqFromInteger (Some( 160)) i))

(*val word160FromInt : int -> word160*)
let word160FromInt i:word160=  (bs_to_w160 (bitSeqFromInteger (Some( 160)) (Nat_big_num.of_int i)))

(*val word160FromNatural : natural -> word160*)
let word160FromNatural i:word160=  (word160FromInteger ( i))

(*val word160FromBoollist : list bool -> word160*)
let word160FromBoollist lst:word160=  ((match bitSeqFromBoolList lst with
 | None -> bs_to_w160(bitSeqFromInteger None (Nat_big_num.of_int 0))
 | Some a -> bs_to_w160 a
))

(*val boolListFromWord160 : word160 -> list bool*)
let boolListFromWord160 w:(bool)list=  (boolListFrombitSeq( 160) (w160_to_bs w))

(*val word160FromNumeral : numeral -> word160*)
let word160FromNumeral w:word160=  (bs_to_w160 (bitSeqFromInteger None (Nat_big_num.of_int w)))

(*val w160Eq : word160 -> word160 -> bool*)
let w160Eq:word160 ->word160 ->bool=  (=)

(*val w160Less : word160 -> word160 -> bool*)
let w160Less bs1 bs2:bool=  (word160BinTest bitSeqLess bs1 bs2)

(*val w160LessEqual : word160 -> word160 -> bool*)
let w160LessEqual bs1 bs2:bool=  (word160BinTest bitSeqLessEqual bs1 bs2)

(*val w160Greater : word160 -> word160 -> bool*)
let w160Greater bs1 bs2:bool=  (word160BinTest bitSeqGreater bs1 bs2)

(*val w160GreaterEqual : word160 -> word160 -> bool*)
let w160GreaterEqual bs1 bs2:bool=  (word160BinTest bitSeqGreaterEqual bs1 bs2)

(*val w160Compare : word160 -> word160 -> ordering*)
let w160Compare bs1 bs2:int=  (word160BinTest bitSeqCompare bs1 bs2)

let instance_Basic_classes_Ord_Word160_word160_dict:(word160)ord_class= ({

  compare_method = w160Compare;

  isLess_method = w160Less;

  isLessEqual_method = w160LessEqual;

  isGreater_method = w160Greater;

  isGreaterEqual_method = w160GreaterEqual})

let instance_Basic_classes_SetType_Word160_word160_dict:(word160)setType_class= ({

  setElemCompare_method = w160Compare})

(*val word160Negate : word160 -> word160*)
let word160Negate:word160 ->word160=  (word160UnaryOp bitSeqNegate)

(*val word160Succ : word160 -> word160*)
let word160Succ:word160 ->word160=  (word160UnaryOp bitSeqSucc)

(*val word160Pred : word160 -> word160*)
let word160Pred:word160 ->word160=  (word160UnaryOp bitSeqPred)

(*val word160Lnot : word160 -> word160*)
let word160Lnot:word160 ->word160=  (word160UnaryOp bitSeqNot)

(*val word160Add : word160 -> word160 -> word160*)
let word160Add:word160 ->word160 ->word160=  (word160BinOp bitSeqAdd)

(*val word160Minus : word160 -> word160 -> word160*)
let word160Minus:word160 ->word160 ->word160=  (word160BinOp bitSeqMinus)

(*val word160Mult : word160 -> word160 -> word160*)
let word160Mult:word160 ->word160 ->word160=  (word160BinOp bitSeqMult)

(*val word160IntegerDivision : word160 -> word160 -> word160*)
let word160IntegerDivision:word160 ->word160 ->word160=  (word160BinOp bitSeqDiv)

(*val word160Division : word160 -> word160 -> word160*)
let word160Division:word160 ->word160 ->word160=  (word160BinOp bitSeqDiv)

(*val word160Remainder : word160 -> word160 -> word160*)
let word160Remainder:word160 ->word160 ->word160=  (word160BinOp bitSeqMod)

(*val word160Land : word160 -> word160 -> word160*)
let word160Land:word160 ->word160 ->word160=  (word160BinOp bitSeqAnd)

(*val word160Lor : word160 -> word160 -> word160*)
let word160Lor:word160 ->word160 ->word160=  (word160BinOp bitSeqOr)

(*val word160Lxor : word160 -> word160 -> word160*)
let word160Lxor:word160 ->word160 ->word160=  (word160BinOp bitSeqXor)

(*val word160Min : word160 -> word160 -> word160*)
let word160Min:word160 ->word160 ->word160=  (word160BinOp (bitSeqMin))

(*val word160Max : word160 -> word160 -> word160*)
let word160Max:word160 ->word160 ->word160=  (word160BinOp (bitSeqMax))

(*val word160Power : word160 -> nat -> word160*)
let word160Power:word160 ->int ->word160=  (word160NatOp bitSeqPow)

(*val word160Asr : word160 -> nat -> word160*)
let word160Asr:word160 ->int ->word160=  (word160NatOp bitSeqArithmeticShiftRight)

(*val word160Lsr : word160 -> nat -> word160*)
let word160Lsr:word160 ->int ->word160=  (word160NatOp bitSeqLogicalShiftRight)

(*val word160Lsl : word160 -> nat -> word160*)
let word160Lsl:word160 ->int ->word160=  (word160NatOp bitSeqShiftLeft)


let instance_Num_NumNegate_Word160_word160_dict:(word160)numNegate_class= ({

  numNegate_method = word160Negate})

let instance_Num_NumAdd_Word160_word160_dict:(word160)numAdd_class= ({

  numAdd_method = word160Add})

let instance_Num_NumMinus_Word160_word160_dict:(word160)numMinus_class= ({

  numMinus_method = word160Minus})

let instance_Num_NumSucc_Word160_word160_dict:(word160)numSucc_class= ({

  succ_method = word160Succ})

let instance_Num_NumPred_Word160_word160_dict:(word160)numPred_class= ({

  pred_method = word160Pred})

let instance_Num_NumMult_Word160_word160_dict:(word160)numMult_class= ({

  numMult_method = word160Mult})

let instance_Num_NumPow_Word160_word160_dict:(word160)numPow_class= ({

  numPow_method = word160Power})

let instance_Num_NumIntegerDivision_Word160_word160_dict:(word160)numIntegerDivision_class= ({

  div_method = word160IntegerDivision})

let instance_Num_NumDivision_Word160_word160_dict:(word160)numDivision_class= ({

  numDivision_method = word160Division})

let instance_Num_NumRemainder_Word160_word160_dict:(word160)numRemainder_class= ({

  mod_method = word160Remainder})

let instance_Basic_classes_OrdMaxMin_Word160_word160_dict:(word160)ordMaxMin_class= ({

  max_method = word160Max;

  min_method = word160Min})

let instance_Word_WordNot_Word160_word160_dict:(word160)wordNot_class= ({

  lnot_method = word160Lnot})

let instance_Word_WordAnd_Word160_word160_dict:(word160)wordAnd_class= ({

  land_method = word160Land})

let instance_Word_WordOr_Word160_word160_dict:(word160)wordOr_class= ({

  lor_method = word160Lor})

let instance_Word_WordXor_Word160_word160_dict:(word160)wordXor_class= ({

  lxor_method = word160Lxor})

let instance_Word_WordLsl_Word160_word160_dict:(word160)wordLsl_class= ({

  lsl_method = word160Lsl})

let instance_Word_WordLsr_Word160_word160_dict:(word160)wordLsr_class= ({

  lsr_method = word160Lsr})

let instance_Word_WordAsr_Word160_word160_dict:(word160)wordAsr_class= ({

  asr_method = word160Asr})

