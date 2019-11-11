import           Control.Monad (unless)

import           System.Exit (exitFailure)
import           System.IO (BufferMode (LineBuffering), hSetBuffering, stderr, stdout)

import qualified Test.Jetski

defaultMain :: [IO Bool] -> IO ()
defaultMain tests = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  result <- and <$> sequence tests
  unless result
    exitFailure

main :: IO ()
main =
  defaultMain [
      Test.Jetski.tests
    ]

