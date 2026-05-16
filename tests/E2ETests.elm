module E2ETests exposing (appTests, main)

import Backend
import Effect.Browser.Dom as Dom
import Effect.Lamdera
import Effect.Test exposing (HttpResponse(..))
import Effect.Time
import Frontend
import Html.Attributes
import Test exposing (describe)
import Test.Html.Query
import Test.Html.Selector
import Types exposing (BackendModel, BackendMsg, FrontendModel, FrontendMsg, ToBackend, ToFrontend)
import Url exposing (Url)


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ Effect.Test.start
        "Ping button round-trip updates the message"
        (Effect.Time.millisToPosix 1767225600000)
        config
        [ Effect.Test.connectFrontend
            1000
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            { width = 800, height = 600 }
            (\client ->
                [ client.checkView 100
                    (findByTestId "message"
                        >> Test.Html.Query.has [ Test.Html.Selector.text "Welcome to Lamdera!" ]
                    )
                , client.click 100 (Dom.id "ping-button")
                , client.checkView 200
                    (findByTestId "message"
                        >> Test.Html.Query.has [ Test.Html.Selector.text "Pong!" ]
                    )
                ]
            )
        ]
    ]


appTests : Test.Test
appTests =
    describe "App tests" (List.map Effect.Test.toTest tests)


findByTestId : String -> Test.Html.Query.Single msg -> Test.Html.Query.Single msg
findByTestId testId =
    Test.Html.Query.find
        [ Test.Html.Selector.attribute (Html.Attributes.attribute "data-testid" testId) ]


safeUrl : Url
safeUrl =
    { protocol = Url.Https
    , host = "lamdera-starter.lamdera.app"
    , port_ = Nothing
    , path = "/"
    , query = Nothing
    , fragment = Nothing
    }


config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = always NetworkErrorResponse
    , handlePortToJs = always Nothing
    , handleFileUpload = always Effect.Test.UnhandledFileUpload
    , handleMultipleFilesUpload = always Effect.Test.UnhandledMultiFileUpload
    , domain = safeUrl
    }
