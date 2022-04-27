{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (viewPipeline)

import Ansi.Log
import Array
import Dict
import Errors exposing (Error)
import FeatherIcons exposing (Icon)
import Focus exposing (Resource, ResourceID, lineFocusStyles, resourceAndLineToFocusId)
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
import RemoteData exposing (RemoteData(..))
import Util
import Vela
    exposing
        ( LogFocus
        , PipelineConfig
        , PipelineModel
        , PipelineTemplates
        , Ref
        , Template
        , Templates
        )



-- VIEW


{-| viewPipeline : takes model and renders collapsible template previews and the pipeline configuration file for the desired ref.
-}
viewPipeline : PartialModel a -> Msgs msg -> Ref -> Html msg
viewPipeline model msgs ref =
    div [ class "pipeline" ]
        [ viewPipelineTemplates model.templates msgs.showHideTemplates
        , viewPipelineConfiguration model msgs ref
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
viewPipelineConfiguration : PartialModel a -> Msgs msg -> Ref -> Html msg
viewPipelineConfiguration model msgs ref =
    case model.pipeline.config of
        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline configuration"

        ( NotAsked, _ ) ->
            text ""

        _ ->
            viewPipelineConfigurationResponse model msgs ref


{-| viewPipelineConfiguration : takes model and renders view for a pipeline configuration.
-}
viewPipelineConfigurationResponse : PartialModel a -> Msgs msg -> Ref -> Html msg
viewPipelineConfigurationResponse model msgs ref =
    div [ class "logs-container", class "-pipeline" ]
        [ case model.pipeline.config of
            ( Success config, _ ) ->
                viewPipelineConfigurationData model msgs ref config

            ( Failure _, err ) ->
                viewPipelineConfigurationError model msgs ref err

            _ ->
                text ""
        ]


{-| viewPipelineConfigurationData : takes model and config and renders view for a pipeline configuration's data.
-}
viewPipelineConfigurationData : PartialModel a -> Msgs msg -> Ref -> PipelineConfig -> Html msg
viewPipelineConfigurationData model msgs ref config =
    let
        decodedConfig =
            safeDecodePipelineData config
    in
    wrapPipelineConfigurationContent model msgs ref (class "") <|
        div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
            viewLines decodedConfig model.pipeline.lineFocus msgs.focusLineNumber


{-| viewPipelineConfigurationData : takes model and string and renders a pipeline configuration error.
-}
viewPipelineConfigurationError : PartialModel a -> Msgs msg -> Ref -> Error -> Html msg
viewPipelineConfigurationError model msgs ref err =
    wrapPipelineConfigurationContent model msgs ref (class "-error") <|
        div [ class "content", Util.testAttribute "pipeline-configuration-error" ]
            [ text <| "There was a problem fetching the pipeline configuration:", div [] [ text err ] ]


{-| wrapPipelineConfigurationContent : takes model, pipeline configuration and content and wraps it with a table, title and the template expansion header.
-}
wrapPipelineConfigurationContent : PartialModel a -> Msgs msg -> Ref -> Html.Attribute msg -> Html msg -> Html msg
wrapPipelineConfigurationContent model { get, expand, download } ref cls content =
    let
        body =
            [ div [ class "header" ]
                [ span []
                    [ text "Pipeline Configuration"
                    , span [ class "link" ] [ text <| "(" ++ ref ++ ")" ]
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


{-| viewPipelineActions : takes model and renders the config header buttons for expanding pipeline templates and downloading yaml.
-}
viewPipelineActions : PartialModel a -> Get msg -> Expand msg -> Download msg -> Html msg
viewPipelineActions model get expand download =
    let
        t =
            case model.templates.data of
                Success templates ->
                    if Dict.size templates > 0 then
                        div [ class "action", class "expand-templates", Util.testAttribute "pipeline-templates-expand" ]
                            [ expandTemplatesToggleButton model.pipeline get expand
                            , expandTemplatesToggleIcon model.pipeline
                            , expandTemplatesTip
                            ]

                    else
                        text ""

                _ ->
                    text ""

        d =
            div [ class "action" ]
                [ button
                    [ class "button"
                    , class "-link"
                    , Util.testAttribute <| "download-yml"
                    , onClick <| download velaYmlFileName <| RemoteData.unwrap "" .decodedData <| Tuple.first model.pipeline.config
                    , attribute "aria-label" <| "download pipeline configuration file for "
                    ]
                    [ text <|
                        if model.pipeline.expanded then
                            "download (expanded) " ++ velaYmlFileName

                        else
                            "download " ++ velaYmlFileName
                    ]
                ]
    in
    div [ class "actions" ] [ t, d ]


velaYmlFileName : String
velaYmlFileName =
    "vela.yml"


{-| expandTemplatesToggleIcon : takes pipeline and renders icon for toggling templates expansion.
-}
expandTemplatesToggleIcon : PipelineModel -> Html msg
expandTemplatesToggleIcon pipeline =
    let
        wrapExpandTemplatesIcon : Icon -> Html msg
        wrapExpandTemplatesIcon i =
            div [ class "icon" ] [ i |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
    in
    if pipeline.expanding then
        Util.smallLoader

    else if pipeline.expanded then
        wrapExpandTemplatesIcon FeatherIcons.checkCircle

    else
        wrapExpandTemplatesIcon FeatherIcons.circle


{-| expandTemplatesToggleButton : takes pipeline and renders button that toggles templates expansion.
-}
expandTemplatesToggleButton : PipelineModel -> Get msg -> Expand msg -> Html msg
expandTemplatesToggleButton pipeline get expand =
    let
        { org, repo, buildNumber, ref } =
            pipeline

        action =
            if pipeline.expanded then
                get org repo buildNumber ref Nothing True

            else
                expand org repo buildNumber ref Nothing True
    in
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault <| action
        , Util.testAttribute "pipeline-templates-expand-toggle"
        ]
        [ if pipeline.expanded then
            text "revert template expansion"

          else
            text "expand templates"
        ]


{-| expandTemplatesTip : renders help tip that is displayed next to the expand templates button.
-}
expandTemplatesTip : Html msg
expandTemplatesTip =
    small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when expanding templates." ]


{-| safeDecodePipelineData : takes pipeline config and decodes the data.
-}
safeDecodePipelineData : PipelineConfig -> PipelineConfig
safeDecodePipelineData config =
    let
        decoded =
            Util.base64Decode config.rawData
    in
    { config | decodedData = decoded }


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
lineFocusButton : Resource -> Int -> (Int -> msg) -> Html msg
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
