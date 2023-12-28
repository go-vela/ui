{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Build.Graph.DOT exposing (renderDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import Pages.Build.Model as BuildModel
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import Util
import Vela
    exposing
        ( Build
        , BuildGraph
        , BuildGraphEdge
        , BuildGraphNode
        , Repository
        , statusToString
        )
import Visualization.DOT
    exposing
        ( Attribute(..)
        , AttributeValue(..)
        , Rankdir(..)
        , Styles
        , clusterSubgraph
        , digraph
        , escapeAttributes
        , makeAttributes
        )


{-| renderDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
renderDOT : BuildModel.PartialModel a -> BuildGraph -> String
renderDOT model buildGraph =
    let
        isNodeFocused : String -> BuildGraphNode -> Bool
        isNodeFocused filter n =
            n.id
                == model.shared.repo.build.graph.focusedNode
                || (String.length filter > 2)
                && (String.contains filter n.name
                        || List.any (\s -> String.contains filter s.name) n.steps
                   )

        isEdgeFocused : Int -> BuildGraphEdge -> Bool
        isEdgeFocused focusedNode e =
            focusedNode == e.destination || focusedNode == e.source

        -- convert BuildGraphNode to Graph.Node
        inNodes =
            buildGraph.nodes
                |> Dict.toList
                |> List.map
                    (\( _, n ) ->
                        Node n.id
                            (BuildGraphNode n.cluster n.id n.name n.status n.startedAt n.finishedAt n.steps (isNodeFocused model.shared.repo.build.graph.filter n))
                    )

        -- convert BuildGraphEdge to Graph.Edge
        inEdges =
            buildGraph.edges
                |> List.map
                    (\e -> Edge e.source e.destination (BuildGraphEdge e.cluster e.source e.destination e.status (isEdgeFocused model.shared.repo.build.graph.focusedNode e)))

        -- construct a Graph to extract nodes and edges
        ( nodes, edges ) =
            Graph.fromNodesAndEdges inNodes inEdges
                |> (\graph -> ( Graph.nodes graph, Graph.edges graph ))

        -- group nodes based on cluster
        builtInNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == builtInClusterID)

        pipelineNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == pipelineClusterID)

        serviceNodes =
            nodes
                |> List.filter (\n -> n.label.cluster == serviceClusterID)

        -- group edges based on cluster
        builtInEdges =
            edges
                |> List.filter (\e -> e.label.cluster == builtInClusterID)

        pipelineEdges =
            edges
                |> List.filter (\e -> e.label.cluster == pipelineClusterID)

        serviceEdges =
            edges
                |> List.filter (\e -> e.label.cluster == serviceClusterID)

        -- convert nodes and edges to DOT string format
        builtInNodesString =
            List.map (nodeToString model buildGraph) builtInNodes
                |> String.join "\n"

        pipelineNodesString =
            List.map (nodeToString model buildGraph) pipelineNodes
                |> String.join "\n"

        serviceNodesString =
            List.map (nodeToString model buildGraph) serviceNodes
                |> String.join "\n"

        builtInEdgesString =
            List.map edgeToString builtInEdges
                |> String.join "\n"

        pipelineEdgesString =
            List.map edgeToString pipelineEdges
                |> String.join "\n"

        serviceEdgesString =
            List.map edgeToString serviceEdges
                |> String.join "\n"

        -- construct DOT subgraphs using nodes and edges
        pipelineSubgraph =
            clusterSubgraph pipelineClusterID pipelineSubgraphStyles pipelineNodesString pipelineEdgesString

        builtInSubgraph =
            clusterSubgraph builtInClusterID builtInSubgraphStyles builtInNodesString builtInEdgesString

        serviceSubgraph =
            if model.shared.repo.build.graph.showServices then
                clusterSubgraph serviceClusterID serviceSubgraphStyles serviceNodesString serviceEdgesString

            else
                ""

        -- reverse the subgraphs for top-bottom rankdir to consistently group services and built-ins
        rotation =
            case model.shared.repo.build.graph.rankdir of
                TB ->
                    List.reverse

                _ ->
                    identity

        subgraphs =
            [ -- pipeline (stages, steps) subgraph and cluster
              pipelineSubgraph
            , ""

            -- built-in (init, clone) subgraph and cluster
            , builtInSubgraph
            , ""

            -- services subgraph and cluster
            , serviceSubgraph
            ]
    in
    digraph (baseGraphStyles model.shared.repo.build.graph.rankdir)
        (rotation subgraphs)


{-| nodeLabel : takes model, graph info, a node, and returns a string representation of the "label" applied to a node element.
a "label" is actually a disguised graphviz table <https://graphviz.org/doc/info/lang.html> that is used to
render a list of stage-steps as graph content that is recognized by the layout
-}
nodeLabel : BuildModel.PartialModel a -> BuildGraph -> BuildGraphNode -> Bool -> String
nodeLabel model buildGraph node showSteps =
    let
        label =
            node.name

        steps =
            List.sortBy .id node.steps

        table content =
            "<table "
                ++ escapeAttributes nodeLabelTableAttributes
                ++ ">"
                ++ String.concat content
                ++ "</table>"

        runtime =
            Util.formatRunTime model.time node.startedAt node.finishedAt

        header =
            "<tr>"
                ++ "<td "
                ++ escapeAttributes
                    [ ( "align", DefaultEscape "left" )
                    ]
                ++ " >"
                ++ ("<font>"
                        ++ "<u>"
                        ++ label
                        ++ "</u>"
                        ++ "</font>"
                        ++ (if node.cluster /= serviceClusterID then
                                "  <font>("
                                    ++ (String.fromInt <| List.length steps)
                                    ++ ")</font>"

                            else
                                ""
                           )
                   )
                ++ "</td>"
                ++ "<td><font>"
                ++ runtime
                ++ "</font></td>"
                ++ "</tr>"

        link step =
            Routes.routeToUrl <|
                Routes.Build buildGraph.org
                    buildGraph.repo
                    (String.fromInt buildGraph.buildNumber)
                    (Just <|
                        Focus.resourceFocusFragment
                            "step"
                            (String.fromInt step.number)
                            []
                    )

        -- table row and cell styling
        rowAttributes _ =
            [-- row attributes go here
            ]

        cellAttributes step =
            [ ( "border", DefaultEscape "0" )
            , ( "cellborder", DefaultEscape "0" )
            , ( "cellspacing", DefaultEscape "0" )
            , ( "margin", DefaultEscape "0" )
            , ( "align", DefaultEscape "left" )
            , ( "href", DefaultEscape <| link step )
            , ( "id", DefaultEscape "node-cell" )
            , ( "title", DefaultEscape ("#status-" ++ statusToString step.status) )
            , ( "tooltip", DefaultEscape (String.join "," [ String.fromInt step.id, step.name, statusToString step.status ]) )
            ]

        row step =
            "<tr "
                ++ escapeAttributes
                    (rowAttributes step)
                ++ ">"
                ++ "<td "
                ++ escapeAttributes
                    (cellAttributes step)
                ++ " "
                ++ ">"
                -- required icon spacing
                ++ "     "
                ++ "<font>"
                ++ step.name
                ++ "</font>"
                ++ "<br align='left'/>"
                ++ "</td>"
                ++ "</tr>"

        rows =
            if showSteps then
                List.map row steps

            else
                []
    in
    table <| header :: rows


{-| nodeLabel : takes model and a node, and returns the DOT string representation
-}
nodeToString : BuildModel.PartialModel a -> BuildGraph -> Node BuildGraphNode -> String
nodeToString model buildGraph node =
    "  "
        ++ String.fromInt node.id
        ++ makeAttributes (nodeAttributes model buildGraph node.label)


{-| edgeToString : takes model and a node, and returns the DOT string representation
-}
edgeToString : Edge BuildGraphEdge -> String
edgeToString edge =
    "  "
        ++ String.fromInt edge.from
        ++ " -> "
        ++ String.fromInt edge.to
        ++ makeAttributes (edgeAttributes edge.label)



-- STYLES


{-| baseGraphStyles : returns the base styles applied to the root graph.
-}
baseGraphStyles : Rankdir -> Styles
baseGraphStyles rankdir =
    { rankdir = rankdir
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
            , ( "penwidth", DefaultEscape "1" )
            , ( "arrowhead", DefaultEscape "dot" )
            , ( "arrowsize", DefaultEscape "0.5" )
            , ( "minlen", DefaultEscape "1" )
            ]
    }


