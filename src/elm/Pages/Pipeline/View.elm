{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (viewPipeline)

import Dict
import Dict.Extra
import Errors exposing (detailedErrorToString)
import FeatherIcons
import Focus exposing (ExpandTemplatesQuery,lineRangeId, lineFocusStyles, Fragment, RefQuery)
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
        , text
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import List.Extra
import Pages exposing (Page(..))
import Pages.Pipeline.Model exposing (PartialModel)
import Pages.Pipeline.Update exposing (Msg(..))
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder
import Util
import Vela
    exposing
        ( Build
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


viewTemplates : WebData Templates -> Html Msg
viewTemplates templates =
    let
        ( content, c ) =
            case templates of
                NotAsked ->
                    ( text ""
                    , ""
                    )

                Loading ->
                    ( Util.smallLoaderWithText "loading pipeline templates"
                    , "-loading"
                    )

                Success t ->
                    let
                        templatesList =
                            Dict.toList t
                    in
                    if List.length templatesList > 0 then
                        ( div [] <| List.map viewTemplate templatesList
                        , "-success"
                        )

                    else
                        ( div [ class "empty" ] [ text "no templates found" ]
                        , "-empty"
                        )

                Failure err ->
                    ( small [ class "error" ] [ text <| "There was a problem fetching templates: " ++ Errors.errorToString err ]
                    , "-error"
                    )
    in
    Html.details [ class "details", class "templates", Html.Attributes.attribute "open" "" ]
        [ Html.summary [ class "summary" ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , div [ class "content", class c ]
            [ content ]
        ]


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


lineFocusButton : Int -> Html Msg
lineFocusButton lineNumber =
    button
        [ class "line-number"
        , class "button"
        , class "-link"
        , onClick <| FocusLine lineNumber
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]


templatesExpansion : PartialModel a -> Org -> Repo -> Maybe String -> Html Msg
templatesExpansion model org repo ref =
    case model.templates of
        Success templates ->
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
                    ]

            else
                text ""

        Loading ->
            Util.smallLoader

        _ ->
            text ""


viewConfig : PartialModel a -> Html Msg
viewConfig model =
    let
        { org, repo, ref, expand, lineFocus } =
            model.pipeline

        header =
            div [ class "header" ]
                [ span [] [ text "Pipeline Configuration" ]
                ]
                
        content =
            case model.pipeline.config of
                Success config ->
                    if String.length config.data > 0 then
                        div [ class "lines" ] <|
                            templatesExpansion model org repo ref
                                :: (List.indexedMap
                                        (\idx ->
                                            \l ->
                                                div [ class "line",class <| lineFocusStyles lineFocus (idx + 1)]
                                                    [ lineFocusButton (idx + 1), code [] [ text l ] ]
                                        )
                                    <|
                                        String.lines config.data
                                   )

                    else
                        code [] [ text "no pipeline config found" ]

                Loading ->
                    Util.smallLoaderWithText "loading pipeline configuration"

                Failure err ->
                    small [ class "error" ] [ text <| "There was a problem fetching the pipeline configuration: " ++ Errors.errorToString err ]

                _ ->
                    text ""
    in
    div [ class "config" ] <|
        [ header
        , div [ class "content", class <| webDataToClass model.pipeline.config ]
            [ content
            ]
        ]

focusStyle : Int -> Int -> Html.Attribute Msg
focusStyle lineNum idx = 
    class <| if lineNum == idx then "-focus" else ""

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
