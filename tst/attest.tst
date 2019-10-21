(herald attest-door)

(comment "CPSA 3.6.4")
(comment "All input read from attest.scm")

(defprotocol attest-door basic
  (defrole appraise
    (vars (d p a akey) (n text))
    (trace (recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    (comment "The appraiser for the door"))
  (defrole person
    (vars (d p a akey) (k skey) (n t text))
    (trace (send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    (uniq-orig n k)
    (comment "Person requesting door entry"))
  (defrole door
    (vars (d p akey) (k skey) (t text))
    (trace (recv (enc (enc k (invk p)) d)) (send (enc t k)) (recv t))
    (uniq-orig t))
  (defrole squealer
    (vars (d p akey) (k skey))
    (trace (recv (enc (enc k (invk p)) d)) (send k))
    (comment "Fake door"))
  (defrule yes
    (forall ((z strd) (a akey))
      (implies
        (and (p "appraise" z 2) (p "appraise" "a" z a) (non (invk a)))
        (exists ((d akey))
          (and (p "appraise" "d" z d) (non (invk d))))))
    (comment "Appraisal succeeded"))
  (comment "Door attestations protocol"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (non-orig (invk p) (invk a))
  (uniq-orig n k)
  (comment "Analyze from the person's perspective")
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t)))
  (label 0)
  (unrealized (0 1))
  (origs (n (0 0)) (k (0 2)))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (precedes ((0 0) (1 0)) ((1 1) (0 1)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (rule yes)
  (operation nonce-test (added-strand appraise 2) n (0 1)
    (enc (enc d n (invk p)) a))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p))))
  (label 1)
  (parent 0)
  (unrealized (0 3))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d d-0 p-0 akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand door 2 (t t) (k k) (d d-0) (p p-0))
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n t k)
  (operation encryption-test (added-strand door 2) (enc t k) (0 3))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p-0)) d-0)) (send (enc t k))))
  (label 2)
  (parent 1)
  (unrealized (2 0))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (deflistener k)
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (operation encryption-test (added-listener k) (enc t k) (0 3))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv k) (send k)))
  (label 3)
  (parent 1)
  (unrealized (2 0))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand door 2 (t t) (k k) (d d) (p p))
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n t k)
  (operation nonce-test (contracted (d-0 d) (p-0 p)) k (2 0)
    (enc (enc k (invk p)) d))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p)) d)) (send (enc t k))))
  (label 4)
  (parent 2)
  (unrealized)
  (shape)
  (maps ((0) ((p p) (a a) (d d) (k k) (n n) (t t))))
  (origs (t (2 1)) (n (0 0)) (k (0 2))))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d d-0 p-0 akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand door 2 (t t) (k k) (d d-0) (p p-0))
  (defstrand squealer 2 (k k) (d d) (p p))
  (precedes ((0 0) (1 0)) ((0 2) (3 0)) ((1 1) (0 1)) ((2 1) (0 3))
    ((3 1) (2 0)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n t k)
  (operation nonce-test (added-strand squealer 2) k (2 0)
    (enc (enc k (invk p)) d))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p-0)) d-0)) (send (enc t k)))
    ((recv (enc (enc k (invk p)) d)) (send k)))
  (label 5)
  (parent 2)
  (unrealized)
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (deflistener k)
  (defstrand squealer 2 (k k) (d d) (p p))
  (precedes ((0 0) (1 0)) ((0 2) (3 0)) ((1 1) (0 1)) ((2 1) (0 3))
    ((3 1) (2 0)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (operation nonce-test (added-strand squealer 2) k (2 0)
    (enc (enc k (invk p)) d))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv k) (send k)) ((recv (enc (enc k (invk p)) d)) (send k)))
  (label 6)
  (parent 3)
  (seen 7)
  (unrealized)
  (comment "1 in cohort - 0 not yet seen"))

