{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (viewPipeline)

import Ansi.Log
import Array
import Dict
import Dict.Extra
import Errors exposing (detailedErrorToString)
import FeatherIcons exposing (Icon)
import Focus exposing (ExpandTemplatesQuery, Fragment, RefQuery, lineFocusStyles, lineRangeId, resourceAndLineToFocusId)
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
        , table
        , td
        , text
        , tr
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import List.Extra
import Pages exposing (Page(..))
import Pages.Build.Logs exposing (decodeAnsi)
import Pages.Build.View exposing (viewLine)
import Pages.Pipeline.Model exposing (Error, Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder
import Util
import Vela
    exposing
        ( Build
        , LogFocus
        , Org
        , Pipeline
        , PipelineConfig
        , Repo
        , Step
        , Steps
        , Template
        , Templates
        )



-- VIEW


{-| viewPipeline : takes model and renders collapsible template previews and the pipeline configuration file for the desired ref.
-}
viewPipeline : PartialModel a -> Html Msg
viewPipeline model =
    div [ class "pipeline" ]
        [ viewTemplates model.templates
        , viewPipelineConfiguration model
        ]


{-| viewTemplates : takes templates and renders a list above the pipeline configuration.

    Does not show if no templates are used in the pipeline.

-}
viewTemplates : ( WebData Templates, Error ) -> Html Msg
viewTemplates templates =
    case templates of
        ( NotAsked, _ ) ->
            text ""

        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline templates"

        ( Success t, _ ) ->
            if Dict.isEmpty t then
                viewTemplatesContent
                    (class "-success")
                <|
                    List.map viewTemplate <|
                        Dict.toList t

            else
                text ""

        ( Failure _, err ) ->
            viewTemplatesContent
                (class "-error")
                [ text <| "There was a problem fetching templates for this pipeline configuration:", div [] [ text err ] ]


{-| viewTemplatesContent : takes templates content and wraps it in a details/summary.
-}
viewTemplatesContent : Html.Attribute Msg -> List (Html Msg) -> Html Msg
viewTemplatesContent cls content =
    Html.details [ class "details", class "templates", Html.Attributes.attribute "open" "" ]
        [ Html.summary [ class "summary" ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , div [ class "content", cls ] content
        ]


{-| viewTemplate : takes template and renders view with name, source and HTML url.
-}
viewTemplate : ( String, Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template" ]
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


{-| viewPipelineConfiguration : takes model and renders a wrapper view for a pipeline configuration.
-}
viewPipelineConfiguration : PartialModel a -> Html Msg
viewPipelineConfiguration model =
    case model.pipeline.config of
        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline configuration"

        ( NotAsked, _ ) ->
            text ""

        _ ->
            viewPipelineConfigurationResponse model


{-| viewPipelineConfiguration : takes model and renders view for a pipeline configuration Success of Failure.
-}
viewPipelineConfigurationResponse : PartialModel a -> Html Msg
viewPipelineConfigurationResponse model =
    let
        { config, lineFocus } =
            model.pipeline
    in
    -- TODO: modularize logs rendering
    div [ class "logs-container", class "-pipeline" ]
        [ case config of
            ( Success c, _ ) ->
                if String.length c.data > 0 then
                    wrapPipelineConfigurationContent model config <|
                        div [ class "logs" ] <|
                            viewLines c lineFocus model.shift

                else
                    code [] [ text "no pipeline config found" ]

            ( Failure _, err ) ->
                wrapPipelineConfigurationContent model config <|
                    div [ class "content" ]
                        [ text <| "There was a problem fetching the pipeline configuration:", div [] [ text err ] ]

            _ ->
                text ""
        ]


{-| wrapPipelineConfigurationContent : takes model, pipeline configuration and content and wraps it with a table, title and the template expansion header.
-}
wrapPipelineConfigurationContent : PartialModel a -> ( WebData PipelineConfig, String ) -> Html Msg -> Html Msg
wrapPipelineConfigurationContent model config content =
    let
        contentClass =
            case config of
                ( Failure _, _ ) ->
                    class "-error"

                _ ->
                    class ""

        body =
            [ div [ class "header" ]
                [ span [] [ text "Pipeline Configuration" ]
                ]
            , viewTemplatesExpansion model
            ]
                ++ [ content ]
    in
    Html.table
        [ class "logs-table"
        , contentClass
        ]
        body


{-| viewTemplatesExpansion : takes model and renders the config header button for expanding pipeline templates.
-}
viewTemplatesExpansion : PartialModel a -> Html Msg
viewTemplatesExpansion model =
    case model.templates of
        ( Success templates, _ ) ->
            if Dict.size templates > 0 then
                let
                    { org, repo, ref } =
                        model.pipeline

                    wrapExpandTemplatesIcon : Icon -> Html Msg
                    wrapExpandTemplatesIcon i =
                        i |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "icon" |> FeatherIcons.toHtml []
                in
                div [ class "expand-templates" ]
                    [ div [ class "toggle" ]
                        [ if model.pipeline.configLoading then
                            Util.smallLoader

                          else if model.pipeline.expanded then
                            wrapExpandTemplatesIcon FeatherIcons.checkCircle

                          else
                            wrapExpandTemplatesIcon FeatherIcons.circle
                        ]
                    , expandTemplatesToggleButton model.pipeline
                    , expandTemplatesTip
                    ]

            else
                text ""

        ( Loading, _ ) ->
            text ""

        _ ->
            text ""


{-| expandTemplatesToggleButton : takes pipeline and renders button to toggle templates expansion.
-}
expandTemplatesToggleButton : Pipeline -> Html Msg
expandTemplatesToggleButton pipeline =
    let
        { org, repo, ref } =
            pipeline

        action =
            if pipeline.expanded then
                GetPipelineConfig org repo ref

            else
                ExpandPipelineConfig org repo ref
    in
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault <| action
        ]
        [ if pipeline.expanded then
            text "revert template expansion"

          else
            text "expand templates"
        ]


{-| expandTemplatesTip : renders help tip that is displayed next to the expand templates button.
-}
expandTemplatesTip : Html Msg
expandTemplatesTip =
    small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when expanding templates." ]



-- LINE FOCUS
-- TODO: modularize logs rendering


viewLines : PipelineConfig -> LogFocus -> Bool -> List (Html Msg)
viewLines c lineFocus shift =
    let
        lines =
            c.data
                |> decodeAnsi
                |> Array.indexedMap
                    (\idx line ->
                        Just <|
                            viewLine "0"
                                (idx + 1)
                                (Just line)
                                "0"
                                lineFocus
                                shift
                    )
                |> Array.toList
                |> Just
    in
    Maybe.withDefault [] lines
        |> List.filterMap identity


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : String -> Int -> Maybe Ansi.Log.Line -> String -> LogFocus -> Bool -> Html Msg
viewLine id lineNumber line resource logFocus shiftDown =
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
                    , Util.testAttribute <| String.join "-" [ "log", "line", resource, String.fromInt lineNumber ]
                    , class <| lineFocusStyles logFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton resource logFocus lineNumber shiftDown ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "log", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : String -> LogFocus -> Int -> Bool -> Html Msg
lineFocusButton resource logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            FocusLine <|
                lineNumber
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", resource, String.fromInt lineNumber ]
        , Html.Attributes.id <| resourceAndLineToFocusId "config" resource lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus resource " ++ resource
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]
