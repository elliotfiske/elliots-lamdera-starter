module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    )

import Auth.Common
import Dict exposing (Dict)
import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation exposing (Key)
import Effect.Lamdera
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , message : String
    , authFlow : Auth.Common.Flow
    , authRedirectBaseUrl : Url
    , currentUser : Maybe Auth.Common.UserInfo
    }


type alias BackendModel =
    { message : String
    , pendingAuths : Dict Auth.Common.SessionId Auth.Common.PendingAuth
    , authenticatedSessions : Dict Auth.Common.SessionId Auth.Common.UserInfo
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | PingClicked
    | SignInWithGithubClicked
    | NoOpFrontendMsg


type ToBackend
    = PingFromFrontend
    | AuthToBackend Auth.Common.ToBackend
    | NoOpToBackend


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | AuthBackendMsg Auth.Common.BackendMsg


type ToFrontend
    = PongFromBackend String
    | AuthToFrontend Auth.Common.ToFrontend
    | GotUser Auth.Common.UserInfo
    | NoOpToFrontend