(defskeleton attest-door
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand squealer 2 (k k) (d d) (p p))
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (operation generalization deleted (2 0))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p)) d)) (send k)))
  (label 7)
  (parent 5)
  (unrealized)
  (shape)
  (maps ((0) ((p p) (a a) (d d) (k k) (n n) (t t))))
  (origs (n (0 0)) (k (0 2))))

(comment "Nothing left to do")

(defprotocol attest-door-trust basic
  (defrole appraise
    (vars (d p a akey) (n text))
    (trace (recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    (comment "The appraiser for the door"))
  (defrole person
    (vars (d p a akey) (k skey) (n t text))
    (trace (send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    (uniq-orig n k)
    (comment "Person requesting door entry"))
  (defrole door
    (vars (d p akey) (k skey) (t text))
    (trace (recv (enc (enc k (invk p)) d)) (send (enc t k)) (recv t))
    (uniq-orig t))
  (defrole squealer
    (vars (d p akey) (k skey))
    (trace (recv (enc (enc k (invk p)) d)) (send k))
    (comment "Fake door"))
  (defrule yes
    (forall ((z strd) (a akey))
      (implies
        (and (p "appraise" z 2) (p "appraise" "a" z a) (non (invk a)))
        (exists ((d akey))
          (and (p "appraise" "d" z d) (non (invk d))))))
    (comment "Appraisal succeeded"))
  (defrule trust
    (forall ((z w strd) (d akey))
      (implies
        (and (p "appraise" z 2) (p "appraise" "d" z d)
          (p "squealer" w 2) (p "squealer" "d" w d))
        (false)))
    (comment "Squealer prohibited due to attestation"))
  (comment "Door attestations protocol with attestation"))

(defskeleton attest-door-trust
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (non-orig (invk p) (invk a))
  (uniq-orig n k)
  (comment "Analyze from the person's perspective")
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t)))
  (label 8)
  (unrealized (0 1))
  (origs (n (0 0)) (k (0 2)))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton attest-door-trust
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (precedes ((0 0) (1 0)) ((1 1) (0 1)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (rule yes)
  (operation nonce-test (added-strand appraise 2) n (0 1)
    (enc (enc d n (invk p)) a))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p))))
  (label 9)
  (parent 8)
  (unrealized (0 3))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton attest-door-trust
  (vars (n t text) (k skey) (p a d d-0 p-0 akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand door 2 (t t) (k k) (d d-0) (p p-0))
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n t k)
  (operation encryption-test (added-strand door 2) (enc t k) (0 3))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p-0)) d-0)) (send (enc t k))))
  (label 10)
  (parent 9)
  (unrealized (2 0))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton attest-door-trust
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (deflistener k)
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n k)
  (operation encryption-test (added-listener k) (enc t k) (0 3))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv k) (send k)))
  (label 11)
  (parent 9)
  (unrealized (2 0))
  (dead)
  (comment "empty cohort"))

(defskeleton attest-door-trust
  (vars (n t text) (k skey) (p a d akey))
  (defstrand person 5 (n n) (t t) (k k) (d d) (p p) (a a))
  (defstrand appraise 2 (n n) (d d) (p p) (a a))
  (defstrand door 2 (t t) (k k) (d d) (p p))
  (precedes ((0 0) (1 0)) ((0 2) (2 0)) ((1 1) (0 1)) ((2 1) (0 3)))
  (non-orig (invk p) (invk a) (invk d))
  (uniq-orig n t k)
  (operation nonce-test (contracted (d-0 d) (p-0 p)) k (2 0)
    (enc (enc k (invk p)) d))
  (traces
    ((send (enc (enc d n (invk p)) a)) (recv (enc n a p))
      (send (enc (enc k (invk p)) d)) (recv (enc t k)) (send t))
    ((recv (enc (enc d n (invk p)) a)) (send (enc n a p)))
    ((recv (enc (enc k (invk p)) d)) (send (enc t k))))
  (label 12)
  (parent 10)
  (unrealized)
  (shape)
  (maps ((0) ((p p) (a a) (d d) (k k) (n n) (t t))))
  (origs (t (2 1)) (n (0 0)) (k (0 2))))

(comment "Nothing left to do")
