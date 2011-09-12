{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies, OverloadedStrings #-}
module Foundation
  ( TKYProf (..)
  , TKYProfRoute (..)
  , resourcesTKYProf
  , Handler
  , Widget
  , module Yesod.Core
  , module Settings
  , module Settings.StaticFiles
  , module Model
  , module Control.Monad.STM
  , StaticRoute (..)
  , lift
  , liftIO
  ) where

import Control.Applicative
import Control.Monad (unless)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.STM (STM, atomically)
import Control.Monad.Trans.Class (lift)
import Model
import Settings (hamletFile, luciusFile, juliusFile, widgetFile)
import Settings.StaticFiles
import System.Directory
import System.FilePath ((</>))
import Web.ClientSession (getKey)
import Yesod.Core
import Yesod.Logger (Logger, logLazyText)
import Yesod.Static (Static, base64md5, StaticRoute(..))
import qualified Data.ByteString.Lazy as L
import qualified Data.Text as T
import qualified Settings

-- | The site argument for your application. This can be a good place to
-- keep settings and values requiring initialization before your application
-- starts running, such as database connections. Every handler will have
-- access to the data present here.
data TKYProf = TKYProf
  { settings   :: Settings.AppConfig
  , getLogger  :: Logger
  , getStatic  :: Static
  , getReports :: Reports
  }

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://docs.yesodweb.com/book/web-routes-quasi/
--
-- This function does three things:
--
-- * Creates the route datatype TKYProfRoute. Every valid URL in your
--   application can be represented as a value of this type.
-- * Creates the associated type:
--       type instance Route TKYProf = TKYProfRoute
-- * Creates the value resourcesTKYProf which contains information on the
--   resources declared below. This is used in Controller.hs by the call to
--   mkYesodDispatch
--
-- What this function does *not* do is create a YesodSite instance for
-- TKYProf. Creating that instance requires all of the handler functions
-- for our application to be in scope. However, the handler functions
-- usually require access to the TKYProfRoute datatype. Therefore, we
-- split these actions into two functions and place them in separate files.
mkYesodData "TKYProf" $(parseRoutesFile "config/routes")

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod TKYProf where
  approot = Settings.appRoot . settings

  encryptKey _ = Just <$> getKey "config/client_session_key.aes"

  defaultLayout widget = do
    mmsg <- getMessage
    (title, bcs) <- breadcrumbs
    pc <- widgetToPageContent $ do
      addWidget $(Settings.widgetFile "header")
      widget
      addLucius $(Settings.luciusFile "default-layout")
    hamletToRepHtml $(Settings.hamletFile "default-layout")

  -- This is done to provide an optimization for serving static files from
  -- a separate domain. Please see the staticroot setting in Settings.hs
  urlRenderOverride y (StaticR s) =
    Just $ uncurry (joinPath y (Settings.staticRoot $ settings y)) $ renderRoute s
  urlRenderOverride _ _ = Nothing

  messageLogger y loc level msg =
    formatLogMessage loc level msg >>= logLazyText (getLogger y)

  -- This function creates static content files in the static folder
  -- and names them based on a hash of their content. This allows
  -- expiration dates to be set far in the future without worry of
  -- users receiving stale content.
  addStaticContent ext' _ content = do
    let fn = base64md5 content ++ '.' : T.unpack ext'
    let statictmp = Settings.staticDir </> "tmp/"
    liftIO $ createDirectoryIfMissing True statictmp
    let fn' = statictmp ++ fn
    exists <- liftIO $ doesFileExist fn'
    unless exists $ liftIO $ L.writeFile fn' content
    return $ Just $ Right (StaticR $ StaticRoute ["tmp", T.pack fn] [], [])

instance YesodBreadcrumbs TKYProf where
  breadcrumb HomeR                   = return ("Home", Nothing)
  breadcrumb ReportsR                = return ("Reports", Just HomeR)
  breadcrumb (ReportsIdTimeR rid _)  = return ("Report #" `T.append` T.pack (show rid), Just ReportsR)
  breadcrumb (ReportsIdAllocR rid _) = return ("Report #" `T.append` T.pack (show rid), Just ReportsR)
  breadcrumb _                       = return ("Not found", Just HomeR)
