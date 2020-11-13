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
import FeatherIcons
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
import Pages.Pipeline.Model exposing (Error, PartialModel)
import Pages.Pipeline.Update exposing (Msg(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder
import Util
import Vela
    exposing
        ( Build
        , LogFocus
        , Org
        , Repo
        , Step
        , Steps
        , Template
        , Templates
        )



-- VIEW


viewPipeline : PartialModel a -> Html Msg
viewPipeline model =
    div [ class "pipeline" ]
        [ viewTemplates model.templates
        , viewConfig model
        ]


viewTemplates : ( WebData Templates, Error ) -> Html Msg
viewTemplates templates =
    let
        content =
            case templates of
                ( NotAsked, _ ) ->
                    text ""

                ( Loading, _ ) ->
                    Util.smallLoaderWithText "loading pipeline templates"

                ( Success t, _ ) ->
                    let
                        templatesList =
                            Dict.toList t
                    in
                    if List.length templatesList > 0 then
                        Html.details [ class "details", class "templates", Html.Attributes.attribute "open" "" ]
                            [ Html.summary [ class "summary" ]
                                [ div [] [ text "Templates" ]
                                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                                ]
                            , div [ class "content", class "-success" ] <|
                                List.map viewTemplate templatesList
                            ]

                    else
                        text ""

                ( Failure _, err ) ->
                    Html.details [ class "details", class "templates", Html.Attributes.attribute "open" "" ]
                        [ Html.summary [ class "summary" ]
                            [ div [] [ text "Templates" ]
                            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
                            ]
                        , div [ class "content", class "-error" ]
                            [ span [] [ text <| "There was a problem fetching templates for this pipeline configuration: " ++ err ] ]
                        ]
    in
    content


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


templatesExpansion : PartialModel a -> Org -> Repo -> Maybe String -> Html Msg
templatesExpansion model org repo ref =
    case model.templates of
        ( Success templates, _ ) ->
            if Dict.size templates > 0 then
                let
                    action =
                        if model.pipeline.expanded then
                            GetPipelineConfig org repo ref

                        else
                            ExpandPipelineConfig org repo ref
                in
                div [ class "expansion" ]
                    [ div [ class "toggle-expansion" ]
                        [ if model.pipeline.configLoading then
                            Util.smallLoader

                          else if model.pipeline.expanded then
                            FeatherIcons.checkCircle |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "expansion-icon -expanded" |> FeatherIcons.toHtml []

                          else
                            FeatherIcons.circle |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "expansion-icon" |> FeatherIcons.toHtml []
                        ]
                    , button
                        [ class "button"
                        , class "-link"
                        , Util.onClickPreventDefault <| action
                        ]
                        [ if model.pipeline.expanded then
                            text "revert template expansion"

                          else
                            text "expand templates"
                        ]
                    , small [ class "expand-tip" ] [ text "note: expanding a pipeline configuration will order yaml fields alphabetically." ]
                    ]

            else
                text ""

        ( Loading, _ ) ->
            text ""

        _ ->
            text ""


viewConfig : PartialModel a -> Html Msg
viewConfig model =
    let
        { org, repo, ref, expand, lineFocus } =
            model.pipeline

        content =
            case model.pipeline.config of
                (Success config, _) ->
                    if String.length config.data > 0 then
                        let
                            header =
                                div [ class "header" ]
                                    [ span [] [ text "Pipeline Configuration" ]
                                    ]

                            lines =
                                config.data
                                    |> decodeAnsi
                                    |> Array.indexedMap
                                        (\idx line ->
                                            Just <|
                                                viewLine "0"
                                                    (idx + 1)
                                                    (Just line)
                                                    "0"
                                                    lineFocus
                                                    model.shift
                                        )
                                    |> Array.toList

                            logs =
                                [ header, templatesExpansion model org repo ref ]
                                    ++ (lines
                                            |> List.filterMap identity
                                       )
                        in
                        div [ class "logs-container", class "-EDIT" ] [ div [ class "logs" ] [ Html.table [ class "logs-table" ] logs ] ]

                    else
                        code [] [ text "no pipeline config found" ]

                (Loading, _) ->
                    Util.smallLoaderWithText "loading pipeline configuration"

                (Failure _, err) ->
                    small [ class "error" ] [ text <| "There was a problem fetching the pipeline configuration: " ++ err ]

                _ ->
                    text ""
    in
    content


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


focusStyle : Int -> Int -> Html.Attribute Msg
focusStyle lineNum idx =
    class <|
        if lineNum == idx then
            "-focus"

        else
            ""


webDataToClass : WebData a -> String
webDataToClass w =
    case w of
        Success _ ->
            "-success"

        Loading ->
            "-loading"

        Failure err ->
            "-error"

        _ ->
            ""
