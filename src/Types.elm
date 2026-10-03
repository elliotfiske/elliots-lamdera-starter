module Types exposing
    ( BackendModel
    , BackendMsg(..)
    , FrontendModel
    , FrontendMsg(..)
    , ToBackend(..)
    , ToFrontend(..)
    )

import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation exposing (Key)
import Effect.Lamdera
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , message : String
    }


type alias BackendModel =
    { message : String
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | PingClicked
    | NoOpFrontendMsg


type ToBackend
    = PingFromFrontend
    | NoOpToBackend


type BackendMsg
    = NoOpBackendMsg
    | ClientConnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId
    | ClientDisconnected Effect.Lamdera.SessionId Effect.Lamdera.ClientId


type ToFrontend
    = PongFromBackend String
    | NoOpToFrontend
