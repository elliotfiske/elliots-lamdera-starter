module Frontend exposing (app, app_)

import Auth.Common
import Auth.Flow
import Effect.Browser
import Effect.Browser.Navigation
import Effect.Command as Command exposing (Command)
import Effect.Lamdera
import Effect.Subscription as Subscription
import Html
import Html.Attributes as Attr
import Html.Events as Events
import Lamdera as L
import OAuth.AuthorizationCode as OAuth
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
init url key =
    let
        baseUrl =
            { url | query = Nothing, fragment = Nothing, path = "/" }

        model =
            { key = key
            , message = "Welcome to Lamdera! Sign in below."
            , authFlow = Auth.Common.Idle
            , authRedirectBaseUrl = baseUrl
            , currentUser = Nothing
            }
    in
    case parseOAuthCallback url of
        Just callbackMethodId ->
            handleAuthCallback model callbackMethodId url

        Nothing ->
            ( model, Command.none )


parseOAuthCallback : Url -> Maybe String
parseOAuthCallback url =
    case String.split "/" url.path |> List.filter (not << String.isEmpty) of
        [ "login", method, "callback" ] ->
            Just method

        _ ->
            Nothing


handleAuthCallback : Model -> String -> Url -> ( Model, Command Command.FrontendOnly ToBackend FrontendMsg )
handleAuthCallback model callbackMethodId url =
    let
        clearUrl =
            Effect.Browser.Navigation.replaceUrl model.key (Url.toString model.authRedirectBaseUrl)
    in
    case OAuth.parseCode url of
        OAuth.Success { code, state } ->
            let
                stateStr =
                    state |> Maybe.withDefault ""

                -- The redirect_uri sent during /authorize is built by the
                -- library as `<base>/login/<method>/callback`. The token
                -- exchange needs the same URL — so send the actual callback
                -- URL (query/fragment stripped) here, NOT authRedirectBaseUrl.
                callbackUrl =
                    { url | query = Nothing, fragment = Nothing }

                toBackendMsg =
                    Auth.Common.AuthCallbackReceived callbackMethodId callbackUrl code stateStr
            in
            ( { model | authFlow = Auth.Common.Authorized code stateStr }
            , Command.batch
                [ Effect.Lamdera.sendToBackend (AuthToBackend toBackendMsg)
                , clearUrl
                ]
            )

        OAuth.Empty ->
            ( { model | authFlow = Auth.Common.Idle }
            , Command.none
            )

        OAuth.Error err ->
            ( { model | authFlow = Auth.Common.Errored (Auth.Common.ErrAuthorization err) }
            , clearUrl
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

        SignInWithGithubClicked ->
            Auth.Flow.signInRequested "OAuthGithub" model Nothing
                |> Tuple.mapSecond (AuthToBackend >> Effect.Lamdera.sendToBackend)

        NoOpFrontendMsg ->
            ( model, Command.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Command Command.FrontendOnly toMsg FrontendMsg )
updateFromBackend msg model =
    case msg of
        PongFromBackend reply ->
            ( { model | message = reply }, Command.none )

        AuthToFrontend authMsg ->
            case authMsg of
                Auth.Common.AuthInitiateSignin signinUrl ->
                    ( model
                    , Effect.Browser.Navigation.load (Url.toString signinUrl)
                    )

                Auth.Common.AuthError err ->
                    ( { model | authFlow = Auth.Common.Errored err }, Command.none )

                Auth.Common.AuthSessionChallenge _ ->
                    ( model, Command.none )

        GotUser userInfo ->
            ( { model | currentUser = Just userInfo, authFlow = Auth.Common.Idle }
            , Command.none
            )

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
          Html.node "link" [ Attr.rel "stylesheet", Attr.href "/output.css?dev=5ab31c17" ] []
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
            , Html.div [ Attr.style "margin-top" "30px", Attr.style "font-family" "sans-serif" ]
                [ viewAuth model ]
            ]
        ]
    }


viewAuth : Model -> Html.Html FrontendMsg
viewAuth model =
    let
        panel children =
            Html.div
                [ Attr.style "max-width" "420px"
                , Attr.style "margin" "0 auto"
                , Attr.style "padding" "16px"
                , Attr.style "border" "1px solid #ddd"
                , Attr.style "border-radius" "8px"
                , Attr.style "text-align" "left"
                , Attr.attribute "data-testid" "auth-panel"
                ]
                children
    in
    case model.currentUser of
        Just user ->
            panel
                [ Html.div [ Attr.style "font-weight" "bold", Attr.style "margin-bottom" "8px" ]
                    [ Html.text "Signed in ✓" ]
                , Html.div [ Attr.attribute "data-testid" "user-display-name" ]
                    [ Html.text (displayName user) ]
                , Html.div [ Attr.style "font-size" "12px", Attr.style "color" "#666", Attr.style "margin-top" "4px" ]
                    [ Html.text ("username: " ++ maybeOrDash user.username) ]
                ]

        Nothing ->
            panel
                [ Html.button
                    [ Attr.id "github-signin"
                    , Events.onClick SignInWithGithubClicked
                    ]
                    [ Html.text "Sign in with GitHub" ]
                , Html.div
                    [ Attr.style "font-size" "12px"
                    , Attr.style "color" "#666"
                    , Attr.style "margin-top" "8px"
                    , Attr.attribute "data-testid" "auth-flow-state"
                    ]
                    [ Html.text ("authFlow: " ++ flowLabel model.authFlow) ]
                ]


displayName : Auth.Common.UserInfo -> String
displayName user =
    case ( user.name, user.username ) of
        ( Just n, _ ) ->
            n

        ( Nothing, Just u ) ->
            u

        ( Nothing, Nothing ) ->
            "(unknown user)"


maybeOrDash : Maybe String -> String
maybeOrDash =
    Maybe.withDefault "—"


flowLabel : Auth.Common.Flow -> String
flowLabel flow =
    case flow of
        Auth.Common.Idle ->
            "Idle"

        Auth.Common.Requested _ ->
            "Requested (redirecting to GitHub…)"

        Auth.Common.Pending ->
            "Pending"

        Auth.Common.Authorized _ _ ->
            "Authorized (exchanging code for token…)"

        Auth.Common.Authenticated _ ->
            "Authenticated"

        Auth.Common.Done _ ->
            "Done"

        Auth.Common.Errored err ->
            "Errored: " ++ errorLabel err


errorLabel : Auth.Common.Error -> String
errorLabel err =
    case err of
        Auth.Common.ErrStateMismatch ->
            "state mismatch"

        Auth.Common.ErrAuthorization _ ->
            "authorization error (check GitHub OAuth App callback URL)"

        Auth.Common.ErrAuthentication _ ->
            "authentication error (token exchange failed — check client secret)"

        Auth.Common.ErrHTTPGetAccessToken ->
            "HTTP error fetching access token"

        Auth.Common.ErrHTTPGetUserInfo ->
            "HTTP error fetching user info"

        Auth.Common.ErrAuthString s ->
            s
