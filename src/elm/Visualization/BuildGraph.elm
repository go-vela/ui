module Visualization.BuildGraph exposing (toDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import Pages.Build.Model as BuildModel
import Routes exposing (Route(..))
import Url.Builder as UB
import Vela
    exposing
        ( BuildGraph
        , BuildGraphEdge
        , BuildGraphNode
        , Step
        , statusToString
        )
import Visualization.DOT as DOT exposing (Attribute(..), AttributeValue(..), escapeAttributes, outputWithStylesAndAttributes)


{-| toDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
toDOT : BuildModel.PartialModel a -> BuildGraph -> String
toDOT model buildGraph =
    let
        baseStyles : DOT.Styles
        baseStyles =
            { rankdir = DOT.LR
            , graph =
                escapeAttributes
                    [ ( "bgcolor", DefaultEscape "transparent" )
                    , ( "splines", DefaultEscape "ortho" )
                    ]
            , node =
                escapeAttributes
                    [ ( "color", DefaultEscape "#151515" )
                    , ( "style", DefaultEscape "filled" )
                    , ( "fontname", DefaultEscape "Arial" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "color", DefaultEscape "azure2" )
                    , ( "penwidth", DefaultEscape "2" )
                    , ( "arrowhead", DefaultEscape "dot" )
                    , ( "arrowsize", DefaultEscape "0.5" )
                    , ( "minlen", DefaultEscape "1" )
                    ]
            }

        builtInSubgraphStyles : DOT.Styles
        builtInSubgraphStyles =
            { rankdir = DOT.LR
            , graph =
                escapeAttributes
                    [ ( "bgcolor", DefaultEscape "transparent" )
                    , ( "peripheries", DefaultEscape "0" )
                    ]
            , node =
                escapeAttributes
                    [ ( "color", DefaultEscape "#151515" )
                    , ( "style", DefaultEscape "filled" )
                    , ( "fontname", DefaultEscape "Arial" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "minlen", DefaultEscape "1" )
                    ]
            }

        pipelineSubgraphStyles : DOT.Styles
        pipelineSubgraphStyles =
            { rankdir = DOT.LR
            , graph =
                escapeAttributes
                    [ ( "bgcolor", DefaultEscape "transparent" )
                    , ( "peripheries", DefaultEscape "0" )
                    ]
            , node =
                escapeAttributes
                    [ ( "color", DefaultEscape "#151515" )
                    , ( "style", DefaultEscape "filled" )
                    , ( "fontname", DefaultEscape "Arial" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "color", DefaultEscape "azure2" )
                    , ( "penwidth", DefaultEscape "2" )
                    , ( "arrowhead", DefaultEscape "dot" )
                    , ( "arrowsize", DefaultEscape "0.5" )
                    , ( "minlen", DefaultEscape "2" )
                    ]
            }

        nodeAttrs : BuildGraphNode -> Dict String Attribute
        nodeAttrs n =
            let
                showSteps =
                    Maybe.withDefault True <| Dict.get n.name model.repo.build.graph.showSteps
            in
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape <| "stage-node" )
                , ( "id", DefaultJSONLabelEscape <| "#" ++ n.status )
                , ( "shape", DefaultJSONLabelEscape "rect" )
                , ( "style", DefaultJSONLabelEscape "filled" )
                , ( "label", HtmlLabelEscape <| buildLabel model n.name n.steps showSteps )
                , ( "href", DefaultJSONLabelEscape ("#" ++ n.name) )
                , ( "border", DefaultJSONLabelEscape "white" )
                ]

        edges =
            List.map (\e -> Edge e.source e.destination (BuildGraphEdge e.source e.destination e.status)) buildGraph.edges

        nodes =
            List.map (\( _, node ) -> Node node.id (BuildGraphNode node.id node.name node.steps node.status)) <| Dict.toList buildGraph.nodes

        edgeAttrs : BuildGraphEdge -> Dict String Attribute
        edgeAttrs e =
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape "stage-edge" )
                , ( "title", DefaultJSONLabelEscape <| "#" ++ e.status )
                , ( "id", DefaultJSONLabelEscape <| "#" ++ e.status )
                , ( "style", DefaultJSONLabelEscape "filled" )
                ]

        graph =
            Graph.fromNodesAndEdges nodes edges
    in
    outputWithStylesAndAttributes baseStyles pipelineSubgraphStyles builtInSubgraphStyles nodeAttrs edgeAttrs graph


buildLabel : BuildModel.PartialModel a -> String -> List Step -> Bool -> String
buildLabel model label steps_ showSteps =
    let
        -- steps =
        --     debugSteps
        steps =
            List.sortBy .id steps_

        table body =
            "<TABLE "
                ++ escapeAttributes
                    [ ( "BORDER", DefaultEscape "0" )
                    , ( "CELLBORDER", DefaultEscape "0" )
                    , ( "CELLSPACING", DefaultEscape "5" )
                    , ( "MARGIN", DefaultEscape "0" )
                    ]
                ++ ">"
                ++ String.join "" body
                ++ "</TABLE>"

        src =
            UB.absolute [ "post.png" ] []

        fontcolor =
            "white"

        header attrs body =
            "<TR><TD  " ++ attrs ++ " >" ++ body ++ "</TD><TD><font color='white'>(" ++ (String.fromInt <| List.length steps) ++ ")</font></TD></TR>"

        row rowAttrs cellAttrs body step =
            "<TR "
                ++ rowAttrs
                ++ " >"
                ++ "<TD "
                ++ cellAttrs
                ++ " "
                ++ ">"
                ++ "&nbsp;&nbsp;"
                ++ "<font color='white'>"
                ++ step.name
                ++ "</font>"
                ++ "<BR ALIGN='LEFT'/>"
                ++ "</TD>"
                ++ "</TR>"

        labelColor =
            "white"

        stuff =
            table <|
                [ header
                    (escapeAttributes
                        [ ( "ALIGN", DefaultEscape "left" ) ]
                    )
                    ("<font color='"
                        ++ labelColor
                        ++ "'>"
                        ++ "<U>"
                        ++ label
                        ++ "</U>"
                        ++ "</font>"
                    )
                ]
                    ++ (if showSteps then
                            List.map
                                (\step ->
                                    let
                                        link =
                                            Routes.routeToUrl <| Routes.Build model.repo.org model.repo.name model.repo.build.buildNumber (Just <| Focus.resourceFocusFragment "step" (String.fromInt step.number) [])
                                    in
                                    row
                                        (escapeAttributes
                                            [ ( "ID", DefaultEscape "node-row" ) ]
                                        )
                                        (escapeAttributes
                                            [ ( "BORDER", DefaultEscape "0" )
                                            , ( "CELLBORDER", DefaultEscape "0" )
                                            , ( "CELLSPACING", DefaultEscape "0" )
                                            , ( "MARGIN", DefaultEscape "0" )
                                            , ( "ALIGN", DefaultEscape "left" )
                                            , ( "HREF", DefaultEscape link )
                                            , ( "ID", DefaultEscape "node-cell" )
                                            , ( "TITLE", DefaultEscape ("#status-" ++ statusToString step.status) )
                                            , ( "TOOLTIP", DefaultEscape (String.join "," [ String.fromInt step.id, step.name, statusToString step.status ]) )
                                            ]
                                        )
                                        step.name
                                        step
                                )
                                steps

                        else
                            []
                       )
    in
    stuff
