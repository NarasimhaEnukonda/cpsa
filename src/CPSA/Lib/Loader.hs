-- Loads protocols and preskeletons from S-expressions.

-- Copyright (c) 2009 The MITRE Corporation
--
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the BSD License as published by the
-- University of California.

module CPSA.Lib.Loader (loadSExprs) where

import Control.Monad
import qualified Data.List as L
import CPSA.Lib.Utilities
import CPSA.Lib.SExpr
import CPSA.Lib.Algebra
import CPSA.Lib.AlgebraLibrary
import CPSA.Lib.Declaration
import CPSA.Lib.State
import CPSA.Lib.Protocol
import CPSA.Lib.Goal
import CPSA.Lib.Strand
import CPSA.Lib.Characteristic

{-- Debugging support
import CPSA.Lib.Debug
--}

-- Load protocols and preskeletons from a list of S-expressions, and
-- then return a list of preskeletons.  The name of the algebra is
-- nom, and its variable generator is provided.

loadSExprs :: (Algebra t p g s e c, Monad m) => String -> g ->
              [SExpr Pos] -> m [Preskel t g s e]
loadSExprs nom origin xs =
    do
      (_, ks) <- foldM (loadSExpr nom origin) ([], []) xs
      return (reverse ks)

loadSExpr :: (Algebra t p g s e c, Monad m) => String -> g ->
             ([Prot t g], [Preskel t g s e]) -> SExpr Pos ->
             m ([Prot t g], [Preskel t g s e])
loadSExpr nom origin (ps, ks) (L pos (S _ "defprotocol" : xs)) =
    do
      p <- loadProt nom origin pos xs
      return (p : ps, ks)
loadSExpr _ _ (ps, ks) (L pos (S _ "defskeleton" : xs)) =
    do
      k <- findPreskel pos ps xs
      return (ps, k : ks)
loadSExpr _ _ (ps, ks) (L pos (S _ "defgoal" : xs)) =
    do
      k <- findGoal pos ps xs
      return (ps, k : ks)
