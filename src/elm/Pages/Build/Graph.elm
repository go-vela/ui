module Pages.Build.Graph exposing (renderBuildGraphDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import Json.Encode
import Pages.Build.Model as BuildModel
import Routes exposing (Route(..))
import Vela
    exposing
        ( BuildGraph
        , BuildGraphEdge
        , BuildGraphNode
        , Step
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
        )


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
                    (\( _, node ) ->
                        Node node.id (BuildGraphNode node.id node.name node.steps node.status)
                    )

        -- convert BuildGraphEdge to Graph.Edge
        inEdges =
            buildGraph.edges
                |> List.map
                    (\e ->
                        Edge e.source e.destination (BuildGraphEdge e.source e.destination e.status)
                    )

        -- construct graph from nodes and edges
        graph =
            Graph.fromNodesAndEdges inNodes inEdges

        nodes =
            Graph.nodes graph

        -- group built-in nodes such as init and clone
        builtInNodes =
            nodes
                |> List.filter isBuiltInNode

        -- group the rest as pipeline nodes
        pipelineNodes =
            nodes
                |> List.filter (\n -> not <| isBuiltInNode n)

        -- sort edges
        edges =
            let
                compareEdge a b =
                    case compare a.from b.from of
                        LT ->
                            LT

                        GT ->
                            GT

                        EQ ->
                            compare a.to b.to
            in
            Graph.edges graph
                |> List.sortWith compareEdge

        -- group built-in edges such as init-to-clone
        builtInEdges =
            edges
                |> List.filter isBuiltInEdge

        -- group the rest as pipeline edges
        pipelineEdges =
            edges
                |> List.filter (\e -> not <| isBuiltInEdge e)

        -- convert nodes and edges to string
        builtInNodesString =
            List.map (nodeToString model) builtInNodes
                |> String.join "\n"

        pipelineNodesString =
            List.map (nodeToString model) pipelineNodes
                |> String.join "\n"

        builtInEdgesString =
            List.map edgeToString builtInEdges
                |> String.join "\n"

        pipelineEdgesString =
            List.map edgeToString pipelineEdges
                |> String.join "\n"
    in
    digraph baseGraphStyles
        [ ""
        , clusterSubgraph "1" pipelineSubgraphStyles pipelineNodesString pipelineEdgesString
        , ""

        -- built-in nodes are clustered to produce a split layout where more built-in steps can be added later
        , clusterSubgraph "0" builtInSubgraphStyles builtInNodesString builtInEdgesString
        , ""
        ]


stageNodeLabel : BuildModel.PartialModel a -> Bool -> String -> List Step -> String
stageNodeLabel model showSteps label steps =
    let
        table content =
            "<table "
                ++ escapeAttributes stageNodeTableAttrs
                ++ ">"
                ++ String.join "" content
                ++ "</table>"

        -- todo: theme styles
        labelColor =
            "white"

        header =
            "<tr><td "
                ++ escapeAttributes
                    [ ( "align", DefaultEscape "left" ) ]
                ++ " >"
                ++ ("<font color='"
                        ++ labelColor
                        ++ "'>"
                        ++ "<u>"
                        ++ label
                        ++ "</u>"
                        ++ "</font>"
                   )
                ++ "</td><td><font color='white'>("
                ++ (String.fromInt <| List.length steps)
                ++ ")</font></td></tr>"

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


isBuiltInNode : Node BuildGraphNode -> Bool
isBuiltInNode node =
    node.id < 0


isBuiltInEdge : Edge BuildGraphEdge -> Bool
isBuiltInEdge e_ =
    e_.from < -1 || e_.to < -1


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


attrToString : Attribute -> String
attrToString attr =
    case attr of
        DefaultJSONLabelEscape s ->
            Json.Encode.string s
                |> Json.Encode.encode 0

        HtmlLabelEscape h ->
            "<" ++ h ++ ">"


attrAssocs : Dict String Attribute -> String
attrAssocs =
    Dict.toList
        >> List.map (\( k, v ) -> k ++ "=" ++ attrToString v)
        >> String.join ", "


makeAttrs : Dict String Attribute -> String
makeAttrs d =
    if Dict.isEmpty d then
        ""

    else
        " [" ++ attrAssocs d ++ "]"



-- STYLES


baseGraphStyles : Styles
baseGraphStyles =
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


nodeAttrs : BuildModel.PartialModel a -> BuildGraphNode -> Dict String Attribute
nodeAttrs model node =
    let
        -- embed node information in the element id
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt node.id
                    , node.status
                    ]

        -- track stepx expansion using the model and OnGraphInteraction
        showSteps =
            Maybe.withDefault True <| Dict.get node.name model.repo.build.graph.showSteps
    in
    Dict.fromList <|
        [ ( "class", DefaultJSONLabelEscape <| "stage-node" )
        , ( "shape", DefaultJSONLabelEscape "rect" )
        , ( "style", DefaultJSONLabelEscape "filled" )
        , ( "border", DefaultJSONLabelEscape "white" )
        , ( "id", DefaultJSONLabelEscape id )
        , ( "label", HtmlLabelEscape <| stageNodeLabel model showSteps node.name (List.sortBy .id node.steps) )
        , ( "href", DefaultJSONLabelEscape ("#" ++ node.name) )
        ]


edgeAttrs : BuildGraphEdge -> Dict String Attribute
edgeAttrs e =
    let
        -- embed edge information in the element id
        id =
            "#"
                ++ String.join ","
                    [ String.fromInt e.source
                    , String.fromInt e.destination
                    , e.status
                    ]
    in
    Dict.fromList <|
        [ ( "class", DefaultJSONLabelEscape "stage-edge" )
        , ( "style", DefaultJSONLabelEscape "filled" )
        , ( "id", DefaultJSONLabelEscape id )
        ]


stageNodeTableAttrs : List ( String, AttributeValue )
stageNodeTableAttrs =
    [ ( "border", DefaultEscape "0" )
    , ( "cellborder", DefaultEscape "0" )
    , ( "cellspacing", DefaultEscape "5" )
    , ( "margin", DefaultEscape "0" )
    ]
