module PDBParser where

import Data.List (intercalate)
import GHC.Exts (groupWith)

data Amino = ARG | HIS | LYS | ASP | GLU | SER | THR | ASN | GLN | CYS | SEC |
           GLY | PRO | ALA | VAL | ILE | LEU | MET | PHE | TYR | TRP | HSD deriving (Show, Eq, Read, Ord)

justifyLeft :: Int -> Char -> String -> String
justifyLeft i ch st
  | lst >= i = st
  | otherwise = st ++ (replicate (i-lst) ch)
    where lst = length st

justifyRight :: Int -> Char -> String -> String
justifyRight i ch st
  | lst >= i = st
  | otherwise = replicate (i-lst) ch ++ st
    where lst = length st

centreText :: Int -> Char -> String -> String
centreText i ch st
  | lst >= i = st
  | otherwise = let lRep = div amount_left 2
                    rRep = amount_left - lRep
                in
                  replicate (lRep) ch ++ st ++ replicate (rRep) ch
    where lst = length st
          amount_left = i - lst

--Because name formatting is weird.
--0 letters
formatName :: String -> String
formatName st = case (length st) of
  0 -> "    "
  1 -> " " ++ st ++ "  "
  2 -> " " ++ st ++ " "
  3 -> " " ++ st
  4 -> st
  _ -> take 4 st

-- Record strings are 80 characters in length. This is the format for an atom string
data Atom = Atom { -- Record Name 1 - 6 eg. "ATOM  "
  serial :: Int, -- 7 - 11
  --name :: String, 14 - 16 (could be 13 - 16 but this doesn't seem to work with smog)
  name :: String, --Is 13-16 but is centred (bias to left)
  altLoc :: Char, -- 17
  resName :: Amino, -- 18 - 20
  chainID:: Char, -- 22
  resSeq :: Int, -- 23 - 26
  iCode :: Char, -- 27
  x :: Double, -- 31 - 38
  y :: Double, -- 39 - 46
  z :: Double, -- 47 - 54
  occupancy :: Double, -- 55 - 60
  tempFactor :: Double, -- 61 - 66 default of 0.0
  segment :: String, -- 73 - 76 left justified
  element :: String, -- 77 - 78 right justified
  charge :: String -- 79 - 80
                 } deriving (Eq, Ord)

instance Show Atom where
  show (Atom serialA nameA altLocA resNameA chainIDA resSeqA iCodeA xA yA zA
       occupancyA tempFactorA segmentA elementA chargeA) =
    let
      rJstTake :: Int -> String -> String
      rJstTake i str = justifyRight i ' ' $ take i str
      lJstTake :: Int -> String -> String
      lJstTake i str = justifyLeft i ' ' $ take i str
      serSt = rJstTake 5 $ show serialA
      namSt = formatName nameA
      altSt = rJstTake 1 $ [altLocA]
      resSt = rJstTake 3 $ show resNameA
      chaSt = rJstTake 1 $ [chainIDA]
      rSqSt = rJstTake 4 $ show resSeqA
      iCoSt = rJstTake 1 $ [iCodeA]
      xSt = rJstTake 8 $ show xA
      ySt = rJstTake 8 $ show yA
      zSt = rJstTake 8 $ show zA
      occSt = rJstTake 6 $ show occupancyA
      temSt = rJstTake 6 $ show tempFactorA
      segSt = lJstTake 4 $ segmentA
      eleSt = rJstTake 2 $ elementA
      chrSt = rJstTake 2 $ chargeA
    in
      "ATOM  " ++ serSt ++ " " ++ namSt ++ altSt ++ resSt ++ " " ++ chaSt ++ rSqSt ++ iCoSt ++
      "   " ++ xSt ++ ySt ++ zSt ++ occSt ++ temSt ++ "      " ++ segSt ++ eleSt ++ chrSt

atomFromString :: String -> Atom
atomFromString str =
  let
    tkDrpStrp :: Int -> Int -> String -> String
    tkDrpStrp i j st = filter ((/=)' ') $ take i $ drop j st
    tkDrpStrpPos i j st = tkDrpStrp (j-i+1) (i-1) st
    serialA = read (tkDrpStrpPos 7 11 str) :: Int
    nameA = tkDrpStrpPos 13 16 str
    altLocA = case tkDrpStrpPos 17 17 str of
      c:cs -> c
      _ -> ' '
    resNameA = read $ tkDrpStrpPos 18 20 str :: Amino
    chainIDA = case tkDrpStrpPos 22 22 str of
      c:cs -> c
      _ -> ' '
    resSeqA = read $ tkDrpStrpPos 23 26 str :: Int
    iCodeA = case tkDrpStrpPos 27 27 str of
      c:cs -> c
      _ -> ' '
    xA = read $ tkDrpStrpPos 31 38 str :: Double
    yA = read $ tkDrpStrpPos 39 46 str :: Double
    zA = read $ tkDrpStrpPos 47 54 str :: Double
    occupancyA = read $ tkDrpStrpPos 55 60 str :: Double
    tempFactorA = read $ tkDrpStrpPos 61 66 str :: Double
    segmentA = tkDrpStrpPos 73 76 str
    elementA = tkDrpStrpPos 77 78 str
    chargeA = tkDrpStrpPos 79 80 str
  in
    Atom serialA nameA altLocA resNameA chainIDA resSeqA iCodeA
    xA yA zA occupancyA tempFactorA segmentA elementA chargeA

--Renumbers an atom
reNumAtom :: Atom -> Int -> Atom
reNumAtom at a = at { serial = a }

reNumAtoms :: [Atom] -> Int -> [Atom]
reNumAtoms [] _ = []
reNumAtoms (a:as) i = reNumAtom a i : reNumAtoms as (i+1)

reNumResidues :: [Atom] -> Int -> [Atom]
reNumResidues ats i= let reNumGroup grp k = map (\at -> at{resSeq=k}) grp
                         reNumGroups [] _ = []
                         reNumGroups (g:gs) j = reNumGroup g j : reNumGroups gs (j+1)
               in concat $ reNumGroups (groupWith (\at -> resSeq at) ats ) i


convertFile :: String -> String
convertFile file = intercalate "\n" $ convertLines (lines file) 1
  where convertLines :: [String] -> Int -> [String]
        convertLines [] _ = []
        convertLines (l:ls) i = case (head $ words l) of
          "ATOM" -> show (reNumAtom (atomFromString l) i) : convertLines ls (i+1)
          _ -> l : convertLines ls (i)

extractAtoms :: String -> [Atom]
extractAtoms file = map atomFromString $ filter (\line -> head (words line)=="ATOM") (lines file)

removeHs :: [Atom] -> [Atom]
removeHs = filter (\a -> element a /= "H")