{-| builtInSubgraphStyles : returns the styles applied to the built-in-steps subgraph.
-}
builtInSubgraphStyles : Styles
builtInSubgraphStyles =
    { rankdir = LR -- unused with subgraph but required by model
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


{-| pipelineSubgraphStyles : returns the styles applied to the pipeline-steps subgraph.
-}
pipelineSubgraphStyles : Styles
pipelineSubgraphStyles =
    { rankdir = LR -- unused with subgraph but required by model
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


{-| serviceSubgraphStyles : returns the styles applied to the services subgraph.
-}
serviceSubgraphStyles : Styles
serviceSubgraphStyles =
    { rankdir = LR -- unused with subgraph but required by model
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
            , ( "penwidth", DefaultEscape "0" )
            , ( "arrowhead", DefaultEscape "dot" )
            , ( "arrowsize", DefaultEscape "0" )
            , ( "minlen", DefaultEscape "1" )
            , ( "style", DefaultEscape "invis" )
            ]
    }


{-| nodeLabelTableAttributes : returns the base styles applied to all node label-tables
-}
nodeLabelTableAttributes : List ( String, AttributeValue )
nodeLabelTableAttributes =
    [ ( "border", DefaultEscape "0" )
    , ( "cellborder", DefaultEscape "0" )
    , ( "cellspacing", DefaultEscape "5" )
    , ( "margin", DefaultEscape "0" )
    ]


{-| nodeAttributes : returns the node-specific dynamic attributes
-}
nodeAttributes : BuildModel.PartialModel a -> BuildGraph -> BuildGraphNode -> Dict String Attribute
nodeAttributes model buildGraph node =
    let
        -- embed node information in the element id
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt node.id
                    , node.name
                    , node.status
                    , Util.boolToString node.focused
                    ]

        class =
            String.join " "
                [ "elm-build-graph-node" -- generic styling
                , "elm-build-graph-node-" ++ String.fromInt node.id -- selector used for testing
                ]

        -- track step expansion using the model and OnGraphInteraction
        showSteps =
            model.shared.repo.build.graph.showSteps
    in
    Dict.fromList <|
        -- node attributes
        [ ( "shape", DefaultJSONLabelEscape "rect" )
        , ( "style", DefaultJSONLabelEscape "filled" )
        , ( "border", DefaultJSONLabelEscape "white" )

        -- dynamic attributes
        , ( "id", DefaultJSONLabelEscape id )
        , ( "class", DefaultJSONLabelEscape class )
        , ( "href", DefaultJSONLabelEscape ("#" ++ node.name) )
        , ( "label", HtmlLabelEscape <| nodeLabel model buildGraph node showSteps )
        , ( "tooltip", DefaultJSONLabelEscape id )
        ]


