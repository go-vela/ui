{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_ exposing (..)

import Auth
import Browser.Dom exposing (focus)
import Components.Loading
import Components.Logs
import Components.Svgs
import Debug exposing (log)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, button, code, details, div, small, summary, text)
import Html.Attributes exposing (attribute, class, classList)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Time
import Utils.Errors as Errors
import Utils.Focus as Focus
import Utils.Helpers as Util
import Utils.Interval as Interval
import Utils.Logs as Logs
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns a build page.
-}
page : Auth.User -> Shared.Model -> Route { org : String, repo : String, build : String } -> Page Model Msg
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


{-| toLayout : takes user, route, model, and passes a build page's info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String, build : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Build"
              , content =
                    "vela view build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/view"
              }
            , { name = "Approve Build"
              , content =
                    "vela approve build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/approve"
              }
            , { name = "Restart Build"
              , content =
                    "vela restart build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/restart"
              }
            , { name = "Cancel Build"
              , content =
                    "vela cancel build --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "build/cancel"
              }
            , { name = "List Steps"
              , content =
                    "vela get steps --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "step/get"
              }
            , { name = "View Step"
              , content =
                    "vela view step --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
                        ++ " --step 1"
              , docs = Just "step/view"
              }
            , { name = "List Logs"
              , content =
                    "vela get logs --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
              , docs = Just "log/get"
              }
            , { name = "View Log Help"
              , content = "vela view log -h"
              , docs = Just "log/view"
              }
            , { name = "View Log Example"
              , content =
                    "vela view log --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
                        ++ " --build "
                        ++ route.params.build
                        ++ " --step 1"
              , docs = Just "log/view"
              }
            ]
        , crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "#" ++ route.params.build, Nothing )
            ]
        , org = route.params.org
        , repo = route.params.repo
        , build = route.params.build
        , toBuildPath =
            \build ->
                Route.Path.Org__Repo__Build_
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


{-| Model : alias for a model object for a build page.
-}
type alias Model =
    { steps : WebData (List Vela.Step)
    , logs : Dict Int (WebData Vela.Log)
    , viewing : List Int
    , focus : Focus.Focus
    , logFollow : Int
    }


