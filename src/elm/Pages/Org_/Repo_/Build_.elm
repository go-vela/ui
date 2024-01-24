{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_ exposing (..)

import Auth
import Components.Logs
import Components.Svgs
import Debug exposing (log)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, code, details, div, small, summary, text)
import Html.Attributes exposing (attribute, class, id)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
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
    , logFollow : Int
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { steps = RemoteData.Loading
      , logs = Dict.empty
      , logLineFocus =
            route.hash
                |> Focus.parseFocusFragment
                |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
      , logFollow = 0
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
    = -- BROWSER
      OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- STEPS
    | GetBuildStepsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ))
    | GetBuildStepLogResponse Vela.Step (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ExpandStep { step : Vela.Step, updateUrlHash : Bool }
    | CollapseStep { step : Vela.Step, updateUrlHash : Bool }
    | ExpandAll
    | CollapseAll
      -- LOGS
    | DownloadLog { filename : String, content : String, map : String -> String }
    | FollowLog { number : Int }


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnHashChanged _ ->
            ( { model
                | logLineFocus =
                    route.hash
                        |> Focus.parseFocusFragment
                        |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
              }
            , Effect.none
            )

        PushUrlHash options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org_Repo_Build_
                        { org = route.params.org
                        , repo = route.params.repo
                        , buildNumber = route.params.buildNumber
                        }
                , query = route.query
                , hash = Just options.hash
                }
            )

        FocusOn options ->
            ( model, Effect.focusOn options )

        -- STEPS
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

        ExpandAll ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map (\step -> ExpandStep { step = step, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        CollapseAll ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map (\step -> CollapseStep { step = step, updateUrlHash = False })
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        -- LOGS
        DownloadLog options ->
            ( model
            , Effect.downloadFile options
            )

        FollowLog options ->
            ( { model | logFollow = options.number }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = ""
    , body =
        [ case model.steps of
            RemoteData.Success steps ->
                if List.length steps > 0 then
                    div []
                        [ div
                            [ class "buttons"
                            , class "log-actions"
                            , class "flowline-left"
                            , Util.testAttribute "log-actions"
                            ]
                            [ Html.button
                                [ class "button"
                                , class "-link"
                                , onClick CollapseAll
                                , Util.testAttribute "collapse-all"
                                ]
                                [ small [] [ text "collapse all" ] ]
                            , Html.button
                                [ class "button"
                                , class "-link"
                                , onClick ExpandAll
                                , Util.testAttribute "expand-all"
                                ]
                                [ small [] [ text "expand all" ] ]
                            ]
                        , div [ class "steps" ]
                            [ div [ class "-items", Util.testAttribute "steps" ] <|
                                List.map (viewStep shared model route) <|
                                    List.sortBy .number <|
                                        RemoteData.withDefault [] model.steps

                            -- if hasStages steps then
                            --     viewStages model msgs rm steps
                            -- else
                            -- List.map viewStep<| steps
                            ]
                        ]

                else
                    div [ class "no-steps" ] [ small [] [ code [] [ text "No steps found for this pipeline." ] ] ]

            _ ->
                Util.smallLoader
        ]
    }


viewStep : Shared.Model -> Model -> Route { org : String, repo : String, buildNumber : String } -> Vela.Step -> Html Msg
viewStep shared model route step =
    let
        stepNumber =
            String.fromInt step.number

        clickStep =
            if step.viewing then
                CollapseStep

            else
                ExpandStep
    in
    div [ Html.Attributes.classList [ ( "step", True ), ( "flowline-left", True ) ], Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ Components.Svgs.statusToIcon step.status ] ]
        , details
            (Html.Attributes.classList
                [ ( "details", True )
                , ( "-with-border", True )
                , ( "-running", step.status == Vela.Running )
                ]
                :: Util.open step.viewing
            )
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ stepNumber
                , onClick <| clickStep { step = step, updateUrlHash = True }
                , id <| "step-" ++ stepNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime shared.time step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml [ attribute "aria-label" "show build actions" ]
                ]
            , div [ class "logs-container" ]
                [ viewLogs shared model route step <|
                    Maybe.withDefault RemoteData.Loading <|
                        Dict.get step.id model.logs
                ]
            ]
        ]


viewLogs : Shared.Model -> Model -> Route { org : String, repo : String, buildNumber : String } -> Vela.Step -> WebData Vela.Log -> Html Msg
viewLogs shared model route step log =
    case step.status of
        Vela.Error ->
            div [ class "message", class "error", Util.testAttribute "resource-error" ]
                [ text <|
                    "error: "
                        ++ (if String.isEmpty step.error then
                                "null"

                            else
                                step.error
                           )
                ]

        Vela.Killed ->
            div [ class "message", class "error", Util.testAttribute "step-skipped" ]
                [ text "step was skipped" ]

        _ ->
            Components.Logs.view
                shared
                { msgs =
                    { pushUrlHash = PushUrlHash
                    , focusOn = FocusOn
                    , download = DownloadLog
                    , follow = FollowLog
                    }
                , log = log
                , org = route.params.org
                , repo = route.params.repo
                , buildNumber = route.params.buildNumber
                , resourceType = "step"
                , resourceNumber = String.fromInt step.number
                , lineFocus =
                    if step.number == Maybe.withDefault -1 (Tuple.first model.logLineFocus) then
                        Just <| Tuple.second model.logLineFocus

                    else
                        Nothing
                , follow = model.logFollow
                }
