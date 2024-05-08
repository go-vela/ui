{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Dashboards.Dashboard_ exposing (Model, Msg, page)

import Auth
import Components.Crumbs
import Components.DashboardRepoCard
import Components.Loading
import Components.Nav
import Effect exposing (Effect)
import Html
    exposing
        ( div
        , h1
        , main_
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        )
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { dashboardId : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { dashboardId : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = ""
              , content = "resources on this page not yet supported via the CLI"
              , docs = Nothing
              }
            ]
        }



-- INIT


type alias Model =
    { dashboard : WebData Vela.Dashboard }


init : Shared.Model -> Route { dashboardId : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { dashboard = RemoteData.Loading }
    , Effect.getDashboard
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse =
            GetDashboardResponse
        , dashboardId = route.params.dashboardId
        }
    )



-- UPDATE


type Msg
    = GetDashboardResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Dashboard ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { dashboardId : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetDashboardResponse response ->
            case response of
                Ok ( _, dashboard ) ->
                    ( { model | dashboard = RemoteData.Success dashboard }
                    , Effect.none
                    )

                Err error ->
                    ( { model | dashboard = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        Tick options ->
            ( model
            , Effect.getDashboard
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetDashboardResponse
                , dashboardId = route.params.dashboardId
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interval.tickEveryFiveSeconds Tick
        ]



-- VIEW


view : Shared.Model -> Route { dashboardId : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( "Dashboards", Nothing )
            , ( route.params.dashboardId, Nothing )
            ]
    in
    { title = "Dashboards"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "dashboard", Util.testAttribute "dashboard" ]
                [ case model.dashboard of
                    RemoteData.Success dashboard ->
                        div []
                            [ h1 [ class "dashboard-title" ] [ text dashboard.dashboard.name ]
                            , div [ class "cards" ]
                                (List.map
                                    (\repo ->
                                        Components.DashboardRepoCard.view shared
                                            { card = repo
                                            }
                                    )
                                    dashboard.repos
                                )
                            ]

                    RemoteData.Failure error ->
                        span []
                            [ text <|
                                case error of
                                    Http.BadStatus statusCode ->
                                        case statusCode of
                                            401 ->
                                                "Unauthorized to retrieve dashboard"

                                            404 ->
                                                "No dashboard found"

                                            _ ->
                                                "No dashboard found; there was an error with the server"

                                    _ ->
                                        "No dashboard found; there was an error with the server"
                            ]

                    _ ->
                        Components.Loading.viewSmallLoader
                ]
            ]
        ]
    }