{-| init : takes shared model, route, and initializes build page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { steps = RemoteData.Loading
      , logs = Dict.empty
      , viewing = []
      , focus = Focus.fromString route.hash
      , logFollow = 0
      }
    , Effect.batch
        [ Effect.getBuildSteps
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse =
                GetBuildStepsResponse
                    { applyDomFocus =
                        route.query
                            |> Dict.get "tab_switch"
                            |> Maybe.withDefault "false"
                            |> (==) "false"
                    }
            , pageNumber = Nothing
            , perPage = Just 100
            , org = route.params.org
            , repo = route.params.repo
            , build = route.params.build
            }
        , Effect.none
        ]
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
      -- BROWSER
    | OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- STEPS
    | GetBuildStepsResponse { applyDomFocus : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ))
    | GetBuildStepsRefreshResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ))
    | GetBuildStepLogResponse { step : Vela.Step, applyDomFocus : Bool, previousFocus : Maybe Focus.Focus } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | GetBuildStepLogRefreshResponse { step : Vela.Step } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ))
    | ClickStep { step : Vela.Step }
    | ExpandStep { step : Vela.Step, applyDomFocus : Bool, previousFocus : Maybe Focus.Focus, triggeredFromClick : Bool }
    | CollapseStep { step : Vela.Step }
    | ExpandAll
    | CollapseAll
      -- LOGS
    | DownloadLog { filename : String, content : String, map : String -> String }
    | FollowLog { number : Int }
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        -- BROWSER
        OnHashChanged options ->
            let
                focus =
                    Focus.fromString options.to
            in
            ( { model
                | focus = focus
              }
            , RemoteData.withDefault [] model.steps
                |> List.filter (\s -> Maybe.withDefault -1 focus.group == s.number)
                |> List.map
                    (\s ->
                        ExpandStep
                            { step = s
                            , applyDomFocus = True
                            , previousFocus = Just model.focus
                            , triggeredFromClick = False
                            }
                    )
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        PushUrlHash options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org__Repo__Build_
                        { org = route.params.org
                        , repo = route.params.repo
                        , build = route.params.build
                        }
                , query = route.query
                , hash = Just options.hash
                }
            )

        FocusOn options ->
            ( model
            , Effect.focusOn options
            )

        -- STEPS
        GetBuildStepsResponse options response ->
            case response of
                Ok ( _, steps ) ->
                    ( { model | steps = RemoteData.succeed <| List.sortBy .number steps }
                    , steps
                        |> List.Extra.find (\step -> Maybe.withDefault -1 model.focus.group == step.number)
                        |> Maybe.map
                            (\step ->
                                ExpandStep
                                    { step = step
                                    , applyDomFocus = options.applyDomFocus
                                    , previousFocus = Nothing
                                    , triggeredFromClick = False
                                    }
                                    |> Effect.sendMsg
                            )
                        |> Maybe.withDefault Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetBuildStepsRefreshResponse response ->
            case response of
                Ok ( _, steps ) ->
                    ( { model | steps = RemoteData.succeed <| List.sortBy .number steps }
                    , steps
                        |> List.filter (\step -> List.member step.number model.viewing)
                        -- note: it's possible that there are log updates in flight
                        -- even after the step has a status of finished, especially
                        -- for large logs. we get the most recent version of logs
                        -- on page load or when a step log is expanded, so potentially
                        -- seeing incomplete logs here is only a concern when someone
                        -- is following the logs live.
                        |> List.filter (\step -> step.finished == 0)
                        |> List.map
                            (\step ->
                                Effect.getBuildStepLog
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetBuildStepLogRefreshResponse { step = step }
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , build = route.params.build
                                    , stepNumber = String.fromInt step.number
                                    }
                            )
                        |> Effect.batch
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetBuildStepLogResponse options response ->
            case response of
                Ok ( _, log ) ->
                    ( { model
                        | logs =
                            Dict.update options.step.id
                                (Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                      }
                    , if options.applyDomFocus then
                        case ( model.focus.group, model.focus.a, model.focus.b ) of
                            ( Just g, Just _, Just _ ) ->
                                FocusOn
                                    { target =
                                        Focus.toDomTarget
                                            { group = Just g
                                            , a = Focus.lineNumberChanged options.previousFocus model.focus
                                            , b = Nothing
                                            }
                                    }
                                    |> Effect.sendMsg

                            ( Just g, Just a, _ ) ->
                                FocusOn
                                    { target =
                                        Focus.toDomTarget
                                            { group = Just g
                                            , a = Just a
                                            , b = Nothing
                                            }
                                    }
                                    |> Effect.sendMsg

                            _ ->
                                Effect.none

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetBuildStepLogRefreshResponse options response ->
            case response of
                Ok ( _, log ) ->
                    let
                        changed =
                            Dict.get options.step.id model.logs
                                |> Maybe.Extra.unwrap log (RemoteData.withDefault log)
                                |> (\l -> l.rawData /= log.rawData)
                    in
                    ( { model
                        | logs =
                            Dict.update options.step.id
                                (Logs.safeDecodeLogData shared.velaLogBytesLimit log)
                                model.logs
                      }
                    , if model.logFollow == options.step.number && changed then
                        FocusOn { target = Logs.bottomTrackerFocusId (String.fromInt options.step.number) }
                            |> Effect.sendMsg

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | steps = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ClickStep options ->
            ( model
            , if List.member options.step.number model.viewing then
                CollapseStep { step = options.step }
                    |> Effect.sendMsg

              else
                Effect.batch
                    [ ExpandStep
                        { step = options.step
                        , applyDomFocus = False
                        , previousFocus = Nothing
                        , triggeredFromClick = True
                        }
                        |> Effect.sendMsg
                    , case model.focus.a of
                        Nothing ->
                            PushUrlHash
                                { hash =
                                    Focus.toString
                                        { group = Just options.step.number
                                        , a = Nothing
                                        , b = Nothing
                                        }
                                }
                                |> Effect.sendMsg

                        _ ->
                            Effect.none
                    ]
            )

        ExpandStep options ->
            let
                isFromHashChanged =
                    options.previousFocus /= Nothing

                didFocusChange =
                    case options.previousFocus of
                        Just f ->
                            f.group /= model.focus.group

                        Nothing ->
                            False

                -- hash will change when no line is selected and the selected group changes
                -- this means expansion msg will double up on fetching logs unless instructed not to
                willFocusChange =
                    case ( model.focus.group, model.focus.a, model.focus.b ) of
                        ( Just g, Nothing, _ ) ->
                            g /= options.step.number

                        _ ->
                            False

                isLogLoaded =
                    Dict.get options.step.id model.logs
                        |> Maybe.withDefault RemoteData.Loading
                        |> Util.isLoaded

                -- fetch logs when expansion msg meets the criteria:
                -- triggered by a click that will change the hash
                -- the focus changes and the logs are not loaded
                fetchLogs =
                    not (options.triggeredFromClick && willFocusChange)
                        && ((didFocusChange && not isLogLoaded) || not isFromHashChanged)

                getLogEffect =
                    Effect.getBuildStepLog
                        { baseUrl = shared.velaAPIBaseURL
                        , session = shared.session
                        , onResponse =
                            GetBuildStepLogResponse
                                { step = options.step
                                , applyDomFocus = options.applyDomFocus
                                , previousFocus = options.previousFocus
                                }
                        , org = route.params.org
                        , repo = route.params.repo
                        , build = route.params.build
                        , stepNumber = String.fromInt options.step.number
                        }

                applyDomFocusEffect =
                    case ( model.focus.group, model.focus.a, model.focus.b ) of
                        ( Just g, Nothing, Nothing ) ->
                            FocusOn
                                { target =
                                    Focus.toDomTarget
                                        { group = Just g
                                        , a = Nothing
                                        , b = Nothing
                                        }
                                }
                                |> Effect.sendMsg

                        _ ->
                            Effect.none

                runEffects =
                    [ if fetchLogs then
                        getLogEffect

                      else
                        Effect.none
                    , if options.applyDomFocus then
                        applyDomFocusEffect

                      else
                        Effect.none
                    ]
            in
            ( { model
                | viewing = List.Extra.unique <| options.step.number :: model.viewing
              }
            , Effect.batch runEffects
            )

        CollapseStep options ->
            ( { model
                | viewing = List.Extra.remove options.step.number model.viewing
                , logs =
                    Dict.update options.step.id
                        (\_ -> Nothing)
                        model.logs
                , logFollow =
                    if model.logFollow == options.step.number then
                        0

                    else
                        model.logFollow
              }
            , Effect.none
            )

        ExpandAll ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map
                    (\step ->
                        ExpandStep
                            { step = step
                            , applyDomFocus = False
                            , previousFocus = Nothing
                            , triggeredFromClick = False
                            }
                    )
                |> List.map Effect.sendMsg
                |> Effect.batch
            )

        CollapseAll ->
            ( model
            , model.steps
                |> RemoteData.withDefault []
                |> List.map (\step -> CollapseStep { step = step })
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

        -- REFRESH
        Tick options ->
            let
                isAnyStepRunning =
                    case model.steps of
                        RemoteData.Success steps ->
                            List.any (\s -> s.finished == 0) steps

                        _ ->
                            False

                runEffect =
                    if isAnyStepRunning then
                        Effect.getBuildSteps
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetBuildStepsRefreshResponse
                            , pageNumber = Nothing
                            , perPage = Just 100
                            , org = route.params.org
                            , repo = route.params.repo
                            , build = route.params.build
                            }

                    else
                        Effect.none
            in
            ( model
            , runEffect
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns the subscriptions for auto refreshing the page.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for a build page.
-}
view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
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
                            [ button
                                [ class "button"
                                , class "-link"
                                , onClick CollapseAll
                                , Util.testAttribute "collapse-all"
                                ]
                                [ small [] [ text "collapse all" ] ]
                            , button
                                [ class "button"
                                , class "-link"
                                , onClick ExpandAll
                                , Util.testAttribute "expand-all"
                                ]
                                [ small [] [ text "expand all" ] ]
                            ]
                        , div [ class "steps" ]
                            [ div [ class "-items", Util.testAttribute "steps" ] <|
                                if hasStages steps then
                                    viewStages shared model route steps

                                else
                                    List.map (viewStep shared model route) steps
                            ]
                        ]

                else
                    div [ class "no-steps" ] [ small [] [ code [] [ text "No steps found for this pipeline." ] ] ]

            _ ->
                Components.Loading.viewSmallLoader
        ]
    }


