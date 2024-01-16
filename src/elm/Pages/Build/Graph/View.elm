{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Build.Graph.View exposing (view)

import Components.Svgs as SvgBuilder exposing (buildVizLegendEdge, buildVizLegendNode)
import FeatherIcons
import Html exposing (Html, button, div, li, text, ul)
import Html.Attributes exposing (class, id)
import Html.Events exposing (onCheck, onClick)
import Pages.Build.Model exposing (Msgs, PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import Svg
import Svg.Attributes
import Util.Helpers as Util
import Vela exposing (BuildNumber, Org, Repo)
import Visualization.DOT as DOT exposing (Attribute(..), AttributeValue(..))



-- VIEW


{-| view : renders the elm build graph root. the graph root is selected by d3 and filled with graphviz content.
-}
view : PartialModel a -> Msgs msg -> Org -> Repo -> BuildNumber -> Html msg
view model msgs org repo buildNumber =
    div [ class "elm-build-graph-container" ]
        [ div [ class "elm-build-graph-actions" ]
            [ ul []
                [ li []
                    [ button [ class "button", class "-icon", id "action-center", Html.Attributes.title "Recenter visualization" ]
                        [ FeatherIcons.minimize
                            |> FeatherIcons.withSize 20
                            |> FeatherIcons.withClass "elm-build-graph-action-button"
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                , li []
                    [ button
                        [ class "button"
                        , class "-icon"
                        , class "build-graph-action-refresh"
                        , Html.Attributes.title "Refresh visualization"
                        , onClick <| msgs.buildGraphMsgs.refresh org repo buildNumber
                        ]
                        [ FeatherIcons.refreshCw
                            |> FeatherIcons.withSize 20
                            |> FeatherIcons.withClass "elm-build-graph-action-button"
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                , li []
                    [ button
                        [ class "button"
                        , class "-icon"
                        , class "build-graph-action-rotate"
                        , class <|
                            case model.shared.repo.build.graph.rankdir of
                                DOT.TB ->
                                    "-vertical"

                                _ ->
                                    ""
                        , Html.Attributes.title "Rotate visualization"
                        , onClick <| msgs.buildGraphMsgs.rotate
                        ]
                        [ FeatherIcons.share2
                            |> FeatherIcons.withSize 20
                            |> FeatherIcons.withClass "elm-build-graph-action-button"
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                ]
            , div [ class "elm-build-graph-action-toggles" ]
                [ div [ class "form-control" ]
                    [ div []
                        [ Html.input
                            [ Html.Attributes.type_ "checkbox"
                            , Html.Attributes.checked model.shared.repo.build.graph.showServices
                            , onCheck msgs.buildGraphMsgs.showServices
                            , id "checkbox-services-toggle"
                            , Util.testAttribute "build-graph-action-toggle-services"
                            ]
                            []
                        , Html.label [ class "form-label", Html.Attributes.for "checkbox-services-toggle" ]
                            [ text "services"
                            ]
                        ]
                    ]
                , div [ class "form-control" ]
                    [ div []
                        [ Html.input
                            [ Html.Attributes.type_ "checkbox"
                            , Html.Attributes.checked model.shared.repo.build.graph.showSteps
                            , onCheck msgs.buildGraphMsgs.showSteps
                            , id "checkbox-steps-toggle"
                            , Util.testAttribute "build-graph-action-toggle-steps"
                            ]
                            []
                        , Html.label [ class "form-label", Html.Attributes.for "checkbox-steps-toggle" ]
                            [ text "steps"
                            ]
                        ]
                    ]
                , div [ class "form-control", class "elm-build-graph-search-filter" ]
                    [ div [ class "elm-build-graph-search-filter-input" ]
                        [ Html.input
                            [ Html.Attributes.type_ "input"
                            , Html.Attributes.placeholder "type to highlight nodes..."
                            , Html.Events.onInput msgs.buildGraphMsgs.updateFilter
                            , id "build-graph-action-filter"
                            , Util.testAttribute "build-graph-action-filter"
                            , Html.Attributes.value model.shared.repo.build.graph.filter
                            ]
                            []
                        , Html.label [ class "elm-build-graph-search-filter-form-label", Html.Attributes.for "build-graph-action-filter" ]
                            [ FeatherIcons.search
                                |> FeatherIcons.withSize 20
                                |> FeatherIcons.withClass "elm-build-graph-action-button"
                                |> FeatherIcons.toHtml []
                            ]
                        ]
                    , button
                        [ class "button"
                        , class "-icon"
                        , Util.testAttribute "build-graph-action-filter-clear"
                        , onClick (msgs.buildGraphMsgs.updateFilter "")
                        ]
                        [ FeatherIcons.x
                            |> FeatherIcons.withSize 20
                            |> FeatherIcons.withClass "elm-build-graph-action-button"
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                ]
            ]
        , div [ class "elm-build-graph-window" ]
            [ ul [ class "elm-build-graph-legend" ]
                [ li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-pending" ]
                    , text "pending"
                    ]
                , li [ class "-running-hover" ]
                    [ buildVizLegendNode [ Svg.Attributes.class "-running" ]
                    , text "running"
                    ]
                , li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-success" ]
                    , text "success"
                    ]
                , li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-failure" ]
                    , text "failed"
                    ]
                , li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-canceled" ]
                    , text "canceled"
                    ]
                , li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-killed" ]
                    , text "skipped"
                    ]
                , li []
                    [ buildVizLegendNode [ Svg.Attributes.class "-selected" ]
                    , text "selected"
                    ]
                , li []
                    [ buildVizLegendEdge [ Svg.Attributes.class "-pending" ]
                    , text "pending"
                    ]
                , li []
                    [ buildVizLegendEdge [ Svg.Attributes.class "-finished" ]
                    , text "complete"
                    ]
                ]
            , case model.shared.repo.build.graph.graph of
                RemoteData.Success _ ->
                    -- dont render anything when the build graph draw command has been dispatched
                    text ""

                RemoteData.Failure _ ->
                    div [ class "elm-build-graph-error" ]
                        [ text "Unable to load build graph, please refresh or try again later!"
                        ]

                RemoteData.Loading ->
                    Util.largeLoader

                RemoteData.NotAsked ->
                    Util.largeLoader
            , Svg.svg
                [ Svg.Attributes.class "elm-build-graph-root"
                ]
                []
            ]
        ]
