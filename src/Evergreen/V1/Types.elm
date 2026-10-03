module Evergreen.V1.Types exposing (..)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Lamdera
import Url


type alias FrontendModel =
    { key : Effect.Browser.Navigation.Key
    , message : String
    }


type alias BackendModel =
    { message : String
    }


type FrontendMsg
    = UrlClicked Effect.Browser.UrlRequest
    | UrlChanged Url.Url
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