{-| edgeAttributes : returns the edge-specific dynamic attributes
-}
edgeAttributes : BuildGraphEdge -> Dict String Attribute
edgeAttributes edge =
    let
        -- embed edge information in the element id to use during OnGraphInteraction callbacks
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt edge.source
                    , String.fromInt edge.destination
                    , edge.status
                    , Util.boolToString edge.focused
                    ]

        class =
            String.join " "
                [ "elm-build-graph-edge" -- generic styling

                -- selector used for testing
                , "elm-build-graph-edge-"
                    ++ String.fromInt edge.source
                    ++ "-"
                    ++ String.fromInt edge.destination
                ]
    in
    Dict.fromList <|
        [ ( "id", DefaultJSONLabelEscape id )
        , ( "class", DefaultJSONLabelEscape class )
        , ( "style", DefaultJSONLabelEscape "filled" )
        ]


{-| builtInClusterID : constant for organizing the layout of build graph nodes
-}
builtInClusterID : Int
builtInClusterID =
    2


{-| pipelineClusterID : constant for organizing the layout of build graph nodes
-}
pipelineClusterID : Int
pipelineClusterID =
    1


{-| serviceClusterID : constant for organizing the layout of build graph nodes
-}
serviceClusterID : Int
serviceClusterID =
    0
