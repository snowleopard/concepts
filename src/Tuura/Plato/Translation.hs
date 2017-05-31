module Tuura.Plato.Translation where

import Data.Char
import Data.List
import Data.Monoid
import Data.Ord
import qualified Data.List.NonEmpty as NonEmpty

import Tuura.Concept.Circuit.Basic
import Tuura.Concept.Circuit.Derived

data ValidationResult a = Valid | Invalid [ValidationError a] deriving Eq

instance Monoid (ValidationResult a) where
    mempty = mempty

    mappend Valid x = x
    mappend x Valid = x
    mappend (Invalid es) (Invalid fs) = Invalid (fs ++ es)

data ValidationError a = UnusedSignal a
                       | InconsistentInitialState a
                       | UndefinedInitialState a
                       | InvariantViolated [Transition a]
                       deriving Eq

data Signal = Signal Int deriving Eq

instance Show Signal where
    show (Signal i)
        | i < 26    = [chr (ord 'A' + i)]
        | otherwise = 'S' : show i

instance Ord Signal
    where
        compare (Signal x) (Signal y) = compare x y

-- TODO: Tidy up function, it looks ugly.
addErrors :: (Eq a, Show a) => [ValidationError a] -> String
addErrors errs = "Error\n" ++
        (if unused /= []
        then "The following signals are not declared as input, "
             ++ "output or internal: \n" ++ unlines (map show unused) ++ "\n"
        else "") ++
        (if incons /= []
        then "The following signals have inconsistent inital states: \n"
             ++ unlines (map show incons) ++ "\n"
        else "") ++
        (if undefd /= []
        then "The following signals have undefined initial states: \n"
             ++ unlines (map show undefd) ++ "\n"
        else "") ++
        (if invVio /= []
        then "The following state(s) are reachable " ++
             "but the invariant does not hold for them:\n" ++
             unlines (map show invVio) ++ "\n"
        else "")
    where
        unused = [ a | UnusedSignal a             <- errs ]
        incons = [ a | InconsistentInitialState a <- errs ]
        undefd = [ a | UndefinedInitialState a    <- errs ]
        invVio = [ a | InvariantViolated a        <- errs ]

validate :: Ord a => [a] -> CircuitConcept a -> ValidationResult a
validate signs circuit = (validateInitialState signs circuit)
                      <> (validateInterface signs circuit)

validateInitialState :: Ord a => [a] -> CircuitConcept a -> ValidationResult a
validateInitialState signs circuit
    | undef ++ inconsistent == [] = Valid
    | otherwise = Invalid (map UndefinedInitialState undef
                        ++ map InconsistentInitialState inconsistent)
  where
    undef        = filter ((==Undefined) . initial circuit) signs
    inconsistent = filter ((==Inconsistent) . initial circuit) signs

validateInterface :: Ord a => [a] -> CircuitConcept a -> ValidationResult a
validateInterface signs circuit
    | unused == [] = Valid
    | otherwise = Invalid (map UnusedSignal unused)
  where
    unused       = filter ((==Unused) . interface circuit) signs

cartesianProduct :: Ord a => NonEmpty.NonEmpty [a] -> [[a]]
cartesianProduct l = removeSupersets sortAllLists
  where
    sequenced    = sequence (NonEmpty.toList l)
    removeDupes  = map nub sequenced
    sortAllLists = map sort removeDupes

removeSupersets :: Eq a => [[a]] -> [[a]]
removeSupersets s = [ x | (x:xs) <- tails sortByLength, not (check x xs) ]
  where
    check current = any (`isSubsequenceOf` current)
    sortByLength  = sortBy (comparing $ negate . length) s

arcLists :: [Causality (Transition a)] -> [([Transition a], Transition a)]
arcLists xs = [ (f, t) | Causality f t <- xs ]
