{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Pipeline exposing (..)

import Ansi.Log
import Array
import Auth
import Components.Loading
import Components.Svgs
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, a, button, code, details, div, small, span, strong, summary, table, td, text, tr)
import Html.Attributes exposing (attribute, class, disabled, href, id, title)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Ansi
import Utils.Errors as Errors
import Utils.Focus as Focus
import Utils.Helpers as Util
import Utils.Warnings as Warnings
import Vela
import View exposing (View)


{-| page : takes user, shared model, route, and returns a build's pipeline page.
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
        |> Page.withOnQueryParameterChanged { key = "expand", onChange = OnExpandQueryParameterChanged }



-- LAYOUT


{-| toLayout : takes user, route, model, and passes a build's pipeline page info to Layouts.
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
                Route.Path.Org__Repo__Build__Pipeline
                    { org = route.params.org
                    , repo = route.params.repo
                    , build = build
                    }
        }



-- INIT


{-| Model : alias for a model object for a build's pipeline page.
-}
type alias Model =
    { build : WebData Vela.Build
    , pipeline : WebData Vela.PipelineConfig
    , templates : WebData (Dict String Vela.Template)
    , focus : Focus.Focus
    , showTemplates : Bool
    , expand : Bool
    , expanding : Bool
    }


{-| init : takes shared model, route, and initializes pipeline page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String, build : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , pipeline = RemoteData.Loading
      , templates = RemoteData.Loading
      , focus = route.hash |> Focus.fromStringNoGroup
      , showTemplates = True
      , expand =
            route.query
                |> Dict.get "expand"
                |> Maybe.Extra.unwrap False
                    (\e -> String.toLower e == "true")
      , expanding = False
      }
    , Effect.batch
        [ Effect.getBuild
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse =
                GetBuildResponse
                    { applyDomFocus =
                        route.query
                            |> Dict.get "tab_switch"
                            |> Maybe.withDefault "false"
                            |> (==) "false"
                    }
            , org = route.params.org
            , repo = route.params.repo
            , build = route.params.build
            }
        ]
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = NoOp
      -- BROWSER
    | OnExpandQueryParameterChanged { from : Maybe String, to : Maybe String }
    | PushUrlQueryParameter { key : String, value : String }
    | OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- BUILD
    | GetBuildResponse { applyDomFocus : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
      -- PIPELINE
    | GetBuildPipelineConfigResponse { applyDomFocus : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PipelineConfig ))
    | GetExpandBuildPipelineConfigResponse { applyDomFocus : Bool } (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ToggleExpand
    | DownloadPipeline { filename : String, content : String, map : String -> String }
      -- TEMPLATES
    | GetBuildPipelineTemplatesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Dict String Vela.Template ))
    | ShowHideTemplates


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String, build : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )

        -- BROWSER
        OnExpandQueryParameterChanged options ->
            let
                expand =
                    options.to
                        |> Maybe.Extra.unwrap False
                            (\e -> String.toLower e == "true")

                expanding =
                    options.from /= options.to

                sideEffect =
                    case model.build of
                        RemoteData.Success build ->
                            Effect.batch
                                [ Effect.getPipelineConfig
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetBuildPipelineConfigResponse { applyDomFocus = False }
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , ref = build.commit
                                    }
                                , if expand then
                                    Effect.expandPipelineConfig
                                        { baseUrl = shared.velaAPIBaseURL
                                        , session = shared.session
                                        , onResponse = GetExpandBuildPipelineConfigResponse { applyDomFocus = False }
                                        , org = route.params.org
                                        , repo = route.params.repo
                                        , ref = build.commit
                                        }

                                  else
                                    Effect.none
                                ]

                        _ ->
                            Effect.getBuild
                                { baseUrl = shared.velaAPIBaseURL
                                , session = shared.session
                                , onResponse = GetBuildResponse { applyDomFocus = False }
                                , org = route.params.org
                                , repo = route.params.repo
                                , build = route.params.build
                                }
            in
            ( { model | expand = expand, expanding = expanding }
            , sideEffect
            )

        PushUrlQueryParameter options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org__Repo__Build__Pipeline
                        { org = route.params.org
                        , repo = route.params.repo
                        , build = route.params.build
                        }
                , query = Dict.insert options.key options.value route.query
                , hash = route.hash
                }
            )

        OnHashChanged _ ->
            let
                focus =
                    route.hash |> Focus.fromStringNoGroup
            in
            ( { model
                | focus = focus
              }
            , if Focus.canTarget focus then
                FocusOn
                    { target =
                        Focus.toDomTarget
                            { group = focus.group
                            , a = Focus.lineNumberChanged (Just model.focus) focus
                            , b = Nothing
                            }
                    }
                    |> Effect.sendMsg

              else
                Effect.none
            )

        PushUrlHash options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org__Repo__Build__Pipeline
                        { org = route.params.org
                        , repo = route.params.repo
                        , build = route.params.build
                        }
                , query = route.query |> Dict.remove "focus"
                , hash = Just options.hash
                }
            )

        FocusOn options ->
            ( model
            , Effect.focusOn options
            )

        -- BUILD
        GetBuildResponse options response ->
            case response of
                Ok ( _, build ) ->
                    ( { model | build = RemoteData.Success build }
                    , Effect.batch
                        [ Effect.getPipelineConfig
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetBuildPipelineConfigResponse { applyDomFocus = options.applyDomFocus }
                            , org = route.params.org
                            , repo = route.params.repo
                            , ref = build.commit
                            }
                        , Effect.getPipelineTemplates
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse = GetBuildPipelineTemplatesResponse
                            , org = route.params.org
                            , repo = route.params.repo
                            , ref = build.commit
                            }
                        ]
                    )

                Err error ->
                    ( { model | build = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- PIPELINE
        GetBuildPipelineConfigResponse options response ->
            case response of
                Ok ( _, pipeline ) ->
                    ( { model
                        | pipeline =
                            RemoteData.Success
                                { pipeline
                                    | decodedData = Util.base64Decode pipeline.rawData
                                }
                        , expanding = False
                      }
                    , Effect.batch
                        [ if model.expand then
                            Effect.expandPipelineConfig
                                { baseUrl = shared.velaAPIBaseURL
                                , session = shared.session
                                , onResponse = GetExpandBuildPipelineConfigResponse { applyDomFocus = options.applyDomFocus }
                                , org = route.params.org
                                , repo = route.params.repo
                                , ref = pipeline.commit
                                }

                          else
                            Effect.none
                        , if Focus.canTarget model.focus && options.applyDomFocus then
                            FocusOn { target = Focus.toDomTarget model.focus }
                                |> Effect.sendMsg

                          else
                            Effect.none
                        ]
                    )

                Err error ->
                    ( { model | pipeline = Errors.toFailure error, expanding = False }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetExpandBuildPipelineConfigResponse options response ->
            case response of
                Ok ( _, expandedPipeline ) ->
                    let
                        basePipeline =
                            RemoteData.withDefault Vela.defaultPipelineConfig model.pipeline
                    in
                    ( { model
                        | pipeline =
                            RemoteData.succeed
                                { basePipeline
                                    | rawData = ""
                                    , decodedData = expandedPipeline
                                }
                        , expanding = False
                      }
                    , if Focus.canTarget model.focus && options.applyDomFocus then
                        FocusOn { target = Focus.toDomTarget model.focus }
                            |> Effect.sendMsg

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | pipeline = Errors.toFailure error, expanding = False }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ToggleExpand ->
            let
                value =
                    if model.expand then
                        "false"

                    else
                        "true"
            in
            ( model
            , Effect.sendMsg <| PushUrlQueryParameter { key = "expand", value = value }
            )

        DownloadPipeline options ->
            ( model
            , Effect.downloadFile options
            )

        -- TEMPLATES
        GetBuildPipelineTemplatesResponse response ->
            case response of
                Ok ( _, templates ) ->
                    ( { model | templates = RemoteData.Success templates }
                    , Effect.none
                    )

                Err error ->
                    ( { model | templates = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ShowHideTemplates ->
            ( { model | showTemplates = not model.showTemplates }
            , Effect.none
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for a build pipeline page.
-}
view : Shared.Model -> Route { org : String, repo : String, build : String } -> Model -> View Msg
view shared route model =
    let
        viewExpandToggle =
            case model.build of
                RemoteData.Success build ->
                    div [ class "action", class "expand-pipeline", Util.testAttribute "pipeline-expand" ]
                        [ viewExpandToggleButton model
                        , if model.expanding then
                            Components.Loading.viewSmallLoader

                          else if model.expand then
                            div [ class "icon" ] [ FeatherIcons.checkCircle |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]

                          else
                            div [ class "icon" ] [ FeatherIcons.circle |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
                        , small [] [ text "note: yaml fields will be sorted alphabetically when the pipeline is expanded." ]
                        ]

                _ ->
                    text ""

        downloadButton =
            case model.pipeline of
                RemoteData.Success pipeline ->
                    div [ class "action" ]
                        [ button
                            [ class "button"
                            , class "-link"
                            , Util.testAttribute <| "download-yml"
                            , onClick <|
                                DownloadPipeline
                                    { filename = "vela.yml"
                                    , content = pipeline.decodedData
                                    , map = identity
                                    }
                            , attribute "aria-label" <| "download pipeline configuration file for "
                            ]
                            [ text <|
                                if model.expand then
                                    "download (expanded) " ++ "vela.yml"

                                else
                                    "download " ++ "vela.yml"
                            ]
                        ]

                _ ->
                    text ""
    in
    { title = "Pipeline"
    , body =
        [ case model.pipeline of
            RemoteData.Success p ->
                if List.length p.warnings > 0 then
                    div
                        [ class "logs-container"
                        , class "-pipeline"
                        ]
                        [ table
                            [ class "logs-table"
                            , class "pipeline"
                            ]
                            [ div [ class "header" ]
                                [ span []
                                    [ text "Warnings"
                                    ]
                                ]
                            , if model.expand then
                                span [ class "tip", Util.testAttribute "pipeline-warnings-expand-note" ]
                                    [ small []
                                        [ text "note: this pipeline is expanded, the line numbers shown only apply to the base pipeline configuration, they are not accurate when viewing an expanded pipeline." ]
                                    ]

                              else
                                text ""
                            , div [ class "warnings", Util.testAttribute "pipeline-warnings" ] <|
                                List.indexedMap (viewWarningAsLogLine model shared) <|
                                    List.sort p.warnings
                            ]
                        ]

                else
                    text ""

            _ ->
                text ""
        , div [ class "pipeline" ]
            [ case model.templates of
                RemoteData.Success templates ->
                    if not <| Dict.isEmpty templates then
                        viewTemplatesDetails model <|
                            div [ class "content", class "-success" ] <|
                                (templates
                                    |> Dict.toList
                                    |> List.map viewTemplate
                                )

                    else
                        text ""

                RemoteData.Failure error ->
                    viewTemplatesDetails model <|
                        div [ class "content", class "-error" ]
                            [ span [ Util.testAttribute "pipeline-templates-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No templates found for this pipeline, most likely due to not having access to the source control repo"

                                                _ ->
                                                    "No templates found for this pipeline, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No templates found for this pipeline, there was an error with the server"
                                ]
                            ]

                _ ->
                    viewTemplatesDetails model <|
                        div [ class "content", class "-success" ] [ Components.Loading.viewSmallLoaderWithText "loading pipeline templates" ]
            , div [ class "logs-container", class "-pipeline" ]
                [ table
                    [ class "logs-table"
                    , class "pipeline"
                    ]
                    [ div [ class "header" ]
                        [ span []
                            [ text "Pipeline Configuration"
                            , RemoteData.unwrap (text "") (\p -> span [ class "commit" ] [ text p.commit ]) model.pipeline
                            ]
                        ]
                    , div [ class "actions" ]
                        [ viewExpandToggle
                        , downloadButton
                        ]
                    , case model.pipeline of
                        RemoteData.Success pipeline ->
                            if String.length pipeline.decodedData > 0 then
                                div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
                                    viewLines pipeline model.expand model.focus shared.shift

                            else
                                div [ class "no-pipeline" ] [ small [] [ code [] [ text "The pipeline found for this build/ref contains no data." ] ] ]

                        RemoteData.Failure error ->
                            div [ class "content", class "-error" ]
                                [ span [ Util.testAttribute "pipeline-configuration-error" ]
                                    [ text <|
                                        case error of
                                            Http.BadStatus statusCode ->
                                                case statusCode of
                                                    401 ->
                                                        "No pipeline configuration (.vela.yml) found for this build/ref, most likely due to not being an admin of the source control repo"

                                                    _ ->
                                                        "No pipeline configuration (.vela.yml) found for this build/ref, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                            _ ->
                                                "No pipeline configuration (.vela.yml) found for this build/ref, there was an error with the server"
                                    ]
                                ]

                        _ ->
                            Components.Loading.viewSmallLoader
                    ]
                ]
            ]
        ]
    }


{-| viewTemplatesDetails : renders templates for a build pipeline.
-}
viewTemplatesDetails : Model -> Html Msg -> Html Msg
viewTemplatesDetails model body =
    details
        (class "details"
            :: class "templates"
            :: Util.testAttribute "pipeline-templates"
            :: Util.open model.showTemplates
        )
        [ summary [ class "summary", Util.onClickPreventDefault ShowHideTemplates ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , body
        ]


{-| viewExpandToggleButton : renders a link to expand or revert an expanded pipeline.
-}
viewExpandToggleButton : Model -> Html Msg
viewExpandToggleButton model =
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault ToggleExpand
        , Util.testAttribute "pipeline-expand-toggle"
        ]
        [ if model.expand then
            text "revert pipeline expansion"

          else
            text "expand pipeline"
        ]


{-| viewTemplate : renders a component with info and link to a template.
-}
viewTemplate : ( String, Vela.Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template", Util.testAttribute <| "pipeline-template-" ++ t.name ]
        [ div [] [ strong [] [ text "Name:" ], strong [] [ text "Source:" ], strong [] [ text "Link:" ] ]
        , div []
            [ span [] [ text t.name ]
            , span [] [ text t.source ]
            , a [ href t.link ] [ text t.link ]
            ]
        ]


{-| viewLines : creates a list of lines for a template.
-}
viewLines : Vela.PipelineConfig -> Bool -> Focus.Focus -> Bool -> List (Html Msg)
viewLines config expand focus shiftKeyDown =
    config.decodedData
        |> Utils.Ansi.decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine
                        expand
                        shiftKeyDown
                        (idx + 1)
                        (Just line)
                        (Dict.get (idx + 1) config.lineWarnings)
                        focus
            )
        |> Array.toList
        |> List.filterMap identity


{-| viewLine : creates a numbered, linkable line for a template.
-}
viewLine : Bool -> Bool -> Int -> Maybe Ansi.Log.Line -> Maybe (List String) -> Focus.Focus -> Html Msg
viewLine expand shiftKeyDown lineNumber line warnings focus =
    tr
        [ id <| String.fromInt lineNumber
        , class "line"
        , Maybe.Extra.unwrap (class "") (\_ -> class "-warning") warnings
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "config", "line", String.fromInt lineNumber ]
                    , class <| Focus.lineRangeStyles Nothing lineNumber focus
                    ]
                    [ td
                        [ class "annotation"
                        , Util.testAttribute <| String.join "-" [ "warning", "annotation", "line", String.fromInt lineNumber ]
                        , warnings
                            |> Maybe.Extra.filter (\_ -> not expand)
                            |> Maybe.Extra.unwrap (class "-hide") (\_ -> class "-show")
                        ]
                        [ Components.Svgs.annotationCircle "-warning" ]
                    , td
                        [ Html.Attributes.title <| "Jump to line " ++ String.fromInt lineNumber
                        ]
                        [ button
                            [ Util.onClickPreventDefault <|
                                PushUrlHash
                                    { hash =
                                        Focus.toString <| Focus.updateLineRange shiftKeyDown Nothing lineNumber focus
                                    }
                            , Util.testAttribute <| String.join "-" [ "config", "line", "num", String.fromInt lineNumber ]
                            , Focus.toAttr
                                { group = Nothing
                                , a = Just lineNumber
                                , b = Nothing
                                }
                            , class "line-number"
                            , class "button"
                            , class "-link"
                            , attribute "aria-label" "focus this line"
                            , title <| "Focus line " ++ String.fromInt lineNumber
                            ]
                            [ span [] [ text <| String.fromInt lineNumber ] ]
                        ]
                    , td [ class "break-text", class "overflow-auto", class "line-content" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| viewWarningAsLogLine : renders a warning as a log line.
-}
viewWarningAsLogLine : Model -> Shared.Model -> Int -> String -> Html Msg
viewWarningAsLogLine model shared idx warning =
    let
        { maybeLineNumber, content } =
            Warnings.fromString warning
    in
    tr
        [ class "warning"
        , Util.testAttribute <| String.join "-" [ "warning", String.fromInt idx ]
        ]
        [ td [ class "annotation", class "-show" ]
            [ Components.Svgs.annotationCircle "-warning"
            ]
        , td []
            [ case maybeLineNumber of
                Just lineNumber ->
                    let
                        -- control focus behaviour so that the button always snaps to the right page location
                        focusChanged =
                            Maybe.Extra.unwrap False (\a -> a == lineNumber) model.focus.a
                    in
                    button
                        [ Util.onClickPreventDefault <|
                            if model.expand then
                                NoOp

                            else if focusChanged then
                                FocusOn { target = Focus.toDomTarget { group = Nothing, a = Just lineNumber, b = Nothing } }

                            else
                                PushUrlHash
                                    { hash =
                                        Focus.toString <| Focus.updateLineRange shared.shift Nothing lineNumber model.focus
                                    }
                        , Util.testAttribute <| String.join "-" [ "warning", "line", "num", String.fromInt lineNumber ]
                        , class "button"
                        , class "-link"
                        , if model.expand then
                            class "-disabled"

                          else
                            class ""
                        , class "line-number"
                        , attribute "aria-label" "jump to this line"
                        , title <| "Jump to line " ++ String.fromInt lineNumber
                        , disabled model.expand
                        ]
                        [ span [] [ text <| String.fromInt lineNumber ] ]

                Nothing ->
                    span
                        [ class "no-line-number"
                        ]
                        [ text "-" ]
            ]
        , td [ class "line-content" ]
            [ text content
            ]
        ]
