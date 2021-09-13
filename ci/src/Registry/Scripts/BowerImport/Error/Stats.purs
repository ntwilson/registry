module Registry.Scripts.BowerImport.Error.Stats 
  ( errorStats
  , prettyPrintStats
  , logStats
  , Stats
  , SucceededPackages
  ) where

import Registry.Prelude

import Control.Monad.Writer (execWriter, tell)
import Data.Array as Array
import Data.Foldable (fold, intercalate, sum)
import Data.Function (on)
import Data.List as List
import Data.List.NonEmpty as NonEmptyList
import Data.Map (SemigroupMap)
import Data.Map as Map
import Data.Newtype (unwrap)
import Data.Ordering (invert)
import Data.Set as Set
import Registry.Scripts.BowerImport.Error (ImportError(..), ImportErrorKey(..), ManifestError, ManifestErrorKey, PackageFailures(..), RawPackageName, RawVersion, manifestErrorKey, printManifestErrorKey)
import Safe.Coerce (coerce)

newtype VersionFailures = VersionFailures 
  (Map RawPackageName (Map RawVersion (Array ImportError)))
derive instance Newtype VersionFailures _

versionFailuresFromPackageFailures :: PackageFailures -> VersionFailures
versionFailuresFromPackageFailures (PackageFailures failures) = VersionFailures $
  let 
    onlyVersionFailures :: List (Map RawPackageName (Map RawVersion ImportError))
    onlyVersionFailures = Map.values failures # map (Map.mapMaybe hush)

    semigroupVersionFailures :: List (SemigroupMap RawPackageName (SemigroupMap RawVersion (Array ImportError)))
    semigroupVersionFailures = coerce (map (map (map Array.singleton)) onlyVersionFailures)

  in coerce (fold semigroupVersionFailures)

type Stats = 
  { countOfPackageSuccesses :: Int
  , countOfPackageFailures :: Int
  , countOfVersionSuccesses :: Int
  , countOfVersionFailures :: Int
  , countImportErrorsByErrorType :: Map ImportErrorKey Int
  , countManifestErrorsByErrorType :: Map ManifestErrorKey Int
  }

type SucceededPackages package version a = Map package (Map version a)

errorStats :: forall package version a. SucceededPackages package version a -> PackageFailures -> Stats
errorStats succeededPackages pFailures@(PackageFailures failures) = 
  { countOfPackageSuccesses
  , countOfPackageFailures
  , countOfVersionSuccesses
  , countOfVersionFailures
  , countImportErrorsByErrorType
  , countManifestErrorsByErrorType 
  } 
  where 
    countOfPackageSuccesses = Map.size succeededPackages 
    countOfVersionSuccesses = sum $ map Map.size succeededPackages

    packages = fold $ map Map.keys $ Map.values failures
    countOfPackageFailures = Set.size packages
    countOfVersionFailures = 
      sum $ map Map.size $ unwrap $ versionFailuresFromPackageFailures pFailures
    countImportErrorsByErrorType = map (sum <<< map (either (const 1) Map.size)) failures

    countManifestErrorsByErrorType = case Map.lookup manifestErrorKey failures of 
      Nothing -> Map.empty
      Just manifestErrors -> 
        let 
          allManifestErrors :: List ManifestError
          allManifestErrors = 
            Map.values manifestErrors
            >>= either List.singleton List.fromFoldable
            # List.mapMaybe (case _ of 
              ManifestError errs -> Just $ List.fromFoldable errs
              _ -> Nothing)
            # join
        in 
          allManifestErrors
          # List.sortBy (compare `on` printManifestErrorKey) 
          # List.groupBy (eq `on` printManifestErrorKey) 
          # map (\v -> printManifestErrorKey (NonEmptyList.head v) /\ NonEmptyList.length v)
          # Map.fromFoldable

        


-- newtype PackageFailures = 
--   PackageFailures (Map ImportErrorKey (Map RawPackageName (Either ImportError (Map RawVersion ImportError))))

prettyPrintStats :: Stats -> String
prettyPrintStats stats = 
  intercalate "\n"
    ( [ "Number of successful packages: " <> show stats.countOfPackageSuccesses 
      , "Number of failed packages: " <> show stats.countOfPackageFailures 
      , "Number of successful versions: " <> show stats.countOfVersionSuccesses
      , "Number of failed versions: " <> show stats.countOfVersionFailures
      , "Failures by error:"
      ]
      <>
      sortedErrors
    )

  where 
    sortedErrors = 
      Map.toUnfoldable stats.countImportErrorsByErrorType
      # Array.sortBy (invertCompare `on` snd)
      <#> (intercalate "\n" <<< execWriter <<< case _ of 
        (key@(ImportErrorKey keyStr) /\ errCount) 
          | key == manifestErrorKey -> do
            tell [ "  " <> keyStr <> ": " <> show errCount <> " (total packages/versions)" ]
            for_ (Map.toUnfoldable stats.countManifestErrorsByErrorType # Array.sortBy (invertCompare `on` snd)) \(err /\ count) -> do
              tell [ "    " <> err <> ": " <> show count ]
          | otherwise -> 
            tell [ "  " <> keyStr <> ": " <> show errCount ]
      )

    invertCompare a b = invert $ compare a b 

logStats :: forall m. MonadEffect m => Stats -> m Unit
logStats = prettyPrintStats >>> log
