{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Dashboards exposing (Model, Msg, page)

import Auth
import Components.Crumbs
import Components.Loading
import Components.Nav
import Effect exposing (Effect)
import Html exposing (Html, a, code, div, h1, h2, hr, li, main_, p, span, text, ul)
import Html.Attributes exposing (class)
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


{-| page : takes user, shared model, route, and returns the dashboards page.
-}
page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


{-| toLayout : takes user, model, and passes the dashboards page info to Layouts.
-}
toLayout : Auth.User -> Route () -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "List Dashboards"
              , content = "vela get dashboards"
              , docs = Just "dashboard/get"
              }
            , { name = "Add Dashboard"
              , content = "vela add dashboard --name MyDashboard"
              , docs = Just "dashboard/add"
              }
            , { name = "Add Dashboard With Repositories"
              , content = "vela add dashboard --name MyDashboard --repos org1/repo1,org2/repo1"
              , docs = Just "dashboard/add"
              }
            , { name = "Add Dashboard With Repositories And Filters"
              , content = "vela add dashboard --name MyDashboard --repos org1/repo1,org2/repo1 --branch main --event push"
              , docs = Just "dashboard/add"
              }
            , { name = "Add Dashboard With Multiple Admins"
              , content = "vela add dashboard --name MyDashboard --admins username1,username2"
              , docs = Just "dashboard/add"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for the dashboards page.
-}
type alias Model =
    { dashboards : WebData (List Vela.Dashboard) }


{-| init : takes shared model and initializes dashboards page input arguments.
-}
init : Shared.Model -> Route () -> () -> ( Model, Effect Msg )
init shared route () =
    ( { dashboards = RemoteData.Loading }
    , Effect.getDashboards
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetDashboardsResponse
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = GetDashboardsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Dashboard ))
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current model, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetDashboardsResponse response ->
            case response of
                Ok ( _, dashboards ) ->
                    ( { model | dashboards = RemoteData.Success dashboards }
                    , Effect.none
                    )

                Err error ->
                    ( { model | dashboards = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for the dashboards page.
-}
view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( "Dashboards", Nothing )
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
            [ div [ Util.testAttribute "dashboards" ] <|
                case model.dashboards of
                    RemoteData.Success dashboards ->
                        if List.length dashboards > 0 then
                            [ div [ class "dashboards" ]
                                [ h1 [] [ text "Dashboards (beta)" ]
                                , viewDashboards dashboards
                                , h2 [] [ text "🧪 Beta Limitations" ]
                                , p [] [ text "This is an early version of Dashboards. Please be aware of the following:" ]
                                , ul []
                                    [ li [] [ text "You have to use CLI/API to manage dashboards" ]
                                    , li [] [ text "You can only list dashboards you created" ]
                                    , li [] [ text "Bookmark or save links to dashboards you didn't create" ]
                                    ]
                                , h2 [] [ text "💬 Got Feedback?" ]
                                , p [] [ text "Help us shape Dashboards. What do you want to see? Use the \"feedback\" link in the top right!" ]
                                ]
                            ]

                        else
                            [ div [ class "dashboards" ]
                                [ h1 [] [ text "Welcome to Dashboards (beta)!" ]
                                , h2 [] [ text "✨ Want to create a new dashboard?" ]
                                , p [] [ text "Use the Vela CLI to add a new dashboard:" ]
                                , code [ class "shell" ] [ text "vela add dashboard --help" ]
                                , h2 [] [ text "💬 Got Feedback?" ]
                                , p [] [ text "Follow the link in the top right to let us know your thoughts and ideas." ]
                                ]
                            ]

                    RemoteData.Failure error ->
                        [ span []
                            [ text <|
                                case error of
                                    Http.BadStatus statusCode ->
                                        case statusCode of
                                            401 ->
                                                "Unauthorized to retrieve dashboards"

                                            _ ->
                                                "No dashboards found, there was an error with the server"

                                    _ ->
                                        "No dashboards found, there was an error with the server"
                            ]
                        ]

                    _ ->
                        [ Components.Loading.viewSmallLoader ]
            ]
        ]
    }


{-| viewDashboards : renders a list of dashboard id links.
-}
viewDashboards : List Vela.Dashboard -> Html Msg
viewDashboards dashboards =
    div [ class "repo-list" ]
        (List.map
            (\dashboard ->
                div [ class "item" ]
                    [ a [ Route.Path.href <| Route.Path.Dashboards_Dashboard_ { dashboard = dashboard.dashboard.id } ]
                        [ text dashboard.dashboard.name ]
                    , div [ class "buttons" ]
                        [ a [ class "button", Route.Path.href <| Route.Path.Dashboards_Dashboard_ { dashboard = dashboard.dashboard.id } ] [ text "View" ]
                        ]
                    ]
            )
            dashboards
        )
