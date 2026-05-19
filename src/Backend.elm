module Backend exposing (app, app_)

import Auth
import Auth.Flow
import Dict
import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription exposing (Subscription)
import Lamdera as L
import Types exposing (BackendModel, BackendMsg(..), ToBackend(..), ToFrontend(..))


type alias Model =
    BackendModel


app =
    Effect.Lamdera.backend
        L.broadcast
        L.sendToFrontend
        app_


app_ =
    { init = init
    , update = update
    , updateFromFrontend = updateFromFrontend
    , subscriptions = subscriptions
    }


subscriptions : Model -> Subscription BackendOnly BackendMsg
subscriptions _ =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        ]


init : ( Model, Command restriction toMsg BackendMsg )
init =
    ( { message = "Hello!"
      , pendingAuths = Dict.empty
      , authenticatedSessions = Dict.empty
      }
    , Command.none
    )


update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
update msg model =
    case msg of
        NoOpBackendMsg ->
            ( model, Command.none )

        ClientConnected sessionId clientId ->
            case Dict.get (Effect.Lamdera.sessionIdToString sessionId) model.authenticatedSessions of
                Just user ->
                    ( model, Effect.Lamdera.sendToFrontend clientId (GotUser user) )

                Nothing ->
                    ( model, Command.none )

        ClientDisconnected _ _ ->
            ( model, Command.none )

        AuthBackendMsg authMsg ->
            Auth.Flow.backendUpdate (Auth.backendConfig model) authMsg
                |> Tuple.mapSecond (Command.fromCmd "auth")


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontend sessionId clientId msg model =
    case msg of
        PingFromFrontend ->
            ( model
            , Effect.Lamdera.sendToFrontend clientId (PongFromBackend "Pong! Backend received your ping.")
            )

        AuthToBackend authMsg ->
            Auth.Flow.updateFromFrontend
                { asBackendMsg = AuthBackendMsg }
                (Effect.Lamdera.clientIdToString clientId)
                (Effect.Lamdera.sessionIdToString sessionId)
                authMsg
                model
                |> Tuple.mapSecond (Command.fromCmd "auth")

        NoOpToBackend ->
            ( model, Command.none )
