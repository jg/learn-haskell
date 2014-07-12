{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE Arrows, NoMonomorphismRestriction #-}
{-# LANGUAGE FlexibleInstances #-}
module Reddit where

import Network.Wreq
import Control.Lens
import Control.Monad
import qualified Data.Text as T
import Data.Text (Text)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text.Encoding as TE
import Text.HandsomeSoup
import Text.XML.HXT.Core
import Data.Tree.NTree.TypeDefs

newtype Url = Url String deriving (Show)

newtype User = User Text

data Comment = Comment {
  title :: String,
  subreddit :: String,
  body :: String
  } deriving (Show)

userToUrl :: String -> Url
userToUrl u =
  Url $ "http://www.reddit.com/user/" ++ show u ++ "/comments/"

showUrl :: Url -> IO ()
showUrl (Url url) = putStrLn url

parseComment :: String -> Comment
parseComment = undefined

getPage :: Url -> IO (String)
getPage (Url url) = do
  result <- get url
  return $ T.unpack (TE.decodeUtf8 (BL.toStrict (result ^. responseBody)))

getUserPage = getPage (Url "http://www.reddit.com/user/dons/comments/")

parseComments :: ArrowXml a => a XmlTree Comment
parseComments = css ".comment" >>>
                       proc x -> do
                         title_ <-         css ".title" //> getText -< x
                         subreddit_ <- css ".subreddit" //> getText -< x
                         body_ <-             css ".md" //> getText -< x
                         returnA -< Comment title_ subreddit_ body_

getNextPageUrl :: ArrowXml a => a XmlTree String
getNextPageUrl = css ".nextprev a" >>> getAttrValue "href"

getComments :: Url -> Int -> [Comment] -> IO [Comment]
getComments _ 0 comments = return (comments)
getComments url n comments = do
  page <- getPage url
  document <- return (parseHtml page)
  pageComments <- runX $ parseComments <<< document
  href <- liftM head (runX (getNextPageUrl <<< document))
  getComments (Url href) (n-1) (comments ++ pageComments)

getCommentPages :: Int -> IO [Comment]
getCommentPages pages = getComments (Url "http://www.reddit.com/user/dons") pages []