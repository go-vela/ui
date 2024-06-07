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
        ( br
        , code
        , div
        , h1
        , main_
        , p
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
import Utils.Favicons as Favicons
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns the dashboard page.
-}
page : Auth.User -> Shared.Model -> Route { dashboard : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, model, and passes the dashboard page info to Layouts.
-}
toLayout : Auth.User -> Route { dashboard : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "View Dashboard"
              , content =
                    "vela view dashboard --id "
                        ++ route.params.dashboard
              , docs = Just "dashboard/view"
              }
            , { name = "Update Dashboard To Change Name"
              , content =
                    "vela update dashboard --id "
                        ++ route.params.dashboard
                        ++ " --name new-name"
              , docs = Just "dashboard/update"
              }
            , { name = "Update Dashboard To Add A Repository"
              , content =
                    "vela update dashboard --id "
                        ++ route.params.dashboard
                        ++ " --add-repos org/repo"
              , docs = Just "dashboard/update"
              }
            , { name = "Update Dashboard To Add An Admin"
              , content =
                    "vela update dashboard --id "
                        ++ route.params.dashboard
                        ++ " --add-admins username"
              , docs = Just "dashboard/update"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for the dashboard page.
-}
type alias Model =
    { dashboard : WebData Vela.Dashboard }


{-| init : takes shared model and initializes dashboard page input arguments.
-}
init : Shared.Model -> Route { dashboard : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { dashboard = RemoteData.Loading }
    , Effect.getDashboard
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetDashboardResponse
        , dashboardId = route.params.dashboard
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = GetDashboardResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Dashboard ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current model, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { dashboard : String } -> Msg -> Model -> ( Model, Effect Msg )
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
                , dashboardId = route.params.dashboard
                }
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Interval.tickEveryFiveSeconds Tick
        ]



-- VIEW


{-| view : takes models, route, and creates the html for the dashboard page.
-}
view : Shared.Model -> Route { dashboard : String } -> Model -> View Msg
view shared route model =
    let
        dashboardName =
            case model.dashboard of
                RemoteData.Success dashboard ->
                    dashboard.dashboard.name

                RemoteData.Loading ->
                    ""

                _ ->
                    "Unknown"

        pageTitle =
            dashboardName ++ " Dashboard"

        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( "Dashboards", Nothing )
            , ( dashboardName, Nothing )
            ]
    in
    { title = pageTitle
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "dashboard", Util.testAttribute "dashboard" ]
                (case model.dashboard of
                    RemoteData.Success dashboard ->
                        [ h1 [ class "dashboard-title" ] [ text dashboard.dashboard.name ]
                        , div [ class "cards" ]
                            (if List.isEmpty dashboard.repos then
                                [ p
                                    []
                                    [ text "This dashboard doesn't have repositories added yet. Add some with the CLI:"
                                    , br [] []
                                    , code [ class "shell" ]
                                        [ text ("vela update dashboard --id " ++ route.params.dashboard ++ " --add-repos org/repo") ]
                                    ]
                                ]

                             else
                                List.map
                                    (\repo ->
                                        Components.DashboardRepoCard.view shared
                                            { card = repo
                                            }
                                    )
                                    dashboard.repos
                            )
                        ]

                    RemoteData.Failure error ->
                        [ span []
                            [ text <|
                                case error of
                                    Http.BadStatus statusCode ->
                                        case statusCode of
                                            401 ->
                                                "Unauthorized to retrieve dashboard"

                                            404 ->
                                                "Dashboard \"" ++ route.params.dashboard ++ "\" not found. Please check the URL."

                                            _ ->
                                                "No dashboard found, there was an error with the server"

                                    _ ->
                                        "No dashboard found, there was an error with the server"
                            ]
                        ]

                    _ ->
                        [ Components.Loading.viewSmallLoader ]
                )
            ]
        ]
    }
