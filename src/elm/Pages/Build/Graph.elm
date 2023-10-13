module Pages.Build.Graph exposing (renderBuildGraphDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import Pages.Build.Model as BuildModel
import Routes exposing (Route(..))
import Util
import Vela
    exposing
        ( BuildGraph
        , BuildGraphEdge
        , BuildGraphNode
        , statusToString
        )
import Visualization.DOT as DOT
    exposing
        ( Attribute(..)
        , AttributeValue(..)
        , Styles
        , clusterSubgraph
        , digraph
        , escapeAttributes
        , makeAttrs
        )


{-| renderBuildGraphDOT : constant for organizing the layout of build graph nodes
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


{-| renderBuildGraphDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
renderBuildGraphDOT : BuildModel.PartialModel a -> BuildGraph -> String
renderBuildGraphDOT model buildGraph =
    let
        -- convert BuildGraphNode to Graph.Node
        inNodes =
            buildGraph.nodes
                |> Dict.toList
                |> List.map
                    (\( _, n ) -> Node n.id (BuildGraphNode n.cluster n.id n.name n.status n.startedAt n.finishedAt n.steps))

        -- convert BuildGraphEdge to Graph.Edge
        inEdges =
            buildGraph.edges
                |> List.map
                    (\e -> Edge e.source e.destination (BuildGraphEdge e.cluster e.source e.destination e.status))

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
            List.map (nodeToString model) builtInNodes
                |> String.join "\n"

        pipelineNodesString =
            List.map (nodeToString model) pipelineNodes
                |> String.join "\n"

        serviceNodesString =
            List.map (nodeToString model) serviceNodes
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
            if model.repo.build.graph.showServices then
                clusterSubgraph serviceClusterID serviceSubgraphStyles serviceNodesString serviceEdgesString

            else
                ""
    in
    digraph baseGraphStyles
        [ ""

        -- pipeline (stages, steps) subgraph and cluster
        , pipelineSubgraph
        , ""

        -- built-in (init, clone) subgraph and cluster
        , builtInSubgraph
        , ""

        -- services subgraph and cluster
        , serviceSubgraph
        , ""
        ]


nodeLabel : BuildModel.PartialModel a -> Bool -> BuildGraphNode -> String
nodeLabel model showSteps node =
    let
        label =
            node.name

        steps =
            List.sortBy .id node.steps

        table content =
            "<table "
                ++ escapeAttributes nodeTableAttrs
                ++ ">"
                ++ String.join "" content
                ++ "</table>"

        -- todo: theme styles
        labelColor =
            "white"

        runtime =
            Util.formatRunTime model.time node.startedAt node.finishedAt

        header =
            "<tr>"
                ++ "<td "
                ++ escapeAttributes
                    [ ( "align", DefaultEscape "left" )
                    ]
                ++ " >"
                ++ ("<font color='"
                        ++ labelColor
                        ++ "'>"
                        ++ "<u>"
                        ++ label
                        ++ "</u>"
                        ++ "</font>"
                        ++ (if node.cluster /= 1 then
                                "  <font color='white'>("
                                    ++ (String.fromInt <| List.length steps)
                                    ++ ")</font>"

                            else
                                ""
                           )
                   )
                ++ "</td>"
                ++ "<td><font color='white'>"
                ++ runtime
                ++ "</font></td>"
                ++ "</tr>"

        link step =
            Routes.routeToUrl <|
                Routes.Build model.repo.org
                    model.repo.name
                    model.repo.build.buildNumber
                    (Just <|
                        Focus.resourceFocusFragment
                            "step"
                            (String.fromInt step.number)
                            []
                    )

        -- table row and cell styling
        rowAttrs _ =
            [-- row attributes go here
            ]

        cellAttrs step =
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
                    (rowAttrs step)
                ++ ">"
                ++ "<td "
                ++ escapeAttributes
                    (cellAttrs step)
                ++ " "
                ++ ">"
                ++ "&nbsp;&nbsp;"
                ++ "<font color='"
                ++ labelColor
                ++ "'>"
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



-- HELPERS


nodeToString : BuildModel.PartialModel a -> Node BuildGraphNode -> String
nodeToString model n =
    "  "
        ++ String.fromInt n.id
        ++ makeAttrs (nodeAttrs model n.label)


edgeToString : Edge BuildGraphEdge -> String
edgeToString e =
    "  "
        ++ String.fromInt e.from
        ++ " -> "
        ++ String.fromInt e.to
        ++ makeAttrs (edgeAttrs e.label)



-- STYLES


baseGraphStyles : Styles
baseGraphStyles =
    { rankdir = DOT.LR
    , graph =
        escapeAttributes
            [ ( "bgcolor", DefaultEscape "transparent" )
            , ( "splines", DefaultEscape "ortho" )

            -- , ( "compound", DefaultEscape "true" )
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


builtInSubgraphStyles : Styles
builtInSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph
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


pipelineSubgraphStyles : Styles
pipelineSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph
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


serviceSubgraphStyles : Styles
serviceSubgraphStyles =
    { rankdir = DOT.LR -- unused with subgraph
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


nodeAttrs : BuildModel.PartialModel a -> BuildGraphNode -> Dict String Attribute
nodeAttrs model node =
    let
        -- embed node information in the element id
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt node.id
                    , node.name
                    , node.status
                    ]

        -- track step expansion using the model and OnGraphInteraction
        showSteps =
            model.repo.build.graph.showSteps
    in
    Dict.fromList <|
        -- static attributes
        defaultNodeAttrs
            ++ -- dynamic attributes
               [ ( "id", DefaultJSONLabelEscape id )
               , ( "href", DefaultJSONLabelEscape ("#" ++ node.name) )
               , ( "label", HtmlLabelEscape <| nodeLabel model showSteps node )
               , ( "tooltip", DefaultJSONLabelEscape node.name )
               ]


defaultNodeAttrs : List ( String, Attribute )
defaultNodeAttrs =
    [ ( "class", DefaultJSONLabelEscape "elm-build-graph-node" )
    , ( "shape", DefaultJSONLabelEscape "rect" )
    , ( "style", DefaultJSONLabelEscape "filled" )
    , ( "border", DefaultJSONLabelEscape "white" )
    ]


nodeTableAttrs : List ( String, AttributeValue )
nodeTableAttrs =
    [ ( "border", DefaultEscape "0" )
    , ( "cellborder", DefaultEscape "0" )
    , ( "cellspacing", DefaultEscape "5" )
    , ( "margin", DefaultEscape "0" )
    ]


edgeAttrs : BuildGraphEdge -> Dict String Attribute
edgeAttrs e =
    let
        -- embed edge information in the element id to use during OnGraphInteraction callbacks
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt e.source
                    , String.fromInt e.destination
                    , e.status
                    ]
    in
    Dict.fromList <|
        [ ( "class", DefaultJSONLabelEscape "elm-build-graph-edge" )
        , ( "style", DefaultJSONLabelEscape "filled" )
        , ( "id", DefaultJSONLabelEscape id )
        ]
