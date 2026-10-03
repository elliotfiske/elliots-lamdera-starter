module Frontend exposing (app, app_)

import Effect.Browser
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command)
import Effect.Lamdera
import Effect.Subscription as Subscription
import Html
import Html.Attributes as Attr
import Html.Events as Events
import Lamdera as L
import Types exposing (FrontendModel, FrontendMsg(..), ToBackend(..), ToFrontend(..))
import Url exposing (Url)


type alias Model =
    FrontendModel


app =
    Effect.Lamdera.frontend
        L.sendToBackend
        app_


app_ =
    { init = init
    , onUrlRequest = UrlClicked
    , onUrlChange = UrlChanged
    , update = update
    , updateFromBackend = updateFromBackend
    , subscriptions = \_ -> Subscription.none
    , view = view
    }


init : Url -> Effect.Browser.Navigation.Key -> ( Model, Command Command.FrontendOnly ToBackend FrontendMsg )
init _ key =
    ( { key = key
      , message = "Welcome to Lamdera!"
      }
    , Command.none
    )


update : FrontendMsg -> Model -> ( Model, Command Command.FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        UrlClicked _ ->
            ( model, Command.none )

        UrlChanged _ ->
            ( model, Command.none )

        PingClicked ->
            ( model, Effect.Lamdera.sendToBackend PingFromFrontend )

        NoOpFrontendMsg ->
            ( model, Command.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Command Command.FrontendOnly toMsg FrontendMsg )
updateFromBackend msg model =
    case msg of
        PongFromBackend reply ->
            ( { model | message = reply }, Command.none )

        NoOpToFrontend ->
            ( model, Command.none )


view : Model -> Effect.Browser.Document FrontendMsg
view model =
    { title = ""
    , body =
        [ -- Tailwind stylesheet. Lamdera serves public/ statically at the site
          -- root, so public/output.css is reachable at /output.css. A plain
          -- <link> in <head> does nothing under Lamdera, so we inject it here.
          -- ?dev is a content-hash cache-buster stamped by scripts/cachebust.js
          -- (dev watcher + pre-commit) from the hash of output.css, so the URL
          -- changes only when the CSS actually changes.
          Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css?dev=ce95d990" ] []
        , Html.div [ Attr.style "text-align" "center", Attr.style "padding-top" "40px" ]
            [ Html.img [ Attr.src "https://lamdera.app/lamdera-logo-black.png", Attr.width 150 ] []
            , Html.div
                [ Attr.style "font-family" "sans-serif"
                , Attr.style "padding-top" "40px"
                , Attr.attribute "data-testid" "message"
                ]
                [ Html.text model.message ]
            , Html.button
                [ Attr.id "ping-button"
                , Events.onClick PingClicked
                , Attr.style "margin-top" "20px"
                ]
                [ Html.text "Ping" ]
            ]
        ]
    }

