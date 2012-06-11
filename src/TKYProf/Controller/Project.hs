{-# LANGUAGE TemplateHaskell #-}
module TKYProf.Controller.Project where
import Data.Aeson.TH (deriveJSON)
import Network.HTTP.Types (noContent204)
import Yesod.Content (RepJson)
import Yesod.Handler (sendResponseStatus)
import Yesod.Json (jsonToRepJson)
import Yesod.Persist (runDB)

import TKYProf.Controller.Internal
import TKYProf.Model
import qualified TKYProf.Model.Project as Proj

getProjectsR :: Handler RepJson
getProjectsR = pagenator 0 20 $ \pagenate -> do
  projects <- runDB $ Proj.selectList [] (pagenate [Desc ProjectUpdatedAt])
  jsonToRepJson (projects :: [Entity Project])

newtype PostProject = PostProject
  { postProjectName :: Text
  }

$(deriveJSON (removePrefix "postProject") ''PostProject)

postProjectsR :: Handler RepJson
postProjectsR = do
  PostProject name <- parseJsonBody
  project <- runDB $ Proj.create name
  jsonToRepJson project

getProjectIdR :: ProjectId -> Handler RepJson
getProjectIdR pid = runDB (Proj.get pid) >>= jsonToRepJson

deleteProjectIdR :: ProjectId -> Handler ()
deleteProjectIdR pid = do
  runDB $ Proj.delete pid
  sendResponseStatus noContent204 ()
