{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
module Test.Jetski where

import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Trans.Either (EitherT(..))

import           Data.Text (Text)
import qualified Data.Text as T

import           Disorder.Core.IO

import           Foreign.Ptr (intPtrToPtr)

import           Jetski

import           P

import           System.IO (IO)

import           Test.Jetski.Arbitrary
import           Test.QuickCheck
import           Test.QuickCheck.Property (succeeded)

------------------------------------------------------------------------

prop_library name (Arguments args) = testEitherT $ do
  withLibrary extraOptions (source name args) $ \library -> do
    f <- function library (unName name) retInt
    _ <- liftIO (f (fmap ffiArg args))
    return (property succeeded)

prop_assembly name (Arguments args) = testEitherT $ do
  _ <- compileAssembly extraOptions (source name args)
  return (property succeeded)


------------------------------------------------------------------------

extraOptions :: [CompilerOption]
extraOptions = ["-O11", "-march=native"]

source :: Name -> [Argument] -> Text
source name args = T.unlines [
      "#include <stdint.h>"
    , ""
    , "extern \"C\" { int " <> unName name <> "(" <> params <> ") {"
    , "    return " <> expr  <> ";"
    , "}"
    , "}"
    ]
  where
    params  = T.intercalate ", " (fmap param args)
    param x = ctype x <> " " <> nameOfArgument x

    expr
     | null args
     = "42"
     | otherwise
     = T.intercalate " + "
     . ("(int)((long)42)":)
     $ fmap go args

    bracket s = "(" <> s <> ")"
    go x = "(int)((long)" <> bracket (nameOfArgument x) <> ")"

ctype :: Argument -> Text
ctype = \case
  Double  _ _ -> "double"
  Int32   _ _ -> "int32_t"
  VoidPtr _ _ -> "void*"

ffiArg :: Argument -> Arg
ffiArg (Double  _ x) = argDouble x
ffiArg (Int32   _ x) = argInt32  x
ffiArg (VoidPtr _ x) = argPtr (intPtrToPtr x)

whichCastToInt :: Argument -> Text
whichCastToInt x
 = case x of
    Double{}  -> "static_cast<intptr_t>"
    Int32{}   -> "static_cast<intptr_t>"
    VoidPtr{} -> "reinterpret_cast<intptr_t>"

------------------------------------------------------------------------

testEitherT :: EitherT JetskiError IO Property -> Property
testEitherT action = testIO $ do
    e <- runEitherT action
    case e of
      Left  l -> failProp l
      Right r -> return r
  where
    failProp x =
      let msg = T.unpack ("testEitherT: " <> errorRender x)
      in  return (counterexample msg (False === True))

errorRender :: JetskiError -> Text
errorRender = \case
    CompilerError opts src err
        -> "when compiling with: " <> T.unwords opts <> "\n\n"
        <> indent src
        <> "\nencountered the following error:\n\n"
        <> indent err
    err -> T.pack (show err)
  where
    indent = T.unlines . fmap ("    " <>) . T.lines


------------------------------------------------------------------------

return []
tests = $quickCheckAll
