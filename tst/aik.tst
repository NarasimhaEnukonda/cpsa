(herald "Anonymous identity protocol from TCG")

(comment "CPSA 3.6.2")
(comment "All input read from aik.scm")

(defprotocol aikprot basic
  (defrole ca
    (vars (mf name) (ek akey))
    (trace (send (enc "ekc" mf ek (privk mf))))
    (non-orig (invk ek)))
  (defrole tpm
    (vars (i x mf pc name) (ek k akey) (srk skey))
    (trace (recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    (non-orig srk (invk ek))
    (uniq-orig k (invk k)))
  (defrole pca
    (vars (i x mf pc name) (ek k akey))
    (trace (recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    (non-orig (privk mf))))

(defskeleton aikprot
  (vars (mf pc i x name) (srk skey) (ek k akey))
  (defstrand tpm 4 (i i) (x x) (mf mf) (pc pc) (srk srk) (ek ek) (k k))
  (non-orig srk (invk ek) (privk pc))
  (uniq-orig k (invk k))
  (traces
    ((recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk)))))
  (label 0)
  (unrealized (0 2))
  (origs (k (0 1)) ((invk k) (0 3)))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (mf pc i x mf-0 name) (srk skey) (ek k ek-0 akey))
  (defstrand tpm 4 (i i) (x x) (mf mf) (pc pc) (srk srk) (ek ek) (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-0) (pc pc) (ek ek-0) (k k))
  (precedes ((0 1) (1 0)) ((1 1) (0 2)))
  (non-orig srk (invk ek) (privk pc) (privk mf-0))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (0 2))
  (traces
    ((recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-0 ek-0 (privk mf-0))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0))))
  (label 1)
  (parent 0)
  (unrealized (1 0))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (mf pc i x mf-0 name) (srk skey) (ek k ek-0 akey))
  (defstrand tpm 4 (i i) (x x) (mf mf) (pc pc) (srk srk) (ek ek) (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-0) (pc pc) (ek ek-0) (k k))
  (defstrand ca 1 (mf mf-0) (ek ek-0))
  (precedes ((0 1) (1 0)) ((1 1) (0 2)) ((2 0) (1 0)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf-0))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand ca 1)
    (enc "ekc" mf-0 ek-0 (privk mf-0)) (1 0))
  (traces
    ((recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-0 ek-0 (privk mf-0))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0)))
    ((send (enc "ekc" mf-0 ek-0 (privk mf-0)))))
  (label 2)
  (parent 1)
  (unrealized (0 2))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton aikprot
  (vars (mf pc i x mf-0 name) (srk skey) (k ek akey))
  (defstrand tpm 4 (i i) (x x) (mf mf) (pc pc) (srk srk) (ek ek) (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-0) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf-0) (ek ek))
  (precedes ((0 1) (1 0)) ((1 1) (0 2)) ((2 0) (1 0)))
  (non-orig srk (invk ek) (privk pc) (privk mf-0))
  (uniq-orig k (invk k))
  (operation encryption-test (contracted (ek-0 ek))
    (enc "aic" i k x (privk pc)) (0 2)
    (enc (enc "aic" i k x (privk pc)) ek))
  (traces
    ((recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf-0 ek (privk mf-0)))))
  (label 3)
  (parent 2)
  (unrealized)
  (shape)
  (maps ((0) ((mf mf) (pc pc) (i i) (x x) (ek ek) (k k) (srk srk))))
  (origs (k (0 1)) ((invk k) (0 3))))

(defskeleton aikprot
  (vars (mf pc i x mf-0 mf-1 name) (srk skey) (ek k ek-0 ek-1 akey))
  (defstrand tpm 4 (i i) (x x) (mf mf) (pc pc) (srk srk) (ek ek) (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-0) (pc pc) (ek ek-0) (k k))
  (defstrand ca 1 (mf mf-0) (ek ek-0))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek-1) (k k))
  (precedes ((0 1) (1 0)) ((0 1) (3 0)) ((1 1) (0 2)) ((2 0) (1 0))
    ((3 1) (0 2)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf-0)
    (privk mf-1))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (0 2)
    (enc (enc "aic" i k x (privk pc)) ek-0))
  (traces
    ((recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-0 ek-0 (privk mf-0))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0)))
    ((send (enc "ekc" mf-0 ek-0 (privk mf-0))))
    ((recv (cat i k x (enc "ekc" mf-1 ek-1 (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek-1))))
  (label 4)
  (parent 2)
  (seen 2)
  (unrealized (3 0))
  (comment "1 in cohort - 0 not yet seen"))

(comment "Nothing left to do")

