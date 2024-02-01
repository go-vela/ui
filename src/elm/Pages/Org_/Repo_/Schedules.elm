{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Schedules exposing (Model, Msg, page, view)

import Api.Pagination
import Auth
import Components.Pager
import Components.Table
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Time
import Utils.Errors
import Utils.Favorites as Favorites
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Repo
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        }



-- INIT


type alias Model =
    { schedules : WebData (List Vela.Schedule)
    , pager : List WebLink
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { schedules = RemoteData.Loading
      , pager = []
      }
    , Effect.getRepoSchedules
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetRepoSchedulesResponse
        , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
        , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = -- SCHEDULES
      GetRepoSchedulesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Schedule ))
    | GotoPage Int
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SCHEDULES
        GetRepoSchedulesResponse response ->
            case response of
                Ok ( meta, schedules ) ->
                    ( { model
                        | schedules = RemoteData.Success schedules
                        , pager = Api.Pagination.get meta.headers
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | schedules = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GotoPage pageNumber ->
            ( model
            , Effect.batch
                [ Effect.replaceRoute
                    { path = route.path
                    , query =
                        Dict.update "page" (\_ -> Just <| String.fromInt pageNumber) route.query
                    , hash = route.hash
                    }
                , Effect.getRepoSchedules
                    { baseUrl = shared.velaAPIBaseURL
                    , session = shared.session
                    , onResponse = GetRepoSchedulesResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getRepoSchedules
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetRepoSchedulesResponse
                , pageNumber = Dict.get "page" route.query |> Maybe.andThen String.toInt
                , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                , org = route.params.org
                , repo = route.params.repo
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Schedules"
    , body =
        [ viewRepoSchedules shared model route.params.org route.params.repo
        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
        ]
    }


{-| viewRepoSchedules : takes schedules model and renders table for viewing repo schedules
-}
viewRepoSchedules : Shared.Model -> Model -> String -> String -> Html Msg
viewRepoSchedules shared model org repo =
    let
        schedulesAllowed =
            Util.checkScheduleAllowlist org repo shared.velaScheduleAllowlist

        actions =
            if schedulesAllowed then
                Just <|
                    div [ class "buttons" ]
                        [ a
                            [ class "button"
                            , class "button-with-icon"
                            , class "-outline"
                            , Util.testAttribute "add-repo-schedule"
                            , Route.Path.href <|
                                Route.Path.Org_Repo_SchedulesAdd
                                    { org = org
                                    , repo = repo
                                    }
                            ]
                            [ text <| "Add Schedule"
                            , FeatherIcons.plus
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                            ]
                        , Components.Pager.view model.pager Components.Pager.defaultLabels GotoPage
                        ]

            else
                Nothing

        ( noRowsView, rows ) =
            if schedulesAllowed then
                case model.schedules of
                    RemoteData.Success s ->
                        ( text "No schedules found for this repo"
                        , schedulesToRows shared.zone org repo s
                        )

                    RemoteData.Failure error ->
                        ( span [ Util.testAttribute "repo-schedule-error" ]
                            [ text <|
                                case error of
                                    Http.BadStatus statusCode ->
                                        case statusCode of
                                            401 ->
                                                "No schedules found for this repo, most likely due to not being an admin of the source control repo"

                                            _ ->
                                                "No schedules found for this repo, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                    _ ->
                                        "No schedules found for this repo, there was an error with the server"
                            ]
                        , []
                        )

                    _ ->
                        ( Util.largeLoader, [] )

            else
                ( viewSchedulesNotAllowedSpan
                , []
                )

        cfg =
            Components.Table.Config
                "Schedules"
                "repo-schedules"
                noRowsView
                tableHeaders
                rows
                actions
    in
    div [] [ Components.Table.view cfg ]


{-| schedulesToRows : takes list of schedules and produces list of Table rows
-}
schedulesToRows : Time.Zone -> String -> String -> List Vela.Schedule -> Components.Table.Rows Vela.Schedule msg
schedulesToRows zone org repo schedules =
    List.map (\s -> Components.Table.Row (addKey s) (viewSchedule zone org repo)) schedules


{-| tableHeaders : returns table headers for schedules table
-}
tableHeaders : Components.Table.Columns
tableHeaders =
    [ ( Nothing, "name" )
    , ( Nothing, "entry" )
    , ( Nothing, "enabled" )
    , ( Nothing, "branch" )
    , ( Nothing, "last scheduled at" )
    , ( Nothing, "updated by" )
    , ( Nothing, "updated at" )
    ]


{-| viewSchedule : takes schedule and renders a table row
-}
viewSchedule : Time.Zone -> String -> String -> Vela.Schedule -> Html msg
viewSchedule zone org repo schedule =
    tr [ Util.testAttribute <| "schedules-row" ]
        [ Components.Table.viewItemCell
            { dataLabel = "name"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ a
                    [ Route.Path.href <|
                        Route.Path.Org_Repo_SchedulesEdit_
                            { org = org
                            , repo = repo
                            , name = schedule.name
                            }
                    ]
                    [ text schedule.name ]
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "cron expression"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text schedule.entry
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "enabled"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.boolToYesNo schedule.enabled
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "branch"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text schedule.branch
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "scheduled at"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault zone schedule.scheduled_at
                ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "updated by"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text schedule.updated_by ]
            }
        , Components.Table.viewItemCell
            { dataLabel = "updated at"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text <| Util.humanReadableDateTimeWithDefault zone schedule.updated_at ]
            }
        ]


{-| addKey : helper to create Vela.Schedule key
-}
addKey : Vela.Schedule -> Vela.Schedule
addKey schedule =
    { schedule | org = schedule.org ++ "/" ++ schedule.repo ++ "/" ++ schedule.name }


{-| viewSchedulesNotAllowedSpan : renders a warning that schedules have not been enabled for the current repository.
-}
viewSchedulesNotAllowedSpan : Html msg
viewSchedulesNotAllowedSpan =
    span [ class "not-allowed", Util.testAttribute "repo-schedule-not-allowed" ]
        [ text "Sorry, Administrators have not enabled Schedules for this repository."
        ]