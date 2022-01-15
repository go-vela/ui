module Visualization.BuildGraph exposing (toDOT)

import Dict exposing (Dict)
import Graph exposing (Edge, Node)
import Vela exposing (BuildGraph, StageNode)
import Visualization.DOT as DOT exposing (Attribute(..), escapeAttributes, outputWithStylesAndAttributes)


{-| toDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
toDOT : () -> BuildGraph -> String
toDOT _ buildGraph =
    let
        -- todo build Graph edges and nodes using dag
        nodes : List (Node StageNode)
        nodes =
            List.map (\( id, node ) -> Node id node) <| Dict.toList buildGraph.nodes

        pairs : List ( Graph.NodeId, Graph.NodeId )
        pairs =
            List.map (\{ source, destination } -> ( source, destination )) buildGraph.edges

        edges =
            List.map (\( a, b ) -> Edge a b ()) pairs

        graph =
            Graph.fromNodesAndEdges nodes edges

        styles : DOT.Styles
        styles =
            { rankdir = DOT.LR
            , graph =
                escapeAttributes
                    [ ( "bgcolor", "transparent" )
                    ]
            , node =
                escapeAttributes
                    [ ( "color", "#151515" )
                    , ( "style", "filled" )
                    , ( "tooltip", " " )
                    , ( "fontname", "Courier" )
                    , ( "fontcolor", "#FFFFFF" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "color", "#808080" )
                    , ( "penwidth", "1.25" )
                    , ( "arrowhead", "none" )
                    ]
            }

        nodeAttrs : StageNode -> Dict String Attribute
        nodeAttrs n =
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape "stage-node" )
                , ( "shape", DefaultJSONLabelEscape "rect" )
                , ( "style", DefaultJSONLabelEscape "filled" )
                , ( "label", HtmlLabelEscape <| n.label )
                ]

        edgeAttrs _ =
            Dict.empty
    in
    outputWithStylesAndAttributes styles nodeAttrs edgeAttrs graph
