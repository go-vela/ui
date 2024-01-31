{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Pipeline exposing (..)

import Ansi.Log
import Array
import Auth
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, a, button, code, details, div, small, span, strong, summary, table, td, text, tr)
import Html.Attributes exposing (attribute, class, href, id, target)
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
import Utils.Errors
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
        |> Page.withOnQueryParameterChanged { key = "expand", onChange = OnExpandQueryParameterChanged }



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, buildNumber : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_Pipeline
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , pipeline : WebData Vela.PipelineConfig
    , templates : WebData (Dict String Vela.Template)
    , focus : Focus.Focus
    , showTemplates : Bool
    , expand : Bool
    , expanding : Bool
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
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
    , Effect.getBuild
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetBuildResponse
        , org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        }
    )



-- UPDATE


type Msg
    = -- BROWSER
      OnExpandQueryParameterChanged { from : Maybe String, to : Maybe String }
    | PushUrlQueryParameter { key : String, value : String }
    | OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- BUILD
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
      -- PIPELINE
    | GetBuildPipelineConfigResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PipelineConfig ))
    | GetExpandBuildPipelineConfigResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ToggleExpand
    | DownloadPipeline { filename : String, content : String, map : String -> String }
      -- TEMPLATES
    | GetBuildPipelineTemplatesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Dict String Vela.Template ))
    | ShowHideTemplates


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
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
                            if expand then
                                Effect.expandPipelineConfig
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetExpandBuildPipelineConfigResponse
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , ref = build.commit
                                    }

                            else
                                Effect.getPipelineConfig
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetBuildPipelineConfigResponse
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , ref = build.commit
                                    }

                        _ ->
                            Effect.getBuild
                                { baseUrl = shared.velaAPIBaseURL
                                , session = shared.session
                                , onResponse = GetBuildResponse
                                , org = route.params.org
                                , repo = route.params.repo
                                , buildNumber = route.params.buildNumber
                                }
            in
            ( { model | expand = expand, expanding = expanding }
            , sideEffect
            )

        PushUrlQueryParameter options ->
            ( model
            , Effect.pushRoute
                { path =
                    Route.Path.Org_Repo_Build_Pipeline
                        { org = route.params.org
                        , repo = route.params.repo
                        , buildNumber = route.params.buildNumber
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
                    Route.Path.Org_Repo_Build_Pipeline
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

        -- BUILD
        GetBuildResponse response ->
            case response of
                Ok ( _, build ) ->
                    let
                        getPipelineConfigEffect =
                            if model.expand then
                                Effect.expandPipelineConfig
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetExpandBuildPipelineConfigResponse
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , ref = build.commit
                                    }

                            else
                                Effect.getPipelineConfig
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse = GetBuildPipelineConfigResponse
                                    , org = route.params.org
                                    , repo = route.params.repo
                                    , ref = build.commit
                                    }
                    in
                    ( { model | build = RemoteData.Success build }
                    , Effect.batch
                        [ getPipelineConfigEffect
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
                    ( { model | build = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        -- PIPELINE
        GetBuildPipelineConfigResponse response ->
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
                    , if Focus.canTarget model.focus then
                        FocusOn { target = Focus.toDomTarget model.focus }
                            |> Effect.sendMsg

                      else
                        Effect.none
                    )

                Err error ->
                    ( { model | pipeline = Utils.Errors.toFailure error, expanding = False }
                    , Effect.handleHttpError { httpError = error }
                    )

        GetExpandBuildPipelineConfigResponse response ->
            case response of
                Ok ( _, expandedPipeline ) ->
                    ( { model
                        | pipeline =
                            RemoteData.Success
                                { rawData = ""
                                , decodedData = expandedPipeline
                                }
                        , expanding = False
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | pipeline = Utils.Errors.toFailure error, expanding = False }
                    , Effect.handleHttpError { httpError = error }
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
                    ( { model | templates = Utils.Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )

        ShowHideTemplates ->
            ( { model | showTemplates = not model.showTemplates }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "Pipeline"
    , body =
        [ div [ class "pipeline" ]
            [ case model.templates of
                RemoteData.Success templates ->
                    if not <| Dict.isEmpty templates then
                        templates
                            |> Dict.toList
                            |> List.map viewTemplate
                            |> viewTemplatesDetails (class "-success") model.showTemplates ShowHideTemplates

                    else
                        text ""

                RemoteData.Failure _ ->
                    text "error"

                _ ->
                    Util.smallLoaderWithText "loading pipeline templates"
            , case model.pipeline of
                RemoteData.Success pipeline ->
                    if String.length pipeline.decodedData > 0 then
                        div [ class "logs-container", class "-pipeline" ]
                            [ table
                                [ class "logs-table"
                                ]
                                [ div [ class "header" ]
                                    [ span []
                                        [ text "Pipeline Configuration"
                                        ]
                                    ]
                                , let
                                    toggle =
                                        case model.build of
                                            RemoteData.Success build ->
                                                div [ class "action", class "expand-pipeline", Util.testAttribute "pipeline-expand" ]
                                                    [ viewExpandToggleButton model
                                                    , if model.expanding then
                                                        Util.smallLoader

                                                      else if model.expand then
                                                        div [ class "icon" ] [ FeatherIcons.checkCircle |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]

                                                      else
                                                        div [ class "icon" ] [ FeatherIcons.circle |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
                                                    , small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when the pipeline is expanded." ]
                                                    ]

                                            _ ->
                                                text ""
                                  in
                                  div [ class "actions" ]
                                    [ toggle
                                    , div [ class "action" ]
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
                                    ]
                                , div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
                                    viewLines pipeline model.focus shared.shift
                                ]
                            ]

                    else
                        div [ class "no-pipeline" ] [ small [] [ code [] [ text "No pipeline found for this build." ] ] ]

                _ ->
                    Util.smallLoader
            ]
        ]
    }


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


viewTemplate : ( String, Vela.Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template", Util.testAttribute <| "pipeline-template-" ++ t.name ]
        [ div [] [ strong [] [ text "Name:" ], strong [] [ text "Source:" ], strong [] [ text "Link:" ] ]
        , div []
            [ span [] [ text t.name ]
            , span [] [ text t.source ]
            , a
                [ target "_blank"
                , href t.link
                ]
                [ text t.link ]
            ]
        ]


viewTemplatesDetails : Html.Attribute msg -> Bool -> msg -> List (Html msg) -> Html msg
viewTemplatesDetails cls open showHide content =
    details
        (class "details"
            :: class "templates"
            :: Util.testAttribute "pipeline-templates"
            :: Util.open open
        )
        [ summary [ class "summary", Util.onClickPreventDefault showHide ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , div [ class "content", cls ] content
        ]


viewLines : Vela.PipelineConfig -> Focus.Focus -> Bool -> List (Html Msg)
viewLines config focus shift =
    config.decodedData
        |> Utils.Ansi.decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine
                        shift
                        (idx + 1)
                        (Just line)
                        focus
            )
        |> Array.toList
        |> List.filterMap identity


viewLine : Bool -> Int -> Maybe Ansi.Log.Line -> Focus.Focus -> Html Msg
viewLine shiftKeyDown lineNumber line focus =
    tr
        [ id <| String.fromInt lineNumber
        , class "line"
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "config", "line", String.fromInt lineNumber ]
                    , class <| Focus.lineRangeStyles Nothing lineNumber focus
                    ]
                    [ td []
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
                            ]
                            [ span [] [ text <| String.fromInt lineNumber ] ]
                        ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]