{-| viewStages : renders a list of stages.
-}
viewStages : Shared.Model -> Model -> Route { org : String, repo : String, build : String } -> List Vela.Step -> List (Html Msg)
viewStages shared model route steps =
    steps
        |> List.map .stage
        |> List.Extra.unique
        |> List.map
            (\stage ->
                steps
                    |> List.filter
                        (\step ->
                            (stage == "init" && (step.stage == "init" || step.stage == "clone"))
                                || (stage /= "clone" && step.stage == stage)
                        )
                    |> viewStage shared model route stage
            )


{-| viewStep : renders a stage component on a build page.
-}
viewStage : Shared.Model -> Model -> Route { org : String, repo : String, build : String } -> String -> List Vela.Step -> Html Msg
viewStage shared model route stage steps =
    div
        [ class "stage", Util.testAttribute <| "stage" ]
        [ viewStageDivider stage
        , steps
            |> List.map (\step -> viewStep shared model route step)
            |> div [ Util.testAttribute <| "stage-" ++ stage ]
        ]


{-| viewStep : renders a step component on a build page.
-}
viewStep : Shared.Model -> Model -> Route { org : String, repo : String, build : String } -> Vela.Step -> Html Msg
viewStep shared model route step =
    div
        [ classList
            [ ( "step", True )
            , ( "flowline-left", True )
            ]
        , Util.testAttribute "step"
        ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ Components.Svgs.statusToIcon step.status ] ]
        , details
            (classList
                [ ( "details", True )
                , ( "-with-border", True )
                , ( "-running", step.status == Vela.Running )
                ]
                :: Util.open (List.member step.number model.viewing)
            )
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ String.fromInt step.number
                , onClick <| ClickStep { step = step }
                , Focus.toAttr
                    { group = Just step.number
                    , a = Nothing
                    , b = Nothing
                    }
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime shared.time step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.withClass "details-icon-expand"
                    |> FeatherIcons.toHtml
                        [ attribute "aria-label" <| "show build step " ++ step.name
                        ]
                ]
            , div [ class "logs-container" ]
                [ viewLogs shared model route step <|
                    Maybe.withDefault RemoteData.Loading <|
                        Dict.get step.id model.logs
                ]
            ]
        ]


{-| viewStageDivider : renders divider between stages.
-}
viewStageDivider : String -> Html msg
viewStageDivider stage =
    if stage /= "init" && stage /= "clone" then
        div [ class "divider", Util.testAttribute <| "stage-divider-" ++ stage ]
            [ div [] [ text stage ] ]

    else
        text ""


{-| hasStages : takes steps and returns true if the pipeline contain stages.
-}
hasStages : List Vela.Step -> Bool
hasStages steps =
    steps
        |> List.filter (\s -> s.stage /= "")
        |> List.head
        |> Maybe.Extra.unwrap "" .stage
        |> (\stage -> stage /= "")


{-| viewLogs : renders a log component for a build step.
-}
viewLogs : Shared.Model -> Model -> Route { org : String, repo : String, build : String } -> Vela.Step -> WebData Vela.Log -> Html Msg
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
                , shift = shared.shift
                , log = log
                , org = route.params.org
                , repo = route.params.repo
                , build = route.params.build
                , resourceType = "step"
                , resourceNumber = String.fromInt step.number
                , focus = model.focus
                , follow = model.logFollow
                }
