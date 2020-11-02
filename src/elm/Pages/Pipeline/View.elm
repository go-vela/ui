{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (viewAnalysis)

import Dict
import Dict.Extra
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , span
        , text
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import List.Extra
import Pages exposing (Page(..))
import Pages.Pipeline.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import SvgBuilder
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


viewPipeline : PartialModel a -> Org -> Repo -> Maybe String -> Html Msg
viewPipeline model org repo  ref =
    let
        header =
            div [ class "header" ]
                [ span [] [ text "Pipeline Configuration" ]
                , button
                    [ class "button"
                    , class "-link"
                    , onClick <| ExpandPipelineConfig org repo ref
                    ]
                    [ text "expand templates" ]
                ]
    in
    div [ class "analysis" ] <|
        [ header
        , if String.length model.pipeline.config > 0 then
            div [ class "lines" ] <|
                List.indexedMap (\idx -> \l -> div [ class "line" ] [ lineFocusButton (idx + 1), code [] [ text l ] ]) <|
                    String.lines model.pipeline.config

          else
            code [] [ text "no pipeline config found" ]
        ]



-- div [ class "analysis" ] [ code [] [text  model.pipeline.config]]


lineFocusButton : Int -> Html Msg
lineFocusButton lineNumber =
    button
        [ class "line-number"
        , class "button"
        , class "-link"
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]




viewTemplates : Templates -> Html Msg
viewTemplates templates =
    let
        templatesList =
            Dict.toList <| templates
    in
    div [ class "templates" ]
        [ div [ class "header" ] [ text "Templates" ]
        , if List.length templatesList > 0 then
            div [] <| List.map viewTemplate templatesList

          else
            div [ class "no-templates" ] [ code [] [ text "pipeline does not contain templates" ] ]
        ]


viewTemplate : ( String, Template ) -> Html msg
viewTemplate ( _, t ) =
    Html.details [ class "details", class "template" ]
        [ Html.summary [ class "summary" ]
            [ text t.name
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
        , div [ class "template" ]
            [ div [] [ span [] [ text "Name:" ], span [] [ text t.name ] ]
            , div [] [ span [] [ text "Type:" ], span [] [ text t.type_ ] ]
            , div []
                [ span [] [ text "Source:" ]
                , a
                    [ Html.Attributes.target "_blank"
                    , Html.Attributes.href t.link
                    ]
                    [ text t.source ]
                ]
            ]
        ]


templateSourceToLink : String -> String
templateSourceToLink source =
    let
        chunks =
            String.split "/" source

        vcs =
            Maybe.withDefault "" <| List.Extra.getAt 0 chunks

        org =
            Maybe.withDefault "" <| List.Extra.getAt 1 chunks

        repo =
            Maybe.withDefault "" <| List.Extra.getAt 2 chunks

        end =
            Maybe.withDefault "" <| List.Extra.getAt 3 chunks

        refChunks =
            String.split "@" end

        ( file, ref ) =
            if List.length refChunks > 1 then
                ( Maybe.withDefault "" <| List.Extra.getAt 0 refChunks, Maybe.withDefault "" <| List.Extra.getAt 1 refChunks )

            else
                ( Maybe.withDefault "" <| List.Extra.getAt 4 chunks, Maybe.withDefault "" <| List.Extra.getAt 3 chunks )
    in
    String.join "/" [ "https://", vcs, org, repo, "blob", ref, file ]


viewAnalysis : PartialModel a -> Org -> Repo -> Maybe String -> Html Msg
viewAnalysis model org repo ref  =
    div [ class "analysis-container" ]
        [  viewTemplates model.pipeline.templates
        , viewPipeline model org repo  ref
        ]
