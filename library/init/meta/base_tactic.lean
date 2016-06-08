/-
Copyright (c) 2016 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
prelude
import init.monad init.meta.format
/-
Remark: we use a function that produces a format object as the exception information.
Motivation: the formatting object may be big, and we may create it on demand.
Remark: We use base_tactic_result to define base_tactic (a monad that combines the state an exceptional monads).
We "merge" them for performance reasons.
-/
inductive base_tactic_result (S : Type) (A : Type) :=
| success   : A → S → base_tactic_result S A
| exception : (options → format) → base_tactic_result S A

section
open base_tactic_result
variables {S A : Type}
variables [has_to_string A]

protected meta_definition base_tactic_result.to_string : base_tactic_result S A → string
| (success a s)   := to_string a
| (exception S A e) := "Exception: " + to_string (e options.mk)

protected meta_definition base_tactic_result.has_to_string [instance] : has_to_string (base_tactic_result S A) :=
has_to_string.mk base_tactic_result.to_string
end

meta_definition base_tactic [reducible] (S : Type) (A : Type) :=
S → base_tactic_result S A

namespace base_tactic
variables {S A B : Type}
open base_tactic_result

inline protected meta_definition fmap (f : A → B) (t : base_tactic S A) : base_tactic S B :=
λ s, base_tactic_result.cases_on (t s)
  (λ a s', success (f a) s')
  (λ e, !exception e)

inline protected meta_definition bind (t₁ : base_tactic S A) (t₂ : A → base_tactic S B) : base_tactic S B :=
λ s : S,  base_tactic_result.cases_on (t₁ s)
  (λ a s', t₂ a s')
  (λ e, !exception e)

inline protected meta_definition return (a : A) : base_tactic S A :=
λ s, success a s

end base_tactic

meta_definition base_tactic.is_monad [instance] (S : Type) : monad (base_tactic S) :=
monad.mk (@base_tactic.fmap S) (@base_tactic.return S) (@base_tactic.bind S)

namespace tactic
variables {S A : Type}
open base_tactic_result

meta_definition fail (e : format) : base_tactic S unit :=
λ s, !exception (λ u, e)

meta_definition try (t : base_tactic S A) : base_tactic S unit :=
λ s, base_tactic_result.cases_on (t s)
 (λ a, success unit.star)
 (λ e, success unit.star s)

meta_definition or_else (t₁ t₂ : base_tactic S A) : base_tactic S A :=
λ s, base_tactic_result.cases_on (t₁ s)
  success
  (λ e₁, base_tactic_result.cases_on (t₂ s)
     success
     (λ e₂, !exception (λ u, e₁ u + format.line + e₂ u)))

infix `<|>`:1 := or_else

meta_definition skip : base_tactic S unit :=
success unit.star

/- Decorate t's exceptions with msg -/
meta_definition decorate_ex (msg : format) (t : base_tactic S A) : base_tactic S A :=
λ s, base_tactic_result.cases_on (t s)
  success
  (λ e, !exception (λ u, msg + format.nest 2 (format.line + e u)))

inline meta_definition write (s' : S) : base_tactic S unit :=
λ s, success unit.star s'

inline meta_definition read : base_tactic S S :=
λ s, success s s
end tactic
