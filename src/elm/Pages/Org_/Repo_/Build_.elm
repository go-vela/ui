{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_ exposing (..)

import Api.Pagination
import Auth
import Components.Logs
import Components.Pager
import Components.Steps
import Components.Svgs as SvgBuilder
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , rows
        , scope
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Utils.Errors as Errors
import Utils.Focus as Focus
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)
        |> Page.withOnHashChanged OnHashChanged



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, buildNumber : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { steps : WebData (List Vela.Step)
    , logs : Dict Int (WebData Vela.Log)
    , logLineFocus : ( Maybe Int, ( Maybe Int, Maybe Int ) )
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { steps = RemoteData.Loading
      , logs = Dict.empty
      , logLineFocus =
            route.hash
                |> Focus.parseFocusFragment
                |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
      }
    , Effect.getBuildSteps
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetBuildStepsResponse
        , pageNumber = Nothing
        , perPage = Nothing
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        }
    )



-- UPDATE


type Msg
    = OnHashChanged { from : Maybe String, to : Maybe String }
    | GetBuildStepsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ))
    | GetBuildStepLogResponse Vela.Step (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ExpandStep { step : Vela.Step, updateUrlHash : Bool }
    | CollapseStep { step : Vela.Step, updateUrlHash : Bool }
    | ExpandSteps
    | CollapseSteps
    | FocusLogLine { identifier : String }
    | DownloadLog { filename : String, content : String, map : String -> String }


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        OnHashChanged _ ->
            ( { model
                | logLineFocus =
                    route.hash
                        |> Focus.parseFocusFragment
                        |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
              }
            , Effect.none
            )

        GetBuildStepsResponse response ->
            case response of
                Ok ( _, steps ) ->
                    let
                        ( steps_, sideEffects ) =
                            steps
                                |> List.map
                                    (\step ->
                                        case model.logLineFocus of
                                            ( Just resourceNumber, _ ) ->
                                                if step.number == resourceNumber then
                                                    ( { step | viewing = True }
                                                    , ExpandStep { step = step, updateUrlHash = False }
                                                        |> Effect.sendMsg
                                                    )

                                                else
                                                    ( { step | viewing = False }, Effect.none )

                                            _ ->
                                                ( { step | viewing = False }, Effect.none )
                                    )
                                |> List.unzip
                                |> Tuple.mapFirst RemoteData.succeed
                                |> Tuple.mapSecond Effect.batch
                    in
                    ( { model
                        | steps =
                            steps_
                      }
                    , sideEffects
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetBuildStepLogResponse step response ->
            case response of
                Ok ( _, log ) ->
                    let
                        logs =
                            Dict.update step.id
                                (Components.Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                    in
                    ( { model | logs = logs }
                    , Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        ExpandStep options ->
            ( { model
                | steps =
                    case model.steps of
                        RemoteData.Success steps ->
                            List.Extra.updateIf
                                (\s -> s.id == options.step.id)
                                (\s -> { s | viewing = True })
                                steps
                                |> RemoteData.succeed

                        _ ->
                            model.steps
              }
            , Effect.batch
                [ Effect.getBuildStepLog
                    { baseUrl = shared.velaAPI
                    , session = shared.session
                    , onResponse = GetBuildStepLogResponse options.step
                    , org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = route.params.buildNumber
                    , stepNumber = String.fromInt options.step.number
                    }
                , if options.updateUrlHash then
                    Effect.pushRoute
                        { path =
                            Route.Path.Org_Repo_Build_
                                { org = route.params.org
                                , repo = route.params.repo
                                , buildNumber = route.params.buildNumber
                                }
                        , query = route.query

                        -- drop the # before applying it to the hash
                        , hash = Just <| "step:" ++ String.fromInt options.step.number
                        }

                  else
                    Effect.none
                ]
            )

        CollapseStep options ->
            ( { model
                | steps =
                    case model.steps of
                        RemoteData.Success steps ->
                            List.Extra.updateIf
                                (\s -> s.id == options.step.id)
                                (\s -> { s | viewing = False })
                                steps
                                |> RemoteData.succeed

                        _ ->
                            model.steps
              }
            , Effect.none
            )

        ExpandSteps ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map (\step -> ExpandStep { step = step, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        CollapseSteps ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map (\step -> CollapseStep { step = step, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        FocusLogLine options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org_Repo_Build_
                        { org = route.params.org
                        , repo = route.params.repo
                        , buildNumber = route.params.buildNumber
                        }
                , query = route.query

                -- drop the # before applying it to the hash
                , hash = Just <| String.dropLeft 1 options.identifier
                }
            )

        DownloadLog options ->
            ( model
            , Effect.downloadFile options
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "#" ++ route.params.buildNumber
    , body =
        [ Components.Steps.view
            shared
            { msgs =
                { expandStep = ExpandStep
                , collapseStep = CollapseStep
                , expandSteps = ExpandSteps
                , collapseSteps = CollapseSteps
                , focusLogLine = FocusLogLine
                , downloadLog = DownloadLog
                }
            , steps = model.steps
            , logs = model.logs
            , org = route.params.org
            , repo = route.params.repo
            , buildNumber = route.params.buildNumber
            , logLineFocus = model.logLineFocus
            }
        ]
    }
