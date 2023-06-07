module Bin.AppM where

import Prelude

import Control.Monad.Except (runExceptT)
import Control.Monad.Reader (class MonadAsk, ReaderT, ask, runReaderT)
import Control.Monad.Reader as ReaderT
import Data.Either (Either)
import Data.Newtype (class Newtype)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect)
import Lib.Foreign.Octokit (GitHubError, Octokit)
import Lib.Git (GitM(..))
import Lib.GitHub (GitHubM(..))
import Node.Path (FilePath)

-- | An app-specific class for functions we want to be made more convenient
class MonadApp m where
  runGitHubM :: forall a. GitHubM a -> m (Either GitHubError a)
  runGitM :: forall a. GitM a -> m (Either String a)

type Env =
  { octokit :: Octokit
  , tmpDir :: FilePath
  , gitBranch :: String
  , manifestDir :: FilePath
  }

newtype AppM a = AppM (ReaderT Env Aff a)

derive instance Newtype (AppM a) _
derive newtype instance Functor AppM
derive newtype instance Apply AppM
derive newtype instance Applicative AppM
derive newtype instance Bind AppM
derive newtype instance Monad AppM
derive newtype instance MonadEffect AppM
derive newtype instance MonadAff AppM
derive newtype instance MonadAsk Env AppM

instance MonadApp AppM where
  runGitHubM (GitHubM run) = do
    { octokit } <- ask
    liftAff $ runReaderT (runExceptT run) octokit

  runGitM (GitM run) = do
    { tmpDir, gitBranch } <- ask
    liftAff $ runReaderT (runExceptT run) { cwd: tmpDir, branch: gitBranch }

runAppM :: forall a. Env -> AppM a -> Aff a
runAppM env (AppM run) = runReaderT run env
