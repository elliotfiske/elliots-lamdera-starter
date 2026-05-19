module Auth exposing (backendConfig)

import Auth.Common
import Auth.Flow
import Auth.Method.OAuthGithub
import Dict
import Env
import Lamdera
import Time
import Types
    exposing
        ( BackendModel
        , BackendMsg(..)
        , FrontendModel
        , FrontendMsg
        , ToBackend(..)
        , ToFrontend(..)
        )


config : Auth.Common.Config FrontendMsg ToBackend BackendMsg ToFrontend FrontendModel BackendModel
config =
    { toBackend = AuthToBackend
    , toFrontend = AuthToFrontend
    , backendMsg = AuthBackendMsg
    , sendToFrontend = Lamdera.sendToFrontend
    , sendToBackend = Lamdera.sendToBackend
    , methods =
        [ Auth.Method.OAuthGithub.configuration Env.githubClientId Env.githubClientSecret
        ]
    , renewSession = \_ _ model -> ( model, Cmd.none )
    }


backendConfig : BackendModel -> Auth.Flow.BackendUpdateConfig FrontendMsg BackendMsg ToFrontend FrontendModel BackendModel
backendConfig model =
    { asToFrontend = AuthToFrontend
    , asBackendMsg = AuthBackendMsg
    , sendToFrontend = Lamdera.sendToFrontend
    , backendModel = model
    , loadMethod =
        \id ->
            config.methods
                |> List.filter (\m -> methodId m == id)
                |> List.head
    , handleAuthSuccess = handleAuthSuccess model
    , renewSession = config.renewSession
    , logout = \_ _ m -> ( m, Cmd.none )
    , isDev = False
    }


handleAuthSuccess :
    BackendModel
    -> Auth.Common.SessionId
    -> Auth.Common.ClientId
    -> Auth.Common.UserInfo
    -> Auth.Common.MethodId
    -> Maybe Auth.Common.Token
    -> Time.Posix
    -> ( BackendModel, Cmd BackendMsg )
handleAuthSuccess model sessionId clientId userInfo _ _ _ =
    ( { model | authenticatedSessions = Dict.insert sessionId userInfo model.authenticatedSessions }
    , Lamdera.sendToFrontend clientId (GotUser userInfo)
    )


methodId : Auth.Common.Method frontendMsg backendMsg frontendModel backendModel -> String
methodId method =
    case method of
        Auth.Common.ProtocolOAuth cfg ->
            cfg.id

        Auth.Common.ProtocolEmailMagicLink cfg ->
            cfg.id
