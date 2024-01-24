{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Pipeline exposing (..)

import Ansi.Log
import Array
import Auth
import Components.Svgs
import Debug exposing (log)
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, a, button, code, details, div, small, span, strong, summary, td, text, tr)
import Html.Attributes exposing (attribute, class, id)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Ansi
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
                Route.Path.Org_Repo_Build_Pipeline
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    , pipeline : WebData Vela.PipelineConfig
    , templates : WebData (Dict String Vela.Template)
    , lineFocus : ( Maybe Int, ( Maybe Int, Maybe Int ) )
    , showTemplates : Bool
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      , pipeline = RemoteData.Loading
      , templates = RemoteData.Loading
      , lineFocus =
            route.hash
                |> Focus.parseFocusFragment
                |> (\ft -> ( ft.resourceNumber, ( ft.lineA, ft.lineB ) ))
      , showTemplates = True
      }
    , Effect.getBuild
        { baseUrl = shared.velaAPI
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
      OnHashChanged { from : Maybe String, to : Maybe String }
    | PushUrlHash { hash : String }
    | FocusOn { target : String }
      -- BUILD
    | GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))
      -- PIPELINE
    | GetBuildPipelineConfigResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PipelineConfig ))
    | DownloadPipeline { filename : String, content : String, map : String -> String }
      -- TEMPLATES
    | GetBuildPipelineTemplatesResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Dict String Vela.Template ))
    | ShowHideTemplates


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnHashChanged _ ->
            ( { model
                | lineFocus =
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
                    ( { model | build = RemoteData.Success build }
                    , Effect.batch
                        [ Effect.getPipelineConfig
                            { baseUrl = shared.velaAPI
                            , session = shared.session
                            , onResponse = GetBuildPipelineConfigResponse
                            , org = route.params.org
                            , repo = route.params.repo
                            , ref = build.commit
                            }
                        , Effect.getPipelineTemplates
                            { baseUrl = shared.velaAPI
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
                    , Effect.handleHttpError { httpError = error }
                    )

        -- PIPELINE
        GetBuildPipelineConfigResponse response ->
            case response of
                Ok ( _, pipeline ) ->
                    ( { model | pipeline = RemoteData.Success { pipeline | decodedData = Util.base64Decode pipeline.rawData } }
                    , Effect.none
                    )

                Err error ->
                    ( { model | pipeline = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
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
    { title = "#" ++ route.params.buildNumber
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
                    if String.length pipeline.rawData > 0 then
                        div [ class "logs-container", class "-pipeline" ]
                            [ Html.table
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
                                            Success build ->
                                                div [ class "action", class "expand-pipeline", Util.testAttribute "pipeline-expand" ]
                                                    [--     expandPipelineToggleButton model build.commit get expand
                                                     -- , expandPipelineToggleIcon pipeline
                                                     -- , expandPipelineTip
                                                    ]

                                            _ ->
                                                text ""
                                  in
                                  div [ class "actions" ]
                                    [ toggle
                                    , div [ class "action" ]
                                        [-- downloadButton config pipeline.expanded download
                                        ]
                                    ]
                                , div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
                                    viewLines shared pipeline (Just <| Tuple.second model.lineFocus)
                                ]
                            ]

                    else
                        div [ class "no-pipeline" ] [ small [] [ code [] [ text "No pipeline found for this build." ] ] ]

                _ ->
                    Util.smallLoader
            ]
        ]
    }


{-| viewTemplate : takes template and renders view with name, source and HTML url.
-}
viewTemplate : ( String, Vela.Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template", Util.testAttribute <| "pipeline-template-" ++ t.name ]
        [ div [] [ strong [] [ text "Name:" ], strong [] [ text "Source:" ], strong [] [ text "Link:" ] ]
        , div []
            [ span [] [ text t.name ]
            , span [] [ text t.source ]
            , a
                [ Html.Attributes.target "_blank"
                , Html.Attributes.href t.link
                ]
                [ text t.link ]
            ]
        ]


{-| viewTemplatesDetails : takes templates content and wraps it in a details/summary.
-}
viewTemplatesDetails : Html.Attribute msg -> Bool -> msg -> List (Html msg) -> Html msg
viewTemplatesDetails cls open showHide content =
    Html.details
        (class "details"
            :: class "templates"
            :: Util.testAttribute "pipeline-templates"
            :: Util.open open
        )
        [ Html.summary [ class "summary", Util.onClickPreventDefault showHide ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , div [ class "content", cls ] content
        ]


{-| viewLines : takes pipeline configuration, line focus and shift key.

    returns a list of rendered data lines with focusable line numbers.

-}
viewLines : Shared.Model -> Vela.PipelineConfig -> Maybe Focus.LineFocus -> List (Html Msg)
viewLines shared config lineFocus =
    config.decodedData
        |> Utils.Ansi.decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine
                        shared
                        "0"
                        (idx + 1)
                        (Just line)
                        "0"
                        lineFocus
            )
        |> Array.toList
        |> List.filterMap identity


{-| viewLine : takes line and focus information and renders line number button and data.
-}
viewLine : Shared.Model -> String -> Int -> Maybe Ansi.Log.Line -> String -> Maybe Focus.LineFocus -> Html Msg
viewLine shared id lineNumber line resource lineFocus =
    tr
        [ Html.Attributes.id <|
            id
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "config", "line", resource, String.fromInt lineNumber ]
                    , class <| Focus.lineFocusStyles lineFocus lineNumber
                    ]
                    [ td []
                        [ button
                            [ Util.onClickPreventDefault <|
                                PushUrlHash
                                    { hash = Focus.lineRangeId "pipeline" "0" lineNumber lineFocus shared.shift
                                    }
                            , Util.testAttribute <| String.join "-" [ "config", "line", "num", resource, String.fromInt lineNumber ]
                            , Html.Attributes.id <| Focus.resourceAndLineToFocusId "config" resource lineNumber
                            , class "line-number"
                            , class "button"
                            , class "-link"
                            , attribute "aria-label" <| "focus resource " ++ resource
                            ]
                            [ span [] [ text <| String.fromInt lineNumber ] ]
                        ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]
