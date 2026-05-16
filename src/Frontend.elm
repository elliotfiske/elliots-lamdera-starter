module Frontend exposing (..)

import Effect.Browser exposing (UrlRequest)
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command)
import Effect.Lamdera
import Effect.Subscription as Subscription exposing (Subscription)
import Html
import Html.Attributes as Attr
import Html.Events as Events
import Lamdera as L
import Types exposing (..)
import Url


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
    , subscriptions = \m -> Subscription.none
    , view = view
    }


init : Url.Url -> Effect.Browser.Navigation.Key -> ( Model, Command restriction toMsg FrontendMsg )
init url key =
    ( { key = key
      , message = "Welcome to Lamdera! You're looking at the auto-generated base implementation. Check out src/Frontend.elm to start coding!"
      }
    , Command.none
    )


update : FrontendMsg -> Model -> ( Model, Command Command.FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        UrlClicked _ ->
            -- Currently unneeded (everything is on one page)
            ( model, Command.none )

        UrlChanged _ ->
            -- Currently unneeded (everything is on one page)
            ( model, Command.none )

        PingClicked ->
            ( model, Effect.Lamdera.sendToBackend PingFromFrontend )

        NoOpFrontendMsg ->
            ( model, Command.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Command restriction toMsg FrontendMsg )
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
        [ Html.div [ Attr.style "text-align" "center", Attr.style "padding-top" "40px" ]
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
