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
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Svg.Attributes
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
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
        { baseUrl = shared.velaAPI
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
    = GetRepoSchedulesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Schedule ))
    | GotoPage Int


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
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
                    ( { model | schedules = Errors.toFailure error }
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
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetRepoSchedulesResponse
                    , pageNumber = Just pageNumber
                    , perPage = Dict.get "perPage" route.query |> Maybe.andThen String.toInt
                    , org = route.params.org
                    , repo = route.params.repo
                    }
                ]
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



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
viewRepoSchedules : Shared.Model -> Model -> String -> String -> Html msg
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

                            -- , Routes.href <|
                            --     Routes.AddSchedule org repo
                            ]
                            [ text <| "Add Schedule"
                            , FeatherIcons.plus
                                |> FeatherIcons.withSize 18
                                |> FeatherIcons.toHtml [ Svg.Attributes.class "button-icon" ]
                            ]
                        ]

            else
                Nothing

        ( noRowsView, rows ) =
            if schedulesAllowed then
                case model.schedules of
                    Success s ->
                        ( text "No schedules found for this repo"
                        , schedulesToRows shared.zone org repo s
                        )

                    Failure error ->
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
    List.map (\s -> Components.Table.Row (addKey s) (renderSchedule zone org repo)) schedules


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


{-| renderSchedule : takes schedule and renders a table row
-}
renderSchedule : Time.Zone -> String -> String -> Vela.Schedule -> Html msg
renderSchedule zone org repo schedule =
    tr [ Util.testAttribute <| "schedules-row" ]
        [ td
            [ attribute "data-label" "name"
            , scope "row"
            , class "break-word"
            , class "name"
            , Util.testAttribute <| "schedules-row-name"
            ]
            [ a [ updateScheduleHref org repo schedule ] [ text schedule.name ] ]
        , td
            [ attribute "data-label" "cron expression"
            , scope "row"
            , class "break-word"
            , Util.testAttribute <| "schedules-row-key"
            ]
            [ text <| schedule.entry ]
        , td
            [ attribute "data-label" "enabled"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.boolToYesNo schedule.enabled ]
        , td
            [ attribute "data-label" "branch"
            , scope "row"
            , class "break-word"
            ]
            [ text schedule.branch ]
        , td
            [ attribute "data-label" "scheduled at"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.humanReadableDateTimeWithDefault zone schedule.scheduled_at ]
        , td
            [ attribute "data-label" "updated by"
            , scope "row"
            , class "break-word"
            ]
            [ text <| schedule.updated_by ]
        , td
            [ attribute "data-label" "updated at"
            , scope "row"
            , class "break-word"
            ]
            [ text <| Util.humanReadableDateTimeWithDefault zone schedule.updated_at ]
        ]


{-| updateScheduleHref : takes schedule and returns href link for routing to view/edit schedule page
-}
updateScheduleHref : String -> String -> Vela.Schedule -> Html.Attribute msg
updateScheduleHref org repo s =
    Html.Attributes.style "" ""



-- Routes.href <|
--     Routes.Vela.Schedule org repo s.name


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