(defprotocol aikprot basic
  (defrole ca
    (vars (mf name) (ek akey))
    (trace (send (enc "ekc" mf ek (privk mf))))
    (non-orig (invk ek)))
  (defrole tpm
    (vars (i x mf pc name) (ek k akey) (srk skey))
    (trace (recv (cat x i (enc "ekc" mf ek (privk mf))))
      (send (cat i k x (enc "ekc" mf ek (privk mf))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    (non-orig srk (invk ek))
    (uniq-orig k (invk k)))
  (defrole pca
    (vars (i x mf pc name) (ek k akey))
    (trace (recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    (non-orig (privk mf))))

(defskeleton aikprot
  (vars (i x pc name) (k akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (non-orig (privk pc))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc)))))
  (label 5)
  (unrealized (0 0))
  (origs)
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf name) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (precedes ((1 1) (0 0)))
  (non-orig (privk pc) (privk mf))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (0 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek))))
  (label 6)
  (parent 5)
  (unrealized (1 0))
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf name) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)))
  (non-orig (invk ek) (privk pc) (privk mf))
  (operation encryption-test (added-strand ca 1)
    (enc "ekc" mf ek (privk mf)) (1 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf)))))
  (label 7)
  (parent 6)
  (unrealized (0 0))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 name) (srk skey) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 3) (0 0)))
  (non-orig srk (invk ek) (privk pc) (privk mf))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand tpm 4)
    (enc "aic" i k x (privk pc)) (0 0)
    (enc (enc "aic" i k x (privk pc)) ek))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk)))))
  (label 8)
  (parent 7)
  (unrealized (3 2))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 name) (k ek ek-0 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand pca 2 (i i) (x x) (mf mf-0) (pc pc) (ek ek-0) (k k))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (0 0)))
  (non-orig (invk ek) (privk pc) (privk mf) (privk mf-0))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (0 0)
    (enc (enc "aic" i k x (privk pc)) ek))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat i k x (enc "ekc" mf-0 ek-0 (privk mf-0))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0))))
  (label 9)
  (parent 7)
  (seen 7)
  (unrealized (3 0))
  (comment "1 in cohort - 0 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 name) (srk skey) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (precedes ((1 1) (3 2)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 3) (0 0)))
  (non-orig srk (invk ek) (privk pc) (privk mf))
  (uniq-orig k (invk k))
  (operation encryption-test (displaced 4 1 pca 2)
    (enc "aic" i k x (privk pc)) (3 2))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk)))))
  (label 10)
  (parent 8)
  (unrealized)
  (shape)
  (maps ((0) ((i i) (x x) (pc pc) (k k))))
  (origs (k (3 1)) ((invk k) (3 3))))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek ek-0 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek-0) (k k))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 1) (4 0))
    ((3 3) (0 0)) ((4 1) (3 2)))
  (non-orig srk (invk ek) (privk pc) (privk mf) (privk mf-1))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (3 2))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek-0 (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0))))
  (label 11)
  (parent 8)
  (unrealized (4 0))
  (comment "2 in cohort - 2 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 name) (srk skey) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((2 0) (4 0)) ((3 1) (1 0))
    ((3 1) (4 0)) ((3 3) (0 0)) ((4 1) (3 2)))
  (non-orig srk (invk ek) (privk pc) (privk mf))
  (uniq-orig k (invk k))
  (operation encryption-test (displaced 5 2 ca 1)
    (enc "ekc" mf-1 ek-0 (privk mf-1)) (4 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek))))
  (label 12)
  (parent 11)
  (seen 10)
  (unrealized)
  (comment "1 in cohort - 0 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek ek-0 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek-0) (k k))
  (defstrand ca 1 (mf mf-1) (ek ek-0))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 1) (4 0))
    ((3 3) (0 0)) ((4 1) (3 2)) ((5 0) (4 0)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf)
    (privk mf-1))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand ca 1)
    (enc "ekc" mf-1 ek-0 (privk mf-1)) (4 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek-0 (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0)))
    ((send (enc "ekc" mf-1 ek-0 (privk mf-1)))))
  (label 13)
  (parent 11)
  (unrealized (3 2))
  (comment "3 in cohort - 3 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf-1) (ek ek))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 1) (4 0))
    ((3 3) (0 0)) ((4 1) (3 2)) ((5 0) (4 0)))
  (non-orig srk (invk ek) (privk pc) (privk mf) (privk mf-1))
  (uniq-orig k (invk k))
  (operation encryption-test (contracted (ek-0 ek))
    (enc "aic" i k x (privk pc)) (3 2)
    (enc (enc "aic" i k x (privk pc)) ek))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf-1 ek (privk mf-1)))))
  (label 14)
  (parent 13)
  (unrealized)
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek ek-0 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek-0) (k k))
  (defstrand ca 1 (mf mf-1) (ek ek-0))
  (precedes ((1 1) (3 2)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 1) (4 0))
    ((3 3) (0 0)) ((4 1) (3 2)) ((5 0) (4 0)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf)
    (privk mf-1))
  (uniq-orig k (invk k))
  (operation encryption-test (displaced 6 1 pca 2)
    (enc "aic" i k x (privk pc)) (3 2)
    (enc (enc "aic" i k x (privk pc)) ek-0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek-0 (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0)))
    ((send (enc "ekc" mf-1 ek-0 (privk mf-1)))))
  (label 15)
  (parent 13)
  (unrealized)
  (comment "1 in cohort - 1 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 mf-2 name) (srk skey)
    (k ek ek-0 ek-1 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek-0) (k k))
  (defstrand ca 1 (mf mf-1) (ek ek-0))
  (defstrand pca 2 (i i) (x x) (mf mf-2) (pc pc) (ek ek-1) (k k))
  (precedes ((1 1) (0 0)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 1) (4 0))
    ((3 1) (6 0)) ((3 3) (0 0)) ((4 1) (3 2)) ((5 0) (4 0))
    ((6 1) (3 2)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf) (privk mf-1)
    (privk mf-2))
  (uniq-orig k (invk k))
  (operation encryption-test (added-strand pca 2)
    (enc "aic" i k x (privk pc)) (3 2)
    (enc (enc "aic" i k x (privk pc)) ek-0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek-0 (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek-0)))
    ((send (enc "ekc" mf-1 ek-0 (privk mf-1))))
    ((recv (cat i k x (enc "ekc" mf-2 ek-1 (privk mf-2))))
      (send (enc (enc "aic" i k x (privk pc)) ek-1))))
  (label 16)
  (parent 13)
  (seen 13)
  (unrealized (6 0))
  (comment "1 in cohort - 0 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand pca 2 (i i) (x x) (mf mf-1) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf-1) (ek ek))
  (precedes ((1 0) (0 0)) ((2 1) (3 0)) ((2 3) (0 0)) ((3 1) (2 2))
    ((4 0) (3 0)))
  (non-orig srk (invk ek) (privk pc) (privk mf) (privk mf-1))
  (uniq-orig k (invk k))
  (operation generalization deleted (1 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((recv (cat i k x (enc "ekc" mf-1 ek (privk mf-1))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf-1 ek (privk mf-1)))))
  (label 17)
  (parent 14)
  (seen 10)
  (unrealized)
  (comment "1 in cohort - 0 not yet seen"))

(defskeleton aikprot
  (vars (i x pc mf mf-0 mf-1 name) (srk skey) (k ek ek-0 akey))
  (deflistener (enc "aic" i k x (privk pc)))
  (defstrand pca 2 (i i) (x x) (mf mf) (pc pc) (ek ek) (k k))
  (defstrand ca 1 (mf mf) (ek ek))
  (defstrand tpm 4 (i i) (x x) (mf mf-0) (pc pc) (srk srk) (ek ek)
    (k k))
  (defstrand ca 1 (mf mf-1) (ek ek-0))
  (precedes ((1 1) (3 2)) ((2 0) (1 0)) ((3 1) (1 0)) ((3 3) (0 0))
    ((4 0) (3 2)))
  (non-orig srk (invk ek) (invk ek-0) (privk pc) (privk mf)
    (privk mf-1))
  (uniq-orig k (invk k))
  (operation generalization deleted (4 0))
  (traces
    ((recv (enc "aic" i k x (privk pc)))
      (send (enc "aic" i k x (privk pc))))
    ((recv (cat i k x (enc "ekc" mf ek (privk mf))))
      (send (enc (enc "aic" i k x (privk pc)) ek)))
    ((send (enc "ekc" mf ek (privk mf))))
    ((recv (cat x i (enc "ekc" mf-0 ek (privk mf-0))))
      (send (cat i k x (enc "ekc" mf-0 ek (privk mf-0))))
      (recv (enc (enc "aic" i k x (privk pc)) ek))
      (send (cat (enc "aic" i k x (privk pc)) (enc k (invk k) srk))))
    ((send (enc "ekc" mf-1 ek-0 (privk mf-1)))))
  (label 18)
  (parent 15)
  (seen 10)
  (unrealized)
  (comment "1 in cohort - 0 not yet seen"))

(comment "Nothing left to do")