loadSExpr nom origin (ps, ks) (L pos (S pos' "defpreskeleton" : xs)) =
    loadSExpr nom origin (ps, ks) (L pos (S pos' "defskeleton" : xs))
loadSExpr _ _ (ps, ks) (L _ (S _ "comment" : _)) = return (ps, ks)
loadSExpr _ _ (ps, ks) (L _ (S _ "herald" : _)) = return (ps, ks)
loadSExpr _ _ _ x = fail (shows (annotation x) "Malformed input")

-- load a protocol

loadProt :: (Algebra t p g s e c, Monad m) => String -> g ->
            Pos -> [SExpr Pos] -> m (Prot t g)
loadProt nom origin pos (S _ name : S _ alg : x : xs)
    | alg /= nom =
        fail (shows pos $ "Expecting terms in algebra " ++ nom)
    | otherwise =
        do
          (gen, rs, comment) <- loadRoles origin (x : xs)
          -- Check for duplicate role names
          (gen, r) <- mkListenerRole pos gen
          validate (mkProt name alg gen rs r comment) rs
    where
      validate prot [] = return prot
      validate prot (r : rs) =
          case L.find (\r' -> rname r == rname r') rs of
            Nothing -> validate prot rs
            Just _ ->
                let msg = "Duplicate role " ++ rname r ++
                          " in protocol " ++ name in
                fail (shows pos msg)
loadProt _ _ pos _ = fail (shows pos "Malformed protocol")

loadRoles :: (Algebra t p g s e c, Monad m) => g -> [SExpr Pos] ->
             m (g, [Role t], [SExpr ()])
loadRoles gen (L pos (S _ "defrole" : x) : xs) =
    do
      (gen, r) <- loadRole gen pos x
      (gen, rs, comment) <- loadRoles gen xs
      return (gen, r : rs, comment)
loadRoles gen xs =
    do
      comment <- alist [] xs    -- Ensure remaining is an alist
      return (gen, [], comment)

loadRole :: (Algebra t p g s e c, Monad m) => g -> Pos ->
            [SExpr Pos] -> m (g, Role t)
loadRole gen pos (S _ name :
                  L _ (S _ "vars" : vars) :
                  L _ (S _ "trace" : evt : c) :
                  rest) =
    do
      (gen, vars) <- loadVars gen vars
      c <- loadTrace vars (evt : c)

      let ts = tterms c
      -- Drop unused variable declarations
      let vs = L.filter (\v->elem v (varsInTerms ts)) vars

      others <- loadGenRoleDecls (length c) vars (assocDecls rest)
      predefs <- loadAllPredefRoleDecls (length c) vars rest

      let dlist = filterVarsSeen (varsSeen vs) $ predefs ++ others
      comment <- alist (map fst declFormats) rest
      let reverseSearch = hasKey "reverse-search" rest
      case termsWellFormed ((termsInDlist predefs) ++ ts ++ (termsInDlist others)) of
        False -> fail (shows pos "Terms in role not well formed")
        True -> return ()
      prios <- mapM (loadRolePriority (length c)) (assoc "priority" rest)
      let r = mkRole name vs c dlist prios comment reverseSearch
      case roleWellFormed r of
        Return () -> return (gen, r)
        Fail msg -> fail (shows pos $ showString "Role not well formed: " msg)
    where
      termsInDlist olist = concat $ map dterms (concatMap snd olist)
      filterVarsSeen tst olist =
        map (\ (name,dlist) -> (name, filter (\ dinst -> all tst (dterms dinst))
                                      dlist)) olist

loadRole _ pos _ = fail (shows pos "Malformed role")

loadAllPredefRoleDecls :: (Algebra t p g s e c, Monad m) => Int -> [t] ->
                          [SExpr Pos] -> m [RoleDeclaration t]
loadAllPredefRoleDecls height vars exprs =
    do
      let formats = map (\ (tag, (i,_)) -> (tag, declInputFormats !! i)) declFormats
      result <- concatMapM (\ i -> loadPredefRoleDeclsAux height vars
                                   (fst $ formats !! i) (snd $ formats !! i)
                                   (assoc (fst $ formats !! i) exprs))
                (nats (length formats))
      return result

loadAllPredefSkelDecls :: (Algebra t p g s e c, Monad m) => [Int] -> [t] ->
                          [SExpr Pos] -> m ([SkelDeclaration t])
loadAllPredefSkelDecls heights vars exprs =
    do
      let formats = map (\ (tag, (i,_)) -> (tag, declInputFormats !! i)) declFormats
      result <- concatMapM (\ i -> loadPredefSkelDeclsAux heights vars
                                   (fst $ formats !! i)
                                   (snd $ formats !! i)
                                   (assoc (fst $ formats !! i) exprs))
                (nats (length formats))
      return result

loadPredefRoleDeclsAux :: (Algebra t p g s e c, Monad m) => Int -> [t] -> String ->
                       (DeclInFormat, Bool, Bool) ->
                       [SExpr Pos] -> m [(RoleDeclaration t)]
loadPredefRoleDeclsAux _ _ _ _ [] = do return []
loadPredefRoleDeclsAux height vars tag (fmt,areq,False) exprs =
    do (tg,insts) <- loadPredefRoleDecls height vars tag "" fmt areq exprs
       case (null insts) of
         True -> return []
         False -> return [(tg,insts)]
loadPredefRoleDeclsAux height vars tag (fmt,areq,True)
    ((L _ (S _ subtag:rest)):others) =
    do
        f <- loadPredefRoleDecls height vars tag subtag fmt areq rest
        r <- loadPredefRoleDeclsAux height vars tag (fmt,areq,True) others
        return [(fst f, ((snd f)++(concat $ map snd r)))]
loadPredefRoleDeclsAux height vars tag (fmt,areq,True)
    ((L pos1 ((Q pos subtag):rest)):others) =
    do
       r <- loadPredefRoleDeclsAux height vars tag (fmt,areq,True)
             ((L pos1 ((S pos ("\"" ++ subtag ++ "\"")):rest)):others)
       return r
loadPredefRoleDeclsAux _ _ _ _ (x@(L _ ((N _ _):_)):_) =
    fail (shows (annotation x) ("Malformed declaration: symbol or string subtag expected"))
loadPredefRoleDeclsAux _ _ tag _ (x:_) =
    fail (shows (annotation x) ("Malformed declaration: subtag required " ++ tag))

loadPredefSkelDeclsAux :: (Algebra t p g s e c, Monad m) => [Int] -> [t] -> String ->
                       (DeclInFormat, Bool, Bool) ->
                       [SExpr Pos] -> m [(SkelDeclaration t)]
loadPredefSkelDeclsAux _ _ _ _ [] = do return []
loadPredefSkelDeclsAux height vars tag (fmt,areq,False) exprs =
    do (tg,insts) <- loadPredefSkelDecls height vars tag "" fmt areq exprs
       case (null insts) of
         True -> return []
         False -> return [(tg,insts)]
loadPredefSkelDeclsAux height vars tag (fmt,areq,True)
    ((L _ (S _ subtag:rest)):others) =
    do
        f <- loadPredefSkelDecls height vars tag subtag fmt areq rest
        r <- loadPredefSkelDeclsAux height vars tag (fmt,areq,True) others
        return [(fst f, ((snd f)++(concat $ map snd r)))]
loadPredefSkelDeclsAux height vars tag (fmt,areq,True)
    ((L pos1 ((Q pos subtag):rest)):others) =
    do r <- loadPredefSkelDeclsAux height vars tag (fmt,areq,True)
             ((L pos1 ((S pos ("\"" ++ subtag ++ "\"")):rest)):others)
       return r
loadPredefSkelDeclsAux _ _ _ _ (x@(L _ ((N _ _):_)):_) =
    fail (shows (annotation x) ("Malformed declaration: symbol or string subtag expected"))
loadPredefSkelDeclsAux _ _ tag _ (x:_) =
     fail (shows (annotation x) ("Malformed declaration: subtag required " ++ tag))
-- loadPredefSkelDeclsAux _ _ _ (_,_,True) _ = do return []

loadPredefRoleDecls :: (Algebra t p g s e c, Monad m) => Int -> [t] -> String ->
                       String -> DeclInFormat -> Bool ->
                       [SExpr Pos] -> m (RoleDeclaration t)
-- Anything with no expressions: not present, return an empty list of instances.
loadPredefRoleDecls _ _ tag _ _ _ [] = do return (tag,[])
-- NullInFmt: return an empty instance.
loadPredefRoleDecls _ _ tag stag NullInFmt _ _ =
   return (tag, [declInstAux [] [] stag])
-- BasicInFmt, True format: get (Maybe Int, t) pairs, then reform.
loadPredefRoleDecls height vars tag stag BasicInFmt True exprs =
    do
       -- Note: since areq = True, appropriate to use loadPosBaseTerms.
       result <- loadPosBaseTerms vars exprs
       return (tag, filter (\ di -> (all (< height) (dlocs di)) &&
                                    (all (>= 0) (dlocs di))) $ map f result)
    where
       f (Nothing, t) = declInstAux [t] [] stag
       f (Just p, t) = declInstAux [t] [p] stag
-- TwoTermInFmt, False format
loadPredefRoleDecls height vars tag stag TwoTermInFmt False (x1:rest) =
    do
       inst1 <- loadRoleTermPairPlusMaybeOneLoc height vars stag x1
       (tg, insts) <- loadPredefRoleDecls height vars tag stag
                      TwoTermInFmt False rest
       return (tg, (inst1:insts))
-- MultiTermInFmt, False format: load as generic, but
-- check max locations = 1
loadPredefRoleDecls height vars tag stag MultiTermInFmt False (x1:rest) =
    do
       dinst <- loadGenRoleDecl height vars stag x1
       (tg, insts) <- loadPredefRoleDecls height vars tag
                      stag MultiTermInFmt False rest
       case (length (dlocs dinst) > 1) of
         True -> fail (shows (annotation x1) "Too many locations in declaration")
         False -> return (tg, (dinst:insts))
-- Default: not supported.
loadPredefRoleDecls _ _ _ _ _ _ xs =
    if (null xs)
       then fail ("[ASSERT FAILED] Input format not supported")
       else fail (shows (annotation (head xs)) "[ASSERT FAILED] Input format not supported")

loadPredefSkelDecls :: (Algebra t p g s e c, Monad m) => [Int] -> [t] -> String ->
                       String -> DeclInFormat -> Bool ->
                       [SExpr Pos] -> m (SkelDeclaration t)
-- Anything with no expressions: not present, return an empty list of instances.
loadPredefSkelDecls _ _ tag _ _ _ [] = return (tag,[])
-- NullInFmt format: return an empty instance.
loadPredefSkelDecls _ _ tag stag NullInFmt _ _ =
   return (tag, [declInstAux [] [] stag])
-- BasicInFmt, True format: get (Maybe Int, t) pairs, then reform.
loadPredefSkelDecls _ vars tag stag BasicInFmt True exprs =
    do
       -- Note: since areq = True, appropriate to use loadBaseTerms.
       result <- loadBaseTerms vars exprs
       return (tag, map f result)
    where
       f t = declInstAux [t] [] stag
-- TwoTermInFmt, False format
loadPredefSkelDecls heights vars tag stag TwoTermInFmt False (x1:rest) =
    do
       inst1 <- loadSkelTermPair vars stag x1
       (tg, insts) <- loadPredefSkelDecls heights vars tag stag
                      TwoTermInFmt False rest
       return (tg, (inst1:insts))
-- (Just 2, Nothing), Nothing, False format: load as generic, but
-- check max locations = 1
loadPredefSkelDecls heights vars tag stag MultiTermInFmt False (x1:rest) =
    do
       dinst <- loadGenSkelDecl heights vars stag x1
       (tg, insts) <- loadPredefSkelDecls heights vars tag stag MultiTermInFmt
                      False rest
       case (length (dlocs dinst) > 1) of
         True -> fail (shows (annotation x1) "Too many locations in declaration")
         False -> return (tg, (dinst:insts))
-- Default: not supported.
loadPredefSkelDecls _ _ _ _ _ _ xs =
    if (null xs)
       then fail ("[ASSERT FAILED] Input format not supported")
       else fail (shows (annotation (head xs)) "[ASSERT FAILED] Input format not supported")

loadRoleTermPairPlusMaybeOneLoc :: (Algebra t p g s e c, Monad m) => Int ->
                                   [t] -> String ->
                                   SExpr Pos -> m (RoleDeclInst t)
loadRoleTermPairPlusMaybeOneLoc _ vars stag (L _ [x1, x2]) =
    do
       t1 <- loadTerm vars False x1
       t2 <- loadTerm vars False x2
       return (declInstAux [t1,t2] [] stag)
loadRoleTermPairPlusMaybeOneLoc height vars stag (L _ [x1, x2, x3]) =
    do
       t1 <- loadTerm vars False x1
       t2 <- loadTerm vars False x2
       p <- loadIntMax height x3
       return (declInstAux [t1,t2] [p] stag)
loadRoleTermPairPlusMaybeOneLoc _ _ _ _ = fail ("Malformed pair of terms")

loadSkelTermPair :: (Algebra t p g s e c, Monad m) => [t] -> String ->
                                   SExpr Pos -> m (SkelDeclInst t)
loadSkelTermPair vars stag (L _ [x1, x2]) =
    do
       t1 <- loadTerm vars False x1
       t2 <- loadTerm vars False x2
       return (declInstAux [t1,t2] [] stag)
loadSkelTermPair _ _ _ = fail ("Malformed pair of terms")

loadRolePriority :: Monad m => Int -> SExpr Pos -> m (Int, Int)
loadRolePriority n (L _ [N _ i, N _ p])
    | 0 <= i && i < n = return (i, p)
loadRolePriority _ x = fail (shows (annotation x) "Malformed priority")

-- Are the vars in t a subset of ones in t.
varsSeen :: Algebra t p g s e c => [t] -> t -> Bool
varsSeen vs t =
    all (flip elem vs) (addVars [] t)

showst :: Algebra t p g s e c => t -> ShowS
showst t =
    shows $ displayTerm (addToContext emptyContext [t]) t

-- This is the only place a role is generated with an empty name.
-- This is what marks a strand as a listener.
mkListenerRole :: (Algebra t p g s e c, Monad m) => Pos -> g -> m (g, Role t)
mkListenerRole pos g =
  do
    (g, [x]) <- loadVars g [L pos [S pos "x", S pos "mesg"]]
    return (g, mkRole "" [x] [In x, Out x] [] [] [] False)

-- Association lists

-- Make an association list into a comment.  The first argument is the
-- set of keys of key-value pairs to be dropped from the comment.

alist :: Monad m => [String] -> [SExpr Pos] -> m [SExpr ()]
alist _ [] = return []
alist keys (a@(L _ (S _ key : _)) : xs)
    | elem key keys = alist keys xs
    | otherwise =
        do
          xs <- alist keys xs
          return $ strip a : xs
alist _ xs = fail (shows (annotation $ head xs) "Malformed association list")

-- Strip positions from an S-expression

strip :: SExpr a -> SExpr ()
strip (S _ s) = S () s
strip (Q _ s) = Q () s
strip (N _ n) = N () n
strip (L _ l) = L () (map strip l)

-- Lookup value in alist, appending values with the same key
assoc :: String -> [SExpr a] -> [SExpr a]
assoc key alist =
    concat $ assocAux key alist

-- Lookup value in alist
assocAux :: String -> [SExpr a] -> [[SExpr a]]
assocAux key alist =
    [ rest | L _ (S _ head : rest) <- alist, key == head ]

-- See if alist has a key
hasKey :: String -> [SExpr a] -> Bool
hasKey key alist =
    any f alist
    where
      f (L _ (S _ head : _)) = head == key
      f _ = False

loadTrace :: (Algebra t p g s e c, Monad m) => [t] ->
             [SExpr Pos] -> m [Event t]
loadTrace vars xs = mapM (loadEvt vars) xs

loadEvt :: (Algebra t p g s e c, Monad m) => [t] ->
          SExpr Pos -> m (Event t)
loadEvt vars (L _ [S _ "recv", t]) =
    do
      t <- loadTerm vars True t
      return (In t)
loadEvt vars (L _ [S _ "send", t]) =
    do
      t <- loadTerm vars True t
      return (Out t)
loadEvt vars (L _ [S _ "tran", t0, t1]) =
    do
      t0 <- loadTerm vars True t0
      t1 <- loadTerm vars True t1
      return $ Sync $ Tran (Just t0, Just t1, Nothing)
loadEvt vars (L _ [S _ "tran", t0, t1, t2]) =
    do
      t0 <- loadTerm vars True t0
      t1 <- loadTerm vars True t1
      t2 <- loadTerm vars True t2
      return $ Sync $ Tran (Just t0, Just t1, Just t2)
loadEvt vars (L _ [S _ "obsv", t0]) =
    do
      t0 <- loadTerm vars True t0
      return $ Sync $ Tran (Just t0, Nothing, Nothing)
loadEvt vars (L _ [S _ "obsv", t0, t1]) =
    do
      t0 <- loadTerm vars True t0
      t1 <- loadTerm vars True t1
      return $ Sync $ Tran (Just t0, Nothing, Just t1)
loadEvt vars (L _ [S _ "init", t0]) =
    do
      t0 <- loadTerm vars True t0
      return $ Sync $ Tran (Nothing, Just t0, Nothing)
loadEvt vars (L _ [S _ "init", t0, t1]) =
    do
      t0 <- loadTerm vars True t0
      t1 <- loadTerm vars True t1
      return $ Sync $ Tran (Nothing, Just t0, Just t1)
loadEvt _ (L pos [S _ dir, _]) =
    fail (shows pos $ "Malformed direction: " ++ dir)
loadEvt _ x = fail (shows (annotation x) "Malformed direction")

loadBaseTerms :: (Algebra t p g s e c, Monad m) => [t] -> [SExpr Pos] -> m [t]
loadBaseTerms _ [] = return []
loadBaseTerms vars (x : xs) =
    do
      t <- loadBaseTerm vars x
      ts <- loadBaseTerms vars xs
      return (adjoin t ts)

maybeLoadBaseTerm :: (Algebra t p g s e c, Monad m) => [t] -> SExpr Pos -> m (Maybe t)
maybeLoadBaseTerm vars x =
    do
      t <- loadTerm vars False x
      case isAtom t of
         True -> return (Just t)
         False -> return Nothing

loadBaseTerm :: (Algebra t p g s e c, Monad m) => [t] -> SExpr Pos -> m t
loadBaseTerm vars x =
    do
      mt <- maybeLoadBaseTerm vars x
      case mt of
        Just t -> return t
        Nothing -> fail (shows (annotation x) "Expecting an atom")

loadPosBaseTerms :: (Algebra t p g s e c, Monad m) => [t] ->
                    [SExpr Pos] -> m [(Maybe Int, t)]
loadPosBaseTerms _ [] = return []
loadPosBaseTerms vars (x : xs) =
    do
      t <- loadPosBaseTerm vars x
      ts <- loadPosBaseTerms vars xs
      return (t:ts)

loadPosBaseTerm :: (Algebra t p g s e c, Monad m) => [t] ->
                   SExpr Pos -> m (Maybe Int, t)
loadPosBaseTerm vars x'@(L _ [x, N _ opos])
    | opos < 0 =
        fail (shows (annotation x')
              "Expecting a non-negative trace length")
    | otherwise =
        do
          t <- loadBaseTerm vars x
          return (Just opos, t)
loadPosBaseTerm vars x =
    do
      t <- loadTerm vars False x
      case isAtom t of
        True -> return (Nothing, t)
        False -> fail (shows (annotation x) "Expecting an atom")

-- Find protocol and then load a preskeleton.

findPreskel :: (Algebra t p g s e c, Monad m) => Pos ->
               [Prot t g] -> [SExpr Pos] ->
               m (Preskel t g s e)
findPreskel pos ps (S _ name : xs) =
    case L.find (\p -> name == pname p) ps of
      Nothing -> fail (shows pos $ "Protocol " ++ name ++ " unknown")
      Just p -> loadPreskel pos p xs
findPreskel pos _ _ = fail (shows pos "Malformed skeleton")

loadPreskel :: (Algebra t p g s e c, Monad m) => Pos ->
               Prot t g -> [SExpr Pos] ->
               m (Preskel t g s e)
loadPreskel pos p (L _ (S _ "vars" : vars) : xs) =
    do
      (gen, kvars) <- loadVars (pgen p) vars
      loadInsts pos p kvars gen [] xs
loadPreskel pos _ _ = fail (shows pos "Malformed skeleton")

loadInsts :: (Algebra t p g s e c, Monad m) => Pos ->
             Prot t g -> [t] -> g -> [Instance t e] ->
             [SExpr Pos] -> m (Preskel t g s e)
loadInsts top p kvars gen insts (L pos (S _ "defstrand" : x) : xs) =
    case x of
      S _ role : N _ height : env ->
          do
            (gen, i) <- loadInst pos p kvars gen role height env
            loadInsts top p kvars gen (i : insts) xs
      _ ->
          fail (shows pos "Malformed defstrand")
loadInsts top p kvars gen insts (L pos (S _ "deflistener" : x) : xs) =
    case x of
      [term] ->
          do
            (gen, i) <- loadListener p kvars gen term
            loadInsts top p kvars gen (i : insts) xs
      _ ->
          fail (shows pos "Malformed deflistener")
loadInsts top p kvars gen insts xs =
    do
      _ <- alist [] xs          -- Check syntax of xs
      others <- loadGenSkelDecls heights kvars (assocDecls xs)
      predefs <- loadAllPredefSkelDecls heights kvars xs
      priorities <- loadPriorities (assoc "priority" xs) insts'
      (gen, gs) <- loadGoals top p gen goals
      loadRest top p gs gen insts' order leadsto
        (predefs ++ others) kcomment priorities
    where
      insts' = reverse insts
      heights = map (\ inst -> length $ trace inst) insts'
      order = assoc "precedes" xs
      leadsto = assoc "leadsto" xs
      goals = assoc "goals" xs
      kcomment =
        loadComment "subgoals" goals ++
        loadComment "comment" (assoc "comment" xs)

loadComment :: String -> [SExpr Pos] -> [SExpr ()]
loadComment _ [] = []
loadComment key comment =
  [L () (S () key : map strip comment)]

loadPriorities :: (Algebra t p g s e c, Monad m) => [SExpr Pos] ->
                  [Instance t e] -> m [((Int,Int),Int)]
loadPriorities [] _ = return []
loadPriorities ((L pos [L _ [N _ s, N _ i], N _ p]) : rest) insts
    | (s < 0 || s >= (length insts) || (i < 0) || (i > height (insts !! s))) =
      fail (shows pos "Malformed node in priority declaration")
    | otherwise =
        case trace (insts !! s) !! i of
          Out _ -> fail (shows pos "Priority declaration disallowed on sending")
          Sync (Tran (Nothing, _, _))
            -> fail (shows pos
                     "Priority declaration disallowed on initializers")
          _ -> do
            others <- loadPriorities rest insts
            return (((s,i),p) : others)
loadPriorities (x : _) _ = fail (shows (annotation x) "Malformed priority")

-- Lookup value in alist, appending values with the same key
assocDecls :: [SExpr a] -> [(String,[SExpr a])]
assocDecls alist =
    [("decl " ++ key, concat [ rest | L _ (S _ head : (S _ head' : rest)) <- alist,
                    "decl" == head, key == head' ]) | key <- keys]
    where
      keys = [ key | L _ (S _ head : (S _ key : _)) <- alist, head=="decl" ]

loadInst :: (Algebra t p g s e c, Monad m) => Pos ->
            Prot t g -> [t] -> g -> String -> Int ->
            [SExpr Pos] -> m (g, Instance t e)
loadInst pos p kvars gen role height env =
    do
      r <- lookupRole pos p role
      case height < 1 || height > length (rtrace r) of
        True -> fail (shows pos "Bad height")
        False ->
            do
              let vars = rvars r
              (gen', env') <- foldM (loadMaplet kvars vars) (gen, emptyEnv) env
              return (mkInstance gen' r env' height)

lookupRole :: Monad m => Pos -> Prot t g -> String -> m (Role t)
lookupRole _ p role  | role == "" =
    return $ listenerRole p
lookupRole pos p role =
    case L.find (\r -> role == rname r) (roles p) of
      Nothing ->
          fail (shows pos $ "Role " ++ role ++ " not found in " ++ pname p)
      Just r -> return r

loadMaplet :: (Algebra t p g s e c, Monad m) => [t] -> [t] ->
              (g, e) -> SExpr Pos -> m (g, e)
loadMaplet kvars vars env (L pos [domain, range]) =
    do
      t <- loadTerm vars False domain
      t' <- loadTerm kvars False range
      case match t t' env of
        env' : _ -> return env'
        [] -> fail (shows pos "Domain does not match range")
loadMaplet _ _ _ x = fail (shows (annotation x) "Malformed maplet")

loadListener :: (Algebra t p g s e c, Monad m) => Prot t g ->
                [t] -> g -> SExpr Pos -> m (g, Instance t e)
loadListener p kvars gen x =
    do
      t <- loadTerm kvars True x
      return $ mkListener p gen t

loadRest :: (Algebra t p g s e c, Monad m) => Pos ->
            Prot t g -> [Goal t] -> g -> [Instance t e] ->
            [SExpr Pos] -> [SExpr Pos] -> SkelDeclList t ->
            [SExpr ()] -> [((Int,Int),Int)] -> m (Preskel t g s e)
loadRest pos p gs gen insts orderings leadsto decls comment priorities =
    do
      case null insts of
        True -> fail (shows pos "No strands")
        False -> return ()
      let heights = map height insts
      o <- loadOrderings heights orderings True
      l <- loadOrderings heights leadsto False
      let k = mkPreskel gen p gs insts o l decls comment priorities
      case termsWellFormed $ (termsInDlist decls) ++ kterms k of
        True -> return ()
        False -> fail (shows pos "Terms in skeleton not well formed:" ++ show (termsInDlist decls ++ kterms k))
      case verbosePreskelWellFormed k of
        Return () -> return k
        Fail msg -> fail $ shows pos
                    $ showString "Skeleton not well formed: " msg

      where
        termsInDlist olist = concat $ map dterms (concatMap snd olist)

loadGenSkelDecls :: (Algebra t p g s e c, Monad m) => [Int] -> [t] ->
                    [(String,[SExpr Pos])] -> m [SkelDeclaration t]
loadGenSkelDecls _ _ [] = return []
loadGenSkelDecls heights vars ((name,rawds):b) =
    do
      a' <- loadGenSkelDeclList heights vars rawds
      b' <- loadGenSkelDecls heights vars b
      return ((name,a'):b')

loadGenSkelDeclList :: (Algebra t p g s e c, Monad m) => [Int] -> [t] -> [SExpr Pos] ->
                       m (SkelDeclInstList t)
loadGenSkelDeclList _ _ [] = return []
loadGenSkelDeclList heights vars (a:b) =
    do
      a' <- loadGenSkelDecl heights vars "" a
      b' <- loadGenSkelDeclList heights vars b
      return (a':b')

loadGenSkelDecl :: (Algebra t p g s e c, Monad m) => [Int] -> [t] -> String ->
                   SExpr Pos -> m (SkelDeclInst t)
loadGenSkelDecl heights vars stag (L _ (tlist:llist)) =
    do
      ts <- loadTerms vars tlist
      ls <- loadNodes heights llist
      return (declInstAux ts ls stag)
loadGenSkelDecl _ _ _ x'@(L _ []) =
    fail (shows (annotation x') "Malformed declaration: Expecting a list of terms in generic declaration")
loadGenSkelDecl _ _ _ x =
    fail (shows (annotation x) "Malformed declaration: expecting a list")

loadGenRoleDecls :: (Algebra t p g s e c, Monad m) => Int -> [t] ->
                    [(String,[SExpr Pos])] -> m [RoleDeclaration t]
loadGenRoleDecls _ _ [] = return []
loadGenRoleDecls height vars ((name,rawds):b) =
    do
      a' <- loadGenRoleDeclList height vars rawds
      b' <- loadGenRoleDecls height vars b
      return ((name,a'):b')

loadGenRoleDeclList :: (Algebra t p g s e c, Monad m) => Int -> [t] -> [SExpr Pos] ->
                       m (RoleDeclInstList t)
loadGenRoleDeclList _ _ [] = return []
loadGenRoleDeclList height vars (a:b) =
    do
      a' <- loadGenRoleDecl height vars "" a
      b' <- loadGenRoleDeclList height vars b
      return (a':b')

loadGenRoleDecl :: (Algebra t p g s e c, Monad m) => Int -> [t] -> String ->
                   SExpr Pos -> m (RoleDeclInst t)
loadGenRoleDecl height vars stag (L _ (tlist:llist)) =
    do
      ts <- loadTerms vars tlist
      ls <- loadIntsMax height llist
      return (declInstAux ts ls stag)
loadGenRoleDecl _ _ _ x'@(L _ []) =
    fail (shows (annotation x') "Malformed declaration: Expecting a list of terms in generic declaration")
loadGenRoleDecl _ _ _ x =
    fail (shows (annotation x) "Malformed declaration: expecting a list")

loadOrderings :: Monad m => [Int] -> [SExpr Pos] -> Bool -> m [Pair]
loadOrderings heights x strict =
    foldM f [] x
    where
      f ns x =
          do
            np <- loadPair heights x strict
            return (adjoin np ns)

loadPair :: Monad m => [Int] -> SExpr Pos -> Bool -> m Pair
loadPair heights (L pos [x0, x1]) strict =
    do
      n0 <- loadNode heights x0
      n1 <- loadNode heights x1
      case (strict && sameStrands n0 n1) of  -- Same strand
        True -> fail (shows pos "Malformed pair -- nodes in same strand")
        False -> return (n0, n1)
    where
      sameStrands (s0, _) (s1, _) = s0 == s1
loadPair _ x _ = fail (shows (annotation x) "Malformed pair")

loadTerms :: (Algebra t p g s e c, Monad m) => [t] -> SExpr Pos -> m [t]
loadTerms _ (L _ []) = return []
loadTerms vars (L pos (head:rest)) =
    do
      a <- loadTerm vars False head
      b <- loadTerms vars (L pos rest)
      return (a:b)
loadTerms _ x = fail (shows (annotation x) "Malformed list of terms")

loadNodes :: Monad m => [Int] -> [SExpr Pos] -> m [Node]
loadNodes _ [] = return []
loadNodes heights (head:rest) =
    do
      b <- loadNodes heights rest
      a <- loadNode heights head
      return (a:b)

loadIntsMax :: Monad m => Int -> [SExpr Pos] -> m [Int]
loadIntsMax _ [] = return []
loadIntsMax max (a:b) =
    do
      a <- loadIntMax max a
      b <- loadIntsMax max b
      return (a:b)

loadIntMax :: Monad m => Int -> SExpr Pos -> m Int
loadIntMax max (N pos x)
    | x < 0 = fail (shows pos "Malformed declaration: Negative position in role")
    | x >= max = fail (shows pos "Malformed declaration: Bad position in role")
    | otherwise = return x
loadIntMax _ x = fail (shows (annotation x) "Malformed declaration: position")

loadNode :: Monad m => [Int] -> SExpr Pos -> m Node
loadNode heights (L pos [N _ s, N _ p])
    | s < 0 = fail (shows pos "Malformed node: Negative strand in node")
    | p < 0 = fail (shows pos "Malformed node: Negative position in node")
    | otherwise =
        case height heights s of
          Nothing -> fail (shows pos "Malformed node: Bad strand in node")
          Just h | p < h -> return (s, p)
          _ -> fail (shows pos "Malformed node: Bad position in node")
    where
      height [] _ = Nothing
      height (x: xs) s          -- Assume s non-negative
          | s == 0 = Just x
          | otherwise = height xs (s - 1)
loadNode _ x = fail (shows (annotation x) "Malformed node")

-- Security Goals

-- Security goals

-- Load a defgoal form
findGoal :: (Algebra t p g s e c, Monad m) => Pos ->
            [Prot t g] -> [SExpr Pos] -> m (Preskel t g s e)
findGoal pos ps (S _ name : x : xs) =
    case L.find (\p -> name == pname p) ps of
      Nothing -> fail (shows pos $ "Protocol " ++ name ++ " unknown")
      Just p ->
        do
          (g, goal, antec) <- loadSentence pos p (pgen p) x
          let (gs, xs') = findAlist xs
          (g, goals) <- loadGoals pos p g gs
          _ <- alist [] xs'          -- Check syntax of xs
          let kcomment =
                loadComment "goals" (x : gs) ++
                loadComment "comment" (assoc "comment" xs')
          -- Make and return the characteristic skeleton of a security goal
          characteristic pos p (goal : goals) g antec kcomment
findGoal pos _ _ = fail (shows pos "Malformed defgoal")

-- Separate argument into goals and any remaining elements of an
-- association list.
findAlist :: [SExpr Pos] -> ([SExpr Pos], [SExpr Pos])
findAlist [] = ([], [])
findAlist (x@(L _ (S _ "forall" : _)) : xs) =
  (x : gs, xs')
  where
    (gs, xs') = findAlist xs
findAlist xs = ([], xs)

--- Load a sequence of security goals

loadGoals :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
             g -> [SExpr Pos] -> m (g, [Goal t])
loadGoals _ _ g [] = return (g, [])
loadGoals pos prot g (x : xs) =
  do
    (g, goal, _) <- loadSentence pos prot g x
    (g, goals) <- loadGoals pos prot g xs
    return (g, goal : goals)

-- Load a single security goal, a universally quantified formula
-- Returns the goal and the antecedent with position information.

loadSentence :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                g -> SExpr Pos -> m (g, Goal t, Conj t)
loadSentence _ prot g (L pos [S _ "forall", L _ vs, x]) =
  do
    (g, vars) <- loadVars g vs
    loadImplication pos prot g (L.nub vars) x
loadSentence pos _ _ _ = fail (shows pos "Malformed goal sentence")

-- Load the top-level implication of a security goal

loadImplication :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                   g -> [t] -> SExpr Pos -> m (g, Goal t, Conj t)
loadImplication _ prot g vars (L pos [S _ "implies", a, c]) =
  do
    (g, antec) <- loadRoleSpecific pos prot g vars vars a
    (g, concl) <- loadConclusion pos prot g vars c
    let goal =
          Goal { uvars = vars,
                 antec = map snd antec,
                 concl = map (map snd) concl }
    return (g, goal, antec)
loadImplication pos _ _ _ _ = fail (shows pos "Malformed goal implication")

-- The conclusion must be a disjunction.  Each disjunct may introduce
-- existentially quantified variables.

loadConclusion :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                  g -> [t] -> SExpr Pos -> m (g, [Conj t])
loadConclusion _ _ g _ (L _ [S _ "false"]) = return (g, [])
loadConclusion _ prot g vars (L pos (S _ "or" : xs)) =
  loadDisjuncts pos prot g vars xs []
loadConclusion pos prot g vars x =
  do
    (g, a) <- loadExistential pos prot g vars x
    return (g, [a])

loadDisjuncts :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                 g -> [t] -> [SExpr Pos] -> [Conj t] -> m (g, [Conj t])
loadDisjuncts _ _ g _ [] rest = return (g, reverse rest)
loadDisjuncts pos prot g vars (x : xs) rest =
  do
    (g, a) <- loadExistential pos prot g vars x
    loadDisjuncts pos prot g vars xs (a : rest)

loadExistential :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                   g -> [t] -> SExpr Pos -> m (g, Conj t)
loadExistential _ prot g vars (L pos [S _ "exists", L _ vs, x]) =
  do
    (g, evars) <- loadVars g vs
    loadRoleSpecific pos prot g (evars ++ vars) evars x
loadExistential pos prot g vars x =
  loadRoleSpecific pos prot g vars [] x

--- Load a conjunction of atomic formulas and ensure the formula is
--- role specific.

loadRoleSpecific :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                    g -> [t] -> [t] -> SExpr Pos -> m (g, Conj t)
loadRoleSpecific pos prot g vars unbound x =
  do
    (g, as) <- loadConjunction pos prot vars g x
    let as' = L.sortBy (\(_, x) (_, y) -> aFormOrder x y) as
    unbound <- foldM roleSpecific unbound as'
    case unbound of
      [] -> return (g, as')
      (v : _) -> fail (shows (annotation x) ("Malformed defgoal: " ++ showst v " not used"))

-- Load a conjunction of atomic formulas

loadConjunction :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                   [t] -> g -> SExpr Pos -> m (g, Conj t)
loadConjunction _ p kvars g (L pos (S _ "and" : xs)) =
  loadConjuncts pos p kvars g xs []
loadConjunction top p kvars g x =
  do
    (g, pos, a) <- loadPrimary top p kvars g x
    return (g, [(pos, a)])

loadConjuncts :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
                 [t] -> g -> [SExpr Pos] -> Conj t -> m (g, Conj t)
loadConjuncts _ _ _ g [] rest = return (g, reverse rest)
loadConjuncts top p kvars g (x : xs) rest =
  do
    (g, pos, a) <- loadPrimary top p kvars g x
    loadConjuncts top p kvars g xs ((pos, a) : rest)

-- Load the atomic formulas

loadPrimary :: (Algebra t p g s e c, Monad m) => Pos -> Prot t g ->
               [t] -> g -> SExpr Pos -> m (g, Pos, AForm t)
loadPrimary _ _ kvars g (L pos [S _ "=", x, y]) =
  do
    (g, t) <- loadSgTerm kvars g x
    (g, t') <- loadSgTerm kvars g y
    return (g, pos, Equals t t')
loadPrimary _ _ kvars g (L pos [S _ "non", x]) =
  do
    t <- loadAlgTerm kvars x
    return (g, pos, Non t)
loadPrimary _ _ kvars g (L pos [S _ "pnon", x]) =
  do
    t <- loadAlgTerm kvars x
    return (g, pos, Pnon t)
loadPrimary _ _ kvars g (L pos [S _ "uniq", x]) =
  do
    t <- loadAlgTerm kvars x
    return (g, pos, Uniq t)
loadPrimary _ _ kvars g (L pos [S _ "uniq-at", x, y]) =
  do
    t <- loadAlgTerm kvars x
    (g, t') <- loadNodeTerm kvars g y
    return (g, pos, UniqAt t t')
loadPrimary _ _ kvars g (L pos [S _ "ugen-at", x, y]) =
  do
    t <- loadAlgTerm kvars x
    (g, t') <- loadNodeTerm kvars g y
    return (g, pos, UgenAt t t')
loadPrimary _ _ kvars g (L pos [S _ "ugen", x]) =
  do
    t <- loadAlgTerm kvars x
    return (g, pos, Ugen t)
loadPrimary _ _ kvars g (L pos [S _ "str-prec", x, y]) =
  do
    (g, t) <- loadNodeTerm kvars g x
    (g, t') <- loadNodeTerm kvars g y
    return (g, pos, StrPrec t t')
loadPrimary _ _ kvars g (L pos [S _ "prec", x, y]) =
  do
    (g, t) <- loadNodeTerm kvars g x
    (g, t') <- loadNodeTerm kvars g y
    return (g, pos, Prec t t')
loadPrimary _ p kvars g (L pos [S _ "p", Q _ name, N _ i, x]) =
  do
    r <- lookupRole pos p name
    (g, t) <- loadNodeTerm kvars g x
    case i < 0 || i >= length (rtrace r) of
      True -> fail (shows pos "Bad index")
      False -> return (g, pos, RolePred r i t)
loadPrimary _ p kvars g (L pos [S _ "p", Q _ name, Q var x, y, z]) =
  do
    r <- lookupRole pos p name
    v <- loadAlgTerm (rvars r) (S var x)
    (g, n) <- loadNodeTerm kvars g y
    t <- loadAlgTerm kvars z
    case isVar v of
      False -> fail (shows pos "Bad parameter -- not a variable")
      True -> return (g, pos, ParamPred r v n t)
loadPrimary _ _ _ _ (L pos (S _ "p" : Q _ name : _)) =
  fail (shows pos ("Malformed role specific formula for role " ++ name))
loadPrimary _ _ _ _ (L pos (S _ pred : _)) =
  fail (shows pos ("Malformed formula for predicate " ++ pred))
loadPrimary pos _ _ _ _ = fail (shows pos "Bad formula")

-- Load a term and make sure it has sort node

loadNodeTerm :: (Algebra t p g s e c, Monad m) => [t] -> g ->
                SExpr Pos -> m (g, t)
loadNodeTerm ts g x =
  do
    (g, t) <- loadSgTerm ts g x
    case isNodeVar t of
      True -> return (g, t)
      False -> fail (shows (annotation x) "Expecting a node variable")

-- Load a term and make sure it does not have sort node

loadAlgTerm :: (Algebra t p g s e c, Monad m) => [t] -> SExpr Pos -> m t
loadAlgTerm _ x@(L _ [N _ _, N _ _]) =
  fail (shows (annotation x) "Expecting an algebra term")
loadAlgTerm ts x =
  do
    t <- loadTerm ts False x
    case isNodeVar t of
      True -> fail (shows (annotation x) "Expecting an algebra term")
      False -> return t

loadSgTerm :: (Algebra t p g s e c, Monad m) => [t] -> g ->
              SExpr Pos -> m (g, t)
loadSgTerm ts g x =
  do
    t <- loadTerm ts False x
    return (g, t)

-- Role specific check

termVars :: Algebra t p g s e c => t -> [t]
termVars t = addVars [] t

allBound :: Algebra t p g s e c => [t] -> t -> Bool
allBound unbound t =
  L.all (flip L.notElem unbound) (termVars t)

-- Returns variables in unbound that are not role specific

roleSpecific :: (Algebra t p g s e c, Monad m) =>
                [t] -> (Pos, AForm t) -> m [t]
roleSpecific unbound (_, RolePred _ _ n) =
  return $ L.delete n unbound
roleSpecific unbound (pos, ParamPred _ _ n t)
  | L.notElem n unbound = return $ unbound L.\\ termVars t
  | otherwise = fail (shows pos "Unbound variable in parameter predicate")
roleSpecific unbound (pos, StrPrec n n')
  | L.notElem n unbound && L.notElem n' unbound = return unbound
  | otherwise = fail (shows pos "Unbound variable in str-prec")
roleSpecific unbound (pos, Prec n n')
  | L.notElem n unbound && L.notElem n' unbound = return unbound
  | otherwise = fail (shows pos "Unbound variable in prec")
roleSpecific unbound (pos, Non t)
  | allBound unbound t = return unbound
  | otherwise = fail (shows pos "Unbound variable in non")
roleSpecific unbound (pos, Pnon t)
  | allBound unbound t = return unbound
  | otherwise = fail (shows pos "Unbound variable in pnon")
roleSpecific unbound (pos, Uniq t)
  | allBound unbound t = return unbound
  | otherwise = fail (shows pos "Unbound variable in uniq")
roleSpecific unbound (pos, UniqAt t n)
  | allBound unbound t && L.notElem n unbound = return unbound
  | otherwise = fail (shows pos "Unbound variable in uniq-at")
roleSpecific unbound (pos, UgenAt t n)
  | allBound unbound t && L.notElem n unbound = return unbound
  | otherwise = fail (shows pos "Unbound variable in ugen-at")
roleSpecific unbound (pos, Ugen t)
  | allBound unbound t = return unbound
  | otherwise = fail (shows pos "Unbound variable in ugen")
roleSpecific unbound (pos, Equals t t')
  | isNodeVar t && isNodeVar t' =
    case L.notElem t unbound && L.notElem t' unbound of
      True -> return unbound
      False -> fail (shows pos "Unbound variable in equals")
  | isNodeVar t = fail (shows pos "Type mismatch in equals")
  | isNodeVar t' = fail (shows pos "Type mismatch in equals")
  | allBound unbound t && allBound unbound t' = return unbound
  | otherwise = fail (shows pos "Unbound variable in equals")
