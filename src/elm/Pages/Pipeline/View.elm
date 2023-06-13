{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (safeDecodePipelineData, viewPipeline)

import Ansi.Log
import Array
import Dict
import Errors exposing (Error)
import FeatherIcons exposing (Icon)
import Focus exposing (ResourceID, ResourceType, lineFocusStyles, resourceAndLineToFocusId)
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , small
        , span
        , strong
        , td
        , text
        , tr
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Pages.Build.Logs exposing (decodeAnsi)
import Pages.Pipeline.Model exposing (Download, Expand, Get, Msgs, PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Util
import Vela
    exposing
        ( LogFocus
        , PipelineConfig
        , PipelineModel
        , PipelineTemplates
        , Template
        , Templates
        )



-- VIEW


{-| viewPipeline : takes model and renders collapsible template previews and the pipeline configuration file for the desired ref.
-}
viewPipeline : PartialModel a -> Msgs msg -> Html msg
viewPipeline model msgs =
    div [ class "pipeline" ]
        [ viewPipelineTemplates model.templates msgs.showHideTemplates
        , viewPipelineConfiguration model msgs
        ]


{-| viewPipelineTemplates : takes templates and renders a list above the pipeline configuration.
-}
viewPipelineTemplates : PipelineTemplates -> msg -> Html msg
viewPipelineTemplates { data, error, show } showHide =
    case data of
        NotAsked ->
            text ""

        Loading ->
            Util.smallLoaderWithText "loading pipeline templates"

        Success t ->
            viewTemplates t show showHide

        Failure _ ->
            viewTemplatesError error show showHide


{-| viewTemplates : takes templates and renders a list of templates.

    Does not show if no templates are used in the pipeline.

-}
viewTemplates : Templates -> Bool -> msg -> Html msg
viewTemplates templates open showHide =
    if not <| Dict.isEmpty templates then
        templates
            |> Dict.toList
            |> List.map viewTemplate
            |> viewTemplatesDetails (class "-success") open showHide

    else
        text ""


{-| viewTemplates : renders an error from fetching templates.
-}
viewTemplatesError : Error -> Bool -> msg -> Html msg
viewTemplatesError err open showHide =
    [ text <| "There was a problem fetching templates for this pipeline configuration"
    , div [ Util.testAttribute "pipeline-templates-error" ] [ text err ]
    ]
        |> viewTemplatesDetails (class "-error") open showHide


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


{-| viewTemplate : takes template and renders view with name, source and HTML url.
-}
viewTemplate : ( String, Template ) -> Html msg
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


{-| viewPipelineConfiguration : takes model and renders a wrapper view for a pipeline configuration if Success or Failure.
-}
viewPipelineConfiguration : PartialModel a -> Msgs msg -> Html msg
viewPipelineConfiguration model msgs =
    case model.pipeline.config of
        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline configuration"

        ( NotAsked, _ ) ->
            text ""

        _ ->
            viewPipelineConfigurationResponse model msgs


{-| viewPipelineConfiguration : takes model and renders view for a pipeline configuration.
-}
viewPipelineConfigurationResponse : PartialModel a -> Msgs msg -> Html msg
viewPipelineConfigurationResponse model msgs =
    div [ class "logs-container", class "-pipeline" ]
        [ case model.pipeline.config of
            ( Success config, _ ) ->
                viewPipelineConfigurationData model config msgs

            ( Failure _, err ) ->
                viewPipelineConfigurationError model msgs err

            _ ->
                text ""
        ]


{-| viewPipelineConfigurationData : takes model and config and renders view for a pipeline configuration's data.
-}
viewPipelineConfigurationData : PartialModel a -> PipelineConfig -> Msgs msg -> Html msg
viewPipelineConfigurationData model config msgs =
    wrapPipelineConfigurationContent model msgs (class "") <|
        div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
            viewLines config model.pipeline.lineFocus msgs.focusLineNumber


{-| viewPipelineConfigurationData : takes model and string and renders a pipeline configuration error.
-}
viewPipelineConfigurationError : PartialModel a -> Msgs msg -> Error -> Html msg
viewPipelineConfigurationError model msgs err =
    wrapPipelineConfigurationContent model msgs (class "") <|
        div [ class "content", Util.testAttribute "pipeline-configuration-error" ]
            [ text <| "There was a problem fetching the pipeline configuration:", div [] [ text err ] ]


{-| wrapPipelineConfigurationContent : takes model, pipeline configuration and content and wraps it with a table, title and the pipeline expansion header.
-}
wrapPipelineConfigurationContent : PartialModel a -> Msgs msg -> Html.Attribute msg -> Html msg -> Html msg
wrapPipelineConfigurationContent model { get, expand, download } cls content =
    let
        body =
            [ div [ class "header" ]
                [ span []
                    [ text "Pipeline Configuration"
                    ]
                ]
            , viewPipelineActions model get expand download
            , content
            ]
    in
    Html.table
        [ class "logs-table"
        , cls
        ]
        body


{-| viewPipelineActions : takes model and renders the config header buttons for expanding pipelines and downloading yaml.
-}
viewPipelineActions : PartialModel a -> Get msg -> Expand msg -> Download msg -> Html msg
viewPipelineActions model get expand download =
    let
        pipeline =
            model.pipeline

        toggle =
            case model.repo.build.build of
                Success build ->
                    div [ class "action", class "expand-pipeline", Util.testAttribute "pipeline-expand" ]
                        [ expandPipelineToggleButton model build.commit get expand
                        , expandPipelineToggleIcon pipeline
                        , expandPipelineTip
                        ]

                _ ->
                    text ""

        dl =
            case pipeline.config of
                ( Success config, _ ) ->
                    div [ class "action" ]
                        [ downloadButton config pipeline.expanded download
                        ]

                _ ->
                    text ""
    in
    div [ class "actions" ] [ toggle, dl ]


{-| downloadButton : takes config information and download msg and returns the button to download a configuration file yaml.
-}
downloadButton : PipelineConfig -> Bool -> Download msg -> Html msg
downloadButton config expanded download =
    button
        [ class "button"
        , class "-link"
        , Util.testAttribute <| "download-yml"
        , onClick <| download velaYmlFileName <| config.decodedData
        , attribute "aria-label" <| "download pipeline configuration file for "
        ]
        [ text <|
            if expanded then
                "download (expanded) " ++ velaYmlFileName

            else
                "download " ++ velaYmlFileName
        ]


{-| velaYmlFileName : default vela filename used for writing the downloaded configuration file.
-}
velaYmlFileName : String
velaYmlFileName =
    "vela.yml"


{-| expandPipelineToggleIcon : takes pipeline and renders icon for toggling pipeline expansion.
-}
expandPipelineToggleIcon : PipelineModel -> Html msg
expandPipelineToggleIcon pipeline =
    let
        wrapExpandIcon : Icon -> Html msg
        wrapExpandIcon i =
            div [ class "icon" ] [ i |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
    in
    if pipeline.expanding then
        Util.smallLoader

    else if pipeline.expanded then
        wrapExpandIcon FeatherIcons.checkCircle

    else
        wrapExpandIcon FeatherIcons.circle


{-| expandPipelineToggleButton : takes pipeline and renders button that toggles pipeline expansion.
-}
expandPipelineToggleButton : PartialModel a -> String -> Get msg -> Expand msg -> Html msg
expandPipelineToggleButton model ref get expand =
    let
        pipeline =
            model.pipeline

        { org, name, build } =
            model.repo

        action =
            if pipeline.expanded then
                get org name build.buildNumber ref Nothing True

            else
                expand org name build.buildNumber ref Nothing True
    in
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault <| action
        , Util.testAttribute "pipeline-expand-toggle"
        ]
        [ if pipeline.expanded then
            text "revert pipeline expansion"

          else
            text "expand pipeline"
        ]


{-| expandPipelineTip : renders help tip that is displayed next to the expand pipeline button.
-}
expandPipelineTip : Html msg
expandPipelineTip =
    small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when the pipeline is expanded." ]


{-| safeDecodePipelineData : takes pipeline config and decodes the data.
-}
safeDecodePipelineData : PipelineConfig -> ( WebData PipelineConfig, Error ) -> PipelineConfig
safeDecodePipelineData incomingConfig currentConfig =
    case currentConfig of
        ( RemoteData.Success current, _ ) ->
            if current.rawData == incomingConfig.rawData then
                current

            else
                { incomingConfig | decodedData = Util.base64Decode incomingConfig.rawData }

        _ ->
            { incomingConfig | decodedData = Util.base64Decode incomingConfig.rawData }


{-| viewLines : takes pipeline configuration, line focus and shift key.

    returns a list of rendered data lines with focusable line numbers.

-}
viewLines : PipelineConfig -> LogFocus -> (Int -> msg) -> List (Html msg)
viewLines config lineFocus focusLineNumber =
    config.decodedData
        |> decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine "0"
                        (idx + 1)
                        (Just line)
                        "0"
                        lineFocus
                        focusLineNumber
            )
        |> Array.toList
        |> Just
        |> Maybe.withDefault []
        |> List.filterMap identity


{-| viewLine : takes line and focus information and renders line number button and data.
-}
viewLine : ResourceID -> Int -> Maybe Ansi.Log.Line -> String -> LogFocus -> (Int -> msg) -> Html msg
viewLine id lineNumber line resource lineFocus focus =
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
                    , class <| lineFocusStyles lineFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton resource lineNumber focus ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| lineFocusButton : renders button for focusing log line ranges.
-}
lineFocusButton : ResourceType -> Int -> (Int -> msg) -> Html msg
lineFocusButton resource lineNumber focus =
    button
        [ Util.onClickPreventDefault <|
            focus lineNumber
        , Util.testAttribute <| String.join "-" [ "config", "line", "num", resource, String.fromInt lineNumber ]
        , Html.Attributes.id <| resourceAndLineToFocusId "config" resource lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus resource " ++ resource
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]
